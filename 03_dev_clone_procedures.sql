/* =====================================================================
   03_dev_clone_procedure.sql
   Proof of concept: ad-hoc, developer-triggered DEV sandboxes created as
   zero-copy clones of TEST (not PROD), matching the recommended
   architecture - DEV is one hop removed from real data, since TEST is
   already subsetted and sanitized.

   Run this after 02_test_extraction_sanitization.sql.
   ===================================================================== */

-- EXECUTE AS CALLER: the clone is created, and therefore owned, in the
-- *developer's* own session context (so each dev ends up owning their
-- own sandbox) rather than being owned by whoever owns this procedure.
CREATE OR REPLACE PROCEDURE TEST.ADMIN.SP_CREATE_DEV_CLONE(DEV_DB_NAME VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    CREATE OR REPLACE DATABASE IDENTIFIER(:DEV_DB_NAME) CLONE TEST;
    RETURN 'Dev sandbox ready: ' || :DEV_DB_NAME || ' (zero-copy clone of TEST)';
END;
$$;

-- Companion teardown procedure, so sandboxes stay short-lived/ephemeral
-- and don't drift from PROD structure over time.
CREATE OR REPLACE PROCEDURE TEST.ADMIN.SP_DROP_DEV_CLONE(DEV_DB_NAME VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    DROP DATABASE IF EXISTS IDENTIFIER(:DEV_DB_NAME);
    RETURN 'Dropped: ' || :DEV_DB_NAME;
END;
$$;

/* ---------------------------------------------------------------------
   Ad-hoc usage by a developer (run interactively, any time):

   USE ROLE DEVELOPER;
   CALL TEST.ADMIN.SP_CREATE_DEV_CLONE('DEV_DKIRBY');
   -- ... do work in DEV_DKIRBY ...
   CALL TEST.ADMIN.SP_DROP_DEV_CLONE('DEV_DKIRBY');   -- when finished

   Re-running SP_CREATE_DEV_CLONE at any point re-clones from the latest
   TEST snapshot (CREATE OR REPLACE), giving the developer a cheap way to
   reset their sandbox back to a known-good state.
   --------------------------------------------------------------------- */

-- Demo run for this PoC:
CALL TEST.ADMIN.SP_CREATE_DEV_CLONE('DEV_DKIRBY');

SELECT * FROM DEV_DKIRBY.CORE.GLD_CUSTOMERS ORDER BY CUSTOMER_ID;
