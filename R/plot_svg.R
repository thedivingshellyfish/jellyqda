# jellyqda :: plot_svg.R -- shared helpers for the SVG graphics
#
# All graphics (plot_cooccurrence.R, plot_portrait.R, plot_network.R) are
# plain SVG written by R: no extra packages, no JavaScript library, works
# offline in the RStudio Viewer, in the app and in the printable report.
# Every mark carries a <title> (native hover tooltip) and data-* attributes
# that the app uses for clicks (inst/app/www/js/18-visuals.js).
#
# Colour: code identity = colour of the code family (as everywhere in
# jellyqda), always together with the code name; magnitude = one blue ramp,
# light -> dark (7 steps), with its own steps for dark mode.

# XML namespace of SVG: an identifier, never fetched (needed so that a saved
# .svg file opens as a graphic). The offline test allows exactly this string.
.SVG_NS <- "http://www.w3.org/2000/svg"

# Sequential blue ramp, light mode (low -> high) and dark mode (low -> high).
.VIZ_SEQ_LIGHT <- c("#cce3fd", "#9dc8f7", "#6aabf1", "#338ced", "#2370cd", "#1757ac", "#0e3d7e")
.VIZ_SEQ_DARK  <- c("#16324f", "#1b4f8a", "#1f64b4", "#2f80dc", "#5a9ded", "#8cbcf4", "#c4defb")

#' Step (1..7) of a value on the sequential ramp; 0 = value 0 / NA.
#' @noRd
.viz_step <- function(v, vmax) {
  out <- integer(length(v))
  ok <- !is.na(v) & v > 0 & is.finite(vmax) & vmax > 0
  out[ok] <- pmin(7L, pmax(1L, as.integer(ceiling(7 * v[ok] / vmax))))
  out
}

#' Stylesheet for the graphics (light + dark mode of the app).
#' @noRd
.viz_css <- function() {
  light <- paste(sprintf(".jqv .q%d{fill:%s}", 1:7, .VIZ_SEQ_LIGHT), collapse = "")
  dark <- paste(sprintf("[data-bs-theme=\"dark\"] .jqv .q%d{fill:%s}", 1:7, .VIZ_SEQ_DARK), collapse = "")
  paste0(
    ".jqv{font-family:system-ui,-apple-system,'Segoe UI',sans-serif}",
    ".jqv text{fill:#2b3440;font-size:11px}",
    ".jqv .muted{fill:#5d6875}",
    ".jqv .q0{fill:#f1f3f6}",
    ".jqv .none{fill:#e4e8ed}",
    ".jqv .val{font-size:10px;font-variant-numeric:tabular-nums;pointer-events:none}",
    ".jqv .val.hi{fill:#ffffff}",          # number on a dark cell (light mode)
    ".jqv .edge{stroke:#8a96a3;stroke-opacity:.55;stroke-linecap:round}",
    ".jqv .node{stroke:#ffffff;stroke-width:2}",
    ".jqv [data-a]:hover,.jqv [data-jump]:hover{opacity:.75;cursor:pointer}",
    ".jqv .edge[data-a]:hover{stroke-opacity:1;stroke:#2370cd}",
    light,
    "[data-bs-theme=\"dark\"] .jqv text{fill:#e3e7ec}",
    "[data-bs-theme=\"dark\"] .jqv .muted{fill:#a9b3bf}",
    "[data-bs-theme=\"dark\"] .jqv .q0{fill:#242b33}",
    "[data-bs-theme=\"dark\"] .jqv .none{fill:#323b45}",
    # dark mode: the ramp runs dark -> light, so high values need dark numbers
    "[data-bs-theme=\"dark\"] .jqv .val{fill:#e3e7ec}",
    "[data-bs-theme=\"dark\"] .jqv .val.hi{fill:#0e1a26}",
    "[data-bs-theme=\"dark\"] .jqv .edge{stroke:#7d8894}",
    "[data-bs-theme=\"dark\"] .jqv .node{stroke:#1b2128}",
    dark)
}

#' Escape text for SVG.
#' @noRd
.svg_esc <- function(x) htmltools::htmlEscape(as.character(x), attribute = TRUE)

#' Shorten labels for axes ("..." at the end).
#' @noRd
.svg_short <- function(x, n = 28) ifelse(nchar(x) > n, paste0(substr(x, 1, n - 1), "\u2026"), x)

#' Approximate text width in pixels (11px system font).
#' @noRd
.svg_text_w <- function(x, px = 6.3) ceiling(max(c(0, nchar(x))) * px)

#' Assemble a complete <svg> element.
#' @noRd
.svg_doc <- function(width, height, body, title, desc = "") {
  sprintf(paste0('<svg class="jqv" xmlns="%s" width="%d" height="%d" ',
                 'viewBox="0 0 %d %d" role="img" aria-label="%s"><title>%s</title><desc>%s</desc>',
                 '<style>%s</style>%s</svg>'),
          .SVG_NS, as.integer(width), as.integer(height), as.integer(width), as.integer(height),
          .svg_esc(title), .svg_esc(title), .svg_esc(desc), .viz_css(), paste(body, collapse = ""))
}

#' Legend for code families: swatch + name, wrapped into rows.
#' @return list(svg = character, height = numeric)
#' @noRd
.svg_legend <- function(labels, colors, x0, y0, width) {
  if (length(labels) == 0) return(list(svg = "", height = 0))
  x <- x0; y <- y0; out <- character()
  for (i in seq_along(labels)) {
    w <- 18 + .svg_text_w(labels[i]) + 16
    if (x + w > x0 + width && x > x0) { x <- x0; y <- y + 18 }
    out <- c(out, sprintf('<rect x="%.1f" y="%.1f" width="11" height="11" rx="3" fill="%s"/><text x="%.1f" y="%.1f">%s</text>',
                          x, y, .svg_esc(colors[i]), x + 16, y + 9.5, .svg_esc(labels[i])))
    x <- x + w
  }
  list(svg = paste(out, collapse = ""), height = y - y0 + 18)
}

#' Return value of the qda_plot_*() functions: the SVG, shown in the RStudio
#' Viewer when printed, or written to `file`.
#' @noRd
.svg_out <- function(svg, file = NULL, data = NULL) {
  if (!is.null(file)) {
    writeLines(enc2utf8(svg), file, useBytes = TRUE)
    return(invisible(file))
  }
  out <- htmltools::browsable(htmltools::HTML(svg))
  attr(out, "data") <- data
  out
}
