# Component Inventory

> Existing-system context derived locally; Atlas was not consulted.

## Application Packages
- dbt_code - dbt transformation project (Bronze/Silver/Gold)

## Infrastructure Packages
- Snowflake (SQL scripts) - ingestion DDL and COPY INTO - stage, file format, tables

## Shared Packages
- dbt_code/macros - 4 macros

## Test Packages
- dbt_code/tests - empty (.gitkeep only); no dbt tests defined

## Total Count
- **Total Packages**: 2
- **Application**: 1
- **Infrastructure**: 1
- **Shared**: 0 (macros live inside dbt_code)
- **Test**: 0
- **dbt models**: 11 (3 bronze, 3 silver, 2 gold, 3 gold ephemeral); 3 snapshots; 4 macros; 3 analyses
