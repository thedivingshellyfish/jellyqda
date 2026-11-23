# jellyqda :: segments.R -- segments (units of the document, "Seg N")
#
# A segment is a range [start, end] of the frozen text (1-based, inclusive).
# Two sources of segments:
#
#   1. automatic (default, as in all earlier versions): paragraphs separated
#      by blank lines -- computed on the fly, nothing stored;
#   2. stored in the table `segments` -- as soon as a document is segmented
#      by another rule (speaker turns, lines) or edited by hand (split,
#      merge, define from a selection). Then ONLY the stored rows count.
#
# Codings are stored by character offsets, never by segment number, so
# changing segments never changes any coding. Every change is undoable
# (snapshot in the audit trail, see history.R).
#
# Exported API: qda_source_segments(), qda_segments_set(),
# qda_segments_reset(), qda_segment_split(), qda_segment_merge(),
# qda_segment_define().

# Rules ------------------------------------------------------------------------

#' Default pattern for speaker turns: a line that starts with an optional
#' time stamp and a short speaker label followed by a colon, e.g.
#' "[00:01:12] P: ...", "I: ...", "B1: ...", "Befragte: ...",
#' "Interviewerin: ...". Lines that do not match continue the previous turn.
#' The label must be ONE word (letters incl. umlauts, digits, _ or -), so a
#' sentence such as "Er sagte: ..." does not count as a new speaker.
#' @noRd
.SPEAKER_PATTERN <- paste0(
  "^[ \t]*(\\[?[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?([.,][0-9]+)?\\]?[ \t]*)?",
  "\\p{L}[\\p{L}\\p{N}_-]{0,24}:([ \t]|$)")

#' Speaker line WITH a time stamp, e.g. "[00:01:12] P: ...". If a document
#' has such lines, only they start a new turn (so header lines like
#' "Projekt: ..." or "Pseudonym: ..." are not mistaken for speakers).
#' @noRd
.SPEAKER_TS_PATTERN <- paste0(
  "^[ \t]*\\[?[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?([.,][0-9]+)?\\]?[ \t]*",
  "\\p{L}[\\p{L}\\p{N}_-]{0,24}:([ \t]|$)")

.SEGMENT_RULES <- c(blankline = "Leerzeilen (Absaetze)",
                    speaker   = "Sprecherwechsel",
                    line      = "jede Zeile")

#' Choices for the segment-rule select inputs in the app (label -> rule).
#' @noRd
.segrule_choices <- function() {
  # setNames instead of c("Abs\u00e4tze" = ...): names with umlauts in c() are
  # converted to the native encoding at installation and appear as "<U+00E4>"
  # in non-UTF-8 locales; values (strings) stay UTF-8.
  stats::setNames(c("blankline", "speaker", "line"),
                  .t(c("Leerzeilen (Abs\u00e4tze)", "Sprecherwechsel ([00:01:12] P: ...)", "Jede Zeile")))
}

#' Start/end of every line of `text` (character positions, without "\n").
#' @noRd
.line_ranges <- function(text) {
  n <- nchar(text, type = "chars")
  nl <- gregexpr("\n", text, fixed = TRUE)[[1]]
  nl <- if (nl[1] == -1) integer() else as.integer(nl)
  starts <- c(1L, nl + 1L)
  ends <- c(nl - 1L, n)
  data.frame(start = starts, end = ends,
             text = substring(text, starts, ends), stringsAsFactors = FALSE)
}

