# Behaviour Test Evidence — Story 1.2, Tier B1

**Captured**: 2026-09-15T10:55:00Z
**Containerised**: true
**Image**: `localhost/aire-behavior:local`
**Image ID**: `20c0a061be1dc9ca94297e57417158d8b00d94d067f52254e4907d85ac3b19cd`
**Command**:
```
podman run --rm -v "$PWD:/work:Z" -w /work -e AIRE_STORY_KEY=story-1.2 \
  aire-behavior:local "bash tests/.evals/behavior/run.sh b1"
```

## Result

```
======================== 5 passed, 25 warnings in 0.04s ========================
```

## Scenario / AC coverage

| Scenario | Tag | Result |
|---|---|---|
| account, user, password, role, and warehouse are env_var references | @AC-1 | PASS |
| schema, threads, and type remain literal | @AC-2 | PASS |
| required environment variable names are documented | @AC-3 | PASS |
| repo-wide search for a literal secret value returns zero matches | @AC-4 | PASS |
| profiles.yml remains valid YAML | @AC-5 | PASS |

5/5 scenarios pass. Every `@AC-n` (AC-1 through AC-5) executed.

## Note on AC-2 scenario adjustment

The original scenario draft asserted a 4th field ("target") alongside schema/threads/type, which
failed on first native run: `target: dev` is a top-level key under `dbt_code:` (dbt's output
selector), not a field inside `outputs.dev` alongside the connection parameters — it was never a
literal-vs-env_var candidate at all. Corrected the scenario to assert only the fields that actually
live in `outputs.dev` (schema, threads, type). See `spec/spec-generation/story-1.2-code-generation.md`
for the full note.

## Feature-file set (this tier)

- `spec/behavior/story-1.2.feature` (this work unit's own contract only — B1 scope)

## Raw artifacts

- `behavior-test-run.log` — full stdout/stderr from the containerised run
- `behavior-test-report.xml` — machine-readable JUnit XML (pytest `--junitxml`)
