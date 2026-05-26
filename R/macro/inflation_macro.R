if (!exists("fetch_eurostat")) source("R/helper_macrodata.R")

inflation_macro <- fetch_eurostat("prc_hicp_manr",
  filters = list(coicop = c("CP00", "NRG")),
  min_year = 2001
) %>%
  pivot_wider(names_from = coicop, values_from = values) %>%
  select(date, country_code, inflation_rate = CP00, energy_rate = NRG)
