# 06_plot_correlations.R
# -----------------------------------------------------------------------------
# (a) Per issue<->macro pair: faceted overlay of national-context salience (%)
#     and the real-world variable in its OWN units, on a dual axis (no z-scores,
#     so magnitudes are preserved). Free per-panel scales keep each country
#     readable; the secondary axis uses a single global transform.
# (b) Correlation summary: within-country correlation (95% CI), West vs East,
#     at both the trailing-3-month and annual resolution.
# -----------------------------------------------------------------------------

source("config.R"); source("R/utils.R")
library(countrycode); library(slider)

sal_col <- "#5e3c99"; macro_col <- "#d95f02"

macro <- readRDS(file.path(DIR_DATA, "core_macro.rds")) %>%
  mutate(crime_per_100k = {
    s <- rowSums(cbind(homicide_per_100k, robbery_per_100k, burglary_per_100k), na.rm = TRUE)
    ifelse(is.na(homicide_per_100k) & is.na(robbery_per_100k) & is.na(burglary_per_100k), NA_real_, s)
  })
salience <- readr::read_csv(file.path(DIR_DATA, "salience_contexts.csv"), show_col_types = FALSE) %>%
  filter(context == "cntry", country_code %in% setdiff(EU_SET, "EU"))

# --- (a) dual-axis overlays per pair -----------------------------------------
overlay <- function(issue, macro_var, macro_axis, flabel, monthly) {
  d_sal <- salience %>% filter(issue == !!issue) %>%
    transmute(country_code, date, pct) %>% filter(!is.na(pct))
  d_mac <- macro %>% select(country_code, date, mv = all_of(macro_var)) %>% filter(!is.na(mv))
  if (monthly) d_mac <- d_mac %>% arrange(country_code, date) %>% group_by(country_code) %>%
    mutate(mv = slider::slide_dbl(mv, mean, .before = 2, .complete = TRUE)) %>%
    ungroup() %>% filter(!is.na(mv))           # trailing 3-month average
  keep <- intersect(unique(d_sal$country_code), unique(d_mac$country_code))
  d_sal <- d_sal %>% filter(country_code %in% keep) %>% mutate(panel = country_label(country_code))
  d_mac <- d_mac %>% filter(country_code %in% keep) %>% mutate(panel = country_label(country_code))
  if (nrow(d_sal) == 0) return(invisible(NULL))

  # per-country Pearson r shown in each facet — computed the same way as stage 04:
  # wave-level (salience month vs trailing-3-mo indicator) for monthly indicators,
  # annual for crime. d_mac$mv is still real units here (rescaled further below).
  if (monthly) {
    rlab <- inner_join(d_sal, d_mac %>% select(panel, date, mv), by = c("panel", "date")) %>%
      group_by(panel) %>% filter(n() >= 4) %>%
      summarise(lab = sprintf("r = %+.2f", cor(pct, mv)), .groups = "drop")
  } else {
    rlab <- inner_join(
      d_sal %>% mutate(y = lubridate::year(date)) %>% group_by(panel, y) %>% summarise(pct = mean(pct), .groups = "drop"),
      d_mac %>% mutate(y = lubridate::year(date)) %>% group_by(panel, y) %>% summarise(mv = mean(mv), .groups = "drop"),
      by = c("panel", "y")) %>%
      group_by(panel) %>% filter(n() >= 4) %>% summarise(lab = sprintf("r = %+.2f", cor(pct, mv)), .groups = "drop")
  }
  xpos <- min(c(d_sal$date, d_mac$date), na.rm = TRUE)

  # PER-COUNTRY min-max: rescale the indicator to each country's own salience
  # [min,max] so both lines fill every panel (free axes). Per-country scaling
  # means the right axis can't share numeric ticks, so it's labelled only.
  scl <- d_sal %>% group_by(panel) %>% summarise(smin = min(pct), smax = max(pct), .groups = "drop") %>%
    inner_join(d_mac %>% group_by(panel) %>% summarise(mmin = min(mv), mmax = max(mv), .groups = "drop"), by = "panel") %>%
    filter(smax > smin, mmax > mmin) %>%
    mutate(a = (smax - smin) / (mmax - mmin), b = smin - a * mmin)
  d_mac <- d_mac %>% inner_join(scl %>% select(panel, a, b), by = "panel") %>% mutate(mv = a * mv + b)

  p <- ggplot() +
    geom_line(data = d_mac, aes(date, mv, colour = "Real-world indicator"), linewidth = 0.4, na.rm = TRUE) +
    geom_line(data = d_sal, aes(date, pct, colour = "Problem perception (%)"), linewidth = 0.5, na.rm = TRUE) +
    geom_point(data = d_sal, aes(date, pct, colour = "Problem perception (%)"), size = 0.5, na.rm = TRUE) +
    geom_text(data = rlab, aes(xpos, Inf, label = lab), hjust = 0, vjust = 1.4, size = 2.3, colour = "grey25") +
    facet_wrap(~ panel, ncol = 7, scales = "free_y") +
    scale_colour_manual(values = c("Problem perception (%)" = sal_col, "Real-world indicator" = macro_col)) +
    scale_y_continuous(name = paste0("% naming ", flabel, " the top issue"),
                       sec.axis = dup_axis(name = paste0(macro_axis, " — min-max scaled per country"),
                                           breaks = NULL, labels = NULL)) +
    scale_x_date(date_breaks = "8 years", date_labels = "%y") +
    labs(title = paste0(tools::toTitleCase(flabel), ": problem perception vs ", tolower(macro_axis)),
         subtitle = "Per country (free axes): salience (%) and the indicator, each scaled to its own min-max. r = within-country Pearson (annual).",
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
  overlay(issue, macro_var, macro_axis, focus_label[[issue]], monthly))

# --- (b) correlation summary: West vs East -----------------------------------
allc <- readr::read_csv(file.path(DIR_DATA, "correlations.csv"), show_col_types = FALSE)
ord  <- allc %>% filter(method == "within_country_pearson", region == "All Europe", resolution == "annual") %>%
  arrange(estimate) %>% pull(macro_label)
corr <- allc %>%
  filter(method == "within_country_pearson",
         region %in% c("Western Europe", "Central & Eastern Europe")) %>%
  mutate(lab = factor(macro_label, levels = ord),
         region = factor(region, levels = c("Western Europe", "Central & Eastern Europe")),
         Resolution = ifelse(resolution == "wave_3m", "Trailing 3-month (monthly)", "Annual"))

p2 <- ggplot(corr, aes(estimate, lab, colour = Resolution, shape = Resolution)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey60") +
  geom_errorbarh(aes(xmin = ci_low, xmax = ci_high), height = 0.2, na.rm = TRUE,
                 position = position_dodge(width = 0.4)) +
  geom_point(size = 2.6, position = position_dodge(width = 0.4)) +
  facet_wrap(~ region) +
  scale_colour_manual(values = c("Trailing 3-month (monthly)" = sal_col, "Annual" = macro_col)) +
  labs(title = "Does problem perception track real-world conditions? West vs East",
       subtitle = "Within-country correlation (95% CI), at trailing-3-month and annual resolution. Crime is annual-only.",
       x = "Correlation", y = NULL, colour = NULL, shape = NULL,
       caption = "Sources: Eurobarometer + Eurostat. Within-country (per-country z-scores), pooled. East = post-communist CEE members.") +
  theme_bw(base_size = 11) + theme(panel.grid.minor = element_blank(), legend.position = "top",
                                   strip.text = element_text(face = "bold"))
ggsave(file.path(DIR_OUTPUT, "correlation_summary.png"), p2, width = 12, height = 5, dpi = 150)
message("  -> ", file.path(DIR_OUTPUT, "correlation_summary.png"))
