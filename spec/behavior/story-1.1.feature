Feature: Monthly revenue by city model (Story 1.1)

  Background:
    Given gold.obt holds these bookings, one row per booking
      | booking_id | city  | country | booking_date | total_amount | service_fee | cleaning_fee | booking_status |
      | B1         | Paris | France  | 2025-01-10   | 600.00       | 30.00       | 20.00        | confirmed      |
      | B2         | Paris | France  | 2025-01-25   | 400.00       | 20.00       | 10.00        | cancelled      |
      | B3         | Rome  | Italy   | 2025-01-12   | 300.00       | 15.00       | 10.00        | confirmed      |
      | B4         | Paris | France  | 2025-02-05   | 1200.00      | 60.00       | 25.00        | confirmed      |
      | B5         | Paris | Texas   | 2025-01-15   | 100.00       | 5.00        | 5.00         | confirmed      |

  @AC-1
  Scenario: The model reads from obt through dbt lineage
    When dbt parses the project
    Then the only parent of agg_monthly_revenue is the obt model
    And the model's source text contains no hardcoded AIRBNB schema-qualified relation name

  @AC-1
  Scenario: A hardcoded relation name is rejected
    Given the model's source text contains "AIRBNB.GOLD.OBT" instead of a ref
    When the change is reviewed against this story
    Then the story is not accepted

  @AC-2
  Scenario: Bookings in one month and city collapse to one row
    When the analyst queries agg_monthly_revenue
    Then there is exactly one row for month 2025-01 and city "Paris" where bookings B1, B2 and B5 are counted
    And there is exactly one row for month 2025-02 and city "Paris"
    And there is exactly one row for month 2025-01 and city "Rome"

  @AC-2
  Scenario: Country is not part of the grain
    When the analyst queries agg_monthly_revenue
    Then Paris in France and Paris in Texas for 2025-01 appear together in the single row for "Paris"

  @AC-3
  Scenario: Revenue sums TOTAL_AMOUNT for every status and excludes fees
    When the analyst queries agg_monthly_revenue
    Then the row for 2025-01 and "Paris" has revenue 1100.00
    And that value is 600.00 + 400.00 + 100.00, so the cancelled booking B2 is included
    And SERVICE_FEE and CLEANING_FEE are not part of it

  @AC-3
  Scenario: Revenue is not multiplied by joins
    When the analyst queries agg_monthly_revenue
    Then the row for 2025-01 and "Rome" has revenue 300.00, equal to the single booking B3

  @AC-4
  Scenario: Output columns and materialization
    When the analyst queries agg_monthly_revenue
    Then the columns are exactly month, city and revenue
    And the model is a table in schema "gold"
    And the model file contains no config override of materialization or schema

  @AC-5
  Scenario: The model compiles
    When dbt parse and dbt compile run for agg_monthly_revenue
    Then both commands succeed

  @AC-5
  Scenario: No credentials are introduced
    When the story's changed files are scanned for secrets
    Then no password, key or account identifier appears in any file
    And dbt_code/profiles.yml is unchanged
