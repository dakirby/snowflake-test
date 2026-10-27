/* =====================================================================
   01_prod_setup.sql
   Proof of concept: stand up the PROD environment with mock data.

   Layers (as table prefixes within a single CORE schema):
     LND_  Landing  - raw, source-fidelity copy (VARCHAR columns only)
     DAL_  Data Access Layer - typed/cleaned
     GLD_  Gold - curated, consumption-ready

   Run this as a role with CREATE DATABASE privileges (e.g. SYSADMIN).
   ===================================================================== */

CREATE DATABASE IF NOT EXISTS PROD
  COMMENT = 'PoC production environment';

CREATE SCHEMA IF NOT EXISTS PROD.CORE
  COMMENT = 'Landing / DAL / Gold tables for the customer mock dataset';

-- ---------------------------------------------------------------------
-- Landing layer: preserve source values exactly as received.
-- Everything is VARCHAR except pipeline-generated metadata columns.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE PROD.CORE.LND_CUSTOMERS (
    CUSTOMER_ID      VARCHAR,
    FULL_NAME        VARCHAR,
    EMAIL            VARCHAR,
    PHONE            VARCHAR,
    SIN              VARCHAR,   -- mock "social insurance number", never real PII
    ACCOUNT_NUMBER   VARCHAR,
    BALANCE          VARCHAR,
    OPEN_DATE        VARCHAR,
    SOURCE_FILE_NAME VARCHAR,
    LOAD_TS          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Synthetic mock rows only - no real member data.
INSERT INTO PROD.CORE.LND_CUSTOMERS
    (CUSTOMER_ID, FULL_NAME, EMAIL, PHONE, SIN, ACCOUNT_NUMBER, BALANCE, OPEN_DATE, SOURCE_FILE_NAME)
VALUES
    ('1001','Alice Dubois','alice.dubois@example.com','306-555-0101','000-000-001','40000000011','12500.75','2019-03-14','mock_load_20261001.csv'),
    ('1002','Brian Okafor','brian.okafor@example.com','306-555-0102','000-000-002','40000000022','450.00',  '2021-07-02','mock_load_20261001.csv'),
    ('1003','Carla Mendes','carla.mendes@example.com','306-555-0103','000-000-003','40000000033','98250.10','2015-11-23','mock_load_20261001.csv'),
    ('1004','Dakota Fontaine','dakota.fontaine@example.com','306-555-0104','000-000-004','40000000044','3200.40','2022-01-09','mock_load_20261001.csv'),
    ('1005','Elin Haas','elin.haas@example.com','306-555-0105','000-000-005','40000000055','720.00',  '2023-05-30','mock_load_20261001.csv'),
    ('1006','Farid Nasser','farid.nasser@example.com','306-555-0106','000-000-006','40000000066','15400.00','2018-08-19','mock_load_20261001.csv'),
    ('1007','Grace Littlechild','grace.littlechild@example.com','306-555-0107','000-000-007','40000000077','60.25',  '2024-02-11','mock_load_20261001.csv'),
    ('1008','Hiro Tanaka','hiro.tanaka@example.com','306-555-0108','000-000-008','40000000088','27850.00','2016-06-04','mock_load_20261001.csv'),
    ('1009','Inga Solberg','inga.solberg@example.com','306-555-0109','000-000-009','40000000099','1125.60','2020-10-27','mock_load_20261001.csv'),
    ('1010','Jaime Ortiz','jaime.ortiz@example.com','306-555-0110','000-000-010','40000000100','5400.00','2017-12-15','mock_load_20261001.csv');

-- ---------------------------------------------------------------------
-- Data Access Layer: typed and cleaned from landing.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE PROD.CORE.DAL_CUSTOMERS (
    CUSTOMER_ID    NUMBER,
    FULL_NAME      VARCHAR,
    EMAIL          VARCHAR,
    PHONE          VARCHAR,
    SIN            VARCHAR,
    ACCOUNT_NUMBER VARCHAR,
    BALANCE        NUMBER(18,2),
    OPEN_DATE      DATE,
    LOAD_TS        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO PROD.CORE.DAL_CUSTOMERS
    (CUSTOMER_ID, FULL_NAME, EMAIL, PHONE, SIN, ACCOUNT_NUMBER, BALANCE, OPEN_DATE)
SELECT
    TRY_CAST(CUSTOMER_ID AS NUMBER),
    FULL_NAME,
    EMAIL,
    PHONE,
    SIN,
    ACCOUNT_NUMBER,
    TRY_CAST(BALANCE AS NUMBER(18,2)),
    TRY_CAST(OPEN_DATE AS DATE)
FROM PROD.CORE.LND_CUSTOMERS;

-- ---------------------------------------------------------------------
-- Gold layer: curated, consumption-ready summary.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE PROD.CORE.GLD_CUSTOMERS (
    CUSTOMER_ID       NUMBER,
    FULL_NAME         VARCHAR,
    BALANCE           NUMBER(18,2),
    BALANCE_TIER      VARCHAR,
    ACCOUNT_AGE_DAYS  NUMBER,
    REFRESHED_AT      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO PROD.CORE.GLD_CUSTOMERS
    (CUSTOMER_ID, FULL_NAME, BALANCE, BALANCE_TIER, ACCOUNT_AGE_DAYS)
SELECT
    CUSTOMER_ID,
    FULL_NAME,
    BALANCE,
    CASE
        WHEN BALANCE >= 10000 THEN 'TIER_1'
        WHEN BALANCE >= 1000  THEN 'TIER_2'
        ELSE 'TIER_3'
    END AS BALANCE_TIER,
    DATEDIFF('day', OPEN_DATE, CURRENT_DATE()) AS ACCOUNT_AGE_DAYS
FROM PROD.CORE.DAL_CUSTOMERS;

-- Sanity check
SELECT * FROM PROD.CORE.GLD_CUSTOMERS ORDER BY CUSTOMER_ID;
