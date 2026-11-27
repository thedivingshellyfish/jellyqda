# jellyqda :: cooccurrence.R -- code co-occurrence ("code overlaps")
#
#   qda_cooccurrence()           which codes occur together, how often
#   qda_cooccurrence_passages()  the passages where two codes occur together
#
# "Together" depends on `unit`:
#   * "segment"  (default) both codes in the same segment (e.g. speaker turn)
#   * "document" both codes somewhere in the same document
#   * "overlap"  the two codings overlap in the text (share characters)
# Units and categories come from R/units.R (shared with intercoder agreement).
# The plots built on these numbers are in R/plot_cooccurrence.R (heatmap)
# and R/plot_network.R (code network).

#' Resolve a code argument for unit-based analyses to its category (path, or
#' top-level path with level = "top"). Accepts a path or a unique label.
#' @noRd
.resolve_category <- function(x, tr, level) {
  x <- as.character(x)
  key <- if (level == "top") tr$root_path else tr$path
  if (x %in% key) return(x)
  if (x %in% tr$path) return(.category_of(tr, tr$id[match(x, tr$path)], level))
  hit <- tr$id[tr$label == x]
  if (length(hit) == 1) return(.category_of(tr, hit, level))
  if (length(hit) > 1) stop(sprintf("'%s' matches several codes; use the path.", x), call. = FALSE)
  stop(sprintf("No code found for '%s'.", x), call. = FALSE)
}

#' The data behind co-occurrence: documents, units, categories, matrix.
#' @noRd
.cooc_build <- function(unit, level, source, min_overlap) {
  con <- qda_con()
  src <- DBI::dbGetQuery(con, "SELECT id, name, frozen_text FROM sources ORDER BY id")
  src$frozen_text <- .utf8(src$frozen_text); src$name <- .utf8(src$name)
  if (!is.null(source)) {
    ids <- vapply(source, function(s) .resolve_source(s)$id, numeric(1))
    src <- src[src$id %in% ids, , drop = FALSE]
  }
  tr <- .code_categories()
  cd <- DBI::dbGetQuery(con, "SELECT id, source_id, code_id, start, end FROM codings ORDER BY source_id, start")
  cd <- cd[cd$source_id %in% src$id, , drop = FALSE]
  cd$sid <- cd$source_id
  cd$cat <- .category_of(tr, cd$code_id, level)
  cd <- cd[!is.na(cd$cat), , drop = FALSE]
  keys <- unique(if (level == "top") tr$root_path else tr$path)
  cats <- keys[keys %in% cd$cat]
  units <- if (unit == "overlap") NULL else .units_for(src, unit)
  M <- if (unit == "overlap") NULL else .mark_units(units, cd, cats, max(1L, as.integer(min_overlap)))
  list(src = src, tr = tr, cd = cd, cats = cats, units = units, M = M)
}

#' Pairs of codings that overlap (same document, at least `min_overlap`
#' shared characters, different categories). Returns row indices into cd.
#' @noRd
.cooc_overlap_pairs <- function(cd, min_overlap = 1L) {
  out <- list()
  for (sid in unique(cd$sid)) {
    r <- which(cd$sid == sid)
    if (length(r) < 2) next
    r <- r[order(cd$start[r])]
    for (k in seq_along(r)[-length(r)]) {
      i <- r[k]; later <- r[(k + 1):length(r)]
      later <- later[cd$start[later] <= cd$end[i]]          # sorted by start
      if (!length(later)) next
      ov <- pmin(cd$end[i], cd$end[later]) - pmax(cd$start[i], cd$start[later]) + 1L
      later <- later[ov >= min_overlap & cd$cat[later] != cd$cat[i]]
      if (length(later)) out[[length(out) + 1]] <- cbind(i, later)
    }
  }
  if (length(out) == 0) return(matrix(integer(), ncol = 2))
  do.call(rbind, out)
}

