# Do Stock-Market Risk Premia Depend on the Economy?

**OCN 682 / MBIO 612 Data Science Fundamentals in R, Fall 2026: Final Independent Project**
Author: Yang An

## Purpose and question

Finance research summarises the stock market with six standard **factors** (market, size, value, profitability, investment, momentum). Their long-run average returns ("risk premia") are treated as fixed numbers. This project asks whether those premia actually depend on economic conditions:

1. Are factor premia different in **NBER recessions** than in expansions?
2. Do premia change after months of **high market stress** (high VIX)?
3. Have premia **shrunk since the underlying research was published**?

**Primary product:** a Quarto HTML analytical report, `index.qmd` → `docs/index.html` (published with GitHub Pages).
**Presentation:** a Quarto RevealJS deck, `presentation/slides.qmd` → `docs/presentation/slides.html`.

## Repository structure

```
ocn682-factor-regimes/
├── README.md
├── ocn682-factor-regimes.Rproj   # open this in RStudio (sets the project root)
├── _quarto.yml                   # Quarto project: renders report + slides into docs/
├── run_all.R                     # one-step reproduction
├── index.qmd                     # main report
├── references.bib
├── presentation/
│   └── slides.qmd                # 8-10 minute RevealJS talk
├── scripts/
│   ├── functions.R               # reusable parsing, analysis and plotting functions
│   ├── 01_download_data.R        # downloads raw data -> data/raw/
│   └── 02_process_data.R         # cleans + joins -> data/processed/
├── data/
│   ├── raw/                      # untouched downloads + download_log.csv
│   ├── processed/                # analysis-ready CSVs
│   └── metadata/
│       ├── README.md             # sources, coverage, processing steps, redistribution
│       └── data_dictionary.csv   # every variable in every processed file
├── outputs/
│   ├── figures/                  # PNGs saved when the report renders
│   └── tables/                   # CSVs saved when the report renders
└── docs/                         # rendered HTML (GitHub Pages)
```

## Data

| Data | Source | Notes |
|---|---|---|
| Fama/French 5 factors (2x3) and Momentum, monthly | [Kenneth R. French Data Library](https://mba.tuck.dartmouth.edu/pages/faculty/ken.french/data_library.html) | Free public data; committed with attribution |
| `USREC`, `GS10`, `TB3MS` | [FRED](https://fred.stlouisfed.org), Federal Reserve Bank of St. Louis | Free public data; committed |
| `VIXCLS` (daily VIX) | FRED, data owned by Cboe | **Raw file not committed** (Cboe owns the data); `01_download_data.R` downloads it |

See [`data/metadata/README.md`](data/metadata/README.md) for coverage, units and processing steps, and [`data/metadata/data_dictionary.csv`](data/metadata/data_dictionary.csv) for variable definitions.

## Dependencies

- R ≥ 4.2 (uses the native pipe `|>` and `\(x)` lambdas)
- [Quarto](https://quarto.org) ≥ 1.4
- R packages:

```r
install.packages(c("tidyverse", "broom", "slider", "here", "scales", "curl",
                   "gt", "knitr", "rmarkdown", "quarto"))
```

## How to reproduce

**One step.** Open `ocn682-factor-regimes.Rproj` in RStudio, then run:

```r
source("run_all.R")
```

**Or step by step**, in this order:

| Step | Command | What it does |
|---|---|---|
| 1 | `source("scripts/01_download_data.R")` | Downloads 6 raw files into `data/raw/` and writes `download_log.csv` |
| 2 | `source("scripts/02_process_data.R")` | Writes three CSVs to `data/processed/` |
| 3 | `quarto render` (terminal) | Renders the report and slides into `docs/` and saves figures/tables to `outputs/` |

All paths are relative (via `here::here()`), so the project runs from any location on any computer.

## Steps that cannot be fully automated

- **Internet access** is needed for step 1. The French Library updates its files monthly, so a fresh download can shift results slightly. The committed raw files and `download_log.csv` record the vintage used.
- **FRED files may need a browser.** FRED often blocks or stalls downloads from scripts (on some networks it never answers R), while the same links work in a browser. The four FRED raw files except VIX are committed to this repository, so a fresh clone does not need them. If you do need to (re)download them, open each link below in a browser and save the file into `data/raw/`. FRED's default name (e.g. `USREC.csv`) is fine; the script renames it and skips any FRED file that already exists.
  - <https://fred.stlouisfed.org/graph/fredgraph.csv?id=USREC>
  - <https://fred.stlouisfed.org/graph/fredgraph.csv?id=GS10>
  - <https://fred.stlouisfed.org/graph/fredgraph.csv?id=TB3MS>
  - <https://fred.stlouisfed.org/graph/fredgraph.csv?id=VIXCLS>
- **VIX raw data** are not in the repository (see Data), so `VIXCLS` must be downloaded (link above) before step 2 on a fresh clone.
- **GitHub Pages** is switched on once by hand: *Settings → Pages → Deploy from branch → `main` / `docs`*.

## Outputs

| Output | File | Type of processing |
|---|---|---|
| Growth of $1 in each factor, recessions shaded | `outputs/figures/fig1_cumulative_returns.png` | Cumulative compounding, recession spells from a 0/1 series |
| Premia by recession/expansion | `outputs/tables/tab1_regime_stats.csv` | Grouped summaries, reshaping |
| Premia after low/medium/high VIX months | `outputs/figures/fig2_vix_terciles.png` | Daily → monthly aggregation, lagging, terciles |
| One regression per factor | `outputs/figures/fig3_regression_coefficients.png` | `nest()` + `purrr::map()` many-model workflow with `broom` |
| Rolling 10-year premia and pre/post publication | `outputs/figures/fig4_rolling_premia.png`, `outputs/tables/tab4_pre_post_publication.csv` | Rolling windows (`slider`), per-factor models |

## References

Fama & French (1993, 2015); Jegadeesh & Titman (1993); McLean & Pontiff (2016). Full list in `references.bib`.
