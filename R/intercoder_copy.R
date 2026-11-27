# jellyqda :: intercoder_copy.R -- qda_intercoder_copy(): blind copy of the
# project for a second coder (step 1 of an intercoder check). The copy keeps
# documents, segments, variables, code system and coding guideline, and
# drops codings, summaries, other memos and the audit trail.

#' Create a blind copy of the project for a second coder
#'
#' The first step of an intercoder check: the copy contains the same
#' documents (frozen texts), segments, document variables and code system
#' including the coding guideline -- but **no codings**, no Mayring
#' summaries, no summary grid and no audit trail, so the second person codes
#' "blind". Code memos (definitions, coding rules) are kept by default; other
#' memos only if requested in `keep_memos`. The active project is not changed.
#'
#' @param path File for the copy (the `.jellyqda` extension is added if
#'   missing). Must not exist yet unless `overwrite = TRUE`.
#' @param keep_memos Kinds of memos to keep in the copy: any of `"code"`,
#'   `"project"`, `"document"`, `"passage"`. Default only code memos.
#' @param overwrite Logical; replace an existing file.
#' @return Invisibly, the path of the copy.
#' @seealso [qda_intercoder()] to compare both projects afterwards.
#' @export
#' @examples
#' dir <- tempfile()
#' qda_open(file.path(dir, "coder_a.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path")
#' qda_code(1, "Career path", segment = 2)
#' copy <- qda_intercoder_copy(file.path(dir, "coder_b.jellyqda"))
#' qda_close()
#' qda_open(copy)
#' nrow(qda_codings())   # 0: coder B starts blind
#' qda_codes()$label     # same code system
#' qda_close()
qda_intercoder_copy <- function(path, keep_memos = "code", overwrite = FALSE) {
  con <- qda_con()
  keep_memos <- match.arg(keep_memos, c("code", "project", "document", "passage"),
                          several.ok = TRUE)
  path <- as.character(path)
  if (!grepl("\\.jellyqda$", path, ignore.case = TRUE)) path <- paste0(path, ".jellyqda")
  path <- normalizePath(path, mustWork = FALSE)
  if (identical(path, normalizePath(project_path(), mustWork = FALSE))) {
    stop("The copy cannot replace the active project.", call. = FALSE)
  }
  if (file.exists(path)) {
    if (!isTRUE(overwrite)) stop(sprintf("File exists: %s (use overwrite = TRUE).", path), call. = FALSE)
    unlink(path)
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  DBI::dbExecute(con, "VACUUM INTO ?", params = list(path))
  cc <- DBI::dbConnect(RSQLite::SQLite(), path)
  on.exit(DBI::dbDisconnect(cc), add = TRUE)
  DBI::dbWithTransaction(cc, {
    DBI::dbExecute(cc, "DELETE FROM codings")
    DBI::dbExecute(cc, "DELETE FROM summaries")
    DBI::dbExecute(cc, sprintf("DELETE FROM memos WHERE kind NOT IN (%s)",
                               paste0("'", keep_memos, "'", collapse = ",")))
    DBI::dbExecute(cc, "DELETE FROM events")
    DBI::dbAppendTable(cc, "events", data.frame(
      action = "intercoder_copy",
      details = as.character(.to_json(list(from = basename(project_path()),
                                           desc = .t("Blind-Kopie f\u00fcr die Intercoder-Pr\u00fcfung angelegt")))),
      created_at = .now(), stringsAsFactors = FALSE))
  })
  DBI::dbExecute(cc, "VACUUM")   # removed rows must not be recoverable from the file
  log_event("intercoder_copy", list(file = basename(path),
                                    desc = sprintf(.t("Blind-Kopie f\u00fcr Intercoder-Pr\u00fcfung: %s"),
                                                   basename(path))))
  invisible(path)
}
