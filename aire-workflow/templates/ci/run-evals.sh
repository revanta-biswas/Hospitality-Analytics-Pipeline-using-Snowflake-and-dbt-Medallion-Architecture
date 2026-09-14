#!/usr/bin/env bash
# run-evals.sh — the J1/J2 LLM judge gates, then merge ALL gate results into eval.json + eval-summary.md.
#
# 🔴 The `gates` block of eval.json iterates ci.gates from tests/.evals/config.json (the SINGLE SOURCE OF
#    TRUTH), so a gate that can fail the build can never be silently absent from the scorecard — the
#    SonarQube-missing-from-eval.json class is deleted by construction (Section 4.0c.3).
#
# 🔴 NO STUBS (Section 5.0). Missing credentials => ERROR, never N/A. A malformed judge response =>
#    ERROR after one retry, never N/A. Exactly two legitimate J1/J2 N/A reasons exist:
#      (a) eval-framework Section 3 fallback chain bottoming out (no architecture.md, no rubric,
#          nothing derivable) — score_rubric() return 3.
#      (b) an EMPTY diff vs BASE_SHA (the epic-level pre-handoff smoke test, which is deliberately a
#          zero-diff PR — ci-pipeline-generation.md Section 4.0.6's own documented "does NOT validate
#          J1/J2" scope) — score_rubric() return 4. Never send an empty diff to the judge: it cannot
#          score what isn't there, and an unparseable/degenerate response would otherwise surface as a
#          fabricated FAIL/ERROR on a run that legitimately has nothing to judge.
set -uo pipefail

BASE_SHA="${1:-}"
CONFIG="tests/.evals/config.json"
EVAL_KEY="${EVAL_KEY:-local}"
EVIDENCE_DIR="reports/eval-evidence/${EVAL_KEY}"
JUDGE_DIR="${EVIDENCE_DIR}/judge"
STATIC_DIR="${EVIDENCE_DIR}/static"

mkdir -p "$JUDGE_DIR" "$STATIC_DIR" tests/.evals/_run

fail() { echo "run-evals: ERROR: $*" >&2; }

[ -f "$CONFIG" ] || { fail "$CONFIG missing"; exit 2; }
command -v jq >/dev/null 2>&1 || { fail "jq not installed"; exit 2; }

ARCH_MIN=$(jq -r '.thresholds.llmJudgeArchitectureScoreMin // 0.85' "$CONFIG")
SEC_MIN=$(jq -r '.thresholds.llmJudgeSecurityScoreMin // 0.85' "$CONFIG")
MODEL=$(jq -r '.judge.model // ""' "$CONFIG")
RUBRIC_VERSION=$(jq -r '.judge.rubricVersion // ""' "$CONFIG")
GATES=(); while IFS= read -r line; do GATES+=("$line"); done < <(jq -r '.ci.gates[]?' "$CONFIG" | tr -d '\r')  # portable

# ── Credentials: missing is ERROR, not N/A (the judge gate SHOULD run) ──
if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  fail "no CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY — the judge gate should have run and did not"
  exit 2
fi
command -v claude >/dev/null 2>&1 || { fail "claude CLI not installed — judge cannot run"; exit 2; }

# 🔴 An EMPTY --model argument is not a harmless default — claude rejects it outright:
#    "API Error: 400 model: String should have at least 1 character", and exits before draining a
#    large piped prompt, which is what turns into a misleading "printf: write error: Broken pipe" /
#    "judge CLI invocation failed" symptom downstream, with the real cause invisible until the
#    invocation's own stderr is captured (Section 6.0 applies to this marker too). Fail clearly, here,
#    before ever constructing that invocation — never let judge.model silently resolve to an empty
#    string once the generator has filled in the resolved flags between the CLAUDE_JUDGE_INVOCATION
#    markers below.
if [ -z "$MODEL" ]; then
  fail "judge.model is not set in ${CONFIG} — cannot invoke claude with an empty --model (set judge.model to a real model name/alias)"
  exit 2
fi

