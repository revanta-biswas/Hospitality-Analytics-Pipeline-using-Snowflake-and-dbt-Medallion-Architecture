# Integration Test Steps — Story 1.3: Data quality tests for agg_monthly_revenue

**Purpose**: verify the new dbt tests pass on good data, fail on bad data, compile, and degrade honestly without a connection. Requires Stories 1.1 and 1.2 in the build.

## System Under Test
| Item | Value |
|------|-------|
| Branch | `epic/monthly-revenue-aggregation` |
| This story's PR | Not raised yet (plan written before code); record the merged PR number here when the story merges |
| Confirm the story is in the build | `git log --oneline | grep "1.3"` (story branch name or commit message carries the story ID) |
| How to build & run it | **Follow the project's own build docs** (`README.md`, `dbt_code/README.md`). This plan does not restate them. |
| Local base URL / port | Not applicable (no web service) |
| Local services that must be up | A reachable Snowflake sandbox for the dbt profile (TO CONFIRM: which sandbox database/schema the Verification Engineer may write to) |
| Test data / accounts to seed | A sandbox copy of `gold.obt` seeded with the rows listed in each case (TO CONFIRM: seeding method) |

> If the build or local run fails, that is a **blocker on the dev team** — report it and do not log
> functional failures against a system that never started.

### TC-INT-01 — not_null tests pass, then fail on an empty city

| Field | Value |
|-------|-------|
| **Traces to** | AC-1 / REQ-F-07 |
| **Type** | Integration |
| **Priority** | P1 |
| **Preconditions** | The locally built branch from **System Under Test**, with `dbt` able to connect to the Snowflake sandbox. |
| **Test data** | Data from Story 1.2 plan (clean). Then in the sandbox `obt` set CITY to NULL for one booking. |

**Steps**
1. With clean data, run `dbt run --select agg_monthly_revenue` then `dbt test --select agg_monthly_revenue,test_type:generic`.
2. Set one booking's CITY to NULL in the sandbox `obt`, rebuild the model, and run the same `dbt test` command again.

**Expected result**
- First run: the not_null tests on month, city and revenue all PASS.
- Second run: the not_null test on city FAILS with 1 failing row.

**Pass/Fail criteria**: PASS if the first run is green and the second run fails exactly the city test. FAIL otherwise (negative case covered by the second run).
**Cleanup**: Drop the sandbox tables created for this case (TO CONFIRM: sandbox naming).

### TC-INT-02 — Month-and-city uniqueness test

| Field | Value |
|-------|-------|
| **Traces to** | AC-2 / REQ-F-07 |
| **Type** | Integration |
| **Priority** | P1 |
| **Preconditions** | The locally built branch from **System Under Test**, with `dbt` able to connect to the Snowflake sandbox. |
| **Test data** | Clean data from the Story 1.2 plan; then a sandbox copy of the model with (2025-01, Paris) inserted twice. |

**Steps**
1. Run `dbt test --select agg_monthly_revenue,test_type:singular` on clean data.
2. Insert a duplicate (2025-01, Paris) row into the sandbox model table and re-run the same command.

**Expected result**
- Clean data: the uniqueness test returns no rows and PASSES.
- Duplicate data: the test returns (2025-01, Paris) and FAILS.

**Pass/Fail criteria**: PASS if clean passes and duplicate fails. FAIL otherwise.
**Cleanup**: Drop the sandbox tables created for this case (TO CONFIRM: sandbox naming).

### TC-INT-03 — Growth recomputation test

| Field | Value |
|-------|-------|
| **Traces to** | AC-3 / REQ-F-07 |
| **Type** | Integration |
| **Priority** | P1 |
| **Preconditions** | The locally built branch from **System Under Test**, with `dbt` able to connect to the Snowflake sandbox. |
| **Test data** | Paris 2025-01 1000.00 and 2025-02 1200.00 from the Story 1.2 data; then change mom_growth_pct for Paris 2025-02 to 25.00 in the sandbox model table. |

**Steps**
1. Run the singular growth test on correct data.
2. Update the sandbox model row to 25.00 and re-run it.

**Expected result**
- Correct data: recomputed 20.00 equals the model value and the test PASSES.
- Altered data: recomputed 20.00 differs from 25.00 and the test FAILS.

**Pass/Fail criteria**: PASS if correct data passes and altered data fails. FAIL otherwise.
**Cleanup**: Drop the sandbox tables created for this case (TO CONFIRM: sandbox naming).

### TC-INT-04 — All new tests compile (boundary: no warehouse needed)

| Field | Value |
|-------|-------|
| **Traces to** | AC-4 / REQ-NF-02 |
| **Type** | Integration |
| **Priority** | P1 |
| **Preconditions** | The locally built branch; `dbt` installed. |
| **Test data** | None |

**Steps**
1. From `dbt_code/`, run `dbt parse`.
2. Run `dbt compile --select agg_monthly_revenue`.

**Expected result**
- Both commands exit 0 and list the new tests among compiled nodes with no error.

**Pass/Fail criteria**: PASS if both succeed. FAIL on any error.
**Cleanup**: None.

### TC-INT-05 — No Snowflake connection: honest degradation

| Field | Value |
|-------|-------|
| **Traces to** | AC-5 / REQ-NF-02 |
| **Type** | Integration |
| **Priority** | P2 |
| **Preconditions** | The locally built branch with the Snowflake profile deliberately unset or pointed at an unreachable account (a sandbox profile, never production). |
| **Test data** | None |

**Steps**
1. Run `dbt test --select agg_monthly_revenue`.
2. Read the evidence/notes the story recorded for this step (TO CONFIRM: where the dev team records it).

**Expected result**
- The run cannot reach the warehouse and reports a connection error; no test is reported as passed.
- The recorded evidence states that test execution was not possible and why.

**Pass/Fail criteria**: PASS if no false pass is recorded and the reason is documented. FAIL if tests are claimed as passed.
**Cleanup**: Restore the normal profile.

