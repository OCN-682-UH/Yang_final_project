# =============================================================================
# functions.R
# Reusable functions for the "Factor premia across economic regimes" project.
# Sourced by scripts/02_process_data.R, index.qmd and presentation/slides.qmd.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)   # dplyr, tidyr, readr, purrr, ggplot2, stringr, lubridate
  library(broom)
  library(slider)
  library(here)
  library(scales)
})

# -----------------------------------------------------------------------------
# Lookup table: factor codes, readable labels, and the year the underlying
# anomaly was first published (used for the pre/post-publication analysis).
# -----------------------------------------------------------------------------
factor_info <- tribble(
  ~factor,  ~label,          ~pub_year, ~pub_source,
  "Mkt-RF", "Market",        NA_integer_, NA_character_,
  "SMB",    "Size",          1981L,     "Banz (1981)",
  "HML",    "Value",         1992L,     "Fama & French (1992)",
  "RMW",    "Profitability", 2013L,     "Novy-Marx (2013)",
  "CMA",    "Investment",    2004L,     "Titman, Wei & Xie (2004)",
  "Mom",    "Momentum",      1993L,     "Jegadeesh & Titman (1993)"
)

# Colour-blind-friendly palette (Okabe-Ito), one colour per factor
factor_colors <- setNames(
  c("#0072B2", "#E69F00", "#009E73", "#CC79A7", "#56B4E9", "#D55E00"),
  factor_info$label
)

# Convert factor codes ("HML") into an ordered factor of labels ("Value")
label_factors <- function(df) {
  df |>
    mutate(factor = factor(factor,
                           levels = factor_info$factor,
                           labels = factor_info$label))
}

# -----------------------------------------------------------------------------
# Reading raw data
# -----------------------------------------------------------------------------

#' Parse a Ken French Data Library CSV and return only the monthly block.
#'
#' French's CSVs start with several lines of description, then a header row
#' that begins with a comma (",Mkt-RF,SMB,..."), then monthly rows (YYYYMM),
#' then a blank line and an annual block. We keep only the monthly block.
#'
#' @param path Path to the unzipped CSV.
#' @return Tibble with a `date` column (first day of month) and one column
#'   per factor, in percent per month.
parse_french_csv <- function(path) {
  lines <- read_lines(path)

  header_idx <- which(str_detect(lines, "^\\s*,"))[1]
  if (is.na(header_idx)) stop("Could not find a header row in ", path)

  body     <- lines[(header_idx + 1):length(lines)]
  is_month <- str_detect(body, "^\\s*\\d{6}\\s*,")
  first_non_month <- which(!is_month)[1]
  if (!is.na(first_non_month)) body <- body[seq_len(first_non_month - 1)]

  col_names    <- str_trim(str_split_1(lines[header_idx], ","))
  col_names[1] <- "yyyymm"

  read_csv(I(paste(body, collapse = "\n")),
           col_names = col_names,
           na = c("-99.99", "-999"),
           show_col_types = FALSE) |>
    mutate(date = ymd(paste0(yyyymm, "01")), .before = 1) |>
    select(-yyyymm)
}

#' Read a FRED "fredgraph.csv" download.
#'
#' FRED marks missing values with "." and has used both "DATE" and
#' "observation_date" as the first column name, so we standardise both.
read_fred_csv <- function(path) {
  raw <- read_csv(path, col_types = cols(.default = col_character()))
  names(raw)[1] <- "date"
  raw |>
    mutate(date = ymd(date),
           across(-date, \(x) suppressWarnings(as.numeric(x))))
}

# -----------------------------------------------------------------------------
# Analysis helpers
# -----------------------------------------------------------------------------

#' Annualised summary statistics of monthly factor returns.
#'
#' @param df Long data with columns `factor` and `ret` (percent per month).
#' @param ... Additional grouping variables (e.g. a regime column).
summarise_premia <- function(df, ...) {
  df |>
    group_by(factor, ...) |>
    summarise(
      n_months = sum(!is.na(ret)),
      mean_ann = 12 * mean(ret, na.rm = TRUE),
      sd_ann   = sqrt(12) * sd(ret, na.rm = TRUE),
      sharpe   = mean_ann / sd_ann,
      t_stat   = mean(ret, na.rm = TRUE) / (sd(ret, na.rm = TRUE) / sqrt(n_months)),
      .groups  = "drop"
    )
}

#' Start/end dates of NBER recessions, for shading time-series plots.
recession_periods <- function(macro) {
  macro |>
    filter(!is.na(usrec)) |>
    arrange(date) |>
    mutate(spell = cumsum(usrec != lag(usrec, default = 0))) |>
    filter(usrec == 1) |>
    group_by(spell) |>
    summarise(start = min(date),
              end   = max(date) %m+% months(1),
              .groups = "drop")
}

#' Fit the same linear model separately for every factor (many-model workflow).
#'
#' @return One row per factor with list-columns: data, model, coefs, fit.
fit_by_factor <- function(df, formula) {
  df |>
    group_by(factor) |>
    nest() |>
    ungroup() |>
    mutate(
      model = map(data, \(d) lm(formula, data = d)),
      coefs = map(model, \(m) tidy(m, conf.int = TRUE)),
      fit   = map(model, glance)
    )
}

