# Power BI dashboard spec (mirrors the Lakeview dashboard)

Page 1 - Overview
- Cards: Contacts, Conversions, Conversion Rate, Calls, Calls per Conversion, Previously Contacted %
- Column: fact_contact[calls_band] x [Conversion Rate], line on secondary axis [Calls per Conversion]
- Bar: dim_prev_campaign[prev_label] x [Conversion Rate]
- Column: dim_period[month_name] (sorted by month_num) x [Conversion Rate], tooltip [Contacts]

Page 2 - Segments
- Column: dim_client[age_band] x [Conversion Rate] (tooltip Lift)
- Bar: dim_client[job] x [Conversion Rate], sorted descending, tooltip [Calls per Conversion]
- Clustered column: dim_client[age_band] x [Conversion Rate], legend dim_channel[channel_label]
- Matrix: rows dim_client[job], columns dim_client[age_band], values [Conversion Rate] with a colour scale
- Slicers: dim_channel[channel_label], dim_prev_campaign[prev_label], dim_economy[euribor_band]

Expected full-data values for checking: Contacts 41,176, Conversion Rate 11.27%, Calls per Conversion 22.79,
1 call 13.04% vs 11+ calls 3.11%, previous success 65.11%, mobile 14.74% vs landline 5.23%.
