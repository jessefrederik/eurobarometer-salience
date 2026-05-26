# 02_build_contexts.R
# -----------------------------------------------------------------------------
# Produce the tidy three-context salience series for every configured issue:
#   data/salience_contexts.csv  (issue, country_code, date, context, pct, n, source)
# Steps: extract per-respondent issue x context dummies from the microdata,
# aggregate to weighted % by country/date/context, add the pooled EU panel, and
# append the latest EC open-volume waves after the microdata boundary.
# -----------------------------------------------------------------------------

source("config.R")
source("R/context_extract.R")
source("R/utils.R")

scaffold_path <- file.path(DIR_DATA, "scaffold.rds")
use_gesis <- file.exists(scaffold_path) &&
  length(list.files(DATA_ROOT, pattern = "\\.rds$")) > 0

micro <- tibble(country_code = character(), date = as.Date(character()),
                context = character(), issue = character(),
                pct = numeric(), n = integer())

if (use_gesis) {
  scaffold <- readRDS(scaffold_path)
  files <- list.files(DATA_ROOT, pattern = "\\.rds$", full.names = TRUE)

  # Cache the (slow) raw extraction so re-runs only redo the cheap aggregation.
  raw_cache <- file.path(DIR_DATA, "contexts_raw.rds")
  if (file.exists(raw_cache)) {
    message("Loading cached context extraction (delete ", raw_cache, " to rebuild)")
    ctx <- readRDS(raw_cache)
  } else {
    message("Extracting issue x context dummies from ", length(files), " waves...")
    ctx <- extract_all_contexts(files, issue_specs)
    saveRDS(ctx, raw_cache)
  }

  panel <- ctx %>%
    inner_join(scaffold, by = c("study", "id")) %>%
    filter(!is.na(value), !is.na(date))

  by_country <- panel %>%
    group_by(issue, country_code, date, context) %>%
    summarise(pct = 100 * weighted.mean(value, weight, na.rm = TRUE),
              n = n(), .groups = "drop") %>%
    filter(n >= 50)

  eu_panel <- panel %>%
    mutate(w_eu = coalesce(weight_eu27, weight)) %>%
    group_by(issue, date, context) %>%
    summarise(pct = 100 * weighted.mean(value, w_eu, na.rm = TRUE),
              n = n(), .groups = "drop") %>%
    filter(n >= 200) %>%
    mutate(country_code = "EU")

  micro <- bind_rows(by_country, eu_panel)
} else {
  message("No microdata scaffold — building EC-only salience (recent waves).")
}
micro <- micro %>% mutate(source = "microdata")

# --- Append EC open-volume waves after the microdata boundary (per issue) -----
ec_file <- file.path(DIR_DATA, "ec_salience.csv")
ec_rows <- tibble()
if (file.exists(ec_file)) {
  ec <- readr::read_csv(ec_file, show_col_types = FALSE)
  bounds <- micro %>% group_by(issue) %>% summarise(micro_max = max(date), .groups = "drop")
  ec_rows <- ec %>%
    left_join(bounds, by = "issue") %>%
    filter(is.na(micro_max) | date > micro_max) %>%
    transmute(issue, country_code, date, context, pct, n = NA_integer_, source = "ec_volume")
  message("Appending ", nrow(ec_rows), " EC rows.")
}

salience_contexts <- bind_rows(micro, ec_rows) %>%
  filter(country_code %in% EU_SET) %>%
  arrange(issue, country_code, context, date)

readr::write_csv(salience_contexts, file.path(DIR_DATA, "salience_contexts.csv"))
message("Wrote data/salience_contexts.csv: ", nrow(salience_contexts), " rows, ",
        n_distinct(salience_contexts$issue), " issues, ",
        n_distinct(salience_contexts$country_code), " countries.")
