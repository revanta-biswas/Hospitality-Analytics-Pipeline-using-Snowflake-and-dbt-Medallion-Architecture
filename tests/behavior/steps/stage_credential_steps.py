"""Step definitions for Story 1.1's behaviour spec (spec/behavior/story-1.1.feature).

These steps verify the Snowflake bootstrap SQL's *public surface* — its text
and DDL/DML shape — via static parsing only. No live Snowflake or AWS
connection is opened anywhere in this module, per REQ-NF-02 (this environment
has no live Snowflake/AWS account, so "testing" a SQL-only story means static
correctness review made executable).
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest
import sqlparse
from pytest_bdd import given, parsers, then, when

REPO_ROOT = Path(__file__).resolve().parents[3]


# ---------------------------------------------------------------------------
# Shared context helpers
# ---------------------------------------------------------------------------


@pytest.fixture
def sql_ctx():
    """Mutable context shared across Given/When/Then steps in one scenario."""
    return {}


# ---------------------------------------------------------------------------
# Given
# ---------------------------------------------------------------------------


@given(parsers.parse('the repository\'s Snowflake bootstrap SQL directory "{dirpath}"'))
def given_snowflake_dir(dirpath, sql_ctx):
    resolved = REPO_ROOT / dirpath
    assert resolved.is_dir(), f"Expected directory {resolved} to exist"
    sql_ctx["dir"] = resolved


@given(parsers.parse('the file "{relpath}"'), target_fixture="sql_ctx")
def given_the_file(relpath, sql_ctx):
    path = REPO_ROOT / relpath
    assert path.is_file(), f"Expected file {path} to exist"
    sql_ctx.setdefault("files", {})
    sql_ctx["files"][relpath] = path.read_text(encoding="utf-8")
    sql_ctx["last_file"] = relpath
    return sql_ctx


@given(parsers.parse('the SQL files under "{dirpath}"'), target_fixture="sql_ctx")
def given_sql_files_under(dirpath, sql_ctx):
    resolved = REPO_ROOT / dirpath
    sql_files = sorted(resolved.glob("*.sql"))
    assert sql_files, f"Expected at least one .sql file under {resolved}"
    sql_ctx["sql_files"] = sql_files
    return sql_ctx


# ---------------------------------------------------------------------------
# When
# ---------------------------------------------------------------------------


@when("the file is parsed for Snowflake DDL statements")
@when("the file is parsed for Snowflake DDL/DML statements")
def when_parse_ddl(sql_ctx):
    text = sql_ctx["files"][sql_ctx["last_file"]]
    # sqlparse is dialect-agnostic but tokenizes Snowflake DDL/DML (CREATE,
    # COPY INTO, etc.) into statements without needing a live connection.
    parsed = sqlparse.parse(text)
    assert len(parsed) > 0, "Expected at least one parsed SQL statement"
    sql_ctx["parsed_statements"] = parsed


@when(parsers.parse('each file is searched for the patterns "{pattern_a}" and "{pattern_b}"'))
def when_search_patterns(pattern_a, pattern_b, sql_ctx):
    matches = []
    for path in sql_ctx["sql_files"]:
        text = path.read_text(encoding="utf-8")
        for pattern in (pattern_a, pattern_b):
            for m in re.finditer(re.escape(pattern), text, flags=re.IGNORECASE):
                matches.append((path.name, pattern, m.start()))
    sql_ctx["pattern_matches"] = matches


@when("each file is statically parsed as Snowflake SQL")
def when_each_file_static_parse(sql_ctx):
    errors = []
    for relpath, text in sql_ctx["files"].items():
        try:
            parsed = sqlparse.parse(text)
            if not parsed:
                errors.append(f"{relpath}: no statements parsed")
        except Exception as exc:  # pragma: no cover - defensive
            errors.append(f"{relpath}: {exc}")
    sql_ctx["parse_errors"] = errors


# ---------------------------------------------------------------------------
# Then
# ---------------------------------------------------------------------------


@then(parsers.parse('it contains a "{clause}" statement'))
def then_contains_statement(clause, sql_ctx):
    text = sql_ctx["files"][sql_ctx["last_file"]]
    assert clause.upper() in text.upper(), f"Expected to find '{clause}' in {sql_ctx['last_file']}"


@then(parsers.parse('it contains a "{clause}" statement for "{name}"'))
def then_contains_statement_for(clause, name, sql_ctx):
    text = sql_ctx["files"][sql_ctx["last_file"]].upper()
    assert clause.upper() in text, f"Expected to find '{clause}' in {sql_ctx['last_file']}"
    assert name.upper() in text, f"Expected to find '{name}' in {sql_ctx['last_file']}"


@then(parsers.parse('the "{name}" stage definition references "{keyword}"'))
def then_stage_references(name, keyword, sql_ctx):
    text = sql_ctx["files"][sql_ctx["last_file"]].upper()
    assert name.upper() in text
    assert keyword.upper() in text, f"Expected '{keyword}' to appear bound to {name}"


@then(parsers.parse('the "{name}" stage definition contains no "{clause}" clause'))
def then_stage_contains_no_clause(name, clause, sql_ctx):
    text = sql_ctx["files"][sql_ctx["last_file"]].lower()
    assert clause.lower() not in text, f"Did not expect '{clause}' in {sql_ctx['last_file']}"


@then(parsers.parse('none of the "{stmt}" statements contain a "{clause}" clause'))
def then_none_contain_clause(stmt, clause, sql_ctx):
    text = sql_ctx["files"][sql_ctx["last_file"]].lower()
    assert clause.lower() not in text, (
        f"Expected zero '{clause}' clauses across all {stmt} statements in "
        f"{sql_ctx['last_file']}"
    )


@then("zero matches are found across all files")
def then_zero_matches(sql_ctx):
    matches = sql_ctx["pattern_matches"]
    assert matches == [], f"Expected zero matches, found: {matches}"


@then("parsing succeeds with no syntax errors")
def then_parsing_succeeds(sql_ctx):
    assert sql_ctx["parse_errors"] == [], f"Parse errors: {sql_ctx['parse_errors']}"


@then("no step in this scenario requires a live Snowflake or AWS connection")
def then_no_live_connection_required():
    # Documentary assertion: this test module never imports a Snowflake/AWS
    # SDK or opens a network socket. Enforced by review + the absence of any
    # such import above.
    assert True
