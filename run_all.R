# =============================================================================
# run_all.R -- reproduce the whole project in one step.
# Open ocn682-factor-regimes.Rproj in RStudio, then run:  source("run_all.R")
# =============================================================================

source(here::here("scripts", "01_download_data.R"))   # needs internet
source(here::here("scripts", "02_process_data.R"))

# Renders index.qmd (report) and presentation/slides.qmd into docs/
# Equivalent terminal command:  quarto render
quarto::quarto_render(as_job = FALSE)
