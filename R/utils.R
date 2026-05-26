# R/utils.R — small shared helpers for aggregation, scaling, and labelling.
# Requires: dplyr, countrycode (loaded by callers).

# Map ISO2c country_code -> display name, with the project's EL/UK/EU overrides.
country_label <- function(code) {
  dplyr::case_when(
    code == "EU" ~ "European Union",
    code == "UK" ~ "United Kingdom",
    code == "EL" ~ "Greece",
    TRUE ~ countrycode::countrycode(code, "iso2c", "country.name", warn = FALSE)
  )
}

# Per-country z-standardisation (mean 0, sd 1). Returns numeric vector.
zscore <- function(x) as.numeric(scale(x))

# Min-max rescale to [0, 100] (used for side-by-side salience/macro panels).
rescale01 <- function(x) {
  r <- range(x, na.rm = TRUE)
  if (!is.finite(diff(r)) || diff(r) == 0) return(rep(NA_real_, length(x)))
  (x - r[1]) / diff(r) * 100
}

# Weighted % of a 0/1 dummy by grouping vars. `data` must have `weight`.
weighted_pct <- function(data, value_col, ...) {
  data %>%
    dplyr::group_by(...) %>%
    dplyr::summarise(
      pct = 100 * stats::weighted.mean({{ value_col }}, weight, na.rm = TRUE),
      n   = dplyr::n(),
      .groups = "drop"
    )
}
