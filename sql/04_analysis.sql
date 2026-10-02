-- 04_analysis.sql  Business KPIs (Spark SQL dialect)
-- Cost proxy: the dataset has no money columns, so effort is measured in calls (campaign_calls = calls made to the
-- client in this campaign) and talk time of the last call (duration_sec). calls_per_conversion = SUM(calls) / conversions.

CREATE OR REPLACE TABLE a_kpi_headline AS
SELECT
  COUNT(*)                                                                   AS contacts,
  SUM(converted)                                                             AS conversions,
  ROUND(100.0 * SUM(converted) / COUNT(*), 2)                                AS conversion_rate_pct,
  SUM(campaign_calls)                                                        AS total_calls,
  ROUND(AVG(campaign_calls), 2)                                              AS avg_calls_per_client,
  ROUND(SUM(campaign_calls) / SUM(converted), 2)                             AS calls_per_conversion,
  ROUND(SUM(duration_sec) / 3600.0, 1)                                       AS last_call_talk_hours,
  ROUND(median(duration_sec), 0)                                             AS median_last_call_sec,
  ROUND(100.0 * SUM(was_previously_contacted) / COUNT(*), 2)                 AS pct_previously_contacted,
  ROUND(100.0 * SUM(CASE WHEN contact_channel = 'cellular' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_mobile,
  ROUND(100.0 * SUM(CASE WHEN month_num = 5 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_contacts_in_may
FROM cln_contacts;

-- Q1: Which client segments convert best, and what does a conversion cost in calls? (one table, many attributes)

CREATE OR REPLACE TABLE a_conv_by_segment AS
WITH base AS (SELECT 100.0 * SUM(converted) / COUNT(*) AS overall_rate FROM cln_contacts),
seg AS (
  SELECT 'age_band' AS attribute, age_band AS value, COUNT(*) AS contacts, SUM(converted) AS conversions, SUM(campaign_calls) AS calls FROM cln_contacts GROUP BY age_band
  UNION ALL SELECT 'job', job, COUNT(*), SUM(converted), SUM(campaign_calls) FROM cln_contacts GROUP BY job
  UNION ALL SELECT 'education', education, COUNT(*), SUM(converted), SUM(campaign_calls) FROM cln_contacts GROUP BY education
  UNION ALL SELECT 'marital', marital, COUNT(*), SUM(converted), SUM(campaign_calls) FROM cln_contacts GROUP BY marital
  UNION ALL SELECT 'housing_loan', housing_loan, COUNT(*), SUM(converted), SUM(campaign_calls) FROM cln_contacts GROUP BY housing_loan
  UNION ALL SELECT 'personal_loan', personal_loan, COUNT(*), SUM(converted), SUM(campaign_calls) FROM cln_contacts GROUP BY personal_loan
  UNION ALL SELECT 'credit_default', credit_default, COUNT(*), SUM(converted), SUM(campaign_calls) FROM cln_contacts GROUP BY credit_default
)
SELECT s.attribute, s.value, s.contacts, s.conversions,
       ROUND(100.0 * s.conversions / s.contacts, 2)                        AS conversion_rate_pct,
       ROUND(100.0 * s.conversions / s.contacts / b.overall_rate, 2)       AS lift,
       ROUND(1.0 * s.calls / NULLIF(s.conversions, 0), 2)                  AS calls_per_conversion
FROM seg s CROSS JOIN base b;

CREATE OR REPLACE TABLE a_conv_by_job AS
SELECT value AS job, contacts, conversions, conversion_rate_pct, lift, calls_per_conversion
FROM a_conv_by_segment WHERE attribute = 'job';

CREATE OR REPLACE TABLE a_conv_by_age AS
SELECT value AS age_band, contacts, conversions, conversion_rate_pct, lift, calls_per_conversion
FROM a_conv_by_segment WHERE attribute = 'age_band';

-- Q2: Diminishing returns - how does conversion change with the number of calls made to the same client?

CREATE OR REPLACE TABLE a_conv_by_calls AS
SELECT calls_band, COUNT(*) AS contacts, SUM(converted) AS conversions,
       ROUND(100.0 * SUM(converted) / COUNT(*), 2)                         AS conversion_rate_pct,
       SUM(campaign_calls)                                                 AS calls,
       ROUND(1.0 * SUM(campaign_calls) / NULLIF(SUM(converted), 0), 2)     AS calls_per_conversion,
       ROUND(100.0 * SUM(campaign_calls) / (SELECT SUM(campaign_calls) FROM cln_contacts), 2) AS share_of_calls_pct,
       ROUND(100.0 * SUM(converted) / (SELECT SUM(converted) FROM cln_contacts), 2)          AS share_of_conversions_pct
FROM cln_contacts GROUP BY calls_band;

-- Q3: Does the previous campaign outcome predict this one?

CREATE OR REPLACE TABLE a_conv_by_prev_outcome AS
SELECT p.prev_label, COUNT(*) AS contacts, SUM(f.converted) AS conversions,
       ROUND(100.0 * SUM(f.converted) / COUNT(*), 2) AS conversion_rate_pct,
       ROUND(1.0 * SUM(f.campaign_calls) / NULLIF(SUM(f.converted), 0), 2) AS calls_per_conversion
FROM fact_contact f JOIN dim_prev_campaign p ON f.prev_key = p.prev_key
GROUP BY p.prev_label;

-- Q4: Timing and channel - month, weekday, mobile vs landline

CREATE OR REPLACE TABLE a_conv_by_month AS
SELECT d.month_num, d.month_name, COUNT(*) AS contacts, SUM(f.converted) AS conversions,
       ROUND(100.0 * SUM(f.converted) / COUNT(*), 2) AS conversion_rate_pct,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM fact_contact), 2) AS share_of_contacts_pct
FROM fact_contact f JOIN dim_period d ON f.period_key = d.period_key
GROUP BY d.month_num, d.month_name;

CREATE OR REPLACE TABLE a_conv_by_weekday AS
SELECT d.dow_num, d.day_name, COUNT(*) AS contacts,
       ROUND(100.0 * SUM(f.converted) / COUNT(*), 2) AS conversion_rate_pct
FROM fact_contact f JOIN dim_period d ON f.period_key = d.period_key
GROUP BY d.dow_num, d.day_name;

CREATE OR REPLACE TABLE a_conv_by_channel AS
SELECT ch.channel_label, COUNT(*) AS contacts, SUM(f.converted) AS conversions,
       ROUND(100.0 * SUM(f.converted) / COUNT(*), 2) AS conversion_rate_pct,
       ROUND(AVG(f.campaign_calls), 2) AS avg_calls,
       ROUND(1.0 * SUM(f.campaign_calls) / NULLIF(SUM(f.converted), 0), 2) AS calls_per_conversion
FROM fact_contact f JOIN dim_channel ch ON f.channel_key = ch.channel_key
GROUP BY ch.channel_label;

-- Q5: Economic context - conversion vs the 3-month Euribor rate at contact time

CREATE OR REPLACE TABLE a_conv_by_economy AS
SELECT e.euribor_band, COUNT(*) AS contacts, SUM(f.converted) AS conversions,
       ROUND(100.0 * SUM(f.converted) / COUNT(*), 2) AS conversion_rate_pct,
       ROUND(AVG(e.euribor3m), 3) AS avg_euribor3m,
       ROUND(AVG(e.nr_employed), 0) AS avg_nr_employed,
       ROUND(AVG(e.cons_conf_idx), 1) AS avg_consumer_confidence
FROM fact_contact f JOIN dim_economy e ON f.economy_key = e.economy_key
GROUP BY e.euribor_band;

-- Q6: Call length of the last contact (descriptive only: known after the call, not usable for targeting)

CREATE OR REPLACE TABLE a_conv_by_call_length AS
SELECT call_length_band, COUNT(*) AS contacts,
       ROUND(100.0 * SUM(converted) / COUNT(*), 2) AS conversion_rate_pct,
       ROUND(AVG(duration_sec), 0) AS avg_duration_sec
FROM fact_contact GROUP BY call_length_band;

-- Q7: Targeting matrix - age band x channel, and the best/worst segments to call first

CREATE OR REPLACE TABLE a_age_channel_matrix AS
SELECT cl.age_band, ch.channel_label, COUNT(*) AS contacts,
       ROUND(100.0 * SUM(f.converted) / COUNT(*), 2) AS conversion_rate_pct
FROM fact_contact f JOIN dim_client cl ON f.client_key = cl.client_key JOIN dim_channel ch ON f.channel_key = ch.channel_key
GROUP BY cl.age_band, ch.channel_label;

CREATE OR REPLACE TABLE a_target_segments AS
SELECT cl.job, cl.age_band, COUNT(*) AS contacts, SUM(f.converted) AS conversions,
       ROUND(100.0 * SUM(f.converted) / COUNT(*), 2) AS conversion_rate_pct,
       ROUND(1.0 * SUM(f.campaign_calls) / NULLIF(SUM(f.converted), 0), 2) AS calls_per_conversion
FROM fact_contact f JOIN dim_client cl ON f.client_key = cl.client_key
GROUP BY cl.job, cl.age_band
HAVING COUNT(*) >= 300;
