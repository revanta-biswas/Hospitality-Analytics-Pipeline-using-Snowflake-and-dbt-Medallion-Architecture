-- Storage Integration: Snowflake assumes an AWS IAM role to reach the S3 bucket.
-- No AWS access key / secret key is ever stored in Snowflake or in this file.
-- STORAGE_AWS_ROLE_ARN is operator-supplied (created once by an account admin,
-- outside of this DDL) — replace the placeholder ARN below with the real role
-- before running against a live account.
CREATE STORAGE INTEGRATION IF NOT EXISTS s3_int
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<your_account_id>:role/<your_snowflake_access_role>'
  STORAGE_ALLOWED_LOCATIONS = ('s3://your_s3_bucket_path/');

-- After creating the integration, an account admin runs
-- `DESC INTEGRATION s3_int` to retrieve STORAGE_AWS_IAM_USER_ARN and
-- STORAGE_AWS_EXTERNAL_ID, then updates the AWS IAM role's trust policy to
-- allow that Snowflake IAM user to assume it. This is an out-of-band, one-time
-- AWS console/IAM step and is not expressible as Snowflake SQL.

CREATE OR REPLACE STAGE s3_stage
STORAGE_INTEGRATION = s3_int
FILE_FORMAT = csv_format
URL='s3://your_s3_bucket_path/';
