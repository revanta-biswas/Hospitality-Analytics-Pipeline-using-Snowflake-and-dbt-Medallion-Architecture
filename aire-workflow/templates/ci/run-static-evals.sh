#!/usr/bin/env bash
# run-static-evals.sh — D1–D7 static eval gate, DELTA-SCOPED against a base ref.
#
# 🔴 The local Static Eval Gate AND CI both call THIS script. The diff logic lives here ONCE so the two
#    environments cannot drift (common/ci-pipeline-generation.md Section 4.0b, common/eval-framework.md
#    Section 2.2). It reads the `ci` manifest and `thresholds` from tests/.evals/config.json — nothing is
#    hardcoded here that also lives in the config.
#
# Contract:
#   arg1  BASE_SHA — the ref to diff against (the PR base, or the local branch checkpoint)
#   Reads tests/.evals/config.json: ci.tools, ci.sourcePaths, thresholds.*
#   Runs each tool against BASE and HEAD, matches findings on (rule-id, file, message) — NEVER line
#   number — counts only findings NEW-vs-baseline AND on a changed file, writes a machine-readable
#   per-gate summary, and exits non-zero ONLY on a real delta breach.
#
# 🔴 NO STUBS (Section 5.0): a gate that cannot run writes status ERROR and this script exits non-zero.
#    It NEVER fabricates PASS or an untrue N/A. N/A is earned and its reason must be true.
set -uo pipefail

BASE_SHA="${1:-}"
COVERAGE_ONLY=0
if [ "${2:-}" = "--coverage-only" ]; then COVERAGE_ONLY=1; fi
CONFIG="tests/.evals/config.json"
EVAL_KEY="${EVAL_KEY:-local}"
EVIDENCE_DIR="reports/eval-evidence/${EVAL_KEY}"
STATIC_DIR="${EVIDENCE_DIR}/static"

# 🔴 mkdir -p every directory before writing (Section 5.3, V12). A clean CI checkout has none of these.
mkdir -p "${STATIC_DIR}/baseline" "${EVIDENCE_DIR}/judge" tests/.evals/_run

fail() { echo "run-static-evals: ERROR: $*" >&2; }

# 🔴 lib-manifest.sh is the ONE place build_merged_manifest/resolve_and_verify_root/root_touched live
#    (common/ci-pipeline-generation.md Section 4.0f/4.0d/4.0g) — sourced here and by
#    ci-manifest-runner.sh, never re-implemented in either file.
LIB_MANIFEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-manifest.sh
source "${LIB_MANIFEST_DIR}/lib-manifest.sh"

if [ -z "$BASE_SHA" ]; then
  fail "no BASE_SHA supplied — cannot compute a delta"
  exit 2
fi
if [ ! -f "$CONFIG" ]; then
  fail "$CONFIG missing — cannot resolve the manifest or thresholds"
  exit 2
fi
# 🔴 THE DELTA IS COMPUTED BY COREUTILS - IF ONE IS MISSING, EVERY GATE SILENTLY PASSES.
#    The verdict line is:  new=$(comm -13 <(sort -u "$base") <(sort -u "$head") | wc -l | tr -d ' ')
#    With `comm` absent the substitution yields empty, ${new:-0} becomes 0, and a real NEW finding is
#    reported as PASS. Same for `sort` (an unsorted input makes comm's output meaningless rather than
#    empty - arguably worse, because it is plausible). These are always present on ubuntu-latest, but
#    NOTHING in this framework installs them, and a self-hosted or minimal-container runner (alpine
#    without coreutils, a slim busybox image) is a supported deployment target. Verified failure mode:
#    with comm missing, an injected new finding scores new=0 -> PASS.
#    Checked ONCE, up front, loudly - never per-gate, and never degraded to a warning.
for _bin in comm sort awk tr wc git; do
  if ! command -v "$_bin" >/dev/null 2>&1; then
    echo "run-static-evals: ERROR: required utility '${_bin}' is not installed. The delta computation depends on it, and without it every gate would silently report PASS. Install coreutils/gawk on this runner." >&2
    exit 2
  fi
done

if ! command -v jq >/dev/null 2>&1; then
  fail "jq not installed — required to read the manifest"
  exit 2
fi

# ── THE MERGED MANIFEST (common/ci-pipeline-generation.md Section 4.0f) — config.json's own ci.roots[]
#    (if any) UNIONED with every tests/.evals/ci-manifest.d/*.json fragment, filename-sorted. A fragment
#    is written ONLY by the work unit that established it, at the end of ITS OWN run — reconciliation
#    never edits config.json directly, so two parallel work units never touch the same file. Every
#    consumer in this script reads THIS merged view, never config.json's ci.roots alone, or a story's
#    own stack facts (added after config.json was generated) would silently never be seen.
MANIFEST_DIR="tests/.evals/ci-manifest.d"
MERGED_MANIFEST="tests/.evals/_run/merged-manifest.json"
build_merged_manifest "$CONFIG" "$MANIFEST_DIR" "$MERGED_MANIFEST"

# ── Read the manifest (single source of truth). Portable array fill (no mapfile — bash 3.2 lacks it). ──
# 🔴 ci.roots[] (common/eval-framework.md Section 1.1) is the current schema — one entry per stack root,
#    each carrying its own tools/sourcePaths. A legacy manifest (no roots[]) falls back to the old flat
#    ci.tools/ci.sourcePaths — never migrated in place, per Section 1's "if it already exists, use it
#    AS-IS" rule. Either way TOOLS/SOURCES end up as the MERGED (union, deduped) view across every root,
#    since D3/D7 below scan by path argument, not by cwd, and take the whole set at once.
HAS_ROOTS=$(jq -r 'length > 0' "$MERGED_MANIFEST")
if [ "$HAS_ROOTS" = "true" ]; then
  TOOLS=(); while IFS= read -r line; do TOOLS+=("$line"); done < <(jq -r '[.[].tools[]?] | unique[]' "$MERGED_MANIFEST" | tr -d '\r')
  SOURCES=(); while IFS= read -r line; do SOURCES+=("$line"); done < <(jq -r '[.[].sourcePaths[]?] | unique[]' "$MERGED_MANIFEST" | tr -d '\r')
