# Static Eval Baseline — Story 1.1

**Captured**: 2026-09-14T12:10:00Z (pre-code-change, on `story/1.1-replace-inline-aws-credentials-storage-integration`)
**Story scope**: `src/snowflake/Stage.sql`, `src/snowflake/Copy_Into.sql` (SQL only — no `.py` files touched)

| Gate | Tool | Result | Notes |
|---|---|---|---|
| D1 Lint | ruff (`src/dbt_code src/snowflake`) | PASS — 0 findings | No `.py` files under `sourcePaths` at this time (dbt/SQL-only project); ruff reports "No Python files found" and exits clean. Real, tool-verified result on zero files, not a fabricated N/A. |
| D2 Type check | mypy (`src/dbt_code src/snowflake`) | PASS — 0 findings | Same reason: "There are no .py[i] files in directory". |
| D3 SAST | semgrep --config auto (repo-wide, incl. `src/snowflake`, `src/dbt_code`) | PASS — 0 findings | 82 rules run across 36 tracked files. Raw output: `d3-semgrep.log` / `d3-semgrep-baseline.json`. |
| D4 Dependency vulns | pip-audit | PASS — 0 known vulnerabilities | Raw output: `d4-pip-audit.log`. |
| D5 Licences | pip-licenses | PASS — 0 disallowed licences (no GPL-2.0/GPL-3.0/AGPL-3.0/SSPL-1.0 present) | Raw output: `d5-pip-licenses.log`. |
| D6 Complexity | radon cc (`src/dbt_code src/snowflake`) | PASS — 0 findings | No `.py` files to measure; radon produced empty output. |
| D7 Secrets | gitleaks detect (whole tree, `--no-git`) | 4 pre-existing findings, **none in `src/snowflake/`** | All 4 are `curl-auth-user` matches on `"${SONAR_TOKEN}:"` inside `.github/workflows/agentic-eval-pipeline.yml` (lines 330, 333) and `aire-workflow/templates/ci/agentic-eval-pipeline.yml.template` (lines 309, 312) — CI-pipeline template artifacts from the STOP CHECKPOINT, unrelated to this story's files. Recorded as pre-existing debt per `common/eval-framework.md` Section 2.2 — not fixed, not blocked on. Raw output: `d7-gitleaks.log` / `d7-gitleaks-baseline.json`. |

**Bootstrap**: no new config files created. `pyproject.toml`, no `.gitleaks.toml`/`.semgrepignore` existed
and none were required to run the above tools with their default/recommended presets — all ran
out-of-the-box. Nothing added under "bootstrap" in `eval.json`.

**Ordering**: this baseline was captured BEFORE any SQL edit in this story (bootstrap step N/A — no
new configs needed → baseline → code generation → post-change re-run → diff), per
`common/eval-framework.md` Section 2.2/2.3.
