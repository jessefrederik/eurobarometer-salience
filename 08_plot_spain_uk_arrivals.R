# 08_plot_spain_uk_arrivals.R
# -----------------------------------------------------------------------------
# Country-specific real-world immigration drivers that Eurostat asylum
# applications miss: Spain's irregular (boat) arrivals and the UK's asylum
# claims (the UK is absent from Eurostat post-Brexit). Pairs each country's
# immigration-as-a-national-problem salience with its own arrivals series.
#
# Annual resolution (the Spain series is annual). Reads:
#   data/reference/spain_irregular_arrivals.csv  (Spanish Interior Ministry)
#   data/reference/uk_asylum_claims.csv           (UK Home Office, OGL)
#   data/salience_contexts.csv
# -----------------------------------------------------------------------------

source("config.R")
source("R/utils.R")

survey_col <- "#867abd"; real_col <- "#df5b57"

# --- annual national-context immigration salience for ES and UK --------------
sal <- readr::read_csv(file.path(DIR_DATA, "salience_contexts.csv"), show_col_types = FALSE) %>%
  filter(issue == "immigration", context == "cntry", country_code %in% c("ES", "UK")) %>%
  mutate(year = lubridate::year(date)) %>%
  group_by(country_code, year) %>%
  summarise(salience = mean(pct, na.rm = TRUE), .groups = "drop")

# --- country-specific real-world arrivals ------------------------------------
real <- bind_rows(
  readr::read_csv(file.path(DIR_REF, "spain_irregular_arrivals.csv"), show_col_types = FALSE) %>%
    transmute(country_code = "ES", year, real = arrivals),
  readr::read_csv(file.path(DIR_REF, "uk_asylum_claims.csv"), show_col_types = FALSE) %>%
    transmute(country_code = "UK", year, real = claims)
)

panel_lab <- c(ES = "Spain — irregular arrivals (mostly by sea)",
               UK = "United Kingdom — asylum claims")

dat <- inner_join(sal, real, by = c("country_code", "year")) %>%
  filter(!is.na(salience), !is.na(real))

# per-country correlation (annual)
rs <- dat %>% group_by(country_code) %>%
  summarise(r = cor(salience, real), n = n(), .groups = "drop")
message("Annual salience vs arrivals correlations:"); print(rs)

plot_df <- dat %>%
  group_by(country_code) %>%
  mutate(`Immigration = national problem (%)` = zscore(salience),
         `Arrivals / claims` = zscore(real)) %>% ungroup() %>%
  tidyr::pivot_longer(c(`Immigration = national problem (%)`, `Arrivals / claims`),
                      names_to = "series", values_to = "z") %>%
  left_join(rs, by = "country_code") %>%
  mutate(panel = sprintf("%s  (r = %+.2f, %d yrs)", panel_lab[country_code], r, n))

p <- ggplot(plot_df, aes(year, z, colour = series)) +
  geom_line(linewidth = 0.8) + geom_point(size = 1.6) +
  facet_wrap(~ panel, ncol = 1) +
  scale_colour_manual(values = c("Immigration = national problem (%)" = survey_col,
                                 "Arrivals / claims" = real_col)) +
  labs(title = "Immigration salience vs country-specific arrivals: Spain & UK",
       subtitle = "Annual, per-country z-scores. Real-world series Eurostat misses: Spanish irregular arrivals; UK asylum claims (post-Brexit, not in Eurostat)",
       x = NULL, y = "z-score", colour = NULL,
       caption = "Sources: Eurobarometer QA3 ('facing your country'); Spanish Ministry of the Interior; UK Home Office (OGL).") +
  theme_bw(base_size = 11) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank(),
        strip.text = element_text(face = "bold"))

ggsave(file.path(DIR_OUTPUT, "immigration_spain_uk_arrivals.png"), p,
       width = 10, height = 7, dpi = 150)
message("  -> output/immigration_spain_uk_arrivals.png")
