# 05_plot_descriptive.R
# -----------------------------------------------------------------------------
# Descriptive small-multiples of problem perceptions: one figure per issue,
# faceted by country (+ EU aggregate), time on the x-axis, three lines for the
# three contexts (red = your country, blue = the EU, black = you personally).
# Reads data/salience_contexts.csv -> output/descriptive_<issue>.png
# -----------------------------------------------------------------------------

source("config.R")
source("R/utils.R")
library(countrycode)

salience <- readr::read_csv(file.path(DIR_DATA, "salience_contexts.csv"), show_col_types = FALSE)

ctx_levels <- c("cntry", "eu", "pers")
ctx_labels <- c('"affecting your country"', '"affecting the EU"', '"affecting you personally"')
ctx_colours <- setNames(c("red", "blue", "black"), ctx_labels)

make_descriptive <- function(iss, label) {
  df <- salience %>%
    filter(issue == iss, country_code %in% EU_SET) %>%
    mutate(panel = country_label(country_code)) %>%
    filter(!is.na(panel)) %>%
    mutate(context = factor(context, ctx_levels, ctx_labels),
           panel = factor(panel, levels = sort(unique(panel))))
  if (nrow(df) == 0) return(invisible(NULL))

  p <- ggplot(df, aes(date, pct, colour = context)) +
    geom_line(linewidth = 0.4) +
    facet_wrap(~ panel, ncol = 8) +
    scale_colour_manual(values = ctx_colours) +
    scale_x_date(breaks = as.Date(c("2005-01-01","2011-01-01","2017-01-01","2023-01-01")),
                 date_labels = "%Y", limits = as.Date(c("2005-01-01", "2026-07-01"))) +
    scale_y_continuous(breaks = c(0, 25, 50, 75, 100), limits = c(0, 100)) +
    labs(title = paste0("Percentage identifying ", label, " as the most important issue"),
         subtitle = "Eurobarometer 2005-2026 (microdata + EC open volumes)",
         x = NULL, y = paste0("% listing ", label, " as most important issue"),
         colour = NULL, caption = "Source: Eurobarometer / European Commission.") +
    theme_bw(base_size = 9) +
    theme(legend.position = "bottom", panel.grid.minor = element_blank(),
          strip.background = element_rect(fill = "grey90", colour = NA),
          strip.text = element_text(size = 7), axis.text = element_text(size = 6))

  out <- file.path(DIR_OUTPUT, paste0("descriptive_", iss, ".png"))
  ggsave(out, p, width = 14, height = 8, dpi = 150)
  message("  -> ", out)
}

issues_present <- intersect(issue_specs$issue, unique(salience$issue))
message("Descriptive charts for ", length(issues_present), " issues...")
for (iss in issues_present) {
  lab <- tolower(issue_specs$label[match(iss, issue_specs$issue)])
  make_descriptive(iss, lab)
}
