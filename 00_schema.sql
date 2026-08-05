-- ============================================================
-- 00_schema.sql
-- Creates the raw staging table that mirrors a typical CRM
-- contact export (e.g., Salesforce / HubSpot). Intentionally
-- contains the kinds of issues found in real CRM exports:
-- exact duplicates, near-duplicates (formatting differences),
-- missing fields, and invalid values.
--
-- Tested against SQLite for portability; syntax is close to
-- ANSI SQL and translates directly to Snowflake / Postgres /
-- SQL Server with minor type adjustments.
-- ============================================================

DROP TABLE IF EXISTS crm_contacts_raw;

CREATE TABLE crm_contacts_raw (
    contact_id      INTEGER PRIMARY KEY,
    first_name      TEXT,
    last_name       TEXT,
    email           TEXT,
    phone           TEXT,
    company         TEXT,
    lead_source     TEXT,
    created_date    TEXT,
    state           TEXT
);

-- Load via: .mode csv / .import sample_data/crm_contacts_raw.csv crm_contacts_raw
-- (see README.md for the one-line load command)
