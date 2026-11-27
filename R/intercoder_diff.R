# jellyqda :: intercoder_diff.R -- qda_intercoder_diff(): the units on which
# the two coders disagree (material for the consensus discussion).

#' Units on which the two coders disagree
#'
#' Lists every unit (segment or document) and code where exactly one of the
#' two coders coded -- the material for the consensus discussion after an
#' intercoder check. Takes the same arguments as [qda_intercoder()].
#'
#' @inheritParams qda_intercoder
#' @param code Optional code path (or label of a top-level code) to show
#'   only its disagreements.
#' @return A tibble: `source_id`, `source`, `segment`, `start`, `end` (the
#'   unit in the active project), `code` (path), `coded_by` (`"A"` or
#'   `"B"`), `coder` (name), `text` (text of the unit), `b_codings` (number
#'   of B's codings that can be taken over with [qda_intercoder_adopt()]).
#' @export
#' @examples
#' dir <- tempfile()
#' qda_open(file.path(dir, "coder_a.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Team")
#' b <- qda_intercoder_copy(file.path(dir, "coder_b.jellyqda"))
#' qda_code(1, "Team", segment = 3)
#' qda_close()
#' qda_open(b); qda_code(1, "Team", segment = 4); qda_close()
#' qda_open(file.path(dir, "coder_a.jellyqda"))
#' qda_intercoder_diff(b)[, c("segment", "code", "coded_by")]
#' qda_close()
qda_intercoder_diff <- function(other, unit = c("segment", "document"), level = c("code", "top"),
                                source = NULL, min_overlap = 1L, coders = NULL, code = NULL) {
  unit <- match.arg(unit); level <- match.arg(level)
  x <- .ic_build(other, unit, level, source, min_overlap, coders)
  idx <- which(x$MA != x$MB, arr.ind = TRUE)
  empty <- tibble::tibble(source_id = integer(), source = character(), segment = integer(),
                          start = integer(), end = integer(), code = character(),
                          coded_by = character(), coder = character(), text = character(),
                          b_codings = integer())
  if (nrow(idx) == 0) return(empty)
  idx <- idx[order(idx[, 1], idx[, 2]), , drop = FALSE]
  u <- x$units[idx[, 1], , drop = FALSE]
  cat <- x$cats[idx[, 2]]
  by_a <- x$MA[idx]
  txt <- x$matched$frozen_text[match(u$source_id, x$matched$id)]
  nb <- vapply(seq_len(nrow(u)), function(i) {
    cb <- x$cb
    sum(cb$sid == u$source_id[i] & cb$cat == cat[i] &
          (pmin(u$end[i], cb$end) - pmax(u$start[i], cb$start) + 1L) >= x$min_overlap)
  }, integer(1))
  out <- tibble::tibble(source_id = as.integer(u$source_id), source = u$source,
                        segment = as.integer(u$segment), start = as.integer(u$start),
                        end = as.integer(u$end), code = cat,
                        coded_by = ifelse(by_a, "A", "B"),
                        coder = ifelse(by_a, x$coders[1], x$coders[2]),
                        text = substring(txt, u$start, u$end), b_codings = nb)
  if (!is.null(code)) out <- out[out$code %in% as.character(code), , drop = FALSE]
  out
}
