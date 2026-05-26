# R/build_frontex_csv.R
# Rebuild data/reference/frontex_ibc_monthly.csv from a raw Frontex
# "Monthly detections of IBC" workbook.
#
# WHY THIS IS NOT AUTO-FETCHED: Frontex does not publish the historical monthly
# series via a stable API. The data.europa.eu entry is stale (2019) and only
# links back to the interactive migratory map; the live ArcGIS FeatureServer
# behind that map exposes ONLY the current month (one record per route, no
# history). The full 2009+ monthly-by-route series is available solely via the
# "Download data" button on https://www.frontex.europa.eu/we-know/migratory-map/
# which generates the workbook client-side.
#
# TO REFRESH (get more recent months): download that workbook, drop it in
#   data/external/Monthly_detections_of_IBC_*.xlsx
# and run this script (or 09 will use the committed CSV if no raw file is found).

source("config.R")
library(readxl); library(tidyr); library(stringr); library(lubridate)

raw <- sort(list.files(DIR_EXTERNAL, pattern = "Monthly_detections_of_IBC.*\\.xlsx$",
                       full.names = TRUE), decreasing = TRUE)
if (length(raw) == 0) {
  message("No raw Frontex workbook in ", DIR_EXTERNAL,
          " — keeping the committed data/reference/frontex_ibc_monthly.csv.\n",
          "  To refresh, download from the Frontex migratory map and place it there.")
} else {
  f <- raw[1]
  message("Rebuilding Frontex CSV from ", basename(f))
  d <- read_excel(f, sheet = "Detections_of_IBC", skip = 1)   # row 1 is a broken formula
  mcols <- names(d)[4:ncol(d)]
  long <- d %>% rename(route = 1) %>% select(route, all_of(mcols)) %>%
    pivot_longer(all_of(mcols), names_to = "m", values_to = "n") %>%
    mutate(date = as.Date(parse_date_time(m, orders = "bY")),
           n = suppressWarnings(as.numeric(n))) %>%
    filter(!is.na(date)) %>%
    group_by(route, date) %>% summarise(detections = sum(n, na.rm = TRUE), .groups = "drop")
  readr::write_csv(long, file.path(DIR_REF, "frontex_ibc_monthly.csv"))
  message("  -> data/reference/frontex_ibc_monthly.csv (", nrow(long), " rows, to ",
          as.character(max(long$date)), ")")
}
