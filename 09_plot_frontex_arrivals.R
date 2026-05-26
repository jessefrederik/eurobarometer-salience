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
panel_lab <- c(ES = "Spain — W.African + W.Med (Frontex), GOB pre-2009",
               IT = "Italy — Central Mediterranean",
               EL = "Greece — Eastern Mediterranean")

# --- (1) frontline countries -------------------------------------------------
# Frontex begins Jan-2009. For SPAIN, extend back to 2002 with the Spanish
# Interior Ministry (GOB) annual series — it matches Frontex-Spain on their
# overlap (annual r = 0.99), so this is a like-for-like extension. The annual
# pre-2009 totals are spread evenly across months.
fx_ctry <- ibc %>% inner_join(route_map, by = "route") %>%
  group_by(country_code, date) %>% summarise(arrivals = sum(detections), .groups = "drop")

gob <- readr::read_csv(file.path(DIR_REF, "spain_irregular_arrivals.csv"), show_col_types = FALSE)
gob_pre2009 <- gob %>% filter(year <= 2008) %>%
  tidyr::crossing(mn = 1:12) %>%
  transmute(country_code = "ES",
            date = as.Date(sprintf("%04d-%02d-01", year, mn)),
            arrivals = arrivals / 12)

ctry_ibc <- bind_rows(fx_ctry, gob_pre2009) %>%
  arrange(country_code, date) %>% group_by(country_code) %>%
  mutate(arrivals = smooth3(arrivals)) %>% ungroup()

front_sal <- salience %>%
  filter(issue == "immigration", context == "cntry", country_code %in% c("ES", "IT", "EL")) %>%
  select(country_code, date, pct)

joined_front <- front_sal %>% inner_join(ctry_ibc, by = c("country_code", "date")) %>%
  filter(!is.na(pct), !is.na(arrivals))
reg_r <- joined_front %>%
  group_by(country_code) %>% summarise(r = cor(pct, arrivals), n = n(), .groups = "drop")
# modern-era (2009+) r — differs from full r only for Spain (which has GOB pre-2009).
reg_r_mod <- joined_front %>% filter(date >= as.Date("2009-01-01")) %>%
  group_by(country_code) %>% summarise(r_mod = cor(pct, arrivals), .groups = "drop")
labs_df <- reg_r %>% left_join(reg_r_mod, by = "country_code") %>%
  mutate(lab = ifelse(country_code == "ES" & abs(r - r_mod) > 0.02,
    sprintf("%s  (r = %+.2f since 2002; %+.2f since 2009)", panel_lab[country_code], r, r_mod),
    sprintf("%s  (r = %+.2f)", panel_lab[country_code], r))) %>%
  select(country_code, lab)
message("Frontline salience vs arrivals:"); print(reg_r); print(reg_r_mod)

# Plot each country over the window where ITS arrivals series exists (ES 2002+
# via GOB, IT/EL 2009+ via Frontex), z-scored within that window.
starts <- ctry_ibc %>% filter(!is.na(arrivals)) %>%
  group_by(country_code) %>% summarise(start = min(date), .groups = "drop")
front_long <- bind_rows(
  front_sal %>% transmute(country_code, date, value = pct, series = "Immigration = national problem (%)"),
  ctry_ibc  %>% transmute(country_code, date, value = arrivals, series = "Irregular arrivals")
) %>% left_join(starts, by = "country_code") %>% filter(date >= start) %>%
  group_by(country_code, series) %>% mutate(z = zscore(value)) %>% ungroup() %>%
  left_join(labs_df, by = "country_code")

p1 <- ggplot(front_long, aes(date, z, colour = series)) +
  geom_line(linewidth = 0.6, na.rm = TRUE) +
  facet_wrap(~ lab, ncol = 1) +
  scale_colour_manual(values = c("Immigration = national problem (%)" = survey_col,
                                 "Irregular arrivals" = ibc_col)) +
  scale_x_date(date_breaks = "3 years", date_labels = "%Y") +
  labs(title = "Immigration salience vs irregular arrivals: Mediterranean frontline",
       subtitle = "Per-country z-scores, trailing 3-mo. Spain extended pre-2009 with Interior Ministry data (matches Frontex, annual r=0.99)",
       x = NULL, y = "z-score", colour = NULL,
       caption = "Sources: Eurobarometer QA3 ('facing your country'); Frontex IBC; Spanish Interior Ministry (Spain pre-2009).") +
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
