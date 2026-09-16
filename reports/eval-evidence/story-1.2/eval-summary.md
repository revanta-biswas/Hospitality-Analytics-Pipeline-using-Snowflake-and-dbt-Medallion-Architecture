# Static Eval Summary — Story 1.2

**Static Eval: PASS (8 of 13 checks ran — 5 N/A, see reasons)**

| Gate | Status | Detail |
|---|---|---|
| D1 Lint (ruff) | PASS | 0 `.py` files in `sourcePaths` |
| D2 Type check (mypy) | PASS | 0 `.py`/`.pyi` files |
| D3 SAST (semgrep) | PASS | 0 findings, baseline and post-change |
| D4 Dependency vulns (pip-audit) | PASS | 0 known vulnerabilities |
| D5 Licences (pip-licenses) | PASS | 0 disallowed licences |
| D6 Complexity (radon) | PASS | 0 `.py` files to measure |
| D7 Secrets (gitleaks) | PASS | 4 pre-existing findings unchanged (identical fingerprints, outside `src/dbt_code/`); independently verified `src/dbt_code/` scans clean |
| Unit Test & Coverage | N/A | No `.py` application code changed |
| Behavioural B1 | PASS | 5/5 scenarios, one per `@AC-1`..`@AC-5`, run containerised (Podman) — `reports/behavior-test-evidence/story-1.2/b1/` |
| Behavioural B2 | N/A | No OTHER story feature file exists yet |
| Behavioural B3 | N/A | Not the last work unit of the cycle |
| API & Contract Testing | N/A | No API layer touched |
| Test Placement Verification | N/A | `check-test-placement.{sh,ps1}` template not yet generated (framework-infrastructure gap, logged, non-blocking) |

## Diff methodology

Baseline captured on `story/1.2-...` before any edit (`reports/eval-evidence/story-1.2/static/baseline/`).
Post-change re-run after the `profiles.yml`/`README.md` edits (`reports/eval-evidence/story-1.2/static/`).
D7 findings compared by `Fingerprint` (never line number) — confirmed byte-identical between baseline
and post-change, and independently re-verified via a `src/dbt_code/`-scoped scan.
