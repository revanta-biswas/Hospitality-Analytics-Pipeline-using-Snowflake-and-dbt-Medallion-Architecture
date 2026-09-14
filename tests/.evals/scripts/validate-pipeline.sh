#!/usr/bin/env bash
# validate-pipeline.sh — LAYER 2: the non-skippable local gate run AFTER slot substitution and BEFORE
# the pipeline is committed (CI-DETERMINISM-PLAN Section 4). This is "run locally, fix, then push".
#
# 🔴 A non-zero exit means the pipeline is NOT committed — it is fixed and re-validated (max 3 attempts,
#    then HALT per Section 4.0.4). This script never mutates the repo; it only inspects.
#
# Usage: bash tests/.evals/scripts/validate-pipeline.sh [base-sha]
set -uo pipefail

WF=".github/workflows/agentic-eval-pipeline.yml"
CONFIG="tests/.evals/config.json"
BASE_SHA="${1:-}"
rc=0
note() { echo "  $*"; }
check_fail() { echo "FAIL  $1"; rc=1; }
check_ok() { echo "ok    $1"; }

echo "validate-pipeline: checking ${WF}"

# A "code view" of the workflow with whole-line YAML comments stripped, so prose in comments (which may
# legitimately mention `|| true`, ${SLOT}, <placeholder> as documentation) never trips a check. Inline
# `#` inside a run: block is left alone — those are shell comments and rare in the generated file.
CODEVIEW="$(mktemp)"
if [ -f "$WF" ]; then grep -vE '^[[:space:]]*#' "$WF" > "$CODEVIEW" || true; fi
cleanup() { rm -f "$CODEVIEW"; }
trap cleanup EXIT

# ── V-slot: no leftover ${SLOT} / GENERATE / placeholder markers ──
# 🔴 Exclude legitimate RUNTIME shell vars the templates set via step env: (e.g. ${EVAL_KEY},
#    ${BASE_SHA}) — those are NOT unresolved template slots. Everything else in ${UPPER_CASE} is.
if [ ! -f "$WF" ]; then check_fail "workflow file $WF does not exist"; else
  slot_hits="$(grep -nE '\$\{[A-Z_]+\}|# GENERATE:|<[a-z][a-z-]*>|>>> [A-Z_ ]+ (START|END) <<<' "$CODEVIEW" \
    | grep -vE '\$\{(EVAL_KEY|BASE_SHA|GITHUB_[A-Z_]+|SONAR_TOKEN|CE_TASK_URL|ANALYSIS_ID|SERVER_URL|REPORT_TASK)\}' || true)"
  if [ -n "$slot_hits" ]; then
    echo "$slot_hits"
    check_fail "unresolved slot/placeholder/marker remains in the committed workflow (V14)"
  else check_ok "no unresolved slots or placeholders (V14)"; fi
fi

# ── V1: YAML parses ──
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import yaml,sys; yaml.safe_load(open('$WF'))" 2>/tmp/vp_yaml.err; then
    check_ok "YAML parses (V1)"
  else check_fail "YAML parse error (V1): $(cat /tmp/vp_yaml.err)"; fi
else note "python3 not available — YAML parse (V1) not run"; fi

# ── V2: actionlint ──
if command -v actionlint >/dev/null 2>&1; then
  if actionlint "$WF" 2>/tmp/vp_al.err; then check_ok "actionlint clean (V2)";
  else check_fail "actionlint errors (V2): $(cat /tmp/vp_al.err)"; fi
else note "actionlint: not available — schema check (V2) not run (record this in the announcement)"; fi

# ── V-manifest: gates[] appears in BOTH the verdict tally and the eval.json schema ──
if [ -f "$CONFIG" ] && command -v jq >/dev/null 2>&1; then
  # Static gate ids are computed inside run-evals; here we assert the ci block is well-formed and that
  # the verdict step in the workflow tallies the five aggregate outcomes the templates emit.
  gate_count=$(jq -r '.ci.gates | length' "$CONFIG" 2>/dev/null || echo 0)
  [ "${gate_count:-0}" -gt 0 ] && check_ok "ci.gates present (${gate_count} gates)" || check_fail "ci.gates empty (manifest not filled)"
  for agg in static unit coverage behavior judge sonar; do
    grep -q "\"${agg}:" "$WF" || check_fail "verdict tally missing aggregate outcome '${agg}' (V8/V18)"
  done
  # eval.json schema check: run-evals must iterate ci.gates (grep the shipped script)
  if [ -f "tests/.evals/scripts/run-evals.sh" ]; then
    grep -q 'ci.gates' tests/.evals/scripts/run-evals.sh || check_fail "run-evals.sh does not iterate ci.gates — scorecard can drift (4.0c.3)"
  fi
else check_fail "$CONFIG or jq missing — cannot validate the manifest"; fi

# ── V4: every file the workflow/scripts reference actually exists ──
for f in "tests/.evals/config.json" "tests/.evals/rubrics/architecture-rubric.json" "tests/.evals/rubrics/security-rubric.json" "tests/.evals/behavior/run.sh"; do
  if [ -f "$f" ]; then check_ok "referenced file exists: $f (V4)"; else check_fail "referenced file missing: $f (V4)"; fi
