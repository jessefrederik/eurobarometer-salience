# 04_correlate.R
# -----------------------------------------------------------------------------
# Relate national-context problem perceptions to the real-world variable each
# issue should plausibly respond to (config.R ISSUE_MACRO):
#   unemployment ~ unemployment rate | inflation ~ HICP | energy ~ HICP energy
#   immigration ~ asylum applications | crime ~ recorded crime per 100k
#
# Correlations are computed at ANNUAL resolution (crime statistics are annual;
# annualising the others keeps the five comparable) and WITHIN country, so they
# describe over-time co-movement, not cross-country level differences. Methods:
#   - Pearson correlation of per-country z-scores (95% CI)
#   - Spearman (rank) correlation — robust to the skew/spikes in the rates
#   - panel fixed-effects slope (country dummies, cluster-robust SE)
# Output: data/correlations.csv
# -----------------------------------------------------------------------------

source("config.R"); source("R/utils.R")
library(sandwich); library(lmtest)

macro <- readRDS(file.path(DIR_DATA, "core_macro.rds")) %>%
  mutate(crime_per_100k = {
    allna <- is.na(homicide_per_100k) & is.na(robbery_per_100k) & is.na(burglary_per_100k)
    ifelse(allna, NA_real_, rowSums(cbind(homicide_per_100k, robbery_per_100k, burglary_per_100k), na.rm = TRUE))
  })

# annual means per country
macro_ann <- macro %>% mutate(year = lubridate::year(date)) %>%
  group_by(country_code, year) %>%
  summarise(across(all_of(unique(ISSUE_MACRO$macro_var)),
                   ~ if (all(is.na(.x))) NA_real_ else mean(.x, na.rm = TRUE)), .groups = "drop")
sal_ann <- readr::read_csv(file.path(DIR_DATA, "salience_contexts.csv"), show_col_types = FALSE) %>%
  filter(context == "cntry", country_code != "EU") %>%
  mutate(year = lubridate::year(date)) %>%
  group_by(issue, country_code, year) %>% summarise(pct = mean(pct, na.rm = TRUE), .groups = "drop")

results <- list(); add <- function(...) results[[length(results) + 1]] <<- tibble(...)

for (i in seq_len(nrow(ISSUE_MACRO))) {
  m <- ISSUE_MACRO[i, ]
  dat <- sal_ann %>% filter(issue == m$issue) %>% select(country_code, year, pct) %>%
    inner_join(macro_ann %>% select(country_code, year, mv = all_of(m$macro_var)),
               by = c("country_code", "year")) %>%
    filter(is.finite(pct), is.finite(mv))
  z <- dat %>% group_by(country_code) %>% filter(n() >= 4) %>%
    mutate(zp = zscore(pct), zm = zscore(mv)) %>% ungroup() %>% filter(is.finite(zp), is.finite(zm))
  if (nrow(z) < 10) { message("skip ", m$issue, " (n=", nrow(z), ")"); next }
  nc <- n_distinct(z$country_code)

  ctp <- tryCatch(cor.test(z$zp, z$zm), error = function(e) NULL)
  rs  <- suppressWarnings(cor(z$zp, z$zm, method = "spearman"))
  if (!is.null(ctp)) add(issue = m$issue, macro = m$macro_var, method = "within_country_pearson",
      estimate = unname(ctp$estimate), ci_low = ctp$conf.int[1], ci_high = ctp$conf.int[2], n = nrow(z), nc = nc)
  add(issue = m$issue, macro = m$macro_var, method = "within_country_spearman",
      estimate = rs, ci_low = NA_real_, ci_high = NA_real_, n = nrow(z), nc = nc)

  fe <- tryCatch({
    fit <- lm(pct ~ mv + factor(country_code), data = dat)
    coeftest(fit, vcov = vcovCL(fit, cluster = ~ country_code))["mv", ]
  }, error = function(e) NULL)
  if (!is.null(fe)) add(issue = m$issue, macro = m$macro_var, method = "panel_fe_levels",
      estimate = fe["Estimate"], ci_low = fe["Estimate"] - 1.96 * fe["Std. Error"],
      ci_high = fe["Estimate"] + 1.96 * fe["Std. Error"], n = nrow(dat), nc = n_distinct(dat$country_code))
}

correlations <- bind_rows(results) %>%
  left_join(ISSUE_MACRO %>% select(issue, macro = macro_var, macro_label), by = c("issue", "macro"))
readr::write_csv(correlations, file.path(DIR_DATA, "correlations.csv"))
message("Wrote data/correlations.csv (", nrow(correlations), " rows)")
print(correlations %>% filter(method != "panel_fe_levels") %>%
        transmute(issue, method = sub("within_country_", "", method), estimate = round(estimate, 2), n, nc) %>%
        as.data.frame())
