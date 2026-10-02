# Databricks run (done for real on 2026-10-02 IST)

| Item | Value |
|---|---|
| Warehouse | Serverless Starter Warehouse (shared; not stopped - auto-stop handles it) |
| Catalog.schema | `workspace.da_learn_05` |
| Raw data | full `bank-additional-full.csv` (5.8 MB) uploaded to the UC volume `/Volumes/workspace/da_learn_05/raw/` via the Files API |
| Notebook | `/Workspace/Shared/da-learn-05-marketing-campaign-analysis/marketing_campaign_pipeline_notebook` (export: `marketing_campaign_pipeline_notebook.sql`) |
| Dashboard | **da-learn-05 Marketing campaign analysis** - published 2026-10-02 22:39 IST, 2 pages, 8 data widgets (export: `marketing_campaign_dashboard.lvdash.json`) |
| Run log | `run_outputs/databricks_run.json` (40 statements, all OK) |
| Parity | `run_outputs/duckdb_vs_databricks.json`: all 8 core tables have identical row counts (stg 41,188; cln/fact 41,176; dim_client 4,270, dim_period 50, dim_channel 2, dim_prev_campaign 3, dim_economy 375) and a_kpi_headline, a_conv_by_segment/calls/prev_outcome/month/economy, dq_assertions, dq_issues match cell by cell |

## Reproduce
1. `CREATE SCHEMA IF NOT EXISTS workspace.da_learn_05; CREATE VOLUME IF NOT EXISTS workspace.da_learn_05.raw;`
2. Upload `data/raw_full/bank-additional-full.csv` to `/Volumes/workspace/da_learn_05/raw/` (Catalog Explorer > volume > Upload, or `databricks fs cp`).
3. Workspace > Import > `databricks/marketing_campaign_pipeline_notebook.sql`, attach a SQL warehouse, *Run all*.
   Staging uses `read_files(..., format => 'csv', header => true, sep => ';', inferColumnTypes => false)` and renames the
   dotted / reserved headers with backticks (`` `emp.var.rate` AS emp_var_rate ``, `` `default` AS credit_default ``).
4. Dashboards > Import > `marketing_campaign_dashboard.lvdash.json` (datasets point to `workspace.da_learn_05.*`), then Publish.

## Dialect notes
- The source has no id. `contact_id` = `ROW_NUMBER() OVER (ORDER BY <all 21 typed fields>)` after `SELECT DISTINCT`, so
  both engines assign identical keys regardless of file read order.
- Month / weekday abbreviations are parsed with `instr('janfeb...', ...)` lookups (no locale-dependent date parsing).
- `median()` is exact in Spark and DuckDB. Avoid `''` inside label literals: Spark concatenates adjacent literals.