else
  TOOLS=(); while IFS= read -r line; do TOOLS+=("$line"); done < <(jq -r '.ci.tools[]?' "$CONFIG" | tr -d '\r')
  SOURCES=(); while IFS= read -r line; do SOURCES+=("$line"); done < <(jq -r '.ci.sourcePaths[]?' "$CONFIG" | tr -d '\r')
fi
[ "${#SOURCES[@]}" -eq 0 ] && SOURCES=("src")
SEMGREP_CRIT=$(jq -r '.thresholds.semgrepFindingsAllowed.critical // 0' "$CONFIG")
SEMGREP_HIGH=$(jq -r '.thresholds.semgrepFindingsAllowed.high // 0' "$CONFIG")
SECRETS_ALLOWED=$(jq -r '.thresholds.secretFindingsAllowed // 0' "$CONFIG")

# 🔴 D5 AND D6 THRESHOLDS MUST BE REACHABLE BY THE GATE COMMAND.
#    `disallowedLicenses` and `maxCyclomaticComplexity` were read by NOTHING - nine mentions across the
#    rule files and zero consumers in any script. delta_diff's verdict is purely "are there new findings
#    vs baseline", so D5 failed on ANY newly-introduced licence (not just a disallowed one) and D6 failed
#    on ANY newly-introduced complexity finding (not just one above the cap). The configured numbers were
#    decorative.
#    They are exported here rather than baked into the resolved command at generation time because
#    eval-framework.md Section 1 is explicit: "thresholds is the ONLY place a number lives" - a value
#    copied into a manifest command string would be a second source that drifts the moment one changes.
#    Section 3's D5/D6 rows show each stack's command referencing these; V35 enforces that it does.
DISALLOWED_LICENSES=$(jq -r '.thresholds.disallowedLicenses // [] | join(",")' "$CONFIG")
MAX_COMPLEXITY=$(jq -r '.thresholds.maxCyclomaticComplexity // 0' "$CONFIG")
export AIRE_DISALLOWED_LICENSES="$DISALLOWED_LICENSES"
export AIRE_MAX_CYCLOMATIC_COMPLEXITY="$MAX_COMPLEXITY"

# 🔴 CHANGED must be set BEFORE any root_touched() call — that function (lib-manifest.sh, Section 4.0g)
#    reads it as a global. Decided fresh on every run from the REAL diff, never from a plan or a guess.
# 🔴 AN UNRESOLVABLE BASE_SHA MUST BE A PIPELINE DEFECT, NEVER AN EMPTY DIFF.
#    `git diff ... 2>/dev/null || true` swallowed both stderr and the exit code, so a shallow clone, a
#    force-push, or a missing merge base produced an EMPTY changed-file set. Every root then failed
#    root_touched, every gate reported "N/A - no changed files under this root", and the job exited 0:
#    a full PASS with nothing installed, built, tested or gated. The dependency closure cannot help
#    either, because it terminates on an empty CHANGED too.
#    An empty diff is legitimate (the zero-diff smoke PR); a FAILED diff is not. Tell them apart.
_diff_rc=0
CHANGED="$(git diff --name-only "${BASE_SHA}...HEAD" 2>"${RUN_DIR:-tests/.evals/_run}/git-diff.err")" || _diff_rc=$?
if [ "$_diff_rc" -ne 0 ]; then
  echo "run-static-evals: ERROR: PIPELINE DEFECT — 'git diff --name-only ${BASE_SHA}...HEAD' failed (exit ${_diff_rc}). The changed-file set could not be computed, so every gate would report 'no changed files' and the job would PASS having measured nothing. Most likely a shallow clone (needs fetch-depth: 0), a force-push, or an unreachable merge base. $(head -n 1 "${RUN_DIR:-tests/.evals/_run}/git-diff.err" 2>/dev/null)" >&2
  exit 2
fi

RESULT_JSON="${STATIC_DIR}/static-results.json"
RAW_MULTI="${RESULT_JSON}.gates.rootraw"
# 🔴 Only the D1–D7 pass starts a fresh gates file. The --coverage-only pass (run later, after the
#    coverage report exists) APPENDS its one line to the SAME file so both invocations land in the
#    same eval.json — never truncate here when only computing the coverage gate.
if [ "$COVERAGE_ONLY" -eq 0 ]; then
  : > "$RESULT_JSON.gates"   # one "gate<TAB>status<TAB>reason" line per gate; merged by run-evals
  : > "$RAW_MULTI"           # scratch: one "gate<TAB>root<TAB>status<TAB>reason" line per delta_diff call
fi

overall_fail=0
record() { # id  status(PASS|FAIL|ERROR|N/A)  reason
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$RESULT_JSON.gates"
  case "$2" in FAIL|ERROR) overall_fail=1 ;; esac
}

# 🔴 record_multi_root — used ONLY by delta_diff, which the generator may call more than once for the
#    SAME gate id when ci.roots[] has more than one root resolving that gate (a monorepo with two
#    stacks that both lint, say). A bare record() there would collide: two calls append two lines for
#    the SAME gate id, and whatever collapses tab-separated lines into eval.json's `gates` object (a
#    dict keyed by gate id) would silently keep only one of them — worse, it could keep a PASS from one
#    root over a FAIL from another. This writes to a per-root scratch file instead; collapse_multi_root
#    (below) aggregates it into exactly ONE real record() call per gate id, worst-status-wins, once every
#    root that resolves that gate has reported.
record_multi_root() { # gate  root  status  reason
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$RAW_MULTI"
}

