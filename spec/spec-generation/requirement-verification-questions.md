# Requirements Clarification Questions — Epic: Harden Pipeline (Security & Data Quality)

Grounded in `spec/plans/atlas-deep-dive.md` (Atlas deep dive, Code Quality & Technical Debt section).
Please answer each question by filling in the letter after `[Answer]:`.

## Question 1
Atlas flags **hard-coded/plaintext credentials** as the top risk: `src/snowflake/Copy_Into.sql` inlines AWS `aws_key_id`/`aws_secret_key` placeholders, and `src/dbt_code/profiles.yml` stores `password` in plaintext. What should this epic do about it?

A) Full fix — replace inline AWS keys with a Snowflake STORAGE INTEGRATION, and move `profiles.yml` secrets to `env_var()` references

B) Partial fix — only move `profiles.yml` secrets to `env_var()`; leave the S3 credential mechanism as-is (documented as follow-up)

C) Documentation only — add clear warnings/README guidance about not committing real secrets, without changing the SQL/config mechanism

D) Out of scope for this epic

E) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 2
Atlas flags **zero data tests** — no `unique`/`not_null`/`relationships`/`accepted_values` schema tests anywhere, despite obvious candidates (PK uniqueness, FK relationships). What test coverage should this epic add?

A) Full coverage — PK uniqueness + not_null on all three entities, relationships (listing_id→listings, host_id→hosts), and accepted_values on status/segment columns

B) Minimal coverage — just PK uniqueness + not_null on the three primary keys

C) Silver-layer only — tests on the cleaned/enriched Silver models only, not Bronze/Gold

D) Out of scope for this epic

E) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 3
Atlas flags `fact.sql` **bypassing `ref()`** — it joins `AIRBNB.GOLD.DIM_LISTINGS`/`DIM_HOSTS` by hard-coded table name instead of `ref('dim_listings')`/`ref('dim_hosts')`, so dbt doesn't model the dependency and run ordering isn't guaranteed. Should this epic fix it?

A) Yes — convert to `ref()` calls so dbt's DAG models the true dependency

B) No — leave as-is; too risky to touch without a live Snowflake environment to validate against

C) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 4
Beyond the top 2 findings, Atlas also lists several **Medium/Low** items (Bronze materialization config conflict between `dbt_project.yml`/`properties.yml` and the model-level override; `NIGHTS_BOOKING` vs `NIGHTS_BOOKED` typo in `analyses/loop.sql`; missing source freshness checks on `sources.yml`; unused `proper_name` macro; `expolore.sql` filename typo; boilerplate `dbt_code/README.md`; root README's "e-commerce" vs actual "hospitality" domain wording). How much of this should this epic cover?

A) All of it — fold every Medium/Low item into this epic's scope alongside the Priority 1/2 items

B) Selected items only — just the Bronze materialization conflict and source freshness (the two with functional/data-quality impact); skip pure typos/docs

C) None of it — this epic is strictly Priority 1/2 (credentials + tests + fact.sql ref()); typos/docs/config-conflicts are separate future work

D) Other (please describe after [Answer]: tag below)

[Answer]: B

## Question 5
This is a portfolio/demo pipeline with **no live Snowflake account** connected (all `profiles.yml`/S3 values are placeholders) and **no CI** currently. What's the validation expectation for this epic's changes?

A) `dbt parse` / `dbt compile` (or equivalent static/dry-run checks) only — no live warehouse run, since no real Snowflake account is available

B) I have (or will set up) a real Snowflake trial/dev account and want changes validated with an actual `dbt run`/`dbt test`

C) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 6
Should this epic also introduce **CI automation** (Atlas Priority 4 — "no CI/CD, no `dbt build`/`dbt test` automation")?

A) Yes — add a GitHub Actions workflow that runs `dbt parse`/`dbt test` (scoped to what's feasible without live credentials) on PRs

B) No — CI/orchestration is out of scope for this epic; focus stays on the security/testing/DAG fixes themselves

C) Other (please describe after [Answer]: tag below)

[Answer]: A
