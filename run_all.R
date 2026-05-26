#!/usr/bin/env Rscript
# run_all.R — end-to-end pipeline orchestrator.
#
# Runs the numbered stages in order. Each stage reads/writes files in data/ and
# output/, so stages are independent and idempotent (caches are reused).
#
# Usage:
#   Rscript run_all.R                 # full pipeline (uses local microdata if present)
#   EB_DATA_ROOT=/path Rscript run_all.R
#   SKIP="03 04" Rscript run_all.R    # skip stages by number
#
# Stages: 00 download EB | 01 build micro | 02 build contexts | 03 build macro
#         04 correlate   | 05 descriptive plots | 06 correlation plots
# 01 is skipped automatically when no GESIS microdata is available (EC-only tier).

stages <- c(
  "00" = "00_download_eurobarometer.R",
  "01" = "01_build_micro.R",
  "02" = "02_build_contexts.R",
  "03" = "03_build_macro.R",
  "04" = "04_correlate.R",
  "05" = "05_plot_descriptive.R",
  "06" = "06_plot_correlations.R",
  "07" = "07_plot_immigration_asylum.R"
)

skip <- strsplit(Sys.getenv("SKIP", ""), "\\s+")[[1]]

# Auto-skip the microdata build when there is none to build.
data_root <- Sys.getenv("EB_DATA_ROOT",
  unset = file.path(Sys.getenv("HOME"), "eb_data_local/Eurobarometer_individual"))
if (length(list.files(data_root, pattern = "\\.rds$")) == 0) {
  message(">> No GESIS microdata in EB_DATA_ROOT — running EC-only tier (skipping 01).")
  skip <- union(skip, "01")
}

for (s in names(stages)) {
  if (s %in% skip) { message("== SKIP ", s, " (", stages[s], ")"); next }
  message("\n========== STAGE ", s, ": ", stages[s], " ==========")
  t0 <- Sys.time()
  ok <- tryCatch({ sys.source(stages[s], envir = new.env(parent = globalenv())); TRUE },
                 error = function(e) { message("!! STAGE ", s, " FAILED: ", conditionMessage(e)); FALSE })
  message("== stage ", s, if (ok) " done in " else " ERRORED after ",
          round(difftime(Sys.time(), t0, units = "mins"), 1), " min")
  if (!ok) quit(status = 1)
}
message("\nPipeline complete. See data/ (tables) and output/ (figures).")
