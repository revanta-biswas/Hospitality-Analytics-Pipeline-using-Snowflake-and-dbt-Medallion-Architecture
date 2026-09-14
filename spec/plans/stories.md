EPIC TICKET: https://github.com/revanta-biswas/Hospitality-Analytics-Pipeline-using-Snowflake-and-dbt-Medallion-Architecture/milestone/1 (Milestone #1 — "Epic: Harden Pipeline (Security & Data Quality)")

# Stories — Epic: Harden Pipeline (Security & Data Quality)

Persona: **Data Engineer** (see `personas.md`). All stories are static/dry-run verifiable — no live
Snowflake account or AWS credentials exist in this environment (REQ-NF-02).

---

## Story 1.1 — Replace inline AWS credentials with a Snowflake Storage Integration

**Tracker ID**: [#1](https://github.com/revanta-biswas/Hospitality-Analytics-Pipeline-using-Snowflake-and-dbt-Medallion-Architecture/issues/1)

**As a** Data Engineer
**I want** the S3 ingestion stage to authenticate via a Snowflake Storage Integration instead of inline AWS keys
**So that** no AWS credential — real or placeholder — is ever inlined in committed SQL

**Covers**: REQ-F-01, REQ-NF-01, REQ-NF-02

**Acceptance Criteria**:
1. `src/snowflake/Stage.sql` creates (or references) a `STORAGE INTEGRATION` object and the external stage `s3_stage` is created `URL=...` bound to that integration — no `credentials=(aws_key_id=... aws_secret_key=...)` clause anywhere in the stage DDL. *(AC-1 → REQ-F-01)*
2. `src/snowflake/Copy_Into.sql`'s `COPY INTO` statements no longer contain any `credentials=(...)` clause — they rely solely on the stage's storage integration. *(AC-2 → REQ-F-01)*
3. A repo-wide search for `aws_key_id` / `aws_secret_key` / `AWS_KEY_ID` / `AWS_SECRET_KEY` inside `src/snowflake/*.sql` returns zero matches. *(AC-3 → REQ-NF-01)*
4. The edited SQL files are valid Snowflake DDL/DML syntax, confirmed by static review (no live Snowflake account is available to execute them). *(AC-4 → REQ-NF-02)*

---

## Story 1.2 — Externalize dbt connection secrets via environment variables

**Tracker ID**: [#2](https://github.com/revanta-biswas/Hospitality-Analytics-Pipeline-using-Snowflake-and-dbt-Medallion-Architecture/issues/2)

**As a** Data Engineer
**I want** `profiles.yml` to read every connection secret from an environment variable
**So that** no plaintext credential value can ever be committed to the repo

**Covers**: REQ-F-02, REQ-NF-01, REQ-NF-02

**Acceptance Criteria**:
1. `src/dbt_code/profiles.yml`'s `account`, `user`, `password`, `role`, and `warehouse` fields are each replaced with `{{ env_var('DBT_<FIELD>') }}` references (e.g. `{{ env_var('DBT_SNOWFLAKE_PASSWORD') }}`). *(AC-1 → REQ-F-02)*
2. `schema` and `threads`/`type`/`target` may remain literal (non-secret operational values). *(AC-2 → REQ-F-02)*
3. The required environment variable names are documented (in `src/dbt_code/README.md` or a new `.env.example` at the dbt project root) so a future run knows what to set. *(AC-3 → REQ-F-02)*
4. A repo-wide search for a literal password/account/user value in `profiles.yml` after the change returns zero matches — only `env_var()` calls remain for secret fields. *(AC-4 → REQ-NF-01)*
5. `profiles.yml` remains valid YAML, confirmed by static parse (no live Snowflake account is available to execute a real connection). *(AC-5 → REQ-NF-02)*

---

## Story 1.3 — Add core data integrity tests (uniqueness, not-null, referential integrity)

**Tracker ID**: [#3](https://github.com/revanta-biswas/Hospitality-Analytics-Pipeline-using-Snowflake-and-dbt-Medallion-Architecture/issues/3)

**As a** Data Engineer
**I want** dbt schema tests enforcing primary-key uniqueness/not-null and foreign-key relationships
**So that** duplicate keys or orphaned references are caught automatically instead of silently propagating to Gold

**Covers**: REQ-F-03, REQ-F-04, REQ-NF-02

**Acceptance Criteria**:
1. `unique` + `not_null` tests are declared for `LISTING_ID` on `silver_listings`. *(AC-1 → REQ-F-03)*
2. `unique` + `not_null` tests are declared for `HOST_ID` on `silver_hosts`. *(AC-2 → REQ-F-03)*
3. `unique` + `not_null` tests are declared for `BOOKING_ID` on `silver_bookings`. *(AC-3 → REQ-F-03)*
4. A `relationships` test validates `silver_bookings.listing_id` → `silver_listings.LISTING_ID`, and another validates `silver_bookings.host_id` → `silver_hosts.HOST_ID`. *(AC-4 → REQ-F-04)*
5. All new test definitions pass `dbt parse` (structurally valid YAML resolving to real models/columns) — no live `dbt test` run is required or expected, since no warehouse is available. *(AC-5 → REQ-NF-02)*

---

## Story 1.4 — Add accepted-values tests for derived categorical columns

**Tracker ID**: [#4](https://github.com/revanta-biswas/Hospitality-Analytics-Pipeline-using-Snowflake-and-dbt-Medallion-Architecture/issues/4)

**As a** Data Engineer
**I want** dbt schema tests constraining the derived category columns to their documented value sets
**So that** an unexpected category value (e.g. from a `segment()` macro change) is caught immediately

**Covers**: REQ-F-05, REQ-NF-02

**Acceptance Criteria**:
1. An `accepted_values` test on `silver_listings.PRICE_PER_NIGHT_TAG` constrains it to exactly the values the `segment()` macro can produce (Budget / Mid-range / Luxury). *(AC-1 → REQ-F-05)*
2. An `accepted_values` test on `silver_hosts.RESPONSE_RATE_QUALITY` constrains it to exactly the values that column's derivation logic can produce (VERY GOOD / GOOD / FAIR / POOR). *(AC-2 → REQ-F-05)*
3. Both tests pass `dbt parse` (structurally valid, referencing real models/columns) — no live `dbt test` run required. *(AC-3 → REQ-NF-02)*

---

## Story 1.5 — Fix `fact.sql` to depend on dimension snapshots via `ref()`

**Tracker ID**: [#5](https://github.com/revanta-biswas/Hospitality-Analytics-Pipeline-using-Snowflake-and-dbt-Medallion-Architecture/issues/5)

**As a** Data Engineer
**I want** `fact.sql` to reference `dim_listings`/`dim_hosts` through dbt's `ref()` function
**So that** dbt's DAG models the true build dependency and never builds `fact` before its dimensions exist

**Covers**: REQ-F-06, REQ-NF-03, REQ-NF-02

**Acceptance Criteria**:
1. `src/dbt_code/models/gold/fact.sql`'s join to the listings dimension uses `{{ ref('dim_listings') }}` instead of the literal `AIRBNB.GOLD.DIM_LISTINGS`. *(AC-1 → REQ-F-06)*
2. The same file's join to the hosts dimension uses `{{ ref('dim_hosts') }}` instead of the literal `AIRBNB.GOLD.DIM_HOSTS`. *(AC-2 → REQ-F-06)*
3. The selected columns and join logic (keys, join type) are otherwise unchanged — only the table-reference mechanism changes, not `fact`'s output shape. *(AC-3 → REQ-NF-03)*
4. `dbt parse`/`dbt compile` confirms `fact.sql` now resolves `ref('dim_listings')`/`ref('dim_hosts')` to the snapshot models, and that dbt's DAG shows `fact` depending on both snapshots — verified statically, no live run. *(AC-4 → REQ-NF-02)*

---

## Story 1.6 — Reconcile the Bronze materialization configuration conflict

**Tracker ID**: [#6](https://github.com/revanta-biswas/Hospitality-Analytics-Pipeline-using-Snowflake-and-dbt-Medallion-Architecture/issues/6)

**As a** Data Engineer
**I want** Bronze's materialization declared in exactly one place
**So that** `dbt_project.yml`/`properties.yml` no longer contradict the models' actual `incremental` behavior

**Covers**: REQ-F-07, REQ-NF-03, REQ-NF-02

**Acceptance Criteria**:
1. `src/dbt_code/dbt_project.yml`'s Bronze config no longer declares `+materialized: table` where the intent is `incremental` — it is corrected to match actual model-level behavior (or removed, deferring entirely to model-level config, whichever keeps exactly one source of truth). *(AC-1 → REQ-F-07)*
2. `src/dbt_code/models/properties.yml`'s Bronze materialization declarations are likewise corrected to match, so no file contradicts another. *(AC-2 → REQ-F-07)*
3. Each `bronze_*.sql` model's own `{{ config(materialized='incremental') }}` is unchanged — this story reconciles the surrounding config files to agree with the models, not the other way around, so no behavior changes. *(AC-3 → REQ-NF-03)*
4. `dbt parse` confirms the project config still loads cleanly after the change. *(AC-4 → REQ-NF-02)*

---

## Story 1.7 — Add source freshness checks to the staging source

**Tracker ID**: [#7](https://github.com/revanta-biswas/Hospitality-Analytics-Pipeline-using-Snowflake-and-dbt-Medallion-Architecture/issues/7)

**As a** Data Engineer
**I want** freshness thresholds declared on the three staging source tables
**So that** stale staging data is flagged instead of silently flowing through Bronze/Silver/Gold

**Covers**: REQ-F-08, REQ-NF-02

**Acceptance Criteria**:
1. `src/dbt_code/models/sources/sources.yml` declares a `loaded_at_field` for each of `listings`, `hosts`, and `bookings`. *(AC-1 → REQ-F-08)*
2. Each table declares a `freshness` block with `warn_after`/`error_after` count/period values. *(AC-2 → REQ-F-08)*
3. `dbt parse` confirms `sources.yml` remains valid YAML and the new freshness blocks are structurally correct — `dbt source freshness` itself is NOT required to run live (needs warehouse access this environment doesn't have). *(AC-3 → REQ-NF-02)*

---

## Story 1.8 — Add a static-validation CI workflow

**Tracker ID**: [#8](https://github.com/revanta-biswas/Hospitality-Analytics-Pipeline-using-Snowflake-and-dbt-Medallion-Architecture/issues/8)

**As a** Data Engineer
**I want** every pull request to automatically run `dbt parse`/`dbt compile` against the project
**So that** structural regressions (broken refs, invalid YAML, non-compiling SQL) are caught before merge, without needing a live Snowflake account

**Covers**: REQ-F-09, REQ-NF-04

**Acceptance Criteria**:
1. A new GitHub Actions workflow (e.g. `.github/workflows/dbt-static-checks.yml`) triggers on `pull_request`. *(AC-1 → REQ-F-09)*
2. The workflow installs the pinned Python/dbt toolchain from `pyproject.toml`/`uv.lock` (e.g. via `uv sync`). *(AC-2 → REQ-F-09)*
3. The workflow runs `dbt parse` against `src/dbt_code/` and fails the job if parsing fails. *(AC-3 → REQ-F-09)*
4. The workflow runs `dbt compile` against `src/dbt_code/` and fails the job if any model fails to compile — this exercises Stories 1.1–1.7's changes (including the new `ref()` calls and schema tests) without needing real Snowflake credentials, using a dummy/CI-only `profiles.yml` target that never connects to a live warehouse. *(AC-4 → REQ-F-09, REQ-NF-04)*
5. The workflow requires no secret, credential, or paid external service to run. *(AC-5 → REQ-NF-04)*

**Note**: This story is sequenced last — it validates the combined output of Stories 1.1–1.7, so it
depends on all of them (see Dependency Graph stage next).

---

## Requirements Coverage Matrix

| REQ-ID | Covering Stories | Status |
|---|---|---|
| REQ-F-01 | 1.1 | Full |
| REQ-F-02 | 1.2 | Full |
| REQ-F-03 | 1.3 | Full |
| REQ-F-04 | 1.3 | Full |
| REQ-F-05 | 1.4 | Full |
| REQ-F-06 | 1.5 | Full |
| REQ-F-07 | 1.6 | Full |
| REQ-F-08 | 1.7 | Full |
| REQ-F-09 | 1.8 | Full |
| REQ-NF-01 | 1.1, 1.2 | Full |
| REQ-NF-02 | 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7 | Full |
| REQ-NF-03 | 1.5, 1.6 | Full |
| REQ-NF-04 | 1.8 | Full |

**Coverage: 13/13 REQ-IDs fully covered by story ACs.**

## Story Granularity Check

All 8 stories: ≤ 5 ACs each (max is 5, in Stories 1.1/1.2/1.6... — actually max is 5 in Story 1.2 and
Story 1.8), touch exactly one architectural layer each (SQL config / dbt YAML / CI workflow), no title
conjunctions, one scenario class per story (each is a single hardening concern). **0 ceiling
violations.**
