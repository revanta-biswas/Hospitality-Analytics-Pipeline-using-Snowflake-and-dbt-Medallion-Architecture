# aire State Tracking

## Project Information
- **Project Type**: Brownfield
- **Start Date**: 2026-09-14T08:02:22Z
- **Current Stage**: PLANNING - Requirements Analysis (pending)

## Workspace State
- **Existing Code**: Yes
- **Programming Languages**: SQL (Jinja/dbt), YAML
- **Build System**: dbt CLI (dbt-core >= 1.11.7, dbt-snowflake >= 1.11.3), Python env via uv (pyproject.toml / uv.lock)
- **Project Structure**: Single-module data pipeline (Medallion architecture: Bronze/Silver/Gold on Snowflake via dbt)
- **Workspace Root**: /Users/revanta.biswas/Desktop/Hospitality-Analytics-Pipeline-using-Snowflake-and-dbt-Medallion-Architecture
- **Reverse Engineering Needed**: No (Atlas deep dive doc pulled — see Existing-System Context below)

## Code Root
- **Root**: `src/` (dbt project at `src/dbt_code/`, Snowflake bootstrap scripts at `src/snowflake/`)
- **Note**: Moved from repo-root `dbt_code/` and `Snowflake/` in commit `c301415` (2026-09-14, prior to this AIRE cycle). dbt paths are relative to `dbt_project.yml` so the move required no internal config changes.

## Existing-System Context
- **Workspace type**: brownfield
- **Helix MCP**: connected
- **Source**: atlas
- **Components in scope**: whole estate (single-module pipeline — no scoping split needed)
- **Atlas deep dive doc**: spec/plans/atlas-deep-dive.md
- **Recorded**: 2026-09-14T07:59:53Z

## Helix MCP Binding
- **Server**: helix
- **Docs tool(s)**: mcp__helix__get_solution_document_tool, mcp__helix__list_solution_documents_tool — fetch/list solution documents (deep dive doc lives here)
- **Graph/Search tool(s)**: mcp__helix__codebase_agent_query (relationship/impact queries), mcp__helix__document_chatbot_query (doc/knowledge-base queries), mcp__helix__codebase_cypher_query, mcp__helix__graph_change_impact
- **Estate / workspace id**: solution_id 992 ("Hospitality-Analytics-Pipeline-using-Snowflake-and-dbt-Medallion-Architecture")
- **Resolved**: 2026-09-14T07:59:53Z

## Tracker
- **Type**: GITHUB
- **Org/Repo**: revanta-biswas/Hospitality-Analytics-Pipeline-using-Snowflake-and-dbt-Medallion-Architecture
- **Parent Epic**: Milestone #1 — "Epic: Harden Pipeline (Security & Data Quality)"
- **Epic URL**: https://github.com/revanta-biswas/Hospitality-Analytics-Pipeline-using-Snowflake-and-dbt-Medallion-Architecture/milestone/1

## Epic Intent (no external Epic provided)
- **Summary**: Harden the pipeline — address Atlas-identified Priority 1/2 findings: hard-coded/plaintext
  credentials (Snowflake COPY scripts, dbt profiles.yml), zero data tests, `fact.sql` bypassing `ref()`
  for dimension joins, and related data-quality/config-consistency debt.
- **Source**: User-directed epic intent captured in chat during Workspace Detection (no tracker Epic existed to fetch).

## Branching
- Base Branch: main
- Epic Branch: epic/harden-pipeline-security-and-data-quality (pushed to origin)
- Epic PR: (not raised — raised manually at cycle end via pr-generator)

## Context Project
- **Existing Knowledge**: No
- **Existing Knowledge Path(s)**: —
- **New References**: No
- **New Reference Path(s)**: —
- **Recorded**: 2026-09-14T08:02:22Z (clarified: "no" applies to both parts)

## Extension Configuration
- **Security Baseline**: Enabled = Yes (always mandatory)
- **Playwright Test Automation**: Enabled = Yes (always mandatory)

## team_size
- team_size: 2 (fixed default, never asked)
- story_creation_mode: all-at-once (fixed default, never asked)

## team_size
- team_size: 2 (fixed default, never asked)
- story_creation_mode: all-at-once (fixed default, never asked)
- target_story_count: 8

## Story Tracker

| Story | Title | Requires | Tracker ID | Status | PR | Merged | Start | End | Recorded |
|-------|-------|----------|------------|--------|----|--------|-------|-----|----------|
| 1.1 | Replace inline AWS credentials with a Snowflake Storage Integration | TBD | #1 | 🟢 Ready for Development | — | — | | | 2026-09-14 08:30 |
| 1.2 | Externalize dbt connection secrets via environment variables | TBD | #2 | 🟢 Ready for Development | — | — | | | 2026-09-14 08:30 |
| 1.3 | Add core data integrity tests (uniqueness, not-null, referential integrity) | TBD | #3 | 🟢 Ready for Development | — | — | | | 2026-09-14 08:30 |
| 1.4 | Add accepted-values tests for derived categorical columns | TBD | #4 | 🟢 Ready for Development | — | — | | | 2026-09-14 08:30 |
| 1.5 | Fix fact.sql to depend on dimension snapshots via ref() | TBD | #5 | 🟢 Ready for Development | — | — | | | 2026-09-14 08:30 |
| 1.6 | Reconcile the Bronze materialization configuration conflict | TBD | #6 | 🟢 Ready for Development | — | — | | | 2026-09-14 08:30 |
| 1.7 | Add source freshness checks to the staging source | TBD | #7 | 🟢 Ready for Development | — | — | | | 2026-09-14 08:30 |
| 1.8 | Add a static-validation CI workflow | TBD | #8 | 🟢 Ready for Development | — | — | | | 2026-09-14 08:30 |

## Stage Progress
### 🔵 PLANNING PHASE
- [x] Workspace Detection
- [x] Reverse Engineering (skipped — Atlas deep dive doc reused)
- [x] Requirements Analysis (spec/plans/requirements.md — APPROVED 2026-09-14T08:11:00Z)
- [x] User Stories — COMPLETE (8 stories generated, GATE 1 approved, pushed to GitHub as issues #1-#8, linked to Milestone #1)
- [ ] Dependency Graph
- [ ] Workflow Planning
- [ ] Application Design
- [ ] System-Level Design stages
- [ ] STOP CHECKPOINT
- [ ] Code Generation (per-story via dev-implement)
