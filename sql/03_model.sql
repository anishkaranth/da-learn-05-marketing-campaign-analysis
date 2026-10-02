-- 03_model.sql  Star schema: fact_contact + dim_client (junk profile), dim_period (month x weekday),
-- dim_channel, dim_prev_campaign, dim_economy (macro indicators at contact time)

CREATE OR REPLACE TABLE dim_client AS
SELECT ROW_NUMBER() OVER (ORDER BY age_band, job, marital, education, credit_default, housing_loan, personal_loan) AS client_key,
       age_band, job, marital, education, credit_default, housing_loan, personal_loan
FROM (SELECT DISTINCT age_band, job, marital, education, credit_default, housing_loan, personal_loan FROM cln_contacts) c;

CREATE OR REPLACE TABLE dim_period AS
SELECT month_num * 10 + dow_num AS period_key, month_num, month_name,
       CASE WHEN month_num <= 3 THEN 1 WHEN month_num <= 6 THEN 2 WHEN month_num <= 9 THEN 3 ELSE 4 END AS quarter,
       dow_num, day_name
FROM (SELECT DISTINCT month_num, month_name, dow_num, day_name FROM cln_contacts) p;

CREATE OR REPLACE TABLE dim_channel AS
SELECT ROW_NUMBER() OVER (ORDER BY contact_channel) AS channel_key, contact_channel,
       CASE WHEN contact_channel = 'cellular' THEN 'Mobile' ELSE 'Landline' END AS channel_label
FROM (SELECT DISTINCT contact_channel FROM cln_contacts) ch;

CREATE OR REPLACE TABLE dim_prev_campaign AS
SELECT ROW_NUMBER() OVER (ORDER BY prev_outcome) AS prev_key, prev_outcome,
       CASE WHEN prev_outcome = 'nonexistent' THEN 'Not in previous campaign'
            WHEN prev_outcome = 'failure' THEN 'Previous campaign: no'
            ELSE 'Previous campaign: yes' END AS prev_label
FROM (SELECT DISTINCT prev_outcome FROM cln_contacts) pc;

CREATE OR REPLACE TABLE dim_economy AS
SELECT ROW_NUMBER() OVER (ORDER BY euribor3m, emp_var_rate, cons_price_idx, cons_conf_idx, nr_employed) AS economy_key,
       emp_var_rate, cons_price_idx, cons_conf_idx, euribor3m, nr_employed, euribor_band
FROM (SELECT DISTINCT emp_var_rate, cons_price_idx, cons_conf_idx, euribor3m, nr_employed, euribor_band FROM cln_contacts) e;

CREATE OR REPLACE TABLE fact_contact AS
SELECT
  c.contact_id, cl.client_key, c.month_num * 10 + c.dow_num AS period_key, ch.channel_key, pc.prev_key, e.economy_key,
  c.age, c.duration_sec, c.call_length_band, c.campaign_calls, c.calls_band, c.days_since_prev_campaign,
  c.previous_contacts, c.was_previously_contacted, c.converted, c.is_heavy_contact
FROM cln_contacts c
LEFT JOIN dim_client cl ON c.age_band = cl.age_band AND c.job = cl.job AND c.marital = cl.marital
                       AND c.education = cl.education AND c.credit_default = cl.credit_default
                       AND c.housing_loan = cl.housing_loan AND c.personal_loan = cl.personal_loan
LEFT JOIN dim_channel ch ON c.contact_channel = ch.contact_channel
LEFT JOIN dim_prev_campaign pc ON c.prev_outcome = pc.prev_outcome
LEFT JOIN dim_economy e ON c.euribor3m = e.euribor3m AND c.emp_var_rate = e.emp_var_rate
                       AND c.cons_price_idx = e.cons_price_idx AND c.cons_conf_idx = e.cons_conf_idx
                       AND c.nr_employed = e.nr_employed;
