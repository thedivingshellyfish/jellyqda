# jellyqda :: portrait.R -- qda_portrait(): the data of a document portrait
# (which codes in which segment, in text order). The strips are drawn by
# qda_plot_portrait() (R/plot_portrait.R) and shown in the app's graphics
# window and the report.

#' Document portrait: which codes appear where in a document
#'
#' Walks through every document segment by segment (in text order) and
#' lists the codes each segment contains. Drawn as a strip per document
#' ([qda_plot_portrait()]), this shows at a glance *where* in an interview a
#' theme comes up -- at the start, throughout, only at the end -- and makes
#' interviews comparable.
#'
#' @param source Optional documents (ids or names); default all.
#' @param level `"top"` (default: code families, one colour each) or
#'   `"code"` (every code and subcode).
#' @param min_overlap Minimum number of characters a coding must overlap a
#'   segment to count.
#' @return A tibble with one row per segment and code (segments without
#'   codes have `code = NA`): `source_id`, `source`, `segment`, `start`,
#'   `end`, `pos` (share of the document before the segment, 0--1),
#'   `width` (share of the document the segment takes), `code`, `color`.
#' @seealso [qda_plot_portrait()]
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path"); qda_code_add("Motivation")
#' qda_code(1, "Career path", segment = 3)
#' qda_code(1, "Motivation", segment = 7)
#' qda_portrait()
#' qda_close()
qda_portrait <- function(source = NULL, level = c("top", "code"), min_overlap = 1L) {
  level <- match.arg(level)
  con <- qda_con()
  src <- DBI::dbGetQuery(con, "SELECT id, name, frozen_text FROM sources ORDER BY id")
  src$frozen_text <- .utf8(src$frozen_text); src$name <- .utf8(src$name)
  if (!is.null(source)) {
    ids <- vapply(source, function(s) .resolve_source(s)$id, numeric(1))
    src <- src[src$id %in% ids, , drop = FALSE]
  }
  empty <- tibble::tibble(source_id = integer(), source = character(), segment = integer(),
                          start = integer(), end = integer(), pos = numeric(), width = numeric(),
                          code = character(), color = character())
  units <- .units_for(src, "segment")
  if (nrow(units) == 0) return(empty)
  tr <- .code_categories()
  cd <- DBI::dbGetQuery(con, "SELECT source_id, code_id, start, end FROM codings")
  cd <- cd[cd$source_id %in% src$id, , drop = FALSE]
  cd$sid <- cd$source_id
  cd$cat <- .category_of(tr, cd$code_id, level)
  keys <- unique(if (level == "top") tr$root_path else tr$path)
  cats <- keys[keys %in% cd$cat]
  M <- .mark_units(units, cd, cats, max(1L, as.integer(min_overlap)))
  # position along the document: characters before the segment / all characters
  len <- nchar(src$frozen_text, type = "chars")[match(units$source_id, src$id)]
  pos <- (units$start - 1) / len
  width <- (units$end - units$start + 1) / len
  col_of <- tr$root_color[match(cats, if (level == "top") tr$root_path else tr$path)]
  # one row per (segment, code) plus one row per uncoded segment -- vectorised
  hit <- if (length(cats)) which(M, arr.ind = TRUE) else matrix(integer(), ncol = 2)
  none <- which(if (length(cats)) rowSums(M) == 0 else rep(TRUE, nrow(units)))
  r <- data.frame(i = c(hit[, 1], none), j = c(hit[, 2], rep(NA_integer_, length(none))))
  r <- r[order(r$i, r$j), , drop = FALSE]
  r$code <- cats[r$j]; r$color <- col_of[r$j]
  u <- units[r$i, , drop = FALSE]
  tibble::tibble(source_id = as.integer(u$source_id), source = u$source, segment = as.integer(u$segment),
                 start = as.integer(u$start), end = as.integer(u$end), pos = pos[r$i],
                 width = width[r$i], code = r$code, color = r$color)
}
