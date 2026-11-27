# jellyqda :: query.R -- code queries ("complex coding retrieval")
#
#   qda_query()          passages that contain ALL of some codes, ANY of
#                        others and NONE of a third group -- optionally only
#                        in documents with certain variable values
#   qda_query_to_code()  code the hits with a (new) code, one undo step
#
# A passage is a unit of analysis (R/units.R): a segment (default, e.g. a
# speaker turn) or a whole document. A code counts with its subcodes unless
# subcodes = FALSE. The app shows this as the tab "Abfrage" in the analysis
# window (R/app_server_query.R).

#' Code ids a query term stands for: the code (path or unique label) and, if
#' `subcodes`, all codes below it.
#' @noRd
.query_ids <- function(term, tr, subcodes) {
  term <- as.character(term)
  id <- tr$id[tr$path == term]
  if (length(id) == 0) id <- tr$id[tr$label == term]
  if (length(id) == 0) stop(sprintf("No code found for '%s'.", term), call. = FALSE)
  if (length(id) > 1) stop(sprintf("'%s' matches several codes; use the path.", term), call. = FALSE)
  if (isTRUE(subcodes)) .code_descendants(tr, id) else id
}

#' Find passages by a combination of codes (AND / OR / NOT)
#'
#' Lists every passage (segment or document) that contains **all** codes in
#' `all`, **at least one** code in `any` and **none** of the codes in
#' `none` -- for example "Workload and Leadership in the same speaker turn,
#' but not Family", only among documents with `role = "nurse"`. This answers
#' questions such as "how do participants talk about A when B comes up too?"
#' and compares subgroups.
#'
#' @param all,any,none Codes (paths such as `"Motivation / Meaning"` or
#'   unique labels). At least one of `all` or `any` is needed.
#' @param vars Optional filter on document variables: a named list, e.g.
#'   `list(role = "nurse")` or `list(role = c("nurse", "doctor"))`.
#' @param unit `"segment"` (codes in the same segment) or `"document"`.
#' @param subcodes Logical; a code also counts when one of its subcodes is
#'   coded (default `TRUE`).
#' @param source Optional documents (ids or names) to search.
#' @param min_overlap Minimum number of characters a coding must overlap a
#'   passage.
#' @return A tibble, one row per hit: `source_id`, `source`, `segment`,
#'   `start`, `end`, `codes` (the queried codes present), `text`. Attribute
#'   `"info"`: the query and how many passages / documents were searched.
#' @seealso [qda_query_to_code()], [qda_cooccurrence()]
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", c("interview_01.txt", "interview_02.md"), package = "jellyqda"))
#' qda_code_add("Career path"); qda_code_add("Motivation"); qda_code_add("Team")
#' qda_code(1, "Career path", segment = 5); qda_code(1, "Motivation", segment = 5)
#' qda_code(1, "Motivation", segment = 7); qda_code(2, "Team", segment = 5)
#' qda_source_set_var(1, "role", "project lead")
#' qda_query(all = c("Career path", "Motivation"))        # both in the same segment
#' qda_query(any = c("Motivation", "Team"), none = "Career path")
#' qda_query(any = "Motivation", vars = list(role = "project lead"))
#' qda_close()
qda_query <- function(all = NULL, any = NULL, none = NULL, vars = NULL,
                      unit = c("segment", "document"), subcodes = TRUE,
                      source = NULL, min_overlap = 1L) {
  unit <- match.arg(unit)
  all <- unique(as.character(all)); any <- unique(as.character(any)); none <- unique(as.character(none))
  if (length(all) == 0 && length(any) == 0) stop("Give at least one code in `all` or `any`.", call. = FALSE)
  con <- qda_con()
  src <- DBI::dbGetQuery(con, "SELECT id, name FROM sources ORDER BY id")
  src$name <- .utf8(src$name)
  if (!is.null(source)) {
    ids <- vapply(source, function(s) .resolve_source(s)$id, numeric(1))
    src <- src[src$id %in% ids, , drop = FALSE]
  }
  # variable filter: every given variable must have one of the given values
  if (length(vars)) {
    av <- .all_source_vars()
    keep <- vapply(as.character(src$id), function(k) {
      v <- av[[k]]
      all(vapply(names(vars), function(key) !is.na(v[key]) && v[[key]] %in% as.character(vars[[key]]), logical(1)))
    }, logical(1))
    src <- src[keep, , drop = FALSE]
  }
  src$frozen_text <- .texts(src$id)
  tr <- .code_categories()
  terms <- c(all, any, none)
  members <- lapply(terms, .query_ids, tr = tr, subcodes = subcodes)
  units <- .units_for(src, unit)
  cd <- DBI::dbGetQuery(con, "SELECT source_id, code_id, start, end FROM codings")
  cd <- cd[cd$source_id %in% src$id, , drop = FALSE]
  # one column per query term: the term's codings (code + subcodes)
  rows <- lapply(seq_along(terms), function(k) {
    x <- cd[cd$code_id %in% members[[k]], c("source_id", "start", "end"), drop = FALSE]
    if (nrow(x)) data.frame(sid = x$source_id, start = x$start, end = x$end, cat = terms[k]) else NULL
  })
  marks <- do.call(rbind, rows)
  if (is.null(marks)) marks <- data.frame(sid = integer(), start = integer(), end = integer(), cat = character())
  M <- .mark_units(units, marks, terms, max(1L, as.integer(min_overlap)))
  col <- function(set) match(set, terms)
  hit <- rep(TRUE, nrow(units))
  if (length(all)) hit <- hit & rowSums(M[, col(all), drop = FALSE]) == length(all)
  if (length(any)) hit <- hit & rowSums(M[, col(any), drop = FALSE]) > 0
  if (length(none)) hit <- hit & rowSums(M[, col(none), drop = FALSE]) == 0
  idx <- which(hit)
  present <- vapply(idx, function(i) paste(terms[M[i, ] & terms %in% c(all, any)], collapse = ", "), character(1))
  u <- units[idx, , drop = FALSE]
  out <- tibble::tibble(source_id = as.integer(u$source_id), source = u$source, segment = as.integer(u$segment),
                        start = as.integer(u$start), end = as.integer(u$end), codes = present,
                        text = .passages(u$source_id, u$start, u$end))
  attr(out, "info") <- list(all = all, any = any, none = none, vars = vars, unit = unit,
                            subcodes = subcodes, units = nrow(units), documents = nrow(src))
  out
}

