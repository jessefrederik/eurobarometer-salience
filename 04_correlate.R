# 04_correlate.R
# -----------------------------------------------------------------------------
# Relate national-context problem perceptions to real-world macro variables.
# Three complementary methods per issue<->macro pair (config.R ISSUE_MACRO):
#   (i)   pooled correlation of per-country z-scored series
#   (ii)  panel fixed-effects (country dummies), cluster-robust SE — levels & changes
#   (iii) individual-level multilevel logit (glmer) for unemployment salience
# Output: data/correlations.csv (issue, macro, method, estimate, se, ci_low/high, n)
# -----------------------------------------------------------------------------

source("config.R")
source("R/utils.R")
library(sandwich); library(lmtest)

salience <- readr::read_csv(file.path(DIR_DATA, "salience_contexts.csv"), show_col_types = FALSE) %>%
  filter(context == "cntry", country_code != "EU")
macro <- readRDS(file.path(DIR_DATA, "core_macro.rds"))

results <- list()
add <- function(...) results[[length(results) + 1]] <<- tibble(...)

for (i in seq_len(nrow(ISSUE_MACRO))) {
  m   <- ISSUE_MACRO[i, ]
  if (!m$macro_var %in% names(macro)) next
  dat <- salience %>%
    filter(issue == m$issue) %>%
    select(country_code, date, pct) %>%
    inner_join(macro %>% select(country_code, date, mv = all_of(m$macro_var)),
               by = c("country_code", "date")) %>%
    filter(!is.na(pct), !is.na(mv))
  if (nrow(dat) < 30) next

  # (i) pooled correlation of per-country z-scores
  z <- dat %>% group_by(country_code) %>% filter(n() >= 4) %>%
    mutate(zp = zscore(pct), zm = zscore(mv)) %>% ungroup() %>%
    filter(is.finite(zp), is.finite(zm))
  if (nrow(z) >= 10) {
    ct <- suppressWarnings(cor.test(z$zp, z$zm))
    add(issue = m$issue, macro = m$macro_var, method = "within_country_cor",
        estimate = unname(ct$estimate), se = NA_real_,
        ci_low = ct$conf.int[1], ci_high = ct$conf.int[2], n = nrow(z))
  }

  # (ii) panel FE, levels (country dummies + cluster-robust SE)
  fe <- tryCatch({
    fit <- lm(pct ~ mv + factor(country_code), data = dat)
    coeftest(fit, vcov = vcovCL(fit, cluster = ~ country_code))["mv", ]
  }, error = function(e) NULL)
  if (!is.null(fe)) add(issue = m$issue, macro = m$macro_var, method = "panel_fe_levels",
      estimate = fe["Estimate"], se = fe["Std. Error"],
      ci_low = fe["Estimate"] - 1.96 * fe["Std. Error"],
      ci_high = fe["Estimate"] + 1.96 * fe["Std. Error"], n = nrow(dat))

  # (ii) panel FE, first differences (half-year) within country
  ch <- dat %>% arrange(country_code, date) %>% group_by(country_code) %>%
    mutate(d_pct = pct - lag(pct), d_mv = mv - lag(mv)) %>% ungroup() %>%
    filter(!is.na(d_pct), !is.na(d_mv))
  fec <- tryCatch({
    fit <- lm(d_pct ~ d_mv + factor(country_code), data = ch)
    coeftest(fit, vcov = vcovCL(fit, cluster = ~ country_code))["d_mv", ]
  }, error = function(e) NULL)
  if (!is.null(fec)) add(issue = m$issue, macro = m$macro_var, method = "panel_fe_changes",
      estimate = fec["Estimate"], se = fec["Std. Error"],
      ci_low = fec["Estimate"] - 1.96 * fec["Std. Error"],
      ci_high = fec["Estimate"] + 1.96 * fec["Std. Error"], n = nrow(ch))
}

# (iii) individual-level multilevel logit for unemployment salience
micro_path <- file.path(DIR_DATA, "core_micro.rds")
if (file.exists(micro_path) && requireNamespace("lme4", quietly = TRUE)) {
  message("Fitting glmer for unemployment salience...")
  core <- readRDS(micro_path) %>%
    inner_join(macro, by = c("country_code", "date")) %>%
    filter(n_issues == 2) %>%
    mutate(across(c(unemp_rate, gdp_per_cap_growth, inflation_rate, energy_rate),
                  ~ as.numeric(scale(.x)), .names = "{.col}_s"))
  fit <- tryCatch(lme4::glmer(
    unemployment ~ unemp_rate_s + gdp_per_cap_growth_s + inflation_rate_s + energy_rate_s + (1 | country_code),
    data = core, family = binomial("logit"), weights = weight,
    control = lme4::glmerControl(optimizer = "bobyqa")), error = function(e) { message("  glmer failed: ", e$message); NULL })
  if (!is.null(fit)) {
    co <- summary(fit)$coefficients
    for (term in rownames(co)[-1]) add(
      issue = "unemployment", macro = sub("_s$", "", term), method = "glmer_logit",
      estimate = co[term, "Estimate"], se = co[term, "Std. Error"],
      ci_low = co[term, "Estimate"] - 1.96 * co[term, "Std. Error"],
      ci_high = co[term, "Estimate"] + 1.96 * co[term, "Std. Error"], n = nrow(core))
  }
}

correlations <- bind_rows(results)
readr::write_csv(correlations, file.path(DIR_DATA, "correlations.csv"))
message("Wrote data/correlations.csv: ", nrow(correlations), " rows.")
print(correlations %>% filter(method == "panel_fe_levels") %>%
        select(issue, macro, estimate, se, n))
