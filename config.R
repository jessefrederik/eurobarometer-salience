# config.R — central configuration for the Eurobarometer salience pipeline.
# Sourced by every numbered script. No heavy work here, just settings + lookups.

suppressMessages({
  library(tidyverse)
})

# --- Paths -------------------------------------------------------------------
# Where the GESIS microdata .rds files live. Override with the EB_DATA_ROOT env
# var. Defaults to a local cache outside the repo (microdata is NOT redistributable).
DATA_ROOT <- Sys.getenv(
  "EB_DATA_ROOT",
  unset = file.path(Sys.getenv("HOME"), "eb_data_local/Eurobarometer_individual")
)

DIR_DATA      <- "data"                       # gitignored intermediates + downloads
DIR_REF       <- "data/reference"             # committed small reference files
DIR_VOLUMES   <- "data/ec_volumes"            # downloaded EC Volume A xlsx (gitignored)
DIR_EXTERNAL  <- "data/external"              # optional manual files (GTD, UK) — gitignored
DIR_OUTPUT    <- "output"                     # figures + tables
for (d in c(DIR_DATA, DIR_VOLUMES, DIR_EXTERNAL, DIR_OUTPUT)) dir.create(d, showWarnings = FALSE, recursive = TRUE)

DATE_CORRECTIONS <- file.path(DIR_REF, "date_corrections.csv")

# --- Country set -------------------------------------------------------------
# 27 EU members + UK + the EU aggregate. Candidate/EFTA states (TR, RS, ME, MK,
# AL, BA, NO, IS, CH, MD, GE) and CY-TCC fall outside this and are dropped from panels.
EU_SET <- c("AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","EL","HU",
            "IE","IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES",
            "SE","UK","EU")

# --- Issue specifications -----------------------------------------------------
# One row per issue we extract from the "most important issues" battery. `include`
# is a (case-insensitive) regex matched against the variable LABEL; `exclude`
# removes false positives. A respondent "mentions" the issue if ANY matching item
# is ticked (pmax over items). These same patterns are reused to map the EC
# open-volume English issue rows onto canonical issues.
#
# `correlate` flags issues with a real-world macro counterpart (see ISSUE_MACRO).
issue_specs <- tribble(
  ~issue,                      ~label,                       ~include,                                              ~exclude,        ~correlate,
  "immigration",               "Immigration",                "IMMIGR",                                              NA,              TRUE,
  "environment_climate",       "Environment / climate",      "ENVIRON|CLIMAT",                                      NA,              FALSE,
  "unemployment",              "Unemployment",               "UNEMPLOY",                                            NA,              TRUE,
  "inflation_cost_of_living",  "Inflation / cost of living", "RISING PRICES|INFLATION|COST OF LIVING|LIVING COST",  NA,              TRUE,
  "economy",                   "Economic situation",         "ECONOMIC SITUATION|\\bECONOMY\\b",                    "EUROPEAN ECON", TRUE,
  "crime",                     "Crime",                      "\\bCRIME\\b",                                         NA,              TRUE,
  "terrorism",                 "Terrorism",                  "TERRORISM",                                           NA,              TRUE,
  "energy",                    "Energy",                     "ENERGY",                                              "ENVIRON|CLIMAT",TRUE,
  "healthcare",                "Health",                     "\\bHEALTH",                                           NA,              FALSE,
  "pensions",                  "Pensions",                   "PENSION",                                             NA,              FALSE,
  "taxation",                  "Taxation",                   "TAXATION|\\bTAXES?\\b",                               NA,              FALSE,
  "housing",                   "Housing",                    "HOUSING",                                             NA,              FALSE,
  "education",                 "Education",                  "EDUCATION",                                           NA,              FALSE,
  "government_debt",           "Government debt",            "GOVERNMENT DEBT|PUBLIC DEBT|NATIONAL DEBT",           NA,              FALSE,
  "defence_foreign_affairs",   "Defence / foreign affairs",  "DEFEN|FOREIGN AFF|SECURITY AND DEFEN",                NA,              FALSE,
  "international_situation",   "International situation",    "INTERNATIONAL SITUATION",                             NA,              FALSE
)

# --- Issue -> real-world macro variable map (for correlation) -----------------
# expected_sign: the hypothesised direction of the salience~macro relationship.
ISSUE_MACRO <- tribble(
  ~issue,                      ~macro_var,           ~macro_label,                       ~expected_sign,
  "unemployment",              "unemp_rate",         "Unemployment rate (Eurostat)",     "+",
  "inflation_cost_of_living",  "inflation_rate",     "HICP inflation (Eurostat)",        "+",
  "immigration",               "asylum_rate",        "Asylum apps per 100k (Eurostat)",  "+",
  "immigration",               "total_permit_first", "First residence permits (Eurostat)","+",
  "economy",                   "gdp_per_cap_growth", "GDP per capita growth (Eurostat)", "-",
  "crime",                     "homicide_per_100k",  "Homicides per 100k (Eurostat)",    "+",
  "energy",                    "energy_rate",        "HICP energy inflation (Eurostat)", "+",
  "terrorism",                 "terror_national",    "Terrorism deaths (GTD, optional)", "+"
)

# --- EC open-data volumes (European Commission portal; no login) --------------
# Standard EB "Volume A" trend tables. Keys resolved 2026-05-26 via data.europa.eu
# (catalog "commu"); refresh via the resolver in 00_download_eurobarometer.R if they 404.
EC_BASE  <- "https://webgate.ec.europa.eu/ebsm/api/public/odp/download?key="
EC_WAVES <- tribble(
  ~wave,      ~key,
  "EB101.3",  "202289A0E60356141402B692C20F5193",   # Spring 2024
  "EB102.2",  "A2534D981B6C0CF8878DEB8447FB08F4",   # Autumn 2024
  "EB103.3",  "AF452C0A6DD70E5D13273C5DF2086956",   # Spring 2025
  "EB104.1",  "A68C45C80315C6F37BBA366C32491DED",   # Autumn 2025
  "EB105.2",  "99134D6EF7DB334B8485DC4C0535E9C2"     # Spring 2026
)

# Canonical issue display order for plots
issue_levels <- issue_specs$issue
