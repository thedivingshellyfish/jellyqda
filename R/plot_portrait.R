# jellyqda :: plot_portrait.R -- qda_plot_portrait(): one strip per document
# (data: qda_portrait(), R/portrait.R). Each segment is a block whose width
# is its share of the document; a segment with several codes is split into
# stacked bands, one per code (in code-tree order); uncoded segments are grey.
# SVG helpers in R/plot_svg.R.

#' Document portraits: one coloured strip per document
#'
#' Draws [qda_portrait()]: every document is a strip from its start (left)
#' to its end (right), every segment a block as wide as its share of the
#' text, coloured by the codes it contains. Strips of several documents
#' underneath each other show where in the interviews the themes come up.
#' Hovering a block names the segment and its codes; in the app a click
#' jumps to the segment.
#'
#' @param x Result of [qda_portrait()]; if `NULL` it is computed with `...`.
#' @param width Width of the strips in pixels.
#' @param interactive Logical; `TRUE` (default) gives every block a tooltip
#'   and a click target (app, Viewer). `FALSE` (used for the printed report)
#'   leaves them out and merges neighbouring segments with the same codes --
#'   the picture is the same, the file much smaller in large projects.
#' @param file Optional path: write the SVG there instead of returning it.
#' @param ... Arguments for [qda_portrait()] (e.g. `level`, `source`).
#' @return The SVG as an HTML object (printing shows it in the RStudio
#'   Viewer), or invisibly `file`.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", c("interview_01.txt", "interview_02.md"), package = "jellyqda"))
#' qda_code_add("Career path"); qda_code_add("Team")
#' qda_code(1, "Career path", segment = 3)
#' qda_code(2, "Team", segment = 5)
#' svg <- qda_plot_portrait()
#' qda_close()
qda_plot_portrait <- function(x = NULL, width = 760, interactive = TRUE, file = NULL, ...) {
  if (is.null(x)) x <- qda_portrait(...)
  title <- .t("Dokument-Portraits")
  if (nrow(x) == 0) {
    return(.svg_out(.svg_doc(420, 40, sprintf('<text x="0" y="24" class="muted">%s</text>',
                                              .svg_esc(.t("Keine Dokumente."))), title), file, x))
  }
  docs <- unique(x[, c("source_id", "source")])
  labs <- .svg_short(docs$source, 30)
  lw <- .svg_text_w(labs) + 12
  strip_h <- 18; row_h <- 26
  W <- lw + width + 10
  out <- character()
  for (d in seq_len(nrow(docs))) {
    y <- 4 + (d - 1) * row_h
    out <- c(out, sprintf('<text x="0" y="%.1f">%s<title>%s</title></text>', y + 13, .svg_esc(labs[d]), .svg_esc(docs$source[d])))
    xd <- x[x$source_id == docs$source_id[d], , drop = FALSE]
    if (!isTRUE(interactive)) xd <- .portrait_merge(xd)
    # vectorised: one <rect> per row (segment x code); k-th of m codes of a
    # segment = k-th horizontal band
    key <- xd$segment
    m <- stats::ave(seq_along(key), key, FUN = length)
    k <- stats::ave(seq_along(key), key, FUN = seq_along)
    lab <- ifelse(is.na(xd$code), NA_character_, gsub(" / ", " \u203a ", xd$code, fixed = TRUE))
    seg_tip <- tapply(lab, key, function(v) if (all(is.na(v))) "" else paste(v[!is.na(v)], collapse = ", "))
    tip <- seg_tip[as.character(key)]
    tip <- ifelse(nzchar(tip), sprintf("Seg %d: %s", key, tip), sprintf(.t("Seg %d: nicht codiert"), key))
    bx <- lw + xd$pos * width; bw <- pmax(1, xd$width * width - 1)   # 1px gap between blocks
    bh <- strip_h / m
    fill <- ifelse(is.na(xd$code), 'class="none"', sprintf('fill="%s"', .svg_esc(xd$color)))
    out <- c(out, if (isTRUE(interactive))
      sprintf('<rect %s x="%.2f" y="%.2f" width="%.2f" height="%.2f" data-jump="1" data-src="%d" data-pos="%d"><title>%s</title></rect>',
              fill, bx, y + (k - 1) * bh, bw, bh, xd$source_id, xd$start, .svg_esc(tip))
    else sprintf('<rect %s x="%.1f" y="%.1f" width="%.1f" height="%.1f"/>', fill, bx, y + (k - 1) * bh, bw, bh))
  }
  # axis: start / end of the document + legend of the codes
  ya <- 4 + nrow(docs) * row_h
  out <- c(out, sprintf('<text class="muted" x="%.1f" y="%.1f">%s</text><text class="muted" x="%.1f" y="%.1f" text-anchor="end">%s</text>',
                        lw, ya + 6, .svg_esc(.t("Anfang")), lw + width, ya + 6, .svg_esc(.t("Ende"))))
  leg_codes <- unique(x$code[!is.na(x$code)])
  leg_cols <- x$color[match(leg_codes, x$code)]
  leg <- .svg_legend(c(gsub(" / ", " \u203a ", leg_codes, fixed = TRUE), .t("nicht codiert")),
                     c(leg_cols, "#e4e8ed"), lw, ya + 18, width)
  H <- ya + 22 + leg$height
  desc <- sprintf(.t("%d Dokument(e); Breite eines Blocks = Anteil am Text; Farbe = Code."), nrow(docs))
  .svg_out(.svg_doc(W, H, c(out, leg$svg), title, desc), file, x)
}

#' Merge neighbouring segments of one document that contain the same codes
#' into one block (for the non-interactive drawing: same picture, fewer
#' elements). Rows: segment x code as from qda_portrait().
#' @noRd
.portrait_merge <- function(xd) {
  segs <- unique(xd$segment)
  sig <- vapply(segs, function(sg) paste(sort(xd$code[xd$segment == sg]), collapse = "|"), character(1))
  run <- cumsum(c(TRUE, sig[-1] != sig[-length(sig)]))
  first <- xd[match(segs, xd$segment), , drop = FALSE]
  last_end <- tapply(first$pos + first$width, run, max)
  keep_seg <- segs[!duplicated(run)]
  out <- xd[xd$segment %in% keep_seg, , drop = FALSE]
  r <- run[match(out$segment, segs)]
  out$width <- as.numeric(last_end[as.character(r)]) - out$pos
  out
}
