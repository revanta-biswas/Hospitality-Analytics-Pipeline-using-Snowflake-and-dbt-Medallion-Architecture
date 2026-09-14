#!/usr/bin/env bash
# auto-fix-agent.sh — CI self-repair via the Claude Code CLI (NOT the marketplace action, Section 6).
#
# 🔴 Input contract (Section 6.5):
#    PRIMARY      tests/.evals/_run/failed-gates.txt  — the authoritative list of what failed. Missing => this
#                 is a PIPELINE DEFECT: report and exit NON-ZERO. Never exit 0 on a job it did not repair.
#    SUPPLEMENTARY eval.json — per-criterion context. Absent => continue anyway, report as a finding.
#
# 🔴 The two proven lies this template fixes permanently:
#    1. mkdir -p every directory before writing the retry counter (Section 6.0.1 rule 2).
#    2. "No eval.json found" is NOT a free pass and NOT an infrastructure failure (Section 6.5). The
#       build failed; that fact is established by failed-gates.txt, not by the scorecard.
set -uo pipefail

CONFIG="tests/.evals/config.json"
RUN_DIR="tests/.evals/_run"
FAILED_GATES="${RUN_DIR}/failed-gates.txt"
BASE_SHA="${BASE_SHA:-}"
EVAL_KEY="${EVAL_KEY:-}"
EVIDENCE_DIR="reports/eval-evidence/${EVAL_KEY}"

mkdir -p "$RUN_DIR"   # 🔴 rule 2 — before the counter write

report_and_exit() { echo "auto-fix-agent: $1" >&2; exit "${2:-1}"; }

# ── PRIMARY input ──
if [ ! -f "$FAILED_GATES" ]; then
  report_and_exit "PIPELINE DEFECT: ${FAILED_GATES} missing — the Verdict step must always produce it. Not exiting 0 on an unrepaired failure." 1
fi
GATES=(); while IFS= read -r line; do GATES+=("$line"); done < <(grep -v '^[[:space:]]*$' "$FAILED_GATES" || true)
if [ "${#GATES[@]}" -eq 0 ]; then
  report_and_exit "failed-gates.txt is empty but self-repair was triggered — cannot determine what to repair." 1
fi

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# TRIAGE (Section 6.4) — RUNS BEFORE THE RETRY COUNTER IS TOUCHED.
# 🔴 Order matters and this was a real defect: the counter used to be incremented ABOVE the triage
#    block, so an infrastructure failure silently burned a retryLimitForSelfRepair attempt even though
#    Section 6.4 states "An infrastructure failure never consumes a retryLimitForSelfRepair attempt".
#    A non-repairable class must cost nothing.
# ══════════════════════════════════════════════════════════════════════════════════════════════════

# ── MANIFEST class (Section 6.4) — never repaired here, and never a code edit ──
# lib-manifest.* records every Manifest-class defect to this marker (a missing ci.roots[] directory, a
# root whose declared markerFile is gone, a tool named in `tools` with no toolInstallCommands entry).
# 🔴 Read the MARKER, never grep the log: stderr is interleaved, truncated and locale-dependent.
# The repair belongs to the owning implement workflow's manifest reconciliation, on its next push —
# self-repair fixes CODE; the workflow owns ci.roots. Editing application source to satisfy a stale
# manifest entry is damage, not a fix.
MANIFEST_DEFECTS="${RUN_DIR}/manifest-defects.txt"
if [ -f "$MANIFEST_DEFECTS" ] && [ -s "$MANIFEST_DEFECTS" ]; then
  report_and_exit "MANIFEST-class failure — not a code defect, not consuming a retry. The manifest does not describe this repo correctly:
$(cat "$MANIFEST_DEFECTS")
Fix tests/.evals/config.json's ci.roots[] (or the owning work unit's tests/.evals/ci-manifest.d/ fragment) and push again. Failing gates: ${GATES[*]}" 1
fi

