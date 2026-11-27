# jellyqda :: app_helpers.R -- small helpers of the Shiny app qda_app():
# button icons, in-vivo code names, the report as HTTP response and the
# icon registry.

# --- Button icons ----------------------------------------------------------------
# fontawesome::fa() returns an SVG. Older shiny versions (< 1.8.1, e.g. from
# the Ubuntu package sources) only accept <i> tags as button icons ("Invalid
# icon"). Hence the SVG is wrapped in an <i>: works everywhere.
#' @noRd
.jq_ico <- function(name) shiny::tags$i(class = "jq-btnico", fontawesome::fa(name))

# --- In-vivo code: turn the marked text into a code name ---------------------
# Collapse white space, drop punctuation/quotes at the edges, shorten to at
# most `max` characters at a word boundary.
#' @noRd
.invivo_label <- function(x, max = 60L) {
  x <- gsub("\\s+", " ", trimws(as.character(x)))
  x <- gsub("^[[:punct:]\u201e\u201c\u201d\u00bb\u00ab\u2013 ]+|[[:punct:]\u201e\u201c\u201d\u00bb\u00ab\u2013 ]+$", "", x, perl = TRUE)
  if (nchar(x) > max) {
    cut <- substr(x, 1, max)
    sp <- regexpr(" [^ ]*$", cut)
    x <- paste0(if (sp > 20) substr(cut, 1, sp - 1) else cut, "\u2026")
  }
  x
}

# --- Report as HTTP response (report tab, see report_url in the server) -----
#' @noRd
.report_response <- function() {
  html <- tryCatch(.report_html(), error = function(e)
    paste0(.t("<!DOCTYPE html><meta charset='utf-8'><p>Bericht konnte nicht erzeugt werden: "),
           htmltools::htmlEscape(conditionMessage(e)), "</p>"))
  shiny::httpResponse(200L, "text/html; charset=UTF-8", enc2utf8(html),
                      headers = list(`Cache-Control` = "no-store"))
}

# --- Icon registry ---------------------------------------------------------------
# All Font Awesome icons that appear as <i class="fa-solid fa-NAME"> in
# server-generated HTML (and those of the UI buttons).
#' @noRd
.jq_icon_names <- function() {
  c("folder-tree", "tags", "tag", "highlighter", "note-sticky", "trash", "floppy-disk",
    "file-export", "plus", "file-lines", "table-columns", "pen", "chevron-down",
    "table-cells", "table-list", "xmark", "check", "rotate-left", "rotate-right", "moon",
    "scissors", "circle-question", "magnifying-glass", "book", "comment",
    "chart-column", "arrow-up-right-from-square", "box-archive", "file-word",
    "book-open", "code-merge")
}
#' @noRd
.jq_icon_registry <- function() {
  shiny::div(id = "jq-icons", style = "display:none",
    lapply(.jq_icon_names(), function(n) shiny::span(`data-faicon` = n, fontawesome::fa(n))))
}
