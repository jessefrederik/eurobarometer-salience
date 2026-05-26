# 06_plot_correlations.R
# -----------------------------------------------------------------------------
# (a) Per issue<->macro pair: faceted overlay of national-context salience (%)
#     and the real-world variable in its OWN units, on a dual axis (no z-scores,
#     so magnitudes are preserved). Free per-panel scales keep each country
#     readable; the secondary axis uses a single global transform.
# (b) Correlation summary: Pearson (with 95% CI) and Spearman per pair.
# -----------------------------------------------------------------------------

source("config.R"); source("R/utils.R")
library(countrycode)

sal_col <- "#5e3c99"; macro_col <- "#d95f02"

macro <- readRDS(file.path(DIR_DATA, "core_macro.rds")) %>%
  mutate(crime_per_100k = {
    s <- rowSums(cbind(homicide_per_100k, robbery_per_100k, burglary_per_100k), na.rm = TRUE)
    ifelse(is.na(homicide_per_100k) & is.na(robbery_per_100k) & is.na(burglary_per_100k), NA_real_, s)
  })
salience <- readr::read_csv(file.path(DIR_DATA, "salience_contexts.csv"), show_col_types = FALSE) %>%
  filter(context == "cntry", country_code %in% setdiff(EU_SET, "EU"))

# --- (a) dual-axis overlays per pair -----------------------------------------
overlay <- function(issue, macro_var, macro_axis, flabel) {
  d_sal <- salience %>% filter(issue == !!issue) %>%
    transmute(country_code, date, pct) %>% filter(!is.na(pct))
  d_mac <- macro %>% select(country_code, date, mv = all_of(macro_var)) %>% filter(!is.na(mv))
  keep <- intersect(unique(d_sal$country_code), unique(d_mac$country_code))
  d_sal <- d_sal %>% filter(country_code %in% keep) %>% mutate(panel = country_label(country_code))
  d_mac <- d_mac %>% filter(country_code %in% keep) %>% mutate(panel = country_label(country_code))
  if (nrow(d_sal) == 0) return(invisible(NULL))

  # global transform so macro*k sits on a comparable range to salience
  k <- as.numeric(quantile(d_sal$pct, .98, na.rm = TRUE) / quantile(d_mac$mv, .98, na.rm = TRUE))

  p <- ggplot() +
    geom_line(data = d_mac, aes(date, mv * k, colour = "Real-world indicator"), linewidth = 0.4, na.rm = TRUE) +
    geom_line(data = d_sal, aes(date, pct, colour = "Problem perception (%)"), linewidth = 0.5, na.rm = TRUE) +
    geom_point(data = d_sal, aes(date, pct, colour = "Problem perception (%)"), size = 0.5, na.rm = TRUE) +
    facet_wrap(~ panel, ncol = 7, scales = "free_y") +
    scale_colour_manual(values = c("Problem perception (%)" = sal_col, "Real-world indicator" = macro_col)) +
    scale_y_continuous(name = paste0("% naming ", flabel, " the top issue"),
                       sec.axis = sec_axis(~ . / k, name = macro_axis)) +
    scale_x_date(date_breaks = "8 years", date_labels = "%y") +
    labs(title = paste0(tools::toTitleCase(flabel), ": problem perception vs ", tolower(macro_axis)),
         subtitle = "National-context salience (left, %) vs the real-world indicator in its own units (right). Per-panel scales.",
         x = NULL, colour = NULL,
         caption = "Sources: Eurobarometer QA3; Eurostat.") +
    theme_bw(base_size = 9) +
    theme(legend.position = "bottom", panel.grid.minor = element_blank(),
          strip.text = element_text(size = 7), axis.text = element_text(size = 6),
          axis.title.y.right = element_text(colour = macro_col), axis.title.y.left = element_text(colour = sal_col))
  out <- file.path(DIR_OUTPUT, paste0("overlay_", issue, ".png"))
  ggsave(out, p, width = 13, height = 8, dpi = 150); message("  -> ", out)
}
for (i in seq_len(nrow(ISSUE_MACRO))) with(ISSUE_MACRO[i, ],
  overlay(issue, macro_var, macro_axis, focus_label[[issue]]))

# --- (b) correlation summary: Pearson + Spearman -----------------------------
corr <- readr::read_csv(file.path(DIR_DATA, "correlations.csv"), show_col_types = FALSE) %>%
  filter(method %in% c("within_country_pearson", "within_country_spearman")) %>%
  mutate(Method = ifelse(method == "within_country_pearson", "Pearson", "Spearman"))

ord <- corr %>% filter(Method == "Pearson") %>% arrange(estimate) %>% pull(macro_label)
corr <- corr %>% mutate(lab = factor(macro_label, levels = ord))

p2 <- ggplot(corr, aes(estimate, lab, colour = Method, shape = Method)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey60") +
  geom_errorbarh(aes(xmin = ci_low, xmax = ci_high), height = 0.2, na.rm = TRUE,
                 position = position_dodge(width = 0.4)) +
  geom_point(size = 3, position = position_dodge(width = 0.4)) +
  scale_colour_manual(values = c(Pearson = sal_col, Spearman = macro_col)) +
  labs(title = "Does problem perception track real-world conditions?",
       subtitle = "Within-country correlation of national salience with each real-world variable (Pearson 95% CI; Spearman = rank, robust)",
       x = "Correlation", y = NULL, colour = NULL, shape = NULL,
       caption = "Sources: Eurobarometer + Eurostat. Within-country (per-country z-scores), pooled.") +
  theme_bw(base_size = 11) + theme(panel.grid.minor = element_blank(), legend.position = "top")
ggsave(file.path(DIR_OUTPUT, "correlation_summary.png"), p2, width = 10, height = 5, dpi = 150)
message("  -> ", file.path(DIR_OUTPUT, "correlation_summary.png"))
