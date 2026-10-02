-- 01_staging.sql
-- Land the UCI Bank Marketing file (bank-additional-full.csv, ';'-delimited) as an all-STRING staging table.
-- Source headers contain dots (emp.var.rate) and a reserved word (default): renamed to snake_case here.
-- {{RAW_DIR}} is substituted by run_pipeline.py (data/raw = repo sample, data/raw_full = complete file).
-- Databricks equivalent (databricks/marketing_campaign_pipeline_notebook.sql) uses backticks:
--   SELECT age, ..., `default` AS credit_default, ..., `emp.var.rate` AS emp_var_rate, ... FROM read_files(
--     '/Volumes/workspace/da_learn_05/raw/bank-additional-full.csv', format => 'csv', header => true, sep => ';', inferColumnTypes => false)
CREATE OR REPLACE TABLE stg_contacts AS
SELECT age, job, marital, education, "default" AS credit_default, housing, loan AS personal_loan,
       contact AS contact_channel, "month" AS contact_month, day_of_week, duration, campaign, pdays, previous, poutcome,
       "emp.var.rate" AS emp_var_rate, "cons.price.idx" AS cons_price_idx, "cons.conf.idx" AS cons_conf_idx,
       euribor3m, "nr.employed" AS nr_employed, y
FROM read_csv('{{RAW_DIR}}/bank-additional-full.csv', delim = ';', header = true, all_varchar = true);
