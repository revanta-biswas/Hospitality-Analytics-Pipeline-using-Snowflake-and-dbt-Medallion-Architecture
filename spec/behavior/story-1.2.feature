Feature: Month-over-month revenue growth columns (Story 1.2)

  Background:
    Given agg_monthly_revenue has revenue per city and month
      | city  | month   | revenue |
      | Paris | 2025-01 | 1000.00 |
      | Paris | 2025-02 | 1200.00 |
      | Paris | 2025-04 | 900.00  |
      | Rome  | 2025-02 | 500.00  |
      | Oslo  | 2025-01 | 0.00    |
      | Oslo  | 2025-02 | 80.00   |
      | Lima  | 2025-01 | 300.00  |
      | Lima  | 2025-02 | 400.00  |

  @AC-1
  Scenario: Previous revenue comes from the prior row of the same city
    When the analyst queries agg_monthly_revenue
    Then Paris for 2025-02 shows previous_month_revenue 1000.00
    And Rome for 2025-02 shows previous_month_revenue empty, not Paris's value

  @AC-1
  Scenario: A month with no bookings is not filled
    When the analyst queries agg_monthly_revenue
    Then there is no row for Paris in 2025-03
    And Paris for 2025-04 shows previous_month_revenue 1200.00, from 2025-02

  @AC-2
  Scenario: The first month of a city has no previous revenue
    When the analyst queries agg_monthly_revenue
    Then Paris for 2025-01 shows previous_month_revenue empty
    And Rome for 2025-02 shows previous_month_revenue empty

  @AC-3
  Scenario: Growth is a percentage rounded to two decimals
    When the analyst queries agg_monthly_revenue
    Then Paris for 2025-02 shows mom_growth_pct 20.00
    And Lima for 2025-02 shows mom_growth_pct 33.33
    And Paris for 2025-04 shows mom_growth_pct -25.00

  @AC-4
  Scenario: No previous row gives no growth value
    When the analyst queries agg_monthly_revenue
    Then Paris for 2025-01 shows mom_growth_pct empty
    And the query returns without an error

  @AC-4
  Scenario: Previous revenue of zero gives no growth value and no division error
    When the analyst queries agg_monthly_revenue
    Then Oslo for 2025-02 shows previous_month_revenue 0.00 and mom_growth_pct empty
    And the query returns without a division-by-zero error

  @AC-5
  Scenario: The final column contract
    When the analyst queries agg_monthly_revenue
    Then the columns are exactly month, city, revenue, previous_month_revenue, mom_growth_pct in that order
    And no country column is present
