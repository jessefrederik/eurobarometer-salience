if (!exists("fetch_eurostat")) source("R/helper_macrodata.R")

crime_rate_2007 <- fetch_eurostat("crim_gen",
  filters = list(iccs = c("ICCS0101", "ICCS0401", "ICCS05012"))
) %>%
  pivot_wider(names_from = iccs, values_from = values) %>%
  select(date, country_code, homicide = ICCS0101, robbery = ICCS0401, burglary = ICCS05012)

crime_rate_2024 <- fetch_eurostat("crim_off_cat",
  filters = list(unit = "NR", iccs = c("ICCS0101", "ICCS0401", "ICCS05012"))
) %>%
  pivot_wider(names_from = iccs, values_from = values) %>%
  select(date, country_code, homicide = ICCS0101, robbery = ICCS0401, burglary = ICCS05012)

population <- get_population(min_year = 1993)

crime_macro <- full_join(crime_rate_2007, crime_rate_2024,
    by = c("date", "country_code", "homicide", "robbery", "burglary")) %>%
  full_join(population, by = c("country_code", "date")) %>%
  mutate(
    homicide_per_100k = homicide / population * 100000,
    robbery_per_100k  = robbery / population * 100000,
    burglary_per_100k = burglary / population * 100000
  ) %>%
  select(date, country_code, homicide_per_100k, robbery_per_100k, burglary_per_100k) %>%
  filter(year(date) >= 2001)