# score_rubric <rubric_file> <out_file> <min> -> prints the numeric score, writes strict-JSON out_file.
# Returns 0 PASS, 1 FAIL, 2 ERROR, 3 N/A (rubric absent), 4 N/A (empty diff — nothing to score).
score_rubric() {
  local rubric="$1" out="$2" min="$3"
  if [ ! -f "$rubric" ]; then
    printf '{"status":"N/A","reason":"rubric %s absent — fallback chain bottomed out"}\n' "$rubric" > "$out"
    return 3
  fi
  local diff prompt resp
  diff="$(git diff "${BASE_SHA}...HEAD" 2>/dev/null || true)"
  if [ -z "$diff" ]; then
    printf '{"status":"N/A","reason":"empty diff vs %s — nothing to score (pre-story/zero-diff run, ci-pipeline-generation.md Section 4.0.6)"}\n' "$BASE_SHA" > "$out"
    return 4
  fi
  prompt="Score the PR diff against this rubric. Score EACH criterion independently (0.0-1.0). Every
criterion below 1.0 MUST cite file:line. Score only what the diff shows; a criterion the diff cannot
exercise is N/A and excluded with remaining weights renormalised to 1.0 — never scored 0. Return STRICT
JSON ONLY, no prose: {\"score\":<0-1>,\"criteria\":[{\"id\":...,\"weight\":...,\"score\":...,\"citation\":...,\"note\":...}]}.
RUBRIC:
$(cat "$rubric")
DIFF:
${diff}"
  # 🔴 headless/permission flags are resolved from `claude --help` at GENERATION time and written in by
  #    the generator between the markers below — never assumed from memory. This is the SAME
  #    requirement Section 6.0 states for auto-fix-agent.sh, applied here too (ci-pipeline-generation.md
  #    Section 4.2, "Authentication alone is not enough") — a bare, unresolved `claude` invocation tries
  #    to start an interactive session with no TTY available in CI, exits almost immediately, and the
  #    `printf` piping the prompt in gets "Broken pipe" because the reader already closed.
  local rc claude_err_file
  claude_err_file="$(mktemp)"
  # >>> CLAUDE_JUDGE_INVOCATION START <<<
  resp="$(printf '%s' "$prompt" | claude 2>"$claude_err_file")"; rc=$?
  # >>> CLAUDE_JUDGE_INVOCATION END <<<
  if [ "$rc" -ne 0 ]; then
    fail "judge CLI invocation failed: $(cat "$claude_err_file" 2>/dev/null)"
    rm -f "$claude_err_file"
    return 2
  fi
  # Extract the JSON object from the response, retry once on parse failure.
  local json
  json="$(printf '%s' "$resp" | sed -n '/{/,/}/p' | jq -c '.' 2>/dev/null || true)"
  if [ -z "$json" ]; then
    resp="$(printf '%s' "$prompt" | claude 2>"$claude_err_file")" || true
    json="$(printf '%s' "$resp" | sed -n '/{/,/}/p' | jq -c '.' 2>/dev/null || true)"
  fi
  rm -f "$claude_err_file"
  if [ -z "$json" ]; then
    printf '{"status":"ERROR","reason":"judge returned unparseable output after one retry"}\n' > "$out"
    return 2
  fi
  echo "$json" | jq --arg m "$MODEL" --arg rv "$RUBRIC_VERSION" \
    '. + {model:$m, rubricVersion:$rv}' > "$out"
  local score
  score="$(jq -r '.score // 0' "$out" | tr -d '\r')"
  awk -v s="$score" -v m="$min" 'BEGIN{exit !(s+0 >= m+0)}' && return 0 || return 1
}

j1_status="ERROR"; j1_reason="not computed"
score_rubric "tests/.evals/rubrics/architecture-rubric.json" "${JUDGE_DIR}/architecture-score.json" "$ARCH_MIN"
case $? in
  0) j1_status=PASS; j1_reason="architecture score >= ${ARCH_MIN}" ;;
  1) j1_status=FAIL; j1_reason="architecture score < ${ARCH_MIN}" ;;
  3) j1_status="N/A"; j1_reason="rubric absent (fallback chain bottomed out)" ;;
  4) j1_status="N/A"; j1_reason="empty diff vs base — nothing to score (pre-story/zero-diff run)" ;;
  *) j1_status=ERROR; j1_reason="judge could not score architecture" ;;
esac

j2_status="ERROR"; j2_reason="not computed"
score_rubric "tests/.evals/rubrics/security-rubric.json" "${JUDGE_DIR}/security-score.json" "$SEC_MIN"
case $? in
  0) j2_status=PASS; j2_reason="security score >= ${SEC_MIN}" ;;
  1) j2_status=FAIL; j2_reason="security score < ${SEC_MIN}" ;;
  3) j2_status="N/A"; j2_reason="rubric absent (fallback chain bottomed out)" ;;
  4) j2_status="N/A"; j2_reason="empty diff vs base — nothing to score (pre-story/zero-diff run)" ;;
  *) j2_status=ERROR; j2_reason="judge could not score security" ;;
esac

# ── Merge: iterate ci.gates, fill each from the real source. Never hardcode a result not computed. ──
declare -A STATIC_STATUS STATIC_REASON
if [ -f "${STATIC_DIR}/static-results.json.gates" ]; then
  while IFS=$'\t' read -r g s r; do STATIC_STATUS["$g"]="$s"; STATIC_REASON["$g"]="$r"; done \
    < "${STATIC_DIR}/static-results.json.gates"
