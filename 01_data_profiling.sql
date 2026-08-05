-- ============================================================
-- 01_data_profiling.sql
-- First step of any data quality engagement: understand the
-- shape and health of the data before writing a single rule.
-- ============================================================

-- 1. Row count and basic completeness check per field
SELECT
    COUNT(*)                                              AS total_rows,
    COUNT(*) - COUNT(first_name)                          AS missing_first_name,
    COUNT(*) - COUNT(last_name)                           AS missing_last_name,
    COUNT(*) - COUNT(NULLIF(TRIM(email), ''))              AS missing_email,
    COUNT(*) - COUNT(NULLIF(TRIM(phone), ''))              AS missing_phone,
    COUNT(*) - COUNT(NULLIF(TRIM(state), ''))              AS missing_state
FROM crm_contacts_raw;

-- 2. Exact duplicate rows (same email, different contact_id)
SELECT email, COUNT(*) AS occurrences
FROM crm_contacts_raw
WHERE email IS NOT NULL AND TRIM(email) <> ''
GROUP BY LOWER(TRIM(email))
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

-- 3. Malformed emails (no '@' or no domain after '@')
SELECT contact_id, email
FROM crm_contacts_raw
WHERE email IS NOT NULL
  AND TRIM(email) <> ''
  AND (email NOT LIKE '%@%' OR email LIKE '%@' OR email LIKE '%@.%');

-- 4. Phone numbers that don't match a basic numeric pattern
--    (flags placeholders like 'not-a-phone' and blanks)
SELECT contact_id, phone
FROM crm_contacts_raw
WHERE phone IS NOT NULL
  AND TRIM(phone) <> ''
  AND phone GLOB '*[A-Za-z]*';

-- 5. Company name variants that likely refer to the same account
--    (simple normalization: strip punctuation/suffixes, compare)
SELECT
    REPLACE(REPLACE(REPLACE(LOWER(company), ' inc', ''), ',', ''), '.', '') AS normalized_company,
    GROUP_CONCAT(DISTINCT company) AS raw_variants,
    COUNT(*) AS contact_count
FROM crm_contacts_raw
GROUP BY normalized_company
HAVING COUNT(DISTINCT company) > 1;
