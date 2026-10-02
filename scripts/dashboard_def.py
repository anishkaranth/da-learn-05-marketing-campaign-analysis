"""Lakeview dashboard + notebook visualization definitions for da-learn-05 (used by build_databricks.py)."""
from lakeview import ds, text, counter, chart, PCT, NUM

VIZ = [
    ("Diminishing returns of repeat calls", "Bar: X = calls_band, Y = conversion_rate_pct (tooltip calls_per_conversion)",
     "SELECT calls_band, contacts, conversion_rate_pct, calls_per_conversion, share_of_conversions_pct FROM a_conv_by_calls ORDER BY calls_band"),
    ("Previous campaign outcome", "Horizontal bar: Y = prev_label, X = conversion_rate_pct",
     "SELECT prev_label, contacts, conversion_rate_pct, calls_per_conversion FROM a_conv_by_prev_outcome ORDER BY conversion_rate_pct DESC"),
    ("Conversion by age band", "Bar: X = age_band, Y = conversion_rate_pct",
     "SELECT age_band, contacts, conversion_rate_pct, lift, calls_per_conversion FROM a_conv_by_age ORDER BY age_band"),
    ("Conversion by job", "Horizontal bar: Y = job, X = conversion_rate_pct",
     "SELECT job, contacts, conversion_rate_pct, calls_per_conversion FROM a_conv_by_job ORDER BY conversion_rate_pct DESC"),
    ("Conversion by month", "Bar: X = month_name (sorted by month_num), Y = conversion_rate_pct; second axis share_of_contacts_pct",
     "SELECT month_num, month_name, contacts, conversion_rate_pct, share_of_contacts_pct FROM a_conv_by_month ORDER BY month_num"),
    ("Age band x channel", "Grouped bar: X = age_band, Y = conversion_rate_pct, color = channel_label",
     "SELECT age_band, channel_label, contacts, conversion_rate_pct FROM a_age_channel_matrix ORDER BY age_band, channel_label"),
    ("Economic context", "Bar: X = euribor_band, Y = conversion_rate_pct",
     "SELECT euribor_band, contacts, conversion_rate_pct, avg_euribor3m FROM a_conv_by_economy ORDER BY euribor_band"),
]


def dashboard(fq):
    q = lambda t: f"{fq}.{t}"
    datasets = [
        ds("kpi", "Headline KPIs", f"SELECT contacts, conversions, conversion_rate_pct / 100 AS conversion_rate, calls_per_conversion FROM {q('a_kpi_headline')}"),
        ds("calls", "By calls per client", f"SELECT calls_band, contacts, conversion_rate_pct, calls_per_conversion FROM {q('a_conv_by_calls')} ORDER BY calls_band"),
        ds("prev", "By previous outcome", f"SELECT prev_label, contacts, conversion_rate_pct FROM {q('a_conv_by_prev_outcome')}"),
        ds("age", "By age band", f"SELECT age_band, contacts, conversion_rate_pct FROM {q('a_conv_by_age')} ORDER BY age_band"),
        ds("job", "By job", f"SELECT job, contacts, conversion_rate_pct FROM {q('a_conv_by_job')}"),
        ds("month", "By month", f"SELECT concat(lpad(CAST(month_num AS STRING), 2, '0'), ' ', month_name) AS month, contacts, conversion_rate_pct FROM {q('a_conv_by_month')} ORDER BY month_num"),
        ds("age_channel", "Age x channel", f"SELECT age_band, channel_label, conversion_rate_pct FROM {q('a_age_channel_matrix')} ORDER BY age_band"),
    ]
    p1 = [text("title", "## Bank term-deposit telemarketing 2008-2010 - who converts, and when to stop calling (41,176 clients)", {"x": 0, "y": 0, "width": 6, "height": 1}),
          counter("kpi_conv", "kpi", "conversion_rate", "Conversion rate", PCT, 0, w=2),
          counter("kpi_cpc", "kpi", "calls_per_conversion", "Calls per conversion", NUM, 2, w=2),
          text("note", "Conversion = client subscribed a term deposit (y = yes). Calls per conversion is the effort / cost proxy (no money columns in the source). Tables in workspace.da_learn_05.", {"x": 4, "y": 1, "width": 2, "height": 2}),
          chart("calls_bar", "bar", "calls", ("calls_band", "Calls to the same client"), ("conversion_rate_pct", "Conversion %"), "Conversion % by number of calls", {"x": 0, "y": 3, "width": 3, "height": 6}),
          chart("prev_bar", "bar", "prev", ("prev_label", "Previous campaign"), ("conversion_rate_pct", "Conversion %"), "Conversion % by previous-campaign outcome", {"x": 3, "y": 3, "width": 3, "height": 6}, horizontal=True),
          chart("month_bar", "bar", "month", ("month", "Month"), ("conversion_rate_pct", "Conversion %"), "Conversion % by month", {"x": 0, "y": 9, "width": 6, "height": 5})]
    p2 = [text("title2", "## Segments: age, job and channel", {"x": 0, "y": 0, "width": 6, "height": 1}),
          chart("age_bar", "bar", "age", ("age_band", "Age band"), ("conversion_rate_pct", "Conversion %"), "Conversion % by age band", {"x": 0, "y": 1, "width": 3, "height": 6}),
          chart("job_bar", "bar", "job", ("job", "Job"), ("conversion_rate_pct", "Conversion %"), "Conversion % by job", {"x": 3, "y": 1, "width": 3, "height": 6}, horizontal=True),
          chart("age_channel_bar", "bar", "age_channel", ("age_band", "Age band"), ("conversion_rate_pct", "Conversion %"), "Conversion % by age band and channel", {"x": 0, "y": 7, "width": 6, "height": 6}, color=("channel_label", "Channel"))]
    return {"datasets": datasets, "pages": [
        {"name": "overview", "displayName": "Overview", "pageType": "PAGE_TYPE_CANVAS", "layout": p1},
        {"name": "segments", "displayName": "Segments", "pageType": "PAGE_TYPE_CANVAS", "layout": p2}]}
