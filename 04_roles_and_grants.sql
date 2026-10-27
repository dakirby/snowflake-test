/* =====================================================================
   04_roles_and_grants.sql
   Proof of concept: minimal role structure so developers can self-serve
   DEV sandboxes without needing elevated access to PROD or TEST.

   Run this as SECURITYADMIN (or a role with MANAGE GRANTS / CREATE ROLE).
   ===================================================================== */

CREATE ROLE IF NOT EXISTS PROD_READONLY
  COMMENT = 'Read-only access to PROD - for reporting/BI consumption';

CREATE ROLE IF NOT EXISTS DEVELOPER
  COMMENT = 'Data & Analytics developers - read TEST, self-service DEV clones';

-- Wire the new roles into the role hierarchy so SYSADMIN can manage them.
GRANT ROLE PROD_READONLY TO ROLE SYSADMIN;
GRANT ROLE DEVELOPER      TO ROLE SYSADMIN;

-- Compute access
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE PROD_READONLY;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE DEVELOPER;

-- ---------------------------------------------------------------------
-- PROD: read-only, for reporting/BI
-- ---------------------------------------------------------------------
GRANT USAGE ON DATABASE PROD TO ROLE PROD_READONLY;
GRANT USAGE ON ALL SCHEMAS IN DATABASE PROD TO ROLE PROD_READONLY;
GRANT SELECT ON ALL TABLES IN SCHEMA PROD.CORE TO ROLE PROD_READONLY;
GRANT SELECT ON FUTURE TABLES IN SCHEMA PROD.CORE TO ROLE PROD_READONLY;

-- ---------------------------------------------------------------------
-- TEST: read-only for developers, plus the ability to call the dev-clone
-- procedures (the procedures themselves do the privileged work).
-- ---------------------------------------------------------------------
GRANT USAGE ON DATABASE TEST TO ROLE DEVELOPER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE TEST TO ROLE DEVELOPER;
GRANT SELECT ON ALL TABLES IN SCHEMA TEST.CORE TO ROLE DEVELOPER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA TEST.CORE TO ROLE DEVELOPER;

GRANT USAGE ON PROCEDURE TEST.ADMIN.SP_CREATE_DEV_CLONE(VARCHAR) TO ROLE DEVELOPER;
GRANT USAGE ON PROCEDURE TEST.ADMIN.SP_DROP_DEV_CLONE(VARCHAR)   TO ROLE DEVELOPER;

-- Required so SP_CREATE_DEV_CLONE (EXECUTE AS CALLER) can create a new
-- database under the developer's own session/role, and so the developer
-- ends up owning (and can freely read/write) their own DEV_* sandbox.
GRANT CREATE DATABASE ON ACCOUNT TO ROLE DEVELOPER;

-- ---------------------------------------------------------------------
-- Assign roles to people, e.g.:
-- GRANT ROLE DEVELOPER TO USER DUNCAN_KIRBY;
-- GRANT ROLE PROD_READONLY TO USER <bi_service_account>;
-- ---------------------------------------------------------------------
