# Integration Test Steps — Story 1.1: Monthly revenue by city model

**Purpose**: verify the new `agg_monthly_revenue` model builds from `obt` and aggregates correctly. **Scope**: grain, revenue definition, columns, materialization, compilation. Black-box: derived from the story's acceptance criteria only.

## System Under Test
| Item | Value |
|------|-------|
| Branch | `epic/monthly-revenue-aggregation` |
| This story's PR | Not raised yet (plan written before code); record the merged PR number here when the story merges |
| Confirm the story is in the build | `git log --oneline | grep "1.1"` (story branch name or commit message carries the story ID) |
| How to build & run it | **Follow the project's own build docs** (`README.md`, `dbt_code/README.md`). This plan does not restate them. |
| Local base URL / port | Not applicable (no web service) |
| Local services that must be up | A reachable Snowflake sandbox for the dbt profile (TO CONFIRM: which sandbox database/schema the Verification Engineer may write to) |
| Test data / accounts to seed | A sandbox copy of `gold.obt` seeded with the rows listed in each case (TO CONFIRM: seeding method) |

> If the build or local run fails, that is a **blocker on the dev team** — report it and do not log
> functional failures against a system that never started.

### TC-INT-01 — Model reads from obt only and hardcodes no relation

| Field | Value |
|-------|-------|
| **Traces to** | AC-1 / REQ-F-01, REQ-NF-01 |
| **Type** | Integration |
| **Priority** | P1 |
| **Preconditions** | The locally built branch from **System Under Test**, with `dbt` able to connect to the Snowflake sandbox. |
| **Test data** | None |

**Steps**
1. Run `dbt parse` from `dbt_code/`.
2. Run `dbt ls --select +agg_monthly_revenue --resource-type model` and note the parent models.
3. Open `dbt_code/models/gold/agg_monthly_revenue.sql` as a document and search for the text `AIRBNB.`.

**Expected result**
- `obt` is the only parent model listed besides `agg_monthly_revenue` itself and `obt`'s own ancestors.
- The text `AIRBNB.` does not appear in the model file.

**Pass/Fail criteria**: PASS if both expectations hold. FAIL if any other direct parent is listed or the text `AIRBNB.` appears (negative case: a hardcoded relation name).
**Cleanup**: None.

### TC-INT-02 — One row per month and city

| Field | Value |
|-------|-------|
| **Traces to** | AC-2 / REQ-F-01, REQ-F-05 |
| **Type** | Integration |
| **Priority** | P1 |
| **Preconditions** | The locally built branch from **System Under Test**, with `dbt` able to connect to the Snowflake sandbox. |
| **Test data** | Sandbox `obt` rows (booking_id, city, country, booking_date, total_amount, service_fee, cleaning_fee, status): B1 Paris France 2025-01-10 600.00 30.00 20.00 confirmed; B2 Paris France 2025-01-25 400.00 20.00 10.00 cancelled; B3 Rome Italy 2025-01-12 300.00 15.00 10.00 confirmed; B4 Paris France 2025-02-05 1200.00 60.00 25.00 confirmed; B5 Paris Texas 2025-01-15 100.00 5.00 5.00 confirmed |

**Steps**
1. Seed the sandbox `obt` with the test data and run `dbt run --select agg_monthly_revenue`.
2. Run `select month, city, count(*) from <sandbox gold>.agg_monthly_revenue group by 1,2 having count(*) > 1`.
3. Run `select month, city from <sandbox gold>.agg_monthly_revenue order by 1,2`.

**Expected result**
- The duplicate query returns zero rows.
- The listing shows (2025-01, Paris), (2025-01, Rome), (2025-02, Paris) and no other rows.

**Pass/Fail criteria**: PASS if no duplicates and the listing matches exactly. FAIL otherwise.
**Cleanup**: Drop the sandbox tables created for this case (TO CONFIRM: sandbox naming).

### TC-INT-03 — Country is not part of the grain (boundary)

| Field | Value |
|-------|-------|
| **Traces to** | AC-2 / REQ-F-05 |
| **Type** | Integration |
| **Priority** | P2 |
| **Preconditions** | The locally built branch from **System Under Test**, with `dbt` able to connect to the Snowflake sandbox. |
| **Test data** | Sandbox `obt` rows (booking_id, city, country, booking_date, total_amount, service_fee, cleaning_fee, status): B1 Paris France 2025-01-10 600.00 30.00 20.00 confirmed; B2 Paris France 2025-01-25 400.00 20.00 10.00 cancelled; B3 Rome Italy 2025-01-12 300.00 15.00 10.00 confirmed; B4 Paris France 2025-02-05 1200.00 60.00 25.00 confirmed; B5 Paris Texas 2025-01-15 100.00 5.00 5.00 confirmed (B5 is Paris in Texas) |

**Steps**
1. With the data from TC-INT-02 built, run `select * from <sandbox gold>.agg_monthly_revenue where city = 'Paris' and month = '2025-01-01'`.

