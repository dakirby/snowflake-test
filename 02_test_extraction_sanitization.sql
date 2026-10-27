/* =====================================================================
   02_test_extraction_sanitization.sql
   Proof of concept: TEST environment, populated by a governed extraction
   task that subsets and sanitizes PROD data.

   Run this after 01_prod_setup.sql.
   ===================================================================== */

CREATE DATABASE IF NOT EXISTS TEST
  COMMENT = 'PoC TEST environment - sanitized subset of PROD';

CREATE SCHEMA IF NOT EXISTS TEST.CORE
  COMMENT = 'Sanitized LND / DAL / GLD tables, refreshed from PROD';

CREATE SCHEMA IF NOT EXISTS TEST.ADMIN
  COMMENT = 'Control-plane objects: extraction/sanitization and dev-clone procedures';

-- ---------------------------------------------------------------------
-- Extraction + sanitization procedure.
--   - Subsets rows (SAMPLE) so TEST stays small and representative.
--   - Masks/replaces anything that identifies a real person:
--       * SIN / ACCOUNT_NUMBER -> one-way hash (SHA2)
--       * FULL_NAME / EMAIL / PHONE -> deterministic synthetic values
--         derived from CUSTOMER_ID (keeps joins/row counts meaningful,
--         removes any real identity).
--   - Rebuilds DAL_/GLD_ tables from whatever rows survived in LND_,
--     so all three layers stay row-aligned.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE TEST.ADMIN.SP_EXTRACT_SANITIZE_PROD_TO_TEST()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    CREATE OR REPLACE TABLE TEST.CORE.LND_CUSTOMERS AS
    SELECT
        CUSTOMER_ID,
        'Test Customer ' || CUSTOMER_ID                         AS FULL_NAME,
        'test.customer.' || CUSTOMER_ID || '@example.com'       AS EMAIL,
        '306-555-' || RIGHT('0000' || CUSTOMER_ID, 4)           AS PHONE,
        SHA2(SIN, 256)                                          AS SIN,
        SHA2(ACCOUNT_NUMBER, 256)                               AS ACCOUNT_NUMBER,
        BALANCE,
        OPEN_DATE,
        SOURCE_FILE_NAME,
        CURRENT_TIMESTAMP()                                     AS LOAD_TS
    FROM PROD.CORE.LND_CUSTOMERS
    SAMPLE (50);  -- ~50% subset; adjust to keep TEST representative but small

    CREATE OR REPLACE TABLE TEST.CORE.DAL_CUSTOMERS AS
    SELECT
        d.CUSTOMER_ID,
        l.FULL_NAME,
        l.EMAIL,
        l.PHONE,
        l.SIN,
        l.ACCOUNT_NUMBER,
        d.BALANCE,
        d.OPEN_DATE,
        CURRENT_TIMESTAMP() AS LOAD_TS
    FROM PROD.CORE.DAL_CUSTOMERS d
    INNER JOIN TEST.CORE.LND_CUSTOMERS l
        ON l.CUSTOMER_ID = d.CUSTOMER_ID::VARCHAR;

    CREATE OR REPLACE TABLE TEST.CORE.GLD_CUSTOMERS AS
    SELECT
        g.CUSTOMER_ID,
        t.FULL_NAME,
        g.BALANCE,
        g.BALANCE_TIER,
        g.ACCOUNT_AGE_DAYS,
        CURRENT_TIMESTAMP() AS REFRESHED_AT
    FROM PROD.CORE.GLD_CUSTOMERS g
    INNER JOIN TEST.CORE.DAL_CUSTOMERS t
        ON t.CUSTOMER_ID = g.CUSTOMER_ID;

    RETURN 'TEST refreshed from PROD at ' || CURRENT_TIMESTAMP()::VARCHAR;
END;
$$;

-- ---------------------------------------------------------------------
-- Task: automates the refresh. Suspended by default on creation -
-- resume it to schedule, or just CALL the procedure directly for
-- ad-hoc/manual refreshes during the PoC.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TASK TEST.ADMIN.TASK_REFRESH_TEST_FROM_PROD
  WAREHOUSE = COMPUTE_WH
  SCHEDULE  = 'USING CRON 0 6 * * * America/Regina'  -- nightly 6am Regina time; adjust as needed
AS
  CALL TEST.ADMIN.SP_EXTRACT_SANITIZE_PROD_TO_TEST();

ALTER TASK TEST.ADMIN.TASK_REFRESH_TEST_FROM_PROD RESUME;

-- ---------------------------------------------------------------------
-- Ad-hoc / manual run for the PoC demo (no need to wait for the schedule):
-- ---------------------------------------------------------------------
CALL TEST.ADMIN.SP_EXTRACT_SANITIZE_PROD_TO_TEST();

-- Sanity check: confirm PII columns are no longer human-readable
SELECT * FROM TEST.CORE.LND_CUSTOMERS ORDER BY CUSTOMER_ID;
