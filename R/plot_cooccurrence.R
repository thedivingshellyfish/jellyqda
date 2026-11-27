# jellyqda :: plot_cooccurrence.R -- qda_plot_cooccurrence(): heatmap of the
# code co-occurrence (data: qda_cooccurrence(), R/cooccurrence.R). Lower
# triangle of the code x code matrix; darker = more often together. SVG
# helpers in R/plot_svg.R.

#' Heatmap of code co-occurrence
#'
#' Shows [qda_cooccurrence()] as a triangle of code x code cells: the darker
#' a cell, the more often the two codes occur together; the number is in the
#' cell. Codes are in code-tree order, each with the colour of its code
#' family. Hovering a cell shows the details; in the app a click lists the
#' passages ([qda_cooccurrence_passages()]).
#'
#' @param x Result of [qda_cooccurrence()]; if `NULL` it is computed with
#'   `...`.
#' @param measure `"n"` (count) or `"jaccard"` (share of units with either
#'   code that have both; evens out frequent codes).
#' @param max_codes Show at most this many codes (the most frequent ones).
#' @param file Optional path: write the SVG there instead of returning it.
#' @param ... Arguments for [qda_cooccurrence()] (e.g. `unit`, `level`).
#' @return The SVG as an HTML object (printing shows it in the RStudio
#'   Viewer), or invisibly `file`.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path"); qda_code_add("Motivation"); qda_code_add("Team")
#' qda_code(1, "Career path", segment = 5); qda_code(1, "Motivation", segment = 5)
#' qda_code(1, "Motivation", segment = 7); qda_code(1, "Team", segment = 7)
#' svg <- qda_plot_cooccurrence()
#' qda_plot_cooccurrence(file = tempfile(fileext = ".svg"))
#' qda_close()
qda_plot_cooccurrence <- function(x = NULL, measure = c("n", "jaccard"), max_codes = 30,
                                  file = NULL, ...) {
  measure <- match.arg(measure)
  if (is.null(x)) x <- qda_cooccurrence(...)
  codes <- attr(x, "codes"); info <- attr(x, "info")
  if (measure == "jaccard" && identical(info$unit, "overlap")) measure <- "n"
  if (!is.null(codes) && nrow(codes) > max_codes) {
    keep <- sort(order(-codes$n)[seq_len(max_codes)])
    codes <- codes[keep, , drop = FALSE]
  }
  k <- if (is.null(codes)) 0L else nrow(codes)
  title <- .t("Code-\u00dcberschneidungen")
  if (k < 2) {
    return(.svg_out(.svg_doc(420, 40, sprintf('<text x="0" y="24" class="muted">%s</text>',
                                              .svg_esc(.t("Zu wenige Codes f\u00fcr eine Matrix."))), title), file, x))
  }
  val <- matrix(0, k, k); cnt <- matrix(0L, k, k)
  ia <- match(x$code_a, codes$code); ib <- match(x$code_b, codes$code)
  ok <- !is.na(ia) & !is.na(ib)
  v <- if (measure == "n") x$n else x$jaccard
  for (r in which(ok)) {
    val[ia[r], ib[r]] <- val[ib[r], ia[r]] <- v[r]
    cnt[ia[r], ib[r]] <- cnt[ib[r], ia[r]] <- x$n[r]
  }
  vmax <- max(val, na.rm = TRUE)
  labs <- paste0(strrep("\u2002", pmax(0L, codes$depth - 1L)), .svg_short(codes$label, 26))
  cell <- 26; gap <- 2
  lw <- .svg_text_w(labs) + 22                       # row labels + swatch
  top <- ceiling(.svg_text_w(labs) * 0.72) + 16       # column labels at -45 degrees
  rows <- 2:k; cols <- 1:(k - 1)
  x0 <- lw; y0 <- top
  W <- x0 + length(cols) * cell + top; H <- y0 + length(rows) * cell + 8   # room for the rotated labels
  unit_lab <- switch(info$unit, segment = .t("Segmente"), document = .t("Dokumente"),
                     overlap = .t("\u00fcberlappende Codings"))
  out <- character()
  # column labels (rotated) with swatches
  for (j in seq_along(cols)) {
    cx <- x0 + (j - 1) * cell + cell / 2
    out <- c(out, sprintf('<g transform="translate(%.1f,%.1f) rotate(-45)"><rect x="0" y="-5" width="9" height="9" rx="2" fill="%s"/><text x="13" y="3">%s</text></g>',
                          cx, y0 - 6, .svg_esc(codes$color[cols[j]]), .svg_esc(labs[cols[j]])))
  }
  for (i in seq_along(rows)) {
    ri <- rows[i]; cy <- y0 + (i - 1) * cell
    out <- c(out, sprintf('<rect x="4" y="%.1f" width="9" height="9" rx="2" fill="%s"/><text x="18" y="%.1f">%s</text>',
                          cy + cell / 2 - 5, .svg_esc(codes$color[ri]), cy + cell / 2 + 4, .svg_esc(labs[ri])))
    for (j in seq_len(min(i, length(cols)))) {
      cj <- cols[j]; cx <- x0 + (j - 1) * cell
      vv <- val[ri, cj]; st <- .viz_step(vv, vmax)
      tip <- sprintf(.t("%s \u00d7 %s: %d %s gemeinsam"), codes$code[ri], codes$code[cj], cnt[ri, cj], unit_lab)
      if (measure == "jaccard" && cnt[ri, cj] > 0) tip <- paste0(tip, sprintf(" (Jaccard %.2f)", vv))
      click <- if (cnt[ri, cj] > 0) sprintf(' data-a="%s" data-b="%s"', .svg_esc(codes$code[ri]), .svg_esc(codes$code[cj])) else ""
      out <- c(out, sprintf('<rect class="q%d" x="%.1f" y="%.1f" width="%d" height="%d" rx="3"%s><title>%s</title></rect>',
                            st, cx + gap / 2, cy + gap / 2, cell - gap, cell - gap, click, .svg_esc(tip)))
      if (cnt[ri, cj] > 0) {
        lab <- if (measure == "n") as.character(cnt[ri, cj]) else sub("^0", "", sprintf("%.2f", vv))
        out <- c(out, sprintf('<text class="val %s" x="%.1f" y="%.1f" text-anchor="middle">%s</text>',
                              if (st >= 4) "hi" else "lo", cx + cell / 2, cy + cell / 2 + 3.5, lab))
      }
    }
  }
  desc <- sprintf(.t("%d Codes; Zahl = %s; dunkler = h\u00e4ufiger gemeinsam."), k,
                  if (measure == "n") unit_lab else .t("Jaccard-Index"))
  .svg_out(.svg_doc(W, H, out, title, desc), file, x)
}
