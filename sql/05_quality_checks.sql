-- 05_quality_checks.sql  Data-quality evidence (Spark SQL dialect): before/after counts, unknown rates, issues, assertions

CREATE OR REPLACE TABLE dq_row_counts AS
SELECT 'contacts' AS entity, (SELECT COUNT(*) FROM stg_contacts) AS raw_rows,
       (SELECT COUNT(*) FROM cln_contacts_dedup) AS distinct_records,
       (SELECT COUNT(*) FROM cln_contacts) AS clean_rows, 'client contact (last call of campaign)' AS grain
UNION ALL SELECT 'fact_contact', NULL, NULL, (SELECT COUNT(*) FROM fact_contact), 'contact'
UNION ALL SELECT 'dim_client', NULL, NULL, (SELECT COUNT(*) FROM dim_client), 'age band x job x marital x education x credit flags'
UNION ALL SELECT 'dim_period', NULL, NULL, (SELECT COUNT(*) FROM dim_period), 'month x weekday'
UNION ALL SELECT 'dim_channel', NULL, NULL, (SELECT COUNT(*) FROM dim_channel), 'contact channel'
UNION ALL SELECT 'dim_prev_campaign', NULL, NULL, (SELECT COUNT(*) FROM dim_prev_campaign), 'previous campaign outcome'
UNION ALL SELECT 'dim_economy', NULL, NULL, (SELECT COUNT(*) FROM dim_economy), 'macro indicator snapshot';