#' Rolling-window average return with a 95% confidence band (annualised).
rolling_premium <- function(df, window = 120) {
  se_fun <- \(x) sd(x) / sqrt(length(x))
  df |>
    arrange(factor, date) |>
    group_by(factor) |>
    mutate(
      roll_mean = slide_dbl(ret, mean,   .before = window - 1, .complete = TRUE),
      roll_se   = slide_dbl(ret, se_fun, .before = window - 1, .complete = TRUE)
    ) |>
    ungroup() |>
    filter(!is.na(roll_mean)) |>
    mutate(mean_ann = 12 * roll_mean,
           lo       = 12 * (roll_mean - 1.96 * roll_se),
           hi       = 12 * (roll_mean + 1.96 * roll_se))
}

# -----------------------------------------------------------------------------
# Plotting
# -----------------------------------------------------------------------------

theme_project <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      panel.grid.minor = element_blank(),
      strip.text       = element_text(face = "bold", hjust = 0),
      plot.title.position = "plot",
      legend.position  = "bottom"
    )
}

save_fig <- function(plot, filename, width = 8, height = 5) {
  ggsave(here("outputs", "figures", filename), plot,
         width = width, height = height, dpi = 300, bg = "white")
  invisible(plot)
}

# Figure 1: growth of $1 in each factor, with recessions shaded
plot_cumulative <- function(factors, recessions) {
  cum <- factors |>
    arrange(factor, date) |>
    group_by(factor) |>
    mutate(wealth = cumprod(1 + ret / 100)) |>
    ungroup()

  ggplot(cum, aes(date, wealth)) +
    geom_rect(data = recessions,
              aes(xmin = start, xmax = end, ymin = 0, ymax = Inf),   # 0 (not -Inf) on log scale
              inherit.aes = FALSE, fill = "grey80", alpha = 0.7) +
    geom_hline(yintercept = 1, linetype = "dashed", linewidth = 0.3) +
    geom_line(aes(colour = factor), linewidth = 0.5, show.legend = FALSE) +
    scale_y_log10(labels = label_dollar()) +
    scale_colour_manual(values = factor_colors) +
    facet_wrap(~ factor, ncol = 3) +
    labs(x = NULL, y = "Growth of $1 (log scale)") +
    theme_project()
}

# Figure 2: average returns by prior-month VIX tercile
plot_vix_regimes <- function(vix_stats) {
  ggplot(vix_stats, aes(mean, fct_rev(factor), colour = vix_regime)) +
    geom_vline(xintercept = 0, linewidth = 0.3) +
    geom_pointrange(aes(xmin = lo, xmax = hi),
                    position = position_dodge(width = 0.6)) +
    scale_colour_manual(values = c(Low = "#9ECAE1", Medium = "#4292C6",
                                   High = "#08306B")) +
    labs(x = "Average return (% per year, 95% CI)", y = NULL,
         colour = "Prior-month VIX") +
    theme_project()
}

# Figure 3: coefficients from the per-factor regressions
plot_coefs <- function(coefs) {
  coefs |>
    mutate(term = case_when(
      term == "usrec"           ~ "Recession month (vs. expansion)",
      term == "term_spread_lag" ~ "Term spread, prior month (per 1 pp)",
      .default = term
    )) |>
    ggplot(aes(estimate, fct_rev(factor), colour = factor)) +
    geom_vline(xintercept = 0, linewidth = 0.3) +
    geom_pointrange(aes(xmin = conf.low, xmax = conf.high),
                    show.legend = FALSE) +
    scale_colour_manual(values = factor_colors) +
    facet_wrap(~ term, scales = "free_x") +
    labs(x = "Change in monthly return (percentage points, 95% CI)", y = NULL) +
    theme_project()
}

# Figure 4: rolling 10-year premium with publication year marked
plot_rolling <- function(rolling, pub_lines) {
  ggplot(rolling, aes(date, mean_ann)) +
    geom_hline(yintercept = 0, linewidth = 0.3) +
    geom_ribbon(aes(ymin = lo, ymax = hi, fill = factor), alpha = 0.2,
                show.legend = FALSE) +
    geom_line(aes(colour = factor), show.legend = FALSE) +
    geom_vline(data = pub_lines, aes(xintercept = pub_date),
               linetype = "dashed", linewidth = 0.4) +
    scale_colour_manual(values = factor_colors) +
    scale_fill_manual(values = factor_colors) +
    facet_wrap(~ factor, ncol = 3) +
    labs(x = "End of 10-year window",
         y = "Rolling average return (% per year)") +
    theme_project()
}

#' Make sure the processed data exist; if not, run the download and/or
#' processing scripts first. Lets index.qmd and slides.qmd render on a
#' fresh clone even if run_all.R was not used.
ensure_processed_data <- function() {
  target <- here("data", "processed", "factor_macro_monthly.csv")
  if (!file.exists(target)) {
    raw_needed <- here("data", "raw",
                       c("french_ff5.csv", "french_mom.csv", "fred_USREC.csv",
                         "fred_GS10.csv", "fred_TB3MS.csv", "fred_VIXCLS.csv"))
    if (!all(file.exists(raw_needed))) {
      message("Raw data missing: running scripts/01_download_data.R")
      source(here("scripts", "01_download_data.R"), local = new.env())
    }
    message("Processed data missing: running scripts/02_process_data.R")
    source(here("scripts", "02_process_data.R"), local = new.env())
  }
  invisible(target)
}

# Small formatting helper for inline numbers in the report
fmt_pct <- function(x, digits = 1) sprintf(paste0("%.", digits, "f%%"), x)
