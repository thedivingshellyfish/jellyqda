# jellyqda :: app.R -- the interactive Shiny app qda_app() (the 'V2 door')
#
# The app is spread over several files (R allows no subfolders in R/, so the
# files share the prefix app_):
#   R/app.R              -- qda_app() (exported entry point, starts the local
#                           app) + .jellyqda_assets() (includes CSS + JS)
#   R/app_ui.R           -- .jellyqda_ui(): page layout: top bar, symbol bar,
#                           3-pane grid with 7 draggable panels
#   R/app_helpers.R      -- button icons, in-vivo labels, report response,
#                           icon registry
#   R/app_server.R       -- .jellyqda_server(): reactive state + shared
#                           helpers; registers the server parts below
#   R/app_server_*.R     -- the server parts by topic (documents, coding,
#                           codes, memos, project, analysis, tables): every
#                           button/input has an observeEvent; outputs render
#                           HTML rows; all state in one DB file
#
# The document text as HTML (#doc, codings as <mark>, overlaps) is built in
# R/render.R (.render_doc_html), segments come from R/segments.R.
#
# Files outside R/ (see inst/app/www/README.md):
#   inst/app/www/css/*.css -- complete styling incl. dark mode
#   inst/app/www/js/*.js   -- complete browser logic: text selection ->
#                             character offsets, delegated clicks,
#                             shortcuts, zoom, dark mode, drag & drop
#                             (panels, files, code re-parenting), layout
#                             persistence (localStorage)
#
# Data flow: browser JS (Shiny.setInputValue) -> Shiny inputs -> server
# handlers (observeEvent) -> qda_* API (other R files) -> SQLite ->
# renderUI outputs -> browser.
#
# To change the look: edit inst/app/www/css/ (+ the fa() icon list in
# .jellyqda_ui() in R/app_ui.R); labels are plain strings here. See README section
# 'Customizing the look'. After editing CSS/JS: reinstall the package.

# qda_app: local Shiny UI (V2) -------------------------------------------------
# One command starts a local-only web UI (127.0.0.1, no internet) inside the
# RStudio Viewer pane -- the "V2 door" reserved in concept section 3.
#
# Layout follows the MAXQDA *workflow logic* (concept section 6), in jellyqda's
# own look (the concept explicitly forbids copying MAXQDA's colors/icons):
#   left column   : Documents tree (top) + Code System tree (bottom)
#   center        : Document Browser (top, select text -> code/memo buttons)
#                   + Retrieved Segments for the selected code (bottom)
#   right column  : Memos (memo of the clicked coding + free memos)
# All data flows through the same qda_*() API into the same .jellyqda file.

