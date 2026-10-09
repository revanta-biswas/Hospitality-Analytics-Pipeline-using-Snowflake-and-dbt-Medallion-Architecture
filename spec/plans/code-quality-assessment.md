# Code Quality Assessment

> Existing-system context derived locally; Atlas was not consulted.

## Test Coverage
- **Overall**: None
- **Unit Tests**: None (dbt tests dir empty; 0 test keys in any yml, measured with grep)
- **Integration Tests**: None

## Code Quality Indicators
- **Linting**: Not configured (no sqlfluff config)
- **Code Style**: Inconsistent (mixed upper/lower-case aliases, e.g. silver_listings vs SILVER_listings)
- **Documentation**: Fair (README only; no model descriptions)

## Technical Debt
- gold/obt.sql and gold/fact.sql use hardcoded `AIRBNB.*` names instead of ref(); breaks lineage
- dbt_code/profiles.yml holds placeholder credentials inside the repo; Snowflake/Copy_Into.sql contains credential placeholders
- analyses/loop.sql references NIGHTS_BOOKING (column is NIGHTS_BOOKED)
- macros/trim.sql defines `proper_name`; file/macro name mismatch
- silver models declare unique_key under table materialization (no effect)
- source schema 'staging' lower-case vs bronze incremental filter on created_at only

## Patterns and Anti-patterns
- **Good Patterns**: layered medallion; incremental bronze; reusable macros; SCD2 snapshots
- **Anti-patterns**: hardcoded relations; no tests; credentials in config files (placeholders)
