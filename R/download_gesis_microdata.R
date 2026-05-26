# download_gesis_microdata.R
# -----------------------------------------------------------------------------
# AUTHENTICATED route: fetch the latest Standard Eurobarometer MICRODATA from the
# GESIS Data Archive and convert it to the .rds form that core_micro.R reads.
#
# Use this ONLY when you need respondent-level data (e.g. to refit the glmer
# model in core_analysis.R). For the salience CHARTS you do NOT need this — the
# open EC volumes (fetch_ec_salience.R) already cover waves up to Spring 2026,
# whereas GESIS currently only archives Standard microdata up to EB 102.2.
#
# ---- WHY this needs your credentials ----------------------------------------
# GESIS has no anonymous download API. Files require a (free) GESIS account and
# per-study acceptance of the usage terms. The `gesisdata` package automates the
# browser login + download; it cannot run without YOUR account.
#
# ---- ONE-TIME SETUP ----------------------------------------------------------
# 1. Register (free): https://login.gesis.org/  (username = your email)
# 2. Install the package + a headless browser backend:
#        install.packages("gesisdata")     # CRAN
#        # gesisdata drives a browser via 'chromote' -> needs Chrome/Chromium
# 3. Put credentials in ~/.Rprofile (NOT in this script / git):
#        options(gesis_email    = "[email protected]",
#                gesis_password = "********",
#                gesis_use      = 5)        # 5 = "final scientific publication"
#    (Or omit them and gesis_download() will prompt interactively.)
# -----------------------------------------------------------------------------

library(gesisdata)
library(haven)

# Latest Standard Eurobarometers carrying the country/EU/personal "most important
# issues" battery (QA3/QA4/QA5). Newest archived at GESIS as of 2026-05.
# (Your repo already has up to ZA8843 = EB 101.3.)
TARGETS <- c(
  ZA8900 = "EB 101.5 (2024)",
  ZA8905 = "EB 102.2 (Autumn 2024)"
  # Newer waves (EB 103/104/105) are not yet deposited at GESIS as microdata;
  # add their ZA numbers here once they appear in the GESIS Data Catalogue.
)

# Where core_micro.R looks for .rds files:
DATA_ROOT <- Sys.getenv(
  "EB_DATA_ROOT",
  unset = file.path(Sys.getenv("HOME"), "eb_data_local/Eurobarometer_individual")
)
staging <- file.path(tempdir(), "gesis_dl")
dir.create(staging, showWarnings = FALSE, recursive = TRUE)

for (za in names(TARGETS)) {
  rds_out <- file.path(DATA_ROOT, paste0(za, ".rds"))
  if (file.exists(rds_out)) { message(za, " already present — skipping"); next }

  message("Downloading ", za, " (", TARGETS[[za]], ") from GESIS ...")
  # gesis_download() logs in, accepts terms, and saves the data file to download_dir.
  gesisdata::gesis_download(file_id = za, download_dir = staging)

  # GESIS ships SPSS (.sav) or Stata (.dta); convert to .rds for core_micro.R.
  src <- list.files(staging, pattern = paste0("(?i)", za, ".*\\.(sav|dta)$"),
                    full.names = TRUE)
  if (length(src) == 0) { warning("no .sav/.dta found for ", za); next }
  dat <- if (grepl("(?i)\\.sav$", src[1])) haven::read_sav(src[1])
         else                              haven::read_dta(src[1])
  saveRDS(dat, rds_out)
  message("  -> wrote ", rds_out, " (", nrow(dat), " rows)")
}

message("\nDone. Re-run core_micro.R to ingest the new waves. NOTE: new waves may\n",
        "use new variable names — verify regex_issues.R still matches their labels\n",
        "(e.g. scan with the same approach as plot_immigration_contexts.R), and\n",
        "delete plots/.scaffold_cache.rds and plots/.panel_cache.rds to rebuild.")
