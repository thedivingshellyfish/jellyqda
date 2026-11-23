# jellyqda :: app.R -- the interactive Shiny app qda_app() (the 'V2 door')
#
# Structure of this file (top to bottom):
#   1. qda_app()               -- exported entry point, starts the local app
#   2. .jellyqda_assets()      -- includes CSS + JS from inst/app/www/
#   3. .jellyqda_ui()          -- page layout: top bar, symbol bar, 3-pane
#      grid with 7 draggable panels
#   4. .jellyqda_server()      -- all reactive logic: every button/input has
#      an observeEvent; outputs render HTML rows; all state in one DB file
#
# The document text as HTML (#doc, codings as <mark>, overlaps) is built in
# R/render.R (.render_doc_html), segments come from R/segments.R.
#
# Files outside this R file:
#   inst/app/www/jellyqda.css  -- complete styling incl. dark mode
#   inst/app/www/jellyqda.js   -- complete browser logic: text selection ->
#                                 character offsets, delegated clicks,
#                                 shortcuts, zoom, dark mode, drag & drop
#                                 (panels, files, code re-parenting), layout
#                                 persistence (localStorage)
#
# Data flow: browser JS (Shiny.setInputValue) -> Shiny inputs -> server
# handlers (observeEvent) -> qda_* API (other R files) -> SQLite ->
# renderUI outputs -> browser.
#
# To change the look: edit inst/app/www/jellyqda.css (+ the fa() icon list in
# .jellyqda_ui()); labels are plain strings here. See README section
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
# long strings in this file:
#
#   inst/app/www/jellyqda.css  -- look (layout, colours, dark mode)
#   inst/app/www/jellyqda.js   -- browser logic (text selection -> offsets,
#                                 clicks -> Shiny inputs, keyboard shortcuts,
#                                 drag & drop, saving the layout)
#
# After installation inst/app/www/ is app/www/ in the package folder;
# system.file() finds it (also with devtools::load_all()).
#
# includeCSS()/includeScript() read the files at every app start and write
# their content directly into the <head> of the page, so the browser can
# never use an outdated cached version.
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
    htmltools::includeCSS(file.path(www, "jellyqda.css")),
    htmltools::includeScript(file.path(www, "jellyqda.js"))
  )
}


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

