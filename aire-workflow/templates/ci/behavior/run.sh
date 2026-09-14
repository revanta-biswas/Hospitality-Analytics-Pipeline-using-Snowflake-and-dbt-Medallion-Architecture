#!/usr/bin/env bash
# behavior/run.sh — the SINGLE entry point for the Gherkin tiers. The developer, AIRE's local gate and
# CI all call `./tests/.evals/behavior/run.sh <tier>` so tier membership can never drift (Section 4.1b).
#
#   b1  this work unit's feature file only
#   b2  every OTHER feature file under spec/behavior/
#   b3  the whole cycle plus spec/behavior.feature (cross-story journeys) — last unit / base-branch PR
#
# 🔴 NO STUBS. A tier that cannot resolve any feature files exits NON-ZERO with the reason — it never
#    prints "ok" and exits 0 (Section 5.0). Tier membership is read from the spec/ layout here, never
#    duplicated in YAML.
#
# 🔴 ONE legitimate exception: exit 3 = N/A, reserved for spec/behavior/ containing ZERO feature files
#    of ANY kind — meaning no story has EVER been dev-implement'd in this epic yet (the pre-story /
#    epic-level-smoke-test case, ci-pipeline-generation.md Section 4.0.6's own documented "does NOT
#    validate" scope). A tier that finds none of ITS OWN files while OTHER feature files exist is still
#    a real contract violation and stays exit 2 (ERROR) — only total absence is N/A.
set -uo pipefail

TIER="${1:-}"
BEHAVIOR_DIR="spec/behavior"
CROSS_STORY="spec/behavior.feature"

[ -n "$TIER" ] || { echo "run.sh: no tier supplied (b1|b2|b3)" >&2; exit 2; }

# 🔴 THIS FILE IS COPIED BYTE-FOR-BYTE. The ONLY region a generated repo may fill is between the
#    STACK-RESOLVED BEHAVIOUR RUNNER markers below. Editing anything else here is template drift
#    (ci-pipeline-generation.md Section 1): the fix lives in ONE repo, the next regeneration deletes
#    it, and every other project keeps the bug. A behaviour change belongs in templates/ci/behavior/run.sh.
#
# Environment:
#   AIRE_STORY_KEY  (optional but STRONGLY preferred for b1) — this work unit's key, e.g. "story-1.10",
#                   resolving to spec/behavior/story-1.10.feature. Set by the invoking implement
#                   workflow and by the CI behaviour step. Without it, b1 accepts a single feature file
#                   and ERRORS when several exist rather than guessing which unit is under test.
#
# The generator resolves the concrete runner invocation for this stack (cucumber-js / pytest-bdd /
# mvn verify / godog / reqnroll) between the markers below (Section 3). It MUST fail the process on a
# scenario failure and MUST NOT be replaced by an `echo ok`.
run_features() { # $@ = feature files
  [ "$#" -gt 0 ] || { echo "run.sh: tier ${TIER} resolved zero feature files" >&2; return 2; }
  # >>> STACK-RESOLVED BEHAVIOUR RUNNER START <<<
  echo "run.sh: no behaviour runner resolved for this stack — generation defect (ERROR, not a pass)" >&2
  return 2
  # >>> STACK-RESOLVED BEHAVIOUR RUNNER END <<<
}

no_stories_yet() { # true iff spec/behavior/ has literally zero *.feature files (not just zero for this tier)
  [ -z "$(ls -1 "${BEHAVIOR_DIR}"/*.feature 2>/dev/null || true)" ]
}