#' Compute segments of `text` by a rule. Returns tibble(segment, start, end).
#' @noRd
.auto_segments <- function(text, rule = c("blankline", "speaker", "line"),
                           pattern = .SPEAKER_PATTERN) {
  rule <- match.arg(rule)
  n <- nchar(text, type = "chars")
  empty <- tibble::tibble(segment = integer(), start = integer(), end = integer())
  if (is.na(n) || n == 0) return(empty)
  if (rule == "blankline") return(.segments_of(text))

  ln <- .line_ranges(text)
  blank <- trimws(ln$text) == ""
  if (rule == "line") {
    keep <- which(!blank)
    s <- ln$start[keep]; e <- ln$end[keep]
  } else {
    # speaker: a new segment starts at every speaker line and after every
    # blank line; other lines continue the current segment
    is_turn <- grepl(pattern, ln$text, perl = TRUE)
    # default pattern + transcript with time stamps: only time-stamped lines
    # start a turn (header lines such as "Projekt: ..." stay together)
    if (identical(pattern, .SPEAKER_PATTERN)) {
      is_ts <- grepl(.SPEAKER_TS_PATTERN, ln$text, perl = TRUE)
      if (sum(is_ts) >= 2) is_turn <- is_ts
    }
    s <- integer(); e <- integer(); open <- FALSE
    for (i in seq_len(nrow(ln))) {
      if (blank[i]) { open <- FALSE; next }
      if (!open || is_turn[i]) {
        s <- c(s, ln$start[i]); e <- c(e, ln$end[i]); open <- TRUE
      } else {
        e[length(e)] <- ln$end[i]
      }
    }
  }
  if (length(s) == 0) return(empty)
  # no trailing spaces / CR in a segment
  tr <- mapply(.trim_range, s, e, MoreArgs = list(text = text), SIMPLIFY = FALSE)
  tr <- tr[!vapply(tr, is.null, logical(1))]
  s <- vapply(tr, `[`, integer(1), 1); e <- vapply(tr, `[`, integer(1), 2)
  tibble::tibble(segment = seq_along(s), start = s, end = e)
}

#' Shrink [s, e] so it neither starts nor ends with whitespace.
#' NULL if the range contains only whitespace.
#' @noRd
.trim_range <- function(s, e, text) {
  s <- as.integer(s); e <- as.integer(e)
  if (e < s) return(NULL)
  sub <- substring(text, s, e)
  if (trimws(sub) == "") return(NULL)
  lead <- attr(regexpr("^\\s*", sub, perl = TRUE), "match.length")
  trail <- attr(regexpr("\\s*$", sub, perl = TRUE), "match.length")
  c(s + max(lead, 0L), e - max(trail, 0L))
}

# Reading ------------------------------------------------------------------------

#' The segments that are in effect for a source: stored ones if any,
#' otherwise automatic (blank lines). tibble(segment, start, end).
#' @noRd
.segments_for <- function(src) {
  if (!is.list(src)) src <- .resolve_source(src)
  rows <- DBI::dbGetQuery(qda_con(),
    "SELECT start, end FROM segments WHERE source_id = ? ORDER BY start",
    params = list(src$id))
  if (nrow(rows) == 0) return(.segments_of(src$frozen_text))
  tibble::tibble(segment = seq_len(nrow(rows)), start = as.integer(rows$start),
                 end = as.integer(rows$end))
}

#' Segments plus the text before, between and after them, so that
#' paste0(prefix, seg1, sep1, seg2, ..., segN, suffix) == text.
#' The document browser relies on this (offsets 1:1).
#' @noRd
.seg_layout <- function(text, segs) {
  n <- nchar(text, type = "chars")
  k <- nrow(segs)
  if (k == 0) return(list(prefix = text, segs = segs, seps = character(), suffix = ""))
  list(
    prefix = if (segs$start[1] > 1) substring(text, 1, segs$start[1] - 1L) else "",
    segs = segs,
    seps = if (k > 1) substring(text, segs$end[-k] + 1L, segs$start[-1] - 1L) else character(),
    suffix = if (segs$end[k] < n) substring(text, segs$end[k] + 1L, n) else ""
  )
}

#' Segments of a source and where they come from
#'
#' @param source Source id or unique name.
#' @return A tibble: `segment` (number as shown in the app, "Seg N"),
#'   `start`, `end` (1-based character offsets), `text`. Attribute
#'   `"origin"`: `"automatisch"` (blank lines, nothing stored) or
#'   `"gespeichert"`.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_source_segments(1)
#' qda_close()
qda_source_segments <- function(source) {
  src <- .resolve_source(source)
  segs <- .segments_for(src)
  stored <- DBI::dbGetQuery(qda_con(), "SELECT COUNT(*) AS n FROM segments WHERE source_id = ?",
                            params = list(src$id))$n > 0
  out <- tibble::tibble(segment = segs$segment, start = segs$start, end = segs$end,
                        text = substring(src$frozen_text, segs$start, segs$end))
  attr(out, "origin") <- if (stored) "gespeichert" else "automatisch"
  out
}

