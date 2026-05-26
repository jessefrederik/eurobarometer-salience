# Requires: haven, tidyverse, retroharmonize (loaded by core_micro.R)

#' Split a vector into chunks of size n
#'
#' @param x A vector to split.
#' @param n Maximum chunk size.
#' @return A list of sub-vectors, each of length <= n.
chunk_vec <- function(x, n) {
  if (length(x) == 0) return(list())
  split(x, ceiling(seq_along(x) / n))
}

#' Read Eurobarometer RDS survey files in chunks and extract metadata
#'
#' Uses `retroharmonize::read_surveys()` and `metadata_create()` to build a
#' combined metadata data frame. Optionally filters to retain only variables
#' relevant to the salience analysis (important issues, demographics, weights,
#' country codes, interview dates).
#'
#' @param folder_path Path to directory containing `.rds` survey files.
#' @param pattern Regex pattern for matching survey files (default `"\\.rds$"`).
#' @param chunk_size Number of files to process per chunk (default 10).
#' @param read_fun Read function name passed to `read_surveys(.f=)`.
#' @param apply_filter If TRUE, filter metadata to relevant variables.
#' @param verbose If TRUE, print progress messages.
#' @return A tibble of deduplicated metadata rows.
eb_metadata_all <- function(
    folder_path,
    pattern = "\\.rds$",
    chunk_size = 10,
    read_fun = "read_rds",     # passed to retroharmonize::read_surveys(.f=)
    apply_filter = TRUE,
    verbose = TRUE
) {
  files <- list.files(folder_path, pattern = pattern, full.names = TRUE)
  if (length(files) == 0) {
    warning("No files found matching pattern in folder_path.")
    return(tibble())
  }
  
  chunks <- chunk_vec(files, chunk_size)
  meta_chunks <- vector("list", length(chunks))
  
  for (i in seq_along(chunks)) {
    if (verbose) message(sprintf("Processing chunk %d/%d (%d files)...", 
                                 i, length(chunks), length(chunks[[i]])))
    # Read a chunk of surveys
    surveys <- read_surveys(chunks[[i]], .f = read_fun)
    
    # (Optional) Document waves if you need that side effect
    # documented <- document_waves(surveys)
    
    # Build metadata for this chunk
    meta_list <- lapply(surveys, metadata_create)
    meta_df <- dplyr::bind_rows(meta_list)
    
    # Apply your filter logic (parentheses for clarity)
    if (apply_filter) {
      meta_df <- meta_df %>%
        dplyr::filter(
          (
            grepl("important issues|import issues", label_orig, ignore.case = TRUE) &
              !grepl("world power", label_orig, ignore.case = TRUE) &
              !grepl("pers", label_orig, ignore.case = TRUE) &
              !grepl("future", label_orig, ignore.case = TRUE) &
              !grepl("issues eu", label_orig, ignore.case = TRUE)
          ) |
            grepl("age exact", label_orig, ignore.case = TRUE) |
            grepl("gender", label_orig, ignore.case = TRUE) |
            grepl("education", label_orig, ignore.case = TRUE) |
            
            grepl("weight", label_orig, ignore.case = TRUE) |
            grepl("rowid", var_name_orig, ignore.case = TRUE) |
            (
              grepl("3166", label_orig, ignore.case = TRUE) 
               
            ) |
            grepl("date of interview", label_orig, ignore.case = TRUE) &
            !grepl("no data", label_orig, ignore.case = TRUE) &
            !grepl("month", label_orig, ignore.case = TRUE) &
            !grepl("day", label_orig, ignore.case = TRUE)
        )
    }
    
    meta_chunks[[i]] <- meta_df
  }
  
  # Bind all chunk-level metadata into one dataframe
  result <- dplyr::bind_rows(meta_chunks) %>%
    dplyr::distinct()
  
  if (verbose) message(sprintf("Done. Combined metadata rows: %d", nrow(result)))
  result
}


