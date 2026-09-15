# Behaviour Test Evidence — Story 1.1, Tier B1

**Feature file**: `spec/behavior/story-1.1.feature`
**Step definitions**: `tests/behavior/steps/stage_credential_steps.py` (loaded via `tests/behavior/conftest.py`)
**Runner**: `tests/behavior/test_story_1_1.py` (`pytest-bdd` `scenarios("../../spec/behavior/story-1.1.feature")`)

## Command

```
python3 -m pytest tests/behavior/ -v --tb=short --junitxml=reports/behavior-test-evidence/story-1.1/b1/behavior-test-report.xml
```

## Result

`4 passed, 0 failed` (see `behavior-test-run.log` for raw stdout, `behavior-test-report.xml` for the
machine-readable JUnit report).

| Scenario | Tag | Result |
|---|---|---|
| Stage.sql creates a Storage Integration and binds the stage to it | `@AC-1` | PASS |
| Copy_Into.sql no longer contains any credentials clause | `@AC-2` | PASS |
| Repo-wide search for AWS key literals returns zero matches | `@AC-3` | PASS |
| Edited SQL is syntactically valid Snowflake DDL/DML without a live account | `@AC-4` | PASS |

Every `@AC-n` tag in `story-1.1.feature` was executed and passed. B1 verification criterion satisfied.

## Containerisation — NOT run in Podman for this delegated pass (honest exception, not a gate claim)

`containerised: false`. This story's assigned scope (per the invoking session's explicit instructions)
was to implement and run real pytest-bdd step definitions that statically verify the SQL text/structure
— not to execute the full `common/behavior-spec.md` Section 5 Podman-sandboxed B1/B2/B3 tiered gate,
which is reserved for the invoking session together with Code Review, Remediate, and PR raising. These
tests ran natively via `python3 -m pytest` in this delegated task's environment.

**This evidence manifest does NOT claim the B1 gate (as defined in `common/behavior-spec.md` Section 5/6)
is satisfied.** It records only that: (a) the Gherkin scenarios exist, one per AC; (b) real, executable
step definitions exist for every scenario, asserting on the actual SQL file content; (c) all 4 scenarios
pass when run. The invoking session still owns running these (and B2/B3) inside
`tests/.evals/behavior/run.sh` in Podman, with `AIRE_STORY_KEY=story-1.1`, before the story's B1/B2/B3
gate can be marked satisfied end-to-end.

## Test nature

No live Snowflake or AWS connection is opened by any step. All assertions are static text/pattern
checks against `src/snowflake/Stage.sql` and `src/snowflake/Copy_Into.sql`, consistent with REQ-NF-02
(no live warehouse in this environment).
