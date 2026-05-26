if (!exists("fetch_eurostat")) source("R/helper_macrodata.R")

gdp_macro <- fetch_eurostat("namq_10_gdp",
  filters = list(unit = "CLV20_MEUR", s_adj = "SCA", na_item = "B1GQ"),
  min_year = 2000
) %>%
  group_by(country_code) %>%
  arrange(country_code, date) %>%
  mutate(gdp_growth = (values / lag(values, 4) - 1) * 100) %>%
  ungroup() %>%
  select(date, country_code, gdp = values, gdp_growth)

gdp_per_cap_macro <- fetch_eurostat("namq_10_pc") %>%
  filter(unit == "CLV20_EUR_HAB",
         s_adj == "NSA",
         na_item == "B1GQ") %>%
  group_by(country_code) %>%
  arrange(country_code, date) %>%
  mutate(gdp_per_cap_growth = (values / lag(values, 4) - 1) * 100) %>%
  ungroup() %>%
  select(date, country_code, gdp_per_cap = values, gdp_per_cap_growth)
