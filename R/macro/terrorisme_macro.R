if (!exists("fetch_eurostat")) source("R/helper_macrodata.R")

library(readxl)
library(countrycode)

# Terrorism deaths come from the Global Terrorism Database, which is NOT openly
# auto-downloadable (registration required). Optional: if the file is absent we
# emit an empty frame so the left-join in core_macro still works. See README.
gtd_file <- file.path(DIR_EXTERNAL, "globalterrorismdatabase.xlsx")

if (file.exists(gtd_file)) {
  gtd <- read_excel(gtd_file, sheet = "Data") %>%
    mutate(date = floor_date(as.Date(paste0(iyear, "-", imonth, "-", iday)), "month"))

  gtd_national <- gtd %>%
    filter(str_detect(region_txt, "Western Europe")) %>%
    group_by(date, country_txt) %>%
    summarise(terror_national = sum(nkill, na.rm = TRUE), .groups = "drop") %>%
    filter(year(date) >= 2000)

  gtd_western <- gtd %>%
    filter(str_detect(region_txt, "North America|Western Europe")) %>%
    group_by(date) %>%
    summarise(terror_western = sum(nkill, na.rm = TRUE), .groups = "drop") %>%
    filter(year(date) >= 2000)

  globalterrorism_macro <- full_join(gtd_western, gtd_national, by = "date") %>%
    mutate(country_code = countrycode(country_txt, "country.name", "iso2c")) %>%
    select(date, country_code, terror_national, terror_western)
} else {
  message("  [optional] ", gtd_file, " absent — terrorism macro skipped")
  globalterrorism_macro <- tibble(
    date = as.Date(character()), country_code = character(),
    terror_national = numeric(), terror_western = numeric()
  )
}
