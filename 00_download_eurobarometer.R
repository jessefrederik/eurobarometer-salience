# 00_download_eurobarometer.R
# -----------------------------------------------------------------------------
# Obtain Eurobarometer data in two tiers:
#   (A) EC open-data volumes  -> data/ec_salience.csv     [always, no login]
#   (B) GESIS microdata        -> EB_DATA_ROOT/*.rds        [optional, needs account]
#
# The 3-context split over the full 2003-2026 history lives only in the GESIS
# microdata; the EC volumes cover the latest rounds openly. The pipeline reuses
# microdata if already present in EB_DATA_ROOT and only downloads what's missing.
# GESIS microdata is licence-restricted and must NOT be committed.
# -----------------------------------------------------------------------------

source("config.R")
source("R/ec_volumes.R")
source("R/immigration_feelings.R")
library(readxl)

# --- (A) EC open volumes ------------------------------------------------------
message("Building EC open-volume salience (all issues, 3 contexts)...")
ec <- build_ec_salience(EC_WAVES, issue_specs, EC_BASE, DIR_VOLUMES)
readr::write_csv(ec, file.path(DIR_DATA, "ec_salience.csv"))
message("  -> ", file.path(DIR_DATA, "ec_salience.csv"), " (", nrow(ec), " rows, ",
        dplyr::n_distinct(ec$wave), " waves)")

# --- (A2) Feelings about immigration (EU vs non-EU), all countries ------------
# Two tiers, like salience: GESIS microdata reaches back to ~2014 (15 waves);
# the EC open volumes cover 2024-2026. Combined and tagged by source.
message("Building immigration-feelings (EU vs non-EU, net positive)...")
feel_ec <- build_immigration_feelings(EC_WAVES, EC_BASE, DIR_VOLUMES) |>
  dplyr::mutate(source = "ec")
feel_micro <- if (file.exists(file.path(DIR_DATA, "scaffold.rds"))) {
  build_immigration_feelings_micro(DATA_ROOT, readRDS(file.path(DIR_DATA, "scaffold.rds"))) |>
    dplyr::mutate(source = "micro")
} else { message("  (no scaffold.rds yet -> microdata feelings skipped; run stage 01 first)"); NULL }
feel <- dplyr::bind_rows(feel_micro, feel_ec) |> dplyr::arrange(origin, country_code, date)
readr::write_csv(feel, file.path(DIR_DATA, "immigration_feelings.csv"))
message("  -> ", file.path(DIR_DATA, "immigration_feelings.csv"), " (", nrow(feel), " rows, ",
        dplyr::n_distinct(feel$country_code), " countries, ",
        format(min(feel$date, na.rm = TRUE)), " - ", format(max(feel$date, na.rm = TRUE)), ")")

# --- (B) GESIS microdata (optional) ------------------------------------------
local_rds <- list.files(DATA_ROOT, pattern = "\\.rds$", full.names = TRUE)
message("GESIS microdata in EB_DATA_ROOT (", DATA_ROOT, "): ", length(local_rds), " .rds files")

if (length(local_rds) == 0) {
  message(
    "  No local microdata found. To build the full-history three-context series:\n",
    "   1. Register (free): https://login.gesis.org/\n",
    "   2. install.packages('gesisdata'); set gesis_email/gesis_password in ~/.Rprofile\n",
    "   3. Run R/download_gesis_microdata.R (downloads .rds into EB_DATA_ROOT)\n",
    "  Without microdata the pipeline still runs on EC volumes (use_gesis = FALSE),\n",
    "  but the personal/national/EU series is limited to the recent EC waves."
  )
}
