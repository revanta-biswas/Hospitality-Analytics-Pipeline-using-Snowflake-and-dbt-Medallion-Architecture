CREATE OR REPLACE STAGE s3_stage
FILE_FORMAT = csv_format
URL='your_s3_bucket_path';