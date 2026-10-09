# Security Test Steps — Story 1.1: Monthly revenue by city model

**Purpose**: confirm the story adds no secrets. **Scope**: files changed by the story. Maps to Security Baseline rules on credential management.

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

### TC-SEC-01 — No credentials in changed files

| Field | Value |
|-------|-------|
| **Traces to** | AC-5 / REQ-NF-03 |
| **Type** | Security |
| **Priority** | P1 |
| **Preconditions** | The story branch is checked out. |
| **Test data** | None |

**Steps**
1. Run `git diff origin/main...HEAD --name-only` to list changed files.
2. Run `git diff origin/main...HEAD | grep -i -E 'password|secret|token|aws_secret|aws_key_id|private[_ ]key'`.

**Expected result**
- No match shows a real value. Placeholders already in the repo (for example `yourkey`) are not new lines.

**Pass/Fail criteria**: PASS if no added line contains a real credential. FAIL otherwise.
**Cleanup**: None.

### TC-SEC-02 — profiles.yml unchanged

| Field | Value |
|-------|-------|
| **Traces to** | AC-5 / REQ-NF-03 |
| **Type** | Security |
| **Priority** | P2 |
| **Preconditions** | The story branch is checked out. |
| **Test data** | None |

**Steps**
1. Run `git diff origin/main...HEAD -- dbt_code/profiles.yml`.

**Expected result**
- The command prints nothing.

**Pass/Fail criteria**: PASS if no diff. FAIL if the file changed.
**Cleanup**: None.

