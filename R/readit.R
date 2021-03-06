#' Read Files of Any Type
#'
#' Given a file path, read the data into R, regardless of file type/extension.
#' `readit` is a thick wrapper around many of the
#' [tidyverse](https://www.tidyverse.org/) libraries, but can be forced to use
#' base functions where possible. Note that the caveat is that the file
#' _**needs**_ to have an extension, as well as be of a relatively common type.
#' "Common types" are any file type that can be handled by the
#' [readr](https://cran.r-project.org/package=readr), [readxl](https://cran.r-project.org/package=readxl),
#' or [haven](https://cran.r-project.org/package=haven) packages.
#'
#' @param .data File path to read data from.
#' @param ... Additional arguments passed to tidyverse read functions, e.g.
#'   `sheet`, `n_max`, etc.
#' @param tidyverse Should `readit` use functions available in the tidyverse,
#'   e.g. functions from `readr`, etc.? Defaults to `TRUE`.
#'
#' @examples
#' readit(system.file("examples", "csv.csv", package = "readit"))
#' readit(system.file("examples", "tab_sep.txt", package = "readit"))
#' readit(system.file("examples", "semi_sep.txt", package = "readit"))
#' readit(system.file("examples", "xlsx.xlsx", package = "readit"))
#' readit(system.file("examples", "xls.xls", package = "readit"))
#' readit(system.file("examples", "iris.sas7bdat", package = "readit"))
#'
#' @export
readit <- function(.data, ..., tidyverse = TRUE) {

  dots <- list(...)
  if ("delim" %in% names(dots))
    stop(red$bold("If you're going to specify a delimiter, just use a specialized function!"))

  ext <- tolower(tools::file_ext(.data))

  if (tidyverse) {

    if (ext == "txt") {
      guess_txt(.data)
    } else if (ext == "csv") {
      .read_fun$read_guess <- "CSV"
      .read_fun$read_fun <- function(x, ...) read_csv(x, ...)
    } else if (grepl("xls", ext)) {
      .read_fun$read_guess <- "xls/xlsx (Excel)"
      .read_fun$read_fun <- function(x, ...) read_excel(x, ...)
    } else if (grepl("^dta$|^sas7|^sav$|^por$", ext)) {
      guess_haven(.data)
    } else if (ext == "json") {
      .read_fun$read_guess <- "JSON"
      .read_fun$read_fun <- function(x, ...) read_json(x, simplifyVector = TRUE, ...)
    } else {
      stop(red$bold("Unrecognized file extension, or file does not exist"))
    }

  } else {
    stop(red$bold("Currently, only tidyverse functions are supported."))
  }

  message(green$bold(sprintf("File guessed to be %s (%s)",
                             .read_fun$read_guess, deparse(substitute(.data)))))
  .read_fun$read_fun(.data, ...)

}



#' Guess ".txt" Delimiter
#'
#' Since a `.txt` file is of ambiguous delimitation, this function is a helper
#' for [readit()] to guess the type, and return the appropriate reader.
#'
#' @param .data Data to guess/read
#'
#' @return A reader function, and its label
guess_txt <- function(.data) {

  # Make sure then names are verbose, for sending console messages
  delims <- list(
    "comma-delimited" = function(x, ...) read_csv(x, ...),
    "tab-delimited" = function(x, ...) read_tsv(x, ...),
    "semi-delimited" = function(x, ...) read_csv2(x, ...),
    "pipe-delimited" = function(x, ...) read_delim(x, delim = "|", trim_ws = TRUE, ...),
    "space-delimited" = function(x, ...) read_table2(x, ...))

  n_max <- 100
  delims_test <- list(
    "comma-delimited" = function(x) read_csv(x, n_max = n_max),
    "tab-delimited" = function(x) read_tsv(x, n_max = n_max),
    "semi-delimited" = function(x) read_csv2(x, n_max = n_max),
    "pipe-delimited" = function(x) read_delim(x, delim = "|", n_max = n_max),
    "space-delimited" = function(x) read_table2(x, n_max = n_max))

  best_delim <- lapply(delims_test, function(y)
    length(colnames(suppressMessages(suppressWarnings(y(.data))))))
  best_delim <- unlist(best_delim)

  # Space-delimited may return many columns erroneously, so depending on how
  # many non-single-col results are returned, use:
  # 1) The second-highest-col-count option (or, the first-appearing, if a tie);
  # 2) The ONLY option;
  # 3) Throw an error

  best_delim <- best_delim[best_delim != 1]

  if (length(best_delim) > 1) {
    best_delim <- names(best_delim[which(best_delim == min(best_delim))])[1]
  } else if (length(best_delim) == 1) {
    best_delim <- names(best_delim)
  } else if (length(best_delim) == 0) {
    stop(red$bold$bgWhite("Whoah, the delimiters are super weird in this file; I can't parse it!"))
  }

  .read_fun$read_guess <- best_delim
  .read_fun$read_fun <- delims[[best_delim]]

}



#' Guess File Type to Pass to `haven` Readers
#'
#' This function is a helper for [readit()] to guess the type of file that can
#' be passed to an appropriate reader from [haven](https://cran.r-project.org/package=haven).
#'
#' @param .data Data to guess/read
#'
#' @return A reader function, and its label
guess_haven <- function(.data) {
  ext <- tolower(tools::file_ext(.data))
  if (ext == "dta") {
    .read_fun$read_guess <- "DTA (Stata)"
    .read_fun$read_fun <- function(x, ...) read_dta(x, ...)
  } else if (grepl("sas7", ext)) {
    .read_fun$read_guess <- ".sas7b*at (SAS)"
    .read_fun$read_fun <- function(x, ...) read_sas(x, ...)
  } else if (grepl("sav", ext)) {
    .read_fun$read_guess <- "SAV (SPSS)"
    .read_fun$read_fun <- function(x, ...) read_sav(x, ...)
  } else if (grepl("por", ext)) {
    .read_fun$read_guess <- "POR (SPSS)"
    .read_fun$read_fun <- function(x, ...) read_por(x, ...)
  }
}
