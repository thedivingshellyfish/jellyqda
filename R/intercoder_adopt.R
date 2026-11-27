# jellyqda :: intercoder_adopt.R -- qda_intercoder_adopt(): take over the
# other coder's codings of one unit into the active project (consensus
# coding). One audit-trail event with a snapshot = one undo step.

#' Take over the other coder's codings of one unit (consensus coding)
#'
#' After discussing a disagreement, the coding of coder B can be copied into
#' the active project: all of B's codings of `code` that overlap the unit
#' `start`--`end` of document `source` are added with B's exact character
#' range (the documents are identical). Codings A already has (same code,
#' same range) are skipped. The codes must exist in the active project
#' (same path). All new codings form one action: Ctrl+Z / [qda_undo()]
#' removes them again. The other file is not changed.
#'
#' @inheritParams qda_intercoder
#' @param source Document of the active project (id or name).
#' @param start,end The unit, as in [qda_intercoder_diff()].
#' @param code Code path (with `level = "top"`: path of the top-level code;
#'   then B's codings of the whole family are taken over).
#' @return Invisibly, a tibble of the new codings.
#' @export
#' @examples
#' dir <- tempfile()
#' qda_open(file.path(dir, "coder_a.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Team")
#' b <- qda_intercoder_copy(file.path(dir, "coder_b.jellyqda"))
#' qda_close()
#' qda_open(b); qda_code(1, "Team", segment = 4); qda_close()
#' qda_open(file.path(dir, "coder_a.jellyqda"))
#' d <- qda_intercoder_diff(b)
#' qda_intercoder_adopt(b, d$source_id[1], d$start[1], d$end[1], d$code[1])
#' qda_codings()[, c("code", "start", "end")]
#' qda_close()
qda_intercoder_adopt <- function(other, source, start, end, code, level = c("code", "top"),
                                 min_overlap = 1L) {
  level <- match.arg(level)
  con <- qda_con()
  src <- .resolve_source(source)
  x <- .ic_build(other, "document", level, src$id, min_overlap)
  if (nrow(x$matched) == 0) {
    stop(sprintf("Document '%s' is not part of the other project (text differs).", src$name), call. = FALSE)
  }
  start <- as.integer(start); end <- as.integer(end)
  cb <- x$cb
  hit <- cb[cb$sid == src$id & cb$cat == as.character(code) &
              (pmin(end, cb$end) - pmax(start, cb$start) + 1L) >= x$min_overlap, , drop = FALSE]
  if (nrow(hit) == 0) stop("The other coder has no coding of this code here.", call. = FALSE)
  b_path <- x$B$codes$path[match(hit$code_id, x$B$codes$id)]
  a_id <- x$A$codes$id[match(b_path, x$A$codes$path)]
  if (anyNA(a_id)) {
    stop(sprintf("Code '%s' does not exist in this project; create it first.",
                 b_path[is.na(a_id)][1]), call. = FALSE)
  }
  have <- x$A$codings[x$A$codings$source_id == src$id, , drop = FALSE]
  dup <- paste(a_id, hit$start, hit$end) %in% paste(have$code_id, have$start, have$end)
  hit <- hit[!dup, , drop = FALSE]; a_id <- a_id[!dup]
  if (nrow(hit) == 0) return(invisible(tibble::tibble(id = integer(), source_id = integer(),
                                                      code_id = integer(), start = integer(),
                                                      end = integer())))
  ids <- integer(nrow(hit))
  DBI::dbWithTransaction(con, {
    for (i in seq_len(nrow(hit))) {
      DBI::dbExecute(con, "INSERT INTO codings (source_id, code_id, start, end, memo) VALUES (?, ?, ?, ?, ?)",
                     params = list(src$id, as.integer(a_id[i]), as.integer(hit$start[i]),
                                   as.integer(hit$end[i]), ""))
      ids[i] <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
    }
  })
  log_event("coding_add", list(intercoder_adopt = basename(x$path_b), source_id = src$id,
                               code = as.character(code), n = length(ids)),
            changes = list(.chg("codings", .snap("codings", integer()), .snap("codings", ids))),
            desc = sprintf(.t("Von %s \u00fcbernommen: %d Coding(s) '%s' in %s"),
                           x$coders[2], length(ids), as.character(code), src$name))
  invisible(tibble::tibble(id = ids, source_id = src$id, code_id = as.integer(a_id),
                           start = as.integer(hit$start), end = as.integer(hit$end)))
}