# ── SMOKE-TEST context (Section 4.0.6) — the Code class is EMPTY here, by definition ──
# The epic-level pre-handoff smoke test is a deliberately ZERO-DIFF scratch PR: identical tree, new
# commit. With no code delta, NO failure on it can possibly be caused by application code — so there is
# nothing in src/ or tests/ for this agent to legitimately repair.
# 🔴 THIS IS THE GUARD THAT MAKES THE DUMMY-TEST INCIDENT STRUCTURALLY IMPOSSIBLE. Observed in the wild:
#    on a repo whose test suite did not exist yet, the unit gate failed, triage classed it "Code", and
#    this agent spent ~45 minutes WRITING FAKE TESTS purely to turn the gate green — fabricating a pass
#    (SH-6) and poisoning the regression baseline for every later work unit, because those fake tests
#    then merged into the epic branch and became "existing". It matters more now, not less: the smoke
#    watch loop in smoke-test-epic.* is deliberately UNBOUNDED (it stops only when this agent stops), so
#    an unguarded code-class repair here can loop indefinitely rather than for 45 minutes.
# What IS in scope on a smoke PR is exactly what the smoke test exists to validate: the ENVIRONMENT.
# CI infrastructure may be repaired; application code and tests may not.
HEAD_REF="${HEAD_REF:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')}"
SMOKE_CONTEXT=0
case "$HEAD_REF" in
  ci/epic-smoke-*) SMOKE_CONTEXT=1 ;;
esac

# ── INFRASTRUCTURE class (Section 6.4) ──
for g in "${GATES[@]}"; do
  case "$g" in
    sonar)
      # Real findings (conditions reported) => code-class. Auth/unreachable/timeout => infra => stop.
      if [ -f "${RUN_DIR}/sonar-conditions.txt" ] && [ -s "${RUN_DIR}/sonar-conditions.txt" ]; then
        : # code-class, repair below
      else
        report_and_exit "sonar failed WITHOUT reported conditions (auth/unreachable/timeout) — infrastructure, not a code defect. Not consuming a retry. Fix the Sonar connection/secret." 1
      fi
      ;;
  esac
done

# ── Retry budget (only a genuinely repairable failure gets this far, so only it consumes an attempt) ──
LIMIT=$(command -v jq >/dev/null 2>&1 && [ -f "$CONFIG" ] && jq -r '.retryLimitForSelfRepair // 3' "$CONFIG" || echo 3)
COUNTER="${RUN_DIR}/self-repair-attempt"
attempt=$(( ( $([ -f "$COUNTER" ] && cat "$COUNTER" || echo 0) ) + 1 ))
if [ "$attempt" -gt "$LIMIT" ]; then
  report_and_exit "retry limit ${LIMIT} reached — 3 retries ended. Please suggest next steps. Unresolved: ${GATES[*]}" 1
fi
echo "$attempt" > "$COUNTER"

# ── SUPPLEMENTARY input (never a precondition) ──
# 🔴 Resolve by EVAL_KEY path, NEVER by `find | head -1` (V31, Section 4.0e). A wildcard search across
#    reports/eval-evidence/ silently adopts the FIRST match across every work unit's evidence — after a
#    few merged stories that includes other stories' own committed eval.json, static-results.json.gates
#    and gitleaks-delta.json. EVAL_KEY is already resolved once (the "Resolve EVAL_KEY" step, same value
#    the verify job used) and is the only correct address for THIS run's own evidence.
if [ -z "$EVAL_KEY" ]; then
  report_and_exit "EVAL_KEY is not set — cannot resolve this run's own evidence directory. The self-repair job's 'Resolve EVAL_KEY' step must run before this script and export EVAL_KEY (Section 4.0e)." 1
fi
EVAL_JSON="${EVIDENCE_DIR}/eval.json"
if [ ! -f "$EVAL_JSON" ]; then
  echo "auto-fix-agent: note — no eval.json found at ${EVAL_JSON}; repairing from failed-gates.txt + logs (Section 6.5). Reporting the missing scorecard as a separate finding." >&2
  EVAL_JSON=""
fi

command -v claude >/dev/null 2>&1 || report_and_exit "claude CLI not installed — cannot self-repair." 1