# --- UI: four-pane layout (MAXQDA workflow logic, jellyqda look) -------------
#' @noRd
.jellyqda_ui <- function(req = NULL) {
  # language for this page: ?lang=xx in the address, else the current one
  l <- .lang_from_query(if (is.null(req)) NULL else req$QUERY_STRING)
  if (!is.null(l)) .jq_i18n$lang <- l
  lang <- .lang()
  fa <- fontawesome::fa
  bslib::page_fluid(
    lang = lang,
    theme = bslib::bs_theme(version = 5, primary = "#2c6fbb", font_scale = 0.82),
    shiny::tags$head(
      .jq_i18n_script(lang),  # language + English catalogue for jqT() in jellyqda.js
      .jellyqda_assets(),   # CSS + JS from inst/app/www/ (see above)
      # Icon registry (invisible): fontawesome::fa() returns SVG graphics, NOT
      # an icon font. HTML written by the server uses
      # <i class="fa-solid fa-NAME"></i>, which without a font would be 0x0
      # pixels (invisible). jellyqda.js (section 14) replaces every such <i>
      # with a copy of the SVG from this registry.
      # New icon in server HTML? -> add its name to .jq_icon_names()
      # (a test checks this: test-app-icons.R, "icon registry").
      .jq_icon_registry()
    ),
    shiny::div(class = "topbar",
      shiny::span(class = "stats", shiny::textOutput("stats_line", inline = TRUE)),
      shiny::span(class = "savedline", shiny::span(class = "savedot"),
                  shiny::textOutput("saved_line", inline = TRUE)),
      shiny::div(class = "btnsection",
        # Save (Ctrl+S): every action is in the project file immediately
        # anyway; the button additionally checkpoints it and creates a restore
        # point (backup).
        shiny::actionButton("save_btn", .t("Speichern"), icon = .jq_ico("floppy-disk"),
                            class = "btn-sm btn-primary jq-save",
                            title = .t("Speichern + Sicherungspunkt anlegen (Strg+S)")),
        # Undo / redo (Ctrl+Z / Ctrl+Y). The tooltip shows exactly what will
        # happen; the server updates it via "jellyqdaHistory".
        shiny::actionButton("undo_btn", NULL, icon = .jq_ico("rotate-left"),
                            class = "btn-sm btn-outline-secondary jq-iconbtn", title = .t("R\u00fcckg\u00e4ngig (Strg+Z)")),
        shiny::actionButton("redo_btn", NULL, icon = .jq_ico("rotate-right"),
                            class = "btn-sm btn-outline-secondary jq-iconbtn", title = .t("Wiederholen (Strg+Y)")),
        shiny::span(class = "symsep"),
        # Report: link with target="_blank" -> own browser tab (the server
        # creates the report anew on every request, see report_url)
        shiny::uiOutput("report_link", inline = TRUE),
        # Analysis: word frequencies, keyword in context, Mayring table
        shiny::actionButton("analysis_btn", .t("Analyse"), icon = .jq_ico("magnifying-glass-chart"),
                            class = "btn-sm btn-outline-secondary",
                            title = .t("Worth\u00e4ufigkeiten, Stichwort im Kontext, Zusammenfassung nach Mayring")),
        # Export menu (<details>: opens without extra JavaScript)
        shiny::tags$details(class = "jq-menu",
          shiny::tags$summary(class = "btn btn-sm btn-outline-secondary",
                              fa("file-export"), .t(" Export "), fa("chevron-down")),
          shiny::div(class = "jq-menu-list",
            shiny::actionButton("export_btn", .t("Alles exportieren (CSV, Excel, Word, Bericht)"),
                                icon = .jq_ico("file-export"), class = "btn-sm jq-menuitem"),
            shiny::actionButton("export_codebook_btn", .t("Codebuch mit Hierarchie (Word + CSV)"),
                                icon = .jq_ico("file-word"), class = "btn-sm jq-menuitem"),
            shiny::actionButton("export_report_btn", .t("Bericht als HTML-Datei speichern"),
                                icon = .jq_ico("chart-column"), class = "btn-sm jq-menuitem"),
            shiny::tags$hr(),
            shiny::actionButton("backup_btn", .t("Backup anlegen (.zip)"), icon = .jq_ico("box-archive"),
                                class = "btn-sm jq-menuitem"),
            shiny::actionButton("layout_reset", .t("Layout zur\u00fccksetzen"), icon = .jq_ico("table-columns"),
                                class = "btn-sm jq-menuitem")
          )
        )
      ),
      shiny::div(class = "symbolbar",
        shiny::span(class = "symgroup",
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-docs", title = .t("Dokumente ein-/ausklappen"), fa("folder-tree")),
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-codes", title = .t("Code System ein-/ausklappen"), fa("tags")),
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-matrix", title = .t("Code-Matrix ein-/ausklappen"), fa("table-cells"))),
        shiny::span(class = "symsep"),
        shiny::span(class = "symgroup",
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-browser", title = .t("Dokument-Browser ein-/ausklappen"), fa("file-lines")),
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-segs", title = .t("All Codings ein-/ausklappen"), fa("highlighter"))),
        shiny::span(class = "symsep"),
        shiny::span(class = "symgroup",
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-memos", title = .t("Memos ein-/ausklappen"), fa("note-sticky")),
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-summary", title = .t("Summary Grid ein-/ausklappen"), fa("table-list"))),
        shiny::span(class = "symsep"),
        shiny::tags$button(class = "symbtn", `data-dark` = "1", title = .t("Dark Mode umschalten"), fa("moon")),
        shiny::tags$button(class = "symbtn", `data-help` = "1", title = .t("Hilfe: Symbole, Tastenkuerzel"), fa("circle-question")),
        # language switch: link to the other language (remembered by jellyqda.js)
        shiny::tags$a(class = "symbtn langbtn", href = if (lang == "en") "?lang=de" else "?lang=en",
                      `data-setlang` = if (lang == "en") "de" else "en",
                      title = if (lang == "en") "Deutsche Oberfl\u00e4che" else "English user interface",
                      if (lang == "en") "DE" else "EN"),
        shiny::span(class = "symsep"),
        shiny::tags$button(class = "symbtn closeapp", `data-closeapp` = "1", title = .t("App beenden (speichert + stoppt)"), fa("xmark"))
      )
    ),
    shiny::div(class = "appgrid",
      # left column: document tree (top) + code system (bottom)
      shiny::div(class = "pane left", `data-pane` = "left",
        shiny::div(class = "panel docs", id = "panel-docs",
shiny::div(class = "panelhead", draggable = "true", fa("folder-tree"), shiny::span(class = "hlabel", .t("Dokumente")), shiny::span(class = "toggler", `data-toggle` = "panel-docs", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody",
            shiny::uiOutput("doc_tree"),
            shiny::hr(),
            # segmentation for newly imported documents (can be changed later)
            shiny::selectInput("import_segrule", .t("Segmente beim Import"),
                               choices = .segrule_choices(), selected = "blankline"),
            shiny::fileInput("import_files", NULL, multiple = TRUE,
                             accept = c(".txt", ".md", ".docx", ".pdf"), buttonLabel = .t("Dateien...")),
            shiny::p(class = "jq-hint", style = "padding:.2rem;margin:.2rem 0",
                     .t("oder Dateien hierher ziehen")),
            shiny::actionButton("import_btn", .t("Importieren"), icon = .jq_ico("plus"), class = "btn-sm btn-primary"),
            shiny::hr(),
            shiny::selectInput("var_doc", .t("Variablen fuer Dokument"), choices = character()),
            shiny::div(style = "display:flex; gap:.3rem;",
              shiny::textInput("var_key", NULL, placeholder = .t("Variable (z.B. Alter)")),
              shiny::textInput("var_val", NULL, placeholder = .t("Wert"))),
            shiny::actionButton("var_add_btn", .t("Variable setzen"), icon = .jq_ico("plus"), class = "btn-sm btn-secondary"),
            shiny::uiOutput("var_list"),
            shiny::hr(),
            # Re-segment the open document.
            # Split/merge single segments: click into the text (segment bar)
            # or mark text -> "As segment".
            shiny::selectInput("seg_rule", .t("Segmente des offenen Dokuments"),
                               choices = .segrule_choices(), selected = "speaker"),
            shiny::actionButton("seg_apply", .t("Neu einteilen"), icon = .jq_ico("scissors"),
                                class = "btn-sm btn-secondary",
                                title = .t("Segmente nach der gew\u00e4hlten Regel neu einteilen (Codings bleiben erhalten, Strg+Z macht es r\u00fcckg\u00e4ngig)"))
          )
        ),
        shiny::div(class = "panel codes", id = "panel-codes",
shiny::div(class = "panelhead", draggable = "true", fa("tags"), shiny::span(class = "hlabel", "Code System"),
                     # "+ Code": new top-level code, directly in the tree (jellyqda.js, section 15)
                     shiny::tags$button(class = "addroot", `data-addroot` = "1",
                                        title = .t("Neuen Code anlegen"), "+ Code"),
                     shiny::span(class = "toggler", `data-toggle` = "panel-codes", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody",
            # tools: filter, expand/collapse all (all in the browser, jellyqda.js)
            shiny::div(class = "treetools",
              shiny::tags$input(type = "search", id = "code_filter", class = "form-control form-control-sm",
                                placeholder = .t("Codes filtern \u2026"), `aria-label` = .t("Codes filtern")),
              shiny::tags$button(class = "btn btn-sm btn-outline-secondary", `data-codeall` = "open",
                                 title = .t("Alle ausklappen"), "\u229e"),
              shiny::tags$button(class = "btn btn-sm btn-outline-secondary", `data-codeall` = "close",
                                 title = .t("Alle einklappen"), "\u229f")),
            shiny::uiOutput("code_tree"),
            shiny::div(class = "jq-hint codelegend",
              shiny::span(.t("Doppelklick = umbenennen \u00b7 Zahl = eigene Codings \u00b7 \u03a3 = mit Subcodes")),
              shiny::span(.t("Auf anderen Code ziehen = umh\u00e4ngen \u00b7 Farbpunkt = Farbe der Code-Familie")))
          )
        ),
        shiny::div(class = "panel matrix", id = "panel-matrix",
          shiny::div(class = "panelhead", draggable = "true", fa("table-cells"), shiny::span(class = "hlabel", .t("Code-Matrix")),
                     shiny::span(class = "toggler", `data-toggle` = "panel-matrix", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody", shiny::uiOutput("matrix_panel"))
        )
      ),
      shiny::div(class = "colhandle", `data-a` = "0", `data-b` = "2"),
      # center: document browser (top) + retrieved segments (bottom)
      shiny::div(class = "pane center", `data-pane` = "center",
        shiny::div(class = "panel browser", id = "panel-browser",
          shiny::div(class = "panelhead", draggable = "true", fa("file-lines"), shiny::span(class = "hlabel", shiny::textOutput("doc_title", inline = TRUE)),
                     shiny::span(class = "zoombtns",
                                 shiny::tags$button(`data-zoom` = "-0.1", title = .t("Schrift kleiner"), "A-"),
                                 shiny::tags$button(`data-zoom` = "0.1", title = .t("Schrift groesser"), "A+")),
                     shiny::span(class = "toggler", `data-toggle` = "panel-browser", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody",
            shiny::uiOutput("clicked_bar"),
            shiny::uiOutput("actionbar"),
            shiny::uiOutput("segbar"),
            shiny::uiOutput("doc_vars"),
            shiny::div(class = "docarea", shiny::uiOutput("doc"))
          )
        ),
        shiny::div(class = "panel segs", id = "panel-segs",
shiny::div(class = "panelhead", draggable = "true", fa("highlighter"), shiny::span(class = "hlabel", shiny::uiOutput("seg_head", inline = TRUE)), shiny::span(class = "toggler", `data-toggle` = "panel-segs", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody",
            shiny::div(style = "display:flex; gap:.3rem; margin-bottom:.3rem;",
              shiny::textInput("search_q", NULL, placeholder = .t("Im ganzen Projekt suchen ...")),
              shiny::actionButton("search_btn", .t("Suchen"), icon = .jq_ico("magnifying-glass"), class = "btn-sm btn-secondary")),
            shiny::selectInput("var_filter", .t("Nur Dokumente mit Variable"), choices = stats::setNames("", .t("(alle)"))),
            shiny::uiOutput("search_results"),
            shiny::uiOutput("seg_panel")
          )
        )
      ),
      shiny::div(class = "colhandle", `data-a` = "2", `data-b` = "4"),
      # right column: memos
      shiny::div(class = "pane right", `data-pane` = "right",
        shiny::div(class = "panel memos", id = "panel-memos",
shiny::div(class = "panelhead", draggable = "true", fa("note-sticky"), shiny::span(class = "hlabel", "Memos"), shiny::span(class = "toggler", `data-toggle` = "panel-memos", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody memopanel",
            # new memos: one button per kind, active only with a matching reference
            shiny::uiOutput("memo_toolbar"),
            # form for a new memo (appears after a click on "+ ...")
            shiny::uiOutput("memo_new_form"),
            # filter (kind), search, open document only
            shiny::uiOutput("memo_filters"),
            shiny::div(class = "memosearch",
              shiny::textInput("memo_search", NULL, placeholder = .t("Memos durchsuchen ...")),
              shiny::checkboxInput("memo_only_doc", .t("nur offenes Dokument"), value = FALSE)),
            # the memo cards
            shiny::uiOutput("memos_list")
          )
        ),
        shiny::div(class = "panel summary", id = "panel-summary",
          shiny::div(class = "panelhead", draggable = "true", fa("table-list"), shiny::span(class = "hlabel", "Summary Grid"),
                     shiny::span(class = "toggler", `data-toggle` = "panel-summary", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody",
            shiny::p(class = "jq-sub",
                     .t("Zelle anklicken = Segmente + Summary bearbeiten.")),
            shiny::uiOutput("sum_matrix"),
            shiny::hr(),
            shiny::uiOutput("sum_detail")
          )
        )
      )
    )
  )
}

# --- server -------------------------------------------------------------------
#' @noRd
.jellyqda_server <- function(input, output, session) {
  # language of this session (same rule as the page: ?lang=xx, else current)
  l <- .lang_from_query(shiny::isolate(session$clientData$url_search))
  if (!is.null(l)) .jq_i18n$lang <- l
  # Reactive state of the session:
  #   src       -- id of the open document
  #   sel       -- current text selection list(start, end, text), 1-based,
  #                from jellyqda.js (input$selection) or the segment badge
  #   clicked   -- id of the clicked coding (blue bar)
  #   sel_code  -- code selected in the code tree
  #   sel_memo  -- passage memo highlighted in the text
  #   memo_filter / memo_new / memo_focus -- state of the memo panel
  #   tick      -- counter; every change to the database calls bump(), and
  #                all outputs that read rv$tick re-render
  rv <- shiny::reactiveValues(src = NULL, sel = NULL, clicked = NULL, sel_code = NULL,
                              edit_entry = NULL, sum_cell = NULL, sel_memo = NULL, tick = 0,
                              search = NULL, var_filter = "",
                              memo_filter = "all", memo_new = NULL, memo_focus = NULL)
  bump <- function() {
    rv$tick <- shiny::isolate(rv$tick) + 1
    rv$last_saved <- format(Sys.time(), "%H:%M:%S")
  }
  rv$last_saved <- format(Sys.time(), "%H:%M:%S")
  esc <- htmltools::htmlEscape

  # notification with an "Undo" link (jellyqda.js then clicks #undo_btn)
  notify_undo <- function(msg, type = "message") {
    shiny::showNotification(msg, type = type, duration = 7,
      action = shiny::tags$a(href = "#", `data-undonow` = "1", .t("R\u00fcckg\u00e4ngig")))
  }
  # most recently assigned codes (row "Recent" in the coding bar)
  rv$recent <- integer()

  # definition + coding rule (coding guideline), else the newest code memo
  code_defs <- function(codes) {
    cm <- qda_memos(kind = "code")
    vapply(seq_len(nrow(codes)), function(i) {
      d <- trimws(codes$description[i] %||% "")
      r <- trimws(if (is.null(codes$coding_rule) || is.na(codes$coding_rule[i])) "" else codes$coding_rule[i])
      if (!nzchar(d)) {
        m <- cm[!is.na(cm$code_id) & cm$code_id == codes$id[i], , drop = FALSE]
        d <- if (nrow(m)) trimws(m$text_[nrow(m)]) else ""
      }
      paste0(d, if (nzchar(r)) paste0(if (nzchar(d)) " \u00b7 " else "", .t("Regel: "), r) else "")
    }, character(1))
  }
  # Anzahl Codings je Code inkl. aller Subcodes
  code_agg <- function(codes) {
    vapply(codes$id, function(i) sum(codes$n_codings[codes$id %in% .code_descendants(codes, i)]),
           numeric(1))
  }

  # Report in its own browser tab: an address of this session under which
  # the server creates the report fresh on every request (registerDataObj).
  report_url <- tryCatch(
    session$registerDataObj("jqreport", list(), function(data, req) .report_response()),
    error = function(e) NULL)
  output$report_link <- shiny::renderUI({
    if (is.null(report_url)) return(NULL)
    shiny::tags$a(id = "report_btn", class = "btn btn-sm btn-outline-secondary", href = report_url,
                  target = "_blank", rel = "noopener",
                  title = .t("Bericht in einem neuen Tab \u00f6ffnen (A4, druckbar)"),
                  fontawesome::fa("chart-column"), .t(" Bericht "), fontawesome::fa("arrow-up-right-from-square"))
  })

  # document tree (left top) ---------------------------------------------------
  output$doc_tree <- shiny::renderUI({
    rv$tick
    s <- qda_sources()
    if (nrow(s) == 0) return(shiny::tags$div(class = "jq-hint", .t("Noch keine Dokumente importiert.")))
    ps <- qda_stats()$per_source
    with_memo <- unique(qda_memos(kind = "document")$source_id)
    rows <- vapply(seq_len(nrow(s)), function(i) {
      cls <- if (!is.null(rv$src) && rv$src == s$id[i]) "docrow sel" else "docrow"
      pct <- if (s$id[i] %in% ps$id) ps$pct_coded[match(s$id[i], ps$id)] else 0
      memo_icon <- if (s$id[i] %in% with_memo) {
        sprintf(.t('<span class="memoicon" data-docmemo="%d" title="Dokument-Memo anzeigen"><i class="fa-solid fa-note-sticky"></i></span>'),
                s$id[i])
      } else ""
      sprintf(.t('<div class="%s" data-src="%d"><i class="fa-solid fa-file-lines"></i>
               <span>%s</span>%s<span class="fmt">%s - %d Seg.</span>
               <span class="pbar" title="%.1f %% codiert"><span style="width:%.1f%%"></span></span></div>'),
              cls, s$id[i], esc(s$name[i]), memo_icon, esc(s$format[i]), s$segments[i], pct, pct)
    }, character(1))
    shiny::HTML(paste(rows, collapse = ""))
  })
  shiny::observeEvent(input$open_source, {
    rv$src <- input$open_source; rv$sel <- NULL; rv$clicked <- NULL; rv$caret <- NULL
  })
  shiny::observeEvent(input$import_btn, {
    shiny::req(input$import_files)
    # original upload names (datapath is only a temp name like 0.pdf)
    qda_import(input$import_files$datapath, names = input$import_files$name,
               segments = input$import_segrule %||% "blankline")
    bump(); shiny::showNotification(.t("Importiert (Text eingefroren, Original in originals/)."), type = "message")
  })

  # document browser (center top) ----------------------------------------------
  output$doc_title <- shiny::renderText({
    rv$tick
    if (is.null(rv$src)) .t("Dokument-Browser") else .resolve_source(rv$src)$name
  })
  output$doc <- shiny::renderUI({
    rv$tick
    id <- rv$src
    if (is.null(id)) return(shiny::tags$div(class = "jq-hint", .t("Links ein Dokument auswaehlen ...")))
    shiny::HTML(.render_doc_html(id, sel_mid = rv$sel_memo))
  })
  # Text selection from the browser (jellyqda.js, section 2). NULL = selection
  # cleared -> the action bar disappears (hence ignoreNULL = FALSE).
  shiny::observeEvent(input$selection, {
    rv$sel <- input$selection
    if (!is.null(input$selection)) rv$caret <- NULL   # selection instead of a cursor
  }, ignoreNULL = FALSE)

  # Action bar ("coding bar"): appears as soon as rv$sel is set.
  # Step 1: one coloured chip per top-level code (Ctrl+1..9). If a code has
  # subcodes, a click unfolds a second row on the "thread":
  # "<code> (code only)" (key 0) + subcodes (keys 1..9). Without subcodes the
  # click codes directly. Plus: search field over all codes (path), Enter
  # without a hit creates a new code; "Recent" = recently assigned codes.
  # Everything that codes has class "codebtn" -> input$assign_code.
  output$actionbar <- shiny::renderUI({
    rv$tick
    s <- rv$sel
    if (is.null(s)) return(NULL)
    codes <- qda_codes()
    tr <- .code_tree(codes)
    defs <- stats::setNames(code_defs(tr), tr$id)
    path_lab <- function(i) gsub(" / ", " \u203a ", tr$path[tr$id == i], fixed = TRUE)
    chip_title <- function(i) {
      d <- defs[[as.character(i)]]
      paste0(path_lab(i), if (nzchar(d)) paste0(" \u2013 ", d) else "")
    }
    # the code family of the most recently assigned code is unfolded
    open_root <- if (length(rv$recent)) tr$root_id[match(rv$recent[1], tr$id)] else NA
    roots <- tr[tr$depth == 1L, , drop = FALSE]
    chips <- if (nrow(roots) == 0) {
      .t('<span class="jq-sub">Noch keine Codes: rechts im Suchfeld tippen und Enter = neuen Code anlegen und vergeben</span>')
    } else paste(vapply(seq_len(nrow(roots)), function(i) {
      r <- roots[i, ]
      key <- if (i <= 9) sprintf(.t('<span class="k">Strg+%d</span>'), i) else ""
      if (r$has_children) {
        sprintf(.t('<button class="rootchip%s" data-openroot="%d" data-def="%s" style="--c:%s" title="%s (Subcodes zeigen)">%s <span class="k">%d\u25be</span>%s</button>'),
                if (!is.na(open_root) && open_root == r$id) " open" else "", r$id,
                esc(defs[[as.character(r$id)]], attribute = TRUE), esc(r$color),
                esc(chip_title(r$id)), esc(r$label), r$n_children, key)
      } else {
        sprintf('<button class="codebtn rootchip" data-codeid="%d" data-def="%s" style="--c:%s" title="%s">%s%s</button>',
                r$id, esc(defs[[as.character(r$id)]], attribute = TRUE), esc(r$color),
                esc(chip_title(r$id)), esc(r$label), if (nzchar(key)) paste0(" ", key) else "")
      }
    }, character(1)), collapse = "")
    sublines <- paste(vapply(which(roots$has_children), function(i) {
      r <- roots[i, ]
      fam <- tr[tr$root_id == r$id & tr$depth > 1L, , drop = FALSE]
      subs <- vapply(seq_len(nrow(fam)), function(j) {
        sprintf('<button class="codebtn sub" data-codeid="%d" data-def="%s" title="%s">%s%s%s</button>',
                fam$id[j], esc(defs[[as.character(fam$id[j])]], attribute = TRUE),
                esc(chip_title(fam$id[j])), strrep("\u21b3 ", max(0L, fam$depth[j] - 2L)),
                esc(fam$label[j]), if (j <= 9) sprintf(' <span class="k">%d</span>', j) else "")
      }, character(1))
      sprintf('<div class="subline" data-subfor="%d" style="--c:%s"%s><span class="thread"></span><div class="chips">%s%s</div></div>',
              r$id, esc(r$color), if (!is.na(open_root) && open_root == r$id) "" else " hidden",
              sprintf(.t('<button class="codebtn self" data-codeid="%d" data-def="%s" title="Nur den Code \u201e%s\u201c vergeben">%s (nur Code) <span class="k">0</span></button>'),
                      r$id, esc(defs[[as.character(r$id)]], attribute = TRUE), esc(r$label), esc(r$label)),
              paste(subs, collapse = ""))
    }, character(1)), collapse = "")
    # search results: all codes, filtered in the browser (jellyqda.js)
    results <- paste(vapply(seq_len(nrow(tr)), function(i) {
      sprintf('<button class="codebtn%s" data-codeid="%d" data-path="%s" data-def="%s" style="--c:%s" title="%s" hidden>%s</button>',
              if (tr$depth[i] > 1L) " sub" else "", tr$id[i], esc(tolower(tr$path[i]), attribute = TRUE),
              esc(defs[[as.character(tr$id[i])]], attribute = TRUE), esc(tr$root_color[i]),
              esc(chip_title(tr$id[i])), esc(path_lab(tr$id[i])))
    }, character(1)), collapse = "")
    rec <- rv$recent[rv$recent %in% tr$id]
    recent <- if (length(rec)) paste0(.t('<span class="jq-sub">Zuletzt:</span>'), paste(vapply(rec, function(i) {
      k <- match(i, tr$id)
      sprintf('<button class="codebtn%s small" data-codeid="%d" data-def="%s" style="--c:%s" title="%s">%s</button>',
              if (tr$depth[k] > 1L) " sub" else "", i, esc(defs[[as.character(i)]], attribute = TRUE),
              esc(tr$root_color[k]), esc(chip_title(i)), esc(path_lab(i)))
    }, character(1)), collapse = "")) else ""
    shiny::div(class = "actionbar",
      shiny::div(class = "pk-top",
        shiny::span(class = "selinfo", sprintf(.t("Markiert: Zeichen %d-%d"), s$start, s$end)),
        shiny::tags$input(type = "search", id = "code_search", class = "form-control form-control-sm",
                          autocomplete = "off", `aria-label` = .t("Code suchen"),
                          placeholder = .t("Code suchen oder neu anlegen \u2026 (Enter)"))),
      shiny::div(class = "chips pk-roots", shiny::HTML(chips)),
      shiny::HTML(sublines),
      shiny::div(class = "chips pk-results", hidden = NA, shiny::HTML(results),
                 shiny::span(class = "jq-sub pk-none", hidden = NA,
                             .t("Kein Code gefunden \u2013 Enter legt ihn als neuen Code an und vergibt ihn."))),
      shiny::div(class = "pk-def", id = "pk_def",
                 .t("Maus \u00fcber einen Code: Definition aus dem Code-Memo. Oder links im Codebaum auf einen Code klicken.")),
      shiny::div(class = "pk-bottom",
        shiny::HTML(recent),
        shiny::span(class = "pk-spacer"),
        shiny::tags$button(class = "segdefbtn invivobtn", `data-invivo` = "1", .t("In vivo"),
                           title = .t("Markierten Text als neuen Code anlegen und vergeben (In-vivo-Code)")),
        shiny::tags$button(class = "segdefbtn", `data-segact` = "define", .t("Als Segment"),
                           title = .t("Markierten Text als eigenes Segment festlegen (Strg+Z macht es r\u00fcckg\u00e4ngig)")),
        shiny::tags$button(id = "memo_only_btn", .t("Memo speichern"),
                           title = paste(.t("Textstellen-Memo zur Markierung anlegen (Strg+M)."),
                                         .t("Mit Text im Feld daneben: sofort speichern; ohne: Formular im Memo-Panel"))),
        shiny::textInput("memo_field", label = NULL,
                         placeholder = .t("Memo oder Kommentar zum Coding (optional)")))
    )
  })
  # Store the marked text with a code (coding bar, code tree, search).
  # Exactly rv$sel$start..end is stored -- so rv$sel must not be overwritten
  # by the segment click before (see BUGFIX in jellyqda.js).
  assign_sel <- function(code_id) {
    s <- rv$sel
    n <- nchar(.resolve_source(rv$src)$frozen_text, type = "chars")
    res <- qda_code(rv$src, as.integer(code_id), start = s$start, end = min(s$end, n),
                    memo = shiny::isolate(input$memo_field) %||% "")
    rv$recent <- utils::head(unique(c(as.integer(code_id), rv$recent)), 3)
    rv$sel <- NULL
    bump()
    path <- qda_codes()$path[qda_codes()$id == code_id]
    notify_undo(sprintf(.t("Codiert: %s"), gsub(" / ", " \u203a ", path, fixed = TRUE)))
    invisible(res)
  }
  shiny::observeEvent(input$assign_code, {
    shiny::req(rv$src, rv$sel)
    assign_sel(input$assign_code)
  })
  # In vivo: the marked text itself becomes the code name (shortened). If a
  # top-level code with this name exists already, it is assigned.
  shiny::observeEvent(input$invivo, {
    shiny::req(rv$src, rv$sel)
    lab <- .invivo_label(rv$sel$text %||% "")
    if (!nzchar(lab)) {
      shiny::showNotification(.t("Kein Text markiert."), type = "warning"); return()
    }
    codes <- qda_codes()
    hit <- codes$id[is.na(codes$parent_id) & codes$label == lab]
    id <- if (length(hit)) hit[1] else tryCatch(qda_code_add(lab)$id, error = function(e) {
      shiny::showNotification(conditionMessage(e), type = "warning"); NULL })
    if (!is.null(id)) assign_sel(id)
  })
  # search field of the coding bar: Enter without a hit -> new code + assign
  shiny::observeEvent(input$add_code_assign, {
    shiny::req(rv$src, rv$sel)
    lab <- trimws(input$add_code_assign$label %||% "")
    if (!nzchar(lab)) return()
    res <- tryCatch(qda_code_add(lab), error = function(e) {
      shiny::showNotification(conditionMessage(e), type = "warning"); NULL })
    if (!is.null(res)) assign_sel(res$id)
  })

  # "Save memo" in the action bar (or Ctrl+M): passage memo.
  # With text in the field -> saved at once; otherwise the form in the memo
  # panel opens (earlier the marked text itself was saved as the memo, so the
  # memo only repeated the passage).
  shiny::observeEvent(input$add_memo_only, {
    shiny::req(rv$src, rv$sel)
    s <- rv$sel
    n <- nchar(.resolve_source(rv$src)$frozen_text, type = "chars")
    end <- min(s$end, n)
    memo_txt <- trimws(input$memo_field %||% "")
    if (nzchar(memo_txt)) {
      res <- qda_memo_add(memo_txt, source = rv$src, start = s$start, end = end)
      rv$sel_memo <- res$id
      rv$memo_focus <- paste0("memo_", res$id)
      bump()
      session$sendCustomMessage("jellyqdaMemoFocus", list(key = rv$memo_focus))
      shiny::showNotification(.t("Textstellen-Memo gespeichert (Strg+Z macht es r\u00fcckg\u00e4ngig)."),
                              type = "message")
    } else {
      rv$memo_new <- list(kind = "passage", source = rv$src, start = s$start, end = end)
      session$sendCustomMessage("jellyqdaMemoFocus", list(key = "new"))
    }
  })

  # click on a highlight -> inspect / delete ----------------------------------
  shiny::observeEvent(input$clicked_coding, { rv$clicked <- input$clicked_coding })
  output$clicked_bar <- shiny::renderUI({
    rv$tick
    cid <- rv$clicked
    if (is.null(cid)) return(NULL)
    df <- qda_codings()
    row <- df[df$id == cid, , drop = FALSE]
    if (nrow(row) == 0) { rv$clicked <- NULL; return(NULL) }
    # re-code: all codes of the same family (code + subcodes) as chips
    tr <- .code_tree(qda_codes())
    k <- match(row$code_id, tr$id)
    fam <- tr[tr$root_id == tr$root_id[k], , drop = FALSE]
    chips <- paste(vapply(seq_len(nrow(fam)), function(j) {
      sprintf('<button class="recodebtn%s%s" data-recode="%d" style="--c:%s" title="%s">%s%s%s</button>',
              if (fam$depth[j] > 1L) " sub" else "", if (fam$id[j] == row$code_id) " cur" else "",
              fam$id[j], esc(fam$root_color[j]), esc(fam$path[j]),
              strrep("\u21b3 ", max(0L, fam$depth[j] - 2L)), esc(fam$label[j]),
              if (fam$depth[j] == 1L && nrow(fam) > 1) .t(" (nur Code)") else "")
    }, character(1)), collapse = "")
    shiny::div(class = "clickedbar",
      shiny::span(class = "snippet",
        sprintf(.t("Coding #%d - %s - %s - Zeichen %d-%d: '%s'%s"),
                row$id, row$source, gsub(" / ", " \u203a ", tr$path[k], fixed = TRUE), row$start, row$end,
                if (nchar(row$text) > 90) paste0(substr(row$text, 1, 90), "...") else row$text,
                if (nzchar(row$memo)) paste0(.t("  |  Kommentar: "), row$memo) else "")),
      if (nrow(fam) > 1) shiny::div(class = "recode",
        shiny::span(class = "jq-sub", sprintf(.t("Umkodieren innerhalb von \u201e%s\u201c:"), tr$label[tr$id == tr$root_id[k]])),
        shiny::HTML(chips)),
      # comment + Mayring fields: plain <input>s, saved by button or Enter
      # (jellyqda.js, section 16) -> input$save_coding_fields
      shiny::div(class = "cbfields", `data-cbid` = row$id,
        shiny::tags$label(`for` = "cb_comment", .t("Kommentar")),
        shiny::tags$input(type = "text", id = "cb_comment", class = "form-control form-control-sm",
                          value = row$memo, placeholder = .t("Kommentar zum Coding \u2026")),
        shiny::tags$details(class = "cbmayring", open = if (nzchar(row$paraphrase) || nzchar(row$generalization)) NA else NULL,
          shiny::tags$summary(.t("Mayring: Paraphrase und Generalisierung")),
          shiny::tags$label(`for` = "cb_para", .t("Paraphrase")),
          shiny::tags$input(type = "text", id = "cb_para", class = "form-control form-control-sm",
                            value = row$paraphrase, placeholder = .t("Inhalt kurz in eigenen Worten")),
          shiny::tags$label(`for` = "cb_gen", .t("Generalisierung")),
          shiny::tags$input(type = "text", id = "cb_gen", class = "form-control form-control-sm",
                            value = row$generalization, placeholder = .t("auf das Abstraktionsniveau der Analyse gehoben")))),
      shiny::div(class = "cbbtns",
        shiny::tags$button(class = "btn btn-sm btn-primary", `data-savecoding` = row$id,
                           title = .t("Kommentar und Mayring-Felder speichern (Enter)"), .t("Speichern")),
        shiny::tags$button(class = "btn btn-sm btn-outline-secondary", `data-anchorfrom` = row$id,
                           title = .t("Diese Textstelle als Ankerbeispiel in den Kodierleitfaden des Codes \u00fcbernehmen"),
                           fontawesome::fa("quote-left"), sprintf(.t(" Als Ankerbeispiel f\u00fcr \u201e%s\u201c"), tr$label[k])),
        shiny::actionButton("del_clicked_coding", .t("L\u00f6schen"), icon = .jq_ico("trash"),
                            class = "btn-sm btn-outline-danger"))
    )
  })
  # save comment / paraphrase / generalisation of a coding
  shiny::observeEvent(input$save_coding_fields, {
    f <- input$save_coding_fields
    id <- as.integer(f$id)
    row <- qda_codings(); row <- row[row$id == id, , drop = FALSE]
    if (nrow(row) == 0) return()
    changed <- FALSE
    if (!identical(trimws(f$memo %||% ""), row$memo)) {
      qda_coding_set_memo(id, trimws(f$memo %||% "")); changed <- TRUE
    }
    p <- trimws(f$paraphrase %||% ""); g <- trimws(f$generalization %||% "")
    if (!identical(p, row$paraphrase) || !identical(g, row$generalization)) {
      qda_coding_set_summary(id, paraphrase = p, generalization = g); changed <- TRUE
    }
    if (changed) { bump(); notify_undo(.t("Coding gespeichert.")) }
  })
  # passage as anchor example into the coding guideline of the code
  shiny::observeEvent(input$anchor_from_coding, {
    id <- as.integer(input$anchor_from_coding)
    row <- qda_codings(); row <- row[row$id == id, , drop = FALSE]
    if (nrow(row) == 0) return()
    sg <- .segments_for(row$source_id)
    i <- which(sg$start <= row$start & sg$end >= row$start)
    txt <- gsub("\\s+", " ", trimws(row$text))
    ex <- sprintf(.t("\u201e%s\u201c (%s%s)"), txt, row$source, if (length(i)) paste0(", Seg ", i[1]) else "")
    qda_code_guide(row$code_id, anchor = ex, append_anchor = TRUE)
    bump()
    notify_undo(sprintf(.t("Ankerbeispiel f\u00fcr \u201e%s\u201c \u00fcbernommen."), row$code))
  })
  shiny::observeEvent(input$recode_coding, {
    shiny::req(rv$clicked)
    res <- tryCatch(qda_coding_recode(rv$clicked, as.integer(input$recode_coding)),
                    error = function(e) { shiny::showNotification(conditionMessage(e), type = "warning"); NULL })
    if (!is.null(res)) {
      bump()
      p <- qda_codes()$path[qda_codes()$id == as.integer(input$recode_coding)]
      notify_undo(sprintf(.t("Umkodiert: %s"), gsub(" / ", " \u203a ", p, fixed = TRUE)))
    }
  })
  shiny::observeEvent(input$del_clicked_coding, {
    shiny::req(rv$clicked)
    qda_coding_delete(rv$clicked)
    rv$clicked <- NULL; bump()
    shiny::showNotification(.t("Coding geloescht (Audit-Trail)."), type = "message")
  })
  shiny::observeEvent(input$del_coding, {
    qda_coding_delete(input$del_coding); bump()
    shiny::showNotification(.t("Coding geloescht (Audit-Trail)."), type = "message")
  })
  # click a segment/coding in a list -> jump to it in the document browser ----
  shiny::observeEvent(input$goto_coding, {
    df <- qda_codings()
    row <- df[df$id == input$goto_coding, , drop = FALSE]
    if (nrow(row) == 0) return()
    rv$src <- row$source_id
    rv$sel <- NULL
    rv$clicked <- row$id
    bump()
    session$sendCustomMessage("jellyqdaScroll", list(cid = row$id))
  })

  # code system (left bottom) ---------------------------------------------------
  # Click on a code: show its segments -- or, while text is marked, code the
  # marked text with this code.
  shiny::observeEvent(input$sel_code, {
    if (!is.null(rv$sel) && !is.null(rv$src)) {
      assign_sel(input$sel_code)
    } else {
      rv$sel_code <- input$sel_code
    }
  })
  # Code tree: top-level code in full colour, subcodes only with a border in
  # the colour of their code, connected by a line ("thread"). Expanding,
  # renaming (double click), "+ Subcode", deleting (with confirmation) and
  # filtering run in the browser (jellyqda.js, section 15) and only send the
  # result to the server. The tree does NOT read rv$sel_code, so that a click
  # does not re-render it (the double click would get lost otherwise);
  # jellyqda.js marks the selection.
  output$code_tree <- shiny::renderUI({
    rv$tick
    codes <- qda_codes()
    if (nrow(codes) == 0) {
      return(shiny::HTML(.t('<ul class="ctree" data-ctree="1"></ul><div class="jq-hint ctree-empty">Noch keine Codes. Oben rechts \u201e+ Code\u201c anklicken.</div>')))
    }
    tr <- .code_tree(codes)
    agg <- stats::setNames(code_agg(tr), tr$id)
    with_memo <- unique(qda_memos(kind = "code")$code_id)
    node <- function(k) {
      id <- tr$id[k]; d <- tr$depth[k]
      kids <- which(!is.na(tr$parent_id) & tr$parent_id == id)
      memo_icon <- if (id %in% with_memo) {
        sprintf(.t('<span class="memoicon" data-codememo="%d" title="Code-Memo anzeigen"><i class="fa-solid fa-note-sticky"></i></span>'), id)
      } else ""
      color <- if (d == 1L) {
        sprintf(.t('<label class="colordot" title="Farbe der Code-Familie \u00e4ndern"><input type="color" value="%s" data-codecolor="%d" aria-label="Farbe von %s"></label>'),
                esc(tr$color[k]), id, esc(tr$label[k], attribute = TRUE))
      } else ""
      row <- sprintf(paste0(
        '<div class="coderow" draggable="true" data-selcode="%d" data-codeid="%d" data-depth="%d" ',
        .t('data-nsub="%d" data-ncod="%d" data-label="%s" data-path="%s" title="%s \u2013 Klick: Segmente zeigen (mit markiertem Text: codieren), Doppelklick: umbenennen">'),
        .t('<button class="cchev%s" data-codetoggle="%d" title="Ein-/ausklappen" tabindex="-1"><i class="fa-solid fa-chevron-down"></i></button>'),
        '%s<span class="codelabel">%s</span>%s',
        .t('<span class="cacts">%s<button class="mini" data-renamecode="%d" title="Umbenennen (Doppelklick, F2)"><i class="fa-solid fa-pen"></i></button>'),
        .t('<button class="mini" data-guidecode="%d" title="Kodierleitfaden: Definition, Ankerbeispiel, Kodierregel"><i class="fa-solid fa-book-open"></i></button>'),
        .t('<button class="mini" data-mergecode="%d" title="Mit einem anderen Code zusammenf\u00fchren"><i class="fa-solid fa-code-merge"></i></button>'),
        .t('<button class="mini del" data-delcode="%d" title="%s l\u00f6schen (mit R\u00fcckfrage)"><i class="fa-solid fa-trash"></i></button></span>'),
        .t('<span class="fmt" title="eigene Codings">%d</span>%s</div>')),
        id, id, d, length(.code_descendants(tr, id)) - 1L, as.integer(agg[[as.character(id)]]),
        esc(tr$label[k], attribute = TRUE), esc(gsub(" / ", " \u203a ", tr$path[k], fixed = TRUE), attribute = TRUE),
        esc(tr$path[k], attribute = TRUE),
        if (length(kids)) "" else " none", id,
        color, esc(tr$label[k]), memo_icon,
        if (d < 3L) sprintf(.t('<button class="mini" data-addsub="%d" title="Subcode unter \u201e%s\u201c anlegen">+ Subcode</button>'),
                            id, esc(tr$label[k], attribute = TRUE)) else "",
        id, id, id, id, if (d == 1L) "Code" else "Subcode",
        tr$n_codings[k],
        if (length(kids)) sprintf(.t('<span class="agg" title="mit allen Subcodes">\u03a3 %d</span>'), as.integer(agg[[as.character(id)]])) else "")
      sprintf('<li class="cnode lvl%d" data-cnode="%d" style="--c:%s">%s%s</li>',
              min(d, 3L), id, esc(tr$root_color[k]), row,
              if (length(kids)) paste0('<ul class="cchildren">', paste(vapply(kids, node, character(1)), collapse = ""), "</ul>") else "")
    }
    shiny::HTML(paste0('<ul class="ctree" data-ctree="1">',
                       paste(vapply(which(tr$depth == 1L), node, character(1)), collapse = ""), "</ul>",
                       .t('<div class="ctree-topdrop">Hierher ziehen = Code auf oberster Ebene</div>')))
  })
  # new code / subcode (input field in the tree, jellyqda.js) -> {label, parent}
  shiny::observeEvent(input$add_code, {
    lab <- trimws(input$add_code$label %||% "")
    if (!nzchar(lab)) return()
    par <- input$add_code$parent
    par <- if (is.null(par) || identical(par, "") || is.na(suppressWarnings(as.integer(par)))) NULL else as.integer(par)
    res <- tryCatch(qda_code_add(lab, parent = par), error = function(e) {
      shiny::showNotification(conditionMessage(e), type = "warning"); NULL })
    if (!is.null(res)) {
      bump()
      notify_undo(sprintf(.t("%s \u201e%s\u201c angelegt."), if (is.null(par)) "Code" else "Subcode", lab))
    }
  })
  # rename (double click in the tree) -> {id, label}
  shiny::observeEvent(input$rename_code, {
    lab <- trimws(input$rename_code$label %||% "")
    id <- as.integer(input$rename_code$id)
    if (!nzchar(lab) || is.na(id)) return()
    old <- qda_codes()$label[qda_codes()$id == id]
    if (identical(old, lab)) return()
    res <- tryCatch(qda_code_rename(id, lab), error = function(e) {
      shiny::showNotification(conditionMessage(e), type = "warning"); NULL })
    if (!is.null(res)) {
      bump()
      notify_undo(sprintf(.t("Umbenannt: \u201e%s\u201c \u2192 \u201e%s\u201c"), old, lab))
    }
  })
  # coding guideline (book icon on a code): dialog with three fields
  shiny::observeEvent(input$guide_code, {
    id <- as.integer(input$guide_code)
    c <- qda_codes(); c <- c[c$id == id, , drop = FALSE]
    if (nrow(c) == 0) return()
    ta <- function(idf, label, value, hint, rows) shiny::div(class = "mb-2",
      shiny::tags$label(`for` = idf, class = "form-label", shiny::strong(label), shiny::span(class = "jq-sub", hint)),
      shiny::tags$textarea(id = idf, class = "form-control", rows = rows, value))
    shiny::showModal(shiny::modalDialog(
      title = sprintf(.t("Kodierleitfaden: %s"), gsub(" / ", " \u203a ", c$path, fixed = TRUE)),
      ta("guide_def", .t("Definition"), c$description, .t(" \u2013 was geh\u00f6rt in diese Kategorie?"), 3),
      ta("guide_anchor", .t("Ankerbeispiele"), c$anchor, .t(" \u2013 typische Textstellen, eine pro Zeile (im Text: Coding anklicken \u2192 \u201eAls Ankerbeispiel\u201c)"), 4),
      ta("guide_rule", .t("Kodierregel"), c$coding_rule, .t(" \u2013 wie werden Grenzf\u00e4lle entschieden?"), 3),
      easyClose = TRUE,
      footer = shiny::tagList(shiny::modalButton(.t("Abbrechen")),
        shiny::tags$button(class = "btn btn-primary", `data-guidesave` = id, .t("Speichern")))))
  })
  shiny::observeEvent(input$guide_save, {
    g <- input$guide_save
    res <- tryCatch(qda_code_guide(as.integer(g$id), definition = g$def %||% "", anchor = g$anchor %||% "",
                                   rule = g$rule %||% ""),
                    error = function(e) { shiny::showNotification(conditionMessage(e), type = "warning"); NULL })
    shiny::removeModal()
    if (!is.null(res)) { bump(); notify_undo(sprintf(.t("Kodierleitfaden von \u201e%s\u201c gespeichert."), res$label)) }
  })
  # merge two codes (selection in the tree, jellyqda.js) -> {from, into}
  shiny::observeEvent(input$merge_code, {
    m <- input$merge_code
    codes <- qda_codes()
    from <- codes$label[codes$id == as.integer(m$from)]; into <- codes$label[codes$id == as.integer(m$into)]
    res <- tryCatch(qda_code_merge(as.integer(m$from), as.integer(m$into)),
                    error = function(e) { shiny::showNotification(conditionMessage(e), type = "warning"); NULL })
    if (!is.null(res)) {
      if (identical(rv$sel_code, as.integer(m$from))) rv$sel_code <- NULL
      rv$clicked <- NULL
      bump()
      notify_undo(sprintf(.t("\u201e%s\u201c in \u201e%s\u201c zusammengef\u00fchrt (%d Codings)."), from, into, res$codings_moved))
    }
  })
  # colour of a code family (colour dot on the code)
  shiny::observeEvent(input$code_color, {
    res <- tryCatch(qda_code_set_color(as.integer(input$code_color$id), input$code_color$color),
                    error = function(e) { shiny::showNotification(conditionMessage(e), type = "warning"); NULL })
    if (!is.null(res)) { bump(); notify_undo(.t("Farbe ge\u00e4ndert.")) }
  })
  # delete (after the confirmation in the tree, jellyqda.js)
  shiny::observeEvent(input$del_code_id, {
    id <- as.integer(input$del_code_id)
    codes <- qda_codes()
    if (!id %in% codes$id) return()
    lab <- codes$label[codes$id == id]
    sub <- is.na(codes$parent_id[codes$id == id]) == FALSE
    res <- qda_code_delete(id)
    if (identical(rv$sel_code, id)) rv$sel_code <- NULL
    rv$clicked <- NULL
    bump()
    notify_undo(sprintf(.t("%s \u201e%s\u201c gel\u00f6scht (%d Codings)."), if (sub) "Subcode" else "Code",
                        lab, res$codings_deleted), type = "warning")
  })

  # retrieved segments (center bottom) -----------------------------------------
  output$seg_head <- shiny::renderUI({
    rv$tick
    if (!is.null(rv$sel_code)) {
      codes <- qda_codes()
      lab <- codes$label[codes$id == rv$sel_code]
      if (length(lab) == 0) lab <- "?"
      ids <- .code_descendants(codes, rv$sel_code)
      shiny::span(sprintf(.t("Retrieved Segments: %s%s (%d)"), lab, if (length(ids) > 1) .t(" + Subcodes") else "",
                          sum(qda_codings()$code_id %in% ids)))
    } else {
      shiny::span(sprintf(.t("All Codings (%d)"), nrow(qda_codings())))
    }
  })
  output$seg_panel <- shiny::renderUI({
    rv$tick
    df <- if (!is.null(rv$sel_code)) {
      d <- qda_codings()
      d[d$code_id %in% .code_descendants(qda_codes(), rv$sel_code), , drop = FALSE]
    } else {
      qda_codings()
    }
    # optional filter: only documents having a certain variable value
    if (!is.null(rv$var_filter) && nzchar(rv$var_filter)) {
      kv <- strsplit(rv$var_filter, "=", fixed = TRUE)[[1]]
      keep <- vapply(qda_sources()$id, function(sid) {
        v <- qda_source_vars(sid)
        !is.null(v[[kv[1]]]) && v[[kv[1]]] == kv[2]
      }, logical(1))
      df <- df[df$source_id %in% qda_sources()$id[keep], , drop = FALSE]
    }
    if (nrow(df) == 0) return(shiny::tags$div(class = "jq-hint", .t("Noch keine Codings.")))
    rows <- vapply(seq_len(nrow(df)), function(i) {
      snippet <- if (nchar(df$text[i]) > 80) paste0(substr(df$text[i], 1, 80), "...") else df$text[i]
      sprintf(.t('<div class="segrow" data-goto="%d" title="Im Dokument-Browser zeigen">
               <span class="snippet">#%d <b>%s</b> &rarr; <b>%s</b> (%d-%d) %s%s</span>
               <button class="mini" data-delcoding="%d" title="Coding l\u00f6schen (Strg+Z macht es r\u00fcckg\u00e4ngig)"><i class="fa-solid fa-trash"></i> L\u00f6schen</button></div>'),
              df$id[i], df$id[i], esc(df$source[i]), esc(df$code[i]), df$start[i], df$end[i],
              esc(snippet),
              if (nzchar(df$memo[i])) sprintf(.t('<span class="memo">Memo: %s</span>'), esc(df$memo[i])) else "",
              df$id[i])
    }, character(1))
    shiny::HTML(paste(rows, collapse = ""))
  })

  # project-wide full-text search ----------------------------------------------
  shiny::observeEvent(input$search_btn, {
    q <- input$search_q
    if (is.null(q) || !nzchar(trimws(q))) return()
    q <- trimws(q)
    hits <- list()
    for (sid in qda_sources()$id) {
      txt <- .resolve_source(sid)$frozen_text
      low <- tolower(txt); ql <- tolower(q)
      pos <- 1L
      while (length(hits) < 200) {
        p <- regexpr(ql, substring(low, pos), fixed = TRUE)
        if (p < 0) break
        at <- pos + p - 1L
        hits[[length(hits) + 1]] <- list(
          src = sid, pos = at,
          snippet = substring(txt, max(1L, at - 40L), min(nchar(txt, "chars"), at + nchar(q, "chars") + 40L)))
        pos <- at + 1L
      }
    }
    rv$search <- hits
    rv$search_q <- q
    bump()
    shiny::showNotification(sprintf(.t("Suche '%s': %d Treffer"), q, length(hits)), type = "message")
  })
  output$search_results <- shiny::renderUI({
    rv$tick
    hits <- rv$search
    if (is.null(hits)) return(NULL)
    if (length(hits) == 0) return(shiny::tags$div(class = "jq-hint", .t("Keine Treffer.")))
    rows <- vapply(hits, function(h) {
      nm <- .resolve_source(h$src)$name
      sprintf(.t('<div class="segrow" data-gotopos data-src="%d" data-pos="%d" title="Im Dokument-Browser springen">
               <span class="snippet"><b>%s</b> (Pos %d): ...%s...</span></div>'),
              h$src, h$pos, esc(nm), h$pos, esc(h$snippet))
    }, character(1))
    # code all hits at once (qda_autocode, one undo step)
    tr <- .code_tree(qda_codes())
    opts <- paste(sprintf('<option value="%d">%s%s</option>', tr$id, strrep("\u00a0\u00a0", tr$depth - 1L),
                          esc(tr$label)), collapse = "")
    auto <- if (nrow(tr) == 0) "" else sprintf(paste0(
      .t('<div class="autocode"><span>Alle %d Treffer von \u201e%s\u201c codieren mit</span>'),
      '<select id="autocode_code" class="form-select form-select-sm" aria-label="Code">%s</select>',
      .t('<select id="autocode_scope" class="form-select form-select-sm" aria-label="Umfang">'),
      .t('<option value="match">nur Treffer</option><option value="segment">ganzes Segment</option></select>'),
      .t('<button class="btn btn-sm btn-primary" data-autocode="1">Codieren</button></div>')),
      length(hits), esc(rv$search_q %||% ""), opts)
    shiny::HTML(paste0(auto, .t('<div class="memogroup">Treffer (Klick = springen)</div>'), paste(rows, collapse = "")))
  })
  shiny::observeEvent(input$autocode, {
    q <- rv$search_q
    shiny::req(q)
    res <- tryCatch(qda_autocode(q, as.integer(input$autocode$code), scope = input$autocode$scope %||% "match",
                                 ignore_case = TRUE, whole_word = FALSE),
                    error = function(e) { shiny::showNotification(conditionMessage(e), type = "warning"); NULL })
    if (is.null(res)) return()
    bump()
    if (nrow(res) == 0) {
      shiny::showNotification(.t("Nichts Neues zu codieren (alle Stellen haben diesen Code schon)."), type = "message")
    } else {
      notify_undo(sprintf(.t("%d Stellen automatisch codiert."), nrow(res)))
    }
  })
  shiny::observeEvent(input$goto_pos, {
    rv$src <- input$goto_pos$src
    rv$sel <- NULL; rv$clicked <- NULL
    bump()
    session$sendCustomMessage("jellyqdaScroll", list(pos = input$goto_pos$pos))
  })

  # variables (case attributes) per document ------------------------------------
  shiny::observe({
    rv$tick
    s <- qda_sources()
    shiny::updateSelectInput(session, "var_doc",
                             choices = stats::setNames(as.character(s$id), s$name),
                             selected = if (nrow(s) && !is.null(rv$src)) as.character(rv$src) else NULL)
    # variable filter options across all sources
    opts <- character()
    for (sid in s$id) {
      v <- qda_source_vars(sid)
      if (length(v)) opts <- c(opts, paste0(names(v), "=", v))
    }
    shiny::updateSelectInput(session, "var_filter",
                             choices = c(stats::setNames("", .t("(alle)")), sort(unique(opts))),
                             selected = rv$var_filter %||% "")
  })
  shiny::observeEvent(input$var_filter, { rv$var_filter <- input$var_filter %||% "" })
  shiny::observeEvent(input$var_add_btn, {
    shiny::req(input$var_doc, input$var_key)
    if (!nzchar(trimws(input$var_key))) return()
    qda_source_set_var(as.integer(input$var_doc), trimws(input$var_key), input$var_val %||% "")
    shiny::updateTextInput(session, "var_key", value = "")
    shiny::updateTextInput(session, "var_val", value = "")
    bump()
    shiny::showNotification(.t("Variable gesetzt."), type = "message")
  })
  shiny::observeEvent(input$del_var, {
    parts <- strsplit(input$del_var, "|", fixed = TRUE)[[1]]
    qda_source_del_var(as.integer(parts[1]), parts[2])
    bump()
  })
  output$var_list <- shiny::renderUI({
    rv$tick
    # empty selection ("") gives NA -> then the open document
    sid <- suppressWarnings(as.integer(input$var_doc %||% NA))
    if (length(sid) != 1 || is.na(sid)) sid <- rv$src
    if (is.null(sid)) return(NULL)
    v <- qda_source_vars(sid)
    if (length(v) == 0) return(shiny::tags$div(class = "jq-hint", .t("Keine Variablen.")))
    rows <- vapply(seq_along(v), function(i) {
      sprintf(.t('<div class="segrow"><span class="snippet"><b>%s</b> = %s</span>
               <button class="mini" data-delvar="1" data-varsrc="%d" data-varkey="%s"><i class="fa-solid fa-trash"></i> L\u00f6schen</button></div>'),
              esc(names(v)[i]), esc(v[i]), sid, esc(names(v)[i]))
    }, character(1))
    shiny::HTML(paste(rows, collapse = ""))
  })
  # JS: del-var button carries data-varsrc/data-varkey -> single input
  output$doc_vars <- shiny::renderUI({
    rv$tick
    if (is.null(rv$src)) return(NULL)
    v <- qda_source_vars(rv$src)
    if (length(v) == 0) return(NULL)
    shiny::div(class = "docvars",
      lapply(seq_along(v), function(i) shiny::span(class = "chip", paste0(names(v)[i], " = ", v[i]))))
  })

  # re-parent a code by drag & drop in the code tree ----------------------------
  shiny::observeEvent(input$reparent_code, {
    res <- tryCatch(
      qda_code_move(input$reparent_code$code, input$reparent_code$parent),
      error = function(e) {
        shiny::showNotification(paste(.t("Umhaengen nicht moeglich:"), conditionMessage(e)), type = "warning")
        NULL
      })
    if (!is.null(res)) {
      bump()
      shiny::showNotification(.t("Code verschoben (neuer Parent)."), type = "message")
    }
  })

  # memos (right column) ---------------------------------------------------------
  # Four memo kinds (memos.R) + comments on codings. All actions arrive as
  # data-* clicks from jellyqda.js (section 13) and go through the
  # qda_memo_*() functions -> audit trail + undo.
  kind_label <- c(passage = .t("Textstelle"), document = .t("Dokument"), code = "Code",
                  project = .t("Projekt"), comment = .t("Kommentar"))
  kind_icon <- c(passage = "highlighter", document = "file-lines", code = "tag",
                 project = "book", comment = "comment")
  fmt_date <- function(x) {
    d <- tryCatch(as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), error = function(e) NA)
    ifelse(is.na(d), "", format(d, "%d.%m.%Y %H:%M", tz = ""))
  }
  short <- function(x, n = 80) ifelse(nchar(x) > n, paste0(substr(x, 1, n), "\u2026"), x)

  # all entries of the panel as one table: memos + comments on codings
  memo_entries <- function() {
    m <- qda_memos()
    segs_cache <- list()
    seg_no <- function(src_id, pos) {
      k <- as.character(src_id)
      if (is.null(segs_cache[[k]])) segs_cache[[k]] <<- .segments_for(src_id)
      sg <- segs_cache[[k]]
      i <- which(sg$start <= pos & sg$end >= pos)
      if (length(i)) i[1] else NA_integer_
    }
    ref <- vapply(seq_len(nrow(m)), function(i) {
      switch(m$kind[i],
        passage = sprintf(.t("%s \u00b7 Seg %s \u00b7 \u201e%s\u201c"), m$source[i],
                          seg_no(m$source_id[i], m$start[i]), short(m$passage[i], 60)),
        document = m$source[i] %||% "",
        code = paste("Code:", m$code[i]),
        project = .t("Projekt"))
    }, character(1))
    # sprintf statt paste0: paste0("memo_", <leer>) ergibt "memo_" (1 Wert),
    # sprintf ergibt korrekt character(0) -- sonst Fehler ohne Memos
    out <- data.frame(key = sprintf("memo_%d", m$id), id = m$id, kind = m$kind, title = m$title,
                      text = m$text_, ref = ref, source_id = m$source_id, code_id = m$code_id,
                      start = m$start, updated = m$updated_at, stringsAsFactors = FALSE)
    cc <- qda_codings()
    cc <- cc[nzchar(cc$memo), , drop = FALSE]
    if (nrow(cc) > 0) {
      out <- rbind(out, data.frame(
        key = sprintf("cod_%d", cc$id), id = cc$id, kind = "comment", title = "",
        text = cc$memo, ref = sprintf(.t("%s \u00b7 %s \u00b7 \u201e%s\u201c"), cc$source, cc$code, short(cc$text, 60)),
        source_id = cc$source_id, code_id = cc$code_id, start = cc$start, updated = NA_character_,
        stringsAsFactors = FALSE))
    }
    out
  }

  # toolbar: "+ Passage" etc.; disabled when the reference is missing
  output$memo_toolbar <- shiny::renderUI({
    rv$tick
    b <- function(kind, ok, why) {
      shiny::tags$button(class = "newmemo", `data-newmemo` = kind,
                         disabled = if (!ok) "disabled" else NULL,
                         title = if (ok) sprintf(.t("Neues %s-Memo"), kind_label[[kind]]) else why,
                         fontawesome::fa(kind_icon[[kind]]), paste0("+ ", kind_label[[kind]]))
    }
    shiny::div(class = "memotoolbar",
      b("passage", !is.null(rv$sel), .t("Zuerst Text im Dokument markieren")),
      b("document", !is.null(rv$src), .t("Zuerst ein Dokument \u00f6ffnen")),
      b("code", !is.null(rv$sel_code), .t("Zuerst einen Code im Code System anklicken")),
      b("project", TRUE, ""))
  })
  shiny::observeEvent(input$new_memo, {
    kind <- input$new_memo$kind
    rv$memo_new <- switch(kind,
      passage = if (!is.null(rv$sel)) list(kind = kind, source = rv$src, start = rv$sel$start, end = rv$sel$end),
      document = if (!is.null(rv$src)) list(kind = kind, source = rv$src),
      code = if (!is.null(rv$sel_code)) list(kind = kind, code = rv$sel_code),
      project = list(kind = kind))
    if (!is.null(rv$memo_new)) session$sendCustomMessage("jellyqdaMemoFocus", list(key = "new"))
  })
  output$memo_new_form <- shiny::renderUI({
    nm <- rv$memo_new
    if (is.null(nm)) return(NULL)
    ref <- switch(nm$kind,
      passage = {
        src <- .resolve_source(nm$source)
        sprintf(.t("%s \u00b7 \u201e%s\u201c"), src$name, short(substring(src$frozen_text, nm$start, nm$end), 90))
      },
      document = .resolve_source(nm$source)$name,
      code = paste("Code:", qda_codes()$label[qda_codes()$id == nm$code]),
      project = .t("Projekt (ohne Bezug)"))
    shiny::div(class = paste("memocard editing new kind-", nm$kind, sep = ""),
      shiny::div(class = "mc-head", shiny::span(class = "mc-kind", fontawesome::fa(kind_icon[[nm$kind]]),
                                                sprintf(.t("Neues %s-Memo"), kind_label[[nm$kind]]))),
      shiny::div(class = "mc-ref", ref),
      shiny::tags$input(id = "memo_new_title", type = "text", class = "form-control mc-titlein",
                        placeholder = if (nm$kind == "code") .t("Titel, z.B. Definition / Kodierregel") else .t("Titel (optional)")),
      shiny::tags$textarea(id = "memo_new_text", class = "form-control", rows = 4,
                           placeholder = .t("Memo-Text ...")),
      shiny::div(class = "mc-btns",
        shiny::tags$button(class = "mini ok", `data-memonew` = "save", fontawesome::fa("check"), .t("Speichern")),
        shiny::tags$button(class = "mini", `data-memonew` = "cancel", .t("Abbrechen"))))
  })
  shiny::observeEvent(input$memo_new_save, {
    nm <- rv$memo_new
    shiny::req(nm)
    txt <- input$memo_new_save$text %||% ""
    ttl <- input$memo_new_save$title %||% ""
    if (!nzchar(trimws(txt)) && !nzchar(trimws(ttl))) {
      shiny::showNotification(.t("Bitte Titel oder Text eingeben."), type = "warning"); return()
    }
    res <- switch(nm$kind,
      passage = qda_memo_add(txt, source = nm$source, start = nm$start, end = nm$end, title = ttl),
      document = qda_memo_add(txt, source = nm$source, title = ttl),
      code = qda_memo_add(txt, code = nm$code, title = ttl),
      project = qda_memo_add(txt, title = ttl))
    rv$memo_new <- NULL
    rv$memo_focus <- paste0("memo_", res$id)
    if (nm$kind == "passage") rv$sel_memo <- res$id
    bump()
    session$sendCustomMessage("jellyqdaMemoFocus", list(key = rv$memo_focus))
    shiny::showNotification(paste0(qda_history()$undo, .t(" (Strg+Z macht es r\u00fcckg\u00e4ngig)")), type = "message")
  })
  shiny::observeEvent(input$memo_new_cancel, { rv$memo_new <- NULL })

  # filter bar with the number per kind
  shiny::observeEvent(input$memo_filter, { rv$memo_filter <- input$memo_filter })
  output$memo_filters <- shiny::renderUI({
    rv$tick
    e <- memo_entries()
    kinds <- c(all = .t("Alle"), passage = .t("Textstelle"), document = .t("Dokument"), code = "Code",
               project = .t("Projekt"), comment = .t("Kommentare"))
    chips <- vapply(names(kinds), function(k) {
      n <- if (k == "all") nrow(e) else sum(e$kind == k)
      sprintf('<button class="memochip%s" data-memofilter="%s">%s <span class="n">%d</span></button>',
              if (identical(rv$memo_filter, k)) " active" else "", k, kinds[[k]], n)
    }, character(1))
    shiny::HTML(paste0('<div class="memochips">', paste(chips, collapse = ""), '</div>'))
  })
  memo_search <- shiny::debounce(shiny::reactive(input$memo_search %||% ""), 300)

  # the memo cards
  output$memos_list <- shiny::renderUI({
    rv$tick
    e <- memo_entries()
    if (nrow(e) == 0) {
      return(shiny::tags$div(class = "jq-hint",
        .t("Noch keine Memos. Oben eine Art w\u00e4hlen (+ Textstelle, + Dokument, + Code, + Projekt) "),
        .t("oder Text markieren und in der Aktionsleiste 'Memo speichern'.")))
    }
    f <- rv$memo_filter %||% "all"
    if (f != "all") e <- e[e$kind == f, , drop = FALSE]
    if (isTRUE(input$memo_only_doc)) {
      e <- e[!is.na(e$source_id) & !is.null(rv$src) & e$source_id %in% rv$src, , drop = FALSE]
    }
    q <- trimws(memo_search())
    if (nzchar(q)) {
      hay <- tolower(paste(e$title, e$text, e$ref))
      e <- e[grepl(tolower(q), hay, fixed = TRUE), , drop = FALSE]
    }
    if (nrow(e) == 0) return(shiny::tags$div(class = "jq-hint", .t("Keine passenden Memos.")))
    # order: most recently changed first; comments/passages of a document in
    # text order when only the open document is shown
    ord <- if (isTRUE(input$memo_only_doc)) order(e$start, na.last = TRUE) else
      order(e$updated, e$id, decreasing = TRUE, na.last = TRUE)
    e <- e[ord, , drop = FALSE]
    cards <- vapply(seq_len(nrow(e)), function(i) {
      k <- e$key[i]; kind <- e$kind[i]
      focus <- if (identical(rv$memo_focus, k)) " focus" else ""
      head <- sprintf('<div class="mc-head"><span class="mc-kind"><i class="fa-solid fa-%s"></i> %s</span><span class="mc-date">%s</span></div>',
                      kind_icon[[kind]], kind_label[[kind]], esc(fmt_date(e$updated[i])))
      ref <- sprintf(.t('<div class="mc-ref" data-memojump="%s" title="Hinspringen">%s</div>'), k, esc(e$ref[i]))
      if (identical(rv$edit_entry, k)) {
        title_in <- if (kind == "comment") "" else
          sprintf(.t('<input type="text" class="form-control mc-titlein" id="memo_title_%s" value="%s" placeholder="Titel (optional)">'),
                  k, esc(e$title[i], attribute = TRUE))
        sprintf(.t('<div class="memocard editing kind-%s%s" data-memokey="%s">%s%s%s
                 <textarea id="memo_edit_%s" class="form-control" rows="4">%s</textarea>
                 <div class="mc-btns"><button class="mini ok" data-savememo="%s"><i class="fa-solid fa-check"></i> Speichern</button>
                 <button class="mini" data-canceledit="1">Abbrechen</button></div></div>'),
                kind, focus, k, head, ref, title_in, k, esc(e$text[i]), k)
      } else {
        del <- if (kind == "comment") {
          sprintf(.t('<button class="mini danger" data-delcomment="%d" title="Kommentar entfernen (das Coding bleibt)"><i class="fa-solid fa-trash"></i> Entfernen</button>'), e$id[i])
        } else {
          sprintf(.t('<button class="mini danger" data-delmemo="%d" title="Memo l\u00f6schen (Strg+Z macht es r\u00fcckg\u00e4ngig)"><i class="fa-solid fa-trash"></i> L\u00f6schen</button>'), e$id[i])
        }
        sprintf(.t('<div class="memocard kind-%s%s" data-memokey="%s">%s%s%s<div class="mc-text">%s</div>
                 <div class="mc-btns"><button class="mini" data-editmemo="%s"><i class="fa-solid fa-pen"></i> Bearbeiten</button>%s</div></div>'),
                kind, focus, k, head,
                if (nzchar(e$title[i])) sprintf('<div class="mc-title">%s</div>', esc(e$title[i])) else "",
                ref, esc(e$text[i]), k, del)
      }
    }, character(1))
    shiny::HTML(paste(cards, collapse = ""))
  })

  shiny::observeEvent(input$edit_memo_entry, { rv$edit_entry <- input$edit_memo_entry })
  shiny::observeEvent(input$cancel_edit, { rv$edit_entry <- NULL; bump() })
  # Save: jellyqda.js sends {key, text, title} directly from the fields (not
  # via the delayed Shiny inputs, which might miss the last typed
  # characters). A bare key (older calls/tests) reads the inputs
  # memo_edit_<key> / memo_title_<key>.
  shiny::observeEvent(input$save_memo_entry, {
    p <- input$save_memo_entry
    key <- if (is.list(p)) p$key else p
    txt <- if (is.list(p)) p$text else input[[paste0("memo_edit_", key)]]
    ttl <- if (is.list(p)) p$title else input[[paste0("memo_title_", key)]]
    if (is.null(txt)) return()
    parts <- strsplit(key, "_", fixed = TRUE)[[1]]
    if (parts[1] == "cod") {
      qda_coding_set_memo(as.integer(parts[2]), txt)
    } else {
      qda_memo_update(as.integer(parts[2]), text_ = txt, title = ttl)
    }
    rv$edit_entry <- NULL
    rv$memo_focus <- key
    bump()
    shiny::showNotification(paste0(qda_history()$undo, .t(" (Strg+Z macht es r\u00fcckg\u00e4ngig)")), type = "message")
  })
  shiny::observeEvent(input$del_memo, {
    qda_memo_delete(input$del_memo)
    if (identical(rv$sel_memo, input$del_memo)) rv$sel_memo <- NULL
    bump()
    shiny::showNotification(paste0(qda_history()$undo, .t(" (Strg+Z macht es r\u00fcckg\u00e4ngig)")), type = "message")
  })
  shiny::observeEvent(input$del_comment, {
    qda_coding_set_memo(input$del_comment, "")
    bump()
    shiny::showNotification(.t("Kommentar entfernt (Strg+Z macht es r\u00fcckg\u00e4ngig)."), type = "message")
  })

  # click the reference of a card -> jump there
  shiny::observeEvent(input$memo_jump, {
    key <- input$memo_jump
    parts <- strsplit(key, "_", fixed = TRUE)[[1]]
    id <- as.integer(parts[2])
    rv$memo_focus <- key
    if (parts[1] == "cod") {
      df <- qda_codings(); row <- df[df$id == id, , drop = FALSE]
      if (nrow(row) == 0) return()
      rv$src <- row$source_id; rv$sel <- NULL; rv$clicked <- row$id; rv$caret <- NULL
      bump()
      session$sendCustomMessage("jellyqdaScroll", list(cid = row$id))
      return()
    }
    m <- qda_memos(); m <- m[m$id == id, , drop = FALSE]
    if (nrow(m) == 0) return()
    if (m$kind %in% c("passage", "document")) {
      rv$src <- m$source_id; rv$sel <- NULL; rv$caret <- NULL
      rv$sel_memo <- if (m$kind == "passage") m$id else NULL
      bump()
      if (m$kind == "passage") session$sendCustomMessage("jellyqdaScroll", list(mid = m$id))
    } else if (m$kind == "code") {
      rv$sel_code <- m$code_id
      bump()
    } else bump()
  })
  # underlined passage clicked in the document -> show the card
  shiny::observeEvent(input$clicked_memo, {
    key <- paste0("memo_", input$clicked_memo)
    rv$sel_memo <- input$clicked_memo
    rv$memo_focus <- key
    rv$memo_filter <- "all"
    bump()
    session$sendCustomMessage("jellyqdaMemoFocus", list(key = key))
  })
  # memo icon in the code tree / in the document list
  shiny::observeEvent(input$code_memo, {
    rv$sel_code <- input$code_memo
    m <- qda_memos(kind = "code", code = input$code_memo)
    rv$memo_filter <- "code"
    rv$memo_focus <- if (nrow(m)) paste0("memo_", m$id[nrow(m)]) else NULL
    bump()
    session$sendCustomMessage("jellyqdaMemoFocus", list(key = rv$memo_focus))
  })
  shiny::observeEvent(input$doc_memo, {
    m <- qda_memos(kind = "document", source = input$doc_memo)
    rv$memo_filter <- "document"
    rv$memo_focus <- if (nrow(m)) paste0("memo_", m$id[nrow(m)]) else NULL
    bump()
    session$sendCustomMessage("jellyqdaMemoFocus", list(key = rv$memo_focus))
  })

  # header: stats + backup + export ---------------------------------------------
  output$stats_line <- shiny::renderText({
    rv$tick
    st <- qda_stats()$overall
    sprintf(.t("%d Quellen - %d Codes - %d Codings - %.1f %% codiert"),
            st$n_sources, st$n_codes, st$n_codings, st$pct_coded)
  })
  output$saved_line <- shiny::renderText({
    rv$tick
    sprintf(.t("Alles gespeichert \u00b7 %s"), rv$last_saved %||% "-")
  })
  # Save (button or Ctrl+S): checkpoint the database + restore point
  shiny::observeEvent(input$save_btn, {
    tryCatch(DBI::dbGetQuery(qda_con(), "PRAGMA wal_checkpoint(TRUNCATE)"), error = function(e) NULL)
    z <- tryCatch(qda_backup(quiet = TRUE), error = function(e) NULL)
    bump()
    shiny::showNotification(
      if (is.null(z)) .t("Gespeichert.") else paste(.t("Gespeichert \u00b7 Sicherungspunkt:"), basename(z)),
      type = "message")
  })
  # Undo / redo ------------------------------------------------------------------
  # Buttons in the top bar or Ctrl+Z / Ctrl+Y (jellyqda.js, section 6).
  shiny::observeEvent(input$undo_btn, {
    res <- tryCatch(qda_undo(), error = function(e) {
      shiny::showNotification(paste(.t("R\u00fcckg\u00e4ngig nicht m\u00f6glich:"), conditionMessage(e)),
                              type = "warning")
      NULL
    })
    if (!is.null(res)) {
      if (res$undone == "nothing") {
        shiny::showNotification(.t("Nichts mehr r\u00fcckg\u00e4ngig zu machen."), type = "message")
      } else {
        rv$sel <- NULL; rv$clicked <- NULL; rv$caret <- NULL
        bump()
        shiny::showNotification(paste(.t("R\u00fcckg\u00e4ngig:"), res$detail), type = "message")
      }
    }
  })
  shiny::observeEvent(input$redo_btn, {
    res <- tryCatch(qda_redo(), error = function(e) {
      shiny::showNotification(paste(.t("Wiederholen nicht m\u00f6glich:"), conditionMessage(e)),
                              type = "warning")
      NULL
    })
    if (!is.null(res)) {
      if (res$redone == "nothing") {
        shiny::showNotification(.t("Nichts zu wiederholen."), type = "message")
      } else {
        rv$sel <- NULL; rv$clicked <- NULL; rv$caret <- NULL
        bump()
        shiny::showNotification(paste(.t("Wiederholt:"), res$detail), type = "message")
      }
    }
  })
  # after every change: set tooltips + enabled/disabled state of both buttons
  shiny::observe({
    rv$tick
    h <- qda_history()
    session$sendCustomMessage("jellyqdaHistory", list(undo = h$undo, redo = h$redo))
  })
  # click on a segment badge -> select the whole segment (action bar appears).
  # jellyqda.js sends input$seg_click only for a real click on the "Seg N"
  # badge, not after a mouse selection in the text.
  shiny::observeEvent(input$seg_click, {
    shiny::req(rv$src)
    segs <- .segments_for(rv$src)
    i <- as.integer(input$seg_click)
    if (i < 1 || i > nrow(segs)) return()
    rv$caret <- NULL   # the click on the badge also sets a cursor -> discard it
    rv$sel <- list(start = segs$start[i], end = segs$end[i],
                   text = substring(.resolve_source(rv$src)$frozen_text, segs$start[i], segs$end[i]))
    bump()
  })
  # Edit segments ----------------------------------------------------------------
  # Click into the text without a selection -> jellyqda.js sends the cursor
  # position (input$caret, 0-based = number of characters before it). Then
  # the segment bar with split / merge appears.
  shiny::observeEvent(input$caret, {
    rv$caret <- input$caret$pos
  })
  # segment containing the cursor (also directly after the last character)
  caret_segment <- function() {
    if (is.null(rv$src) || is.null(rv$caret)) return(NULL)
    segs <- .segments_for(rv$src)
    p <- rv$caret + 1L
    i <- which(segs$start <= p & segs$end + 1L >= p)
    if (length(i) == 0) return(NULL)
    list(i = i[1], n = nrow(segs), start = segs$start[i[1]], end = segs$end[i[1]])
  }
  output$segbar <- shiny::renderUI({
    rv$tick
    if (!is.null(rv$sel)) return(NULL)        # with a selection: action bar
    cs <- caret_segment()
    if (is.null(cs)) return(NULL)
    btn <- function(act, label, title, enabled = TRUE) {
      shiny::tags$button(class = "mini segact", `data-segact` = act, title = title,
                         disabled = if (!enabled) "disabled" else NULL, label)
    }
    shiny::div(class = "segbar",
      shiny::span(class = "seginfo", sprintf(.t("Segment %d von %d (Zeichen %d-%d)"),
                                             cs$i, cs$n, cs$start, cs$end)),
      btn("split", .t("Hier teilen"), .t("Neues Segment ab der Cursorposition beginnen")),
      btn("prev", .t("\u2191 Mit vorherigem zusammenf\u00fchren"),
          .t("Dieses Segment an das vorherige anh\u00e4ngen"), cs$i > 1),
      btn("next", .t("\u2193 Mit n\u00e4chstem zusammenf\u00fchren"),
          .t("Das n\u00e4chste Segment an dieses anh\u00e4ngen"), cs$i < cs$n),
      shiny::tags$button(class = "mini segclose", `data-segact` = "close", title = .t("Schlie\u00dfen"), "\u00d7")
    )
  })
  # action from the segment bar or the action bar ("As segment")
  shiny::observeEvent(input$seg_action, {
    shiny::req(rv$src)
    act <- input$seg_action$act
    if (identical(act, "close")) { rv$caret <- NULL; return() }
    cs <- caret_segment()
    res <- tryCatch({
      if (act %in% c("split", "prev", "next") && is.null(cs)) {
        stop(.t("An der Cursorposition liegt kein Segment."), call. = FALSE)
      }
      if (act == "define" && is.null(rv$sel)) stop(.t("Bitte zuerst Text markieren."), call. = FALSE)
      switch(act,
        split  = qda_segment_split(rv$src, at = rv$caret + 1L),
        prev   = qda_segment_merge(rv$src, cs$i - 1L),
        "next" = qda_segment_merge(rv$src, cs$i),
        define = qda_segment_define(rv$src, rv$sel$start, rv$sel$end),
        stop(.t("Unbekannte Segment-Aktion."), call. = FALSE))
      TRUE
    }, error = function(e) {
      shiny::showNotification(conditionMessage(e), type = "warning"); FALSE
    })
    if (isTRUE(res)) {
      rv$caret <- NULL; rv$sel <- NULL
      bump()
      shiny::showNotification(paste0(qda_history()$undo, .t("  (Strg+Z macht es r\u00fcckg\u00e4ngig)")),
                              type = "message")
    }
  })
  # re-segment the whole document by a rule (documents panel)
  shiny::observeEvent(input$seg_apply, {
    if (is.null(rv$src)) {
      shiny::showNotification(.t("Bitte zuerst ein Dokument \u00f6ffnen."), type = "warning")
      return()
    }
    qda_segments_set(rv$src, input$seg_rule %||% "speaker")
    rv$caret <- NULL; rv$sel <- NULL
    bump()
    shiny::showNotification(paste0(qda_history()$undo, .t("  (Strg+Z macht es r\u00fcckg\u00e4ngig)")),
                            type = "message")
  })

  # Analysis window ---------------------------------------------------------------
  # Three tabs: word frequencies (qda_words), keyword in context (qda_kwic),
  # summary after Mayring (paraphrase/generalisation per coding).
  an_choices <- function() {
    src <- qda_sources(); tr <- .code_tree(qda_codes())
    list(docs = c(stats::setNames("", .t("(alle Dokumente)")), stats::setNames(as.character(src$id), src$name)),
         codes = c(stats::setNames("", .t("(alle Codes)")), stats::setNames(as.character(tr$id),
                   paste0(strrep("\u00a0\u00a0", tr$depth - 1L), tr$label))))
  }
  rv$may_tick <- 0
  shiny::observeEvent(input$analysis_btn, {
    ch <- an_choices()
    sel <- function(id, label, choices) shiny::selectInput(id, label, choices, selectize = FALSE)
    shiny::showModal(shiny::modalDialog(
      title = .t("Analyse"), size = "xl", easyClose = TRUE,
      footer = shiny::modalButton(.t("Schlie\u00dfen")),
      shiny::tabsetPanel(id = "analysis_tab", type = "tabs",
        shiny::tabPanel(.t("Worth\u00e4ufigkeiten"), value = "words",
          shiny::div(class = "anfilters",
            sel("words_src", .t("Dokument"), ch$docs),
            sel("words_code", .t("nur Text in Codings von"), ch$codes),
            shiny::numericInput("words_n", .t("Anzahl W\u00f6rter"), 40, min = 10, max = 500, step = 10)),
          shiny::p(class = "jq-sub", .t("Ohne Zahlen, Zeitmarken, F\u00fcll- und Stoppw\u00f6rter. Wort anklicken = Stichwort im Kontext.")),
          shiny::uiOutput("words_table")),
        shiny::tabPanel(.t("Stichwort im Kontext"), value = "kwic",
          shiny::div(class = "anfilters",
            shiny::textInput("kwic_q", .t("Wort oder Phrase"), placeholder = .t("z. B. Familie")),
            sel("kwic_src", .t("Dokument"), ch$docs),
            shiny::checkboxInput("kwic_whole", .t("nur ganze W\u00f6rter"), TRUE)),
          shiny::uiOutput("kwic_table")),
        shiny::tabPanel(.t("Zusammenfassung (Mayring)"), value = "mayring",
          shiny::div(class = "anfilters",
            sel("may_code", .t("Code (mit Subcodes)"), ch$codes),
            sel("may_src", .t("Dokument"), ch$docs),
            shiny::downloadButton("may_csv", .t("Tabelle f\u00fcr Excel (CSV)"), class = "btn-sm btn-outline-secondary")),
          shiny::p(class = "jq-sub", shiny::strong(.t("Paraphrase")), .t(" = Inhalt kurz in eigenen Worten \u00b7 "),
                   shiny::strong(.t("Generalisierung")), .t(" = auf das Abstraktionsniveau der Analyse gehoben \u00b7 "),
                   shiny::strong(.t("Reduktion")), .t(" = der Code. Gespeichert wird beim Verlassen eines Feldes.")),
          shiny::uiOutput("mayring_table")))))
  })
  output$words_table <- shiny::renderUI({
    rv$tick
    n <- suppressWarnings(as.integer(input$words_n %||% 40)); if (is.na(n)) n <- 40L
    w <- qda_words(source = if (nzchar(input$words_src %||% "")) as.integer(input$words_src) else NULL,
                   code = if (nzchar(input$words_code %||% "")) as.integer(input$words_code) else NULL,
                   n = n)
    if (nrow(w) == 0) return(shiny::div(class = "jq-hint", .t("Keine W\u00f6rter gefunden.")))
    mx <- max(w$n)
    rows <- sprintf('<tr><td class="num">%d</td><td><button class="linkword" data-kwicword="%s">%s</button></td><td class="num">%d</td><td class="wbar"><span style="width:%.1f%%"></span></td><td class="num">%d</td></tr>',
                    seq_len(nrow(w)), esc(w$word, attribute = TRUE), esc(w$word), w$n, 100 * w$n / mx, w$sources)
    shiny::HTML(paste0(.t('<table class="antable words"><thead><tr><th>#</th><th>Wort</th><th>H\u00e4ufigkeit</th><th></th><th>Dokumente</th></tr></thead><tbody>'),
                       paste(rows, collapse = ""), "</tbody></table>"))
  })
  shiny::observeEvent(input$kwic_word, {
    shiny::updateTextInput(session, "kwic_q", value = input$kwic_word)
    shiny::updateTabsetPanel(session, "analysis_tab", selected = "kwic")
  })
  output$kwic_table <- shiny::renderUI({
    q <- trimws(input$kwic_q %||% "")
    if (nchar(q) < 2) return(shiny::div(class = "jq-hint", .t("Mindestens zwei Zeichen eingeben.")))
    k <- qda_kwic(q, source = if (nzchar(input$kwic_src %||% "")) as.integer(input$kwic_src) else NULL,
                  width = 60, whole_word = isTRUE(input$kwic_whole))
    if (nrow(k) == 0) return(shiny::div(class = "jq-hint", sprintf(.t("Keine Treffer f\u00fcr \u201e%s\u201c."), q)))
    shown <- utils::head(k, 300)
    rows <- sprintf(.t('<tr class="kwicrow" data-kwicsrc="%d" data-kwicpos="%d" title="Im Dokument zeigen"><td class="kref">%s<br><span class="jq-sub">Seg %s</span></td><td class="kl">%s</td><td class="km">%s</td><td class="kr">%s</td></tr>'),
                    shown$source_id, shown$start, esc(shown$source), ifelse(is.na(shown$segment), "-", shown$segment),
                    esc(shown$left), esc(shown$match), esc(shown$right))
    shiny::HTML(paste0(sprintf(.t('<p class="jq-sub">%d Treffer in %d Dokument(en)%s. Zeile anklicken = im Dokument zeigen.</p>'),
                               nrow(k), length(unique(k$source_id)), if (nrow(k) > 300) .t(" (die ersten 300 gezeigt)") else ""),
                       '<table class="antable kwic"><tbody>', paste(rows, collapse = ""), "</tbody></table>"))
  })
  shiny::observeEvent(input$kwic_goto, {
    shiny::removeModal()
    rv$src <- as.integer(input$kwic_goto$src); rv$sel <- NULL; rv$clicked <- NULL
    bump()
    session$sendCustomMessage("jellyqdaScroll", list(pos = as.integer(input$kwic_goto$pos)))
  })
  may_rows <- function() {
    cd <- qda_codings()
    tr <- .code_tree(qda_codes())
    if (nzchar(input$may_code %||% "")) cd <- cd[cd$code_id %in% .code_descendants(tr, as.integer(input$may_code)), , drop = FALSE]
    if (nzchar(input$may_src %||% "")) cd <- cd[cd$source_id == as.integer(input$may_src), , drop = FALSE]
    k <- match(cd$code_id, tr$id)
    cd$path <- gsub(" / ", " \u203a ", tr$path[k], fixed = TRUE)
    cd$color <- tr$root_color[k]
    cd$depth <- tr$depth[k]
    cd
  }
  output$mayring_table <- shiny::renderUI({
    rv$may_tick   # not rv$tick: the field would lose the focus on saving otherwise
    cd <- may_rows()
    if (nrow(cd) == 0) return(shiny::div(class = "jq-hint", .t("Keine Codings f\u00fcr diese Auswahl.")))
    short <- function(x, n = 320) ifelse(nchar(x) > n, paste0(substr(x, 1, n), "\u2026"), x)
    rows <- sprintf(paste0(.t('<tr><td class="mref">%s<br><span class="jq-sub">#%d \u00b7 Z. %d\u2013%d</span></td>'),
                           '<td class="mtext">%s</td>',
                           '<td><textarea class="form-control form-control-sm" rows="3" data-mayid="%d" data-mayfield="paraphrase" aria-label="Paraphrase">%s</textarea></td>',
                           .t('<td><textarea class="form-control form-control-sm" rows="3" data-mayid="%d" data-mayfield="generalization" aria-label="Generalisierung">%s</textarea></td>'),
                           '<td class="mcode"><span class="swatch%s" style="--c:%s"></span> %s</td></tr>'),
                    esc(cd$source), cd$id, cd$start, cd$end, esc(short(gsub("\\s+", " ", cd$text))),
                    cd$id, esc(cd$paraphrase), cd$id, esc(cd$generalization),
                    ifelse(cd$depth > 1L, " sub", ""), esc(cd$color), esc(cd$path))
    shiny::HTML(paste0(.t('<table class="antable mayring"><thead><tr><th>Fall</th><th>Textstelle</th><th>Paraphrase</th><th>Generalisierung</th><th>Reduktion (Code)</th></tr></thead><tbody>'),
                       paste(rows, collapse = ""), "</tbody></table>"))
  })
  shiny::observeEvent(input$mayring_save, {
    m <- input$mayring_save
    val <- trimws(m$value %||% "")
    res <- tryCatch(
      if (identical(m$field, "paraphrase")) qda_coding_set_summary(as.integer(m$id), paraphrase = val)
      else qda_coding_set_summary(as.integer(m$id), generalization = val),
      error = function(e) { shiny::showNotification(conditionMessage(e), type = "warning"); NULL })
    if (!is.null(res)) bump()
  })
  output$may_csv <- shiny::downloadHandler(
    filename = function() paste0("mayring_", format(Sys.time(), "%Y%m%d-%H%M"), ".csv"),
    content = function(file) {
      cd <- may_rows()
      readr::write_excel_csv2(data.frame(Fall = cd$source, Coding = cd$id, Start = cd$start, Ende = cd$end,
                                         Textstelle = cd$text, Paraphrase = cd$paraphrase,
                                         Generalisierung = cd$generalization, Reduktion = cd$path,
                                         check.names = FALSE), file)
    })

  # help modal: legend of icons + shortcuts
  shiny::observeEvent(input$help_btn, {
    shiny::showModal(shiny::modalDialog(
      title = .t("Hilfe: Symbole & Tastenkuerzel"),
      shiny::tags$ul(
        shiny::tags$li(shiny::strong(.t("Kodier-Leiste")), .t(" - Text markieren, dann Code anklicken. Hat ein Code Subcodes, klappt der Klick sie aus; \u201e(nur Code)\u201c vergibt den Code selbst. Suchfeld: Code \u00fcber den Pfad finden, Enter ohne Treffer legt einen neuen Code an")),
        shiny::tags$li(shiny::strong(.t("Strg+1..9")), .t(" - n-ter Code der Kodier-Leiste; danach "), shiny::strong("1..9"), .t(" = Subcode, "), shiny::strong("0"), .t(" = nur der Code, "), shiny::strong("Esc"), .t(" = zuklappen")),
        shiny::tags$li(shiny::strong(.t("Codebaum")), .t(" - \u201e+ Code\u201c oben, \u201e+ Subcode\u201c an der Zeile; "), shiny::strong(.t("Doppelklick")), .t(" (oder F2) = umbenennen; Papierkorb = l\u00f6schen (mit R\u00fcckfrage); Farbpunkt = Farbe der Code-Familie; Pfeil = ein-/ausklappen. Ist Text markiert, codiert ein Klick auf einen Code")),
        shiny::tags$li(shiny::strong(.t("Coding anklicken")), .t(" - Details, Umkodieren innerhalb der Code-Familie, Kommentar, Mayring (Paraphrase/Generalisierung), Ankerbeispiel, L\u00f6schen")),
        shiny::tags$li(shiny::strong(.t("In vivo")), .t(" - Kodier-Leiste: der markierte Text wird zum neuen Code")),
        shiny::tags$li(shiny::strong(.t("Buch / Pfeil am Code")), .t(" - Kodierleitfaden (Definition, Ankerbeispiel, Kodierregel) / mit anderem Code zusammenf\u00fchren")),
        shiny::tags$li(shiny::strong(.t("Suche")), .t(" - \u201eAlle Treffer codieren\u201c codiert jede Fundstelle (oder ihr Segment) in einem Schritt")),
        shiny::tags$li(shiny::strong(.t("Code-Matrix: Spalten")), .t(" - Fallvergleich nach einer Dokument-Variable")),
        shiny::tags$li(shiny::strong(.t("Analyse")), .t(" - Worth\u00e4ufigkeiten, Stichwort im Kontext, Zusammenfassung nach Mayring")),
        shiny::tags$li(shiny::strong(.t("Strg+S")), .t(" - Speichern + Sicherungspunkt (gespeichert wird ohnehin jede Aktion sofort)")),
        shiny::tags$li(shiny::strong(.t("Bericht")), .t(" - \u00f6ffnet den Bericht in einem neuen Tab, druckbar auf A4 (Strg+P)")),
        shiny::tags$li(shiny::strong(.t("Strg+M")), .t(" - Textstellen-Memo zur Markierung (mit Text im Memo-Feld: sofort, sonst Formular im Memo-Panel)")),
        shiny::tags$li(shiny::strong("Memos"), .t(" - vier Arten: Textstelle (unterstrichen), Dokument, Code (z.B. Definition, Kodierregel), Projekt; dazu Kommentare an Codings. Panel rechts: + Neues Memo, Filter, Suche; Bezug anklicken = hinspringen; Strg+Enter speichert")),
        shiny::tags$li(shiny::strong(.t("Segmente")), .t(" - in den Text klicken: Segment hier teilen / zusammenf\u00fchren; Text markieren: 'Als Segment'; Dokumente-Panel: ganzes Dokument neu einteilen (z.B. nach Sprecherwechsel)")),
        shiny::tags$li(shiny::strong(.t("\u00dcberlappungen")), .t(" - graue Stellen mit Zahl = mehrere Codings; Maus dar\u00fcber zeigt sie an, Klick heftet die Liste fest")),
        shiny::tags$li(shiny::strong(.t("Strg+Z / Strg+Y")), .t(" - letzte Aktion r\u00fcckg\u00e4ngig machen / wiederholen (auch Code l\u00f6schen, Variablen, Summaries, Segmente)")),
        shiny::tags$li(shiny::strong(.t("Seg-Badge")), .t(" anklicken - ganzen Absatz markieren")),
        shiny::tags$li(shiny::strong(.t("Symbolleiste / Chevron")), .t(" - jeweiliges Fenster (Panel) ein-/ausklappen")),
        shiny::tags$li(shiny::strong(.t("Mond")), .t(" - Dark Mode; "), shiny::strong("?"), .t(" - diese Hilfe; "), shiny::strong("X"), .t(" - App beenden (speichert + Backup)")),
        shiny::tags$li(shiny::strong(.t("Umh\u00e4ngen")), .t(" - Code auf einen anderen Code ziehen = wird dessen Subcode")),
        shiny::tags$li(shiny::strong(.t("Dokumente-Panel")), .t(" - Dateien per Drag & Drop importieren")),
        shiny::tags$li(shiny::strong(.t("Doppel-Codierung")), .t(" - derselbe Text mehrfach codiert: gestrichelter pinker Rahmen"))
      ),
      easyClose = TRUE, footer = shiny::modalButton(.t("Schliessen"))
    ))
  })
  shiny::observeEvent(input$backup_btn, {
    z <- qda_backup(quiet = TRUE)
    bump(); shiny::showNotification(paste(.t("Backup:"), z), type = "message")
  })
  shiny::observeEvent(input$export_codebook_btn, {
    ex <- qda_export("codebook")
    bump(); shiny::showNotification(paste(.t("Codebuch exportiert:"), paste(basename(ex$file), collapse = ", ")), type = "message")
  })
  shiny::observeEvent(input$export_report_btn, {
    ex <- qda_export("report")
    bump(); shiny::showNotification(paste(.t("Bericht gespeichert:"), basename(ex$file)), type = "message")
  })
  shiny::observeEvent(input$export_btn, {
    ex <- qda_export("all")
    bump(); shiny::showNotification(paste(.t("Exportiert:"), nrow(ex), .t("Dateien nach exports/")), type = "message")
  })

  # code matrix (Code Matrix Browser) -------------------------------------------
  # Code matrix in code-tree order. Codes with subcodes show the sum incl.
  # subcodes (Sigma); the subcode rows collapse with the code tree
  # (data-anc = ancestors, jellyqda.js section 15).
  output$matrix_panel <- shiny::renderUI({
    rv$tick
    codes <- qda_codes()
    sources <- qda_sources()
    if (nrow(codes) == 0 || nrow(sources) == 0) {
      return(shiny::tags$div(class = "jq-hint", .t("Codes und Dokumente noetig.")))
    }
    tr <- .code_tree(codes)
    esc2 <- htmltools::htmlEscape
    anc_of <- function(id) {
      out <- integer(); p <- tr$parent_id[tr$id == id]
      while (length(p) && !is.na(p)) { out <- c(out, p); p <- tr$parent_id[tr$id == p] }
      out
    }
    # columns: documents or the values of a variable (case comparison)
    vars <- sort(unique(unlist(lapply(sources$id, function(i) names(qda_source_vars(i))))))
    by <- rv$mx_by %||% ""
    if (!by %in% vars) by <- ""
    sel <- sprintf(paste0(.t('<div class="mxby"><label for="mx_by">Spalten</label>'),
                          .t('<select id="mx_by" class="form-select form-select-sm"><option value="">Dokumente</option>%s</select>%s</div>')),
                   paste(sprintf(.t('<option value="%s"%s>Fallvergleich: %s</option>'), esc2(vars, attribute = TRUE),
                                 ifelse(vars == by, " selected", ""), esc2(vars)), collapse = ""),
                   if (length(vars) == 0) .t('<span class="jq-sub">Fallvergleich: erst Variablen an Dokumenten setzen</span>') else "")
    if (nzchar(by)) {
      cm <- qda_case_matrix(by)
      groups <- setdiff(names(cm), c("code", "path", "depth"))
      nd <- attr(cm, "n_documents")
      maxn <- max(1, as.matrix(cm[, groups, drop = FALSE]))
      head <- paste0('<tr><th>Code \\ ', esc2(by), '</th>',
                     paste0('<th>', esc2(groups), ' <span class="jq-sub">(', nd[groups], .t(' Dok.)</span></th>'), collapse = ""),
                     '</tr>')
      body <- vapply(seq_len(nrow(tr)), function(i) {
        cells <- vapply(groups, function(g) {
          n <- cm[[g]][i]
          bg <- if (n > 0) sprintf(' style="background:rgba(44,111,187,%s)"', round(0.12 + 0.55 * n / maxn, 2)) else ""
          sprintf('<td class="mxcell nolink"%s>%s</td>', bg, if (n > 0) n else "")
        }, character(1))
        sub <- tr$depth[i] > 1L
        sprintf('<tr data-mxrow="%d" data-anc="%s"%s><td class="rowlab" data-selcode="%d" style="padding-left:%.1frem"><span class="swatch%s" style="--c:%s"></span> %s%s</td>%s</tr>',
                tr$id[i], paste(anc_of(tr$id[i]), collapse = " "), if (sub) "" else ' class="mxtop"', tr$id[i],
                0.3 + 0.9 * (tr$depth[i] - 1L), if (sub) " sub" else "", esc2(tr$root_color[i]), esc2(tr$label[i]),
                if (tr$has_children[i]) ' <span class="jq-sub">\u03a3</span>' else "", paste0(cells, collapse = ""))
      }, character(1))
      return(shiny::HTML(paste0(sel, '<table class="mx">', head, paste0(body, collapse = ""), "</table>",
                                .t('<p class="jq-sub mxnote">Codings je Gruppe; Codes z\u00e4hlen ihre Subcodes mit.</p>'))))
    }
    cod <- DBI::dbGetQuery(qda_con(), "SELECT code_id, source_id, COUNT(*) AS n FROM codings GROUP BY code_id, source_id")
    own <- matrix(0L, nrow = nrow(tr), ncol = nrow(sources),
                  dimnames = list(as.character(tr$id), as.character(sources$id)))
    if (nrow(cod) > 0) {
      ok <- as.character(cod$code_id) %in% rownames(own) & as.character(cod$source_id) %in% colnames(own)
      own[cbind(as.character(cod$code_id[ok]), as.character(cod$source_id[ok]))] <- cod$n[ok]
    }
    cnt <- own
    for (i in seq_len(nrow(tr))) {
      if (tr$has_children[i]) {
        ids <- as.character(.code_descendants(tr, tr$id[i]))
        cnt[i, ] <- colSums(own[ids, , drop = FALSE])
      }
    }
    maxn <- max(cnt, 1L)
    head <- paste0(.t('<tr><th>Code \\ Dokument</th>'),
                   paste0('<th>', esc2(sources$name), '</th>', collapse = ""), "<th>SUM</th></tr>")
    body_rows <- vapply(seq_len(nrow(tr)), function(i) {
      cells <- vapply(seq_len(nrow(sources)), function(j) {
        n <- cnt[i, j]
        # Heatmap: opacity 0.12..0.67 -- stronger would push the number in the
        # cell (light and dark) below the WCAG contrast of 4.5:1
        bg <- if (n > 0) sprintf(' style="background:rgba(44,111,187,%s)"', round(0.12 + 0.55 * n / maxn, 2)) else ""
        sprintf('<td class="mxcell" data-mxcode="%d" data-mxsrc="%d"%s>%s</td>',
                tr$id[i], sources$id[j], bg, if (n > 0) n else "")
      }, character(1))
      sub <- tr$depth[i] > 1L
      sprintf('<tr data-mxrow="%d" data-anc="%s"%s><td class="rowlab" data-selcode="%d" style="padding-left:%.1frem"><span class="swatch%s" style="--c:%s"></span> %s%s</td>%s<td><b>%d</b></td></tr>',
              tr$id[i], paste(anc_of(tr$id[i]), collapse = " "), if (sub) "" else ' class="mxtop"',
              tr$id[i], 0.3 + 0.9 * (tr$depth[i] - 1L), if (sub) " sub" else "",
              esc2(tr$root_color[i]), esc2(tr$label[i]),
              if (tr$has_children[i]) ' <span class="jq-sub">\u03a3</span>' else "",
              paste0(cells, collapse = ""), as.integer(sum(cnt[i, ])))
    }, character(1))
    top <- tr$depth == 1L
    colsums <- vapply(seq_len(nrow(sources)), function(j) as.integer(sum(cnt[top, j])), integer(1))
    foot <- sprintf('<tr class="sumrow"><td>SUM</td>%s<td>%d</td></tr>',
                    paste0("<td>", colsums, "</td>", collapse = ""), as.integer(sum(cnt[top, ])))
    shiny::HTML(paste0(sel, '<table class="mx">', head, paste0(body_rows, collapse = ""), foot, "</table>"))
  })
  shiny::observeEvent(input$mx_by, { rv$mx_by <- input$mx_by %||% "" })
  shiny::observeEvent(input$mx_cell, {
    rv$sel_code <- input$mx_cell$code
    rv$src <- input$mx_cell$source
    rv$sel <- NULL
    bump()
    shiny::showNotification(.t("Zelle gewaehlt: Code im Browser geoeffnet."), type = "message")
  })

  # summary grid -----------------------------------------------------------------
  output$sum_matrix <- shiny::renderUI({
    rv$tick
    codes <- qda_codes()
    sources <- qda_sources()
    if (nrow(codes) == 0 || nrow(sources) == 0) {
      return(shiny::tags$div(class = "jq-hint", .t("Codes und Dokumente noetig.")))
    }
    cod <- DBI::dbGetQuery(qda_con(), "SELECT code_id, source_id, COUNT(*) AS n FROM codings GROUP BY code_id, source_id")
    has_sum <- qda_summaries()
    has_keys <- if (nrow(has_sum)) paste(has_sum$code_id, has_sum$source_id, sep = "_") else character()
    esc2 <- htmltools::htmlEscape
    codes <- .code_tree(codes)
    head <- paste0(.t('<tr><th>Code \\ Dokument</th>'),
                   paste0("<th>", esc2(substr(sources$name, 1, 12)), "</th>", collapse = ""), "</tr>")
    body_rows <- vapply(seq_len(nrow(codes)), function(i) {
      cells <- vapply(seq_len(nrow(sources)), function(j) {
        n <- if (nrow(cod)) sum(cod$n[cod$code_id == codes$id[i] & cod$source_id == sources$id[j]]) else 0L
        cls <- if (paste(codes$id[i], sources$id[j], sep = "_") %in% has_keys) "sumcell has" else "sumcell"
        sprintf('<td class="%s" data-sumcode="%d" data-sumsrc="%d" title="%d Codings">%s</td>',
                cls, codes$id[i], sources$id[j], n, if (n > 0) n else "")
      }, character(1))
      sprintf('<tr><td class="rowlab" data-selcode="%d" style="padding-left:%.1frem"><span class="swatch%s" style="--c:%s"></span> %s</td>%s</tr>',
              codes$id[i], 0.3 + 0.9 * (codes$depth[i] - 1L), if (codes$depth[i] > 1L) " sub" else "",
              esc2(codes$root_color[i]), esc2(codes$label[i]), paste0(cells, collapse = ""))
    }, character(1))
    shiny::HTML(paste0('<table class="mx">', head, paste0(body_rows, collapse = ""), "</table>"))
  })
  shiny::observeEvent(input$sum_cell, {
    rv$sum_cell <- list(code = input$sum_cell$code, source = input$sum_cell$source)
    s <- qda_summaries()
    row <- s[s$code_id == rv$sum_cell$code & s$source_id == rv$sum_cell$source, , drop = FALSE]
    rv$sum_text_val <- if (nrow(row)) row$text_[1] else ""
  })
  output$sum_detail <- shiny::renderUI({
    rv$tick
    sc <- rv$sum_cell
    if (is.null(sc)) {
      return(shiny::tags$div(class = "jq-hint", .t("Zelle in der Summary-Grid anklicken ...")))
    }
    codes <- qda_codes(); sources <- qda_sources()
    clab <- codes$label[codes$id == sc$code]; slab <- sources$name[sources$id == sc$source]
    segs <- qda_codings()
    segs <- segs[segs$code_id == sc$code & segs$source_id == sc$source, , drop = FALSE]
    seg_rows <- if (nrow(segs) == 0) .t('<div class="jq-hint">keine Segmente</div>') else {
      paste(vapply(seq_len(nrow(segs)), function(i) {
        snippet <- if (nchar(segs$text[i]) > 70) paste0(substr(segs$text[i], 1, 70), "...") else segs$text[i]
        sprintf('<div class="segrow" data-goto="%d"><span class="snippet">#%d (%d-%d) %s</span></div>',
                segs$id[i], segs$id[i], segs$start[i], segs$end[i], esc(snippet))
      }, character(1)), collapse = "")
    }
    shiny::div(
      shiny::tags$b(sprintf(.t("Zelle: %s x %s (%d Segmente)"), clab, slab, nrow(segs))),
      shiny::div(class = "sumdetail-segs", shiny::HTML(seg_rows)),
      shiny::textAreaInput("sum_text", .t("Summary (wird gespeichert)"), rows = 3, value = rv$sum_text_val %||% ""),
      shiny::actionButton("sum_save_btn", .t("Summary speichern"), icon = .jq_ico("floppy-disk"), class = "btn-sm btn-primary")
    )
  })
  shiny::observeEvent(input$sum_save_btn, {
    shiny::req(rv$sum_cell)
    txt <- input$sum_text %||% ""
    qda_summary_set(rv$sum_cell$code, rv$sum_cell$source, txt)
    rv$sum_text_val <- txt
    bump()
    shiny::showNotification(.t("Summary gespeichert (Audit-Trail)."), type = "message")
  })

  # flexible layout -------------------------------------------------------------
  shiny::observeEvent(input$layout_reset, {
    session$sendCustomMessage("jellyqdaReset", 1)
  })
  # close app: save work (export + backup), then stop ---------------------------
  shiny::observeEvent(input$close_app, {
    qda_export("all")
    z <- qda_backup(quiet = TRUE)
    shiny::showNotification(paste(.t("Gespeichert. Export + Backup:"), z), type = "message", duration = 10)
    shiny::stopApp()
  })
}


