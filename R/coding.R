# Codings --------------------------------------------------------------------

#' Assign a code to a passage of a source
#'
#' Address a passage either by **segment number** (as shown in
#' [qda_view()]) or by explicit 1-based character offsets `start`/`end` into
#' the frozen text. Offsets are validated against the frozen text, so a
#' coding can never point outside the source.
#'
#' @param source Source id or unique name.
#' @param code Code id or unique label.
#' @param segment Segment number (see [qda_view()]). Mutually exclusive with
#'   `start`/`end`.
#' @param start,end 1-based inclusive character offsets into the frozen text.
#' @param memo Optional memo attached to this coding.
#' @return Invisibly, a one-row tibble describing the new coding.
#' @export
#' @examples
#' \dontrun{
#' qda_code(source = 1, segment = 3, code = "Beruflicher Werdegang")
#' qda_code(source = "interview_01.txt", start = 120, end = 340,
#'          code = "KMU", memo = "5 Jahre KMU")
#' }
qda_code <- function(source, code, segment = NULL, start = NULL, end = NULL, memo = "") {
  con <- qda_con()
  src <- .resolve_source(source)
  cod <- .resolve_code(code)
  if (!is.null(segment)) {
    if (!is.null(start) || !is.null(end)) {
      stop("Use either `segment` or `start`/`end`, not both.", call. = FALSE)
    }
    segs <- .segments_of(src$frozen_text)
    hit <- segs[segs$segment == as.integer(segment), , drop = FALSE]
    if (nrow(hit) == 0) {
      stop(sprintf("Source '%s' has no segment %s (it has %d).",
                   src$name, segment, nrow(segs)), call. = FALSE)
    }
    start <- hit$start; end <- hit$end
  }
  if (is.null(start) || is.null(end)) {
    stop("Provide either `segment` or both `start` and `end`.", call. = FALSE)
  }
  start <- as.integer(start); end <- as.integer(end)
  n <- nchar(src$frozen_text, type = "chars")
  if (is.na(start) || is.na(end) || start < 1L || end > n || start > end) {
    stop(sprintf("Invalid offsets start=%s, end=%s for source '%s' (%d chars).",
                 start, end, src$name, n), call. = FALSE)
  }
  DBI::dbExecute(
    con,
    "INSERT INTO codings (source_id, code_id, start, end, memo) VALUES (?, ?, ?, ?, ?)",
    params = list(src$id, cod$id, start, end, as.character(memo))
  )
  id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
  log_event("coding_add", list(coding_id = id, source_id = src$id, code_id = cod$id,
                               start = start, end = end, memo = as.character(memo)))
  invisible(tibble::tibble(id = id, source_id = src$id, code_id = cod$id,
                           start = start, end = end, memo = as.character(memo)))
}

#' List all codings (optionally filtered)
#'
#' @param source Optional source id or name to filter by.
#' @param code Optional code id or label to filter by.
#' @return A tibble: `id`, `source_id`, `source`, `code_id`, `code`, `start`,
#'   `end`, `memo`, `text` (the coded passage extracted from the frozen
#'   text).
#' @export
qda_codings <- function(source = NULL, code = NULL) {
  con <- qda_con()
  df <- DBI::dbGetQuery(con, "
    SELECT c.id, c.source_id, s.name AS source, c.code_id, k.label AS code,
           c.start, c.end, c.memo, s.frozen_text
    FROM codings c
    JOIN sources s ON s.id = c.source_id
    JOIN codes k ON k.id = c.code_id
    ORDER BY c.source_id, c.start, c.id")
  df$frozen_text <- .utf8(df$frozen_text)
  if (!is.null(source)) df <- df[df$source_id == .resolve_source(source)$id, , drop = FALSE]
  if (!is.null(code)) df <- df[df$code_id == .resolve_code(code)$id, , drop = FALSE]
  tibble::tibble(
    id = df$id, source_id = df$source_id, source = df$source,
    code_id = df$code_id, code = df$code,
    start = df$start, end = df$end, memo = df$memo,
    text = substring(df$frozen_text, df$start, df$end)
  )
}

#' Set / change the memo of an existing coding
#'
#' @param coding Coding id.
#' @param memo New memo text.
#' @return Invisibly, a one-row tibble with the updated coding.
#' @export
qda_coding_set_memo <- function(coding, memo) {
  con <- qda_con()
  row <- .resolve_coding(coding)
  DBI::dbExecute(con, "UPDATE codings SET memo = ? WHERE id = ?",
                 params = list(as.character(memo), row$id))
  log_event("coding_memo", list(coding_id = row$id, memo = as.character(memo)))
  invisible(tibble::tibble(id = row$id, source_id = row$source_id, code_id = row$code_id,
                           start = row$start, end = row$end, memo = as.character(memo)))
}

#' Delete a coding
#'
#' @param coding Coding id.
#' @return Invisibly `NULL`.
#' @export
qda_coding_delete <- function(coding) {
  con <- qda_con()
  row <- .resolve_coding(coding)
  DBI::dbExecute(con, "DELETE FROM codings WHERE id = ?", params = list(row$id))
  log_event("coding_delete", list(coding_id = row$id, source_id = row$source_id,
                                  code_id = row$code_id, start = row$start, end = row$end))
  invisible(NULL)
}

#' Retrieve all segments coded with a given code
#'
#' The "Retrieved Segments" view: every passage that received this code,
#' with source, offsets, extracted text and memo.
#'
#' @param code Code id or unique label.
#' @return A tibble: `id`, `source_id`, `source`, `code_id`, `code`, `start`,
#'   `end`, `text`, `memo`.
#' @export
#' @examples
#' \dontrun{
#' qda_segments("Beruflicher Werdegang")
#' }
qda_segments <- function(code) {
  con <- qda_con()
  cod <- .resolve_code(code)
  df <- DBI::dbGetQuery(con, "
    SELECT c.id, c.source_id, s.name AS source, c.code_id, k.label AS code,
           c.start, c.end, c.memo, s.frozen_text
    FROM codings c
    JOIN sources s ON s.id = c.source_id
    JOIN codes k ON k.id = c.code_id
    WHERE c.code_id = ?
    ORDER BY c.source_id, c.start", params = list(cod$id))
  df$frozen_text <- .utf8(df$frozen_text)
  tibble::tibble(
    id = df$id, source_id = df$source_id, source = df$source,
    code_id = df$code_id, code = df$code,
    start = df$start, end = df$end, memo = df$memo,
    text = substring(df$frozen_text, df$start, df$end)
  )
}
