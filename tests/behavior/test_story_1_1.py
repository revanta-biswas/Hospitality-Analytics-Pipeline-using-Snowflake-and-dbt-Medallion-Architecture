"""pytest-bdd runner for Story 1.1 — Snowflake Storage Integration.

Binds spec/behavior/story-1.1.feature to the step definitions in
tests/behavior/steps/. Per common/behavior-spec.md Section 4.1, pytest-bdd is
used (not `behave`) because scenarios() takes an arbitrary feature path with
no adjacency requirement to the steps module.
"""
from pytest_bdd import scenarios

scenarios("../../spec/behavior/story-1.1.feature")
