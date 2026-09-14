# Cycle-level cross-story journeys — Epic: Harden Pipeline (Security & Data Quality)
#
# Per common/behavior-spec.md Section 3: this file holds ONLY genuine journeys that span multiple
# work units and that no single story owns. It is NOT a copy of per-story scenarios.
#
# Assessment for this epic: each of the 8 stories (1.1-1.7) is an independent, self-contained
# hardening fix to its own file/config surface (Snowflake bootstrap SQL, dbt profile, dbt schema
# tests, fact.sql, dbt_project.yml/properties.yml, sources.yml) with no runtime interaction between
# them -- a user/system does not traverse from one story's change into another's in a single flow,
# because this is a headless batch data pipeline, not an interactive system with user journeys.
#
# The one place multiple stories' outputs genuinely compose is Story 1.8's own CI workflow, which
# validates (via dbt parse/dbt compile) that ALL of 1.1-1.7's changes coexist without breaking the
# project. That composition is already Story 1.8's own AC-4 and its own story-level feature file
# (spec/behavior/story-1.8.feature) -- restating it here would violate the "not a copy of per-story
# scenarios" rule.
#
# Explicit record per common/behavior-spec.md Section 3: this requirement set has NO genuine
# cross-story journey beyond what Story 1.8 already owns as its own acceptance criterion. No
# @REQ-tagged scenarios are written below.

Feature: Cross-story journeys for the pipeline-hardening epic

  # No cross-story scenarios apply to this epic -- see assessment above.
  # B3 (common/behavior-spec.md Section 6) will run this feature file (0 scenarios) alongside
  # every story's own feature file at last-unit time, per the standard tier rules.
