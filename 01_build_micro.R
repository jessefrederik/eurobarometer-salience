# 01_build_micro.R
# -----------------------------------------------------------------------------
# Harmonise the GESIS Eurobarometer microdata waves into one respondent-level
# dataset `core_micro` (binary issue dummies, survey weights, country, date).
# Caches the lightweight scaffold (study, id, country_code, weight, weight_eu27,
# date) used by the three-context extractor in 02.
#
# Includes the Cyprus fix: CY-TCC is kept separate from CY (not merged), which
# corrects Cyprus salience on every issue. See R/build_core_micro.R.
# -----------------------------------------------------------------------------

source("config.R")
source("R/build_core_micro.R")   # -> core_micro (reads EB_DATA_ROOT/*.rds)

saveRDS(core_micro, file.path(DIR_DATA, "core_micro.rds"))
saveRDS(
  core_micro %>% dplyr::select(study, id, country_code, weight, weight_eu27, date),
  file.path(DIR_DATA, "scaffold.rds")
)
message("Built core_micro: ", nrow(core_micro), " respondents, ",
        dplyr::n_distinct(core_micro$study), " waves, ",
        dplyr::n_distinct(core_micro$country_code), " countries.")
