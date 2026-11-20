# Export ---------------------------------------------------------------------

#' Export segments, codebook, codings or the audit trail
#'
#' Writes files into `path` (default: `exports/` next to the project file).
#'
#' * `"segments"`: all codings with extracted text -- CSV, plus `.xlsx` if the
#'   `writexl` package is installed
#' * `"codings"`: raw codings table -- CSV
#' * `"codebook"`: the code tree -- CSV and `.docx` (via officer)
#' * `"audit"`: the full events audit trail -- CSV
#' * `"all"`: all of the above
#'
#' @param what One or more of `"all"`, `"segments"`, `"codings"`, `"codebook"`,
#'   `"audit"`.
#' @param path Output directory (created if missing).
#' @return Invisibly, a tibble of written files: `file`, `what`, `rows`.
#' @export
#' @examples
#' \dontrun{
#' qda_export("all")
#' qda_export("audit")   # for the methods section
#' }
qda_export <- function(what = "all", path = NULL) {
  con <- qda_con()
  what <- match.arg(what, c("all", "segments", "codings", "codebook", "audit"),
                    several.ok = TRUE)
  if ("all" %in% what) what <- c("segments", "codings", "codebook", "audit")
  dir <- path %||% file.path(project_dir(), "exports")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  ts <- format(Sys.time(), "%Y%m%d-%H%M%S", tz = "UTC")
  written <- list()
  add <- function(file, what_, rows) {
    written[[length(written) + 1]] <<- tibble::tibble(file = file, what = what_, rows = rows)
  }
  if ("segments" %in% what) {
    df <- qda_codings()
    f <- file.path(dir, paste0("segments_", ts, ".csv"))
    readr::write_csv(df, f)
    add(f, "segments", nrow(df))
    if (requireNamespace("writexl", quietly = TRUE)) {
      f2 <- file.path(dir, paste0("segments_", ts, ".xlsx"))
      writexl::write_xlsx(as.data.frame(df), f2)
      add(f2, "segments", nrow(df))
    }
  }
  if ("codings" %in% what) {
    df <- DBI::dbGetQuery(con, "SELECT * FROM codings ORDER BY id")
    f <- file.path(dir, paste0("codings_", ts, ".csv"))
    readr::write_csv(df, f)
    add(f, "codings", nrow(df))
  }
  if ("codebook" %in% what) {
    df <- qda_codes()
    f <- file.path(dir, paste0("codebook_", ts, ".csv"))
    readr::write_csv(df, f)
    add(f, "codebook", nrow(df))
    doc <- officer::read_docx()
    doc <- officer::body_add_par(doc, "jellyqda codebook", style = "heading 1")
    if (nrow(df) > 0) {
      for (i in seq_len(nrow(df))) {
        line <- paste0(df$path[i], if (nzchar(df$description[i])) paste0(" -- ", df$description[i]) else "")
        doc <- officer::body_add_par(doc, line)
      }
    }
    f2 <- file.path(dir, paste0("codebook_", ts, ".docx"))
    print(doc, target = f2)
    add(f2, "codebook", nrow(df))
  }
  if ("audit" %in% what) {
    df <- DBI::dbGetQuery(con, "SELECT id, action, details, created_at FROM events ORDER BY id")
    f <- file.path(dir, paste0("audit_", ts, ".csv"))
    readr::write_csv(df, f)
    add(f, "audit", nrow(df))
  }
  files <- vapply(written, function(w) w$file, character(1))
  log_event("export", list(what = what, files = files))
  invisible(do.call(rbind, written))
}