#' Code co-occurrence: which codes appear together, and how often
#'
#' Counts for every pair of codes how often they appear **together**: in the
#' same segment (default, e.g. the same speaker turn), in the same document,
#' or as overlapping codings. Typical questions: which themes are talked
#' about together? Which categories are hard to tell apart (they are always
#' coded together)? The result is the basis of the heatmap
#' ([qda_plot_cooccurrence()]) and the code network ([qda_plot_network()]).
#'
#' @param unit `"segment"` (both codes in the same segment), `"document"`
#'   (somewhere in the same document) or `"overlap"` (the codings share
#'   text).
#' @param level `"code"` (every code and subcode) or `"top"` (code families:
#'   a code together with its subcodes).
#' @param source Optional documents (ids or names); default all.
#' @param min_overlap Minimum number of characters a coding must overlap a
#'   unit (or, with `unit = "overlap"`, the other coding).
#' @return A tibble with one row per pair of codes that occur together,
#'   most frequent first: `code_a`, `code_b` (paths), `n` (units -- or, with
#'   `unit = "overlap"`, pairs of codings -- with both), `n_a`, `n_b` (units
#'   with each code, or its number of codings), `jaccard` (`n / (n_a + n_b -
#'   n)`: 1 = always together; `NA` for `unit = "overlap"`). Attribute
#'   `"codes"`: one row per code (`code`, `label`, `depth`, `color`, `n`);
#'   attribute `"info"`: unit, level, number of units and documents.
#' @seealso [qda_cooccurrence_passages()], [qda_plot_cooccurrence()],
#'   [qda_plot_network()]
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path"); qda_code_add("Motivation"); qda_code_add("Team")
#' qda_code(1, "Career path", segment = 5)
#' qda_code(1, "Motivation", start = 300, end = 420)
#' qda_code(1, "Motivation", segment = 7)
#' qda_code(1, "Team", segment = 7)
#' qda_cooccurrence()
#' qda_cooccurrence(unit = "overlap")
#' qda_close()
qda_cooccurrence <- function(unit = c("segment", "document", "overlap"), level = c("code", "top"),
                             source = NULL, min_overlap = 1L) {
  unit <- match.arg(unit); level <- match.arg(level)
  x <- .cooc_build(unit, level, source, min_overlap)
  cats <- x$cats; k <- length(cats)
  if (unit == "overlap") {
    nc <- vapply(cats, function(cc) sum(x$cd$cat == cc), integer(1), USE.NAMES = FALSE)
    C <- matrix(0L, k, k)
    p <- .cooc_overlap_pairs(x$cd, max(1L, as.integer(min_overlap)))
    if (nrow(p)) {
      a <- match(x$cd$cat[p[, 1]], cats); b <- match(x$cd$cat[p[, 2]], cats)
      for (r in seq_along(a)) {
        C[a[r], b[r]] <- C[a[r], b[r]] + 1L
        C[b[r], a[r]] <- C[b[r], a[r]] + 1L
      }
    }
    n_units <- NA_integer_
  } else {
    C <- if (k) crossprod(x$M * 1L) else matrix(0L, 0, 0)
    storage.mode(C) <- "integer"
    nc <- if (k) diag(C) else integer()
    n_units <- nrow(x$units)
  }
  pairs <- if (k > 1) which(upper.tri(C) & C > 0, arr.ind = TRUE) else matrix(integer(), ncol = 2)
  n <- C[pairs]; n_a <- nc[pairs[, 1]]; n_b <- nc[pairs[, 2]]
  out <- tibble::tibble(code_a = cats[pairs[, 1]], code_b = cats[pairs[, 2]], n = as.integer(n),
                        n_a = as.integer(n_a), n_b = as.integer(n_b),
                        jaccard = if (unit == "overlap") rep(NA_real_, length(n)) else n / (n_a + n_b - n))
  out <- out[order(-out$n, match(out$code_a, cats), match(out$code_b, cats)), , drop = FALSE]
  tr <- x$tr; key <- if (level == "top") tr$root_path else tr$path
  i <- match(cats, key)
  attr(out, "codes") <- tibble::tibble(code = cats, label = tr$label[i],
                                       depth = if (level == "top") rep(1L, k) else tr$depth[i],
                                       color = tr$root_color[i], n = as.integer(nc))
  attr(out, "info") <- list(unit = unit, level = level, units = n_units, documents = nrow(x$src),
                            min_overlap = max(1L, as.integer(min_overlap)))
  out
}

#' The passages where two codes occur together
#'
#' The units (segments or documents) that contain both codes -- or, with
#' `unit = "overlap"`, the stretches of text where codings of the two codes
#' overlap. This is what you read after spotting a pair in
#' [qda_cooccurrence()], the heatmap or the network.
#'
#' @inheritParams qda_cooccurrence
#' @param code_a,code_b Code paths (e.g. `"Career path / Small company"`) or
#'   unique labels; with `level = "top"` the top-level codes.
#' @return A tibble: `source_id`, `source`, `segment`, `start`, `end`,
#'   `text`.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Motivation"); qda_code_add("Team")
#' qda_code(1, "Motivation", segment = 7)
#' qda_code(1, "Team", segment = 7)
#' qda_cooccurrence_passages("Motivation", "Team")
#' qda_close()
qda_cooccurrence_passages <- function(code_a, code_b, unit = c("segment", "document", "overlap"),
                                      level = c("code", "top"), source = NULL, min_overlap = 1L) {
  unit <- match.arg(unit); level <- match.arg(level)
  x <- .cooc_build(unit, level, source, min_overlap)
  a <- .resolve_category(code_a, x$tr, level); b <- .resolve_category(code_b, x$tr, level)
  txt_of <- function(sid) x$src$frozen_text[match(sid, x$src$id)]
  empty <- tibble::tibble(source_id = integer(), source = character(), segment = integer(),
                          start = integer(), end = integer(), text = character())
  if (unit == "overlap") {
    cd <- x$cd[x$cd$cat %in% c(a, b), , drop = FALSE]
    p <- .cooc_overlap_pairs(cd, max(1L, as.integer(min_overlap)))
    if (nrow(p) == 0) return(empty)
    s <- pmax(cd$start[p[, 1]], cd$start[p[, 2]]); e <- pmin(cd$end[p[, 1]], cd$end[p[, 2]])
    sid <- cd$sid[p[, 1]]
    out <- tibble::tibble(source_id = as.integer(sid), source = x$src$name[match(sid, x$src$id)],
                          segment = NA_integer_, start = as.integer(s), end = as.integer(e))
  } else {
    if (!all(c(a, b) %in% x$cats)) return(empty)
    both <- which(x$M[, match(a, x$cats)] & x$M[, match(b, x$cats)])
    if (length(both) == 0) return(empty)
    u <- x$units[both, , drop = FALSE]
    out <- tibble::tibble(source_id = as.integer(u$source_id), source = u$source,
                          segment = as.integer(u$segment), start = as.integer(u$start),
                          end = as.integer(u$end))
  }
  out$text <- substring(txt_of(out$source_id), out$start, out$end)
  out[order(out$source_id, out$start), , drop = FALSE]
}
