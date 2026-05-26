# 06_plot_correlations.R
# -----------------------------------------------------------------------------
# (a) Per issue<->macro pair: faceted overlay of the z-scored problem perception
#     (national context) and the z-scored real-world variable, by country.
#     -> output/correlation_overlay_<issue>_<macro>.png
# (b) Summary: forest plot of the within-country correlation (with 95% CI)
#     for every issue<->macro pair. -> output/correlation_summary.png
# -----------------------------------------------------------------------------

source("config.R")
source("R/utils.R")
library(countrycode)

salience <- readr::read_csv(file.path(DIR_DATA, "salience_contexts.csv"), show_col_types = FALSE) %>%
  filter(context == "cntry", country_code %in% EU_SET, country_code != "EU")
macro <- readRDS(file.path(DIR_DATA, "core_macro.rds"))
corr  <- readr::read_csv(file.path(DIR_DATA, "correlations.csv"), show_col_types = FALSE)

survey_col <- "#867abd"; macro_col <- "#df5b57"

# --- (a) overlay facets per pair ---------------------------------------------
overlay <- function(iss, mv, lab) {
  if (!mv %in% names(macro)) return(invisible(NULL))
  d <- salience %>% filter(issue == iss) %>% select(country_code, date, pct) %>%
    inner_join(macro %>% select(country_code, date, mval = all_of(mv)), by = c("country_code", "date")) %>%
    filter(!is.na(pct), !is.na(mval)) %>%
    group_by(country_code) %>% filter(n() >= 4) %>%
    mutate(`Problem perception (survey)` = zscore(pct),
           `Real-world indicator` = zscore(mval)) %>% ungroup() %>%
    mutate(panel = country_label(country_code))
  if (nrow(d) == 0) return(invisible(NULL))
  dl <- d %>% pivot_longer(c(`Problem perception (survey)`, `Real-world indicator`),
                           names_to = "series", values_to = "z")

  p <- ggplot(dl, aes(date, z, colour = series)) +
    geom_line(linewidth = 0.4, na.rm = TRUE) +
    facet_wrap(~ panel, ncol = 7) +
    scale_colour_manual(values = c("Problem perception (survey)" = survey_col,
                                   "Real-world indicator" = macro_col)) +
    labs(title = paste0(lab, ": problem perception vs real-world indicator"),
         subtitle = "Per-country z-scores (mean 0, sd 1)", x = NULL, y = "z-score", colour = NULL,
         caption = "Sources: Eurobarometer (perception), Eurostat (indicator).") +
    theme_bw(base_size = 9) +
    theme(legend.position = "bottom", panel.grid.minor = element_blank(),
          strip.text = element_text(size = 7), axis.text = element_text(size = 6))
  out <- file.path(DIR_OUTPUT, paste0("correlation_overlay_", iss, "_", mv, ".png"))
  ggsave(out, p, width = 13, height = 8, dpi = 150); message("  -> ", out)
}

message("Correlation overlay facets...")
for (i in seq_len(nrow(ISSUE_MACRO))) overlay(ISSUE_MACRO$issue[i], ISSUE_MACRO$macro_var[i],
                                              ISSUE_MACRO$macro_label[i])

# --- (b) correlation summary forest plot -------------------------------------
summ <- corr %>%
  filter(method == "within_country_cor") %>%
  left_join(ISSUE_MACRO, by = c("issue", "macro" = "macro_var")) %>%
  mutate(lab = paste0(issue, "  ~  ", coalesce(macro_label, macro)),
         lab = fct_reorder(lab, estimate))

if (nrow(summ) > 0) {
  p <- ggplot(summ, aes(estimate, lab)) +
    geom_vline(xintercept = 0, colour = "grey60", linetype = "dashed") +
    geom_errorbarh(aes(xmin = ci_low, xmax = ci_high), height = 0.25, colour = survey_col) +
    geom_point(size = 2.5, colour = survey_col) +
    labs(title = "Do real-world conditions track problem perceptions?",
         subtitle = "Within-country correlation of national-context salience with each real-world indicator (95% CI)",
         x = "Correlation (per-country z-scores)", y = NULL,
         caption = "Sources: Eurobarometer + Eurostat. Positive = salience rises with the indicator.") +
    theme_bw(base_size = 11) + theme(panel.grid.minor = element_blank())
  ggsave(file.path(DIR_OUTPUT, "correlation_summary.png"), p, width = 10, height = 5.5, dpi = 150)
  message("  -> ", file.path(DIR_OUTPUT, "correlation_summary.png"))
}
