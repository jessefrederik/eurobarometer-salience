# Requires: eurostat, tidyverse (loaded by core_macro.R)

#' Fetch a Eurostat dataset with standardized column names
#'
#' Wraps `eurostat::get_eurostat()`, renaming `time`/`TIME_PERIOD` to `date`
#' and `geo` to `country_code`. Coerces date to Date class and optionally
#' filters by minimum year.
#'
#' @param dataset_id Eurostat dataset ID (e.g. `"une_rt_m"`).
#' @param filters Named list of filter values passed to `get_eurostat()`.
#' @param min_year Optional minimum year to keep (inclusive).
#' @return A tibble with standardized `date` and `country_code` columns.
fetch_eurostat <- function(dataset_id, filters = list(), min_year = NULL) {
  df <- eurostat::get_eurostat(dataset_id, filters = filters)

  # Normalise date column: Eurostat uses 'time' or 'TIME_PERIOD'
  if ("TIME_PERIOD" %in% names(df) && !"date" %in% names(df)) {
    df <- df %>% rename(date = TIME_PERIOD)
  } else if ("time" %in% names(df) && !"date" %in% names(df)) {
    df <- df %>% rename(date = time)
  }

  # Normalise geo → country_code
  if ("geo" %in% names(df)) {
    df <- df %>% rename(country_code = geo)
  }

  df <- df %>% mutate(date = as.Date(date))

  if (!is.null(min_year)) {
    df <- df %>% filter(year(date) >= min_year)
  }

  df
}

# Session-cached population data (avoids duplicate API calls)
.population_cache <- new.env(parent = emptyenv())

#' Get annual population data from Eurostat (session-cached)
#'
#' Loads `demo_pjan` (total population, both sexes, all ages) via
#' [fetch_eurostat()]. Results are cached in a session-level environment
#' to avoid duplicate API calls when sourced by multiple macro scripts.
#'
#' @param min_year Minimum year to keep (default 2000).
#' @return A tibble with columns `country_code`, `date`, `population`.
get_population <- function(min_year = 2000) {
  cache_key <- as.character(min_year)
  if (!is.null(.population_cache[[cache_key]])) {
    return(.population_cache[[cache_key]])
  }

  pop <- fetch_eurostat("demo_pjan",
    filters = list(sex = "T", age = "TOTAL", freq = "A"),
    min_year = min_year
  ) %>%
    select(country_code, date, population = values)

  .population_cache[[cache_key]] <- pop
  pop
}

#' Compute per-100k rate by joining population and forward-filling
#'
#' Joins annual population data (via [get_population()]) onto `df`,
#' forward/backward fills gaps, and computes `value_col / population * 100000`.
#'
#' @param df Data frame with `country_code`, `date`, and a values column.
#' @param value_col Name (string) of the column containing raw counts.
#' @param rate_col Name (string) for the new per-100k rate column.
#' @param min_year Minimum year for population data (default 2000).
#' @return The input data frame with `population` and the new rate column added.
per_100k <- function(df, value_col, rate_col, min_year = 2000) {
  pop <- get_population(min_year)

  df %>%
    full_join(pop, by = c("country_code", "date")) %>%
    arrange(country_code, date) %>%
    group_by(country_code) %>%
    tidyr::fill(population, .direction = "downup") %>%
    ungroup() %>%
    mutate(!!rate_col := !!sym(value_col) / population * 100000)
}
