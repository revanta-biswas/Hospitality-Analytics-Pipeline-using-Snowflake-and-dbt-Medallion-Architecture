# Story Generation Plan — Epic: Harden Pipeline (Security & Data Quality)

## Methodology

**Assume the role of a product owner.** Requirements are drawn from `spec/plans/requirements.md`
(REQ-F-01..09, REQ-NF-01..04), grounded in `spec/plans/atlas-deep-dive.md`. Since this is a headless
data pipeline (no UI, no end users beyond the data engineer/analyst who runs and maintains it), the
single persona in scope is **the Data Engineer** who owns and operates this pipeline.

`team_size: 2` (fixed default, not asked). `story_creation_mode: all-at-once` (fixed default, not asked).

## Step 1.5 — SPIDR Slicing Analysis

Applied to the 9 functional requirements:

| Requirement(s) | SPIDR axis driving the split | Story boundary decision |
|---|---|---|
| REQ-F-01 (Storage Integration for S3 ingestion) | Interfaces — distinct config surface (Snowflake SQL bootstrap) from dbt profile secrets | Own story |
| REQ-F-02 (env_var() for profiles.yml) | Interfaces — distinct config surface (dbt connection profile) | Own story |
| REQ-F-03 + REQ-F-04 (uniqueness/not_null + relationships tests) | Rules — both are core referential/uniqueness data-integrity rules on the same 3 Silver models; combining keeps one coherent "core data integrity tests" story at 5 ACs (3 uniqueness + 2 relationships), at the sizing ceiling but not over it | Combined into one story |
| REQ-F-05 (accepted_values tests) | Rules — a distinct rule class (enumerated-value validation) from uniqueness/referential integrity; combining with F-03/04 would push that story to 7 ACs, over the 5-AC ceiling | Own story |
| REQ-F-06 (fact.sql ref() fix) | Standalone, single file, single concern | Own story |
| REQ-F-07 (Bronze materialization config conflict) | Standalone, single concern (dbt_project.yml + properties.yml reconciliation) | Own story |
| REQ-F-08 (source freshness on sources.yml) | Standalone, single concern | Own story |
| REQ-F-09 (CI workflow: dbt parse/compile) | Steps — this is the last step in the workflow; it validates the end-state all other stories produce, so it depends on all of them being mergeable | Own story, sequenced last |

**Result: 8 stories.** REQ-NF-01/02/03/04 are non-functional constraints layered onto ACs of the
stories above (not separate stories) — e.g. REQ-NF-02 (static-only verification) becomes the AC
"verified via `dbt parse`/`dbt compile`, not a live run" attached to every story that touches SQL/YAML.

## Recommended Story Count

 **How many user stories should I create for this work?**

    Recommended: 8 stories (suggested range: 7-9)

   Why 8:
   - 9 functional requirements SPIDR-sliced into single-purpose stories: 2 config-hardening stories
     (Interfaces axis — Snowflake bootstrap vs dbt profile are different surfaces), 2 data-test stories
     (Rules axis — uniqueness/referential-integrity vs accepted-values are different rule classes, kept
     apart to stay under the 5-AC ceiling), 3 standalone single-file fixes (fact.sql ref(), Bronze
     materialization config, source freshness), and 1 CI story sequenced last (depends on everything
     else being statically clean)
   - Yields 7 stories with no interdependency (only the CI story genuinely depends on the others) — well
     above `team_size` (= 2), so multiple stories are runnable in parallel throughout the cycle
   - Each story stays within the Step 1.5 sizing ceilings (at most 5 ACs, one architectural layer
     touched, one scenario class, no title conjunction)

   Reply with a number to override, or "ok"/"use recommended" to accept 8.
[Answer]: ok

## Story Breakdown Approach

**Feature-Based** — stories are organized around the discrete hardening capabilities Atlas identified
(credentials, tests, DAG integrity, config consistency, CI), not around user journeys or personas,
since there is exactly one persona (Data Engineer) and no UI-driven workflow to slice by journey.

## Persona

Single persona: **Data Engineer** — owns, runs, and maintains this pipeline; the sole consumer of
every hardening change in this epic (see `personas.md`).

## Execution Checklist

- [x] Apply SPIDR slicing to all 9 functional requirements (table above)
- [x] Compute and confirm recommended story count (8, accepted)
- [ ] Generate `spec/plans/personas.md` (Data Engineer persona)
- [ ] Generate `spec/plans/stories.md` with Epic header line, 8 stories, each with `**Covers**:` REQ-IDs,
      acceptance criteria (INVEST-compliant, within Step 1.5 ceilings), and persona mapping
- [ ] Populate the `## Story Tracker` in `runtime-artifacts/aire-state.md` (Requires = TBD, Tracker ID = —,
      Status = Ready for Development)
- [ ] Run the Requirements Full-Coverage Check (Step 18.5) — every REQ-ID fully covered
- [ ] Run the Story Granularity & Splitting Check (Step 18.6) — 0 ceiling violations
- [ ] Present the complete story set for GATE 1 approval
