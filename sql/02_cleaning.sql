-- 02_cleaning.sql  Typed, standardised, de-duplicated campaign contacts (Spark SQL dialect; DuckDB via 00 shims)
-- One row = one client contacted in the 2008-2010 Portuguese bank term-deposit campaign (last contact of the campaign).

CREATE OR REPLACE TABLE cln_contacts_typed AS
SELECT
  TRY_CAST(trim(age) AS INT)                                          AS age,
  CASE WHEN lower(trim(job)) = 'admin.' THEN 'admin' ELSE lower(trim(job)) END AS job,
  lower(trim(marital))                                                AS marital,
  CASE lower(trim(education))
       WHEN 'basic.4y' THEN 'basic 4y' WHEN 'basic.6y' THEN 'basic 6y' WHEN 'basic.9y' THEN 'basic 9y'
       WHEN 'high.school' THEN 'high school' WHEN 'professional.course' THEN 'professional course'
       WHEN 'university.degree' THEN 'university degree' ELSE lower(trim(education)) END AS education,
  lower(trim(credit_default))                                         AS credit_default,
  lower(trim(housing))                                                AS housing_loan,
  lower(trim(personal_loan))                                          AS personal_loan,
  lower(trim(contact_channel))                                        AS contact_channel,
  CAST((instr('janfebmaraprmayjunjulaugsepoctnovdec', lower(trim(contact_month))) + 2) / 3 AS INT) AS month_num,
  lower(trim(contact_month))                                          AS month_abbr,
  CAST((instr('montuewedthufri', lower(trim(day_of_week))) + 2) / 3 AS INT) AS dow_num,
  lower(trim(day_of_week))                                            AS dow_abbr,
  TRY_CAST(trim(duration) AS INT)                                     AS duration_sec,
  TRY_CAST(trim(campaign) AS INT)                                     AS campaign_calls,
  TRY_CAST(trim(pdays) AS INT)                                        AS pdays_raw,
  TRY_CAST(trim(previous) AS INT)                                     AS previous_contacts,
  lower(trim(poutcome))                                               AS prev_outcome,
  TRY_CAST(trim(emp_var_rate) AS DOUBLE)                              AS emp_var_rate,
  TRY_CAST(trim(cons_price_idx) AS DOUBLE)                            AS cons_price_idx,
  TRY_CAST(trim(cons_conf_idx) AS DOUBLE)                             AS cons_conf_idx,
  TRY_CAST(trim(euribor3m) AS DOUBLE)                                 AS euribor3m,
  TRY_CAST(trim(nr_employed) AS DOUBLE)                               AS nr_employed,
  CASE WHEN lower(trim(y)) = 'yes' THEN 1 ELSE 0 END                  AS converted
FROM stg_contacts;

-- The file has no client id: exact duplicate records (all 21 fields equal) are collapsed, then a deterministic
-- contact_id is assigned by ordering on every field so DuckDB and Databricks produce the same keys.

CREATE OR REPLACE TABLE cln_contacts_dedup AS
SELECT DISTINCT * FROM cln_contacts_typed
WHERE age IS NOT NULL AND campaign_calls IS NOT NULL AND month_num BETWEEN 1 AND 12 AND dow_num BETWEEN 1 AND 5;

CREATE OR REPLACE TABLE cln_contacts AS
SELECT
  ROW_NUMBER() OVER (ORDER BY month_num, dow_num, age, job, marital, education, credit_default, housing_loan, personal_loan,
                              contact_channel, duration_sec, campaign_calls, pdays_raw, previous_contacts, prev_outcome,
                              emp_var_rate, cons_price_idx, cons_conf_idx, euribor3m, nr_employed, converted) AS contact_id,
  age,
  CASE WHEN age < 25 THEN '1: 17-24' WHEN age < 35 THEN '2: 25-34' WHEN age < 45 THEN '3: 35-44'
       WHEN age < 55 THEN '4: 45-54' WHEN age < 65 THEN '5: 55-64' ELSE '6: 65+' END AS age_band,
  job, marital, education, credit_default, housing_loan, personal_loan, contact_channel,
  month_num, concat(upper(substr(month_abbr, 1, 1)), substr(month_abbr, 2)) AS month_name,
  dow_num, concat(upper(substr(dow_abbr, 1, 1)), substr(dow_abbr, 2)) AS day_name,
  duration_sec,
  CASE WHEN duration_sec < 120 THEN '1: <2 min' WHEN duration_sec < 300 THEN '2: 2-5 min'
       WHEN duration_sec < 600 THEN '3: 5-10 min' ELSE '4: 10+ min' END AS call_length_band,
  campaign_calls,
  CASE WHEN campaign_calls = 1 THEN '1: 1 call' WHEN campaign_calls = 2 THEN '2: 2 calls'
       WHEN campaign_calls = 3 THEN '3: 3 calls' WHEN campaign_calls <= 5 THEN '4: 4-5 calls'
       WHEN campaign_calls <= 10 THEN '5: 6-10 calls' ELSE '6: 11+ calls' END AS calls_band,
  CASE WHEN pdays_raw = 999 THEN NULL ELSE pdays_raw END AS days_since_prev_campaign,
  previous_contacts,
  CASE WHEN previous_contacts > 0 THEN 1 ELSE 0 END AS was_previously_contacted,
  prev_outcome,
  emp_var_rate, cons_price_idx, cons_conf_idx, euribor3m, nr_employed,
  CASE WHEN euribor3m < 1 THEN '1: <1%' WHEN euribor3m < 1.5 THEN '2: 1-1.5%' WHEN euribor3m < 4 THEN '3: 1.5-4%'
       WHEN euribor3m < 4.9 THEN '4: 4-4.9%' ELSE '5: 4.9%+' END AS euribor_band,
  converted,
  CASE WHEN job = 'unknown' OR marital = 'unknown' OR education = 'unknown' THEN 1 ELSE 0 END AS dq_unknown_profile,
  CASE WHEN campaign_calls > 10 THEN 1 ELSE 0 END AS is_heavy_contact
FROM cln_contacts_dedup;