collapse_multi_root() {
  [ -s "$RAW_MULTI" ] || return 0
  local gates
  gates="$(cut -f1 "$RAW_MULTI" | sort -u)"
  local g
  while IFS= read -r g; do
    [ -z "$g" ] && continue
    local worst="N/A" reasons="" line status root reason
    while IFS=$'\t' read -r gate root status reason; do
      [ "$gate" = "$g" ] || continue
      reasons="${reasons}${reasons:+; }[${root}] ${reason}"
      case "$status" in
        ERROR) worst="ERROR" ;;
        FAIL) [ "$worst" != "ERROR" ] && worst="FAIL" ;;
        PASS) [ "$worst" != "ERROR" ] && [ "$worst" != "FAIL" ] && worst="PASS" ;;
        N/A) [ "$worst" = "N/A" ] || : ;;
      esac
    done < "$RAW_MULTI"
    record "$g" "$worst" "$reasons"
  done <<< "$gates"
}

has_tool() { for t in "${TOOLS[@]}"; do [ "$t" = "$1" ] && return 0; done; return 1; }

# 🔴 D1–D7 run only on the normal pass. The --coverage-only pass runs later in the pipeline (after
#    "unit + coverage" has produced the report) purely to compute the coverage gate — re-running
#    semgrep/gitleaks/D1-D2/D4-D6 a second time here would be wasted work, not a correctness issue,
#    but it's also wrong: it would re-diff against a tree state that has since moved (checkout cycles
#    inside delta_diff), for no benefit.
if [ "$COVERAGE_ONLY" -eq 0 ]; then

# ── D3 SAST — semgrep with its NATIVE baseline flag (only NEW findings since BASE_SHA) ──
if has_tool semgrep; then
  if command -v semgrep >/dev/null 2>&1; then
    out="${STATIC_DIR}/semgrep-delta.json"
    if semgrep --config auto --baseline-commit "$BASE_SHA" --json --quiet "${SOURCES[@]}" > "$out" 2>/dev/null; then
      crit=$(jq '[.results[]? | select(.extra.severity=="ERROR")] | length' "$out")
      high=$(jq '[.results[]? | select(.extra.severity=="WARNING")] | length' "$out")
      if [ "$crit" -gt "$SEMGREP_CRIT" ] || [ "$high" -gt "$SEMGREP_HIGH" ]; then
        record D3_sast FAIL "new semgrep findings: ${crit} critical, ${high} high (allowed ${SEMGREP_CRIT}/${SEMGREP_HIGH})"
      else
        record D3_sast PASS "no new findings above threshold"
      fi
    else
      record D3_sast ERROR "semgrep run failed"
    fi
  else
    record D3_sast ERROR "semgrep in manifest but not installed"
  fi
else
  # 🔴 NEVER LEAVE A GATE UNRECORDED. Before this, a tool absent from ci.roots[].tools skipped the whole
  #    block and wrote NOTHING — D3_sast simply did not appear in eval.json. Section 4.0c.3 is explicit:
  #    "The gates block is complete or it is wrong." An absent gate is not a passing gate; it is an
  #    unmeasured one, and it must say so in the artifact a human reads.
  record D3_sast ERROR "semgrep is not listed in any ci.roots[].tools — D3 static security analysis was NOT performed. semgrep is stack-agnostic and applies to every language, so this is a manifest gap, not an inapplicable gate. Add it to the owning root's tools + toolInstallCommands."
fi

# ── D7 Secrets — gitleaks scoped to the new commits only ──
if has_tool gitleaks; then
  if command -v gitleaks >/dev/null 2>&1; then
    out="${STATIC_DIR}/gitleaks-delta.json"
    gitleaks detect --no-banner --redact --report-format json --report-path "$out" \
      --log-opts "${BASE_SHA}..HEAD" >/dev/null 2>&1 || true
    n=$( [ -f "$out" ] && jq 'length' "$out" 2>/dev/null || echo 0 )
    if [ "${n:-0}" -gt "$SECRETS_ALLOWED" ]; then
      record D7_secrets FAIL "${n} secret finding(s) in new commits (allowed ${SECRETS_ALLOWED})"
    else
      record D7_secrets PASS "no new secrets"
    fi
  else
    record D7_secrets ERROR "gitleaks in manifest but not installed"
  fi
else
  # 🔴 Same rule as D3 above: unrecorded is not the same as passing.
  record D7_secrets ERROR "gitleaks is not listed in any ci.roots[].tools — D7 secret scanning was NOT performed. gitleaks is stack-agnostic, so this is a manifest gap, not an inapplicable gate. Add it to the owning root's tools + toolInstallCommands."
fi

fi   # end: D3/D7 run only on the normal (non --coverage-only) pass

# ── D1 Lint · D2 Types · D4 Deps · D5 Licences · D6 Complexity ──
# These have no universal native baseline flag. The BASE side is the baseline dev-implement.md Step 4.6
# already captured and COMMITTED to this story branch, once, before any code was generated — delta_diff
# below reuses that committed file directly instead of re-deriving it. The generator resolves the
# concrete tool invocation per stack (Section 3) and appends it below via the delta_diff helper. If the
# manifest lists the tool but no invocation was resolved, that is an ERROR — never a silent skip.
# Captured once, before any stash/checkout cycle, so every restore targets a known-good ref — never
# `checkout -`, whose target can drift once the tree has been detached more than once in this script.
ORIG_REF="$(git symbolic-ref -q --short HEAD || git rev-parse HEAD)"

