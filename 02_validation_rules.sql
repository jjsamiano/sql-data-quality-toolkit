-- ============================================================
-- 02_validation_rules.sql
-- Field-level data quality rules, expressed as a single view.
-- Each row gets a pass/fail flag per rule plus an overall
-- quality score, so dirty records can be triaged and reported
-- on without deleting anything.
-- ============================================================

DROP VIEW IF EXISTS v_contact_quality_flags;

CREATE VIEW v_contact_quality_flags AS
SELECT
    contact_id,
    first_name,
    last_name,
    email,
    phone,
    company,
    state,

    -- Rule 1: required identity fields present
    CASE WHEN first_name IS NULL OR TRIM(first_name) = '' THEN 0 ELSE 1 END AS rule_first_name_present,
    CASE WHEN last_name  IS NULL OR TRIM(last_name)  = '' THEN 0 ELSE 1 END AS rule_last_name_present,

    -- Rule 2: valid email format
    CASE
        WHEN email IS NULL OR TRIM(email) = '' THEN 0
        WHEN email NOT LIKE '%_@_%.__%' THEN 0
        ELSE 1
    END AS rule_email_valid,

    -- Rule 3: phone is numeric-ish (digits, spaces, dashes, +, parens only)
    CASE
        WHEN phone IS NULL OR TRIM(phone) = '' THEN 0
        WHEN phone GLOB '*[A-Za-z]*' THEN 0
        ELSE 1
    END AS rule_phone_valid,

    -- Rule 4: state is a recognized 2-letter US code (sample list)
    CASE
        WHEN state IN ('CA','NY','IL','TX','WA','FL','MA','CO') THEN 1
        ELSE 0
    END AS rule_state_valid

FROM crm_contacts_raw;

-- Roll the flags up into a single quality score (0.0 - 1.0) per record
SELECT
    contact_id,
    (rule_first_name_present + rule_last_name_present + rule_email_valid
     + rule_phone_valid + rule_state_valid) / 5.0 AS quality_score
FROM v_contact_quality_flags
ORDER BY quality_score ASC;

-- Aggregate pass rate per rule -- this is the number that goes on the
-- data quality KPI dashboard
SELECT
    ROUND(AVG(rule_first_name_present) * 100, 1) AS pct_first_name_present,
    ROUND(AVG(rule_last_name_present)  * 100, 1) AS pct_last_name_present,
    ROUND(AVG(rule_email_valid)        * 100, 1) AS pct_email_valid,
    ROUND(AVG(rule_phone_valid)        * 100, 1) AS pct_phone_valid,
    ROUND(AVG(rule_state_valid)        * 100, 1) AS pct_state_valid
FROM v_contact_quality_flags;
