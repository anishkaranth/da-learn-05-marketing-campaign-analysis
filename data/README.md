# Data

| Folder | In git? | Content |
|---|---|---|
| `data/raw/bank-additional-full.csv` | yes | reproducible sample: 68 contacts x 21 columns (11 conversions) |
| `data/raw_full/bank-additional-full.csv` | no (.gitignore) | complete file, 41,188 rows x 21 columns, 5,834,924 bytes - `python scripts/download_full_data.py` |
| `data/clean_full/star/` | no | star-schema CSVs from the full run (`run_pipeline.py --source full`) |

**Sample rule** (`scripts/make_sample.py`): keep every 600th record in file order (rows 600, 1200, ..., 40800).
The file is chronological, so the sample covers May 2008 to Nov 2010. All 21 columns are copied verbatim (same `;`
delimiter, quoted strings such as `"admin."`, `"basic.4y"`, `pdays = 999` sentinel); only CRLF line endings are
normalised to LF. Same file name as the full file, so `sql/01_staging.sql` reads either folder unchanged.

The sample is for smoke-testing and the Power BI kit only; every reported number uses the full file. With 68 rows the
assertion "one call converts better than 6+ calls" FAILS on the sample (it passes on the full data).

Source: UCI Machine Learning Repository dataset 222 (CC BY 4.0), also on Kaggle as `henriqueyamahata/bank-marketing` -
see the *Complete dataset* section of the main README for URLs, checksum and licence.
