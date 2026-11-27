# jellyqda :: report_visuals.R -- sections "Code-Ueberschneidungen" and
# "Dokument-Portraits" of the HTML report (.report_html() in R/export.R).
# Uses the same SVG graphics as the app (R/plot_*.R), co-occurrence by
# segment, code families for the portraits. Large projects: at most 25 codes
# in the heatmap, lines from 2 joint occurrences in the network.

#' Report section with heatmap + network ("" if there is nothing to show).
#' @noRd
.viz_report_cooc <- function() {
  x <- tryCatch(qda_cooccurrence(unit = "segment", level = "code"), error = function(e) NULL)
  if (is.null(x) || nrow(x) == 0) return("")
  codes <- attr(x, "codes")
  min_n <- if (nrow(x) > 40) 2L else 1L
  paste0(
    .t('<p class="meta">Codes, die im selben Segment vorkommen. Zahl = Anzahl der Segmente mit beiden Codes; je dunkler, desto h\u00e4ufiger.'),
    if (nrow(codes) > 25) sprintf(.t(" Gezeigt: die %d h\u00e4ufigsten Codes."), 25L) else "", "</p>",
    '<div class="rsvg">', as.character(qda_plot_cooccurrence(x, max_codes = 25)), "</div>",
    sprintf(.t('<p class="meta">Code-Netzwerk: Kreisgr\u00f6\u00dfe = Anzahl Segmente mit dem Code, Linienst\u00e4rke = gemeinsam in Segmenten%s.</p>'),
            if (min_n > 1) sprintf(.t(" (Linien ab %d)"), min_n) else ""),
    '<div class="rsvg">', as.character(qda_plot_network(x, min_n = min_n, size = 440)), "</div>")
}

#' Report section with the document portraits ("" if nothing is coded).
#' @noRd
.viz_report_portraits <- function() {
  x <- tryCatch(qda_portrait(level = "top"), error = function(e) NULL)
  if (is.null(x) || nrow(x) == 0 || all(is.na(x$code))) return("")
  paste0(.t('<p class="meta">Jedes Dokument von Anfang (links) bis Ende (rechts); jedes Segment ein Block in der Farbe der Code-Familien, die es enth\u00e4lt.</p>'),
         '<div class="rsvg">', as.character(qda_plot_portrait(x, width = 520, interactive = FALSE)), "</div>")
}
