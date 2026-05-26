# R/ec_volumes.R
# Parse the European Commission's open-data "Volume A" trend tables (one per
# Standard EB round) into tidy salience-by-country, for ALL configured issues in
# the three contexts (QA3 = country, QA4 = personal, QA5 = EU). Open access, no
# login. Reuses the issue_specs include/exclude regexes from config.R.
#
# Requires: readxl, dplyr, stringr, tibble (loaded by caller).

# "Fieldwork : 12/3 - 5/4/2026" -> first-of-(start month) Date.
.ec_fieldwork_date <- function(m) {
  cell <- as.character(unlist(m))
  fw <- cell[grepl("fieldwork|terrain", cell, ignore.case = TRUE)]
  if (length(fw) == 0) return(as.Date(NA))
  sm <- stringr::str_match(fw[1], "(\\d{1,2})\\s*/\\s*(\\d{1,2})")
  yr <- stringr::str_match(fw[1], "(\\d{4})")[, 2]
  if (any(is.na(c(sm[, 3], yr)))) return(as.Date(NA))
  as.Date(sprintf("%s-%02d-01", yr, as.integer(sm[, 3])))
}

# Normalise EC country tokens ("UE27\nEU27", "DEW"/"DEE") to project codes.
.ec_norm_country <- function(x) {
  x <- stringr::str_squish(stringr::str_replace_all(x, "[\r\n]+", " "))
  dplyr::case_when(
    stringr::str_detect(x, "EU27|UE27") ~ "EU",
    x %in% c("DEW", "DEE")              ~ NA_character_,   # keep only combined DE
    TRUE ~ x
  )
}

# One QA sheet -> tidy (country_code, pct) for one issue (proportion row, <=1).
.ec_extract_issue <- function(m, include, exclude) {
  hrow <- which(apply(m, 1, function(r) any(grepl("EU27|UE27", as.character(r), ignore.case = TRUE))))[1]
  if (is.na(hrow)) return(NULL)
  ccol <- which(grepl("EU27|UE27", as.character(m[hrow, ]), ignore.case = TRUE))[1]
  labcol <- ccol - 1

  codes <- .ec_norm_country(as.character(unlist(m[hrow, ccol:ncol(m)])))
  labs  <- toupper(as.character(m[[labcol]]))
  euval <- suppressWarnings(as.numeric(m[[ccol]]))

  hit <- grepl(include, labs, ignore.case = TRUE)
  if (!is.na(exclude)) hit <- hit & !grepl(exclude, labs, ignore.case = TRUE)
  cand <- which(hit & !is.na(euval) & euval <= 1)        # proportion row (not counts)
  if (length(cand) == 0) return(NULL)

  props <- suppressWarnings(as.numeric(unlist(m[cand[1], ccol:ncol(m)])))
  tibble(country_code = codes, pct = 100 * props) %>%
    filter(!is.na(country_code), !is.na(pct))
}

# Build tidy EC salience across all waves/issues/contexts.
build_ec_salience <- function(ec_waves, issue_specs, base_url, vol_dir) {
  contexts <- c(cntry = "QA3", pers = "QA4", eu = "QA5")
  out <- list()
  for (i in seq_len(nrow(ec_waves))) {
    wv <- ec_waves$wave[i]
    f  <- file.path(vol_dir, paste0(wv, "_volA.xlsx"))
    if (!file.exists(f)) {
      message("  downloading EC volume ", wv)
      utils::download.file(paste0(base_url, ec_waves$key[i]), f, mode = "wb", quiet = TRUE)
    }
    fdate <- .ec_fieldwork_date(suppressMessages(
      readxl::read_excel(f, sheet = "QA3", col_names = FALSE, n_max = 3, .name_repair = "minimal")))
    for (cx in names(contexts)) {
      m <- suppressMessages(as.data.frame(
        readxl::read_excel(f, sheet = contexts[[cx]], col_names = FALSE, .name_repair = "minimal")))
      for (k in seq_len(nrow(issue_specs))) {
        sp <- issue_specs[k, ]
        df <- .ec_extract_issue(m, sp$include, sp$exclude)
        if (!is.null(df) && nrow(df)) {
          out[[length(out) + 1]] <- df %>%
            mutate(wave = wv, date = fdate, context = cx, issue = sp$issue)
        }
      }
    }
  }
  bind_rows(out) %>%
    select(wave, date, country_code, context, issue, pct) %>%
    arrange(issue, context, country_code, date)
}
