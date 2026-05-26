# 07_plot_immigration_asylum.R
# -----------------------------------------------------------------------------
# Two targeted correlation figures for immigration:
#   (1) NATIONAL: immigration-as-a-(country)-problem  vs  that country's asylum
#       applications, faceted by country (per-country z-scores).
#   (2) EU SCALE: immigration-as-an-(EU)-problem (EU-wide aggregate) vs TOTAL EU
#       asylum applications, single panel (dual axis), with the correlation.
#
# Asylum requests = Eurostat migr_asyappctzm (first-time applicants); EU total
# uses the EU27_2020 aggregate. Reads data/salience_contexts.csv.
# -----------------------------------------------------------------------------

source("config.R")
source("R/utils.R")
library(eurostat); library(countrycode); library(slider)

survey_col <- "#867abd"; asyl_col <- "#df5b57"

salience <- readr::read_csv(file.path(DIR_DATA, "salience_contexts.csv"), show_col_types = FALSE)

# --- Asylum applications (monthly), per country + EU27 total ------------------
asyl <- get_eurostat("migr_asyappctzm",
  filters = list(sex = "T", citizen = "TOTAL", age = "TOTAL", applicant = "FRST")) %>%
  rename(country_code = geo, date = any_of(c("TIME_PERIOD", "time"))) %>%
  mutate(date = as.Date(date)) %>%
  select(country_code, date, applications = values)

asyl_country <- asyl %>% filter(country_code %in% setdiff(EU_SET, c("EU", "UK"))) %>%
  arrange(country_code, date) %>% group_by(country_code) %>%
  mutate(applications = slider::slide_dbl(applications, mean, .before = 2, .complete = TRUE)) %>%
  ungroup()   # 3-month rolling mean to de-noise the monthly series
asyl_eu      <- asyl %>% filter(country_code == "EU27_2020") %>%
  arrange(date) %>%
  mutate(applications_3m = slider::slide_dbl(applications, mean, .before = 2, .complete = TRUE))

# =============================================================================
# (1) NATIONAL: salience (country context) vs national asylum applications
# =============================================================================
nat_sal <- salience %>%
  filter(issue == "immigration", context == "cntry", country_code %in% setdiff(EU_SET, "EU"))

nat <- bind_rows(
  nat_sal %>% transmute(country_code, date, value = pct,
                        series = "Immigration = national problem (%)"),
  asyl_country %>% transmute(country_code, date, value = applications,
                             series = "Asylum applications (Eurostat)")
) %>%
  group_by(country_code, series) %>% filter(sum(!is.na(value)) >= 4) %>%
  mutate(z = zscore(value)) %>% ungroup() %>%
  mutate(panel = country_label(country_code)) %>% filter(!is.na(panel))

p1 <- ggplot(nat, aes(date, z, colour = series)) +
  geom_line(linewidth = 0.4, na.rm = TRUE) +
  facet_wrap(~ panel, ncol = 7) +
  scale_colour_manual(values = c("Immigration = national problem (%)" = survey_col,
                                 "Asylum applications (Eurostat)" = asyl_col)) +
  scale_x_date(date_breaks = "6 years", date_labels = "%Y") +
  labs(title = "Immigration as a national problem vs national asylum applications",
       subtitle = "Per-country z-scores. Eurobarometer QA3 ('facing your country') vs Eurostat first-time asylum applications",
       x = NULL, y = "z-score", colour = NULL,
       caption = "Sources: Eurobarometer (perception), Eurostat migr_asyappctzm (asylum).") +
  theme_bw(base_size = 9) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank(),
        strip.text = element_text(size = 7), axis.text = element_text(size = 6))

ggsave(file.path(DIR_OUTPUT, "immigration_national_vs_asylum.png"), p1,
       width = 13, height = 8, dpi = 150)
message("  -> output/immigration_national_vs_asylum.png")

# =============================================================================
# (2) EU SCALE: immigration as an EU problem vs TOTAL EU asylum applications
# =============================================================================
eu_sal <- salience %>%
  filter(issue == "immigration", context == "eu", country_code == "EU") %>%
  select(date, pct) %>% arrange(date)

# correlation at survey dates (nearest month join)
joined <- eu_sal %>% inner_join(asyl_eu %>% select(date, applications), by = "date") %>%
  filter(!is.na(pct), !is.na(applications))
r <- if (nrow(joined) >= 5) cor(joined$pct, joined$applications) else NA_real_

# dual-axis scaling (asylum -> salience scale)
max_s <- max(eu_sal$pct, na.rm = TRUE)
max_a <- max(asyl_eu$applications, na.rm = TRUE)
k <- max_s / max_a

p2 <- ggplot() +
  geom_line(data = asyl_eu, aes(date, applications * k, colour = "Total EU asylum applications"),
            linewidth = 0.7, na.rm = TRUE) +
  geom_line(data = eu_sal, aes(date, pct, colour = "Immigration = EU problem (%)"),
            linewidth = 0.9, na.rm = TRUE) +
  geom_point(data = eu_sal, aes(date, pct, colour = "Immigration = EU problem (%)"),
             size = 1.1, na.rm = TRUE) +
  scale_colour_manual(values = c("Immigration = EU problem (%)" = survey_col,
                                 "Total EU asylum applications" = asyl_col)) +
  scale_y_continuous(name = "% of EU citizens naming immigration\nthe most important issue facing the EU",
                     sec.axis = sec_axis(~ . / k, name = "Total EU first-time asylum applications (monthly)",
                                         labels = scales::comma)) +
  scale_x_date(date_breaks = "3 years", date_labels = "%Y") +
  labs(title = "Immigration as an EU-wide problem vs total EU asylum applications",
       subtitle = if (is.na(r)) "EU aggregate" else
         sprintf("EU aggregate. Correlation at survey dates: r = %.2f", r),
       x = NULL, colour = NULL,
       caption = "Sources: Eurobarometer QA5 ('facing the EU'), pooled EU27; Eurostat migr_asyappctzm (EU27_2020 total).") +
  theme_bw(base_size = 11) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank())

ggsave(file.path(DIR_OUTPUT, "immigration_eu_vs_total_asylum.png"), p2,
       width = 10, height = 6, dpi = 150)
message("  -> output/immigration_eu_vs_total_asylum.png  (r = ",
        ifelse(is.na(r), "NA", round(r, 2)), ", n = ", nrow(joined), ")")
