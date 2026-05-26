#' Load and harmonize Eurobarometer survey data from RDS files
#'
#' For each survey file in `folder_path`, selects only variables listed in
#' `eb_meta`, coalesces duplicate columns mapping to the same `label_std`,
#' sanitizes haven-labelled and factor columns, and row-binds all surveys.
#' Interview date columns are converted to character via haven labels.
#'
#' @param folder_path Path to directory containing `.rds` survey files.
#' @param eb_meta Metadata data frame with columns `filename`, `var_name_orig`,
#'   and `label_std` (output of [eb_metadata_all()]).
#' @return A data frame (or data.table) with harmonized column names and a
#'   `study` column identifying the source survey.
load_filtered_rds <- function(folder_path, eb_meta) {
  # Requires: dplyr, stringr (loaded by core_micro.R via tidyverse)

  # list all rds files (full path)
  files <- list.files(folder_path, pattern = "\\.rds$", full.names = TRUE)
  
  # make sure filenames are basename() in eb_meta
  eb_meta <- eb_meta %>%
    mutate(filename = basename(filename))
  
  # keep only rows with a label_std (drop true junk if any)
  eb_meta <- eb_meta %>%
    filter(!is.na(label_std))
  
  # lookup: for each filename, which original vars do we need?
  vars_by_file <- split(eb_meta$var_name_orig, eb_meta$filename)
  
  # keep only files that actually have variables defined in eb_meta
  files <- files[basename(files) %in% names(vars_by_file)]
  if (length(files) == 0L) {
    return(dplyr::tibble())  # nothing to do
  }
  
  # helper to normalise column types
  sanitize_cols <- function(df) {
    df[] <- lapply(df, function(col) {
      # drop haven_labelled class but keep underlying values
      if (inherits(col, "haven_labelled")) {
        if (requireNamespace("haven", quietly = TRUE)) {
          col <- haven::zap_labels(col)    # keeps numeric/character, drops labels + class
        } else {
          col <- as.vector(col)           # fallback: just drop class/attributes
        }
      }
      
      # factors -> character to avoid factor/character clashes
      if (is.factor(col)) {
        col <- as.character(col)
      }
      
      col
    })
    df
  }
  
  # little base coalesce for data.frame columns
  fcoalesce <- function(df_cols) {
    res <- df_cols[[1]]
    if (ncol(df_cols) == 1L) return(res)
    for (j in 2:ncol(df_cols)) {
      idx <- is.na(res)
      if (any(idx)) {
        res[idx] <- df_cols[[j]][idx]
      }
    }
    res
  }
  
  # helper: convert haven_labelled vector to its labels (character)
  labelled_to_labels <- function(x) {
    labs <- attr(x, "labels")
    if (is.null(labs)) return(as.character(x))
    # match underlying values to label vector
    names(labs)[match(x, labs)]
  }
  
  # preallocate list
  eb_list <- vector("list", length(files))
  
  for (i in seq_along(files)) {
    f     <- files[i]
    fname <- basename(f)
    
    vars_needed <- unique(vars_by_file[[fname]])
    
    meta_file <- eb_meta %>%
      filter(filename == fname,
             var_name_orig %in% vars_needed)
    
    if (nrow(meta_file) == 0L) {
      eb_list[[i]] <- NULL
      next
    }
    
    # read RDS
    dat <- readRDS(f)
    
    vars_in_data <- intersect(meta_file$var_name_orig, names(dat))
    if (length(vars_in_data) == 0L) {
      eb_list[[i]] <- NULL
      next
    }
    
    dat_selected <- dat[, vars_in_data, drop = FALSE]
    rm(dat); gc(verbose = FALSE)
    
    ## --- SPECIAL CASE: interview_date -> use haven labels ---
    ## assumes label_std == "interview_date" for those vars
    interview_vars <- meta_file$var_name_orig[meta_file$label_std == "interview_date"]
    interview_vars <- intersect(interview_vars, names(dat_selected))
    
    if (length(interview_vars) > 0L) {
      for (v in interview_vars) {
        col <- dat_selected[[v]]
        if (inherits(col, "haven_labelled")) {
          dat_selected[[v]] <- labelled_to_labels(col)  # character labels
        } else {
          # still force to character for safety/consistency
          dat_selected[[v]] <- as.character(col)
        }
      }
    }
    ## --------------------------------------------------------
    
    dat_selected <- sanitize_cols(dat_selected)
    
    dat_selected$study <- substr(fname, 1, nchar(fname) - 4)
    ## This will tag every row with the original filename/wave.
    
    # --- now proceed with harmonisation ---
    for (lab in unique(meta_file$label_std)) {
      vars_lab <- meta_file$var_name_orig[meta_file$label_std == lab]
      vars_lab <- intersect(vars_lab, names(dat_selected))
      
      if (length(vars_lab) == 1L) {
        names(dat_selected)[match(vars_lab, names(dat_selected))] <- lab
      } else if (length(vars_lab) > 1L) {
        cols_df <- dat_selected[vars_lab]
        new_col <- fcoalesce(cols_df)
        dat_selected[[lab]] <- new_col
        dat_selected[vars_lab] <- NULL
      }
    }
    
    eb_list[[i]] <- dat_selected
  }
  
  # drop empty elements (if any)
  eb_list <- Filter(Negate(is.null), eb_list)
  if (length(eb_list) == 0L) {
    return(dplyr::tibble())
  }
  
  # row-bind with harmonised names
  if (requireNamespace("data.table", quietly = TRUE)) {
    out <- data.table::rbindlist(
      eb_list,
      use.names   = TRUE,
      fill        = TRUE,
      ignore.attr = TRUE
    )
  } else {
    out <- dplyr::bind_rows(eb_list)
  }
  
  rm(eb_list); gc(verbose = FALSE)
  out
}

