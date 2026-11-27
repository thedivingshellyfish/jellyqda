# jellyqda :: render.R -- the document text with codings as HTML
#
# Used by the app's document browser (.render_doc_html), the exported HTML
# report (export.R) and qda_view() (view.R) -- one implementation, so all
# three show overlaps the same way.
#
# THE invariant (tested in tests/testthat/test-render-offsets.R): the visible
# text of the HTML is identical to the frozen text, character by character.
# The app maps a mouse selection to character offsets by measuring this
# text; any extra or missing character would store codings at wrong places.
# Therefore everything that is only decoration (segment numbers, overlap
# numbers, popovers) is CSS ::before content or lives outside #doc.

# Codings of a source, ordered by position.
#' @noRd
# `color` is the colour of the code family (top-level code); `sub` is TRUE
# for codings with a subcode (shown as a light tint + underline + label tag).
.codings_of <- function(source_id) {
  cods <- DBI::dbGetQuery(qda_con(), "
    SELECT c.id, c.start, c.end, c.memo, c.code_id, k.label, k.color
    FROM codings c JOIN codes k ON k.id = c.code_id
    WHERE c.source_id = ? ORDER BY c.start, c.id", params = list(source_id))
  tr <- .code_tree(DBI::dbGetQuery(qda_con(), "SELECT id, label, parent_id, color FROM codes"))
  m <- match(cods$code_id, tr$id)
  cods$color <- ifelse(is.na(m), cods$color, tr$root_color[m])
  cods$sub <- !is.na(m) & tr$depth[m] > 1L
  cods
}

# Passage memos of a source (underlined in the text, see memos.R).
#' @noRd
.passage_memos_of <- function(source_id) {
  DBI::dbGetQuery(qda_con(), "
    SELECT id, start, end FROM memos
    WHERE kind = 'passage' AND source_id = ? AND start IS NOT NULL
    ORDER BY start, id", params = list(source_id))
}

# Ids of codings whose range is coded more than once (identical start/end):
# shown with a dashed outline.
#' @noRd
.dup_ids <- function(cods) {
  if (nrow(cods) == 0) return(integer())
  key <- paste(cods$start, cods$end)
  cods$id[duplicated(key) | duplicated(key, fromLast = TRUE)]
}

#' HTML for text[st..en] with all codings in `cods` marked.
#'
#' The range is cut at every coding start/end into pieces. Each piece is
#' written exactly ONCE and wrapped according to the codings covering it:
#'   one coding   -> <mark data-cid> with the code colour as background
#'   2+ codings   -> <mark class="ovl" data-cids data-n> light grey, a stripe
#'                   in the colours of the involved codes, and a number
#'                   (CSS ::before) at the start of each overlap run
#'   passage memo -> <mark class="memomark" data-mid> underline (innermost);
#'                   `memos` = data.frame(id, start, end) from .passage_memos_of
#' (Regression: the old version wrote each coding with its full text, so
#' overlapping text appeared twice and later offsets were shifted.)
#' @noRd
#' `anchors` (report only): list(cod = c("<coding id>" = number),
#' memo = c("<memo id>" = number)). At the start of each coding / passage
#' memo a small number badge is written as real text -- fine for the
#' report, never used in the app (offsets!).
#' @noRd
.marked_html <- function(text, st, en, cods, dup_ids = integer(), sel_mid = NULL,
                         memos = NULL, anchors = NULL) {
  esc <- htmltools::htmlEscape
  # codings and passage memos in one table; `kind` tells them apart
  sub <- if (is.null(cods$sub)) rep(FALSE, nrow(cods)) else as.logical(cods$sub)
  all <- data.frame(id = cods$id, start = cods$start, end = cods$end,
                    color = cods$color, label = cods$label, sub = sub,
                    kind = rep("coding", nrow(cods)), stringsAsFactors = FALSE)
  if (!is.null(memos) && nrow(memos) > 0) {
    all <- rbind(all, data.frame(id = memos$id, start = memos$start, end = memos$end,
                                 color = NA_character_, label = "Memo", sub = FALSE,
                                 kind = "memo", stringsAsFactors = FALSE))
  }
  cods <- all
  hit <- which(cods$start <= en & cods$end >= st)
  if (length(hit) == 0) return(esc(substring(text, st, en)))
  cs <- pmax(cods$start[hit], st); ce <- pmin(cods$end[hit], en)
  is_memo <- cods$kind == "memo"

  memo_open <- function(j) {
    cls <- if (!is.null(sel_mid) && cods$id[j] == sel_mid) "memomark sel" else "memomark"
    sprintf('<mark class="%s" data-mid="%d" title="%s">',
            cls, cods$id[j], .t("Memo (Klick = im Memo-Panel zeigen)"))
  }
  # top-level code: full colour. Subcode: light tint of the family colour,
  # underline in that colour and (at the start of the coding) a small label
  # tag -- drawn by CSS ::before from data-tag, so it adds no DOM text.
  # --c carries the colour for the print view of the report.
  single_open <- function(j, a) {
    cls <- c(if (cods$id[j] %in% dup_ids) "dup", if (cods$sub[j]) "sub",
             if (cods$sub[j] && a == cods$start[j]) "tagstart")
    style <- if (cods$sub[j]) {
      sprintf("background-color:%s;border-bottom-color:%s;--c:%s",
              .hex_rgba(cods$color[j], 0.30), cods$color[j], cods$color[j])
    } else sprintf("background-color:%s;--c:%s", cods$color[j], cods$color[j])
    sprintf('<mark class="%s" data-cid="%d"%s style="%s" title="%s">',
            paste(cls, collapse = " "), cods$id[j],
            if (cods$sub[j]) sprintf(' data-tag="%s"', esc(cods$label[j], attribute = TRUE)) else "",
            esc(style), esc(cods$label[j]))
  }
  # data-cids: the codings of this place (space separated) -> popover in
  # js/12-overlap-popover.js; title: plain fallback where no JS runs (report, qda_view)
  ovl_open <- function(js, first) {
    k <- length(js)
    stops <- paste(sprintf("%s %.2f%% %.2f%%", cods$color[js], (seq_len(k) - 1) * 100 / k,
                           seq_len(k) * 100 / k), collapse = ", ")
    sprintf(paste0('<mark class="ovl%s%s" data-cids="%s" data-n="%d" ',
                   'style="background-image:linear-gradient(to right, %s)" title="%s">'),
            if (first) " ovl-start" else "", if (any(cods$id[js] %in% dup_ids)) " dup" else "",
            paste(cods$id[js], collapse = " "), k, esc(stops),
            esc(paste0(k, .t(" Codings: "), paste(cods$label[js], collapse = ", "))))
  }

  cuts <- sort(unique(c(st, cs, ce + 1L, en + 1L)))
  cuts <- cuts[cuts >= st & cuts <= en + 1L]
  out <- character(length(cuts) - 1L)
  prev_real <- integer()
  for (k in seq_len(length(cuts) - 1L)) {
    a <- cuts[k]; z <- cuts[k + 1L] - 1L
    piece <- esc(substring(text, a, z))
    cover <- hit[cs <= a & ce >= z]
    memo <- cover[is_memo[cover]]
    real <- cover[!is_memo[cover]]
    if (length(memo) > 0) {
      piece <- paste0(paste(vapply(memo, memo_open, character(1)), collapse = ""), piece,
                      strrep("</mark>", length(memo)))
    }
    if (length(real) == 1) {
      piece <- paste0(single_open(real, a), piece, "</mark>")
    } else if (length(real) >= 2) {
      # number badge only where a new overlap run (other set of codings) starts
      piece <- paste0(ovl_open(real, !identical(real, prev_real)), piece, "</mark>")
    }
    prev_real <- real
    if (!is.null(anchors)) {
      starts <- hit[cods$start[hit] == a]
      if (length(starts)) {
        badge <- vapply(starts, function(j) {
          if (is_memo[j]) {
            n <- anchors$memo[as.character(cods$id[j])]
            if (is.na(n)) "" else sprintf('<span class="anc memo">M%d</span>', n)
          } else {
            n <- anchors$cod[as.character(cods$id[j])]
            if (is.na(n)) "" else sprintf('<span class="anc" style="--c:%s">%d</span>', esc(cods$color[j]), n)
          }
        }, character(1))
        piece <- paste0(paste(badge, collapse = ""), piece)
      }
    }
    out[k] <- piece
  }
  paste(out, collapse = "")
}

#' Document HTML for the app's document browser (and the HTML report).
#'
#' <div id="doc" data-codings="{json}"> with one <div class="segtext"
#' data-seg="N"> per segment (stored or automatic, see segments.R) and the
#' text between segments as plain text nodes. data-codings holds the details
#' of every coding for the overlap popover -- an attribute, not text.
#' @noRd
.render_doc_html <- function(source_id, sel_mid = NULL) {
  src <- .resolve_source(source_id)
  text <- src$frozen_text
  esc <- htmltools::htmlEscape
  lay <- .seg_layout(text, .segments_for(src))
  cods <- .codings_of(src$id)
  memos <- .passage_memos_of(src$id)
  dup_ids <- .dup_ids(cods)
  segs <- lay$segs
  divs <- vapply(seq_len(nrow(segs)), function(i) {
    sprintf('<div class="segtext" data-seg="%d">%s</div>', i,
            .marked_html(text, segs$start[i], segs$end[i], cods, dup_ids, sel_mid, memos))
  }, character(1))
  body <- paste0(esc(lay$prefix),
                 paste0(divs, vapply(c(lay$seps, ""), esc, character(1)), collapse = ""),
                 esc(lay$suffix))

  info <- list()
  if (nrow(cods) > 0) {
    codes <- qda_codes()
    path_of <- stats::setNames(codes$path, codes$id)
    for (j in seq_len(nrow(cods))) {
      info[[as.character(cods$id[j])]] <- list(
        label = unname(path_of[as.character(cods$code_id[j])] %||% cods$label[j]),
        color = cods$color[j], start = cods$start[j], end = cods$end[j],
        memo = cods$memo[j],
        text = substring(text, cods$start[j], min(cods$end[j], cods$start[j] + 90L)))
    }
  }
  json <- if (length(info) == 0) "{}" else as.character(jsonlite::toJSON(info, auto_unbox = TRUE))
  sprintf('<div id="doc" data-codings="%s">%s</div>', esc(json, attribute = TRUE), body)
}

#' Automatic (blank-line) segments plus the exact separators between them.
#' Kept for compatibility; new code uses .segments_for() + .seg_layout().
#' @noRd
.split_segments_full <- function(text) {
  lay <- .seg_layout(text, .segments_of(text))
  list(segs = lay$segs, seps = lay$seps)
}
