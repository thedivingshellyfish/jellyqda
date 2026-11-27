# jellyqda :: summary.R -- summary grid cells: qda_summary_set()/qda_summaries()
# One summary text per (code, source); UNIQUE constraint in schema.R.

# Summary grid (V2) ------------------------------------------------------------
# One editable summary text per (code, source) cell -- the "Summary Grid" of
# the concept (section 6, V2). Stored in the `summaries` table, audited.

#' Set the summary text for a code x source cell (Summary Grid)
#'
#' Creates or overwrites the summary of one cell. Empty text clears the cell.
#'
#' @param code Code id or unique label.
#' @param source Source id or unique name.
#' @param text_ Summary text.
#' @return Invisibly, a one-row tibble with the stored summary.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path")
#' qda_code_add("SME", parent = "Career path")
#' qda_code(1, "SME", segment = 2)
#' qda_summary_set("SME", 1, "Strongly shaped by the first employer.")
#' qda_summaries()
#' qda_close()
qda_summary_set <- function(code, source, text_) {
  con <- qda_con()
  cod <- .resolve_code(code)
  src <- .resolve_source(source)
  sum_id <- function() DBI::dbGetQuery(con,
    "SELECT id FROM summaries WHERE code_id = ? AND source_id = ?",
    params = list(cod$id, src$id))$id
  before <- .snap("summaries", sum_id())
  DBI::dbExecute(con, "
    INSERT INTO summaries (code_id, source_id, text_, updated_at)
    VALUES (?, ?, ?, ?)
    ON CONFLICT(code_id, source_id) DO UPDATE SET
      text_ = excluded.text_, updated_at = excluded.updated_at",
    params = list(cod$id, src$id, as.character(text_), .now()))
  log_event("summary_set", list(code_id = cod$id, source_id = src$id,
                                text = as.character(text_)),
            changes = list(.chg("summaries", before, .snap("summaries", sum_id()))),
            desc = sprintf(.t("Summary ge\u00e4ndert: '%s' x %s"), cod$label, src$name))
  invisible(tibble::tibble(code_id = cod$id, source_id = src$id,
                           text_ = as.character(text_), updated_at = .now()))
}

#' Get one summary cell (or all summaries)
#'
#' @param code Optional code id/label; with `source` returns that single cell.
#' @param source Optional source id/name.
#' @return A tibble: `code_id`, `code`, `source_id`, `source`, `text_`,
#'   `updated_at`.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path")
#' qda_code_add("SME", parent = "Career path")
#' qda_summary_set("SME", 1, "Strongly shaped by the first employer.")
#' qda_summaries()
#' qda_close()
qda_summaries <- function(code = NULL, source = NULL) {
  con <- qda_con()
  df <- DBI::dbGetQuery(con, "
    SELECT s.code_id, k.label AS code, s.source_id, src.name AS source,
           s.text_, s.updated_at
    FROM summaries s
    JOIN codes k ON k.id = s.code_id
    JOIN sources src ON src.id = s.source_id
    ORDER BY k.id, src.id")
  if (!is.null(code)) df <- df[df$code_id == .resolve_code(code)$id, , drop = FALSE]
  if (!is.null(source)) df <- df[df$source_id == .resolve_source(source)$id, , drop = FALSE]
  tibble::tibble(code_id = df$code_id, code = df$code, source_id = df$source_id,
                 source = df$source, text_ = df$text_, updated_at = df$updated_at)
}
