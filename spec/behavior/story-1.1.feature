Feature: Snowflake S3 ingestion authenticates via Storage Integration, not inline AWS keys

  As a Data Engineer
  I want the S3 ingestion stage to authenticate via a Snowflake Storage Integration
  instead of inline AWS keys
  So that no AWS credential is ever inlined in committed SQL

  Background:
    Given the repository's Snowflake bootstrap SQL directory "src/snowflake"

  @AC-1
  Scenario: Stage.sql creates a Storage Integration and binds the stage to it
    Given the file "src/snowflake/Stage.sql"
    When the file is parsed for Snowflake DDL statements
    Then it contains a "CREATE STORAGE INTEGRATION" statement
    And it contains a "CREATE OR REPLACE STAGE" statement for "s3_stage"
    And the "s3_stage" stage definition references "STORAGE_INTEGRATION"
    And the "s3_stage" stage definition contains no "credentials=(aws_key_id" clause
    And the "s3_stage" stage definition contains no "aws_secret_key" clause

  @AC-2
  Scenario: Copy_Into.sql no longer contains any credentials clause
    Given the file "src/snowflake/Copy_Into.sql"
    When the file is parsed for Snowflake DDL/DML statements
    Then it contains a "COPY INTO" statement for "AIRBNB.STAGING.BOOKINGS"
    And it contains a "COPY INTO" statement for "AIRBNB.STAGING.HOSTS"
    And it contains a "COPY INTO" statement for "AIRBNB.STAGING.LISTINGS"
    And none of the "COPY INTO" statements contain a "credentials=(" clause

  @AC-3
  Scenario: Repo-wide search for AWS key literals returns zero matches
    Given the SQL files under "src/snowflake"
    When each file is searched for the patterns "aws_key_id" and "aws_secret_key"
    Then zero matches are found across all files

  @AC-4
  Scenario: Edited SQL is syntactically valid Snowflake DDL/DML without a live account
    Given the file "src/snowflake/Stage.sql"
    And the file "src/snowflake/Copy_Into.sql"
    When each file is statically parsed as Snowflake SQL
    Then parsing succeeds with no syntax errors
    And no step in this scenario requires a live Snowflake or AWS connection