# Writing ------------------------------------------------------------------------

#' Replace all stored segments of a source by `segs` (data.frame start/end),
#' after validating them; logs an undoable event.
#' @noRd
.store_segments <- function(src, segs, action, desc, details = list()) {
  con <- qda_con()
  n <- nchar(src$frozen_text, type = "chars")
  segs <- segs[order(segs$start), c("start", "end"), drop = FALSE]
  s <- as.integer(segs$start); e <- as.integer(segs$end)
  if (any(is.na(s) | is.na(e)) || any(s < 1L | e > n | e < s)) {
    stop(.t("Ungueltige Segmentgrenzen."), call. = FALSE)
  }
  if (length(s) > 1 && any(s[-1] <= e[-length(e)])) {
    stop(.t("Segmente duerfen sich nicht ueberlappen."), call. = FALSE)
  }
  old_ids <- DBI::dbGetQuery(con, "SELECT id FROM segments WHERE source_id = ?",
                             params = list(src$id))$id
  before <- .snap("segments", old_ids)
  DBI::dbWithTransaction(con, {
    DBI::dbExecute(con, "DELETE FROM segments WHERE source_id = ?", params = list(src$id))
    if (length(s) > 0) {
      DBI::dbAppendTable(con, "segments", data.frame(source_id = src$id, start = s, end = e))
    }
  })
  new_ids <- DBI::dbGetQuery(con, "SELECT id FROM segments WHERE source_id = ?",
                             params = list(src$id))$id
  log_event(action, c(list(source_id = src$id, n_segments = length(s)), details),
            changes = list(.chg("segments", before, .snap("segments", new_ids))),
            desc = desc)
  invisible(.segments_for(src))
}

#' Segment a document by a rule
#'
#' Replaces the segments of a document. Codings are not affected (they are
#' stored by character offsets), only the segment numbers change.
#' Undoable with [qda_undo()].
#'
#' @param source Source id or unique name.
#' @param rule `"blankline"` (paragraphs separated by blank lines, the
#'   default of jellyqda), `"speaker"` (a new segment at every speaker turn,
#'   e.g. `"[00:01:12] P: ..."` or `"Befragte: ..."`; lines without speaker
#'   label belong to the previous turn; blank lines also separate) or
#'   `"line"` (every non-empty line).
#' @param pattern For `rule = "speaker"`: regular expression (Perl) that
#'   recognises the first line of a speaker turn. The default matches an
#'   optional time stamp followed by a one-word label (up to 25 characters)
#'   and a colon; if the document contains time-stamped turns, only those
#'   count (so header lines like `"Projekt: ..."` are not split off).
#' @return Invisibly, the new segments (tibble `segment`, `start`, `end`).
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_segments_set(1, "line")      # one segment per line
#' qda_segments_set(1, "speaker")   # speaker turns like "[00:01:12] P: ..."
#' qda_source_segments(1)
#' qda_close()
qda_segments_set <- function(source, rule = c("blankline", "speaker", "line"),
                             pattern = NULL) {
  rule <- match.arg(rule)
  src <- .resolve_source(source)
  segs <- .auto_segments(src$frozen_text, rule, pattern %||% .SPEAKER_PATTERN)
  .store_segments(src, segs, "segments_set",
                  desc = sprintf(.t("Segmente neu eingeteilt (%s): %s, %d Segmente"),
                                 .t(.SEGMENT_RULES[[rule]]), src$name, nrow(segs)),
                  details = list(rule = rule))
}

#' Back to automatic segments (blank lines)
#'
#' Deletes the stored segments of a document; afterwards the automatic
#' paragraph segmentation of earlier jellyqda versions applies again.
#' Undoable with [qda_undo()].
#'
#' @param source Source id or unique name.
#' @return Invisibly, the segments now in effect.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_segments_set(1, "line")
#' qda_segments_reset(1)   # back to blank-line segments
#' qda_source_segments(1)
#' qda_close()
qda_segments_reset <- function(source) {
  src <- .resolve_source(source)
  .store_segments(src, data.frame(start = integer(), end = integer()), "segments_set",
                  desc = sprintf(.t("Segmente zurueckgesetzt (automatisch): %s"), src$name),
                  details = list(rule = "reset"))
}

