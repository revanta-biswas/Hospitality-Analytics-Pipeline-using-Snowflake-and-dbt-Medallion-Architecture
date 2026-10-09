Feature: Monthly revenue by city with month-over-month growth, end to end

  Background:
    Given gold.obt holds these bookings, one row per booking
      | booking_id | city  | booking_date | total_amount | booking_status |
      | B1         | Paris | 2025-01-10   | 600.00       | confirmed      |
      | B2         | Paris | 2025-01-25   | 400.00       | cancelled      |
      | B3         | Paris | 2025-02-05   | 1200.00      | confirmed      |
      | B4         | Paris | 2025-04-18   | 900.00       | confirmed      |
      | B5         | Rome  | 2025-02-07   | 500.00       | confirmed      |

  @REQ-F-02 @REQ-F-03 @REQ-F-04
  Scenario: An analyst reads revenue and growth per city across a gap month  # stories 1.1 and 1.2
    When the analyst queries agg_monthly_revenue
    Then Paris for 2025-01 shows revenue 1000.00, previous_month_revenue empty and mom_growth_pct empty
    And Paris for 2025-02 shows revenue 1200.00, previous_month_revenue 1000.00 and mom_growth_pct 20.00
    And Paris for 2025-04 shows revenue 900.00, previous_month_revenue 1200.00 and mom_growth_pct -25.00
    And Rome for 2025-02 shows revenue 500.00, previous_month_revenue empty and mom_growth_pct empty
    And there is no row for Paris in 2025-03

  @REQ-F-07 @REQ-F-04 @REQ-NF-02
  Scenario: The quality tests agree with the model's growth values  # stories 1.2 and 1.3
    Given the model built as above
    When the not_null, unique month-and-city and growth-recomputation tests are compiled
    Then all three test definitions compile without error
    And, where a Snowflake connection exists, all three tests pass on the data above
    And, where no connection exists, the run records that execution was not possible
