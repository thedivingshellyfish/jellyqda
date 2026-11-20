# Viewer ---------------------------------------------------------------------

#' View a source in the RStudio Viewer with segment numbers and codings
#'
#' Renders the frozen text of a source as HTML: every paragraph is a numbered
#' **segment** (the unit you address in [qda_code()]), and all codings are
#' highlighted in the color of their code. In RStudio the HTML opens in the
#' Viewer pane; elsewhere it is written to a temp file (opened in a browser
#' when interactive).
#'
#' @param source Source id or unique name.
#' @param open Logical; open the HTML in the RStudio Viewer / browser.
#' @return Invisibly, the HTML string.
#' @export
#' @examples
#' \dontrun{
#' qda_view(1)                    # by id
#' qda_view("interview_01.txt")   # by name
#' }
qda_view <- function(source, open = TRUE) {
  con <- qda_con()
  src <- .resolve_source(source)
  segs <- .segments_of(src$frozen_text)
  cods <- DBI::dbGetQuery(con, "
    SELECT c.id, c.start, c.end, c.memo, k.label, k.color
    FROM codings c JOIN codes k ON k.id = c.code_id
    WHERE c.source_id = ? ORDER BY c.start", params = list(src$id))

  esc <- htmltools::htmlEscape
  body <- character()
  for (i in seq_len(nrow(segs))) {
    st <- segs$start[i]; en <- segs$end[i]
    seg_txt <- substring(src$frozen_text, st, en)
    ov <- cods[cods$start <= en & cods$end >= st, , drop = FALSE]
    html_txt <- character(); pos <- st
    if (nrow(ov) > 0) {
      for (j in seq_len(nrow(ov))) {
        cs <- max(ov$start[j], st); ce <- min(ov$end[j], en)
        if (cs > pos) html_txt <- c(html_txt, esc(substring(seg_txt, pos - st + 1, cs - st)))
        html_txt <- c(html_txt, sprintf(
          '<mark style="background-color:%s" title="%s">%s</mark>',
          esc(ov$color[j]), esc(ov$label[j]), esc(substring(seg_txt, cs - st + 1, ce - st + 1))
        ))
        pos <- ce + 1
      }
    }
    if (pos <= en) html_txt <- c(html_txt, esc(substring(seg_txt, pos - st + 1, en - st + 1)))
    body <- c(body, sprintf(
      '<div class="seg"><span class="segnum">Segment %d</span><span class="segtext">%s</span></div>',
      i, paste(html_txt, collapse = "")
    ))
  }
  html <- paste0(
    "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><style>",
    "body{font-family:Georgia,serif;max-width:52em;margin:1.5em auto;line-height:1.55;color:#222}",
    ".src{font-family:sans-serif;font-size:1.1em;font-weight:bold;border-bottom:2px solid #888;",
    "padding-bottom:.3em;margin-bottom:1em}",
    ".src small{font-weight:normal;color:#666}",
    ".seg{margin:0 0 .8em 0;padding-left:6.5em;position:relative}",
    ".segnum{position:absolute;left:0;top:.15em;font-family:monospace;font-size:.8em;",
    "background:#eee;border:1px solid #ccc;border-radius:4px;padding:.1em .4em;color:#444}",
    "mark{padding:0 .1em;border-radius:2px}",
    "</style></head><body>",
    sprintf('<div class="src">%s <small>(%s, %d chars, %d segments)</small></div>',
            esc(src$name), esc(src$format), nchar(src$frozen_text, type = "chars"), nrow(segs)),
    paste(body, collapse = "\n"),
    "</body></html>"
  )
  if (isTRUE(open)) {
    tmp <- tempfile(fileext = ".html")
    writeLines(html, tmp, useBytes = TRUE)
    if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
      rstudioapi::viewer(tmp)
    } else if (interactive()) {
      utils::browseURL(tmp)
    }
  }
  invisible(html)
}
