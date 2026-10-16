# =============================================================================
# 02_process_data.R
# Cleans and joins the raw files into analysis-ready monthly data.
# Input : data/raw/*.csv (from 01_download_data.R)
# Output: data/processed/factors_monthly.csv
#         data/processed/macro_monthly.csv
#         data/processed/factor_macro_monthly.csv   <- used by the report
# =============================================================================

source(here::here("scripts", "functions.R"))

raw_dir  <- here("data", "raw")
proc_dir <- here("data", "processed")
dir.create(proc_dir, recursive = TRUE, showWarnings = FALSE)

needed  <- c("french_ff5.csv", "french_mom.csv", "fred_USREC.csv",
             "fred_GS10.csv", "fred_TB3MS.csv", "fred_VIXCLS.csv")
missing <- needed[!file.exists(file.path(raw_dir, needed))]
if (length(missing) > 0) {
  stop("Missing raw files: ", paste(missing, collapse = ", "),
       "\nRun scripts/01_download_data.R first.")
}

# --- 1. Factor returns --------------------------------------------------------
ff5 <- parse_french_csv(file.path(raw_dir, "french_ff5.csv"))
mom <- parse_french_csv(file.path(raw_dir, "french_mom.csv"))

factors_wide <- inner_join(ff5, mom, by = "date")   # common sample (from 1963-07)

rf <- factors_wide |> select(date, rf = RF)

factors_monthly <- factors_wide |>
  select(-RF) |>
  pivot_longer(-date, names_to = "factor", values_to = "ret") |>
  filter(!is.na(ret)) |>
  arrange(factor, date)

unexpected <- setdiff(unique(factors_monthly$factor), factor_info$factor)
if (length(unexpected) > 0) {
  stop("Unexpected factor columns in French files: ",
       paste(unexpected, collapse = ", "))
}

# --- 2. Macro / market-condition variables -----------------------------------
usrec <- read_fred_csv(file.path(raw_dir, "fred_USREC.csv")) |> rename(usrec = USREC)
gs10  <- read_fred_csv(file.path(raw_dir, "fred_GS10.csv"))  |> rename(gs10 = GS10)
tb3ms <- read_fred_csv(file.path(raw_dir, "fred_TB3MS.csv")) |> rename(tb3ms = TB3MS)

# VIX is daily: aggregate to a monthly average
vix_monthly <- read_fred_csv(file.path(raw_dir, "fred_VIXCLS.csv")) |>
  filter(!is.na(VIXCLS)) |>
  mutate(date = floor_date(date, "month")) |>
  group_by(date) |>
  summarise(vix = mean(VIXCLS), vix_days = n(), .groups = "drop")

macro_monthly <- usrec |>
  full_join(gs10,  by = "date") |>
  full_join(tb3ms, by = "date") |>
  left_join(vix_monthly, by = "date") |>
  left_join(rf, by = "date") |>
  arrange(date) |>
  mutate(
    usrec           = as.integer(usrec),
    term_spread     = gs10 - tb3ms,
    # Lag by one month so predictors are known before the return month
    term_spread_lag = lag(term_spread),
    vix_lag         = lag(vix)
  ) |>
  filter(date >= ymd("1960-01-01"))

# --- 3. Analysis panel: one row per factor-month ------------------------------
factor_macro_monthly <- factors_monthly |>
  inner_join(macro_monthly |>
               select(date, usrec, term_spread, term_spread_lag, vix, vix_lag),
             by = "date") |>
  filter(!is.na(usrec)) |>
  arrange(factor, date)

# --- 4. Sanity checks ----------------------------------------------------------
stopifnot(
  !anyDuplicated(factor_macro_monthly[c("date", "factor")]),
  all(factor_macro_monthly$usrec %in% c(0L, 1L)),
  n_distinct(factor_macro_monthly$factor) == nrow(factor_info)
)

# --- 5. Save ------------------------------------------------------------------
write_csv(factors_monthly,      file.path(proc_dir, "factors_monthly.csv"))
write_csv(macro_monthly,        file.path(proc_dir, "macro_monthly.csv"))
write_csv(factor_macro_monthly, file.path(proc_dir, "factor_macro_monthly.csv"))

message(sprintf(
  "Processed panel: %d rows, %d factors, %s to %s.",
  nrow(factor_macro_monthly), n_distinct(factor_macro_monthly$factor),
  format(min(factor_macro_monthly$date), "%Y-%m"),
  format(max(factor_macro_monthly$date), "%Y-%m")
))