#' Code the hits of a query with a code
#'
#' Turns the result of [qda_query()] into codings: every hit (segment or
#' document) is coded with `code`. A code that does not exist yet is created
#' first (as a top-level code, or below `parent`). The codings form one action:
#' Ctrl+Z / [qda_undo()] removes them again (and a second undo the new code).
#' Hits that already carry this code over the same range are skipped.
#'
#' @param hits Result of [qda_query()].
#' @param code Code (path or unique label) or the label of a new code.
#' @param parent For a new code: its parent code (optional).
#' @return Invisibly, a tibble of the new codings.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path"); qda_code_add("Motivation")
#' qda_code(1, "Career path", segment = 5); qda_code(1, "Motivation", segment = 5)
#' hits <- qda_query(all = c("Career path", "Motivation"))
#' qda_query_to_code(hits, "Career and motivation")
#' qda_codings()[, c("code", "start", "end")]
#' qda_close()
qda_query_to_code <- function(hits, code, parent = NULL) {
  con <- qda_con()
  code <- as.character(code)
  tr <- .code_categories()
  cid <- tr$id[tr$path == code]
  if (length(cid) == 0) cid <- tr$id[tr$label == code]
  if (length(cid) > 1) stop(sprintf("'%s' matches several codes; use the path.", code), call. = FALSE)
  if (length(cid) == 0) cid <- qda_code_add(code, parent = parent)$id
  if (nrow(hits) == 0) return(invisible(tibble::tibble(id = integer(), source_id = integer(),
                                                       code_id = integer(), start = integer(), end = integer())))
  have <- DBI::dbGetQuery(con, "SELECT source_id, start, end FROM codings WHERE code_id = ?", params = list(cid))
  new <- hits[!paste(hits$source_id, hits$start, hits$end) %in% paste(have$source_id, have$start, have$end), , drop = FALSE]
  ids <- integer(nrow(new))
  if (nrow(new)) {
    DBI::dbWithTransaction(con, {
      for (i in seq_len(nrow(new))) {
        DBI::dbExecute(con, "INSERT INTO codings (source_id, code_id, start, end, memo) VALUES (?, ?, ?, ?, '')",
                       params = list(new$source_id[i], as.integer(cid), new$start[i], new$end[i]))
        ids[i] <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
      }
    })
    label <- DBI::dbGetQuery(con, "SELECT label FROM codes WHERE id = ?", params = list(cid))$label
    log_event("coding_add", list(code_id = cid, query = TRUE, n = length(ids)),
              changes = list(.chg("codings", .snap("codings", integer()), .snap("codings", ids))),
              desc = sprintf(.t("Abfrage-Treffer codiert: %d Stellen mit '%s'"), length(ids), .utf8(label)))
  }
  invisible(tibble::tibble(id = ids, source_id = as.integer(new$source_id), code_id = as.integer(cid),
                           start = as.integer(new$start), end = as.integer(new$end)))
}