#' Start the jellyqda app (local Shiny UI) for the active project
#'
#' Launches a local Shiny app on `127.0.0.1` (loopback only -- fully offline)
#' and opens it in the RStudio Viewer pane when running inside RStudio.
#' The layout shows all panes at once: document tree, code system, document
#' browser (mark text with the mouse, then click a code button or the memo
#' button to store the coding at the exact character offsets), retrieved
#' segments per selected code, and the memo panel.
#'
#' The call blocks the console while the app runs (press Esc to stop), like
#' any Shiny app. Open the printed URL in additional browser windows/tabs for
#' a multi-window setup -- all windows share the same session and project.
#'
#' Requires the suggested packages `shiny`, `bslib` and
#' `fontawesome` (install once; runtime needs no internet).
#'
#' @param host Host to bind; loopback only, default `"127.0.0.1"`.
#' @param port Port; `NULL` picks a random free port.
#' @param open Logical; open the app at all.
#' @param new_window Logical; open the app in a **new browser window**
#'   (default, recommended -- the RStudio Viewer pane is small). With
#'   `new_window = FALSE` it opens inside the RStudio Viewer pane instead.
#' @param lang User interface language, `"en"` or `"de"`. `NULL` (default)
#'   uses [qda_language()] (option `jellyqda.lang` or the system locale).
#'   The language can also be switched in the app (EN/DE button).
#' @return Invisibly `NULL` (after the app is stopped).
#' @export
#' @examples
#' if (interactive()) {
#'   qda_open(file.path(tempfile(), "example.jellyqda"))
#'   qda_app()                    # new browser window; Esc stops the app
#'   qda_app(lang = "de")         # German user interface
#'   qda_app(new_window = FALSE)  # inside the RStudio Viewer pane
#' }
qda_app <- function(host = "127.0.0.1", port = NULL, open = TRUE, new_window = TRUE, lang = NULL) {
  if (!qda_is_open()) {
    stop("No jellyqda project is open. Call qda_open(path) first.", call. = FALSE)
  }
  if (!is.null(lang)) qda_language(lang)
  for (p in c("shiny", "bslib", "fontawesome")) {
    if (!requireNamespace(p, quietly = TRUE)) {
      stop(sprintf("qda_app() needs the package '%s' (install once, runtime stays offline): install.packages('%s')", p, p), call. = FALSE)
    }
  }
  # ui as a function: evaluated per page request, so "?lang=en" / "?lang=de"
  # in the address (EN/DE button) switches the language
  app <- shiny::shinyApp(ui = function(req) .jellyqda_ui(req), server = .jellyqda_server)
  launcher <- function(url) {
    cat("jellyqda app (local, offline):", url, "\n")
    if (isTRUE(open)) {
      if (isTRUE(new_window)) {
        utils::browseURL(url)  # eigenes Browser-Fenster
      } else if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
        rstudioapi::viewer(url)  # RStudio Viewer-Pane
      } else {
        utils::browseURL(url)
      }
    }
  }
  shiny::runApp(app, host = host, port = port,
                launch.browser = if (isTRUE(open)) launcher else FALSE)
  invisible(NULL)
}

# --- Include CSS + JS (files in inst/app/www/) ---------------------------------
# All styling and the complete browser logic live in their own files, not as
# long strings in R code:
#
#   inst/app/www/css/*.css -- look (layout, colours, dark mode), 9 files
#   inst/app/www/js/*.js   -- browser logic (text selection -> offsets,
#                             clicks -> Shiny inputs, keyboard shortcuts,
#                             drag & drop, saving the layout), 17 files
#
# The files are numbered; they are read in name order and joined into ONE
# <style> and ONE <script> tag -- exactly as if they were one big file. So
# the order of CSS rules (cascade) stays the same, and JS functions of one
# file can be used in every other file. A new file only needs the right
# number in front.
#
# After installation inst/app/www/ is app/www/ in the package folder;
# system.file() finds it (also with devtools::load_all()).
#
# The files are read at every app start and their content is written
# directly into the <head> of the page, so the browser can never use an
# outdated cached version.
#
# When changing CSS/JS: reinstall the package (devtools::install()) or run
# devtools::load_all() and restart R.
#' @noRd
.jellyqda_assets <- function() {
  www <- system.file("app", "www", package = "jellyqda")
  if (!nzchar(www)) {
    stop("jellyqda: folder app/www not found - please reinstall the package.",
         call. = FALSE)
  }
  shiny::tagList(
    htmltools::tags$style(type = "text/css", htmltools::HTML(.jq_read_assets(www, "css"))),
    htmltools::tags$script(htmltools::HTML(.jq_read_assets(www, "js")))
  )
}

# All files www/<type>/*.<type> in name order, joined into one string.
#' @noRd
.jq_read_assets <- function(www, type) {
  files <- list.files(file.path(www, type), pattern = paste0("\\.", type, "$"),
                      full.names = TRUE)
  files <- files[order(basename(files), method = "radix")]
  if (!length(files)) {
    stop(sprintf("jellyqda: no .%s files in app/www/%s - please reinstall the package.",
                 type, type), call. = FALSE)
  }
  txt <- vapply(files, function(f)
    paste(readLines(f, encoding = "UTF-8", warn = FALSE), collapse = "\n"), character(1))
  paste(txt, collapse = "\n\n")
}
