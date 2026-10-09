Feature: Data quality tests for agg_monthly_revenue (Story 1.3)

  Background:
    Given agg_monthly_revenue is built from gold.obt as in Stories 1.1 and 1.2

  @AC-1
  Scenario: not_null tests pass on clean data
    Given no row has an empty month, city or revenue
    When the not_null tests on month, city and revenue run
    Then all three tests pass

  @AC-1
  Scenario: not_null test fails on an empty city
    Given one row has an empty city
    When the not_null test on city runs
    Then that test fails and reports 1 failing row

  @AC-2
  Scenario: The month-and-city uniqueness test passes on clean data
    Given every (month, city) pair appears once
    When the singular uniqueness test runs
    Then it returns no rows and passes

  @AC-2
  Scenario: The uniqueness test fails on a duplicate pair
    Given the pair (2025-01, "Paris") appears twice
    When the singular uniqueness test runs
    Then it returns that pair and fails

  @AC-3
  Scenario: The growth test passes when values agree
    Given Paris has revenue 1000.00 in 2025-01 and 1200.00 in 2025-02 with mom_growth_pct 20.00
    When the singular growth test recomputes growth from obt
    Then the recomputed value 20.00 equals the model value and the test passes

  @AC-3
  Scenario: The growth test fails when a value is wrong
    Given the model shows mom_growth_pct 25.00 for Paris in 2025-02
    When the singular growth test recomputes growth from obt
    Then the recomputed value 20.00 differs and the test fails

  @AC-4
  Scenario: Tests compile
    When dbt parse and dbt compile run
    Then all new tests compile without error

  @AC-5
  Scenario: No Snowflake connection is available
    Given no Snowflake connection is configured
    When the test step is executed
    Then dbt test is not run against the warehouse
    And the evidence records that execution was not possible, with the reason