done
if [ -f "$CONFIG" ] && command -v jq >/dev/null 2>&1; then
  sonar_enabled=$(jq -r '.sonarqube.enabled // false' "$CONFIG")
  if [ "$sonar_enabled" = "true" ]; then
    if [ -f "sonar-project.properties" ]; then check_ok "sonar-project.properties exists (sonarqube.enabled=true) (V4)"
    else check_fail "sonarqube.enabled=true but sonar-project.properties is missing (V4)"; fi
  fi
fi

# ── V11: EVAL_KEY resolves via resolve-eval-key.sh output, never the raw branch ref ──
if [ -f "$WF" ]; then
  if grep -qE 'EVAL_KEY:\s*"\$\{\{\s*github\.head_ref\s*\}\}"' "$CODEVIEW"; then
    check_fail "EVAL_KEY set directly from github.head_ref — branch refs contain '/', this must go through resolve-eval-key.sh (V11)"
  elif grep -q 'steps.evalkey.outputs.key' "$CODEVIEW"; then
    check_ok "EVAL_KEY resolves via resolve-eval-key.sh output (V11)"
  else
    check_fail "no EVAL_KEY resolution via steps.evalkey.outputs.key found (V11)"
  fi
fi

# ── V12: every generated script creates its output directories before writing ──
for s in "tests/.evals/scripts/run-static-evals.sh" "tests/.evals/scripts/run-evals.sh" "tests/.evals/scripts/auto-fix-agent.sh"; do
  if [ -f "$s" ]; then
    if grep -q 'mkdir -p' "$s"; then check_ok "$s creates its directories before writing (V12)"
    else check_fail "$s has no 'mkdir -p' — a clean checkout will hit 'No such file or directory' (V12)"; fi
  fi
done

# ── V15: verify job uploads the eval-results artifact self-repair's download-artifact depends on ──
if [ -f "$WF" ]; then
  if grep -q 'actions/upload-artifact' "$WF" && grep -q 'name: eval-results' "$WF"; then
    check_ok "verify job uploads eval-results artifact (V15)"
  else
    check_fail "no actions/upload-artifact step named 'eval-results' found — self-repair's download-artifact will find nothing (V15)"
  fi
fi