**Expected result**
- Exactly one row is returned for Paris in 2025-01 and it includes the revenue of B1, B2 (France) and B5 (Texas) together.

**Pass/Fail criteria**: PASS if one row and the revenue equals the sum of B1, B2 and B5. FAIL if two rows appear.
**Cleanup**: Drop the sandbox tables created for this case (TO CONFIRM: sandbox naming).

### TC-INT-04 — Revenue sums TOTAL_AMOUNT for all statuses and excludes fees

| Field | Value |
|-------|-------|
| **Traces to** | AC-3 / REQ-F-02, REQ-NF-04 |
| **Type** | Integration |
| **Priority** | P1 |
| **Preconditions** | The locally built branch from **System Under Test**, with `dbt` able to connect to the Snowflake sandbox. |
| **Test data** | Sandbox `obt` rows (booking_id, city, country, booking_date, total_amount, service_fee, cleaning_fee, status): B1 Paris France 2025-01-10 600.00 30.00 20.00 confirmed; B2 Paris France 2025-01-25 400.00 20.00 10.00 cancelled; B3 Rome Italy 2025-01-12 300.00 15.00 10.00 confirmed; B4 Paris France 2025-02-05 1200.00 60.00 25.00 confirmed; B5 Paris Texas 2025-01-15 100.00 5.00 5.00 confirmed |

**Steps**
1. With the data built, run `select revenue from <sandbox gold>.agg_monthly_revenue where city='Paris' and month='2025-01-01'`.
2. Repeat for Rome 2025-01 and Paris 2025-02.

**Expected result**
- Paris 2025-01 revenue is 1100.00 (600.00 + 400.00 + 100.00); the cancelled booking B2 is included and no fee amount is added.
- Rome 2025-01 revenue is 300.00; Paris 2025-02 revenue is 1200.00.

**Pass/Fail criteria**: PASS if all three values match exactly. FAIL if any value includes fees or omits the cancelled booking.
**Cleanup**: Drop the sandbox tables created for this case (TO CONFIRM: sandbox naming).

### TC-INT-05 — No double counting (boundary)

| Field | Value |
|-------|-------|
| **Traces to** | AC-3 / REQ-NF-04 |
| **Type** | Integration |
| **Priority** | P2 |
| **Preconditions** | The locally built branch from **System Under Test**, with `dbt` able to connect to the Snowflake sandbox. |
| **Test data** | Sandbox `obt` rows (booking_id, city, country, booking_date, total_amount, service_fee, cleaning_fee, status): B1 Paris France 2025-01-10 600.00 30.00 20.00 confirmed; B2 Paris France 2025-01-25 400.00 20.00 10.00 cancelled; B3 Rome Italy 2025-01-12 300.00 15.00 10.00 confirmed; B4 Paris France 2025-02-05 1200.00 60.00 25.00 confirmed; B5 Paris Texas 2025-01-15 100.00 5.00 5.00 confirmed |

**Steps**
1. Run `select sum(total_amount) from <sandbox obt>` and `select sum(revenue) from <sandbox gold>.agg_monthly_revenue`.

**Expected result**
- Both totals are 2600.00.

**Pass/Fail criteria**: PASS if the two totals are equal. FAIL if the aggregate total is higher or lower.
**Cleanup**: Drop the sandbox tables created for this case (TO CONFIRM: sandbox naming).

### TC-INT-06 — Output columns and materialization

| Field | Value |
|-------|-------|
| **Traces to** | AC-4 / REQ-F-05, REQ-F-06 |
| **Type** | Integration |
| **Priority** | P1 |
| **Preconditions** | The locally built branch from **System Under Test**, with `dbt` able to connect to the Snowflake sandbox. |
| **Test data** | Data from TC-INT-02 |

**Steps**
1. Run `describe table <sandbox gold>.agg_monthly_revenue`.
2. Run `select table_type, table_schema from information_schema.tables where table_name = 'AGG_MONTHLY_REVENUE'`.
3. Open the model file and look for `materialized`, `schema`, `database` or `alias` in any config block.

**Expected result**
- Columns are exactly MONTH, CITY, REVENUE (the growth columns arrive in Story 1.2).
- The relation is a BASE TABLE in schema GOLD.
- No config override of those keys exists in the file.

**Pass/Fail criteria**: PASS if all three hold. FAIL if a column is missing or extra, the object is a view, or an override is present.
**Cleanup**: Drop the sandbox tables created for this case (TO CONFIRM: sandbox naming).

### TC-INT-07 — Model compiles (boundary: no warehouse needed)

| Field | Value |
|-------|-------|
| **Traces to** | AC-5 / REQ-NF-02 |
| **Type** | Integration |
| **Priority** | P1 |
| **Preconditions** | The locally built branch; `dbt` installed. |
| **Test data** | None |

**Steps**
1. From `dbt_code/`, run `dbt parse`.
2. Run `dbt compile --select agg_monthly_revenue`.

**Expected result**
- Both commands exit with code 0 and print no error.

**Pass/Fail criteria**: PASS if both succeed. FAIL on any error.
**Cleanup**: None.

