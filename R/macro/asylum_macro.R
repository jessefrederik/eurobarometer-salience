if (!exists("fetch_eurostat")) source("R/helper_macrodata.R")

library(readxl)

# Eurostat asylum applications (two datasets: legacy decisions + recent first-time
# applications), normalised per 100k population. Excludes UK.
asylum_2007 <- fetch_eurostat("migr_asyctzm") %>%
  filter(citizen == "TOTAL") %>%
  select(country_code, date, values)

asylum_2025 <- fetch_eurostat("migr_asyappctzm",
  filters = list(sex = "T", citizen = "TOTAL", age = "TOTAL", applicant = "FRST")
) %>%
  select(country_code, date, values) %>%
  mutate(date = as.Date(paste0(date, "-01")))

asylum_all <- asylum_2007 %>%
  full_join(asylum_2025, by = c("country_code", "date", "values")) %>%
  filter(country_code != "UK")

# Optional UK supplement (quarterly claims). See README to enable.
uk_file <- file.path(DIR_EXTERNAL, "asylum_uk.xlsx")
if (file.exists(uk_file)) {
  asylum_uk <- read_excel(uk_file, sheet = "Data_Asy_D01", skip = 1) %>%
    group_by(Quarter) %>%
    summarise(total_asylum = sum(Claims, na.rm = TRUE), .groups = "drop") %>%
    mutate(
      date = as.Date(case_when(
        str_detect(Quarter, "Q1") ~ paste0(substr(Quarter, 1, 4), "-01-01"),
        str_detect(Quarter, "Q2") ~ paste0(substr(Quarter, 1, 4), "-04-01"),
        str_detect(Quarter, "Q3") ~ paste0(substr(Quarter, 1, 4), "-07-01"),
        str_detect(Quarter, "Q4") ~ paste0(substr(Quarter, 1, 4), "-10-01")
      )),
      country_code = "UK"
    ) %>%
    select(date, country_code, values = total_asylum)
  asylum_all <- full_join(asylum_all, asylum_uk, by = c("country_code", "date", "values"))
} else {
  message("  [optional] ", uk_file, " absent — UK asylum left NA")
}

asylum_macro <- asylum_all %>%
  per_100k("values", "asylum_rate") %>%
  select(date, country_code, asylum_rate)
