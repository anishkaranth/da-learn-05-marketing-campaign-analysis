# Power BI model

Star schema exported by `run_pipeline.py --source sample` into `powerbi/data/` (68-contact sample; for the full model
run `--source full` and use `data/clean_full/star/`).

| Table | Grain | Key | Notes |
|---|---|---|---|
| fact_contact | one row per client contact | contact_id | age, campaign_calls, calls_band, duration_sec, call_length_band, previous_contacts, converted (0/1), is_heavy_contact |
| dim_client | junk profile | client_key | age_band, job, marital, education, credit_default, housing_loan, personal_loan |
| dim_period | month x weekday | period_key (month*10 + weekday) | month_num, month_name, quarter, dow_num, day_name (no year in source) |
| dim_channel | contact channel | channel_key | contact_channel, channel_label (Mobile / Landline) |
| dim_prev_campaign | previous outcome | prev_key | prev_outcome, prev_label |
| dim_economy | macro snapshot | economy_key | emp_var_rate, cons_price_idx, cons_conf_idx, euribor3m, nr_employed, euribor_band |

Relationships (many-to-one, single direction, dimension -> fact): `fact_contact[client_key] -> dim_client[client_key]`,
`fact_contact[period_key] -> dim_period[period_key]`, `fact_contact[channel_key] -> dim_channel[channel_key]`,
`fact_contact[prev_key] -> dim_prev_campaign[prev_key]`, `fact_contact[economy_key] -> dim_economy[economy_key]`.

Sort `dim_period[month_name]` by `month_num` and `day_name` by `dow_num`. Bands (`age_band`, `calls_band`,
`call_length_band`, `euribor_band`) carry a numeric prefix (`1: 17-24`) so they sort correctly as text.
