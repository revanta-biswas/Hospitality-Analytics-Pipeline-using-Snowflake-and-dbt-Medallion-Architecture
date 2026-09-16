# Static Eval Baseline — Story 1.2

Captured: 2026-09-15T10:40:00Z, on story/1.2-externalize-dbt-secrets-env-vars @ epic branch tip (36dd05f, post framework sync)

| Gate | Result |
|---|---|
| D1 Lint (ruff) | 0 .py files under sourcePaths (src/dbt_code, src/snowflake) |
| D2 Type check (mypy) | 0 .py/.pyi files |
| D3 SAST (semgrep) | 0 findings (see d3-semgrep-baseline.json) |
| D4 Dependency vulns (pip-audit) | 0 known vulnerabilities (repo dependency graph unchanged) |
| D5 Licences (pip-licenses) | 0 disallowed licences (unchanged) |
| D6 Complexity (radon) | 0 .py files to measure |
| D7 Secrets (gitleaks) | 4 pre-existing findings (curl-auth-user on ${SONAR_TOKEN} in CI template files) — see d7-gitleaks-baseline.json |
