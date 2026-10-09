# Personas

## Data Analyst
- **Role**: Consumes gold-layer tables for reporting, dashboards and KPI tracking.
- **Goals**: See monthly revenue per city and how it changes month over month, with no custom SQL.
- **Frustrations**: Re-deriving aggregates in every dashboard; unclear revenue definitions.
- **Stories**: 1.1, 1.2

## Analytics Engineer
- **Role**: Builds and maintains the dbt project (bronze, silver, gold).
- **Goals**: Models that follow repo conventions, use `ref()` and are covered by tests.
- **Frustrations**: Untested models and hardcoded relations that break lineage.
- **Stories**: 1.3
