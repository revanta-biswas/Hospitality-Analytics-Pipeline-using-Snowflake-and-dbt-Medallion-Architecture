EPIC TICKET: none (LOCAL) - Add gold/agg_monthly_revenue.sql: monthly revenue by city with month-over-month growth via LAG(); see spec/plans/epic-brief.md

# User Stories

## Story 1.1: Monthly revenue by city model
**As a** Data Analyst, **I want** a gold model that totals booking revenue per month and city, **so that** I can see revenue trends by city without writing my own aggregation.
**Persona**: Data Analyst
**Requires**: none
**Covers**: REQ-F-01, REQ-F-02, REQ-F-05 (columns month, city, revenue), REQ-F-06, REQ-NF-01, REQ-NF-02, REQ-NF-03, REQ-NF-04
**Acceptance Criteria**
- AC-1: `dbt_code/models/gold/agg_monthly_revenue.sql` exists and reads only from `{{ ref('obt') }}`, with no hardcoded `AIRBNB.*` relation names. (REQ-F-01, REQ-NF-01)
- AC-2: The model returns exactly one row per `DATE_TRUNC('month', BOOKING_DATE)` and `CITY` combination; country is not part of the grain. (REQ-F-01, REQ-F-05)
- AC-3: `revenue` equals `SUM(TOTAL_AMOUNT)` for that month and city, includes bookings of every status, and excludes SERVICE_FEE and CLEANING_FEE, without double counting. (REQ-F-02, REQ-NF-04)
- AC-4: The output columns are `month`, `city`, `revenue`, and the model builds as a table in schema `gold` through the existing folder config, with no model-level override. (REQ-F-05, REQ-F-06)
- AC-5: `dbt parse` and `dbt compile` succeed for the model, and no credentials or secrets are added to any file. (REQ-NF-02, REQ-NF-03)

## Story 1.2: Month-over-month revenue growth columns
**As a** Data Analyst, **I want** each city-month row to show the previous month's revenue and the percentage growth, **so that** I can spot growth and decline directly.
**Persona**: Data Analyst
**Requires**: 1.1
**Covers**: REQ-F-03, REQ-F-04, REQ-F-05 (final column contract), REQ-NF-04
**Acceptance Criteria**
- AC-1: `previous_month_revenue` is `LAG(revenue) OVER (PARTITION BY city ORDER BY month)`; months with no bookings are not filled, so it is the prior existing row for that city. (REQ-F-03)
- AC-2: `previous_month_revenue` is NULL for a city's first month. (REQ-F-03)
- AC-3: `mom_growth_pct` equals `(revenue - previous_month_revenue) / previous_month_revenue * 100`, rounded to 2 decimals. (REQ-F-04)
- AC-4: `mom_growth_pct` is NULL, with no division-by-zero error, when `previous_month_revenue` is NULL or zero. (REQ-F-04, REQ-NF-04)
- AC-5: The final output columns are exactly `month`, `city`, `revenue`, `previous_month_revenue`, `mom_growth_pct`. This story owns the seam with Story 1.1's three-column contract. (REQ-F-05)

## Story 1.3: Data quality tests for agg_monthly_revenue
**As an** Analytics Engineer, **I want** automated tests on the new model, **so that** regressions in grain or growth math are caught.
**Persona**: Analytics Engineer
**Requires**: 1.2
**Covers**: REQ-F-07, REQ-NF-02
**Acceptance Criteria**
- AC-1: A schema yml declares `not_null` tests on `month`, `city` and `revenue` for `agg_monthly_revenue`. (REQ-F-07)
- AC-2: A singular test in `dbt_code/tests/` fails when any (month, city) pair appears more than once; it is plain SQL because `dbt_utils` is not installed in this project. (REQ-F-07)
- AC-3: A singular test recomputes month-over-month growth independently from `ref('obt')` and fails when it differs from `mom_growth_pct`. (REQ-F-07)
- AC-4: All new tests pass `dbt parse` and `dbt compile`. (REQ-NF-02)
- AC-5: Tests run in `dbt test` only where a Snowflake connection exists; the story records that execution was not possible in this cycle if no connection is available. (REQ-NF-02)

## Requirements Coverage Matrix
| REQ-ID | Covering stories | Status |
|---|---|---|
| REQ-F-01 | 1.1 | Full |
| REQ-F-02 | 1.1 | Full |
| REQ-F-03 | 1.2 | Full |
| REQ-F-04 | 1.2 | Full |
| REQ-F-05 | 1.1 (month, city, revenue), 1.2 (full five-column contract) | Full |
| REQ-F-06 | 1.1 | Full |
| REQ-F-07 | 1.3 | Full |
| REQ-NF-01 | 1.1 | Full |
| REQ-NF-02 | 1.1, 1.3 | Full |
| REQ-NF-03 | 1.1 | Full |
| REQ-NF-04 | 1.1, 1.2 | Full |
