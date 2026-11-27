# jellyqda :: plot_network.R -- qda_plot_network(): codes as nodes, lines
# for co-occurrence (data: qda_cooccurrence(), R/cooccurrence.R).
# Layout "circle" (default: codes in tree order around a circle, code
# families next to each other, deterministic, good for print) or "force" (a
# small Fruchterman-Reingold layout: related codes move together).
# SVG helpers in R/plot_svg.R.

#' Positions of the nodes, in a unit square [0, 1] x [0, 1].
#' @noRd
.net_layout <- function(k, edges, layout = "circle", iterations = 300) {
  ang <- -pi / 2 + 2 * pi * (seq_len(k) - 1) / max(1, k)
  pos <- cbind(0.5 + 0.5 * cos(ang), 0.5 + 0.5 * sin(ang))
  if (layout == "circle" || k < 3 || nrow(edges) == 0) return(pos)
  # Fruchterman-Reingold, started on the circle (deterministic)
  kk <- sqrt(1 / k); temp <- 0.1
  w <- edges$w / max(edges$w)
  for (it in seq_len(iterations)) {
    d <- array(0, c(k, 2))
    dx <- outer(pos[, 1], pos[, 1], "-"); dy <- outer(pos[, 2], pos[, 2], "-")
    dist <- sqrt(dx^2 + dy^2) + 1e-6
    rep_f <- kk^2 / dist; diag(rep_f) <- 0
    d[, 1] <- rowSums(dx / dist * rep_f); d[, 2] <- rowSums(dy / dist * rep_f)
    for (e in seq_len(nrow(edges))) {
      a <- edges$a[e]; b <- edges$b[e]
      vx <- pos[a, 1] - pos[b, 1]; vy <- pos[a, 2] - pos[b, 2]
      ds <- sqrt(vx^2 + vy^2) + 1e-6
      att <- ds^2 / kk * (0.3 + 0.7 * w[e])
      d[a, ] <- d[a, ] - c(vx, vy) / ds * att
      d[b, ] <- d[b, ] + c(vx, vy) / ds * att
    }
    len <- sqrt(rowSums(d^2)) + 1e-9
    pos <- pos + d / len * pmin(len, temp)
    temp <- temp * 0.985
  }
  rng <- function(v) if (diff(range(v)) < 1e-9) rep(0.5, length(v)) else (v - min(v)) / diff(range(v))
  cbind(rng(pos[, 1]), rng(pos[, 2]))
}

#' Code network: codes as circles, lines for co-occurrence
#'
#' Draws [qda_cooccurrence()] as a network: every code is a circle (colour
#' of its code family, size = how often it was used), a line connects two
#' codes that occur together (thicker = more often). With `layout =
#' "circle"` the codes sit in code-tree order around a circle, so code
#' families stay next to each other; `layout = "force"` pulls related codes
#' together. Hovering shows the numbers; in the app a click on a line lists
#' the passages.
#'
#' @param x Result of [qda_cooccurrence()]; if `NULL` it is computed with
#'   `...`.
#' @param min_n Draw only lines for pairs that occur together at least this
#'   often.
#' @param layout `"circle"` or `"force"`.
#' @param size Width and height of the drawing area in pixels.
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
#' svg <- qda_plot_network()
#' svg <- qda_plot_network(layout = "force", level = "top")
#' qda_close()
qda_plot_network <- function(x = NULL, min_n = 1L, layout = c("circle", "force"), size = 560,
                             file = NULL, ...) {
  layout <- match.arg(layout)
  if (is.null(x)) x <- qda_cooccurrence(...)
  codes <- attr(x, "codes"); info <- attr(x, "info")
  title <- .t("Code-Netzwerk")
  k <- if (is.null(codes)) 0L else nrow(codes)
  if (k < 2) {
    return(.svg_out(.svg_doc(420, 40, sprintf('<text x="0" y="24" class="muted">%s</text>',
                                              .svg_esc(.t("Zu wenige Codes f\u00fcr ein Netzwerk."))), title), file, x))
  }
  e <- x[x$n >= max(1L, as.integer(min_n)), , drop = FALSE]
  edges <- data.frame(a = match(e$code_a, codes$code), b = match(e$code_b, codes$code), w = e$n)
  edges <- edges[!is.na(edges$a) & !is.na(edges$b), , drop = FALSE]
  pos <- .net_layout(k, edges, layout)
  labs <- .svg_short(codes$label, 24)
  pad_x <- .svg_text_w(labs) + 24; pad_y <- 34
  W <- size + 2 * pad_x; H <- size + 2 * pad_y
  px <- pad_x + pos[, 1] * size; py <- pad_y + pos[, 2] * size
  nmax <- max(1, codes$n); wmax <- if (nrow(edges)) max(edges$w) else 1
  r <- 6 + 12 * sqrt(codes$n / nmax)
  unit_lab <- switch(info$unit, segment = .t("Segmente"), document = .t("Dokumente"),
                     overlap = .t("\u00fcberlappende Codings"))
  out <- character()
  ord <- order(edges$w)                       # thick lines on top
  for (i in ord) {
    a <- edges$a[i]; b <- edges$b[i]
    tip <- sprintf(.t("%s \u2013 %s: %d %s gemeinsam"), codes$code[a], codes$code[b], edges$w[i], unit_lab)
    out <- c(out, sprintf('<line class="edge" x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke-width="%.1f" data-a="%s" data-b="%s"><title>%s</title></line>',
                          px[a], py[a], px[b], py[b], 1 + 7 * edges$w[i] / wmax,
                          .svg_esc(codes$code[a]), .svg_esc(codes$code[b]), .svg_esc(tip)))
  }
  for (j in seq_len(k)) {
    tip <- sprintf(.t("%s: %d %s"), codes$code[j], codes$n[j], unit_lab)
    out <- c(out, sprintf('<circle class="node" cx="%.1f" cy="%.1f" r="%.1f" fill="%s"%s><title>%s</title></circle>',
                          px[j], py[j], r[j], .svg_esc(codes$color[j]), "", .svg_esc(tip)))
    # label outside the node: to the right on the right half, to the left otherwise
    right <- pos[j, 1] >= 0.5
    out <- c(out, sprintf('<text x="%.1f" y="%.1f" text-anchor="%s">%s</text>',
                          px[j] + (if (right) 1 else -1) * (r[j] + 5), py[j] + 4,
                          if (right) "start" else "end", .svg_esc(labs[j])))
  }
  desc <- sprintf(.t("%d Codes, %d Verbindungen; Kreisgr\u00f6\u00dfe = H\u00e4ufigkeit, Linienst\u00e4rke = gemeinsam in %s."),
                  k, nrow(edges), unit_lab)
  .svg_out(.svg_doc(W, H, out, title, desc), file, x)
}
