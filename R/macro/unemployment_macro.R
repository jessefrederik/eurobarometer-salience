if (!exists("fetch_eurostat")) source("R/helper_macrodata.R")

# Eurostat monthly unemployment rate (excludes UK).
unemployment_rate <- fetch_eurostat("une_rt_m",
  filters = list(sex = "T", age = "TOTAL", s_adj = "SA", unit = "PC_ACT", freq = "M"),
  min_year = 2001
) %>%
  select(date, country_code, values) %>%
  filter(!country_code %in% c("UK", "GB"))

# Optional UK supplement (Eurostat drops the UK). See README to enable.
uk_file <- file.path(DIR_EXTERNAL, "UK_unemployment.csv")
if (file.exists(uk_file)) {
  uk_unemployment_rate <- read.csv(uk_file) %>%
    mutate(
      date = as.Date(parse_date_time(date, orders = "%d/%m/%Y")),
      values = as.numeric(gsub(",", ".", values)),
      country_code = "GB"
    ) %>%
    select(date, country_code, values)
  unemployment_rate <- full_join(unemployment_rate, uk_unemployment_rate,
                                 by = c("date", "country_code", "values"))
} else {
  message("  [optional] ", uk_file, " absent — UK unemployment left NA")
}

unemployment_macro <- unemployment_rate %>%
  arrange(country_code, date) %>%
  select(date, country_code, unemp_rate = values)
