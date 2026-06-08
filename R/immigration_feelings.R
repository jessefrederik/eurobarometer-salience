# R/immigration_feelings.R
# Parse the Standard Eurobarometer "feelings about immigration" question from
# the EC open-data Volume A trend tables, for ALL countries. Two items:
#   EU     = "Immigration of people from other EU Member States"
#   non-EU = "Immigration of people from outside the EU"
# Four-point scale (very/fairly positive | fairly/very negative). We report
# % positive, % negative, and net = positive - negative.
#
# The question's sheet NUMBER changes across waves (QB8 in EB101.3, etc.), so we
# locate the two sheets by their header TEXT, not a fixed name. Reuses the
# .ec_fieldwork_date / .ec_norm_country helpers from R/ec_volumes.R.

# Find the EU / non-EU immigration-feelings sheets in one volume.
.feel_find_sheets <- function(path) {
  res <- list(eu = NA_character_, non_eu = NA_character_)
  for (sh in readxl::excel_sheets(path)) {
    hdr <- tryCatch(suppressMessages(readxl::read_excel(
      path, sheet = sh, range = "B3:B6", col_names = FALSE, .name_repair = "minimal")),
      error = function(e) NULL)
    if (is.null(hdr)) next
    txt <- paste(na.omit(unlist(hdr)), collapse = " ")
    if (!grepl("sentiment positif ou n|positive or negative feeling", txt, ignore.case = TRUE)) next
    if (!grepl("immigration", txt, ignore.case = TRUE)) next
    if (grepl("autres Etats membres|autres États membres|other.*Member States|other EU", txt, ignore.case = TRUE))
      res$eu <- sh
    else if (grepl("en dehors|hors UE|outside the EU|non-?EU", txt, ignore.case = TRUE))
      res$non_eu <- sh
  }
  res
}

# Extract one feelings sheet -> tidy (country_code, positive, negative, net).
.feel_extract <- function(path, sheet, origin, wave, date) {
  m <- suppressMessages(as.data.frame(readxl::read_excel(
    path, sheet = sheet, col_names = FALSE, .name_repair = "minimal")))
  hrow <- which(apply(m, 1, function(r) any(grepl("EU27|UE27", as.character(r), ignore.case = TRUE))))[1]
  if (is.na(hrow)) return(NULL)
  ccol  <- which(grepl("EU27|UE27", as.character(m[hrow, ]), ignore.case = TRUE))[1]
  labcol <- ccol - 1
  codes <- .ec_norm_country(as.character(unlist(m[hrow, ccol:ncol(m)])))
  labs  <- as.character(m[[labcol]])
  euval <- suppressWarnings(as.numeric(m[[ccol]]))
  getrow <- function(lab) {
    cand <- which(grepl(paste0("^\\s*", lab, "\\s*$"), labs, ignore.case = TRUE) &
                  !is.na(euval) & euval <= 1)                # proportion row, not counts
    if (length(cand) == 0) return(rep(NA_real_, length(codes)))
    suppressWarnings(as.numeric(unlist(m[cand[1], ccol:ncol(m)])))
  }
  vp <- getrow("Very positive"); fp <- getrow("Fairly positive")
  fn <- getrow("Fairly negative"); vn <- getrow("Very negative")
  tibble(wave = wave, date = date, country_code = codes, origin = origin,
         positive = round(100 * (vp + fp), 1),
         negative = round(100 * (fn + vn), 1),
         net      = round(100 * ((vp + fp) - (fn + vn)), 1)) %>%
    filter(!is.na(country_code), !is.na(net))
}

# Build the all-country, all-wave feelings table. Relies on the volumes already
# being cached in vol_dir (the salience build downloads them).
build_immigration_feelings <- function(ec_waves, base_url, vol_dir) {
  out <- list()
  for (i in seq_len(nrow(ec_waves))) {
    wv <- ec_waves$wave[i]
    f  <- file.path(vol_dir, paste0(wv, "_volA.xlsx"))
    if (!file.exists(f)) {
      message("  downloading EC volume ", wv)
      utils::download.file(paste0(base_url, ec_waves$key[i]), f, mode = "wb", quiet = TRUE)
    }
    fdate <- .ec_fieldwork_date(suppressMessages(readxl::read_excel(
      f, sheet = "QA3", col_names = FALSE, n_max = 3, .name_repair = "minimal")))
    sh <- .feel_find_sheets(f)
    if (!is.na(sh$eu))     out[[length(out) + 1]] <- .feel_extract(f, sh$eu, "eu", wv, fdate)
    if (!is.na(sh$non_eu)) out[[length(out) + 1]] <- .feel_extract(f, sh$non_eu, "non_eu", wv, fdate)
    if (is.na(sh$eu) && is.na(sh$non_eu)) message("  ", wv, ": no immigration-feelings sheet found")
  }
  bind_rows(out) %>% arrange(origin, country_code, date)
}