# 🔴 The BRIEF below tells Claude to commit its own fix (it has git tool access) — so "did the agent
#    change anything" can NOT be judged by working-tree dirtiness alone (Section 6 lesson: a clean
#    `git status` after the CLI call means "Claude already committed it", not "nothing happened").
#    Track HEAD movement too; only BOTH unchanged means a genuine no-op.
BEFORE_SHA="$(git rev-parse HEAD)"

# -- STORY / WORK-UNIT CONTEXT (Section 6.5) --
# The agent repairs BETTER when it knows what the work unit was supposed to do. Everything here is
# read from files that already exist -- nothing is copied per story and nothing can drift
# (common/behavior-spec.md: the .feature file is the work unit's ONLY spec).
# PATHS ONLY: the agent has read access and opens what it needs. Never paste file bodies into the
# brief -- a large prompt piped to a TTY-less CLI is exactly the "Broken pipe" failure mode.
UNIT_FEATURE="spec/behavior/${EVAL_KEY}.feature"
CONTEXT_LINES=""
[ -f "$UNIT_FEATURE" ] && CONTEXT_LINES="${CONTEXT_LINES}
  - This work unit's Gherkin contract (its acceptance criteria, authored BEFORE the code): ${UNIT_FEATURE}"
[ -f "spec/plans/architecture.md" ] && CONTEXT_LINES="${CONTEXT_LINES}
  - Architecture constraints this repo is held to (Section 10 is what the J1 judge scores): spec/plans/architecture.md"
[ -f "spec/plans/requirements.md" ] && CONTEXT_LINES="${CONTEXT_LINES}
  - Requirements: spec/plans/requirements.md"
[ -f "spec/plans/stories.md" ] && CONTEXT_LINES="${CONTEXT_LINES}
  - Work-unit definitions and acceptance criteria: spec/plans/stories.md"
[ -f "runtime-artifacts/aire-state.md" ] && CONTEXT_LINES="${CONTEXT_LINES}
  - Story Tracker (which unit this is, its tracker id, its dependencies): runtime-artifacts/aire-state.md"
[ -n "$EVAL_JSON" ] && CONTEXT_LINES="${CONTEXT_LINES}
  - This run's scorecard, with per-criterion judge scores and file:line citations: ${EVAL_JSON}"

