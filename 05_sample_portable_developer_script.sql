/* =====================================================================
   05_sample_portable_developer_script.sql
   Demonstrates the "no hard-coded table names" workflow.

   RULE: SQL in this script never qualifies a table with a database name
   (no PROD.CORE.x, TEST.CORE.x, or DEV_xxx.CORE.x references). It only
   ever uses two-part schema.table names. The ONLY thing that changes
   between environments is the `USE DATABASE` line at the top - set via
   session context (interactively) or connection/role defaults (in a
   CI/CD pipeline). This script's logic itself never needs editing.
   ===================================================================== */

-- STEP 0: point this session at the target environment.
-- Set the database in the Snowsight UI to target DEV / TEST / PROD - nothing below changes.
-- If using VS Code, set target database with Snowflake CLI to the appropriate data environment.
USE SCHEMA CORE;
USE WAREHOUSE COMPUTE_WH;

-- STEP 1: rebuild DAL_CUSTOMERS from LND_CUSTOMERS (schema.table only)
CREATE OR REPLACE TABLE DAL_CUSTOMERS AS
SELECT
    TRY_CAST(CUSTOMER_ID AS NUMBER)      AS CUSTOMER_ID,
    FULL_NAME,
    EMAIL,
    PHONE,
    SIN,
    ACCOUNT_NUMBER,
    TRY_CAST(BALANCE AS NUMBER(18,2))    AS BALANCE,
    TRY_CAST(OPEN_DATE AS DATE)          AS OPEN_DATE,
    CURRENT_TIMESTAMP()                  AS LOAD_TS
FROM LND_CUSTOMERS;

-- STEP 2: rebuild GLD_CUSTOMERS from DAL_CUSTOMERS (schema.table only)
CREATE OR REPLACE TABLE GLD_CUSTOMERS AS
SELECT
    CUSTOMER_ID,
    FULL_NAME,
    BALANCE,
    CASE
        WHEN BALANCE >= 10000 THEN 'TIER_1'
        WHEN BALANCE >= 1000  THEN 'TIER_2'
        ELSE 'TIER_3'
    END                                             AS BALANCE_TIER,
    DATEDIFF('day', OPEN_DATE, CURRENT_DATE())      AS ACCOUNT_AGE_DAYS,
    CURRENT_TIMESTAMP()                             AS REFRESHED_AT
FROM DAL_CUSTOMERS;

-- Verify
SELECT * FROM GLD_CUSTOMERS ORDER BY CUSTOMER_ID;

/* ---------------------------------------------------------------------
   Why this works:
   Every environment (PROD, TEST, every DEV_* clone) has the identical
   CORE schema with identically named LND_/DAL_/GLD_ tables. Since this
   script never embeds a database name, it is byte-for-byte identical
   whether a developer runs it in their own DEV_* sandbox, a QA engineer
   runs it against TEST, or a CI/CD pipeline deploys it to PROD. Commit
   this file to Git unchanged - environment targeting is controlled
   entirely by session/connection context (or the pipeline stage),
   never by editing the SQL.
   --------------------------------------------------------------------- */
