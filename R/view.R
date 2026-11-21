# jellyqda :: view.R -- qda_view(): frozen text with colored <mark> codings
# as HTML for the RStudio Viewer; segment numbers included.

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
  segs <- .segments_for(src)            # stored or automatic segments
  cods <- .codings_of(src$id)
  dup_ids <- .dup_ids(cods)
  memos <- .passage_memos_of(src$id)
  esc <- htmltools::htmlEscape
  # same marking as the app (render.R): overlaps grey with a number, the
  # code names appear as tooltip
  body <- vapply(seq_len(nrow(segs)), function(i) {
    sprintf('<div class="seg"><span class="segnum">Segment %d</span><span class="segtext">%s</span></div>',
            i, .marked_html(src$frozen_text, segs$start[i], segs$end[i], cods, dup_ids,
                            memos = memos))
  }, character(1))
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
    "mark.memomark{background:transparent;border-bottom:3px solid #b58900}",
    "mark.dup{outline:2px dashed #d81b60;outline-offset:1px}",
    "mark.ovl{background-color:#dde1e6;background-size:100% 3px;background-position:left bottom;background-repeat:no-repeat}",
    "mark.ovl.ovl-start::before{content:attr(data-n);font:700 .62rem/1.25 sans-serif;color:#fff;background:#5a6672;border-radius:.7rem;padding:0 .32rem;margin-right:.18rem;vertical-align:.18em}",
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
