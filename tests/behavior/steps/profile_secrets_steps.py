"""Step definitions for Story 1.2 — externalizing dbt connection secrets via env_var().

No live Snowflake account exists in this environment (REQ-NF-02), so these steps verify the
YAML text/structure of profiles.yml and README.md directly rather than attempting a live
connection.
"""
import re
from pathlib import Path

import yaml
from pytest_bdd import given, parsers, then, when

REPO_ROOT = Path(__file__).resolve().parents[3]
PROFILES_PATH = REPO_ROOT / "src" / "dbt_code" / "profiles.yml"
README_PATH = REPO_ROOT / "src" / "dbt_code" / "README.md"

ENV_VAR_RE = re.compile(r"^\{\{\s*env_var\(\s*'([A-Za-z0-9_]+)'\s*\)\s*\}\}$")


@given('the dbt connection profile at "src/dbt_code/profiles.yml"', target_fixture="profiles_path")
def _profiles_path():
    assert PROFILES_PATH.exists(), f"expected {PROFILES_PATH} to exist"
    return PROFILES_PATH


def _parsed_profile(path):
    return yaml.safe_load(path.read_text())


@when("the profile's connection fields are inspected", target_fixture="profile_fields")
def _inspect_connection_fields(profiles_path):
    doc = _parsed_profile(profiles_path)
    return doc["dbt_code"]["outputs"]["dev"]


@then(parsers.parse('"{field}" is an env_var() reference'))
def _field_is_env_var(profile_fields, field):
    value = profile_fields[field]
    match = ENV_VAR_RE.match(value.strip())
    assert match, f"expected {field!r} to be an env_var() reference, got {value!r}"


@when("the profile's non-secret operational fields are inspected", target_fixture="profile_fields")
def _inspect_operational_fields(profiles_path):
    doc = _parsed_profile(profiles_path)
    return doc["dbt_code"]["outputs"]["dev"]


@then(parsers.parse('"{field}" is present as a literal value'))
def _field_is_literal(profile_fields, field):
    value = profile_fields[field]
    if isinstance(value, str):
        assert not ENV_VAR_RE.match(value.strip()), (
            f"expected {field!r} to remain a literal value, got env_var() reference {value!r}"
        )
    # non-string literals (e.g. threads: 1) are trivially literal


@when('"src/dbt_code/README.md" is inspected', target_fixture="readme_text")
def _inspect_readme():
    assert README_PATH.exists(), f"expected {README_PATH} to exist"
    return README_PATH.read_text()


@then("it documents every DBT_ environment variable name referenced in profiles.yml")
def _readme_documents_env_vars(readme_text):
    doc = _parsed_profile(PROFILES_PATH)
    fields = doc["dbt_code"]["outputs"]["dev"]
    referenced_vars = set()
    for value in fields.values():
        if isinstance(value, str):
            match = ENV_VAR_RE.match(value.strip())
            if match:
                referenced_vars.add(match.group(1))
    assert referenced_vars, "expected at least one env_var() reference in profiles.yml"
    missing = [v for v in referenced_vars if v not in readme_text]
    assert not missing, f"README.md is missing documentation for: {missing}"


@when('"src/dbt_code/profiles.yml" is searched for literal password, account, or user values', target_fixture="raw_profile_text")
def _search_raw_text():
    return PROFILES_PATH.read_text()


@then("zero matches are found outside of env_var() references")
def _zero_literal_secret_matches(raw_profile_text):
    doc = yaml.safe_load(raw_profile_text)
    fields = doc["dbt_code"]["outputs"]["dev"]
    for key in ("account", "user", "password", "role", "warehouse"):
        value = fields[key]
        assert isinstance(value, str) and ENV_VAR_RE.match(value.strip()), (
            f"expected {key!r} to be an env_var() reference with no literal value, got {value!r}"
        )


@when('"src/dbt_code/profiles.yml" is parsed as YAML', target_fixture="yaml_parse_result")
def _parse_yaml():
    try:
        return ("ok", yaml.safe_load(PROFILES_PATH.read_text()))
    except yaml.YAMLError as exc:  # pragma: no cover - failure path
        return ("error", exc)


@then("it parses without error")
def _parses_without_error(yaml_parse_result):
    status, payload = yaml_parse_result
    assert status == "ok", f"expected profiles.yml to parse cleanly, got error: {payload}"
