# R/context_extract.R
# Generalised three-context extractor for the Eurobarometer "most important
# issues" battery. Each issue is asked in up to three contexts:
#   cntry = facing (your country)   | eu = facing the EU   | pers = facing you personally
# (plus a Turkish-Cypriot "tcc" variant we drop).
#
# This generalises plot_immigration_contexts.R / plot_environment_contexts.R:
# a respondent "mentions" an issue in a context if ANY matching item is ticked
# (pmax over items), which handles split-ballots and multi-item issues uniformly.
#
# Requires: haven, dplyr, purrr, tibble (loaded by the calling script).

# Classify a variable label into a context (or NA if not the MII battery).
classify_context <- function(label) {
  l <- toupper(label)
  # Require "import(ant) issues" ADJACENT — this is the standard "two most
  # important issues" battery. It deliberately EXCLUDES "IMPORTANT NAT ISSUES"
  # (the QD1 multi-select question in EB 65.3 / ZA4507, where respondents pick
  # ~3 issues, inflating every issue's salience ~2-3x). See docs.
  if (!grepl("IMPORT(ANT)?\\s+ISS", l)) return(NA_character_)
  if (grepl("\\bNAT\\b", l)) return(NA_character_)   # belt-and-braces: drop "NAT ISSUES"
  if (grepl("TCC", l))      return("tcc")     # incl. CY-TCC subsample: drop
  if (grepl("\\bEU\\b", l)) return("eu")
  if (grepl("PERS", l))     return("pers")
  return("cntry")                             # CNTRY / CTRY / bare
}

# 0/1 recode: 1 = mentioned, else 0, NA preserved.
.zap01 <- function(x) {
  x <- suppressWarnings(as.numeric(haven::zap_labels(x)))
  ifelse(is.na(x), NA_real_, ifelse(x == 1, 1, 0))
}

# Pre-computed combination totals to drop (they re-bundle sub-items, e.g. energy).
.is_total <- function(varname, label) {
  grepl("_t$", varname) | grepl("\\+", label) | grepl("QA[0-9].*\\+", toupper(label))
}

# Extract every issue x context dummy from ONE raw wave file.
# Returns long tibble: study, id, issue, context, value (0/1).
extract_file_contexts <- function(path, issue_specs) {
  dat  <- readRDS(path)
  study <- tools::file_path_sans_ext(basename(path))
  vn    <- names(dat)
  labs  <- vapply(dat, function(c) {
    l <- attr(c, "label"); if (is.null(l)) "" else as.character(l)
  }, character(1))
  ctx_all <- vapply(labs, classify_context, character(1))

  rows <- vector("list", nrow(issue_specs))
  for (k in seq_len(nrow(issue_specs))) {
    spec <- issue_specs[k, ]
    hit <- grepl(spec$include, labs, ignore.case = TRUE)
    if (!is.na(spec$exclude)) hit <- hit & !grepl(spec$exclude, labs, ignore.case = TRUE)
    hit <- hit & !.is_total(vn, labs)
    cand <- which(hit & ctx_all %in% c("cntry", "eu", "pers"))
    if (length(cand) == 0L) next

    ctx <- ctx_all[cand]
    out <- tibble(study = study, id = seq_len(nrow(dat)))
    for (cx in c("cntry", "eu", "pers")) {
      vars <- vn[cand][ctx == cx]
      if (length(vars) == 0L) { out[[cx]] <- NA_real_; next }
      cols <- lapply(dat[vars], .zap01)
      out[[cx]] <- do.call(pmax, c(cols, list(na.rm = TRUE)))  # "mentioned in ANY item"
    }
    rows[[k]] <- out %>%
      pivot_longer(c(cntry, eu, pers), names_to = "context", values_to = "value") %>%
      mutate(issue = spec$issue)
  }
  rm(dat); gc(verbose = FALSE)
  bind_rows(rows)
}

# Extract across all wave files. Returns long tibble (study, id, issue, context, value).
extract_all_contexts <- function(files, issue_specs) {
  purrr::map_dfr(files, function(f) {
    message("  contexts <- ", basename(f))
    extract_file_contexts(f, issue_specs)
  })
}
