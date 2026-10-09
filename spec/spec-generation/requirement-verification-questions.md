# Requirements Clarification Questions

Epic: add `gold/agg_monthly_revenue.sql` (monthly revenue by city with month-over-month growth).

> Answers filled in by the AI on the user's instruction ("fill urself recommneded"), choosing the recommended option for each question. Review and amend if any is wrong.
Depth: Standard. Please fill in every `[Answer]:` tag.

## Question 1
Which column defines "revenue"? `gold.obt` offers TOTAL_AMOUNT (nights x booking amount, excluding fees), SERVICE_FEE and CLEANING_FEE.

A) SUM(TOTAL_AMOUNT) only

B) SUM(TOTAL_AMOUNT + SERVICE_FEE + CLEANING_FEE) (gross)

C) Both: separate columns for booking revenue and gross revenue

D) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 2
Which bookings count towards revenue? `BOOKING_STATUS` exists in `gold.obt`; its possible values are not defined in the repo.

A) All bookings, regardless of status

B) Only confirmed/completed bookings (please list the status values after the tag)

C) Exclude cancelled bookings only (please give the cancelled status value after the tag)

D) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 3
Grouping grain: the brief says month and city. Should country also be part of the key, since the same city name can exist in different countries?

A) Month + city only, as written

B) Month + city + country

C) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 4
Which output columns do you want besides month, city and revenue?

A) Minimal: month, city, revenue, previous-month revenue, MoM growth

B) Minimal plus booking count

C) Minimal plus booking count and average booking value

D) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 5
How should month-over-month growth be expressed, and what happens when there is no previous month or the previous month is zero?

A) Percentage ((current - previous) / previous * 100), NULL when previous is missing or zero

B) Absolute difference (current - previous), NULL for the first month

C) Both percentage and absolute difference, NULL when not computable

D) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 6
`LAG()` looks at the previous row, not the previous calendar month. If a city has no bookings in a month, should that month appear as a zero row?

A) No: LAG over existing rows only (a gap means "previous" is the last month with bookings)

B) Yes: fill missing months with 0 revenue per city (calendar spine) so growth is always against the true prior month

C) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 7
Source of data for the new model:

A) `ref('obt')` (recommended: it already has BOOKING_DATE, CITY, TOTAL_AMOUNT and gives dbt lineage)

B) Hardcoded `AIRBNB.GOLD.OBT`, matching `fact.sql` style

C) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 8
Materialization and schema for `agg_monthly_revenue`:

A) Table in schema `gold` (inherits the existing gold folder config)

B) View in schema `gold`

C) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 9
Data quality tests. The repo currently has no dbt tests. Should this model get tests?

A) Yes: not_null and a unique combination of (month, city) as dbt tests in a schema yml, plus a singular test for MoM growth correctness

B) Yes: only not_null/unique generic tests

C) No tests (match the current repo)

D) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 10
Can the pipeline be run against a real Snowflake account in this cycle (for `dbt build` / `dbt test` verification)?

A) Yes, credentials are available locally

B) No: verify by compilation only (`dbt parse`/`dbt compile`), and review SQL manually

C) Other (please describe after [Answer]: tag below)

[Answer]: B

## Question 11 (extension opt-in): Resiliency Extensions
Should the resiliency baseline be applied to this project?

**What this extension is.** Directional, design-time best practices derived from the AWS Well-Architected Framework (Reliability Pillar), covering fault tolerance, availability, observability and recoverability.

**What this extension is NOT.** It does not make your workload production-ready or certify any availability, RTO or RPO target, and it is not a substitute for a formal AWS Well-Architected Review.

A) Yes: apply the resiliency baseline as directional best practices and design-time guidance

B) No: skip the resiliency baseline (suitable for PoCs, prototypes, experimental projects)

X) Other (please describe after [Answer]: tag below)

[Answer]: B

## Question 12 (extension opt-in): Property-Based Testing Extension
Should property-based testing (PBT) rules be enforced for this project?

A) Yes: enforce all PBT rules as blocking constraints

B) Partial: enforce PBT rules only for pure functions and serialization round-trips

C) No: skip all PBT rules (suitable for projects with no significant application business logic)

X) Other (please describe after [Answer]: tag below)

[Answer]: C

---
Note: Security Baseline and Playwright Test Automation are always mandatory and need no question. Playwright is expected to be N/A for stories without a UI.
