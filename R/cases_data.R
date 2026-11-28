# jellyqda :: cases_data.R -- which codings belong to which case
#
# Internal helpers for everything that counts or filters by case
# (qda_case_matrix(unit = "case"), qda_query(case = ...), export, report):
#   .case_ranges()   every case as character ranges (a whole document =
#                    1 .. length of the text)
#   .coding_cases()  pairs (coding, case): a coding belongs to a case when it
#                    overlaps one of the case's ranges by >= min_overlap chars
# A coding can belong to several cases (e.g. a passage both speakers share).

#' All cases as ranges: case_id, case, source_id, start, end.
#' @noRd
.case_ranges <- function(case_ids = NULL) {
  m <- DBI::dbGetQuery(qda_con(), "SELECT m.case_id, c.name AS case_name, m.source_id, m.start, m.end
                                   FROM case_members m JOIN cases c ON c.id = m.case_id ORDER BY m.case_id, m.source_id, m.start")
  if (!is.null(case_ids)) m <- m[m$case_id %in% case_ids, , drop = FALSE]
  whole <- is.na(m$start)
  if (any(whole)) {
    len <- nchar(.texts(m$source_id[whole]), type = "chars")
    m$start[whole] <- 1L; m$end[whole] <- len
  }
  data.frame(case_id = as.integer(m$case_id), case = .utf8(m$case_name), source_id = as.integer(m$source_id),
             start = as.integer(m$start), end = as.integer(m$end), stringsAsFactors = FALSE)
}

#' Pairs (row of `cd`, case_id) for codings `cd` (source_id, start, end).
#' @noRd
.coding_cases <- function(cd, min_overlap = 1L, ranges = .case_ranges()) {
  empty <- data.frame(i = integer(), case_id = integer())
  if (nrow(cd) == 0 || nrow(ranges) == 0) return(empty)
  out <- lapply(seq_len(nrow(ranges)), function(k) {
    r <- ranges[k, ]
    ov <- pmin(cd$end, r$end) - pmax(cd$start, r$start) + 1L
    i <- which(cd$source_id == r$source_id & ov >= min_overlap)
    if (length(i)) data.frame(i = i, case_id = r$case_id) else NULL
  })
  out <- do.call(rbind, out)
  if (is.null(out)) empty else unique(out)
}

#' Does a passage (source_id, start, end) lie in one of the cases? (vectorised)
#' @noRd
.in_cases <- function(source_id, start, end, case_ids, min_overlap = 1L) {
  r <- .case_ranges(case_ids)
  hit <- logical(length(source_id))
  for (k in seq_len(nrow(r))) {
    ov <- pmin(end, r$end[k]) - pmax(start, r$start[k]) + 1L
    hit <- hit | (source_id == r$source_id[k] & ov >= min_overlap)
  }
  hit
}

#' Cases as one flat table (export, report): one row per member with the
#' case variables as columns.
#' @noRd
.cases_table <- function() {
  cs <- qda_cases()
  vars <- setdiff(names(cs), c("id", "name", "description", "documents", "passages", "sources"))
  rows <- lapply(seq_len(nrow(cs)), function(i) {
    m <- qda_case_members(cs$id[i])
    if (nrow(m) == 0) m <- tibble::tibble(source = NA_character_, start = NA_integer_, end = NA_integer_)
    out <- tibble::tibble(case = cs$name[i], description = cs$description[i], source = m$source, start = m$start, end = m$end)
    for (v in vars) out[[v]] <- cs[[v]][i]
    out
  })
  if (length(rows)) do.call(rbind, rows) else tibble::tibble(case = character(), description = character(),
                                                               source = character(), start = integer(), end = integer())
}
