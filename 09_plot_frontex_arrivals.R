# 09_plot_frontex_arrivals.R
# -----------------------------------------------------------------------------
# Frontex detections of irregular border crossings (IBC) as the real-world
# arrivals measure. Two figures:
#   (1) Mediterranean frontline countries (ES/IT/EL): national-context
#       immigration salience vs their route's crossings (trailing 3-mo, z-scores).
#   (2) EU scale: immigration-as-an-EU-problem vs total EU Frontex crossings
#       (dual axis) — a media-salient alternative to asylum applications.
#
# Route->country: ES = Western African + Western Mediterranean; IT = Central
# Mediterranean; EL = Eastern Mediterranean. (Frontex has no Channel route, so
# the UK is not covered here.) Reads data/reference/frontex_ibc_monthly.csv.
# -----------------------------------------------------------------------------

source("config.R")
source("R/utils.R")
library(slider)

survey_col <- "#867abd"; ibc_col <- "#1b9e77"
smooth3 <- function(x) slider::slide_dbl(x, mean, .before = 2, .complete = TRUE)

salience <- readr::read_csv(file.path(DIR_DATA, "salience_contexts.csv"), show_col_types = FALSE)
ibc <- readr::read_csv(file.path(DIR_REF, "frontex_ibc_monthly.csv"), show_col_types = FALSE)

route_map <- tribble(
  ~country_code, ~route,
  "ES", "Western African Route",
  "ES", "Western Mediterranean Route",
  "IT", "Central Mediterranean Route",
  "EL", "Eastern Mediterranean Route"
)
panel_lab <- c(ES = "Spain — W. African + W. Mediterranean",
               IT = "Italy — Central Mediterranean",
               EL = "Greece — Eastern Mediterranean")

# --- (1) frontline countries -------------------------------------------------
ctry_ibc <- ibc %>% inner_join(route_map, by = "route") %>%
  group_by(country_code, date) %>% summarise(ibc = sum(detections), .groups = "drop") %>%
  arrange(country_code, date) %>% group_by(country_code) %>%
  mutate(ibc = smooth3(ibc)) %>% ungroup()

front_sal <- salience %>%
  filter(issue == "immigration", context == "cntry", country_code %in% c("ES", "IT", "EL")) %>%
  select(country_code, date, pct)

reg_r <- front_sal %>% inner_join(ctry_ibc, by = c("country_code", "date")) %>%
  filter(!is.na(pct), !is.na(ibc)) %>%
  group_by(country_code) %>% summarise(r = cor(pct, ibc), n = n(), .groups = "drop")
message("Frontline salience vs Frontex crossings:"); print(reg_r)

# Restrict to the Frontex era before z-scoring so the plotted window matches the
# correlation window (otherwise Spain's pre-2009 salience peak distorts the scale).
front_long <- bind_rows(
  front_sal  %>% transmute(country_code, date, value = pct, series = "Immigration = national problem (%)"),
  ctry_ibc   %>% transmute(country_code, date, value = ibc, series = "Irregular crossings (Frontex)")
) %>% filter(date >= min(ibc$date)) %>%
  group_by(country_code, series) %>% mutate(z = zscore(value)) %>% ungroup() %>%
  left_join(reg_r %>% mutate(lab = sprintf("%s  (r = %+.2f)", panel_lab[country_code], r)),
            by = "country_code")

p1 <- ggplot(front_long, aes(date, z, colour = series)) +
  geom_line(linewidth = 0.6, na.rm = TRUE) +
  facet_wrap(~ lab, ncol = 1) +
  scale_colour_manual(values = c("Immigration = national problem (%)" = survey_col,
                                 "Irregular crossings (Frontex)" = ibc_col)) +
  scale_x_date(date_breaks = "3 years", date_labels = "%Y") +
  labs(title = "Immigration salience vs Frontex irregular crossings: Mediterranean frontline",
       subtitle = "Per-country z-scores. National-context salience vs route detections (trailing 3-mo)",
       x = NULL, y = "z-score", colour = NULL,
       caption = "Sources: Eurobarometer QA3 ('facing your country'); Frontex detections of irregular border crossings.") +
  theme_bw(base_size = 10) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank(),
        strip.text = element_text(face = "bold"))
ggsave(file.path(DIR_OUTPUT, "immigration_frontex_frontline.png"), p1, width = 10, height = 8, dpi = 150)
message("  -> output/immigration_frontex_frontline.png")

# --- (2) EU scale: EU-problem salience vs total EU Frontex crossings ---------
eu_ibc <- ibc %>% group_by(date) %>% summarise(ibc = sum(detections), .groups = "drop") %>%
  arrange(date) %>% mutate(ibc = smooth3(ibc))
eu_sal <- salience %>% filter(issue == "immigration", context == "eu", country_code == "EU") %>%
  select(date, pct) %>% arrange(date)

j <- eu_sal %>% inner_join(eu_ibc, by = "date") %>% filter(!is.na(pct), !is.na(ibc))
r_eu <- if (nrow(j) >= 5) cor(j$pct, j$ibc) else NA_real_
message(sprintf("EU: immigration-as-EU-problem vs total Frontex IBC  r = %.2f (n = %d)", r_eu, nrow(j)))

k <- max(eu_sal$pct, na.rm = TRUE) / max(eu_ibc$ibc, na.rm = TRUE)
p2 <- ggplot() +
  geom_line(data = eu_ibc, aes(date, ibc * k, colour = "Total EU irregular crossings (Frontex)"),
            linewidth = 0.7, na.rm = TRUE) +
  geom_line(data = eu_sal, aes(date, pct, colour = "Immigration = EU problem (%)"),
            linewidth = 0.9, na.rm = TRUE) +
  geom_point(data = eu_sal, aes(date, pct, colour = "Immigration = EU problem (%)"), size = 1.1, na.rm = TRUE) +
  scale_colour_manual(values = c("Immigration = EU problem (%)" = survey_col,
                                 "Total EU irregular crossings (Frontex)" = ibc_col)) +
  scale_y_continuous(name = "% of EU citizens naming immigration\nthe top issue facing the EU",
                     sec.axis = sec_axis(~ . / k, name = "Total EU irregular crossings (3-mo avg)",
                                         labels = scales::comma)) +
  scale_x_date(date_breaks = "3 years", date_labels = "%Y") +
  labs(title = "Immigration as an EU problem vs total EU irregular crossings (Frontex)",
       subtitle = if (is.na(r_eu)) "EU aggregate" else sprintf("EU aggregate. Correlation at survey dates: r = %.2f", r_eu),
       x = NULL, colour = NULL,
       caption = "Sources: Eurobarometer QA5 ('facing the EU'); Frontex detections of irregular border crossings.") +
  theme_bw(base_size = 11) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank())
ggsave(file.path(DIR_OUTPUT, "immigration_eu_vs_frontex.png"), p2, width = 10, height = 6, dpi = 150)
message("  -> output/immigration_eu_vs_frontex.png")