# -- SCOPE -- differs between a normal work-unit PR and the zero-diff smoke PR --
if [ "$SMOKE_CONTEXT" -eq 1 ]; then
  SCOPE_BLOCK="SCOPE - THIS IS THE EPIC-LEVEL SMOKE TEST (a deliberately ZERO-DIFF PR).
  There is NO code change on this PR, so no failure here can be caused by application code.
  You are validating and repairing the ENVIRONMENT, nothing else.
  YOU MAY EDIT:    .github/workflows/**, tests/.evals/scripts/**, tests/.evals/behavior/**, and tool
                   pins / install commands in tests/.evals/config.json or tests/.evals/ci-manifest.d/*.json.
  YOU MAY NOT EDIT, FOR ANY REASON: src/**, tests/** (except tests/.evals/**), or any application
     source or test file. In particular you MUST NOT create tests.
  If a test runner reports that it collected ZERO tests, that is the CORRECT and EXPECTED state of
     this repo right now - the first story has not been built yet. It is N/A, not a failure. Do NOT
     write a test, a placeholder test, a dummy assertion or a conftest to make it pass. If that is the
     only thing failing, say so plainly and stop: the pipeline is behaving correctly.
  Never weaken a threshold or delete a gate to make this PR green."
else
  SCOPE_BLOCK="SCOPE - a normal work-unit PR. Fix the CODE that failed the gates.
  YOU MAY EDIT:    src/** (application code) and tests/** (real tests for that code) - and nothing
                   else. Code belongs in src/, tests belong in tests/. Never introduce a third location.
  YOU MAY NOT EDIT: .github/workflows/**, tests/.evals/config.json, tests/.evals/rubrics/**,
     tests/.evals/ci-manifest.d/**, or spec/**. Those are the contract you are being measured against.
     If the failure is genuinely caused by one of them, that is a MANIFEST or INFRASTRUCTURE class
     failure - report it and stop rather than editing the yardstick.
  Stay inside THIS work unit. Do not touch files another work unit owns just because a gate
     mentioned them."
fi

BRIEF="The agentic eval pipeline failed on this PR. You are the CI self-repair agent.
You have read, write and commit access to this checkout. Use them - investigate, fix, verify, commit.

FAILED GATES: ${GATES[*]}

WHERE THE TRUTH IS (read these first, in this order):
  - tests/.evals/_run/failed-gates.txt  - PRIMARY. The authoritative list of what failed.
  - the failing steps' logs in this job - the actual error text to repair against.
  - eval.json (if present)              - per-criterion scores and file:line citations.

WORK-UNIT CONTEXT (open what you need; do not assume):${CONTEXT_LINES}

${SCOPE_BLOCK}

HOW TO FIX (stack-agnostic - this repo may be any language, or a mix of several):
  - Read the repo to learn its stack, its conventions and its test layout. Never assume a framework, a
    package manager, a directory layout or a command. tests/.evals/_run/merged-manifest.json records
    the commands this project actually uses, per root, with the directory each one runs from.
  - Match the surrounding code: its language, style, naming, error handling and test idiom.
  - Fix the ROOT CAUSE of each failed gate, one gate at a time. Do not shotgun unrelated changes.
  - Re-run what you can verify yourself (the linter, the type checker, the unit tests, the build) from
    the correct working directory, and confirm it is actually green before you commit.

NON-NEGOTIABLE GUARDRAILS (violating any of these is worse than leaving the gate red):
  - Never delete, skip, weaken or ignore a test to go green. Fix the code the test is failing on.
  - Never write a fake, empty, trivially-true or placeholder test to satisfy a coverage or test gate.
    A test that cannot fail is not a test. If coverage is short, write a REAL test that exercises the
    behaviour; if you cannot, say so and stop.
  - Never suppress a finding: no blanket eslint-disable, no nosec, no type-ignore, no SuppressWarnings,
    no ignore-list entry, no widening of a disallowed-licence list.
  - Never lower a threshold in tests/.evals/config.json, and never edit a rubric.
  - Never edit spec/plans/architecture.md to make the J1 architecture gate pass. The architecture
    changes only when the DESIGN changed - never because a score did not clear.
  - Never edit sonar-project.properties, the Quality Gate, or mark an issue Won't Fix.
  - SECURITY: your fix must satisfy the Security Baseline the review enforces. Never introduce a
    hardcoded credential, token, key or connection string; never log a secret or PII; never disable
    TLS/certificate verification, authentication, authorization or CSRF protection; never widen CORS
    to a wildcard; never build a query by string concatenation instead of parameterising it; never
    weaken input validation to make a test pass. A repair that trades a failing gate for a
    vulnerability is a regression, not a fix.
  - Never commit generated evidence, build output, caches, or tests/.evals/_run/** state.
  - Do NOT try to invoke or re-run the J1_architecture / J2_security judge gates yourself. Scoring them
    means shelling out to claude again from inside your own tool call, which cannot authenticate
    (credentials do not propagate to a nested claude invocation) - that failure is expected, not a bug
    worth reporting. This script re-verifies J1/J2 for real after your turn ends; just fix the cited
    criteria/citations from eval.json and stop.

IF YOU CANNOT FIX IT: say exactly which gate, what you tried, and why it did not work - then stop.
A clear, honest report is a valid outcome. A fabricated pass never is.

Commit with:  fix(ci): self-repair attempt ${attempt} - ${GATES[*]}"

# 🔴 headless/permission flags resolved from `claude --help` at GENERATION time (Section 6.0) —
#    the generator writes the resolved invocation between the markers below, never assumed from memory.
# >>> CLAUDE_REPAIR_INVOCATION START <<<
printf '%s' "$BRIEF" | claude || report_and_exit "the repair CLI invocation failed on attempt ${attempt}." 1
# >>> CLAUDE_REPAIR_INVOCATION END <<<

# ── Verify the agent actually changed something ──
# Claude may have committed the fix itself (per the BRIEF) — that leaves the tree clean but HEAD
# moved. Only a clean tree AND an unmoved HEAD means it genuinely made no changes.
AFTER_SHA="$(git rev-parse HEAD)"
if [ "$AFTER_SHA" = "$BEFORE_SHA" ] && [ -z "$(git status --porcelain)" ]; then
  report_and_exit "self-repair produced no changes on attempt ${attempt} — nothing committed. PR stays red." 1
fi

# ── 🔴 SCOPE ENFORCEMENT — the BRIEF states the scope; THIS is what makes it binding ──
# A prompt is guidance, not a guarantee. Every path the agent touched (committed or still in the tree)
# is checked against the scope for this context, and a violation aborts BEFORE the push — so a
# forbidden edit can never reach the repository. The local commits die with the ephemeral runner.
#
# 🔴 On the smoke PR this is the hard stop behind the dummy-test incident: even if the agent is talked
#    into "just one small test file", it cannot land one. On a normal PR it is what stops the agent
#    editing the yardstick — the workflow, the thresholds, the rubrics or the specs — instead of the code.
TOUCHED="$( { git diff --name-only "$BEFORE_SHA" HEAD 2>/dev/null; git status --porcelain | awk '{print $NF}'; } | sort -u | grep -v '^[[:space:]]*$' || true)"
VIOLATIONS=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [ "$SMOKE_CONTEXT" -eq 1 ]; then
    # Smoke PR: environment only. src/** and tests/** are out of scope; tests/.evals/** is the exception.
    case "$f" in
      tests/.evals/*) : ;;
      src/*|tests/*)  VIOLATIONS="${VIOLATIONS}
  ${f}" ;;
    esac
  else
    # Normal work-unit PR: the contract being measured against is off-limits.
    case "$f" in
      .github/workflows/*|tests/.evals/config.json|tests/.evals/rubrics/*|tests/.evals/ci-manifest.d/*|spec/*)
        VIOLATIONS="${VIOLATIONS}
  ${f}" ;;
    esac
  fi
done <<< "$TOUCHED"

if [ -n "$VIOLATIONS" ]; then
  if [ "$SMOKE_CONTEXT" -eq 1 ]; then
    report_and_exit "SCOPE VIOLATION on the epic smoke PR — self-repair modified application code or tests, which is never a valid repair for a ZERO-DIFF PR. Nothing has been pushed. Offending paths:${VIOLATIONS}

The smoke test validates the ENVIRONMENT, not the code — there is no code change on this PR for a gate to be failing on. If a test runner reported that it collected zero tests, that is correct and expected before the first story: it is N/A, not a failure. Fix the environment (workflow, eval scripts, tool pins) or report the real blocker. Failing gates: ${GATES[*]}" 1
  else
    report_and_exit "SCOPE VIOLATION — self-repair modified the contract it is measured against, not the code. Nothing has been pushed. Offending paths:${VIOLATIONS}

The workflow, tests/.evals/config.json, the rubrics, the manifest fragments and spec/** are all off-limits to this agent (Section 6.4). If the failure is genuinely caused by one of them, that is a MANIFEST or INFRASTRUCTURE class failure for the owning workflow to fix — not something to repair here. Failing gates: ${GATES[*]}" 1
  fi
fi

# 🔴 D7_secrets is the ONE gate a forward commit can be structurally unable to clear: gitleaks scans
#    `--log-opts BASE..HEAD`, i.e. every commit's OWN patch in that range — not the final tree. A
#    finding anchored to a commit that was ALREADY pushed to origin before this attempt started stays
#    in that history forever; no later commit can retroactively edit it. Observed in production:
#    self-repair correctly fixed the actual code (2 of 3 D7 findings' source locations, plus D1_lint),
#    re-verified, and found D7_secrets still red with the SAME finding count — because the flagged text
#    is permanently baked into an already-pushed commit's patch, not because the fix didn't work.
#    Refusing to commit in that case would discard real, valuable fixes for no benefit — but SILENTLY
#    committing as if D7 passed would hide a genuinely unresolved finding. Do neither: commit the real
#    fixes, and say plainly that D7_secrets needs a human decision.
d7_only_history_anchored_remaining() {
  # 🔴 Resolve by EVAL_KEY path, never `find | head -1` (same rule as above — never adopt another
  #    work unit's committed evidence).
  local gates_file gitleaks_report origin_ref commit
  gates_file="${EVIDENCE_DIR}/static/static-results.json.gates"
  [ -n "$EVAL_KEY" ] && [ -f "$gates_file" ] || return 1

  local failing=()
  while IFS=$'\t' read -r g s _; do
    case "$s" in FAIL|ERROR) failing+=("$g") ;; esac
  done < "$gates_file"
  # Must be the ONLY thing still failing — anything else means real fixable work remains.
  [ "${#failing[@]}" -eq 1 ] && [ "${failing[0]}" = "D7_secrets" ] || return 1

  gitleaks_report="${EVIDENCE_DIR}/static/gitleaks-delta.json"
  [ -f "$gitleaks_report" ] && command -v jq >/dev/null 2>&1 || return 1

  origin_ref="origin/${GITHUB_HEAD_REF:-HEAD}"
  git fetch origin "${GITHUB_HEAD_REF:-HEAD}" >/dev/null 2>&1 || true

  while IFS= read -r commit; do
    [ -z "$commit" ] && continue
    git merge-base --is-ancestor "$commit" "$origin_ref" 2>/dev/null || return 1
  done < <(jq -r '.[].Commit // empty' "$gitleaks_report" 2>/dev/null | sort -u | tr -d '\r')
  return 0
}

# ── rule 4: re-run the evals BEFORE committing; a commit that does not re-verify wastes a retry ──
if [ -n "$BASE_SHA" ]; then
  bash tests/.evals/scripts/run-static-evals.sh "$BASE_SHA"; static_rc=$?
  bash tests/.evals/scripts/run-evals.sh "$BASE_SHA"; evals_rc=$?
  if [ "$static_rc" -ne 0 ] || [ "$evals_rc" -ne 0 ]; then
    if d7_only_history_anchored_remaining; then
      echo "auto-fix-agent: D7_secrets remains red — every remaining finding is anchored to an already-pushed commit (gitleaks' own --log-opts BASE..HEAD commit-range scan); no forward commit can clear it. Proceeding to commit the real fix(es) made for the other gate(s). D7_secrets needs a human decision: rebase to scrub the secret from that commit and force-push, or (only if it is a rotated/false-positive credential) add a scoped gitleaks allowlist entry for that exact fingerprint — never a blanket suppression." >&2
    else
      report_and_exit "re-verification still FAILS after repair attempt ${attempt} — not committing an unverified fix." 1
    fi
  fi
fi

# 🔴 A fresh GH Actions runner has no git identity configured — `git commit` fails outright
#    ("Author identity unknown... fatal: empty ident name") even after a fully correct repair, wasting
#    a retry attempt on something that was never a code problem. `--local` (not `--global`) scopes it to
#    this checkout only. Same bot-identity convention as smoke-test-epic.sh's `aire-ci-smoke` commits.
git config --local user.name "aire-self-repair"
git config --local user.email "aire-self-repair@localhost"

# Claude may have already committed its own fix inside the CLI call above. Only create an extra
# commit for whatever it left uncommitted — never treat "nothing left to stage" as a failure.
if [ -n "$(git status --porcelain)" ]; then
  # -- never stage this run's own scratch state: the retry counter, failed-gates.txt, the merged
  #    manifest and manifest-defects.txt all live under tests/.evals/_run/ and are per-run artifacts.
  #    Committing them pollutes the diff and, worse, carries a stale failed-gates.txt into the next run.
  git add -A -- ':!tests/.evals/_run' 2>/dev/null || git add -A
  git commit -m "fix(ci): self-repair attempt ${attempt} — ${GATES[*]}" || report_and_exit "commit failed on attempt ${attempt}." 1
fi
git push origin HEAD:"${GITHUB_HEAD_REF:-HEAD}" || report_and_exit "push failed on attempt ${attempt}." 1

echo "auto-fix-agent: attempt ${attempt} committed and pushed for gates: ${GATES[*]}"
exit 0
