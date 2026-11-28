# jellyqda :: pseudonymise.R -- replace names while importing
#
#   qda_pseudonyms()            read a key list (CSV / Excel / "A = B" lines /
#                               named vector) into original -> replacement
#   qda_pseudonymise_preview()  how often each name would be replaced, per
#                               file, without importing anything
#   .pseudo_apply()             the replacement itself (used by qda_import()
#                               and qda_import_survey(), argument pseudonyms)
#
# The text of a document is frozen at import and can never be changed
# afterwards (offsets must stay stable). So pseudonymisation has to happen
# BEFORE the text is frozen -- that is what this file is for.
# What is NOT stored anywhere in the project: the key list, the original
# names, the original file (originals/ is skipped for pseudonymised
# imports). The audit trail only records how many replacements were made.
# Keep your key list in a separate, safe place.

#' Read a key list for pseudonymisation
#'
#' A key list says which real names (people, places, organisations ...) are
#' replaced by which placeholder. It can be
#' * a CSV, TSV or Excel file with two columns: original, replacement (a
#'   header line is fine),
#' * text lines like `"Anna Schmidt = [Person A]"`,
#' * a named character vector `c("Anna Schmidt" = "[Person A]")`.
#'
#' Longer names are replaced first, so "Anna Schmidt" wins over "Anna".
#'
#' @param x The key list (see above).
#' @param whole_word Logical; only replace whole words (default `TRUE`, so
#'   "Ina" does not hit "Martina").
#' @param ignore_case Logical; also replace "ANNA" and "anna" (default
#'   `FALSE`).
#' @return A named character vector (names = originals) with the matching
#'   options as attributes; pass it to `qda_import(pseudonyms = ...)`.
#' @seealso [qda_import()], [qda_pseudonymise_preview()]
#' @export
#' @examples
#' key <- qda_pseudonyms(c("Anna Schmidt = [Person A]", "Hamburg = [City 1]", "Anna = [Person A]"))
#' key
#' f <- file.path(tempdir(), "key.csv")
#' writeLines(c("original,replacement", "Anna Schmidt,[Person A]"), f)
#' qda_pseudonyms(f)
qda_pseudonyms <- function(x, whole_word = TRUE, ignore_case = FALSE) {
  if (!is.null(attr(x, "jq_pseudonyms"))) return(x)
  key <- if (!is.null(names(x)) && all(nzchar(names(x)))) {
    stats::setNames(as.character(x), names(x))
  } else if (length(x) == 1 && !grepl("=", x, fixed = TRUE) && file.exists(x)) {
    ext <- tolower(tools::file_ext(x))
    df <- if (ext %in% c("xlsx", "xls")) {
      if (!requireNamespace("readxl", quietly = TRUE)) stop("Reading Excel files needs the package 'readxl'.", call. = FALSE)
      as.data.frame(readxl::read_excel(x, col_names = FALSE, col_types = "text"))
    } else {
      utils::read.delim(x, sep = if (ext == "tsv") "\t" else if (grepl(";", readLines(x, n = 1, warn = FALSE))) ";" else ",",
                        header = FALSE, colClasses = "character", encoding = "UTF-8", quote = "\"", strip.white = TRUE)
    }
    if (ncol(df) < 2) stop("The key list needs two columns: original, replacement.", call. = FALSE)
    df[] <- lapply(df, function(col) .utf8(as.character(col)))   # key lists are UTF-8 files
    df <- df[!is.na(df[[1]]) & nzchar(df[[1]]), , drop = FALSE]
    if (nrow(df) && tolower(df[[1]][1]) %in% c("original", "name", "real", "klarname", "von", "from")) df <- df[-1, , drop = FALSE]
    stats::setNames(ifelse(is.na(df[[2]]), "", df[[2]]), df[[1]])
  } else {
    lines <- unlist(strsplit(as.character(x), "\n", fixed = TRUE))
    lines <- trimws(lines[grepl("=", lines, fixed = TRUE)])
    kv <- regmatches(lines, regexpr("=", lines, fixed = TRUE), invert = TRUE)
    stats::setNames(trimws(vapply(kv, `[`, character(1), 2)), trimws(vapply(kv, `[`, character(1), 1)))
  }
  key <- key[nzchar(names(key))]
  names(key) <- stringi::stri_trans_nfc(names(key)); key[] <- stringi::stri_trans_nfc(key)
  key <- key[!duplicated(names(key))]
  key <- key[order(-nchar(names(key)), names(key))]          # longest first
  structure(key, jq_pseudonyms = TRUE, whole_word = isTRUE(whole_word), ignore_case = isTRUE(ignore_case))
}

#' Replace every original of `key` in `text` (vectorised over text).
#' Two passes via placeholders, so a replacement is never replaced again.
#' @return list(text, counts = named integer per original, summed over text)
#' @noRd
.pseudo_apply <- function(text, key) {
  counts <- stats::setNames(integer(length(key)), names(key))
  if (length(key) == 0) return(list(text = text, counts = counts))
  esc <- function(s) gsub("([.\\\\|()\\[\\]{}^$*+?])", "\\\\\\1", s, perl = TRUE)
  pre <- if (isTRUE(attr(key, "whole_word"))) "(?<![\\p{L}\\p{N}])" else ""
  post <- if (isTRUE(attr(key, "whole_word"))) "(?![\\p{L}\\p{N}])" else ""
  flags <- if (isTRUE(attr(key, "ignore_case"))) "(?i)" else ""
  for (k in seq_along(key)) {
    re <- paste0(flags, pre, esc(names(key)[k]), post)
    hits <- gregexpr(re, text, perl = TRUE)
    counts[k] <- sum(vapply(hits, function(h) sum(h > 0), integer(1)))
    if (counts[k] > 0) text <- gsub(re, sprintf("\001%d\002", k), text, perl = TRUE)
  }
  for (k in seq_along(key)) text <- gsub(sprintf("\001%d\002", k), key[[k]], text, fixed = TRUE)
  list(text = text, counts = counts)
}

#' Preview a pseudonymisation
#'
#' Reads the files like [qda_import()] would and counts how often each name
#' of the key list would be replaced -- nothing is imported. Use it to check
#' the key list: a name with 0 hits is perhaps spelled differently in the
#' transcript.
#'
#' @param files Paths of `.txt`, `.md`, `.docx` or `.pdf` files.
#' @param pseudonyms Key list, see [qda_pseudonyms()].
#' @return A tibble: `file`, `original`, `replacement`, `n` (replacements).
#' @export
#' @examples
#' f <- file.path(tempdir(), "interview_anna.txt")
#' writeLines(c("I: Anna, how did you start?", "Anna: In Hamburg, with Ben."), f)
#' qda_pseudonymise_preview(f, c("Anna" = "[Person A]", "Hamburg" = "[City 1]", "Ben" = "[Person B]"))
qda_pseudonymise_preview <- function(files, pseudonyms) {
  key <- qda_pseudonyms(pseudonyms)
  rows <- lapply(normalizePath(as.character(files), mustWork = TRUE), function(f) {
    fmt <- tolower(tools::file_ext(f))
    ex <- switch(fmt, txt = , md = .read_text_file(f), docx = .read_docx_file(f), pdf = .read_pdf_file(f),
                 stop(sprintf("Unsupported format '.%s' (%s).", fmt, basename(f)), call. = FALSE))
    r <- .pseudo_apply(c(.normalize_text(ex$text), basename(f)), key)
    tibble::tibble(file = basename(f), original = names(key), replacement = unname(key), n = unname(r$counts))
  })
  do.call(rbind, rows)
}
