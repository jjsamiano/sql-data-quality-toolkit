# SQL Data Quality & Deduplication Toolkit

A self-contained SQL workflow for profiling, validating, and deduplicating a
messy CRM export — the same category of work I've done on production CRM
datasets (Salesforce, HubSpot) ranging from 400 to 100,000+ records.

**Note on data:** the CSV in `sample_data/` is entirely synthetic, built to
reproduce the categories of issues found in real CRM exports (exact
duplicates, near-duplicates, missing fields, malformed emails/phones). No
employer or client data is used anywhere in this repo.

## What's here

| File | Purpose |
|---|---|
| `00_schema.sql` | Staging table DDL |
| `01_data_profiling.sql` | Completeness checks, duplicate counts, format anomalies |
| `02_validation_rules.sql` | Field-level pass/fail rules rolled into a per-record quality score and an aggregate pass-rate view (the numbers that would feed a KPI dashboard) |
| `03_deduplication.sql` | Tiered match-key deduplication (email → phone → name+company) with a merge/survivor report |
| `sample_data/crm_contacts_raw.csv` | 15-row synthetic CRM export used to run all of the above |

## Run it yourself

Everything here is written against SQLite for zero-setup portability, using
syntax that carries over directly to Snowflake, Postgres, or SQL Server.

```bash
sqlite3 demo.db
sqlite> .read 00_schema.sql
sqlite> .mode csv
sqlite> .import sample_data/crm_contacts_raw.csv crm_contacts_raw
sqlite> .read 01_data_profiling.sql
sqlite> .read 02_validation_rules.sql
sqlite> .read 03_deduplication.sql
```

## What it demonstrates, and where it hands off

Running `03_deduplication.sql` against the sample data collapses 15 raw rows
to **11 unique contacts** — a 27% reduction from single-key (email/phone)
matching alone. Two near-duplicate pairs are *deliberately* left unresolved
by this script:

- **John Reyes / Jon Reyes** — same person, different first-name spelling
- **Sarah Lopez (×2)** — same phone number, but a malformed email on one
  record breaks simple email-first matching

Both require matching across multiple keys at once, or fuzzy name
comparison — which plain single-key SQL isn't built for. That's the exact
handoff point to **[02-python-etl-reconciliation](../../sql-data-quality-toolkit)**,
where a Python pass resolves both remaining pairs. In production this is
usually how the two layers split: SQL for deterministic, high-confidence
matching at scale; Python for the fuzzy tier on what's left.
