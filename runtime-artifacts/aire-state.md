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
- **Parent Epic**: none (no Epic link/key provided; epic intent captured below)
- **Epic URL**: n/a

## Epic Intent (no external Epic provided)
- **Summary**: Harden the pipeline — address Atlas-identified Priority 1/2 findings: hard-coded/plaintext
  credentials (Snowflake COPY scripts, dbt profiles.yml), zero data tests, `fact.sql` bypassing `ref()`
  for dimension joins, and related data-quality/config-consistency debt.
- **Source**: User-directed epic intent captured in chat during Workspace Detection (no tracker Epic existed to fetch).

## Branching
- Base Branch: main
- Epic Branch: epic/harden-pipeline-security-and-data-quality
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

## Stage Progress
- [x] Workspace Detection
- [ ] Requirements Analysis
- [ ] User Stories
- [ ] Dependency Graph
- [ ] Workflow Planning
- [ ] Application Design
- [ ] System-Level Design stages
- [ ] STOP CHECKPOINT
- [ ] Code Generation (per-story via dev-implement)
