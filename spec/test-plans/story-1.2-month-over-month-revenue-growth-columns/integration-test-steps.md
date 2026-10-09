# Integration Test Steps — Story 1.2: Month-over-month revenue growth columns

**Purpose**: verify previous-month revenue and growth percentage. **Scope**: LAG behaviour, rounding, NULL handling, final column contract. Requires Story 1.1 in the build.

## System Under Test
| Item | Value |
|------|-------|
| Branch | `epic/monthly-revenue-aggregation` |
| This story's PR | Not raised yet (plan written before code); record the merged PR number here when the story merges |
| Confirm the story is in the build | `git log --oneline | grep "1.2"` (story branch name or commit message carries the story ID) |
| How to build & run it | **Follow the project's own build docs** (`README.md`, `dbt_code/README.md`). This plan does not restate them. |
| Local base URL / port | Not applicable (no web service) |
| Local services that must be up | A reachable Snowflake sandbox for the dbt profile (TO CONFIRM: which sandbox database/schema the Verification Engineer may write to) |
| Test data / accounts to seed | A sandbox copy of `gold.obt` seeded with the rows listed in each case (TO CONFIRM: seeding method) |

> If the build or local run fails, that is a **blocker on the dev team** — report it and do not log
> functional failures against a system that never started.

### TC-INT-01 — Previous revenue is per city

| Field | Value |
|-------|-------|
| **Traces to** | AC-1 / REQ-F-03 |
| **Type** | Integration |
| **Priority** | P1 |
| **Preconditions** | The locally built branch from **System Under Test**, with `dbt` able to connect to the Snowflake sandbox. |
| **Test data** | Sandbox `agg_monthly_revenue` source rows from `obt` producing revenue: Paris 2025-01 1000.00, Paris 2025-02 1200.00, Paris 2025-04 900.00 (no March bookings), Rome 2025-02 500.00, Oslo 2025-01 0.00, Oslo 2025-02 80.00, Lima 2025-01 300.00, Lima 2025-02 400.00. Seed `obt` with one booking per city-month carrying that total_amount. |

**Steps**
1. Seed `obt`, run `dbt run --select agg_monthly_revenue`.
2. Run `select city, month, previous_month_revenue from <sandbox gold>.agg_monthly_revenue where month = '2025-02-01' order by city`.

**Expected result**
- Paris shows 1000.00; Rome shows empty (NULL), not Paris's value; Oslo shows 0.00; Lima shows 300.00.

**Pass/Fail criteria**: PASS if all four values match. FAIL if a city sees another city's revenue.
**Cleanup**: Drop the sandbox tables created for this case (TO CONFIRM: sandbox naming).

### TC-INT-02 — A gap month is not filled (boundary)

| Field | Value |
|-------|-------|
| **Traces to** | AC-1 / REQ-F-03 |
| **Type** | Integration |
| **Priority** | P1 |
| **Preconditions** | The locally built branch from **System Under Test**, with `dbt` able to connect to the Snowflake sandbox. |
| **Test data** | Sandbox `agg_monthly_revenue` source rows from `obt` producing revenue: Paris 2025-01 1000.00, Paris 2025-02 1200.00, Paris 2025-04 900.00 (no March bookings), Rome 2025-02 500.00, Oslo 2025-01 0.00, Oslo 2025-02 80.00, Lima 2025-01 300.00, Lima 2025-02 400.00. Seed `obt` with one booking per city-month carrying that total_amount. |

**Steps**
1. Run `select month, revenue, previous_month_revenue from <sandbox gold>.agg_monthly_revenue where city='Paris' order by month`.

**Expected result**
- Three rows only: 2025-01, 2025-02, 2025-04. No 2025-03 row.
- The 2025-04 row shows previous_month_revenue 1200.00 (from 2025-02).

**Pass/Fail criteria**: PASS if there is no March row and April's previous value is 1200.00. FAIL otherwise.
**Cleanup**: Drop the sandbox tables created for this case (TO CONFIRM: sandbox naming).

### TC-INT-03 — First month has no previous revenue

| Field | Value |
|-------|-------|
| **Traces to** | AC-2 / REQ-F-03 |
| **Type** | Integration |
| **Priority** | P1 |
| **Preconditions** | The locally built branch from **System Under Test**, with `dbt` able to connect to the Snowflake sandbox. |
| **Test data** | Sandbox `agg_monthly_revenue` source rows from `obt` producing revenue: Paris 2025-01 1000.00, Paris 2025-02 1200.00, Paris 2025-04 900.00 (no March bookings), Rome 2025-02 500.00, Oslo 2025-01 0.00, Oslo 2025-02 80.00, Lima 2025-01 300.00, Lima 2025-02 400.00. Seed `obt` with one booking per city-month carrying that total_amount. |

