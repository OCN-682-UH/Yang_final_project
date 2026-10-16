# Metadata

## Raw data (`data/raw/`)

All raw files are downloaded by `scripts/01_download_data.R`. They are kept exactly as downloaded (only renamed), and `data/raw/download_log.csv` records the source URL and download time of each file.

| File | Source | Frequency | Coverage | Notes |
|---|---|---|---|---|
| `french_ff5.csv` | Kenneth R. French Data Library, *Fama/French 5 Factors (2x3)* | Monthly (an annual block at the end is ignored) | 1963-07 onward | Mkt-RF, SMB, HML, RMW, CMA, RF in percent per month. Missing = -99.99 |
| `french_mom.csv` | Kenneth R. French Data Library, *Momentum Factor (Mom)* | Monthly | 1927 onward | Mom in percent per month |
| `fred_USREC.csv` | FRED, series `USREC` | Monthly | 1854 onward | NBER-based recession indicator, 0/1 |
| `fred_GS10.csv` | FRED, series `GS10` (Board of Governors) | Monthly | 1953 onward | 10-year Treasury yield, % per year |
| `fred_TB3MS.csv` | FRED, series `TB3MS` (Board of Governors) | Monthly | 1934 onward | 3-month T-bill rate, % per year |
| `fred_VIXCLS.csv` | FRED, series `VIXCLS` (Cboe) | Daily | 1990 onward | VIX close. Missing = "." |

Source pages:

- French Data Library: <https://mba.tuck.dartmouth.edu/pages/faculty/ken.french/data_library.html>
- FRED: <https://fred.stlouisfed.org/series/USREC>, `/GS10`, `/TB3MS`, `/VIXCLS`

## Redistribution

- The French Data Library and the Federal Reserve series (GS10, TB3MS) are free public data and are committed with attribution. USREC is FRED's indicator built from NBER business-cycle dates.
- VIX data are © Cboe and are redistributed by FRED. The raw daily file is included here, with attribution, only so that this course project can be reproduced without downloading (FRED blocks scripted downloads).
- The French files are revised over time, so re-downloading may change numbers slightly. `download_log.csv` documents the vintage used.

## Processing (`scripts/02_process_data.R`)

1. Parse the monthly block of each French CSV (skip the description lines and the annual block) and convert `YYYYMM` to a date.
2. Join the five-factor and momentum files on date, keeping the common sample. Separate the risk-free rate (`RF`) and reshape factors to long format (one row per factor-month).
3. Read the FRED series, convert "." to `NA`, and average daily VIX closes within each month.
4. Build the term spread (`gs10 - tb3ms`) and one-month lags of the term spread and VIX, so that predictors are known before the return month.
5. Join factors to macro variables by month and run sanity checks (no duplicate factor-months, recession indicator is 0/1, all six factors present).

Variable definitions are in [`data_dictionary.csv`](data_dictionary.csv).
