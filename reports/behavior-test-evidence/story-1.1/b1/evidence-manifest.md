# Behaviour Test Evidence — Story 1.1, Tier B1

**Captured**: 2026-09-15T09:30:00Z
**Containerised**: true
**Image**: `localhost/aire-behavior:local`
**Image ID**: `c8e74779e7f01e1243ed3cf4d748a2bd3dcabb7dfe66275359bdd4ecdfc44259`
**Command**:
```
podman run --rm -v "$PWD:/work:Z" -w /work -e AIRE_STORY_KEY=story-1.1 \
  aire-behavior:local "bash tests/.evals/behavior/run.sh b1"
```

## Note on prior attempt

An earlier, native (non-containerised) run of this story's tests reported the same 4/4 pass, which
initially masked a real environment-parity defect: `tests/.evals/behavior/Containerfile` only
installed `pytest-bdd`, not the full `[dependency-groups.dev]` set from `pyproject.toml` (missing
`sqlparse`, imported by `tests/behavior/steps/stage_credential_steps.py`). The FIRST containerised run
of this tier failed with `ModuleNotFoundError: No module named 'sqlparse'` — exactly the class of
failure environment parity exists to catch (`common/behavior-spec.md` Section 5). Fixed the
Containerfile to install the exact dev dependency group, rebuilt the image, and re-ran. This log/report
reflects the corrected, passing run.

## Result

```
======================== 4 passed, 14 warnings in 0.06s ========================
```

## Scenario / AC coverage

| Scenario | Tag | Result |
|---|---|---|
| Stage.sql creates a Storage Integration and binds the stage to it | @AC-1 | PASS |
| Copy_Into.sql no longer contains any credentials clause | @AC-2 | PASS |
| Repo-wide search for AWS key literals returns zero matches | @AC-3 | PASS |
| Edited SQL is syntactically valid Snowflake DDL/DML without a live account | @AC-4 | PASS |

4/4 scenarios pass. Every `@AC-n` (AC-1 through AC-4) executed.

## Feature-file set (this tier)

- `spec/behavior/story-1.1.feature` (this work unit's own contract only — B1 scope)

## Raw artifacts

- `behavior-test-run.log` — full stdout/stderr from the containerised run
- `behavior-test-report.xml` — machine-readable JUnit XML (pytest `--junitxml`)