**Steps**
1. Run `select city, month, previous_month_revenue from <sandbox gold>.agg_monthly_revenue where (city, month) in (('Paris','2025-01-01'),('Rome','2025-02-01'))`.

**Expected result**
- Both rows show previous_month_revenue empty (NULL).

**Pass/Fail criteria**: PASS if both are NULL. FAIL if either holds a number.
**Cleanup**: Drop the sandbox tables created for this case (TO CONFIRM: sandbox naming).

### TC-INT-04 — Growth percentage and rounding

| Field | Value |
|-------|-------|
| **Traces to** | AC-3 / REQ-F-04 |
| **Type** | Integration |
| **Priority** | P1 |
| **Preconditions** | The locally built branch from **System Under Test**, with `dbt` able to connect to the Snowflake sandbox. |
| **Test data** | Sandbox `agg_monthly_revenue` source rows from `obt` producing revenue: Paris 2025-01 1000.00, Paris 2025-02 1200.00, Paris 2025-04 900.00 (no March bookings), Rome 2025-02 500.00, Oslo 2025-01 0.00, Oslo 2025-02 80.00, Lima 2025-01 300.00, Lima 2025-02 400.00. Seed `obt` with one booking per city-month carrying that total_amount. |

**Steps**
1. Run `select city, month, mom_growth_pct from <sandbox gold>.agg_monthly_revenue where (city, month) in (('Paris','2025-02-01'),('Lima','2025-02-01'),('Paris','2025-04-01'))`.

**Expected result**
- Paris 2025-02 is 20.00; Lima 2025-02 is 33.33 (rounded from 33.3333); Paris 2025-04 is -25.00.

**Pass/Fail criteria**: PASS if all three match to two decimals. FAIL otherwise.
**Cleanup**: Drop the sandbox tables created for this case (TO CONFIRM: sandbox naming).

### TC-INT-05 — No growth value when previous is missing or zero; no error

| Field | Value |
|-------|-------|
| **Traces to** | AC-4 / REQ-F-04, REQ-NF-04 |
| **Type** | Integration |
| **Priority** | P1 |
| **Preconditions** | The locally built branch from **System Under Test**, with `dbt` able to connect to the Snowflake sandbox. |
| **Test data** | Sandbox `agg_monthly_revenue` source rows from `obt` producing revenue: Paris 2025-01 1000.00, Paris 2025-02 1200.00, Paris 2025-04 900.00 (no March bookings), Rome 2025-02 500.00, Oslo 2025-01 0.00, Oslo 2025-02 80.00, Lima 2025-01 300.00, Lima 2025-02 400.00. Seed `obt` with one booking per city-month carrying that total_amount. |

**Steps**
1. Run `dbt run --select agg_monthly_revenue` and note the exit status.
2. Run `select city, month, previous_month_revenue, mom_growth_pct from <sandbox gold>.agg_monthly_revenue where city in ('Paris','Oslo') and month in ('2025-01-01','2025-02-01')`.

**Expected result**
- The dbt run completes with no division-by-zero error.
- Paris 2025-01 growth is NULL (no previous). Oslo 2025-02 shows previous 0.00 and growth NULL.

**Pass/Fail criteria**: PASS if the run succeeds and both growth values are NULL. FAIL on any error or a numeric/infinite value.
**Cleanup**: Drop the sandbox tables created for this case (TO CONFIRM: sandbox naming).

### TC-INT-06 — Final column contract

| Field | Value |
|-------|-------|
| **Traces to** | AC-5 / REQ-F-05 |
| **Type** | Integration |
| **Priority** | P1 |
| **Preconditions** | The locally built branch from **System Under Test**, with `dbt` able to connect to the Snowflake sandbox. |
| **Test data** | Sandbox `agg_monthly_revenue` source rows from `obt` producing revenue: Paris 2025-01 1000.00, Paris 2025-02 1200.00, Paris 2025-04 900.00 (no March bookings), Rome 2025-02 500.00, Oslo 2025-01 0.00, Oslo 2025-02 80.00, Lima 2025-01 300.00, Lima 2025-02 400.00. Seed `obt` with one booking per city-month carrying that total_amount. |

**Steps**
1. Run `describe table <sandbox gold>.agg_monthly_revenue`.

**Expected result**
- Columns, in this order: MONTH, CITY, REVENUE, PREVIOUS_MONTH_REVENUE, MOM_GROWTH_PCT. No COUNTRY column.

**Pass/Fail criteria**: PASS if the list and order match exactly. FAIL on any extra, missing or reordered column.
**Cleanup**: Drop the sandbox tables created for this case (TO CONFIRM: sandbox naming).

