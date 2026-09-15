-- Authentication is inherited from @s3_stage's STORAGE_INTEGRATION (see Stage.sql).
-- No AWS credential clause is required or permitted here.

COPY INTO AIRBNB.STAGING.BOOKINGS
FROM @s3_stage
FILES=('bookings.csv');

COPY INTO AIRBNB.STAGING.HOSTS
FROM @s3_stage
FILES=('hosts.csv');

COPY INTO AIRBNB.STAGING.LISTINGS
FROM @s3_stage
FILES=('listings.csv');