# ── V16/V22: for every version-check line in an "Install eval tools" step, an install command for
#    that same tool appears earlier in the SAME block. A version check with no preceding install
#    only "works" by accident, when the runner image happens to ship the tool already. ──
check_install_order() {
  awk '
    BEGIN {
      n = split("python3 pip pip3 node npm npx git jq curl bash sh podman docker echo printf exit tar gitleaks_version", a, " ")
      for (i=1;i<=n;i++) allowed[a[i]]=1
    }
    /^      - name: "Install eval tools"/ { instep=1; delete seen; next }
    instep && /^      - name:/ { instep=0 }
    instep && /^  [a-zA-Z-]+:/ { instep=0 }
    instep {
      line=$0
      is_comment = (line ~ /^[[:space:]]*#/)
      is_check = (line ~ /--version/ && line ~ /\|\|/) || (line ~ /[[:space:]]version[[:space:]]/ && line ~ /\|\|/) || (line ~ /not found after install/)
      if (is_check && !is_comment) {
        t=line; gsub(/^[[:space:]]+/, "", t); split(t, arr, " ")
        if (arr[1] == "command" && arr[2] == "-v") { tool = arr[3] } else { tool = arr[1] }
        if (tool != "" && !(tool in allowed) && !(tool in seen)) {
          print tool
        }
      } else if (!is_comment) {
        m = split(line, toks, /[ \t"=]+/)
        for (i=1;i<=m;i++) if (toks[i] != "") seen[toks[i]] = 1
      }
    }
  ' "$WF"
}
if [ -f "$WF" ]; then
  missing="$(check_install_order)"
  if [ -n "$missing" ]; then
    while IFS= read -r t; do check_fail "version check for '$t' with no preceding install in the same 'Install eval tools' step (V16/V22)"; done <<< "$missing"
  else
    check_ok "every version check in 'Install eval tools' is preceded by its install in the same step (V16/V22)"
  fi
fi

# ── V24: after any pip-based eval-tool install, pip check must run before the version checks — this
#    is what catches a pinned tool's transitive dependency graph breaking against an unpinned
#    ecosystem package (Section 3.2.1's setuptools/pkg_resources failure — the original bug). ──
check_pip_check() {
  awk '
    /^      - name: "Install eval tools"/ { instep=1; has_pip=0; has_check=0; next }
    instep && /^      - name:/ { if (has_pip && !has_check) print "MISSING"; instep=0 }
    instep && /^  [a-zA-Z-]+:/ { if (has_pip && !has_check) print "MISSING"; instep=0 }
    instep && /pip install/ { has_pip=1 }
    instep && /pip check/ { has_check=1 }
    END { if (instep && has_pip && !has_check) print "MISSING" }
  ' "$WF"
}
if [ -f "$WF" ]; then
  pipcheck_missing="$(check_pip_check)"
  if [ -n "$pipcheck_missing" ]; then
    check_fail "an 'Install eval tools' step runs pip install but never runs 'pip check' before its version checks (V24)"
  else
    check_ok "pip check runs after every pip-based eval-tool install, or no pip install is used (V24)"
  fi
fi

note "V23 (clean-room dry-run) cannot be verified statically from this file — confirm Section 4.0.1a's clean-room dry-run was actually performed before this commit."

# ── V8: every gate step isolated (id + continue-on-error), exactly one verdict, sonar last & always() ──
if [ -f "$WF" ]; then
  if grep -qE '\|\|[[:space:]]*true|\|\|[[:space:]]*exit 0|;[[:space:]]*true' "$CODEVIEW"; then
    check_fail "forbidden '|| true' / '|| exit 0' / '; true' in a step (V8)"
  else check_ok "no '|| true' style masking (V8)"; fi
  vcount=$(grep -cE '^[[:space:]]*-[[:space:]]*name:[[:space:]]*"Verdict"' "$WF" || true)
  [ "${vcount:-0}" -eq 1 ] && check_ok "exactly one Verdict step (V8)" || check_fail "expected exactly one Verdict step, found ${vcount} (V8)"
fi

# ── V10: trigger covers base branch + every integration prefix from the manifest ──
if [ -f "$WF" ] && [ -f "$CONFIG" ] && command -v jq >/dev/null 2>&1; then
  v10_ok=1
  base=$(jq -r '.ci.baseBranch // "main"' "$CONFIG")
  grep -q "\"${base}\"" "$WF" || { check_fail "trigger does not name base branch '${base}' (V10)"; v10_ok=0; }
  while read -r p; do
    [ -z "$p" ] && continue
    grep -q "'${p}/\*\*'" "$WF" || { check_fail "trigger missing integration prefix '${p}/**' (V10)"; v10_ok=0; }
  done < <(jq -r '.ci.integrationBranchPrefixes[]?' "$CONFIG" | tr -d '\r')
  [ "$v10_ok" -eq 1 ] && check_ok "trigger covers base branch + every integration prefix (V10)"
fi

# ── V13: self-repair re-runs BOTH eval scripts before committing — a commit that never re-verifies
#    wastes a retry attempt on an unverified fix. ──
if [ -f "tests/.evals/scripts/auto-fix-agent.sh" ]; then
  af="tests/.evals/scripts/auto-fix-agent.sh"
  commit_line=$(grep -n 'git commit' "$af" | head -1 | cut -d: -f1 || true)
  static_line=$(grep -n 'run-static-evals' "$af" | head -1 | cut -d: -f1 || true)
  evals_line=$(grep -n 'run-evals\.sh' "$af" | tail -1 | cut -d: -f1 || true)
  if [ -n "$commit_line" ] && [ -n "$static_line" ] && [ -n "$evals_line" ] && \
     [ "$static_line" -lt "$commit_line" ] && [ "$evals_line" -lt "$commit_line" ]; then
    check_ok "auto-fix-agent.sh re-runs run-static-evals.sh and run-evals.sh before git commit (V13)"
  else
    check_fail "auto-fix-agent.sh does not clearly re-run both eval scripts before git commit (V13)"
  fi
fi

# ── V19: self-repair never exits 0 without repairing — every real 'exit 0' must follow a commit ──
if [ -f "tests/.evals/scripts/auto-fix-agent.sh" ]; then
  af="tests/.evals/scripts/auto-fix-agent.sh"
  af_codeview="$(mktemp)"
  grep -vE '^[[:space:]]*#' "$af" > "$af_codeview"
  last_commit_line=$(grep -n 'git commit' "$af_codeview" | tail -1 | cut -d: -f1 || true)
  v19_bad=0
  while IFS=: read -r ln content; do
    [ -z "$ln" ] && continue
    if [ -z "$last_commit_line" ] || [ "$ln" -lt "$last_commit_line" ]; then
      v19_bad=1
      echo "  early exit 0 at line $ln: $content"
    fi
  done < <(grep -n 'exit 0' "$af_codeview" || true)
  rm -f "$af_codeview"
  if [ "$v19_bad" -eq 1 ]; then
    check_fail "auto-fix-agent.sh has an 'exit 0' reachable before a successful commit — self-repair must never claim success without repairing (V19)"
  else
    check_ok "every 'exit 0' in auto-fix-agent.sh follows a successful commit (V19)"
  fi
fi

# ── V20: no deferred-setup N/A — these phrases paired with N/A status are ERROR, never N/A ──
v20_hit=0
for s in "tests/.evals/scripts/run-static-evals.sh" "tests/.evals/scripts/run-evals.sh" "tests/.evals/scripts/auto-fix-agent.sh"; do
  [ -f "$s" ] || continue
  hits=$(grep -nE "N/A" "$s" | grep -Ei 'yet|TODO|not wired|not bootstrapped|not installed|not enabled|pending' || true)
  if [ -n "$hits" ]; then v20_hit=1; echo "$hits"; fi
done
if [ "$v20_hit" -eq 1 ]; then
  check_fail "an 'N/A' reason contains a deferred-setup phrase (yet/TODO/not wired/pending/...) — this must be ERROR, not N/A (V20, eval-framework.md Section 2.4.2)"
else
  check_ok "no deferred-setup language paired with N/A (V20)"
fi

# ── V7: within the stack-resolved D-gates region, every line is delta_diff/record — never a bare
#    whole-tree tool invocation (Section 4.0b's whole-tree-verdict bug). ──
if [ -f "tests/.evals/scripts/run-static-evals.sh" ]; then
  region=$(awk '/>>> STACK-RESOLVED D-GATES START <<</{flag=1; next} />>> STACK-RESOLVED D-GATES END <<</{flag=0} flag' tests/.evals/scripts/run-static-evals.sh)
  # 🔴 `record_multi_root` is the construct run-static-evals.sh itself instructs the generator to emit
  #    for an unresolvable D-gate. The old alternation matched literal `record ` + SPACE only, so it
  #    REJECTED the correct construct - pushing generation back toward the silent-omission shape this
  #    very check exists to prevent.
  bad=$(echo "$region" | grep -vE '^[[:space:]]*($|#|delta_diff |record(_multi_root)? )' || true)
  if [ -n "$bad" ]; then
    check_fail "bare command in the stack-resolved D-gates region (not wrapped in delta_diff/record) — whole-tree verdict risk (V7)"
    echo "$bad"
  else
    check_ok "stack-resolved D-gates region contains only delta_diff/record calls (V7)"
  fi
  # 🔴 V7b - COMPLETENESS. An EMPTY region passed V7 vacuously: a pipeline covering ZERO of
  #    D1/D2/D4/D5/D6 was reported clean. Every D-gate the manifest declares in ci.gates must actually
  #    appear in the region, or it can never be recorded at all - and run-evals.* turns an absent gate
  #    into N/A, which never fails the build.
  if command -v jq >/dev/null 2>&1 && [ -f "tests/.evals/config.json" ]; then
    missing=""
    for g in $(jq -r '.ci.gates[]? // empty' tests/.evals/config.json 2>/dev/null | grep -E '^D[1-7]_' || true); do
      case "$g" in
        D3_sast|D7_secrets) continue ;;   # hard-coded in the fixed template, not in the region
      esac
      echo "$region" | grep -q "$g" || missing="${missing}${missing:+, }${g}"
    done
    if [ -n "$missing" ]; then
      check_fail "D-gate(s) declared in ci.gates but ABSENT from the stack-resolved region: ${missing} — they can never be recorded, and an absent gate is laundered into a non-failing N/A (V7b)"
    else
      check_ok "every D-gate in ci.gates appears in the stack-resolved region (V7b)"
    fi
  fi
  # 🔴 V35 - D5/D6 MUST REFERENCE THEIR THRESHOLD. run-static-evals.* exports
  #    AIRE_DISALLOWED_LICENSES and AIRE_MAX_CYCLOMATIC_COMPLEXITY so the configured numbers are
  #    REACHABLE, but reachable is not enforced: delta_diff's verdict is only "are there new findings
  #    vs baseline", so a D5 command that does not consult the disallow-list fails on ANY newly
  #    introduced licence, and a D6 command that does not consult the cap fails on ANY new complexity
  #    finding. Both thresholds were previously read by no script at all; this is what stops them
  #    sliding back into being decorative. (An earlier code comment cited this check before it
  #    existed - it exists now.)
  if [ -n "$region" ]; then
    thr_missing=""
    if echo "$region" | grep -q 'D5_licenses'; then
      echo "$region" | grep 'D5_licenses' | grep -q 'AIRE_DISALLOWED_LICENSES' \
        || thr_missing="${thr_missing}${thr_missing:+, }D5_licenses (AIRE_DISALLOWED_LICENSES)"
    fi
    if echo "$region" | grep -q 'D6_complexity'; then
      echo "$region" | grep 'D6_complexity' | grep -q 'AIRE_MAX_CYCLOMATIC_COMPLEXITY' \
        || thr_missing="${thr_missing}${thr_missing:+, }D6_complexity (AIRE_MAX_CYCLOMATIC_COMPLEXITY)"
    fi
    if [ -n "$thr_missing" ]; then
      check_fail "gate command does not reference its configured threshold: ${thr_missing} — the number in tests/.evals/config.json is then decorative and the gate fails on ANY new finding rather than one that breaches the threshold (V35)"
    else
      check_ok "D5/D6 commands reference their configured thresholds (V35)"
    fi
  fi
fi

# 🔴 V36 - both generated Sonar steps must carry the run-time scope guard. Without it, a
#    sonar.sources path that does not exist yet (greenfield src/ at the smoke test) fails the scan
#    outright with "The folder 'src' does not exist" (exit 3) AND takes the quality gate down with
#    ".scannerwork/report-task.txt does not exist" - two red steps on a PR with no code to analyse.
#    Observed in a real run. Section 4.1.1b.
WF=".github/workflows/agentic-eval-pipeline.yml"
if [ -f "$WF" ] && grep -q 'sonarqube-scan-action' "$WF"; then
  sonar_missing=""
  grep -q 'Resolve Sonar scope' "$WF" || sonar_missing="the 'Resolve Sonar scope' step itself"
  awk '/sonarqube-scan-action/{found=1} found && /steps\.sonarscope\.outputs\.skip/{ok=1} END{exit !ok}' "$WF"       || sonar_missing="${sonar_missing}${sonar_missing:+; }the scan step's skip guard"
  if grep -q 'sonarqube-quality-gate-action' "$WF"; then
    grep -B6 'sonarqube-quality-gate-action' "$WF" | grep -q 'report-task.txt'         || sonar_missing="${sonar_missing}${sonar_missing:+; }the quality-gate step's report-task.txt guard"
  fi
  if [ -n "$sonar_missing" ]; then
    check_fail "SonarQube steps are missing their run-time scope guard: ${sonar_missing} — a configured source path that does not exist yet fails the scan with exit 3 and the quality gate with a missing report-task.txt (V36)"
  else
    check_ok "SonarQube steps carry the run-time scope guard (V36)"
  fi
fi

# ── V9 (partial — see note below): no hardcoded PASS/N-A literal bypassing record/Record ──
for s in "tests/.evals/scripts/run-static-evals.sh" "tests/.evals/scripts/run-evals.sh"; do
  [ -f "$s" ] || continue
  hits=$(grep -nE '"status"[[:space:]]*:[[:space:]]*"(PASS|N/A)"' "$s" | grep -v 'rubric %s absent' || true)
  if [ -n "$hits" ]; then
    check_fail "hardcoded status literal outside the documented rubric-absent N/A fallback in $s — possible stub (V9)"
    echo "$hits"
  else
    check_ok "no hardcoded PASS/N-A literal outside the documented rubric-absent fallback in $s (V9)"
  fi
done
note "V9's full requirement — prove each script can FAIL against a deliberately broken input — needs fault injection and is not fully automated here. The check above only catches the hardcoded-literal half of Section 5.0."

# ── V25: the exact "Install eval tools" pip line resolves as a WHOLE, not tool-by-tool. Two
#    independently pinned tools can each work alone yet be mutually impossible together (observed:
#    semgrep==1.127.0 pins tomli~=2.0.1; pip-audit==2.10.1 pins tomli>=2.2.1 — no tomli version
#    satisfies both). This is a static version-range clash, not drift — it fails identically every
#    time regardless of what else is installed, so pip install --dry-run in ANY environment (not
#    necessarily a clean one — that's V23's job, for drift) catches it deterministically. ──
PIP_CMD=()
if command -v pip >/dev/null 2>&1; then PIP_CMD=(pip)
elif command -v pip3 >/dev/null 2>&1; then PIP_CMD=(pip3)
elif command -v python3 >/dev/null 2>&1; then PIP_CMD=(python3 -m pip)
fi
if [ -f "$WF" ] && [ "${#PIP_CMD[@]}" -gt 0 ]; then
  pip_line=$(awk '
    /^      - name: "Install eval tools"/ { instep=1; next }
    instep && /^      - name:/ { instep=0 }
    instep && /^  [a-zA-Z-]+:/ { instep=0 }
    instep && /pip install "/ { print; exit }
  ' "$WF")
  if [ -n "$pip_line" ]; then
    pkgs_arr=()
    while IFS= read -r p; do
      p="${p%\"}"; p="${p#\"}"
      [ -n "$p" ] && pkgs_arr+=("$p")
    done < <(echo "$pip_line" | grep -oE '"[a-zA-Z0-9_.-]+==[a-zA-Z0-9_.-]+"')
    if [ "${#pkgs_arr[@]}" -gt 0 ]; then
      dry_out=$("${PIP_CMD[@]}" install --dry-run "${pkgs_arr[@]}" 2>&1)
      dry_rc=$?
      if [ "$dry_rc" -ne 0 ]; then
        if echo "$dry_out" | grep -qi 'ResolutionImpossible\|conflicting dependencies'; then
          check_fail "the pinned tool set in 'Install eval tools' cannot be resolved together (V25) — pip install --dry-run reports a real conflict:"
          echo "$dry_out" | grep -A6 'conflict is caused by' || echo "$dry_out" | tail -n 10
        elif echo "$dry_out" | grep -qi 'no such option: --dry-run'; then
          note "V25 not run: the local pip ($("${PIP_CMD[@]}" --version 2>/dev/null)) is older than 22.2 and does not support --dry-run. This check WILL run correctly on the actual GitHub Actions runner (actions/setup-python always installs a modern pip) — upgrade local pip to verify it here too."
        else
          note "V25: pip install --dry-run could not complete (network/registry issue, not a version conflict) — re-run with connectivity to verify"
        fi
      else
        check_ok "the pinned tool set in 'Install eval tools' resolves together (V25)"
      fi
    else
      note "V25: no pinned (==) pip packages found in 'Install eval tools' — nothing to dry-run"
    fi
  fi
else
  note "V25 (combined pip resolution) skipped — no pip/pip3/python3 -m pip available in this environment"
fi

# ── V6 (known actions only): marketplace actions actually used carry their required env/permissions ──
if [ -f "$WF" ]; then
  if grep -q 'gitleaks/gitleaks-action' "$WF"; then
    grep -A5 'gitleaks/gitleaks-action' "$WF" | grep -q 'GITHUB_TOKEN' \
      && check_ok "gitleaks-action has GITHUB_TOKEN wired (V6)" \
      || check_fail "gitleaks-action present without GITHUB_TOKEN in its env (V6)"
  fi
  if grep -q 'anthropics/claude-code-action' "$WF"; then
    grep -q 'id-token: write' "$WF" \
      && check_ok "claude-code-action present with id-token: write permission (V6)" \
      || check_fail "claude-code-action present without id-token: write permission (V6)"
  fi
  if grep -qE 'SonarSource/sonarqube-scan-action|SonarSource/sonarqube-quality-gate-action' "$WF"; then
    grep -q 'SONAR_TOKEN' "$WF" && grep -q 'SONAR_HOST_URL' "$WF" \
      && check_ok "SonarQube actions have SONAR_TOKEN/SONAR_HOST_URL wired (V6)" \
      || check_fail "SonarQube action present without both SONAR_TOKEN and SONAR_HOST_URL (V6)"
  fi
fi

# ── V26: CLAUDE_REPAIR_INVOCATION / CLAUDE_JUDGE_INVOCATION must be a RESOLVED claude call (headless +
#    permission flags from `claude --help` at generation time, Section 6.0) — never left as a bare
#    `claude` with no flags. Unresolved, this either hangs on an interactive approval prompt in a
#    TTY-less runner or silently repairs/scores nothing while still looking like it ran — the exact
#    "looks like success" failure Section 6.0 warns about, and V14 does not catch it (its markers live
#    in these SCRIPT files, not in $WF). Observed in practice: self-repair diagnosed the failure
#    correctly, then reported itself blocked from Edit/Write/Bash approval and pushed no fix. ──
check_invocation_resolved() {
  local file="$1" marker="$2"
  [ -f "$file" ] || { note "V26: ${file} not found — skipping (generated separately, or a different variant is in use)"; return; }
  local block
  block="$(awk -v m="$marker" '
    $0 ~ ">>> " m " START <<<" { grabbing=1; next }
    $0 ~ ">>> " m " END <<<" { grabbing=0 }
    grabbing { print }
  ' "$file")"
  if [ -z "$block" ]; then
    check_fail "could not find the ${marker} markers in ${file} — has the fixed template text been hand-edited? (Section 3.1)"
    return
  fi
  if echo "$block" | grep -qE '\bclaude\b' && ! echo "$block" | grep -qE '\bclaude\s+--?[a-zA-Z]'; then
    check_fail "${marker} in ${file} still invokes a bare 'claude' with no flags — headless/permission flags were never resolved at generation time (V26, Section 6.0)"
  else
    check_ok "${marker} in ${file} invokes claude with resolved flags (V26)"
  fi
}
check_invocation_resolved "tests/.evals/scripts/auto-fix-agent.sh" "CLAUDE_REPAIR_INVOCATION"
check_invocation_resolved "tests/.evals/scripts/run-evals.sh" "CLAUDE_JUDGE_INVOCATION"

# ── V27: structural fidelity to templates/ci/agentic-eval-pipeline.yml.template — every FIXED job id
#    and step name the template declares (i.e. everything OUTSIDE a ${SLOT} region — post-#7a, only
#    ${BASE_BRANCH}/${PR_BRANCH_FILTERS}/${BEHAVIOR_IMAGE_TAG}/${SONAR_STEPS}/${CLAUDE_CODE_VERSION}
#    remain) must appear verbatim in the committed workflow, and neither job may carry a `name:`
#    override the template does not define — both jobs
#    are named ONLY by their id (verify-and-evaluate, self-repair); GitHub renders the id as-is when no
#    `name:` is given. 🔴 KEEP THIS LIST IN SYNC WITH THE TEMPLATE — update it in the same commit
#    whenever agentic-eval-pipeline.yml.template's fixed step names change. This is what turns "the
#    model quietly re-authored the YAML instead of copying it" (observed in the wild: job display name
#    "Verify and evaluate", a fused "Stage 1+2" step replacing the template's separately-isolated
#    stages, a Verdict tallying only 2 outcomes instead of 6) from an undetectable drift into a hard
#    generation-time failure. ──
if [ -f "$WF" ]; then
  FIXED_JOB_IDS="verify-and-evaluate self-repair"
  FIXED_STEP_NAMES=(
    "Checkout (full history for delta diffs)"
    "Resolve EVAL_KEY"
    "Resolve base SHA"
    "Purge inherited evidence"
    "Read manifest"
    "Setup Node"
    "Setup Python"
    "Setup Java"
    "Setup Go"
    "Setup .NET"
    "Install dependencies"
    "Compile / build"
    "Stage 1: static evals (delta-scoped)"
    "Stage 2: unit + coverage"
    "Coverage gate (delta-scoped)"
    "Stage 2: behaviour (Gherkin, Podman)"
    "Install Claude Code CLI"
    "Stage 3: judge gates J1 + J2"
    "Record SonarQube gate status"
    "Verdict"
    "Stage 4: publish scorecard"
    "Upload eval artifacts"
    "Checkout PR head"
    "Download eval artifacts"
    "Autonomous self-repair"
  )

  v27_fail=0

  # Job ids: exactly 2-space-indented identifiers ending in ':', scoped to the top-level `jobs:` block
  # only (Section 4.0.2 rule 5 mandates 2-space, spaces-only indentation, so this is a safe structural
  # anchor — without the jobs: scope this would also match `on:`'s own 2-space-indented trigger keys).
  actual_job_ids="$(awk '/^jobs:$/{f=1;next} f && /^[a-zA-Z]/{exit} f && /^  [a-zA-Z0-9_-]+:$/{line=$0; gsub(/^  /,"",line); gsub(/:$/,"",line); print line}' "$WF")"
  for jid in $FIXED_JOB_IDS; do
    echo "$actual_job_ids" | grep -qx "$jid" \
      || { check_fail "job id '${jid}' missing from the committed workflow (V27) — has the YAML been re-authored instead of copied from the template?"; v27_fail=1; }
  done
  extra_jobs="$(echo "$actual_job_ids" | grep -vxF -e "verify-and-evaluate" -e "self-repair" || true)"
  [ -n "$extra_jobs" ] && { check_fail "unexpected job id(s) not in the template: ${extra_jobs} (V27)"; v27_fail=1; }

  # No job-level `name:` override — the template defines none for either job.
  for jid in verify-and-evaluate self-repair; do
    job_block="$(awk -v j="  ${jid}:" 'seen && /^  [a-zA-Z0-9_-]+:$/{exit} $0==j{seen=1;next} seen{print}' "$WF")"
    if echo "$job_block" | grep -qE '^ {4}name:'; then
      check_fail "job '${jid}' carries a name: override the template does not define (V27) — e.g. a capitalized/spaced display name is proof the YAML was hand-edited rather than copied"
      v27_fail=1
    fi
  done

  # Every fixed step name must be present verbatim.
  for sname in "${FIXED_STEP_NAMES[@]}"; do
    grep -qF "name: \"${sname}\"" "$WF" \
      || { check_fail "template step \"${sname}\" is missing from the committed workflow (V27) — steps may have been merged, renamed, or the YAML re-authored instead of copied"; v27_fail=1; }
  done

  [ "$v27_fail" -eq 0 ] \
    && check_ok "workflow structurally matches agentic-eval-pipeline.yml.template — all fixed job ids and step names present, no unexpected name: overrides (V27)"
fi

# ── V28 + V29 (#7a): the cd/verify and diff-scope logic no longer lives in generated, per-repo YAML
#    text — it moved into the FIXED, framework-owned tests/.evals/scripts/ci-manifest-runner.sh and
#    lib-manifest.sh (common/ci-pipeline-generation.md Section 4.0d.1/4.0g), which the generated
#    workflow only ever CALLS. So these checks are no longer "does this repo's generated text contain a
#    cd for each root" (there is no such per-root generated text left to scan) — they are "does the
#    copied runner script actually contain the resolve_and_verify_root / root_touched calls it must",
#    a ONE-TIME structural check on the fixed script rather than a per-root check on the YAML. ──
RUNNER="tests/.evals/scripts/ci-manifest-runner.sh"
LIBMANIFEST="tests/.evals/scripts/lib-manifest.sh"
if [ -f "$RUNNER" ] && [ -f "$LIBMANIFEST" ]; then
  if grep -q 'resolve_and_verify_root' "$RUNNER" && grep -q 'resolve_and_verify_root()' "$LIBMANIFEST"; then
    check_ok "${RUNNER} verifies each root via resolve_and_verify_root before running its command (V28)"
  else
    check_fail "${RUNNER} does not call resolve_and_verify_root — a root's command could run from an unverified working directory (V28, Section 4.0d.1)"
  fi
  if grep -q 'root_touched' "$RUNNER" && grep -q 'root_touched()' "$LIBMANIFEST"; then
    check_ok "${RUNNER} diff-scopes each root via root_touched before running its command (V29)"
  else
    check_fail "${RUNNER} does not call root_touched — every root's install/build/coverage command would run unconditionally on every PR (V29, Section 4.0g)"
  fi
elif [ -f "$WF" ]; then
  note "V28/V29 skipped — ${RUNNER} or ${LIBMANIFEST} not found (a legacy pre-#7a pipeline, or a variant not yet migrated)"
fi

# ── V30: no untraceable manifest value — Section 3.0.1. Pragmatic, static checks: manifestState/roots[]
#    consistency, plus each declared root actually existing on disk with its markerFile present. This
#    does not (and cannot, statically) prove every installCommand string names a real script — that half
#    stays a manual V3 check, same as today — but it does catch the two most common untraceable-value
#    defects: a "resolved" manifest whose root doesn't exist, and an "unresolved" one that was populated
#    anyway (the exact architecture.md-derived-value failure this check exists to prevent). ──
if [ -f "$CONFIG" ] && command -v jq >/dev/null 2>&1; then
  manifest_state=$(jq -r '.ci.manifestState // "resolved"' "$CONFIG")
  roots_len=$(jq -r '(.ci.roots // []) | length' "$CONFIG")
  if [ "$manifest_state" = "unresolved" ] && [ "$roots_len" -gt 0 ]; then
    check_fail "ci.manifestState is 'unresolved' but ci.roots[] has ${roots_len} entr(y/ies) — an unresolved manifest must have an EMPTY roots[] (V30, Section 3.0). A non-empty roots[] alongside 'unresolved' is exactly the architecture.md-derived-value defect this check exists to catch"
  elif [ "$manifest_state" = "resolved" ] && [ "$roots_len" -eq 0 ]; then
    note "V30: ci.manifestState is 'resolved' but ci.roots[] is empty — verify manually that this is intentional (a legacy flat manifest with no roots[] at all is a separate, valid case)"
  else
    check_ok "ci.manifestState ('${manifest_state}') is consistent with ci.roots[] length (${roots_len}) (V30)"
  fi

  if [ "$roots_len" -gt 0 ]; then
    v30_fail=0
    while IFS=$'\t' read -r root marker; do
      [ -z "$root" ] && continue
      if [ ! -d "$root" ]; then
        check_fail "ci.roots[] root '${root}' does not exist in this checkout (V30) — an untraceable manifest value"
        v30_fail=1
      elif [ -n "$marker" ] && [ "$marker" != "null" ] && [ ! -e "${root}/${marker}" ]; then
        check_fail "ci.roots[] root '${root}' declares markerFile '${marker}', which is not present at ${root}/${marker} (V30) — an untraceable manifest value"
        v30_fail=1
      fi
    done < <(jq -r '.ci.roots[]? | [.root, (.markerFile // "")] | @tsv' "$CONFIG" | tr -d '\r')
    [ "$v30_fail" -eq 0 ] && check_ok "every ci.roots[] entry's directory and markerFile exist in this checkout (V30)"
  fi
else
  note "V30 skipped — jq not available or ${CONFIG} not found"
fi

# ── V31: CI purges inherited evidence and resolves by key, never by search — Section 4.0e. ──
if [ -f "$WF" ]; then
  if grep -qF 'name: "Purge inherited evidence"' "$WF"; then
    check_ok "workflow has a 'Purge inherited evidence' step (V31)"
  else
    check_fail "workflow has no 'Purge inherited evidence' step — a checkout that already carries a story's own committed reports/eval-evidence/\${EVAL_KEY}/ can let a gate that fails to produce fresh output silently publish the stale local run instead (V31, Section 4.0e)"
  fi

  # The self-repair job must resolve its OWN EVAL_KEY (mirroring the verify job) — without it,
  # auto-fix-agent.* has no key-addressed path and must fall back to searching.
  self_repair_block="$(awk '/^  self-repair:$/{f=1} f{print}' "$WF")"
  if echo "$self_repair_block" | grep -qF 'name: "Resolve EVAL_KEY"'; then
    check_ok "self-repair job resolves its own EVAL_KEY (V31)"
  else
    check_fail "self-repair job has no 'Resolve EVAL_KEY' step of its own — auto-fix-agent.* cannot resolve its evidence by key and would have to search (V31, Section 4.0e)"
  fi

  if echo "$self_repair_block" | grep -qE 'EVAL_KEY:\s*"?\$\{\{\s*steps\.evalkey\.outputs\.key'; then
    check_ok "self-repair passes EVAL_KEY to auto-fix-agent.* (V31)"
  else
    check_fail "self-repair job does not pass EVAL_KEY to the 'Autonomous self-repair' step's env (V31, Section 4.0e)"
  fi
fi

# 🔴 No script may resolve an evidence file by wildcard/recursive search — every EVAL_KEY-addressed
#    resolution point is available (V31, Section 4.0e). find/Get-ChildItem over reports/eval-evidence/
#    silently adopts the FIRST match across every work unit's own committed evidence.
for f in tests/.evals/scripts/auto-fix-agent.sh tests/.evals/scripts/auto-fix-agent.ps1; do
  [ -f "$f" ] || continue
  hit="$(grep -nE 'find[[:space:]]+reports/eval-evidence|Get-ChildItem[^|]*reports/eval-evidence' "$f" || true)"
  if [ -n "$hit" ]; then
    echo "$hit"
    check_fail "${f} resolves evidence via a wildcard/recursive search instead of an EVAL_KEY-addressed path (V31, Section 4.0e)"
  else
    check_ok "${f} resolves evidence by EVAL_KEY path, not by search (V31)"
  fi
done

# ── Slot-equality (Section 3.1) is now STRUCTURAL under #7a, not a runtime check: both jobs call the
#    SAME fixed steps (Read manifest, Setup Node/Python/Java/Go/.NET, Install dependencies) — there is
#    no per-repo generated text left that could textually diverge between them. V27's structural-fidelity
#    check is what still catches a step missing from either job.

# ── V-dryrun: the scripts actually run on the current branch (catches path/flag/mkdir bugs) ──
if [ -n "$BASE_SHA" ] && [ -f "tests/.evals/scripts/run-static-evals.sh" ]; then
  echo "  dry-run: run-static-evals.sh against ${BASE_SHA}"
  bash tests/.evals/scripts/run-static-evals.sh "$BASE_SHA" >/tmp/vp_static.out 2>&1
  drc=$?
  # A real finding (exit 1) is a VALID outcome — it proves the script works. Only a crash-class exit
  # (2) or a missing-dir style error is a validation failure.
  if [ "$drc" -eq 2 ]; then check_fail "run-static-evals crashed (exit 2): $(tail -n3 /tmp/vp_static.out)";
  else check_ok "run-static-evals executed (exit ${drc} — a real finding is a valid outcome)"; fi
else note "dry-run skipped — pass a base sha to enable (recommended before commit)"; fi

note "Not mechanically checked here — verify manually before commit: V3 (every repo script/lockfile the manifest resolved to actually exists — Section 1's own read-never-assume rule), V5 (every secrets.* the workflow references is named in the generation announcement), V17 (the eval.json/judge evidence round trip — needs live judge credentials to exercise), V21 (tool-install retry with an OCI-container fallback, Section 2.4.1)."

echo ""
if [ "$rc" -ne 0 ]; then
  echo "validate-pipeline: FAILED — the pipeline is NOT committed. Fix the findings above and re-run."
else
  echo "validate-pipeline: PASSED — safe to commit."
fi
exit "$rc"
