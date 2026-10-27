# Snowflake PROD / TEST / DEV Proof of Concept

Five scripts, run in order, that stand up a working example of the
source control architecture: PROD as the
source of truth, TEST as a governed, sanitized extraction from PROD, and
DEV as an ad-hoc, zero-copy clone for individual developers.

| Script | Purpose |
|---|---|
| `01_prod_setup.sql` | Creates the `PROD` database with a `CORE` schema containing `LND_CUSTOMERS`, `DAL_CUSTOMERS`, `GLD_CUSTOMERS` (mock data only). |
| `02_test_extraction_sanitization.sql` | Creates `TEST`, plus a stored procedure + task that subsets (`SAMPLE`) and sanitizes (hashes SIN/account number, replaces name/email/phone) PROD data into TEST. |
| `03_dev_clone_procedure.sql` | Stored procedures developers call ad hoc to clone a personal `DEV_*` database from `TEST` (zero-copy `CLONE`), and to drop it when done. |
| `04_roles_and_grants.sql` | Minimal `PROD_READONLY` and `DEVELOPER` roles so developers can self-serve DEV sandboxes without direct write access to PROD/TEST. |
| `05_sample_portable_developer_script.sql` | A transformation script that only ever references two-part `schema.table` names, showing how the *same* SQL runs unmodified in DEV, TEST, or PROD. |

## Design choices worth noting

- **Layer naming simplified for this PoC.** The medallion architecture `LND`, `DAL`, `GLD` has been implemented as separate tables within a CORE schema, but in an actual implementation these layers can be implemented as *schemas* per database. 
- **No hard-coded table names across environments.** PROD, TEST, and
  every `DEV_*` clone share the identical schema and table names.
  Portability comes entirely from switching database context — the SQL logic
  of a script itself (e.g., script 05) never changes between environments.
- **Sanitization is intentionally simple for a PoC.** Names/emails/phones
  are replaced with deterministic placeholders derived from
  `CUSTOMER_ID`; SIN and account number are one-way hashed (`SHA2`). A
  production version would likely use a proper data-masking/faker
  approach and column-level masking policies.

## Suggested run order

```sql
-- as SYSADMIN (or equivalent)
01_prod_setup.sql
02_test_extraction_sanitization.sql
03_dev_clone_procedure.sql

-- as SECURITYADMIN (or equivalent)
04_roles_and_grants.sql

-- as a developer, in their own session
05_sample_portable_developer_script.sql
```
