# 03_build_macro.R
# -----------------------------------------------------------------------------
# Download the real-world macro indicators from Eurostat (open API) and assemble
# the monthly country panel `core_macro` -> data/core_macro.rds.
# Indicators: unemployment, inflation+energy, asylum, GDP, residence permits,
# crime (all Eurostat) + terrorism (optional GTD). Annual/quarterly series are
# broadcast to monthly; 3m/6m rolling means added for the monthly indicators.
# -----------------------------------------------------------------------------

source("config.R")
library(slider); library(eurostat); library(countrycode); library(haven); library(readxl)
source("R/helper_macrodata.R")   # defines fetch_eurostat / get_population / per_100k

safe_mean <- function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
permit_vars <- c("total_permit_stock","permit_stock_work","permit_stock_family",
  "permit_stock_study","permit_stock_refugee","permit_stock_ukraine","permit_stock_other",
  "total_permit_first","permit_first_work","permit_first_family","permit_first_study",
  "permit_first_refugee_ukraine_other")
gdp_quarterly_vars <- c("gdp_per_cap","gdp","gdp_per_cap_growth","gdp_growth")

message("Fetching Eurostat indicators (this calls the Eurostat API)...")
source("R/macro/asylum_macro.R")
source("R/macro/gdp_macro.R")
source("R/macro/permit_macro.R")
source("R/macro/unemployment_macro.R")
source("R/macro/inflation_macro.R")
source("R/macro/terrorisme_macro.R")
source("R/macro/crime_macro.R")

# Restrict to countries we actually analyse (microdata set if available, else EU_SET).
sel_countries <- if (file.exists(file.path(DIR_DATA, "core_micro.rds"))) {
  unique(readRDS(file.path(DIR_DATA, "core_micro.rds"))$country_code)
} else EU_SET

core_macro <- unemployment_macro %>%
  left_join(inflation_macro, by = c("date", "country_code")) %>%
  left_join(asylum_macro, by = c("date", "country_code")) %>%
  left_join(globalterrorism_macro, by = c("date", "country_code")) %>%
  left_join(macro_permit_stock, by = c("date", "country_code")) %>%
  left_join(macro_permit_first, by = c("date", "country_code")) %>%
  left_join(gdp_per_cap_macro, by = c("date", "country_code")) %>%
  left_join(gdp_macro, by = c("date", "country_code")) %>%
  left_join(crime_macro, by = c("date", "country_code")) %>%
  mutate(country_code = if_else(country_code == "GB", "UK", country_code)) %>%
  mutate(country = countrycode(country_code, "iso2c", "country.name"),
         country = if_else(country_code == "EU27_2020", "European Union", country)) %>%
  filter(!is.na(country)) %>%
  group_by(country_code) %>%
  arrange(date) %>%
  mutate(
    across(c(unemp_rate, inflation_rate, energy_rate, asylum_rate),
           list(`3m` = ~ slider::slide_dbl(.x, mean, .before = 2, .complete = TRUE),
                `6m` = ~ slider::slide_dbl(.x, mean, .before = 5, .complete = TRUE)),
           .names = "{.col}_{.fn}"),
    year = year(date), quarter = quarter(date)
  ) %>%
  rename_with(~ str_replace(.x, "_rate_", "_"), matches("_rate_(3m|6m)$")) %>%
  filter(year >= 2001) %>%
  group_by(country_code, year) %>%
  mutate(across(any_of(permit_vars), ~ safe_mean(.x))) %>%
  ungroup() %>%
  group_by(country_code, year, quarter) %>%
  mutate(across(any_of(gdp_quarterly_vars), ~ safe_mean(.x))) %>%
  ungroup() %>%
  filter(country_code %in% sel_countries)

saveRDS(core_macro, file.path(DIR_DATA, "core_macro.rds"))
message("Built core_macro: ", nrow(core_macro), " country-months, ",
        n_distinct(core_macro$country_code), " countries, ",
        format(min(core_macro$date)), " to ", format(max(core_macro$date)), ".")
