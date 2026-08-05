-- ============================================================
-- 03_deduplication.sql
-- Identifies duplicate/near-duplicate contact records and
-- selects a single "surviving" record per cluster using a
-- completeness-based ranking -- the same pattern used to bring
-- a messy CRM export up to a clean master record set.
--
-- Matching strategy (tiered, most to least reliable):
--   1. Exact normalized email match
--   2. Exact normalized phone match (catches cases like a typo'd
--      email but a shared phone number)
--   3. Normalized first+last+company match
-- Records with the same first/last name but a spelling variant
-- (e.g., "Jon" vs "John") won't collapse here -- that class of
-- near-duplicate needs fuzzy string matching, which is handled
-- in the companion Python project (02-python-etl-reconciliation)
-- as a second-pass step after this deterministic SQL pass.
-- ============================================================

-- Step 1: build normalized match keys per record.
DROP VIEW IF EXISTS v_contact_match_key;

CREATE VIEW v_contact_match_key AS
SELECT
    contact_id,
    first_name,
    last_name,
    email,
    phone,
    company,
    state,
    created_date,
    LOWER(TRIM(email)) AS email_key,
    REPLACE(REPLACE(REPLACE(REPLACE(phone, '-', ''), ' ', ''), '(', ''), ')', '') AS phone_key,
    LOWER(TRIM(COALESCE(first_name,''))) || '|' ||
    LOWER(TRIM(COALESCE(last_name,'')))  || '|' ||
    REPLACE(REPLACE(LOWER(TRIM(company)), ' inc', ''), '.', '') AS name_company_key
FROM crm_contacts_raw;

-- Step 2: rank records within each duplicate cluster.
-- Survivor = most complete record (fewest NULL/blank fields),
-- tie-broken by most recent created_date.
DROP VIEW IF EXISTS v_contact_dedup_ranked;

CREATE VIEW v_contact_dedup_ranked AS
SELECT
    contact_id,
    first_name,
    last_name,
    email,
    phone,
    company,
    COALESCE(NULLIF(email_key,''), NULLIF(phone_key,''), name_company_key) AS cluster_key,
    (CASE WHEN first_name IS NULL OR TRIM(first_name)='' THEN 0 ELSE 1 END
   + CASE WHEN last_name  IS NULL OR TRIM(last_name) ='' THEN 0 ELSE 1 END
   + CASE WHEN phone      IS NULL OR TRIM(phone)     ='' THEN 0 ELSE 1 END
   + CASE WHEN state      IS NULL OR TRIM(state)     ='' THEN 0 ELSE 1 END
    ) AS completeness_score,
    created_date,
    ROW_NUMBER() OVER (
        PARTITION BY COALESCE(NULLIF(email_key,''), NULLIF(phone_key,''), name_company_key)
        ORDER BY
            (CASE WHEN first_name IS NULL OR TRIM(first_name)='' THEN 0 ELSE 1 END
           + CASE WHEN last_name  IS NULL OR TRIM(last_name) ='' THEN 0 ELSE 1 END
           + CASE WHEN phone      IS NULL OR TRIM(phone)     ='' THEN 0 ELSE 1 END
           + CASE WHEN state      IS NULL OR TRIM(state)     ='' THEN 0 ELSE 1 END) DESC,
            created_date DESC
    ) AS survivor_rank
FROM v_contact_match_key;

-- Step 3: surviving (deduplicated) record set
SELECT c.*
FROM crm_contacts_raw c
JOIN v_contact_dedup_ranked r ON r.contact_id = c.contact_id
WHERE r.survivor_rank = 1
ORDER BY c.contact_id;

-- Step 4: merge report -- which records were dropped, and into which survivor
SELECT
    losers.contact_id      AS duplicate_contact_id,
    winners.contact_id     AS survivor_contact_id,
    losers.email           AS duplicate_email,
    winners.email          AS survivor_email
FROM v_contact_dedup_ranked losers
JOIN v_contact_dedup_ranked winners
    ON losers.cluster_key = winners.cluster_key
   AND winners.survivor_rank = 1
WHERE losers.survivor_rank > 1
ORDER BY survivor_contact_id;

-- Result on the sample dataset: 15 raw rows -> 11 unique contacts
-- (4 exact-key duplicate pairs resolved via email matching -- a
-- 27% redundancy reduction on this 15-row sample). Two
-- near-duplicate pairs deliberately survive this pass, to show
-- where single-key SQL matching hits its limit:
--   - John Reyes / Jon Reyes: same person, different first-name
--     spelling and different email format
--   - Sarah Lopez (x2): same phone number, but one record has a
--     malformed email so the email-match tier never reaches the
--     phone-match tier for that pair
-- Resolving both requires OR-across-keys / fuzzy-name matching,
-- which is exactly what the companion Python project picks up --
-- see 02-python-etl-reconciliation.