delta_diff() { # gate_id  "cmd producing 'rule\tfile\tmessage' lines"  [root]  [markerFile]
  # 🔴 root/markerFile (default "." / none) come straight from the OWNING ci.roots[] entry the generator
  #    resolved this gate's command from — never re-detected here. Both the baseline and head capture
  #    run the SAME command from the SAME verified root, in a subshell, so this script's own cwd (and
  #    every git command after this function returns) is never disturbed (Section 4.0d).
  local gate="$1" cmd="$2" root="${3:-.}" marker="${4:-}"
  local base head stashed=0 before_stash after_stash base_ok checkout_err abs_root abs_root_base root_tag
  local base_rc=0 base_crashed=0
  # 🔴 Root-scoped file names — root_tag sanitizes "/" so two roots resolving the SAME gate id (a
  #    monorepo with two lintable stacks) never collide on baseline/head paths the way a bare
  #    "${gate}.txt" would. This is what makes multi-root-per-gate correctness possible at all; without
  #    it, the second root's head capture would diff against the FIRST root's baseline and every finding
  #    would look "new" or "gone" for reasons that have nothing to do with the actual code.
  root_tag="$(printf '%s' "$root" | tr '/' '_')"
  base="${STATIC_DIR}/baseline/${gate}__${root_tag}.txt"
  head="${STATIC_DIR}/${gate}__${root_tag}-head.txt"

  # 🔴 DIFF-SCOPED EXECUTION (Section 4.0g) — a root this PR never touched can only ever produce zero
  # NEW findings (baseline would equal head), so skip running its tool at all rather than pay for it and
  # get the same PASS. N/A here is EARNED, not a silent omission — collapse_multi_root still writes one
  # real line for this gate id, and a root genuinely touched by another root's fragment still runs.
  if ! root_touched "$root"; then
    record_multi_root "$gate" "$root" N/A "no changed files under root '${root}' for this PR (diff-scoped)"
    return
  fi

  abs_root="$(resolve_and_verify_root "$root" "$marker")" || {
    record_multi_root "$gate" "$root" ERROR "MANIFEST DEFECT — root '${root}' failed verification (see stderr) — never a code defect, fix ci.roots in tests/.evals/config.json"
    return
  }

  # 🔴 THE TOOL MUST EXIST BEFORE ITS GATE CAN MEAN ANYTHING (finding: silent PASS on a missing tool).
  #    Both passes below redirect stderr to /dev/null and swallow the exit status. With the tool absent
  #    that produced an EMPTY baseline and an EMPTY head run; diffing empty against empty found zero new
  #    findings, so D1_lint / D2_types / D6_complexity recorded PASS having measured NOTHING. Only
  #    semgrep and gitleaks were ever guarded. On any stack with no resolvable linter/type-checker/
  #    complexity tool — Rust, Ruby, PHP, Scala, C/C++ — that meant three of seven static gates went
  #    permanently, invisibly green. A gate that cannot fail is not a gate (Section 5.0).
  local cmd_bin
  cmd_bin="$(printf '%s\n' "$cmd" | awk '{print $1}')"
  case "$cmd_bin" in
    ''|*=*|'$'*) : ;;   # empty, env-assignment-prefixed, or variable-headed: no resolvable binary name
    *)
      # 🔴 RESOLVE FROM THE ROOT, NOT FROM THE SCRIPT'S CWD. Section 3.0a MANDATES the repo-committed
      #    wrapper ("Resolve ./mvnw, never mvn, whenever the wrapper is present"), and a wrapper is
      #    root-relative: `command -v ./mvnw` from the repo root returns 1 for a wrapper that lives at
      #    backend/mvnw and works perfectly. Checking from the wrong directory turned the guard into a
      #    false ERROR on exactly the command shape the framework requires — every Java/Gradle monorepo
      #    PR would have hard-failed D1/D2/D6 from its first run, and the obvious human "fix" (rewrite
      #    ./mvnw to bare mvn) silently un-pins the build. Same reasoning for ./node_modules/.bin/*.
      if ! ( cd "$abs_root" && command -v "$cmd_bin" >/dev/null 2>&1 ); then
        record_multi_root "$gate" "$root" ERROR "tool '${cmd_bin}' for gate ${gate} is not installed on this runner — the gate cannot run. This is an ERROR, never a silent PASS and never an N/A: install it via this root's ci.roots[].toolInstallCommands, or remove the gate from ci.gates deliberately."
        return
      fi
      ;;
  esac

  # 🔴 REUSE the already-committed baseline when one exists. dev-implement.md Step 4.6 captures this
  #    EXACT file once, on the story branch, BEFORE any code is generated, and commits it — making
  #    reports/eval-evidence/<key>/static/baseline/ a TRACKED path in this branch's history, never
  #    disposable scratch space. Recomputing it here via a BASE_SHA checkout writes an untracked file
  #    at that same tracked path while displaced at BASE_SHA; returning to ORIG_REF then makes git
  #    REFUSE the checkout ("untracked working tree file would be overwritten by checkout") because
  #    the committed version is still sitting there — a real FATAL abort, observed in CI. Trust the
  #    committed baseline and skip the whole checkout dance in that case; only recompute via checkout
  #    when no baseline is committed yet (the pre-story epic-level smoke test, which has no story
  #    branch to have captured one — ci-pipeline-generation.md Section 4.0.6).
  if [ ! -f "$base" ]; then
    before_stash="$(git stash list | wc -l | tr -d ' ')"
    git stash push -q --include-untracked 2>/dev/null || true
    after_stash="$(git stash list | wc -l | tr -d ' ')"
    [ "$after_stash" -gt "$before_stash" ] && stashed=1

    checkout_err="$(git checkout -q "$BASE_SHA" 2>&1)"
    if [ $? -ne 0 ]; then
      record_multi_root "$gate" "$root" ERROR "cannot checkout base ref: ${checkout_err}"
      if [ "$stashed" -eq 1 ] && ! git stash pop -q 2>/dev/null; then
        fail "FATAL: could not restore stash after a failed checkout — working tree left dirty. Aborting rather than running further gates or stages against a broken tree."
        exit 3
      fi
      return
    fi

    # 🔴 Defensive re-mkdir: the checkout above can leave this untracked directory gone by the time we
    #    write to it. Without this, the write below silently fails, sort/comm then read a missing file
    #    as an EMPTY baseline, and every pre-existing finding gets miscounted as "new" — a fabricated
    #    FAIL from a capture that never actually happened (violates Section 5.0 NO STUBS).
    mkdir -p "${STATIC_DIR}/baseline"
    # Re-resolve abs_root AFTER the base-ref checkout — same relative root, but re-verify the marker
    # file still exists at that historical commit (a root can legitimately not exist yet at an older
    # base ref, e.g. a story that itself introduces a new stack root — that is a true, earned N/A for
    # the baseline side, never a Manifest defect at HEAD's own state, so its stderr is suppressed here).
    if abs_root_base="$(resolve_and_verify_root "$root" "$marker" 2>/dev/null)"; then
      # 🔴 The BASE pass gets the SAME treatment as the head pass. It used to swallow the exit status
      #    entirely (`|| true`), so a tool that crashed at BASE_SHA wrote an empty baseline while HEAD
      #    ran fine - and every PRE-EXISTING finding then counted as NEW, fabricating a blocking FAIL.
      #    Reachable whenever the story's own diff adds the tool's config file (.eslintrc, mypy.ini).
      base_rc=0
      ( cd "$abs_root_base" && eval "$cmd" ) > "$base" 2>"${base}.err" || base_rc=$?
      if [ "$base_rc" -ne 0 ] && [ ! -s "$base" ]; then
        base_crashed=1
      fi
    else
      : > "$base"   # root genuinely absent at the baseline ref — empty baseline, every HEAD finding counts as new (correct: nothing pre-existed)
    fi
    base_ok=1
    [ -f "$base" ] || base_ok=0

    checkout_err="$(git checkout -q "$ORIG_REF" 2>&1)"
    if [ $? -ne 0 ]; then
      fail "FATAL: could not return to ${ORIG_REF} after checking out the base ref: ${checkout_err}. Aborting rather than running further gates or stages against a broken tree."
      exit 3
    fi

    if [ "$stashed" -eq 1 ]; then
      checkout_err="$(git stash pop -q 2>&1)"
      if [ $? -ne 0 ]; then
        fail "FATAL: git stash pop failed (likely a conflict): ${checkout_err}. Working tree left dirty. Aborting rather than running further gates or stages against a broken tree."
        exit 3
      fi
    fi

    if [ "$base_crashed" -eq 1 ]; then
      record_multi_root "$gate" "$root" ERROR "gate ${gate} command failed at the BASE ref on root '${root}' (exit ${base_rc}) with no output — the baseline could not be measured, so every pre-existing finding would be miscounted as NEW. Never diffed against an empty baseline."
      return
    fi
    if [ "$base_ok" -eq 0 ]; then
      record_multi_root "$gate" "$root" ERROR "baseline capture failed — ${base} was not written while checked out at ${BASE_SHA} (cannot compute a delta from a missing baseline, Section 5.0)"
      return
    fi
  fi

  mkdir -p "${STATIC_DIR}"
  # 🔴 A linter exits NON-ZERO when it finds problems, so a non-zero status alone is not an error.
  #    The crash signature is: non-zero status AND no output AND something on stderr. That is a tool
  #    that blew up (bad config, missing plugin, unsupported flag) — it must ERROR, not diff to PASS.
  local head_rc=0
  ( cd "$abs_root" && eval "$cmd" ) > "$head" 2>"${head}.err" || head_rc=$?
  # 🔴 THE CRASH SIGNATURE IS "NON-ZERO AND NO OUTPUT" - stderr is NOT required.
  #    Requiring non-empty stderr left two live bypasses, both verified: a command that suppresses its
  #    own stderr (`... 2>/dev/null`), and any tool that logs to STDOUT behind a filter - which is the
  #    normal Maven/Gradle shape (`./mvnw ... | grep ... | sed ...`), where a plugin-download failure
  #    produces rc=1 with empty stdout AND empty stderr and was recorded PASS. A gate that produced no
  #    findings AND exited non-zero has not "found nothing"; it did not run.
  if [ "$head_rc" -ne 0 ] && [ ! -s "$head" ]; then
    record_multi_root "$gate" "$root" ERROR "gate ${gate} command failed on root '${root}' (exit ${head_rc}) with no output — the tool did not run. First line of stderr: $(head -n 1 "${head}.err" 2>/dev/null || echo '(stderr empty or suppressed)')"
    return
  fi
  if [ ! -f "$head" ]; then
    record_multi_root "$gate" "$root" ERROR "head capture failed — ${head} was not written at ${ORIG_REF}"
    return
  fi
  # NEW findings = in head, not in base (match on the whole rule\tfile\tmessage tuple, not line no.)
  # 🔴 ZERO OUTPUT AT BOTH ENDS IS AMBIGUOUS - and it is the shape of the one hole this gate cannot
  #    close by itself. A tool that exits 0 having scanned NOTHING (an ignore pattern covering the
  #    changed paths, a glob matching no files, a misconfigured include root) is indistinguishable
  #    from a tool that scanned properly and found nothing wrong: both give empty base, empty head,
  #    zero new findings, PASS. No missing binary and no crash, so neither the presence check nor the
  #    crash check fires. It is the most common real-world cause of a lint gate measuring zero files.
  #    This cannot be resolved from inside the diff, so it is made VISIBLE instead of silently clean:
  #    the gate still passes (failing every genuinely-clean root would be worse), but it is recorded
  #    as an explicitly qualified pass and listed in zero-output-gates.txt for the scorecard.
  #    🔴 The real defence is generation-time: V9 requires each gate be PROVEN able to fail before the
  #    pipeline is committed (Section 4.0.1). Treat an entry here as a prompt to re-check that proof.
  if [ ! -s "$base" ] && [ ! -s "$head" ]; then
    mkdir -p "${RUN_DIR:-tests/.evals/_run}"
    printf '%s\t%s\n' "$gate" "$root" >> "${RUN_DIR:-tests/.evals/_run}/zero-output-gates.txt"
    record_multi_root "$gate" "$root" PASS "no findings at base or head — QUALIFIED: the tool produced zero output at BOTH ends, so 'clean' and 'scanned nothing' are indistinguishable here. Confirm this gate's command actually covers root '${root}' sourcePaths (V9: prove it can fail)."
    return
  fi

  local new
  new=$(comm -13 <(sort -u "$base") <(sort -u "$head") | wc -l | tr -d ' ')
  if [ "${new:-0}" -gt 0 ]; then
    record_multi_root "$gate" "$root" FAIL "${new} new finding(s) vs baseline on changed files"
  else
    record_multi_root "$gate" "$root" PASS "no new findings vs baseline"
  fi
}
# ── unitCoverage — delta-scoped against the coverage report(s) the "unit + coverage" step already
#    produced (Section 4.0b: run-static-evals owns this verdict; the raw test command never applies
#    --cov-fail-under itself). Supports cobertura (pytest-cov, dotnet coverlet) and lcov (istanbul/
#    c8/vitest). Anything else, or a missing manifest field, is a real ERROR — never a silent N/A.
#
#    🔴 MULTI-REPORT: a full-stack project has separate backend + frontend coverage reports. Configure
#    `ci.coverageReports`: an array of {path, format, sourcePaths}; each changed file is matched to
#    the report whose sourcePaths prefix owns it, and scored against that report specifically. A
#    changed file matching no report's sourcePaths is skipped (not every changed file is coverable —
#    e.g. docs, config). `ci.coverageReportPath`/`ci.coverageFormat` (single pair, scored against the
#    whole `ci.sourcePaths`) still works unmodified when `coverageReports` is absent — back-compat. ──
coverage_delta() {
  local min changed hit=0 found=0 f had_error=0 unmatched_files=""
  min=$(jq -r '.thresholds.unitTestCoverageMin // 90' "$CONFIG")

  # 🔴 Preference order: the MERGED ci.roots[] view (config.json + every ci-manifest.d/*.json fragment,
  #    Section 4.0f — each entry carrying its own coverageReportPath, relative to that root, plus
  #    format/sourcePaths) → legacy ci.coverageReports[] (no root concept, reports already at a
  #    repo-root-relative path) → legacy single coverageReportPath/coverageFormat. REPORT_ROOTS defaults
  #    to "." for the two legacy forms — their reports were never root-relative, so normalization below
  #    is a no-op for them and the old fuzzy fallback still applies.
  local roots_report_count
  roots_report_count=$(jq -r 'map(select(.coverageReportPath and .coverageFormat)) | length' "$MERGED_MANIFEST")
  local report_count
  report_count=$(jq -r '.ci.coverageReports // [] | length' "$CONFIG")

  local -a REPORT_PATHS=() REPORT_FORMATS=() REPORT_SOURCEPATHS=() REPORT_ROOTS=()
  if [ "$roots_report_count" -gt 0 ]; then
    while IFS=$'\t' read -r rp rf rs rr; do
      REPORT_PATHS+=("$rp"); REPORT_FORMATS+=("$rf"); REPORT_SOURCEPATHS+=("$rs"); REPORT_ROOTS+=("$rr")
    done < <(jq -r 'map(select(.coverageReportPath and .coverageFormat)) | .[]
                    | [.coverageReportPath, .coverageFormat, ((.sourcePaths // []) | join("|")), (.root // ".")] | @tsv' "$MERGED_MANIFEST" | tr -d '\r')
  elif [ "$report_count" -gt 0 ]; then
    while IFS=$'\t' read -r rp rf rs; do
      REPORT_PATHS+=("$rp"); REPORT_FORMATS+=("$rf"); REPORT_SOURCEPATHS+=("$rs"); REPORT_ROOTS+=(".")
    done < <(jq -r '.ci.coverageReports[] | [.path, .format, (.sourcePaths // [] | join("|"))] | @tsv' "$CONFIG" | tr -d '\r')
  else
    local single_path single_format
    single_path=$(jq -r '.ci.coverageReportPath // ""' "$CONFIG")
    single_format=$(jq -r '.ci.coverageFormat // ""' "$CONFIG")
    if [ -z "$single_path" ] || [ -z "$single_format" ]; then
      record unitCoverage ERROR "neither ci.roots[].coverageReportPath, ci.coverageReports, nor ci.coverageReportPath/ci.coverageFormat is set in the manifest — cannot compute the delta-scoped coverage gate (Section 4.0b)"
      return
    fi
    REPORT_PATHS=("$single_path"); REPORT_FORMATS=("$single_format"); REPORT_ROOTS=(".")
    local joined; joined=$(IFS='|'; echo "${SOURCES[*]}")
    REPORT_SOURCEPATHS=("$joined")
  fi

  if ! command -v python3 >/dev/null 2>&1 && printf '%s\n' "${REPORT_FORMATS[@]}" | grep -qE '^(cobertura|jacoco)$'; then
    record unitCoverage ERROR "ci.roots[].coverageFormat cobertura/jacoco requires python3, which is not installed"
    return
  fi

  changed="$(git diff --name-only "${BASE_SHA}...HEAD" -- "${SOURCES[@]}" 2>/dev/null || true)"
  if [ -z "$changed" ]; then
    record unitCoverage PASS "no changed files under ${SOURCES[*]} — threshold vacuously satisfied"
    return
  fi

  while IFS= read -r f; do
    [ -z "$f" ] && continue

    local matched_idx=-1 i
    for i in "${!REPORT_SOURCEPATHS[@]}"; do
      local sp_joined="${REPORT_SOURCEPATHS[$i]}" sp matched=0
      IFS='|' read -ra sp_arr <<< "$sp_joined"
      for sp in "${sp_arr[@]}"; do
        case "$f" in "$sp"/*|"$sp") matched=1; break ;; esac
      done
      if [ "$matched" -eq 1 ]; then matched_idx="$i"; break; fi
    done
    [ "$matched_idx" -eq -1 ] && continue   # not owned by any configured report — not every changed file is coverable

    local rp="${REPORT_PATHS[$matched_idx]}" rfmt="${REPORT_FORMATS[$matched_idx]}" rroot="${REPORT_ROOTS[$matched_idx]:-.}" lh="" lf="" real_rp
    # 🔴 rp is documented as relative to `rroot` (eval-framework.md Section 1.1) for a ci.roots[]-sourced
    #    entry; the two legacy forms (rroot always ".") already store a repo-root-relative path, so this
    #    is a no-op for them.
    if [ "$rroot" = "." ]; then real_rp="$rp"; else real_rp="${rroot%/}/${rp}"; fi
    if [ ! -f "$real_rp" ]; then
      fail "unitCoverage: coverage report not found at ${real_rp} (root='${rroot}', reportPath='${rp}') — needed for changed file ${f}"
      had_error=1
      continue
    fi

    case "$rfmt" in
      cobertura|jacoco)
        # 🔴 ONE python extractor for both XML coverage schemas. JaCoCo XML is NOT Cobertura XML -
        #    Cobertura nests <class filename=...><lines><line hits=...>, JaCoCo nests
        #    <package name="com/acme"><sourcefile name="Money.java"><line nr= mi= ci=>. Treating them as
        #    one format is why `mvn test jacoco:report` - the command Section 3 itself prescribes for
        #    Java - could never be read, so the coverage gate was unreachable on every Java repo.
        read -r lh lf < <(REPORT_PATH="$real_rp" TARGET_FILE="$f" TARGET_ROOT="$rroot" REPORT_FMT="$rfmt" python3 - <<'PYEOF'
import os, xml.etree.ElementTree as ET

target = os.environ["TARGET_FILE"]
rroot  = os.environ["TARGET_ROOT"]
fmt    = os.environ["REPORT_FMT"]

def candidates(fn):
    """Every repo-root-relative path this report entry could plausibly denote."""
    fn = fn.replace("\\", "/")
    while fn.startswith("./"):
        fn = fn[2:]
    out = [fn]
    if rroot != ".":
        out.append(rroot.rstrip("/") + "/" + fn)
    return out

def matches(fn):
    # 🔴 Match rule, fixed. EXACT after root-normalisation, OR the report path ENDS WITH the target's
    #    full repo-relative path. The endswith direction is deliberately ONE-WAY: a report entry may be
    #    longer than the target (an ABSOLUTE path like /home/runner/work/repo/src/app.ts, or a Go/Java
    #    import-style path), never shorter. The reverse direction - target ends with the report entry -
    #    is what let a bare basename match the wrong module in a monorepo, so it is gone.
    for c in candidates(fn):
        if c == target:
            return True
    norm = fn.replace("\\", "/")
    return norm.endswith("/" + target)

h = 0; t = 0; seen = False
tree = ET.parse(os.environ["REPORT_PATH"]); root = tree.getroot()

if fmt == "cobertura":
    for cls in root.iter('class'):
        if matches(cls.get('filename', '')):
            seen = True
            lines_el = cls.find('lines')
            if lines_el is not None:
                for l in lines_el.findall('line'):
                    t += 1
                    if int(l.get('hits', 0)) > 0:
                        h += 1
else:  # jacoco
    for pkg in root.iter('package'):
        pkg_name = (pkg.get('name') or '').replace('.', '/')
        for sf in pkg.findall('sourcefile'):
            rel = (pkg_name + '/' + (sf.get('name') or '')).lstrip('/')
            # JaCoCo paths are package-relative, so they are always a SUFFIX of the repo path
            # (src/main/java/ or src/main/kotlin/ sits in between). Suffix match only.
            if target.replace("\\", "/").endswith("/" + rel) or target == rel or matches(rel):
                seen = True
                for l in sf.findall('line'):
                    ci = int(l.get('ci', 0)); mi = int(l.get('mi', 0))
                    if ci + mi == 0:
                        continue
                    t += 1
                    if ci > 0:
                        h += 1

# 🔴 Distinguish "file present in the report with zero covered lines" (real 0%, must count) from
#    "file absent from the report entirely" (a path-matching failure, must NOT be silently averaged
#    away). -1 -1 is the sentinel for the latter; the caller turns it into an explicit finding.
print(h, t) if seen else print(-1, -1)
PYEOF
) 2>/dev/null
        ;;
      lcov)
        # Same one-way match rule as the XML formats above: an lcov SF: line may be ABSOLUTE
        # (istanbul commonly writes /abs/repo/src/x.ts) or root-relative, never a bare basename that
        # could belong to another package.
        read -r lh lf < <(awk -v target="$f" -v rroot="$rroot" '
          function norm(s) { gsub(/\\/, "/", s); sub(/^\.\//, "", s); return s }
          function endswith(s, suf) { return length(s) >= length(suf) && substr(s, length(s)-length(suf)+1) == suf }
          function hit(file,   c) {
            c = norm(file)
            if (c == target) return 1
            if (rroot != "." && (rroot "/" c) == target) return 1
            if (endswith(c, "/" target)) return 1
            return 0
          }
          $0 ~ /^SF:/ { active = hit(substr($0,4)); if (active) seen = 1 }
          active && /^LH:/ { lh += substr($0,4) }
          active && /^LF:/ { lf += substr($0,4) }
          /^end_of_record/ { active = 0 }
          END { if (seen) print lh+0, lf+0; else print -1, -1 }
        ' "$real_rp")
        ;;
      gocover)
        # Go coverprofile: "mode: set" then  <import/path/file.go>:L.C,L.C numStmts count
        # The path is an IMPORT path (module path + package dir), never a filesystem path, so it can
        # only ever be matched as a suffix of the repo-relative target.
        read -r lh lf < <(awk -v target="$f" '
          function endswith(s, suf) { return length(s) >= length(suf) && substr(s, length(s)-length(suf)+1) == suf }
          NR == 1 && /^mode:/ { next }
          {
            split($0, a, ":")
            file = a[1]
            if (file == target || endswith(file, "/" target) || endswith(target, "/" file)) {
              seen = 1
              n = split($0, b, " ")
              stmts = b[n-1] + 0; cnt = b[n] + 0
              lf += stmts
              if (cnt > 0) lh += stmts
            }
          }
          END { if (seen) print lh+0, lf+0; else print -1, -1 }
        ' "$real_rp")
        ;;
      *)
        fail "unitCoverage: unsupported format '${rfmt}' for report ${rp} — supported: cobertura, jacoco, lcov, gocover"
        had_error=1
        continue
        ;;
    esac

    # 🔴 A changed file the report does NOT mention is a PATH-MATCHING FAILURE, not 0% coverage, and
    #    never something to average away. Before this, an unmatched file contributed 0/0 - it vanished
    #    from the gate entirely, so a brand-new untested file sitting beside a well-covered one was
    #    invisible and the gate passed on the covered file alone. Record it and fail the gate.
    if [ "${lh:-0}" = "-1" ] && [ "${lf:-0}" = "-1" ]; then
      fail "unitCoverage: changed file '${f}' is NOT present in its configured coverage report (${real_rp}, format=${rfmt}, root='${rroot}'). This is a report/path mismatch or a genuinely unmeasured file — never treated as 0/0."
      unmatched_files="${unmatched_files}${unmatched_files:+, }${f}"
      had_error=1
      continue
    fi
    hit=$((hit + ${lh:-0})); found=$((found + ${lf:-0}))
  done <<< "$changed"

  if [ "$had_error" -eq 1 ]; then
    record unitCoverage ERROR "coverage could not be computed for one or more changed files — see the job log above.${unmatched_files:+ Files absent from their configured report: ${unmatched_files}}"
    return
  fi
  if [ "$found" -eq 0 ]; then
    record unitCoverage ERROR "no coverage data found for any changed file across the configured report(s) — report/changed-file path mismatch"
    return
  fi

  local pct
  pct=$(awk -v h="$hit" -v f="$found" 'BEGIN{printf "%.1f", (h/f)*100}')
  if awk -v p="$pct" -v m="$min" 'BEGIN{exit !(p+0 >= m+0)}'; then
    record unitCoverage PASS "changed-file coverage ${pct}% >= ${min}% (${hit}/${found} lines)"
  else
    record unitCoverage FAIL "changed-file coverage ${pct}% < ${min}% (${hit}/${found} lines)"
  fi
}

# GENERATED PER STACK: the generator appends one `delta_diff <gate> '<cmd>' "<root>" "<markerFile>"`
# line PER ROOT in ci.roots[] that resolves a D1/D2/D4/D5/D6 tool for its stack — a monorepo with two
# stacks that both lint therefore emits TWO `delta_diff D1_lint ...` calls, one per root, each cd-ing
# into its OWN verified root before running its OWN stack's command (common/ci-pipeline-generation.md
# Section 4.0d). A single-root manifest (or a legacy manifest with no roots[]) omits the last two args —
# they default to "." / no marker check, i.e. today's behaviour, unchanged.
# 🔴 A root with no resolvable command for a gate, and no true N/A reason, emits
#    `record_multi_root <gate> "<root>" ERROR "..."` directly — NEVER a bare `record <gate> ...` call.
#    Every per-root outcome for a gate that ci.roots[] can resolve more than once MUST go through
#    record_multi_root, so collapse_multi_root (called once, right after this block) is the ONLY thing
#    that ever writes these gates' final line — a generator-emitted bare `record` here would race it and
#    leave two lines for the same gate id in the file.
# Runs only on the normal pass — same reasoning as the D3/D7 guard above.
if [ "$COVERAGE_ONLY" -eq 0 ]; then
  :  # no-op — keeps this block syntactically valid even before the generator fills in any gates
     # (bash treats an if-body containing only comments as empty, which is a syntax error)
# >>> STACK-RESOLVED D-GATES START <<<
# >>> STACK-RESOLVED D-GATES END <<<
  collapse_multi_root
fi

# unitCoverage runs ONLY on the --coverage-only pass, called after "unit + coverage" has produced
# the report this function reads (Section 4.0b). See the coverage_delta() definition above.
if [ "$COVERAGE_ONLY" -eq 1 ]; then
  coverage_delta
fi

# Emit summary and set exit code from real results only.
echo "static eval gates (delta vs ${BASE_SHA}):"
cat "$RESULT_JSON.gates" | while IFS=$'\t' read -r g s r; do printf '  %-14s %-5s %s\n' "$g" "$s" "$r"; done

if [ "$overall_fail" -ne 0 ]; then
  echo "run-static-evals: at least one D-gate FAILED or ERRORED (delta-scoped)" >&2
  exit 1
fi
exit 0
