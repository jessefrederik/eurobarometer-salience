# Eurobarometer issue salience vs real-world conditions

A reproducible R pipeline measuring how salient different problems are to Europeans
— the share naming each as the most important issue facing their country — and how
that tracks the **real-world conditions** the problem refers to:

| Problem perception | Real-world variable (Eurostat) |
|---|---|
| Unemployment | Unemployment rate |
| Inflation / cost of living | HICP inflation |
| Energy | HICP energy inflation |
| Immigration | Asylum applications per 100k |
| Crime | Recorded crime per 100k (homicide + robbery + burglary) |

It harmonises ~70 Eurobarometer waves (2002–2026) into a respondent-level dataset,
extracts each issue's salience, pulls the matching Eurostat series, and reports the
within-country correlation between perception and reality.

![Does perception track conditions?](output/correlation_summary.png)

📄 **Write-up:** [How closely does problem perception track reality?](docs/analysis.md)

## Headline finding

Perception tracks **economic** conditions closely and **immigration** loosely:

| Perception ~ real-world variable | Pearson | Spearman (robust) |
|---|---|---|
| Unemployment ~ unemployment rate | 0.78 | 0.78 |
| Inflation ~ HICP inflation | 0.72 | 0.62 |
| Crime ~ recorded crime | 0.51 | 0.53 |
| Energy ~ HICP energy inflation | 0.49 | **0.24** |
| Immigration ~ asylum applications | 0.26 | 0.30 |

Adding **Spearman** alongside Pearson matters: the energy link nearly halves under
rank correlation (0.49 → 0.24), revealing it is driven by the single 2022 energy-price
spike rather than a steady relationship. Unemployment and crime are robust to it.

## What it produces

- `data/salience_contexts.csv` — salience by issue × country × wave × context
- `data/correlations.csv` — within-country Pearson, Spearman, and panel-FE estimates
- `output/correlation_summary.png` — the forest plot above
- `output/overlay_<issue>.png` — per-country overlays: salience (%) and the
  real-world indicator, each **min–max scaled to its own range** so co-movement is
  visible in every country (free axes); each facet labelled with its Pearson r
- `output/descriptive_<issue>.png` — salience over time, three question contexts

![Unemployment overlay](output/overlay_unemployment.png)

## Data

- **Perceptions** — Eurobarometer "most important issues" battery (asked for *your
  country*, *you personally*, and *the EU*). Harmonised from GESIS microdata
  (2002–2024) and extended with the European Commission's open result volumes
  (2024–Spring 2026). The 3-context split is the pipeline's distinctive feature;
  the correlation analysis uses the national ("your country") context.
- **Real-world** — Eurostat: `une_rt_m` (unemployment), `prc_hicp_manr` (HICP
  inflation + energy), `migr_asyappctzm` (asylum), `crim_gen`/`crim_off_cat`
  (crime). All open, fetched via the `eurostat` package.

## Setup & running

```r
install.packages("renv"); renv::restore()
Sys.setenv(EB_DATA_ROOT = "/path/to/Eurobarometer_individual")  # GESIS .rds files
```

```sh
Rscript run_all.R          # full pipeline; auto-detects microdata
```

No microdata? It still runs on the EC open volumes (recent waves only). To fetch
the full history, register free at <https://login.gesis.org> and run
`R/download_gesis_microdata.R`. GESIS microdata is licence-restricted and **not**
committed here.

Stages:

```
00_download_eurobarometer.R   EC open volumes -> data/ec_salience.csv
01_build_micro.R              harmonise GESIS waves -> core_micro
02_build_contexts.R           issue × context salience -> data/salience_contexts.csv
03_build_macro.R              Eurostat -> data/core_macro.rds
04_correlate.R                within-country Pearson + Spearman + panel FE
05_plot_descriptive.R         salience over time, per issue
06_plot_correlations.R        dual-axis overlays + correlation summary
```

## Method notes

- Correlations are **within-country** (per-country z-scores, pooled) at **annual**
  resolution (crime statistics are annual; annualising keeps the five comparable).
- **Pearson and Spearman** are both reported — Spearman is the honest robustness
  check against the right-skewed rates (energy especially).
- Overlays use **real units on a dual axis**, not z-scores, so magnitudes are visible.

## Caveats

- Eurobarometer runs ~2–3 waves/year, so the perception side caps temporal resolution.
- Correlations are **descriptive co-movement, not causal** — no identification strategy.
- Crime statistics are annual and sparser than the monthly economic series.
- Microdata and EC volumes are spliced at 2024 (validated overlap r = 0.999); Cyprus
  excludes the separately-sampled Turkish-Cypriot Community.

Code: MIT. Data: GESIS (no redistribution), Eurostat (© EU), EC open volumes.
