# How closely does problem perception track reality?

*Eurobarometer issue salience vs real-world conditions, 2002–2026. Reproducible from this repository (`run_all.R`).*

## Question

When a problem gets worse in the real world, do more people name it the most
important issue facing their country? We test five problems against the Eurostat
variable each should plausibly respond to:

| Perception | Real-world variable |
|---|---|
| Unemployment | Unemployment rate |
| Inflation / cost of living | HICP inflation |
| Energy | HICP energy inflation |
| Immigration | Asylum applications per 100k |
| Crime | Recorded crime per 100k (homicide + robbery + burglary) |

## Method

Salience is the survey-weighted share naming the issue (national context, QA3).
Correlations are **within country** (per-country z-scores, pooled, so they describe
over-time co-movement rather than cross-country level differences) and at **annual**
resolution, because crime statistics are annual and this keeps the five comparable.
We report **Pearson** (with 95% CI), **Spearman** (rank — robust to the skewed,
spiky rates), and a panel fixed-effects slope. Time-series overlays show salience (%)
and the indicator **each min–max scaled to its own range, per country** (free axes),
so co-movement is visible in every country; each facet is labelled with its Pearson r.

## Findings

![Correlation summary](../output/correlation_summary.png)

| Perception ~ variable | Pearson | Spearman | n (country-years) |
|---|---|---|---|
| Unemployment ~ unemployment rate | **0.78** | **0.78** | 624 |
| Inflation ~ HICP inflation | 0.72 | 0.62 | 598 |
| Crime ~ recorded crime | 0.51 | 0.53 | 571 |
| Energy ~ HICP energy inflation | 0.49 | **0.24** | 312 |
| Immigration ~ asylum applications | 0.26 | 0.30 | 579 |

**1. Economic problems track reality closely.** Unemployment salience moves almost
one-for-one with the unemployment rate (0.78, identical under Pearson and Spearman) —
the cleanest relationship in the data, visible country by country in the overlay
(the 2008–13 surge in Spain, Greece, Portugal, Ireland). Inflation is close behind.

![Unemployment overlay](../output/overlay_unemployment.png)

**2. Energy is an artefact of one spike.** Energy salience correlates with energy
prices at 0.49 under Pearson but only **0.24** under Spearman — the gap is the tell.
The relationship is carried almost entirely by the 2022 energy-price shock; outside
that episode there is little steady co-movement. This is exactly the kind of
outlier-driven result a rank correlation is meant to expose.

**3. Immigration tracks asylum only loosely.** At 0.26–0.30 it is the weakest link of
the five. Immigration salience is driven by crisis episodes (2015–16) and by national
politics more than by the asylum numbers themselves — concern often stays high after
flows recede, and rises for reasons unrelated to local arrivals.

**4. Crime tracks moderately** (≈0.52, robust across both measures), though crime
statistics are annual and sparser than the monthly economic series.

## Takeaway

Problem perception is **tightly coupled to economic conditions** (unemployment,
inflation) and **loosely coupled to immigration**. Where Pearson and Spearman agree
(unemployment, crime, immigration) the relationship is real; where they diverge
(energy) it is an episode, not a trend. "People worry about what's happening" holds
strongly for the economy and weakly for immigration.

## Caveats

- Eurobarometer runs ~2–3 waves/year, so the perception side caps temporal resolution.
- Correlations are **descriptive co-movement, not causal** — measures are collinear
  and there is no identification strategy.
- Crime data is annual and covers fewer country-years than the economic series.
- National-context salience only; microdata + EC open volumes spliced at 2024
  (validated overlap r = 0.999); Cyprus excludes the Turkish-Cypriot Community sample.
- **Data quality:** EB 65.3 (ZA4507, May 2006) is excluded — it used a non-standard
  multi-select "important national issues" question (respondents picked ~3 issues vs
  the standard 2), which inflated *every* issue's salience ~2–3× and produced a
  spurious one-wave spike. It is the only such wave (all others verified consistent).
