# =============================================================================
# 01_download_data.R
# Downloads the raw data into data/raw/. Requires an internet connection.
# Run from anywhere inside the project (paths use here::here()).
# =============================================================================

library(here)
library(readr)
library(tibble)

options(timeout = 300)
raw_dir <- here("data", "raw")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

# Download with the {curl} package:
# - forces HTTP/1.1 (FRED can fail with "Stream error in the HTTP/2 framing layer")
# - sends browser-like headers (FRED's firewall can stall non-browser requests)
# - times out instead of hanging, and retries a few times
# - if the download fails but the file is already in data/raw/ (for example,
#   saved manually from a browser), the existing file is used instead.
fetch <- function(url, dest, tries = 3, timeout = 90) {
  for (i in seq_len(tries)) {
    h <- curl::new_handle(
      http_version   = 2L,   # 2 = CURL_HTTP_VERSION_1_1
      connecttimeout = 20,
      timeout        = timeout,
      useragent      = paste("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
                             "AppleWebKit/537.36 (KHTML, like Gecko)",
                             "Chrome/129.0 Safari/537.36")
    )
    curl::handle_setheaders(h, Accept = "text/csv,text/plain,*/*",
                            `Accept-Language` = "en-US,en;q=0.9")
    ok <- tryCatch({
      curl::curl_download(url, dest, handle = h, quiet = TRUE)
      TRUE
    }, error = function(e) {
      message("  attempt ", i, " failed: ", conditionMessage(e))
      FALSE
    })
    if (ok) {
      message("Downloaded: ", sub("\\?.*$", "", basename(url)),
              if (grepl("id=", url)) sub(".*id=", " ", url) else "")
      return(invisible(dest))
    }
    Sys.sleep(2)
  }
  if (file.exists(dest)) {
    warning("Download failed; using existing file ", basename(dest),
            call. = FALSE)
    return(invisible(dest))
  }
  stop("Could not download ", url, " after ", tries, " attempts.\n",
       "Manual fix: open that URL in a web browser and save the file as\n  ",
       dest, "\nthen run this script again.", call. = FALSE)
}

log <- list()

# --- 1. Kenneth R. French Data Library (zipped CSVs) -------------------------
french_base  <- "https://mba.tuck.dartmouth.edu/pages/faculty/ken.french/ftp/"
french_files <- c(
  ff5 = "F-F_Research_Data_5_Factors_2x3_CSV.zip",
  mom = "F-F_Momentum_Factor_CSV.zip"
)

for (nm in names(french_files)) {
  url      <- paste0(french_base, french_files[[nm]])
  zip_path <- tempfile(fileext = ".zip")
  fetch(url, zip_path)

  csv_name <- unzip(zip_path, list = TRUE)$Name[1]
  unzip(zip_path, files = csv_name, exdir = raw_dir, overwrite = TRUE)

  target <- file.path(raw_dir, paste0("french_", nm, ".csv"))
  if (file.exists(target)) file.remove(target)
  file.rename(file.path(raw_dir, csv_name), target)

  log[[length(log) + 1]] <- tibble(file = basename(target), source_url = url)
}

# --- 2. FRED (Federal Reserve Bank of St. Louis) -----------------------------
# USREC  : NBER-based recession indicator (monthly, 0/1)
# GS10   : 10-year Treasury constant-maturity yield (monthly, %)
# TB3MS  : 3-month Treasury bill secondary-market rate (monthly, %)
# VIXCLS : Cboe VIX daily close (1990 onward) -- see README on redistribution
#
# FRED often blocks or stalls requests from scripts (on some networks it
# never answers R at all), while the same links work in a web browser.
# So: if a FRED file is already in data/raw/ we keep it and do not re-download.
# Files saved from a browser keep FRED's default name (e.g. "USREC.csv");
# they are renamed to the project's naming scheme ("fred_USREC.csv").
fred_series <- c("USREC", "GS10", "TB3MS", "VIXCLS")

# Remove leftovers from interrupted downloads
unlink(list.files(raw_dir, pattern = "\\.curltmp$", full.names = TRUE))

for (id in fred_series) {
  url    <- paste0("https://fred.stlouisfed.org/graph/fredgraph.csv?id=", id)
  target <- file.path(raw_dir, paste0("fred_", id, ".csv"))
  manual <- file.path(raw_dir, paste0(id, ".csv"))

  if (!file.exists(target) && file.exists(manual)) file.rename(manual, target)

  if (file.exists(target)) {
    message("Using existing file: ", basename(target))
  } else {
    fetch(url, target, tries = 2, timeout = 30)
  }
  log[[length(log) + 1]] <- tibble(file = basename(target), source_url = url)
}

# --- 3. Record what was downloaded and when ----------------------------------
download_log <- dplyr::bind_rows(log)
download_log$downloaded_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)
write_csv(download_log, file.path(raw_dir, "download_log.csv"))

message("All raw files saved to data/raw/.")
