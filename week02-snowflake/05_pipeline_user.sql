-- =====================================================
-- 05_pipeline_user.sql
-- Least-privilege service user for the automated pipeline
-- (GitHub Actions: load to RAW + dbt build to DBT_PROD)
-- =====================================================

use role ACCOUNTADMIN;

-- 1. Role
create role if not exists PIPELINE_ROLE;

-- 2. Compute + database access
grant usage on warehouse WEATHER_WH to role PIPELINE_ROLE;
grant usage on database WEATHER_DB to role PIPELINE_ROLE;
grant usage on schema WEATHER_DB.RAW to role PIPELINE_ROLE;

-- 3. Loader permissions (PUT + COPY INTO)
grant read, write on stage WEATHER_DB.RAW.WEATHER_STAGE to role PIPELINE_ROLE;
grant usage on file format WEATHER_DB.RAW.JSON_FORMAT to role PIPELINE_ROLE;
grant select, insert on table WEATHER_DB.RAW.WEATHER_RAW to role PIPELINE_ROLE;

-- 4. Prod schema for dbt (role owns it, so dbt can create/replace tables)
create schema if not exists WEATHER_DB.DBT_PROD;
grant ownership on schema WEATHER_DB.DBT_PROD to role PIPELINE_ROLE;
-- 4b. CI schema for pull request checks (sandbox, never prod)
create schema if not exists WEATHER_DB.DBT_CI;
grant ownership on schema WEATHER_DB.DBT_CI to role PIPELINE_ROLE;

-- 5. Service user (key-pair only, no password)
create user if not exists PIPELINE_USER
    type = SERVICE
    default_role = PIPELINE_ROLE
    default_warehouse = WEATHER_WH
    rsa_public_key = '<paste public key here>';

grant role PIPELINE_ROLE to user PIPELINE_USER;

-- 6. Roll up custom role to SYSADMIN (Snowflake best practice)
-- Without this, DBT_PROD tables owned by PIPELINE_ROLE are invisible to ACCOUNTADMIN
grant role PIPELINE_ROLE to role SYSADMIN;

-- Key rotation (when a key is exposed or expires):
-- alter user PIPELINE_USER set rsa_public_key = '<new public key>';