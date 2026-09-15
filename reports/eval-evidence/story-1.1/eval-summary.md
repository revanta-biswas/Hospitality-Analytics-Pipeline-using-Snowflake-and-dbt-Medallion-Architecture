# Static Eval Summary — Story 1.1

**Static Eval: PASS (8 of 10 checks ran — 2 N/A, see reasons)**

| Gate | Status | Detail |
|---|---|---|
| D1 Lint (ruff) | PASS | 0 `.py` files in `sourcePaths` — real tool-verified result on zero files |
| D2 Type check (mypy) | PASS | 0 `.py`/`.pyi` files |
| D3 SAST (semgrep) | PASS | 0 findings, 82 rules / 36 files |
| D4 Dependency vulns (pip-audit) | PASS | 0 known vulnerabilities |
| D5 Licences (pip-licenses) | PASS | 0 disallowed licences |
| D6 Complexity (radon) | PASS | 0 `.py` files to measure |
| D7 Secrets (gitleaks) | PASS | 4 pre-existing findings unchanged (identical fingerprints, outside `src/snowflake/`) — **zero NEW findings** |
| Unit Test & Coverage | N/A | No `.py` application code changed by this story |
| Behavioural B1 | PASS | 4/4 scenarios, one per `@AC-1`..`@AC-4` — see `reports/behavior-test-evidence/story-1.1/b1/` |
| API & Contract Testing | N/A | No API layer touched |

## Diff methodology

Baseline captured on `story/1.1-...` before any SQL edit (`reports/eval-evidence/story-1.1/static/baseline/`).
Post-change re-run after the `Stage.sql`/`Copy_Into.sql` edits (`reports/eval-evidence/story-1.1/static/`).
D7 findings compared by `Fingerprint` (never line number, per `common/eval-framework.md` Section 2.2) —
confirmed byte-identical between baseline and post-change.

## Explicitly out of scope for this pass

Per the invoking session's instructions: Code Review, Remediate, PR raising, and the J1/J2 judge gates
are NOT executed here and are NOT included in this scorecard's `overall` verdict. `overall: PASS` above
covers only the Static Eval Gate (D1-D7) plus the B1 behavioural tier as implemented in this delegated
task.
