COPY INTO AIRBNB.STAGING.BOOKINGS
FROM @s3_stage
FILES=('bookings.csv')
CREDENTIALS=(aws_key_id = 'yourkey', aws_secret_key = 'yoursecretkey');

COPY INTO AIRBNB.STAGING.HOSTS
FROM @s3_stage
FILES=('hosts.csv')
CREDENTIALS=(aws_key_id = 'yourkey', aws_secret_key = 'yoursecretkey');

COPY INTO AIRBNB.STAGING.LISTINGS
FROM @s3_stage
FILES=('listings.csv')
CREDENTIALS=(aws_key_id = 'yourkey', aws_secret_key = 'yoursecretkey');