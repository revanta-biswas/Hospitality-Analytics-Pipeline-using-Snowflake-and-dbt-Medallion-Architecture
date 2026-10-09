# API Documentation

> Existing-system context derived locally; Atlas was not consulted.

## REST APIs
None. This is a batch data pipeline.

## Internal APIs
### Macros
- `multiply(x, y)` -> `round(x * y, 2)`
- `segment(col)` -> CASE: <100 Budget, <200 Mid-range, else Luxury
- `generate_schema_name(custom_schema_name, node)` -> custom schema verbatim, else target.schema
- `proper_name(col, node)` (in trim.sql) -> `col | trim | upper`

## Data Models
### gold.obt (relevant for revenue aggregation)
- **Fields**: BOOKING_ID, LISTING_ID, BOOKING_DATE (TIMESTAMP), TOTAL_AMOUNT, SERVICE_FEE, CLEANING_FEE, BOOKING_STATUS, CREATED_AT, HOST_ID, PROPERTY_TYPE, ROOM_TYPE, CITY, COUNTRY, ACCOMMODATES, BEDROOMS, BATHROOMS, PRICE_PER_NIGHT, PRICE_PER_NIGHT_TAG, LISTING_CREATED_AT, HOST_NAME, HOST_SINCE, IS_SUPERHOST, RESPONSE_RATE, RESPONSE_RATE_QUALITY, HOST_CREATED_AT
- **Relationships**: bookings LEFT JOIN listings on listing_id, LEFT JOIN hosts on host_id
- **Validation**: none (no dbt tests defined)
### Raw staging tables (Snowflake/Create_Table.sql)
- BOOKINGS(booking_id STRING, listing_id, booking_date TIMESTAMP, nights_booked, booking_amount, cleaning_fee, service_fee, booking_status, created_at)
- LISTINGS(listing_id, host_id, property_type, room_type, city, country, accommodates, bedrooms, bathrooms, price_per_night, created_at)
- HOSTS(host_id, host_name, host_since, is_superhost, response_rate, created_at)
