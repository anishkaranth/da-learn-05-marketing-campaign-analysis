"""SVG charts for da-learn-05 from the KPI tables written by run_pipeline.py (pure vector, see svgcharts.py)."""
import csv, pathlib, sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import svgcharts as sc


def load(tables, name):
    with open(pathlib.Path(tables) / f"{name}.csv", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def make_all(tables, out):
    out = pathlib.Path(out)
    f = lambda r, k: float(r[k]) if r[k] != "" else 0.0
    kpi = load(tables, "a_kpi_headline")[0]
    age = sorted(load(tables, "a_conv_by_age"), key=lambda r: r["age_band"])
    job = sorted(load(tables, "a_conv_by_job"), key=lambda r: -f(r, "conversion_rate_pct"))
    calls = sorted(load(tables, "a_conv_by_calls"), key=lambda r: r["calls_band"])
    prev = sorted(load(tables, "a_conv_by_prev_outcome"), key=lambda r: -f(r, "conversion_rate_pct"))
    month = sorted(load(tables, "a_conv_by_month"), key=lambda r: int(r["month_num"]))
    eco = sorted(load(tables, "a_conv_by_economy"), key=lambda r: r["euribor_band"])
    mat = load(tables, "a_age_channel_matrix")
    pct = lambda r: f"{f(r, 'conversion_rate_pct'):.1f}%"

    charts = {
        "conversion_by_age": sc.vbar("Conversion rate % by age band", [r["age_band"][3:] for r in age],
                                     [f(r, "conversion_rate_pct") for r in age], notes=[pct(r) for r in age], ylabel="conv %"),
        "conversion_by_job": sc.hbar("Conversion rate % by job (calls per conversion)", [r["job"] for r in job],
                                     [f(r, "conversion_rate_pct") for r in job],
                                     notes=[f"{pct(r)}  {f(r, 'calls_per_conversion'):.0f} calls/conv" for r in job], label_w=90),
        "calls_diminishing_returns": sc.vbar("Conversion % by calls to the same client (label: calls per conversion)",
                                             [r["calls_band"][3:] for r in calls], [f(r, "conversion_rate_pct") for r in calls],
                                             notes=[f"{pct(r)} | {f(r, 'calls_per_conversion'):.0f}" for r in calls], ylabel="conv %"),
        "previous_campaign": sc.hbar("Conversion rate % by previous-campaign outcome", [r["prev_label"] for r in prev],
                                     [f(r, "conversion_rate_pct") for r in prev],
                                     notes=[f"{pct(r)}  n={int(r['contacts']):,}" for r in prev], label_w=150),
        "conversion_by_month": sc.vbar("Conversion % by month (label: share of all contacts)", [r["month_name"] for r in month],
                                       [f(r, "conversion_rate_pct") for r in month],
                                       notes=[f"{f(r, 'share_of_contacts_pct'):.0f}%" for r in month], ylabel="conv %"),
        "conversion_by_euribor": sc.vbar("Conversion % by 3-month Euribor at contact time", [r["euribor_band"][3:] for r in eco],
                                         [f(r, "conversion_rate_pct") for r in eco],
                                         notes=[f"{pct(r)} n={int(r['contacts']):,}" for r in eco], ylabel="conv %"),
    }
    bands = [r["age_band"] for r in age]
    series = [[next((f(m, "conversion_rate_pct") for m in mat if m["age_band"] == b and m["channel_label"] == ch), 0) for b in bands]
              for ch in ("Mobile", "Landline")]
    charts["age_x_channel"] = sc.vbar("Conversion % by age band and channel", [b[3:] for b in bands], series,
                                      names=["Mobile", "Landline"], ylabel="conv %")
    for name, panel in charts.items():
        sc.save(panel, out / f"{name}.svg")
    kpis = [(f"{int(float(kpi['contacts'])):,}", "Clients contacted"), (f"{int(float(kpi['conversions'])):,}", "Deposits sold"),
            (f"{float(kpi['conversion_rate_pct']):.2f}%", "Conversion rate"), (f"{int(float(kpi['total_calls'])):,}", "Calls made"),
            (f"{float(kpi['calls_per_conversion']):.1f}", "Calls per sale"), (f"{float(kpi['pct_mobile']):.1f}%", "Reached on mobile")]
    order = ["calls_diminishing_returns", "previous_campaign", "conversion_by_age", "conversion_by_job", "conversion_by_month", "age_x_channel"]
    sc.dashboard(out / "dashboard.svg", "Bank term-deposit telemarketing 2008-2010: who converts, and when to stop calling", kpis,
                 [charts[k] for k in order])
    print("charts ->", out, sorted(p.name for p in out.glob("*.svg")))


if __name__ == "__main__":
    make_all(sys.argv[1] if len(sys.argv) > 1 else "results/tables", sys.argv[2] if len(sys.argv) > 2 else "results/charts")