case "$TIER" in
  b1)
    # 🔴 B1 MUST RUN *THIS* WORK UNIT'S CONTRACT — never a neighbouring one.
    #    AIRE_STORY_KEY names it (e.g. "story-1.10" -> spec/behavior/story-1.10.feature). It is set by
    #    the invoking dev-implement / bug-fix-implement / enhancement-implement run, and by the CI
    #    behaviour step from the already-resolved EVAL_KEY.
    #    Without it this took `ls -1 story-*.feature | tail -n1` — the LEXICOGRAPHICALLY last file.
    #    That is wrong the moment an epic passes nine work units: "story-1.10" sorts BEFORE "story-1.9",
    #    so tail -n1 returns 1.9 and B1 runs an ALREADY-MERGED unit's contract instead of the one being
    #    built — and PASSES, having never tested this unit. A silent pass, and it gets likelier as the
    #    epic grows.
    #    So: use the key when given; accept a lone feature file when there is exactly one; and when
    #    several exist with no key, ERROR rather than guess.
    if [ -n "${AIRE_STORY_KEY:-}" ]; then
      unit_feature="${BEHAVIOR_DIR}/${AIRE_STORY_KEY}.feature"
      if [ ! -f "$unit_feature" ]; then
        # 🔴 AIRE_STORY_KEY is ALWAYS set in CI (the workflow passes the resolved eval key), so this
        #    branch is the ONLY one CI ever takes — the no_stories_yet() N/A exception below MUST be
        #    reachable from here too, not just from the no-key fallback branch at line ~82, or every
        #    epic-level pre-handoff smoke test (zero feature files, by design) reports a false ERROR
        #    instead of the earned N/A. Observed in production (ci-pipeline-generation.md Section 4.0.6).
        if no_stories_yet; then
          echo "run.sh: b1 N/A — no story has been dev-implement'd in this epic yet (spec/behavior/ has zero feature files)" >&2
          exit 3
        fi
        echo "run.sh: b1 ERROR — AIRE_STORY_KEY='${AIRE_STORY_KEY}' but ${unit_feature} does not exist. B1 must run THIS unit's own contract; refusing to fall back to another unit's feature file." >&2
        exit 2
      fi
    else
      mapfile -t unit_candidates < <(ls -1 "${BEHAVIOR_DIR}"/story-*.feature 2>/dev/null || true)
      if [ "${#unit_candidates[@]}" -eq 1 ]; then
        unit_feature="${unit_candidates[0]}"
      elif [ "${#unit_candidates[@]}" -gt 1 ]; then
        echo "run.sh: b1 ERROR — ${#unit_candidates[@]} story feature files exist and AIRE_STORY_KEY is not set, so THIS unit's contract cannot be identified. Not guessed: the lexicographically last file is story-1.9 when story-1.10 is the unit under test, which passes B1 without testing it. Set AIRE_STORY_KEY=<work-unit-key> (e.g. story-1.10)." >&2
        exit 2
      else
        unit_feature=""
      fi
    fi
    if [ -z "$unit_feature" ]; then
      if no_stories_yet; then
        echo "run.sh: b1 N/A — no story has been dev-implement'd in this epic yet (spec/behavior/ has zero feature files)" >&2
        exit 3
      fi
      echo "run.sh: b1 found no story feature file (other feature files exist — this story's own contract is missing)" >&2
      exit 2
    fi
    run_features "$unit_feature" ;;
  b2)
    mapfile -t others < <(ls -1 "${BEHAVIOR_DIR}"/*.feature 2>/dev/null || true)
    if [ "${#others[@]}" -eq 0 ]; then
      echo "run.sh: b2 N/A — no story has been dev-implement'd in this epic yet (spec/behavior/ has zero feature files)" >&2
      exit 3
    fi
    run_features "${others[@]}" ;;
  b3)
    mapfile -t all < <(ls -1 "${BEHAVIOR_DIR}"/*.feature 2>/dev/null || true)
    [ -f "$CROSS_STORY" ] && all+=("$CROSS_STORY")
    if [ "${#all[@]}" -eq 0 ]; then
      echo "run.sh: b3 N/A — no story has been dev-implement'd in this epic yet, and no cross-story spec/behavior.feature exists" >&2
      exit 3
    fi
    run_features "${all[@]}" ;;
  *)
    echo "run.sh: unknown tier '${TIER}' (expected b1|b2|b3)" >&2; exit 2 ;;
esac
