# Technology Stack

> Existing-system context derived locally; Atlas was not consulted.

## Programming Languages
- SQL (Snowflake dialect) with Jinja - all models
- Python >=3.12 - tooling only (pyproject.toml)

## Frameworks
- dbt-core >=1.11.7 - transformation
- dbt-snowflake >=1.11.3 - adapter

## Infrastructure
- Snowflake - warehouse (database AIRBNB)
- AWS S3 - raw CSV storage

## Build Tools
- uv (uv.lock) - dependency management

## Testing Tools
- none configured (no dbt tests, no pytest tests; .pytest_cache present but untracked)