#' Split a segment at a character position
#'
#' The segment containing `at` is split so that a new segment starts at
#' `at` (whitespace at the cut is trimmed away). Undoable.
#'
#' @param source Source id or unique name.
#' @param at 1-based character position where the new segment starts.
#' @return Invisibly, the new segments.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_segment_split(1, at = 100)
#' qda_source_segments(1)
#' qda_close()
qda_segment_split <- function(source, at) {
  src <- .resolve_source(source)
  segs <- .segments_for(src)
  at <- as.integer(at)
  i <- which(segs$start <= at & segs$end >= at)
  if (length(i) == 0) stop(.t("An dieser Stelle liegt kein Segment."), call. = FALSE)
  left <- .trim_range(segs$start[i], at - 1L, src$frozen_text)
  right <- .trim_range(at, segs$end[i], src$frozen_text)
  if (is.null(left) || is.null(right)) {
    stop(.t("Am Anfang oder Ende eines Segments kann nicht geteilt werden."), call. = FALSE)
  }
  new <- rbind(segs[-i, c("start", "end")],
               data.frame(start = c(left[1], right[1]), end = c(left[2], right[2])))
  .store_segments(src, new, "segment_split",
                  desc = sprintf(.t("Segment %d geteilt bei Zeichen %d (%s)"), i, at, src$name))
}

#' Merge a segment with the following one
#'
#' @param source Source id or unique name.
#' @param segment Segment number; it is merged with segment `segment + 1`.
#' @return Invisibly, the new segments.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_segment_merge(1, 1)   # segments 1 + 2 -> 1
#' qda_source_segments(1)
#' qda_close()
qda_segment_merge <- function(source, segment) {
  src <- .resolve_source(source)
  segs <- .segments_for(src)
  i <- as.integer(segment)
  if (is.na(i) || i < 1 || i >= nrow(segs)) {
    stop(sprintf(.t("Segment %s hat kein nachfolgendes Segment."), segment), call. = FALSE)
  }
  new <- rbind(segs[-c(i, i + 1L), c("start", "end")],
               data.frame(start = segs$start[i], end = segs$end[i + 1L]))
  .store_segments(src, new, "segment_merge",
                  desc = sprintf(.t("Segmente %d und %d zusammengefuehrt (%s)"), i, i + 1L, src$name))
}

#' Define a passage as its own segment
#'
#' Makes `start`..`end` one segment (e.g. a passage marked in the app).
#' Segments it overlaps are shortened; a segment that contains it entirely
#' is split into up to three parts. Whitespace at the edges is trimmed.
#'
#' @param source Source id or unique name.
#' @param start,end 1-based inclusive character offsets.
#' @return Invisibly, the new segments.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_segment_define(1, start = 120, end = 200)
#' qda_source_segments(1)
#' qda_close()
qda_segment_define <- function(source, start, end) {
  src <- .resolve_source(source)
  text <- src$frozen_text
  r <- .trim_range(start, end, text)
  if (is.null(r)) stop(.t("Die Auswahl enthaelt keinen Text."), call. = FALSE)
  s <- r[1]; e <- r[2]
  segs <- .segments_for(src)
  keep <- list()
  for (j in seq_len(nrow(segs))) {
    a <- segs$start[j]; z <- segs$end[j]
    if (z < s || a > e) { keep[[length(keep) + 1]] <- c(a, z); next }   # untouched
    if (a < s) {                                                        # part before
      p <- .trim_range(a, s - 1L, text); if (!is.null(p)) keep[[length(keep) + 1]] <- p
    }
    if (z > e) {                                                        # part after
      p <- .trim_range(e + 1L, z, text); if (!is.null(p)) keep[[length(keep) + 1]] <- p
    }
  }
  keep[[length(keep) + 1]] <- c(s, e)
  new <- data.frame(start = vapply(keep, `[`, numeric(1), 1),
                    end = vapply(keep, `[`, numeric(1), 2))
  .store_segments(src, new, "segment_adjust",
                  desc = sprintf(.t("Segment festgelegt: Zeichen %d-%d (%s)"), s, e, src$name))
}
