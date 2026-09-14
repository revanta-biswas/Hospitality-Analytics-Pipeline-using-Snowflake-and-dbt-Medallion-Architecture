# Requirements — Epic: Harden Pipeline (Security & Data Quality)

## Intent Analysis Summary

- **User request**: Harden the Hospitality Analytics Pipeline (Snowflake + dbt Medallion) against the
  debt Atlas's deep-dive analysis identified — hard-coded/plaintext credentials, zero data tests, a
  `ref()`-bypassing hard dependency in `fact.sql`, and related config/data-quality inconsistencies.
- **Request type**: Refactoring + Enhancement (security hardening, test coverage, DAG-integrity fix,
  CI introduction) on an existing brownfield system. No new business features.
- **Scope estimate**: Multiple components — touches `src/dbt_code/profiles.yml`,
  `src/snowflake/Copy_Into.sql`, `src/dbt_code/models/sources/sources.yml`, `src/dbt_code/models/gold/fact.sql`,
  `src/dbt_code/dbt_project.yml` / `properties.yml`, new schema-test YAML across Bronze/Silver/Gold, and a
  new CI workflow. No UI, no new data domains.
- **Complexity estimate**: Moderate — no single change is architecturally complex, but the changes span
  several components and introduce a first CI/test-automation layer where none existed.
- **Depth applied**: Standard (brownfield, existing Atlas grounding, clarifying questions asked and
  answered — see Q&A below).

## Grounding

- **Existing-system truth**: `spec/plans/atlas-deep-dive.md` (Atlas via Helix MCP, pulled 2026-09-14).
  Every requirement below traces to a specific finding in that document's "Code Quality & Technical
  Debt" and "Recommendations" sections.
- **Context Project artifacts**: none (user declined both Existing Knowledge and New References at
  Workspace Detection).
- **Design References**: none registered.
- **Clarifying questions**: `spec/spec-generation/requirement-verification-questions.md` — 6 questions,
  all answered 2026-09-14T08:07:00Z (Q1=A, Q2=A, Q3=A, Q4=B, Q5=A, Q6=A). No contradictions found.

## Constraints Established by Answers

- **No live Snowflake account or S3 bucket is available** (Q5=A) — every change in this epic must be
  verifiable **statically**: `dbt parse`, `dbt compile`, YAML/SQL syntax and reference validity. No
  story in this epic may require a live `dbt run`/`dbt test`/`dbt snapshot` execution against a real
  warehouse to be considered done.
- **Scope is bounded** (Q4=B): only Medium/Low findings with functional or data-quality impact are
  in scope (Bronze materialization config conflict, missing source freshness). Pure typo/doc-only
  findings (`NIGHTS_BOOKING` typo, `expolore.sql` filename, boilerplate `dbt_code/README.md`, the root
  README's "e-commerce" wording) are explicitly **out of scope** for this epic.

---

## Functional Requirements

### REQ-F-01 — Replace inline AWS credentials in the Snowflake ingestion bootstrap with a Storage Integration
**Source**: atlas-deep-dive.md, Technical Debt #1 (🔴 High), Recommendations Priority 1 #1.
`src/snowflake/Copy_Into.sql` currently inlines `aws_key_id`/`aws_secret_key` placeholders in the
`COPY INTO` statements. Replace this pattern with a Snowflake **STORAGE INTEGRATION** object bound to
the external stage (`src/snowflake/Stage.sql`), so no AWS credential of any kind is ever inlined in SQL.
- The stage DDL must reference the storage integration instead of embedding keys.
- The `COPY INTO` statements must no longer contain `credentials=(aws_key_id=... aws_secret_key=...)`.
- Must be expressed so it can be statically reviewed (valid SQL) without a live AWS/Snowflake account.

### REQ-F-02 — Externalize dbt connection secrets via environment variables
**Source**: atlas-deep-dive.md, Technical Debt #1 (🔴 High), Recommendations Priority 1 #1.
`src/dbt_code/profiles.yml` currently stores `password` (and other connection fields) as plaintext
placeholder values. Convert every secret-bearing field to `{{ env_var('...') }}` references so no
credential value — placeholder or real — is ever committed in plaintext.
- At minimum: `account`, `user`, `password`, `role`, `warehouse` become `env_var()` lookups.
- Document the required environment variable names (e.g. in `src/dbt_code/README.md` or a `.env.example`).

### REQ-F-03 — Add dbt schema tests for primary-key uniqueness and non-null constraints
**Source**: atlas-deep-dive.md, Technical Debt #2 (🔴 High), Recommendations Priority 1 #2; user
answer Q2=A (full coverage).
Add `unique` + `not_null` dbt tests for the three natural primary keys:
- `LISTING_ID` on `silver_listings` (and/or `bronze_listings`, per dbt convention for where PKs are
  first guaranteed unique)
- `HOST_ID` on `silver_hosts`
- `BOOKING_ID` on `silver_bookings`

### REQ-F-04 — Add dbt relationship (referential integrity) tests
**Source**: atlas-deep-dive.md, Technical Debt #2 (🔴 High); user answer Q2=A.
Add `relationships` tests validating:
- `silver_bookings.listing_id` → `silver_listings.LISTING_ID`
- `silver_bookings.host_id` → `silver_hosts.HOST_ID`

### REQ-F-05 — Add dbt `accepted_values` tests on categorical/derived columns
**Source**: atlas-deep-dive.md, Technical Debt #2 (🔴 High); user answer Q2=A.
Add `accepted_values` tests on the derived categorical columns produced by the `segment()` and
response-rate-quality logic:
- `silver_listings.PRICE_PER_NIGHT_TAG` (Budget / Mid-range / Luxury, per the `segment()` macro's
  documented output values)
- `silver_hosts.RESPONSE_RATE_QUALITY` (VERY GOOD / GOOD / FAIR / POOR)

### REQ-F-06 — Fix `fact.sql` to use `ref()` instead of hard-coded table names
**Source**: atlas-deep-dive.md, Technical Debt #3 (🟠 Medium), Dependency Health section; user answer
Q3=A.
`src/dbt_code/models/gold/fact.sql` must reference the dimension snapshots via `ref('dim_listings')`
and `ref('dim_hosts')` instead of the literal `AIRBNB.GOLD.DIM_LISTINGS` / `AIRBNB.GOLD.DIM_HOSTS`
table names, so dbt's DAG models the true dependency and enforces correct build ordering
(snapshots before `fact`).

### REQ-F-07 — Resolve the Bronze materialization configuration conflict
**Source**: atlas-deep-dive.md, Technical Debt #5 (🟠 Medium); user answer Q4=B (selected
functional/data-quality items in scope).
`dbt_project.yml` and `properties.yml` both declare Bronze models as `+materialized: table`, while
every Bronze model file overrides to `incremental`. Reconcile these into a single, consistent
declaration point (the model-level `incremental` config should be the sole source of truth; remove or
correct the misleading `table` declarations in `dbt_project.yml` and `properties.yml` so config no
longer contradicts actual behavior).

