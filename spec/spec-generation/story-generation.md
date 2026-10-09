# Story Generation Plan

Epic: monthly revenue by city with month-over-month growth (`gold/agg_monthly_revenue.sql`).
Requirements: REQ-F-01..07, REQ-NF-01..04 (`spec/plans/requirements.md`). `team_size` = 2 (framework default).

## Plan Checklist
- [x] Apply SPIDR slicing to each REQ-ID
- [x] Generate `spec/plans/stories.md` (Epic header first line, `**Covers**` on every story, at most 5 ACs each)
- [x] Generate `spec/plans/personas.md`
- [x] Populate the Story Tracker in `runtime-artifacts/aire-state.md`
- [x] Requirements full-coverage check (matrix appended to stories.md)
- [x] Story granularity and splitting check
- [x] GATE 1: story set approval

## Approach
Feature-based breakdown, SPIDR-sliced. Personas: Data Analyst (consumes the model), Analytics Engineer (builds and maintains it).

## Question 1
How many user stories should I create for this work?

Recommended: 3 stories (suggested range: 2-4)

Why 3:
- SPIDR "Rules": the month-over-month growth rule (LAG, percentage, NULL handling) is a distinct business rule, so it is its own story, separate from the base monthly aggregation (REQ-F-03, REQ-F-04 vs REQ-F-01, REQ-F-02, REQ-F-05, REQ-F-06).
- Testing is its own scenario class (REQ-F-07), so tests are a separate story rather than extra ACs on the model stories.
- Each story stays within the sizing ceilings (at most 5 ACs, one layer, one scenario class). The work is small, so a fourth story would add overhead without reducing review effort.
- Honest limit on parallelism: all three touch one model, so stories 1.2 and 1.3 depend on 1.1. The Dependency Graph stage will record this; only a 2-story split (model + growth together, tests separate) would allow tests to be written against the agreed column contract in parallel.

Reply with a number to override, or "ok"/"use recommended" to accept 3.

[Answer]: ok, use recommended (3)
