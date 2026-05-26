library(tidyverse)
library(haven)
library(retroharmonize)

source('R/function_metadata.R')
source('R/function_selectRDS.R')
source('R/function_clean_dates.R')
source('R/regex_issues.R')
source('R/harmonize_issues.R')

### LADEN META DATA

DATA_ROOT <- Sys.getenv(
  "EB_DATA_ROOT",
  unset = file.path(Sys.getenv("HOME"), "Dropbox/GitHub/Eurobarometer/datafiles/Eurobarometer_individual")
)
folder_path <- DATA_ROOT
eb_meta <- eb_metadata_all(folder_path, chunk_size = 10)

eb_meta <-eb_meta %>%
  mutate(
    filename   = basename(filename),
    label_clean = str_squish(str_replace_all(label_orig, "_|\\.|\\s+", " ")),
    label_std   = harmonize_issue(label_clean)
  )

## LADEN EN FILTEREN DATA

eb_original <- load_filtered_rds(folder_path, eb_meta) %>% 
  dplyr::group_by(study) %>%
  dplyr::mutate(id = dplyr::row_number())


core_micro <- eb_original %>%
  mutate(
    interview_date = ifelse(interview_date == "Data not available", NA, interview_date),
    country_code = case_when(
      country_code == "DE-E" ~ "DE",       # East/West Germany: strata of one country
      country_code == "DE-W" ~ "DE",
      country_code == "GB-GBN" ~ "GB",      # Great Britain + Northern Ireland = UK
      country_code == "GB-NIR" ~ "GB",
      country_code == "RS-KM" ~ "RS",
      # NB: CY-TCC (Turkish-Cypriot Community) is kept SEPARATE, not merged into CY.
      # It is a distinct population with near-zero immigration salience; merging it
      # halved Cyprus's salience on every issue. The Commission (EC volumes) and the
      # EUI charts both report CY (Republic) separately from CY-TCC. CY-TCC then falls
      # outside `eu_set` and is excluded from the country panels.
      TRUE ~ country_code
    )
  ) %>%
  apply_date_corrections() %>%
  mutate(interview_date_parsed = clean_interview_date(interview_date)) %>%
  group_by(country_code, study) %>%
  mutate(
    modal_date = stat_mode_unique(interview_date_parsed),
    interview_date_parsed = if_else(
      is.na(interview_date_parsed),
      modal_date,
      interview_date_parsed
    )
  ) %>%
  ungroup() %>%
  mutate(
    weight_united_germany = ifelse(weight_united_germany == 0, NA, weight_united_germany),
    weight = coalesce(
      weight_united_germany,
      weight_target,
      weight_w1,
      weight_eu,
      weight_redressment,
      1
    ),
    country_code = case_when(
      country_code == "GB" ~ "UK",
      country_code == "GR" ~ "EL",
      TRUE ~ country_code
    )
  ) %>%
  mutate(across(any_of(canonical_levels), ~ replace(.x, .x > 1, 0))) %>%
  mutate(
    n_issues = rowSums(across(any_of(canonical_levels)), na.rm = TRUE),
    sum_correct = if_else(n_issues == 2, 1, 0)
  ) %>%
  select(
    id,
    study,
    age,
    gender,
    interview_date,
    date_parsed = interview_date_parsed,
    date = modal_date,
    country_code,
    weight,
    weight_eu27,
    any_of(canonical_levels),
    sum_correct,
    n_issues
  ) %>% 
  group_by(study,country_code) %>%
  mutate(date = floor_date(max(date), "month")) %>% 
  ungroup()



