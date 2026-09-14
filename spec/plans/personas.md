# Personas — Epic: Harden Pipeline (Security & Data Quality)

## Persona 1: Data Engineer

**Role**: Owns, operates, and maintains the Hospitality Analytics Pipeline (Snowflake + dbt Medallion
architecture). Runs the Snowflake bootstrap scripts, executes `dbt run`/`dbt snapshot`, reviews CI
results, and is the sole technical stakeholder for this pipeline's correctness and security posture.

**Characteristics**:
- Comfortable with SQL, dbt, and Snowflake administration (roles, storage integrations, stages)
- Responsible for not leaking credentials and for the pipeline's data quality
- Works without a live production Snowflake account in this environment — validates changes locally
  via `dbt parse`/`dbt compile` before they would ever run against a real warehouse
- Cares about being able to trust the Gold-layer outputs (OBT, fact, dimension snapshots) without
  manually re-checking every model after a change

**Motivations**:
- Eliminate the risk of committing real credentials by mistake
- Catch data-quality regressions (duplicate keys, orphaned foreign keys, unexpected category values)
  automatically instead of discovering them downstream
- Trust that dbt's own dependency graph reflects the real build order, so `dbt run` never fails from
  an out-of-order build
- Get fast, free (no live warehouse) feedback on every pull request

**Relevant to stories**: ALL 8 stories in this epic — this is a single-persona epic (headless data
pipeline, no end-user-facing UI).
