#' Classify raw Eurobarometer variable labels into standardized issue names
#'
#' Iterates through `issue_patterns` (defined in `regex_issues.R`) and assigns
#' the first matching `label_std` to each element. Labels matching
#' `drop_patterns` are set to NA. Uses first-match-wins semantics.
#'
#' @param x Character vector of cleaned variable labels.
#' @return Character vector of standardized issue names (or NA for unmatched).
harmonize_issue <- function(x) {
  res <- rep(NA_character_, length(x))
  if (nzchar(drop_patterns)) {
    res[str_detect(x, drop_patterns)] <- NA_character_
  }
  for (i in seq_len(nrow(issue_patterns))) {
    hit <- is.na(res) & str_detect(x, issue_patterns$pattern[i])
    res[hit] <- issue_patterns$label_std[i]
  }
  res
}
