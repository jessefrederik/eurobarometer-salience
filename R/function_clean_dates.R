# Requires: tidyverse (loaded by core_micro.R)

#' Apply study-specific interview date corrections from a CSV config file
#'
#' Reads `date_corrections.csv` and applies three correction types:
#' - `malformed`: replaces a specific broken date string (matched by study + original_value)
#' - `append_year`: appends a year to truncated dates (e.g. "15 March" → "15 March 2003")
#' - `missing`: fills NA interview_date with a known fallback date
#'
#' @param df Data frame with `study` and `interview_date` columns.
#' @param path Path to the corrections CSV (default: `"datafiles/date_corrections.csv"`).
#' @return The input data frame with corrected `interview_date` values.
apply_date_corrections <- function(df, path = "data/reference/date_corrections.csv") {
  corrections <- read.csv(path, stringsAsFactors = FALSE)

  malformed  <- corrections %>% filter(condition == "malformed")
  append_yr  <- corrections %>% filter(condition == "append_year")
  missing_dt <- corrections %>% filter(condition == "missing")

  df %>%
    mutate(
      # Fix malformed dates: only replace when study + exact broken string match
      interview_date = {
        mal_key <- paste(study, interview_date, sep = "|")
        mal_ref <- paste(malformed$study, malformed$original_value, sep = "|")
        mal_idx <- match(mal_key, mal_ref)
        if_else(!is.na(mal_idx), malformed$corrected_date[mal_idx], interview_date)
      },
      # Append year to truncated dates
      interview_date = if_else(
        study %in% append_yr$study & !is.na(interview_date),
        paste0(interview_date, " ", append_yr$corrected_date[match(study, append_yr$study)]),
        interview_date
      ),
      # Fill missing dates with known fallback
      interview_date = if_else(
        study %in% missing_dt$study & is.na(interview_date),
        missing_dt$corrected_date[match(study, missing_dt$study)],
        interview_date
      )
    )
}

#' Statistical mode for Date vectors, returning the earliest in case of ties
#'
#' @param x A vector coercible to Date. NAs are removed before computation.
#' @return A single Date (the mode), or `NA_Date_` if input is all-NA/empty.
stat_mode_unique <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) return(NA_Date_)
  x <- as.Date(x)
  t <- table(x)
  modes <- names(t)[t == max(t)]
  # choose earliest among the tied modes
  as.Date(min(modes))
}



#' Parse messy interview date strings into POSIXct
#'
#' Handles weekday prefixes, ordinal suffixes, missing spaces, and multiple
#' date formats (DMY, dmy, d/m/Y, Y-m-d, etc.). English locale assumed.
#'
#' @param x Character vector of raw interview date strings.
#' @return POSIXct vector of parsed dates (NA where parsing fails).
clean_interview_date <- function(x) {
  x <- trimws(x)
  
  # 1. Turn explicit non-dates into NA
  x[x %in% c("Data not available", "")] <- NA_character_
  
  # 2. Drop weekday at the start, with or without comma:
  #    "Monday 15 March 2004" or "Monday, 15th March 2004"
  x <- str_remove(x, "^[A-Za-z]+,?\\s+")
  # (Works even for "Wedneday," etc., we just kill the first word.)
  
  # 3. Insert space between month and year if missing, e.g. "March2014"
  x <- gsub("([A-Za-z]+)(\\d{4})", "\\1 \\2", x, perl = TRUE)
  
  # 4. Remove ordinal suffixes: 1st, 2nd, 3rd, 4th, 12nd, 31th, etc.
  x <- gsub("(?<=\\d)(st|nd|rd|th)", "", x, perl = TRUE)
  
  # 5. Parse with multiple possible formats
  parse_date_time(
    x,
    orders = c(
      "d B Y",   # 15 March 2014
      "d b Y",   # 15 Mar 2014
      "d B y",   # 15 March 14
      "d b y",   # 15 Mar 14
      "d-m-y",   # 15-Jun-21
      "d/m/Y",   # 15/06/2021
      "d/m/y",   # 15/06/21
      "Y-m-d"    # 2021-06-15
    ),
    locale = "en_GB"  # month/day names are English
  )
}
