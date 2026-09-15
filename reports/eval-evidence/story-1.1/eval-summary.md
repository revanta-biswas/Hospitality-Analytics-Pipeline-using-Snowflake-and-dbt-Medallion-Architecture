# Static Eval Summary — Story 1.1

**Static Eval: PASS (11 of 13 checks ran — 4 N/A, see reasons)**

| Gate | Status | Detail |
|---|---|---|
| D1 Lint (ruff) | PASS | 0 `.py` files in `sourcePaths` — real tool-verified result on zero files |
| D2 Type check (mypy) | PASS | 0 `.py`/`.pyi` files |
| D3 SAST (semgrep) | PASS | 0 findings, 82 rules / 36 files |
| D4 Dependency vulns (pip-audit) | PASS | 0 known vulnerabilities |
| D5 Licences (pip-licenses) | PASS | 0 disallowed licences |
| D6 Complexity (radon) | PASS | 0 `.py` files to measure |
| D7 Secrets (gitleaks) | PASS | 4 pre-existing findings unchanged (identical fingerprints, outside `src/snowflake/`) — zero NEW findings |
| Unit Test & Coverage | N/A | No `.py` application code changed by this story |
| Behavioural B1 | PASS | 4/4 scenarios, one per `@AC-1`..`@AC-4`, run containerised (Podman) — `reports/behavior-test-evidence/story-1.1/b1/` |
| Behavioural B2 | N/A | No OTHER story feature file exists yet |
| Behavioural B3 | N/A | Not the last work unit of the cycle |
| API & Contract Testing | N/A | No API layer touched |
| J1 Architecture (judge) | PASS | 1.0 (only ARCH-01 applicable, renormalized) — `reports/eval-evidence/story-1.1/judge/architecture-score.json` |
| J2 Security (judge) | PASS | 1.0 (SEC-01 + SEC-04 applicable, renormalized) — `reports/eval-evidence/story-1.1/judge/security-score.json` |

## Diff methodology

Baseline captured on `story/1.1-...` before any SQL edit (`reports/eval-evidence/story-1.1/static/baseline/`).
Post-change re-run after the `Stage.sql`/`Copy_Into.sql` edits (`reports/eval-evidence/story-1.1/static/`).
D7 findings compared by `Fingerprint` (never line number, per `common/eval-framework.md` Section 2.2) —
confirmed byte-identical between baseline and post-change.

## Generation defects found and fixed during this story's gates

While bringing the Behavioral Test Gate (B1) to a genuine containerised pass, 4 pre-existing generation
defects in the AIRE-templated CI scaffolding (never previously exercised, since the epic-level smoke
test's zero-diff PR legitimately N/A's the whole behavior gate) were found and fixed:
1. `tests/.evals/behavior/Containerfile`'s DEPS slot was missing `sqlparse` (declared in
   `pyproject.toml`'s dev group, used by a step definition) — caught by the FIRST real containerised
   run, which failed with `ModuleNotFoundError` exactly as environment parity is meant to catch.
2. `run.sh`'s `run_features()` (the STACK-RESOLVED BEHAVIOUR RUNNER slot) was unfilled, then — on
   first fix — ignored its own resolved feature-file arguments and ran the whole `tests/behavior/`
   tree regardless of tier.
3. `run_features()` re-fixed to resolve each feature-file argument to its bound `test_<key>.py`
   module and run only those.
4. `run.sh`'s `b2)` case included the current unit's own feature file in "others," which would have
   made B2 silently pass instead of correctly reporting N/A on the epic's first story.

All four are logged in `runtime-artifacts/audit.md` with root cause and fix.
