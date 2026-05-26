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
library(sandwich); library(lmtest); library(slider)

macro <- readRDS(file.path(DIR_DATA, "core_macro.rds")) %>%
  mutate(crime_per_100k = {
    allna <- is.na(homicide_per_100k) & is.na(robbery_per_100k) & is.na(burglary_per_100k)
    ifelse(allna, NA_real_, rowSums(cbind(homicide_per_100k, robbery_per_100k, burglary_per_100k), na.rm = TRUE))
  })

# Monthly indicators: trailing 3-month average (the survey month + the 2 before),
# matched to each survey wave. Crime is annual (published yearly) so it uses
# annual means. See ISSUE_MACRO$monthly.
monthly_vars <- ISSUE_MACRO$macro_var[ISSUE_MACRO$monthly]
macro <- macro %>% arrange(country_code, date) %>% group_by(country_code) %>%
  mutate(across(all_of(monthly_vars),
                ~ slider::slide_dbl(.x, mean, .before = 2, .complete = TRUE), .names = "{.col}_3m")) %>%
  ungroup()

# wave-level national-context salience
sal_wave <- readr::read_csv(file.path(DIR_DATA, "salience_contexts.csv"), show_col_types = FALSE) %>%
  filter(context == "cntry", country_code != "EU") %>% select(issue, country_code, date, pct)

# annual versions (for the crime pair)
macro_ann <- macro %>% mutate(year = lubridate::year(date)) %>%
  group_by(country_code, year) %>%
  summarise(across(all_of(unique(ISSUE_MACRO$macro_var)),
                   ~ if (all(is.na(.x))) NA_real_ else mean(.x, na.rm = TRUE)), .groups = "drop")
sal_ann <- sal_wave %>% mutate(year = lubridate::year(date)) %>%
  group_by(issue, country_code, year) %>% summarise(pct = mean(pct, na.rm = TRUE), .groups = "drop")

results <- list(); add <- function(...) results[[length(results) + 1]] <<- tibble(...)

regions <- list("All Europe"               = setdiff(EU_SET, "EU"),
                "Western Europe"           = WEST_EU,
                "Central & Eastern Europe" = EAST_EU)

for (i in seq_len(nrow(ISSUE_MACRO))) {
  m <- ISSUE_MACRO[i, ]
  if (m$monthly) {
    # wave-level: salience at each survey month vs trailing 3-month indicator
    dat0 <- sal_wave %>% filter(issue == m$issue) %>% select(country_code, date, pct) %>%
      inner_join(macro %>% select(country_code, date, mv = all_of(paste0(m$macro_var, "_3m"))),
                 by = c("country_code", "date")) %>% filter(is.finite(pct), is.finite(mv))
  } else {
    # crime: annual
    dat0 <- sal_ann %>% filter(issue == m$issue) %>% select(country_code, year, pct) %>%
      inner_join(macro_ann %>% select(country_code, year, mv = all_of(m$macro_var)),
                 by = c("country_code", "year")) %>% filter(is.finite(pct), is.finite(mv))
  }

  for (rg in names(regions)) {
    dat <- dat0 %>% filter(country_code %in% regions[[rg]])
    z <- dat %>% group_by(country_code) %>% filter(n() >= 4) %>%
      mutate(zp = zscore(pct), zm = zscore(mv)) %>% ungroup() %>% filter(is.finite(zp), is.finite(zm))
    if (nrow(z) < 10) next
    nc <- n_distinct(z$country_code)

    ctp <- tryCatch(cor.test(z$zp, z$zm), error = function(e) NULL)
    rs  <- suppressWarnings(cor(z$zp, z$zm, method = "spearman"))
    if (!is.null(ctp)) add(region = rg, issue = m$issue, macro = m$macro_var, method = "within_country_pearson",
        estimate = unname(ctp$estimate), ci_low = ctp$conf.int[1], ci_high = ctp$conf.int[2], n = nrow(z), nc = nc)
    add(region = rg, issue = m$issue, macro = m$macro_var, method = "within_country_spearman",
        estimate = rs, ci_low = NA_real_, ci_high = NA_real_, n = nrow(z), nc = nc)

    if (rg == "All Europe") {
      fe <- tryCatch({
        fit <- lm(pct ~ mv + factor(country_code), data = dat)
        coeftest(fit, vcov = vcovCL(fit, cluster = ~ country_code))["mv", ]
      }, error = function(e) NULL)
      if (!is.null(fe)) add(region = rg, issue = m$issue, macro = m$macro_var, method = "panel_fe_levels",
          estimate = fe["Estimate"], ci_low = fe["Estimate"] - 1.96 * fe["Std. Error"],
          ci_high = fe["Estimate"] + 1.96 * fe["Std. Error"], n = nrow(dat), nc = n_distinct(dat$country_code))
    }
  }
}

correlations <- bind_rows(results) %>%
  left_join(ISSUE_MACRO %>% select(issue, macro = macro_var, macro_label), by = c("issue", "macro"))
readr::write_csv(correlations, file.path(DIR_DATA, "correlations.csv"))
message("Wrote data/correlations.csv (", nrow(correlations), " rows)")
print(correlations %>% filter(method == "within_country_pearson") %>%
        transmute(issue, region, r = round(estimate, 2)) %>%
        tidyr::pivot_wider(names_from = region, values_from = r) %>% as.data.frame())