### REQ-F-08 — Add source freshness checks to `sources.yml`
**Source**: atlas-deep-dive.md, Technical Debt #6 (🟠 Medium); user answer Q4=B.
Add a `loaded_at_field` and `freshness` (`warn_after`/`error_after`) block to the `staging` source
definition in `src/dbt_code/models/sources/sources.yml` for all three tables, so stale staging data is
detected rather than silently passing through.

### REQ-F-09 — Introduce a CI workflow that statically validates the dbt project
**Source**: atlas-deep-dive.md, Technical Debt #11 (🟡 Low) / Recommendations Priority 4 #9; user
answers Q5=A + Q6=A.
Add a GitHub Actions workflow that runs on pull requests and, at minimum:
- Installs the pinned Python/dbt toolchain (`uv sync` or equivalent, per `pyproject.toml`/`uv.lock`)
- Runs `dbt parse` (validates the project loads, all `ref()`/`source()` calls resolve, YAML is valid)
- Runs `dbt compile` (validates every model, including `fact.sql` after REQ-F-06 and the new schema
  tests after REQ-F-03..05, compiles to valid SQL)
- Does **not** attempt `dbt run`/`dbt test`/`dbt snapshot` against a live warehouse — no Snowflake
  credentials are available in this environment (constraint from Q5=A)

---

## Non-Functional Requirements

### REQ-NF-01 — No plaintext or hard-coded secrets in version control
**Source**: atlas-deep-dive.md Technical Debt #1; user answer Q1=A.
After REQ-F-01/REQ-F-02, no committed file may contain a real or placeholder credential value in a
form indistinguishable from a real secret (i.e., placeholder values must be replaced by `env_var()`/
storage-integration references, not merely relabeled placeholder strings).

### REQ-NF-02 — All changes must be statically verifiable without live infrastructure
**Source**: user answer Q5=A (explicit constraint — no live Snowflake account or AWS credentials exist
in this environment).
Every story in this epic must define its "done" state in terms of `dbt parse`/`dbt compile`/SQL-syntax
validation and/or dbt's own test-definition validation (`dbt test --store-failures=false --select
... --defer` style dry checks where applicable) — never a requirement to execute against a live
warehouse.

### REQ-NF-03 — Backward-compatible schema and behavior
**Source**: implicit from brownfield hardening scope — no functional/business behavior change was
requested.
None of REQ-F-01 through REQ-F-09 may change the shape or values of `OBT`, `fact`, or the snapshot
dimension outputs as consumed by any downstream reporting — this is a hardening epic, not a schema
migration. (`fact.sql`'s `ref()` fix changes *how* it depends on the dims, not *what* it selects.)

### REQ-NF-04 — CI runtime and cost boundaries
**Source**: user answer Q6=A, scoped by Q5=A.
The CI workflow (REQ-F-09) must not require any secret, credential, or paid external service to run —
it operates purely on the repository's own SQL/YAML/Python content.

---

## Requirements Coverage Note

This is an epic-level `requirements.md`; the `## Requirements Coverage Matrix` (Rule 3 of
`common/requirements-traceability.md`) is produced in `stories.md` at the User Stories stage
immediately following this document's approval.

## Out of Scope (explicitly, per Q4=B)

- `NIGHTS_BOOKING` vs `NIGHTS_BOOKED` typo in `dbt_code/analyses/loop.sql` (Technical Debt #4, 🟠 —
  reclassified out of scope by the user as a non-functional analysis-file typo, not a build-affecting
  issue)
- `expolore.sql` filename typo (Technical Debt #7, 🟡)
- Boilerplate `dbt_code/README.md` (Technical Debt #8, 🟡)
- Unused `proper_name` macro (Technical Debt #9, 🟡)
- Root README's "e-commerce" vs "hospitality" domain wording (Technical Debt #10, 🟡)
