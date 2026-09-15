# Code Generation Plan — Story 1.1

**Story**: Replace inline AWS credentials with a Snowflake Storage Integration
**Tracker**: GitHub issue #1 (Milestone #1 — Epic: Harden Pipeline)
**Covers**: REQ-F-01, REQ-NF-01, REQ-NF-02
**Branch**: `story/1.1-replace-inline-aws-credentials-storage-integration` (cut from `epic/harden-pipeline-security-and-data-quality`)
**Dependencies**: `requires: none` (Dependency Graph)

## Context

`src/snowflake/Stage.sql` currently creates `s3_stage` with a bare `URL='your_s3_bucket_path'` and no
credential/integration binding (it is actually missing a `CREDENTIALS`/`STORAGE_INTEGRATION` clause
entirely today — the real credential leak lives in `Copy_Into.sql`, whose three `COPY INTO` statements
each inline `CREDENTIALS=(aws_key_id = 'yourkey', aws_secret_key = 'yoursecretkey')`). Per Atlas Flow 1
(Raw Ingestion) and REQ-F-01, the fix is to:
1. Introduce a `STORAGE INTEGRATION` object in `Stage.sql` (or a sibling bootstrap file referenced by
   it) that Snowflake uses to assume an AWS IAM role — no static AWS keys anywhere.
2. Bind `s3_stage` to that storage integration via `STORAGE_INTEGRATION = <name>`.
3. Remove every `CREDENTIALS=(aws_key_id=... aws_secret_key=...)` clause from `Copy_Into.sql`'s three
   `COPY INTO` statements — a stage bound to a storage integration needs no per-`COPY` credential
   clause at all.

REQ-NF-02 constrains "done" to static verifiability: no live Snowflake/AWS account exists in this
environment, so every check here is either (a) mechanical text/pattern verification of the SQL files,
or (b) Gherkin scenarios whose steps assert on the SQL file's parsed structure — never an actual
`CREATE STORAGE INTEGRATION` executed against a warehouse.

## Steps

- [x] **Step 1 — Write this plan document** (process step, no REQ tag)
- [x] **Step 2 — Write the story's Gherkin behaviour spec** `spec/behavior/story-1.1.feature`
      (REQ-F-01, REQ-NF-01, REQ-NF-02, AC-1, AC-2, AC-3, AC-4) — written BEFORE the SQL edit, per
      `common/behavior-spec.md` Section 2.
- [x] **Step 3 — Add the STORAGE INTEGRATION object + rebind `s3_stage`** in
      `src/snowflake/Stage.sql` (REQ-F-01, AC-1): added a `CREATE STORAGE INTEGRATION IF NOT EXISTS
      s3_int ...` block (placeholder ARN/allowed-location values, clearly documented as
      operator-supplied) and changed the `CREATE OR REPLACE STAGE s3_stage` DDL to reference
      `STORAGE_INTEGRATION = s3_int` instead of any credential clause.
- [x] **Step 4 — Remove inline AWS credentials from `Copy_Into.sql`** (REQ-F-01, REQ-NF-01, AC-2, AC-3):
      deleted the `CREDENTIALS=(aws_key_id = ..., aws_secret_key = ...)` clause from all three `COPY
      INTO` statements (`BOOKINGS`, `HOSTS`, `LISTINGS`); they inherit auth from the stage's storage
      integration.
- [x] **Step 5 — Mechanical verification (AC-3)**: grepped `src/snowflake/*.sql` for
      `aws_key_id`/`aws_secret_key`/`credentials=` — zero matches confirmed (REQ-F-01, REQ-NF-01, AC-3).
- [x] **Step 6 — "Unit Test & Coverage" step, adapted for a SQL-only story (REQ-NF-02)**: this story has
      no application code in any language with a coverage tool (0 `.py` files touched; `unitCoverage`
      recorded N/A). The concrete, runnable form of test-for-a-SQL-diff-with-no-warehouse is the
      pytest-bdd step definitions for AC-1..AC-4 written in `tests/behavior/steps/` — these ARE the
      executable tests for this story and were run for real (see Step 7).
- [x] **Step 7 — Implement + RUN the pytest-bdd step definitions** for `story-1.1.feature`
      (`tests/behavior/test_story_1_1.py` + `tests/behavior/steps/stage_credential_steps.py` +
      `tests/behavior/conftest.py`), asserting directly on the SQL file text/structure (regex-based, no
      live connection). Ran via `python3 -m pytest tests/behavior/ -v` — 4/4 scenarios passed, one per
      `@AC-n` (REQ-F-01, REQ-NF-01, REQ-NF-02, AC-1..AC-4). Evidence:
      `reports/behavior-test-evidence/story-1.1/b1/`.
- [x] **Step 8 — Full regression checkpoint**: re-ran the only test suite that exists (this story's own
      new pytest-bdd tests — no pre-existing suite; `baseline-regression.log` already recorded "no
      suite"). 4/4 pass, zero NEW failures (there is nothing pre-existing to have broken).
- [x] **Step 9 — Static Eval Gate D1–D7 post-change diff**: re-ran D1–D7, diffed against
      `reports/eval-evidence/story-1.1/static/baseline/`. Zero NEW findings on `src/snowflake/*.sql`
      (gitleaks fingerprints identical baseline vs post-change). See
      `reports/eval-evidence/story-1.1/eval-summary.md`.
- [x] **Step 10 — Documentation**: none required beyond the plan/feature file — no README/API docs are
      in scope for this story's ACs. (Confirmed no doc gap.)

## REQ/AC Trace Summary

| REQ-ID | AC(s) | Plan Steps |
|---|---|---|
| REQ-F-01 | AC-1, AC-2, AC-3 | Steps 3, 4, 5, 7, 9 |
| REQ-NF-01 | AC-2, AC-3 | Steps 4, 5, 7, 9 |
| REQ-NF-02 | AC-4 | Steps 6, 7, 8 |

Trace completeness self-check: every `Covers` REQ-ID (REQ-F-01, REQ-NF-01, REQ-NF-02) and every AC
(AC-1–AC-4) appears in at least one tagged step above. PASS.

## Design Reference Grounding

`Design reference: none covers this component` — no UI/API prototype references apply to Snowflake
bootstrap SQL; built from the ACs, `requirements.md` REQ-F-01/REQ-NF-01/REQ-NF-02, `architecture.md`
ARCH-01, and Atlas Flow 1 (Raw Ingestion) only.

## API & Contract Testing Gate

N/A — this story's plan has no API Layer Generation step (pure SQL DDL/DML, no service endpoint).

## Out of scope for this delegated pass

Code Review, Remediate, PR raising and the J1/J2 judge gates are explicitly reserved for the invoking
session per its instructions — not executed here.
