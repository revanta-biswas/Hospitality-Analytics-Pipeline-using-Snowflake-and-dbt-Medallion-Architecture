Feature: Externalize dbt connection secrets via environment variables

  As a Data Engineer
  I want profiles.yml to read every connection secret from an environment variable
  So that no plaintext credential value can ever be committed to the repo

  Background:
    Given the dbt connection profile at "src/dbt_code/profiles.yml"

  @AC-1
  Scenario: account, user, password, role, and warehouse are env_var references
    When the profile's connection fields are inspected
    Then "account" is an env_var() reference
    And "user" is an env_var() reference
    And "password" is an env_var() reference
    And "role" is an env_var() reference
    And "warehouse" is an env_var() reference

  @AC-2
  Scenario: schema, threads, and type remain literal
    When the profile's non-secret operational fields are inspected
    Then "schema" is present as a literal value
    And "threads" is present as a literal value
    And "type" is present as a literal value

  @AC-3
  Scenario: required environment variable names are documented
    When "src/dbt_code/README.md" is inspected
    Then it documents every DBT_ environment variable name referenced in profiles.yml

  @AC-4
  Scenario: repo-wide search for a literal secret value returns zero matches
    When "src/dbt_code/profiles.yml" is searched for literal password, account, or user values
    Then zero matches are found outside of env_var() references

  @AC-5
  Scenario: profiles.yml remains valid YAML
    When "src/dbt_code/profiles.yml" is parsed as YAML
    Then it parses without error
