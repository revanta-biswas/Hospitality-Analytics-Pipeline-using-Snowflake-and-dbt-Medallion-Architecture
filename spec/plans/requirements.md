# Requirements

## Intent Analysis
- **User request**: "gold/agg_monthly_revenue.sql would group by DATE_TRUNC('month', BOOKING_DATE) and city, adding month-over-month growth with LAG()."
- **Request type**: New Feature
- **Scope estimate**: Single Component (one new dbt model plus its tests config)
- **Complexity estimate**: Simple
- **Depth**: Standard
- **Existing-system context**: derived locally; Atlas was not consulted (`spec/plans/atlas-deep-dive.md`).
- **Context Project artifacts consulted**: none (Existing Knowledge: No). New References consulted: none. Design references: none.

## Functional Requirements
- **REQ-F-01**: Add a dbt model at `dbt_code/models/gold/agg_monthly_revenue.sql` that reads from `{{ ref('obt') }}` and returns one row per (month, city), where month = `DATE_TRUNC('month', BOOKING_DATE)` and city = `CITY`.
- **REQ-F-02**: Revenue per row is `SUM(TOTAL_AMOUNT)` (booking revenue, excluding SERVICE_FEE and CLEANING_FEE). All booking statuses are included; no status filtering.
- **REQ-F-03**: Each row carries the previous month's revenue for the same city, computed with `LAG(revenue) OVER (PARTITION BY city ORDER BY month)`. Months with no bookings are not filled; the previous value is the prior row that exists for that city.
- **REQ-F-04**: Each row carries month-over-month growth as a percentage, `(revenue - previous_revenue) / previous_revenue * 100`, rounded to 2 decimals. It is NULL when there is no previous row or previous revenue is zero (no division-by-zero error).
- **REQ-F-05**: Output columns are exactly: month, city, revenue, previous_month_revenue, mom_growth_pct. Grain is month + city only (country is not part of the key).
- **REQ-F-06**: The model is materialized as a table in schema `gold`, inheriting the existing `gold` folder configuration; no model-level override is needed.
- **REQ-F-07**: Add dbt tests in a schema yml for the new model: `not_null` on month, city and revenue; a uniqueness test on the (month, city) combination; and a singular test verifying mom_growth_pct against an independently computed value from `obt`.

## Non-Functional Requirements
- **REQ-NF-01 (Maintainability)**: Use `ref()` for upstream relations (no hardcoded `AIRBNB.*` names) so dbt lineage includes the model; match the repo's SQL style (UPPERCASE column names, Jinja config block).
- **REQ-NF-02 (Testability / Verification)**: No Snowflake account is assumed. Verification in this cycle is by `dbt parse` / `dbt compile` and SQL review; dbt tests are authored but executed only where a connection exists.
- **REQ-NF-03 (Security)**: No credentials, account identifiers or secrets are added to any file; `profiles.yml` is not modified. Security Baseline applies and is enforced as blocking where relevant (largely N/A for a read-only aggregate SQL model).
- **REQ-NF-04 (Correctness)**: Aggregation must be deterministic and must not double count: `obt` is one row per booking, so SUM over it is safe.

## Assumptions and Open Items
- BOOKING_STATUS values are not defined in the repo, so no filtering is applied (answer Q2 = A). If cancelled bookings should be excluded, raise an enhancement or change request.
- Country is excluded from the grain (Q3 = A); two cities with the same name in different countries would be merged.
- `BOOKING_DATE` is a TIMESTAMP; month truncation uses the timestamp as stored (no timezone conversion).

## Extension Configuration
| Extension | Enabled | Decided At |
|---|---|---|
| Security Baseline | Yes (always mandatory) | Workflow start |
| Playwright Test Automation | Yes (always mandatory; N/A, no UI) | Workflow start |
| Resiliency Baseline | No | Requirements Analysis |
| Property-Based Testing | No | Requirements Analysis |

## Clarifying Question Answers (summary)
Q1 A, Q2 A, Q3 A, Q4 A, Q5 A, Q6 A, Q7 A, Q8 A, Q9 A, Q10 B, Q11 B (resiliency off), Q12 C (PBT off). Answers were filled by the AI on the user's instruction, choosing recommended options.
