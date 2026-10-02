# Build the Power BI report (Power BI Desktop, Windows)

1. *Get data > Text/CSV* and load the six files in `powerbi/data/` (or `data/clean_full/star/` after a full run).
   Check types: keys, counts and flags = Whole number, macro indicators = Decimal, bands and labels = Text.
2. *Model view*: create the five relationships listed in `model.md` (single direction, many-to-one).
3. Set *Sort by column*: `dim_period[month_name]` by `month_num`, `dim_period[day_name]` by `dow_num`.
4. Create a `_Measures` table and paste the measures from `measures.dax`; format Conversion Rate, Share of Calls, Share of Conversions
   and Previously Contacted % as percentages, Calls per Conversion with 1 decimal.
5. Build the two pages in `dashboard_spec.md`.
6. Validate with the full star: Conversion Rate must show 11.27% and Contacts 41,176 (the 68-row sample shows 16.18%).
