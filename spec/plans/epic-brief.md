# Epic Brief

**Source**: User description (Tracker: LOCAL, no external Epic)

## Description
Add a gold-layer model `gold/agg_monthly_revenue.sql` that groups by
`DATE_TRUNC('month', BOOKING_DATE)` and city, and adds month-over-month growth using `LAG()`.
