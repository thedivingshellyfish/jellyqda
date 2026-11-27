# jellyqda :: units.R -- units of analysis, shared by several analyses
#
# A unit of analysis is a range of a document: a segment (e.g. a speaker
# turn, see segments.R) or the whole document. Analyses that ask "is code X
# present in this unit?" build a logical matrix units x categories here:
#   * intercoder agreement (intercoder_data.R): one matrix per coder,
#   * code co-occurrence (cooccurrence.R): codes appearing in the same unit.
# A category is a code path ("Parent / Child") or, with level = "top", the
# path of the top-level code (the whole code family).

#' Units of analysis for some documents.
#' @param src data frame with id, name, frozen_text (one row per document)
#' @param unit "segment" or "document"
#' @return data.frame source_id, source, segment, start, end (segments of one
#'   document in text order, not overlapping)
#' @noRd
.units_for <- function(src, unit = c("segment", "document")) {
  unit <- match.arg(unit)
  empty <- data.frame(source_id = integer(), source = character(), segment = integer(),
                      start = integer(), end = integer(), stringsAsFactors = FALSE)
  if (nrow(src) == 0) return(empty)
  # stored segments of all documents in one query (instead of loading every
  # text again per document); documents without stored segments use the
  # automatic blank-line segments of the text we already have
  stored <- if (unit == "segment") DBI::dbGetQuery(qda_con(), sprintf(
    "SELECT source_id, start, end FROM segments WHERE source_id IN (%s) ORDER BY source_id, start",
    paste(as.integer(src$id), collapse = ","))) else NULL
  out <- lapply(seq_len(nrow(src)), function(i) {
    if (unit == "document") {
      n <- nchar(src$frozen_text[i], type = "chars")
      if (is.na(n) || n == 0) return(NULL)
      return(data.frame(source_id = src$id[i], source = src$name[i], segment = NA_integer_,
                        start = 1L, end = n, stringsAsFactors = FALSE))
    }
    st <- stored[stored$source_id == src$id[i], , drop = FALSE]
    sg <- if (nrow(st)) data.frame(segment = seq_len(nrow(st)), start = st$start, end = st$end)
          else .segments_of(src$frozen_text[i])
    if (nrow(sg) == 0) return(NULL)
    data.frame(source_id = rep(src$id[i], nrow(sg)), source = rep(src$name[i], nrow(sg)),
               segment = sg$segment, start = sg$start, end = sg$end, stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, out)
  if (is.null(out)) empty else out
}

#' Logical matrix units x categories: TRUE where a coding of the category
#' overlaps the unit by at least `min_overlap` characters.
#' @param units from .units_for()
#' @param cd data frame with sid (source id of the unit), start, end, cat
#' @param cats character vector of categories (the columns)
#' @noRd
.mark_units <- function(units, cd, cats, min_overlap = 1L) {
  M <- matrix(FALSE, nrow(units), length(cats))   # columns in the order of `cats`
  if (nrow(cd) == 0 || nrow(units) == 0 || length(cats) == 0) return(M)
  cd <- cd[cd$cat %in% cats, , drop = FALSE]
  j_all <- match(cd$cat, cats)
  # per document: units are sorted and do not overlap, so the units a coding
  # touches are found with findInterval() instead of comparing all units
  for (sid in unique(cd$sid)) {
    ui <- which(units$source_id == sid)
    if (length(ui) == 0) next
    us <- units$start[ui]; ue <- units$end[ui]
    rows <- which(cd$sid == sid)
    first <- findInterval(cd$start[rows] - 1L, ue) + 1L   # first unit ending at/after start
    last <- findInterval(cd$end[rows], us)                # last unit starting at/before end
    for (k in seq_along(rows)) {
      if (first[k] > last[k]) next
      cand <- first[k]:last[k]
      r <- rows[k]
      ov <- pmin(ue[cand], cd$end[r]) - pmax(us[cand], cd$start[r]) + 1L
      hit <- ui[cand[ov >= min_overlap]]
      if (length(hit)) M[hit, j_all[r]] <- TRUE
    }
  }
  M
}

#' Codes of the active project with path, root path, colours and depth (tree
#' order) -- the categories for unit-based analyses.
#' @noRd
.code_categories <- function() {
  codes <- DBI::dbGetQuery(qda_con(), "SELECT id, label, parent_id, color FROM codes ORDER BY id")
  codes$label <- .utf8(codes$label)
  tr <- .code_tree(codes)
  tr$path <- .code_paths(tr)
  tr$root_path <- tr$path[match(tr$root_id, tr$id)]
  tr
}

#' Category of each code id: its path or the path of its top-level code.
#' @noRd
.category_of <- function(tr, code_ids, level = "code") {
  key <- if (level == "top") tr$root_path else tr$path
  key[match(code_ids, tr$id)]
}
