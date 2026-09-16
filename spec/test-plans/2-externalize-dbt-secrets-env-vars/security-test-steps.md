# Security Test Steps — Story 1.2: Externalize dbt connection secrets via environment variables

## System Under Test
| Item | Value |
|------|-------|
| Branch | `epic/harden-pipeline-security-and-data-quality` |
| This story's merged PR | 🟡 TO CONFIRM: [PR URL once Story 1.2's PR is raised and merged] |
| Confirm the story is in the build | `git log --oneline | grep -i "1.2\|env_var\|externalize"` |
| How to build & run it | Follow the project's own build docs (README / dbt project docs). This plan does not restate them. |
| Local base URL / port | N/A — this is a dbt project config file, not a running service |
| Local services that must be up | None required to inspect the file; a local Snowflake connection (via the documented `DBT_*` env vars) is only needed if actually running `dbt debug`/`dbt run` |
| Test data / accounts to seed | None |

> If the build or local run fails, that is a blocker on the dev team — report it and do not log
> functional failures against a system that never started.

---

### TC-SEC-01 — No plaintext secret values remain in profiles.yml

| Field | Value |
|-------|-------|
| **Traces to** | AC-1, AC-4 / REQ-F-02, REQ-NF-01 |
| **Type** | Security |
| **Priority** | P1 (critical path) |
| **Preconditions** | Local checkout of the integration branch, story merged |
| **Test data** | None |

**Steps**
1. Open `src/dbt_code/profiles.yml` in a text editor.
2. Inspect the `account`, `user`, `password`, `role`, and `warehouse` fields under `dbt_code.outputs.dev`.
3. Run a repo-wide search (e.g. `grep -rn "password\|account\|user\|role\|warehouse" src/dbt_code/profiles.yml`).

**Expected result**
- Each of the 5 fields is an `{{ env_var('DBT_...') }}` reference — no literal string value (placeholder or real) is present.
- The search in step 3 shows only `env_var()` expressions for those 5 keys, never a bare literal.

**Pass/Fail criteria**: PASS if all 5 fields are `env_var()` references with zero literal values; FAIL if any field still holds a literal string.
**Cleanup**: None (read-only inspection).

---

### TC-SEC-02 — Non-secret operational fields remain literal (no unnecessary externalization)

| Field | Value |
|-------|-------|
| **Traces to** | AC-2 / REQ-F-02 |
| **Type** | Security |
| **Priority** | P2 |
| **Preconditions** | Local checkout of the integration branch, story merged |
| **Test data** | None |

**Steps**
1. Open `src/dbt_code/profiles.yml`.
2. Inspect `schema`, `threads`, and `type` under `dbt_code.outputs.dev`.

**Expected result**
- These fields remain literal (non-`env_var()`) values — they are operational, not secret, and the story's AC explicitly says they may stay literal.

**Pass/Fail criteria**: PASS if `schema`/`threads`/`type` are literal values, not `env_var()` calls; FAIL if any was unnecessarily externalized (a deviation from the AC, not a security bug per se, but worth flagging).
**Cleanup**: None.

---

### TC-SEC-03 — Required environment variables are documented

| Field | Value |
|-------|-------|
| **Traces to** | AC-3 / REQ-F-02 |
| **Type** | Security |
| **Priority** | P2 |
| **Preconditions** | Local checkout of the integration branch, story merged |
| **Test data** | None |

**Steps**
1. Open `src/dbt_code/README.md`.
2. Compare the environment variable names listed there against the `env_var()` calls found in `profiles.yml` (from TC-SEC-01).

**Expected result**
- Every `DBT_*` variable name referenced in `profiles.yml` is documented in `src/dbt_code/README.md` (name, and ideally a one-line description of what it's for).

**Pass/Fail criteria**: PASS if all referenced variable names appear in the README; FAIL if any is undocumented, since an operator would have no way to know what to set.
**Cleanup**: None.

---

### TC-SEC-04 — Negative case: missing environment variable fails safely, does not leak a default secret

| Field | Value |
|-------|-------|
| **Traces to** | AC-1, AC-5 / REQ-NF-02 |
| **Type** | Security |
| **Priority** | P2 |
| **Preconditions** | Local checkout of the integration branch, story merged; dbt CLI installed locally (`uv sync` or equivalent per the project's build docs); the 5 `DBT_*` environment variables deliberately **left unset** |
| **Test data** | None (deliberately absent env vars) |

**Steps**
1. In a terminal with none of the 5 `DBT_*` variables set, run `dbt debug --project-dir src/dbt_code --profiles-dir src/dbt_code` (or the project's documented equivalent invocation).
2. Observe the output.

**Expected result**
- dbt reports a clear error that the required environment variable(s) are missing/undefined — it does **not** silently fall back to a blank string, a hardcoded default, or connect using some other implicit credential.
- No credential value (real or otherwise) is echoed in the error output.

**Pass/Fail criteria**: PASS if the failure is explicit and no credential-shaped value appears in the output; FAIL if the command proceeds silently, or if any value resembling a credential appears in the console output/logs.
**Cleanup**: None (no state was changed).

---

### TC-SEC-05 — profiles.yml remains structurally valid YAML

| Field | Value |
|-------|-------|
| **Traces to** | AC-5 / REQ-NF-02 |
| **Type** | Security |
| **Priority** | P1 (critical path — a malformed file is itself a risk if it fails open) |
| **Preconditions** | Local checkout of the integration branch, story merged |
| **Test data** | None |

**Steps**
1. Run a YAML parse check against `src/dbt_code/profiles.yml`, e.g. `python3 -c "import yaml; yaml.safe_load(open('src/dbt_code/profiles.yml'))"`, or `dbt debug`'s own profile-parsing step.

**Expected result**
- The file parses without error; dbt's own tooling recognizes the profile as well-formed.

**Pass/Fail criteria**: PASS if the parse succeeds with no exception; FAIL on any parse error.
**Cleanup**: None.