CREATE OR REPLACE TABLE dq_null_rates AS
SELECT 'contacts' AS entity, 'job' AS column_name,
  (SELECT ROUND(100.0 * SUM(CASE WHEN job IS NULL OR trim(job) IN ('', 'unknown') THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_contacts) AS raw_unknown_pct,
  (SELECT ROUND(100.0 * SUM(CASE WHEN job = 'unknown' THEN 1 ELSE 0 END) / COUNT(*), 3) FROM cln_contacts) AS clean_unknown_pct,
  'kept as category unknown' AS treatment
UNION ALL SELECT 'contacts', 'education',
  (SELECT ROUND(100.0 * SUM(CASE WHEN education IS NULL OR trim(education) IN ('', 'unknown') THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_contacts),
  (SELECT ROUND(100.0 * SUM(CASE WHEN education = 'unknown' THEN 1 ELSE 0 END) / COUNT(*), 3) FROM cln_contacts),
  'kept as category unknown'
UNION ALL SELECT 'contacts', 'credit_default',
  (SELECT ROUND(100.0 * SUM(CASE WHEN credit_default IS NULL OR trim(credit_default) IN ('', 'unknown') THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_contacts),
  (SELECT ROUND(100.0 * SUM(CASE WHEN credit_default = 'unknown' THEN 1 ELSE 0 END) / COUNT(*), 3) FROM cln_contacts),
  'kept as category unknown (bank did not disclose)'
UNION ALL SELECT 'contacts', 'housing_loan',
  (SELECT ROUND(100.0 * SUM(CASE WHEN housing IS NULL OR trim(housing) IN ('', 'unknown') THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_contacts),
  (SELECT ROUND(100.0 * SUM(CASE WHEN housing_loan = 'unknown' THEN 1 ELSE 0 END) / COUNT(*), 3) FROM cln_contacts),
  'kept as category unknown'
UNION ALL SELECT 'contacts', 'pdays (999 = not previously contacted)',
  (SELECT ROUND(100.0 * SUM(CASE WHEN trim(pdays) = '999' THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_contacts),
  (SELECT ROUND(100.0 * SUM(CASE WHEN days_since_prev_campaign IS NULL THEN 1 ELSE 0 END) / COUNT(*), 3) FROM cln_contacts),
  'sentinel 999 -> NULL';

CREATE OR REPLACE TABLE dq_issues AS
SELECT 'contacts: exact duplicate records removed' AS check_name,
       (SELECT COUNT(*) FROM stg_contacts) - (SELECT COUNT(*) FROM cln_contacts) AS affected_rows
UNION ALL SELECT 'contacts: unknown job / marital / education (kept)', (SELECT SUM(dq_unknown_profile) FROM cln_contacts)
UNION ALL SELECT 'contacts: credit_default = yes (too rare to analyse)', (SELECT COUNT(*) FROM cln_contacts WHERE credit_default = 'yes')
UNION ALL SELECT 'contacts: last call duration 0 sec', (SELECT COUNT(*) FROM cln_contacts WHERE duration_sec = 0)
UNION ALL SELECT 'contacts: more than 10 calls in campaign (kept, flagged)', (SELECT SUM(is_heavy_contact) FROM cln_contacts)
UNION ALL SELECT 'contacts: previously contacted but pdays = 999', (SELECT COUNT(*) FROM cln_contacts WHERE previous_contacts > 0 AND days_since_prev_campaign IS NULL)
UNION ALL SELECT 'RI: fact without client profile', (SELECT COUNT(*) FROM fact_contact WHERE client_key IS NULL)
UNION ALL SELECT 'RI: fact without channel', (SELECT COUNT(*) FROM fact_contact WHERE channel_key IS NULL)
UNION ALL SELECT 'RI: fact without previous-campaign outcome', (SELECT COUNT(*) FROM fact_contact WHERE prev_key IS NULL)
UNION ALL SELECT 'RI: fact without economy snapshot', (SELECT COUNT(*) FROM fact_contact WHERE economy_key IS NULL);

CREATE OR REPLACE TABLE dq_assertions AS
WITH c AS (
  SELECT 'fact_contact.contact_id unique' AS check_name, (SELECT COUNT(*) - COUNT(DISTINCT contact_id) FROM fact_contact) AS failed_rows
  UNION ALL SELECT 'fact_contact.client_key -> dim_client', (SELECT COUNT(*) FROM fact_contact WHERE client_key IS NULL OR client_key NOT IN (SELECT client_key FROM dim_client))
  UNION ALL SELECT 'fact_contact.period_key -> dim_period', (SELECT COUNT(*) FROM fact_contact WHERE period_key NOT IN (SELECT period_key FROM dim_period))
  UNION ALL SELECT 'fact_contact.channel_key -> dim_channel', (SELECT COUNT(*) FROM fact_contact WHERE channel_key IS NULL OR channel_key NOT IN (SELECT channel_key FROM dim_channel))
  UNION ALL SELECT 'fact_contact.prev_key -> dim_prev_campaign', (SELECT COUNT(*) FROM fact_contact WHERE prev_key IS NULL OR prev_key NOT IN (SELECT prev_key FROM dim_prev_campaign))
  UNION ALL SELECT 'fact_contact.economy_key -> dim_economy', (SELECT COUNT(*) FROM fact_contact WHERE economy_key IS NULL OR economy_key NOT IN (SELECT economy_key FROM dim_economy))
  UNION ALL SELECT 'every raw month and weekday parsed', (SELECT COUNT(*) FROM cln_contacts_typed WHERE month_num NOT BETWEEN 1 AND 12 OR dow_num NOT BETWEEN 1 AND 5)
  UNION ALL SELECT 'target y is yes or no', (SELECT COUNT(*) FROM stg_contacts WHERE lower(trim(y)) NOT IN ('yes', 'no'))
  UNION ALL SELECT 'age between 17 and 98', (SELECT COUNT(*) FROM fact_contact WHERE age < 17 OR age > 98)
  UNION ALL SELECT 'at least one call per contact', (SELECT COUNT(*) FROM fact_contact WHERE campaign_calls < 1)
  UNION ALL SELECT 'no previous contacts implies outcome nonexistent', (SELECT COUNT(*) FROM cln_contacts WHERE previous_contacts = 0 AND prev_outcome <> 'nonexistent')
  UNION ALL SELECT 'previous success implies previous contacts > 0', (SELECT COUNT(*) FROM cln_contacts WHERE prev_outcome = 'success' AND previous_contacts = 0)
  UNION ALL SELECT 'segment conversions add up to total', (SELECT COUNT(*) FROM (SELECT attribute, SUM(conversions) AS s FROM a_conv_by_segment GROUP BY attribute) x
                                                           WHERE s <> (SELECT conversions FROM a_kpi_headline))
  UNION ALL SELECT 'one call converts better than 6+ calls', (SELECT COUNT(*) FROM a_conv_by_calls a JOIN a_conv_by_calls b
                                                              ON a.calls_band = '1: 1 call' AND b.calls_band IN ('5: 6-10 calls', '6: 11+ calls')
                                                              WHERE b.conversion_rate_pct >= a.conversion_rate_pct)
)
SELECT check_name, failed_rows, CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END AS status FROM c;