fi
# Behaviour/coverage/sonar outcomes come from the workflow's own step outcomes, surfaced via
# tests/.evals/_run/<gate>.status when a caller writes them; absent => the caller did not run that gate.
step_status() { [ -f "tests/.evals/_run/$1.status" ] && cat "tests/.evals/_run/$1.status" || echo "N/A"; }

EVAL_JSON="${EVIDENCE_DIR}/eval.json"
{
  echo '{'
  echo "  \"evalKey\": \"${EVAL_KEY}\","
  echo "  \"model\": \"${MODEL}\","
  echo "  \"rubricVersion\": \"${RUBRIC_VERSION}\","
  echo '  "gates": {'
  first=1
  any_fail=0
  for g in "${GATES[@]}"; do
    case "$g" in
      # 🔴 Match ANY D1-D7 gate by prefix (D[1-7]_*), never by hardcoding each exact suffix. An
      #    earlier version of this case statement listed exact strings (D2_types, D4_deps,
      #    D5_licenses) that didn't match the real gate ids a project's own config.json actually used
      #    (D2_typecheck, D4_sca, D5_license) — so those three silently fell through to the "unknown
      #    gate id" -> N/A branch below, never able to fail the build no matter what
      #    static-results.json.gates actually said. Observed in production: a real, reproduced
      #    D2_typecheck FAIL was merged into eval.json as N/A, and the overall verdict came back PASS.
      #    The .ps1 twin already uses this same '^D[1-7]_|^unitCoverage$' regex approach — kept in
      #    sync here.
      D[1-7]_*|unitCoverage)
        # 🔴 unitCoverage belongs here, NOT with the step_status() group below — coverage_delta()
        #    in run-static-evals.* writes it into static-results.json.gates, same as D1-D7. It was
        #    previously grouped with behaviorB1-3/sonarqube (which read tests/.evals/_run/<gate>.status),
        #    meaning its real computed result never reached eval.json. Fixed here.
        # 🔴 A DECLARED GATE WITH NO RESULT IS AN **ERROR**, NEVER A PASSING N/A.
        #    `${STATIC_STATUS[$g]:-N/A}` laundered an ABSENT gate into a non-failing status: N/A never
        #    sets any_fail, so a pipeline that recorded ZERO of D1/D2/D4/D5/D6 - because the generator
        #    resolved no command for them, or the stack-resolved region was empty - emitted
        #    "verdict": "PASS" having measured nothing. The gate is in ci.gates, so it was DECLARED as
        #    something this project enforces; the only honest outcome for "declared but never run" is
        #    ERROR. A gate that genuinely does not apply must be RECORDED as an earned N/A by
        #    run-static-evals.* with a real reason (eval-framework.md Section 2.5.1's closed list) -
        #    absence is not that.
        if [ -n "${STATIC_STATUS[$g]:-}" ]; then
          st="${STATIC_STATUS[$g]}"; rs="${STATIC_REASON[$g]:-}"
        else
          st="ERROR"
          rs="gate '${g}' is declared in ci.gates but produced NO result in static-results.json.gates - it was never run. Absence is not a pass: either the generator resolved no command for it (fix ci.roots[]/the stack-resolved region), or the gate should not be in ci.gates."
        fi ;;
      J1_architecture) st="$j1_status"; rs="$j1_reason" ;;
      J2_security) st="$j2_status"; rs="$j2_reason" ;;
      behaviorB1|behaviorB2|behaviorB3|sonarqube)
        st="$(step_status "$g")"; rs="from workflow step outcome" ;;
      *) st="N/A"; rs="unknown gate id" ;;
    esac
    case "$st" in FAIL|ERROR) any_fail=1 ;; esac
    [ $first -eq 1 ] && first=0 || echo ','
    printf '    "%s": {"status": "%s", "reason": "%s"}' "$g" "$st" "${rs//\"/\\\"}"
  done
  echo ''
  echo '  },'
  if [ "$any_fail" -ne 0 ]; then echo '  "verdict": "FAIL"'; else echo '  "verdict": "PASS"'; fi
  echo '}'
} > "$EVAL_JSON"

# eval-summary.md — human view pasted into the PR
{
  echo "# AIRE eval summary — ${EVAL_KEY}"
  echo ""
  echo "| Gate | Status | Notes |"
  echo "|---|---|---|"
  jq -r '.gates | to_entries[] | "| \(.key) | \(.value.status) | \(.value.reason) |"' "$EVAL_JSON"
  echo ""
  echo "**Verdict:** $(jq -r '.verdict' "$EVAL_JSON")"
} > "${EVIDENCE_DIR}/eval-summary.md"

echo "run-evals: wrote $EVAL_JSON (verdict $(jq -r '.verdict' "$EVAL_JSON"))"
[ "$(jq -r '.verdict' "$EVAL_JSON")" = "PASS" ] || exit 1
exit 0
