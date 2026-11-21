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
#' Requires the suggested packages `shiny`, `bslib`, `colourpicker` and
#' `fontawesome` (install once; runtime needs no internet).
#'
#' @param host Host to bind; loopback only, default `"127.0.0.1"`.
#' @param port Port; `NULL` picks a random free port.
#' @param open Logical; open the app at all.
#' @param new_window Logical; open the app in a **new browser window**
#'   (default, recommended -- the RStudio Viewer pane is small). With
#'   `new_window = FALSE` it opens inside the RStudio Viewer pane instead.
#' @return Invisibly `NULL` (after the app is stopped).
#' @export
#' @examples
#' \dontrun{
#' qda_open("meinarbeit.jellyqda")
#' qda_app()                    # new browser window; Esc stops the app
#' qda_app(new_window = FALSE)  # inside the RStudio Viewer pane
#' }
qda_app <- function(host = "127.0.0.1", port = NULL, open = TRUE, new_window = TRUE) {
  if (!qda_is_open()) {
    stop("No jellyqda project is open. Call qda_open(path) first.", call. = FALSE)
  }
  for (p in c("shiny", "bslib", "colourpicker", "fontawesome")) {
    if (!requireNamespace(p, quietly = TRUE)) {
      stop(sprintf("qda_app() needs the package '%s' (install once, runtime stays offline): install.packages('%s')", p, p), call. = FALSE)
    }
  }
  app <- shiny::shinyApp(ui = .jellyqda_ui(), server = .jellyqda_server)
  launcher <- function(url) {
    cat("jellyqda app (lokal, offline):", url, "\n")
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

# --- CSS + JS einbinden (Dateien in inst/app/www/) ---------------------------
# Das gesamte Styling und die komplette Browser-Logik liegen NICHT mehr als
# lange Strings in dieser Datei, sondern in eigenen Dateien:
#
#   inst/app/www/jellyqda.css  -- Aussehen (Layout, Farben, Dark Mode)
#   inst/app/www/jellyqda.js   -- Browser-Logik (Textauswahl -> Offsets,
#                                 Klicks -> Shiny-Inputs, Tastenkuerzel,
#                                 Drag & Drop, Layout speichern)
#
# Nach der Installation liegt inst/app/www/ als app/www/ im Paketordner;
# system.file() findet ihn (auch mit devtools::load_all()).
#
# includeCSS()/includeScript() lesen die Dateien bei jedem App-Start und
# schreiben ihren Inhalt direkt in den <head> der Seite. Vorteil: der
# Browser kann nie eine veraltete, zwischengespeicherte Version benutzen.
#
# Wichtig beim Aendern: nach Bearbeiten von CSS/JS das Paket neu installieren
# (devtools::install()) bzw. devtools::load_all() ausfuehren und R neu starten.
#' @noRd
.jellyqda_assets <- function() {
  www <- system.file("app", "www", package = "jellyqda")
  if (!nzchar(www)) {
    stop("jellyqda: Ordner app/www nicht gefunden - bitte das Paket neu installieren.",
         call. = FALSE)
  }
  shiny::tagList(
    htmltools::includeCSS(file.path(www, "jellyqda.css")),
    htmltools::includeScript(file.path(www, "jellyqda.js"))
  )
}


# --- UI: four-pane layout (MAXQDA workflow logic, jellyqda look) -------------
#' @noRd
.jellyqda_ui <- function() {
  fa <- fontawesome::fa
  bslib::page_fluid(
    theme = bslib::bs_theme(version = 5, primary = "#2c6fbb", font_scale = 0.82),
    shiny::tags$head(
      .jellyqda_assets(),   # CSS + JS aus inst/app/www/ (siehe oben)
      # Unsichtbare Icons: sorgen nur dafuer, dass Font Awesome (CSS + Fonts)
      # beim Start geladen wird. Das HTML, das der Server spaeter per renderUI
      # erzeugt, benutzt <i class="fa-solid ..."> und braucht diese Fonts.
      shiny::div(style = "display:none", fa("folder-tree"), fa("tags"), fa("highlighter"),
                 fa("note-sticky"), fa("trash"), fa("floppy-disk"), fa("file-export"),
                 fa("plus"), fa("file-lines"), fa("table-columns"), fa("pen"), fa("chevron-down"),
                 fa("table-cells"), fa("table-list"), fa("xmark"), fa("check"),
                 fa("rotate-left"), fa("rotate-right"), fa("moon"), fa("scissors"),
                 fa("circle-question"), fa("magnifying-glass"), fa("trash"))
    ),
    shiny::div(class = "topbar",
      shiny::span(class = "stats", shiny::textOutput("stats_line", inline = TRUE)),
      shiny::span(class = "savedline", shiny::textOutput("saved_line", inline = TRUE)),
      shiny::div(class = "btnsection",
        # Rueckgaengig / Wiederholen (Strg+Z / Strg+Y). Der Tooltip zeigt, was
        # genau passiert; er wird vom Server per "jellyqdaHistory" aktualisiert.
        shiny::actionButton("undo_btn", "R\u00fcckg\u00e4ngig", icon = fa("rotate-left"),
                            class = "btn-sm btn-outline-secondary", title = "R\u00fcckg\u00e4ngig (Strg+Z)"),
        shiny::actionButton("redo_btn", "Wiederholen", icon = fa("rotate-right"),
                            class = "btn-sm btn-outline-secondary", title = "Wiederholen (Strg+Y)"),
        shiny::actionButton("backup_btn", "Backup", icon = fa("floppy-disk"), class = "btn-sm btn-outline-secondary"),
        shiny::actionButton("export_btn", "Export", icon = fa("file-export"), class = "btn-sm btn-outline-secondary"),
        shiny::actionButton("layout_reset", "Layout reset", icon = fa("table-columns"),
                            class = "btn-sm btn-outline-secondary")
      ),
      shiny::div(class = "symbolbar",
        shiny::span(class = "symgroup",
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-docs", title = "Dokumente ein-/ausklappen", fa("folder-tree")),
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-codes", title = "Code System ein-/ausklappen", fa("tags")),
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-matrix", title = "Code-Matrix ein-/ausklappen", fa("table-cells"))),
        shiny::span(class = "symsep"),
        shiny::span(class = "symgroup",
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-browser", title = "Dokument-Browser ein-/ausklappen", fa("file-lines")),
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-segs", title = "All Codings ein-/ausklappen", fa("highlighter"))),
        shiny::span(class = "symsep"),
        shiny::span(class = "symgroup",
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-memos", title = "Memos ein-/ausklappen", fa("note-sticky")),
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-summary", title = "Summary Grid ein-/ausklappen", fa("table-list"))),
        shiny::span(class = "symsep"),
        shiny::tags$button(class = "symbtn", `data-dark` = "1", title = "Dark Mode umschalten", fa("moon")),
        shiny::tags$button(class = "symbtn", `data-help` = "1", title = "Hilfe: Symbole, Tastenkuerzel", fa("circle-question")),
        shiny::span(class = "symsep"),
        shiny::tags$button(class = "symbtn closeapp", `data-closeapp` = "1", title = "App beenden (speichert + stoppt)", fa("xmark"))
      )
    ),
    shiny::div(class = "appgrid",
      # left column: document tree (top) + code system (bottom)
      shiny::div(class = "pane left", `data-pane` = "left",
        shiny::div(class = "panel docs", id = "panel-docs",
shiny::div(class = "panelhead", draggable = "true", fa("folder-tree"), shiny::span(class = "hlabel", "Dokumente"), shiny::span(class = "toggler", `data-toggle` = "panel-docs", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody",
            shiny::uiOutput("doc_tree"),
            shiny::hr(),
            # Segmentierung fuer neu importierte Dokumente (spaeter aenderbar)
            shiny::selectInput("import_segrule", "Segmente beim Import",
                               choices = .segrule_choices(), selected = "blankline"),
            shiny::fileInput("import_files", NULL, multiple = TRUE,
                             accept = c(".txt", ".md", ".docx", ".pdf"), buttonLabel = "Dateien..."),
            shiny::p(class = "jq-hint", style = "padding:.2rem;margin:.2rem 0",
                     "oder Dateien hierher ziehen"),
            shiny::actionButton("import_btn", "Importieren", icon = fa("plus"), class = "btn-sm btn-primary"),
            shiny::hr(),
            shiny::selectInput("var_doc", "Variablen fuer Dokument", choices = character()),
            shiny::div(style = "display:flex; gap:.3rem;",
              shiny::textInput("var_key", NULL, placeholder = "Variable (z.B. Alter)"),
              shiny::textInput("var_val", NULL, placeholder = "Wert")),
            shiny::actionButton("var_add_btn", "Variable setzen", icon = fa("plus"), class = "btn-sm btn-secondary"),
            shiny::uiOutput("var_list"),
            shiny::hr(),
            # Segmente des gerade geoeffneten Dokuments neu einteilen.
            # Einzelne Segmente teilen/zusammenfuehren: im Text klicken
            # (Segment-Leiste) oder Text markieren -> "Als Segment".
            shiny::selectInput("seg_rule", "Segmente des offenen Dokuments",
                               choices = .segrule_choices(), selected = "speaker"),
            shiny::actionButton("seg_apply", "Neu einteilen", icon = fa("scissors"),
                                class = "btn-sm btn-secondary",
                                title = "Segmente nach der gew\u00e4hlten Regel neu einteilen (Codings bleiben erhalten, Strg+Z macht es r\u00fcckg\u00e4ngig)")
          )
        ),
        shiny::div(class = "panel codes", id = "panel-codes",
shiny::div(class = "panelhead", draggable = "true", fa("tags"), shiny::span(class = "hlabel", "Code System"), shiny::span(class = "toggler", `data-toggle` = "panel-codes", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody",
            shiny::uiOutput("code_tree"),
            shiny::hr(),
            shiny::textInput("new_code_label", "Neuer Code", placeholder = "Label"),
            shiny::selectInput("new_code_parent", "Parent", choices = c("(kein Parent)" = "")),
            colourpicker::colourInput("new_code_color", "Farbe", value = "#E69F00"),
            shiny::textInput("new_code_desc", "Beschreibung", placeholder = "optional"),
            shiny::actionButton("add_code_btn", "Code anlegen", icon = fa("plus"), class = "btn-sm btn-primary"),
            shiny::hr(),
            shiny::selectInput("ren_code_select", "Code waehlen", choices = character()),
            shiny::textInput("ren_code_label", "Umbenennen in", placeholder = "neues Label"),
            shiny::actionButton("rename_code_btn", "Umbenennen", class = "btn-sm btn-secondary"),
            shiny::actionButton("delete_code_btn", "Loeschen", icon = fa("trash"), class = "btn-sm btn-outline-danger")
          )
        ),
        shiny::div(class = "panel matrix", id = "panel-matrix",
          shiny::div(class = "panelhead", draggable = "true", fa("table-cells"), shiny::span(class = "hlabel", "Code-Matrix"),
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
                                 shiny::tags$button(`data-zoom` = "-0.1", title = "Schrift kleiner", "A-"),
                                 shiny::tags$button(`data-zoom` = "0.1", title = "Schrift groesser", "A+")),
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
              shiny::textInput("search_q", NULL, placeholder = "Im ganzen Projekt suchen ..."),
              shiny::actionButton("search_btn", "Suchen", icon = fa("magnifying-glass"), class = "btn-sm btn-secondary")),
            shiny::selectInput("var_filter", "Nur Dokumente mit Variable", choices = c("(alle)" = "")),
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
            # neue Memos: ein Button je Art, aktiv nur mit passendem Bezug
            shiny::uiOutput("memo_toolbar"),
            # Formular fuer ein neues Memo (erscheint nach Klick auf "+ ...")
            shiny::uiOutput("memo_new_form"),
            # Filter (Art), Suche, nur offenes Dokument
            shiny::uiOutput("memo_filters"),
            shiny::div(class = "memosearch",
              shiny::textInput("memo_search", NULL, placeholder = "Memos durchsuchen ..."),
              shiny::checkboxInput("memo_only_doc", "nur offenes Dokument", value = FALSE)),
            # die Memo-Karten
            shiny::uiOutput("memos_list")
          )
        ),
        shiny::div(class = "panel summary", id = "panel-summary",
          shiny::div(class = "panelhead", draggable = "true", fa("table-list"), shiny::span(class = "hlabel", "Summary Grid"),
                     shiny::span(class = "toggler", `data-toggle` = "panel-summary", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody",
            shiny::p(class = "jq-sub",
                     "Zelle anklicken = Segmente + Summary bearbeiten."),
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
  # Reaktiver Zustand der Sitzung:
  #   src       -- id des geoeffneten Dokuments
  #   sel       -- aktuelle Textauswahl list(start, end, text), 1-basiert,
  #                kommt aus jellyqda.js (input$selection) oder vom Seg-Badge
  #   clicked   -- id des angeklickten Codings (blaue Leiste)
  #   sel_code  -- im Code-Baum ausgewaehlter Code
  #   sel_memo  -- Textstellen-Memo, das im Text hervorgehoben wird
  #   memo_filter / memo_new / memo_focus -- Zustand des Memo-Panels
  #   tick      -- Zaehler; jede Aenderung an der DB ruft bump() auf, und alle
  #                Outputs, die rv$tick lesen, zeichnen sich dadurch neu
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

  code_choices <- function() {
    c <- qda_codes()
    if (nrow(c) == 0) return(c("(kein Parent)" = ""))
    out <- stats::setNames(as.character(c$id), c$label)
    c("(kein Parent)" = "", out)
  }
  shiny::observe({
    rv$tick
    shiny::updateSelectInput(session, "new_code_parent", choices = code_choices())
    shiny::updateSelectInput(session, "ren_code_select",
                             choices = stats::setNames(as.character(qda_codes()$id), qda_codes()$label))
  })

  # document tree (left top) ---------------------------------------------------
  output$doc_tree <- shiny::renderUI({
    rv$tick
    s <- qda_sources()
    if (nrow(s) == 0) return(shiny::tags$div(class = "jq-hint", "Noch keine Dokumente importiert."))
    ps <- qda_stats()$per_source
    with_memo <- unique(qda_memos(kind = "document")$source_id)
    rows <- vapply(seq_len(nrow(s)), function(i) {
      cls <- if (!is.null(rv$src) && rv$src == s$id[i]) "docrow sel" else "docrow"
      pct <- if (s$id[i] %in% ps$id) ps$pct_coded[match(s$id[i], ps$id)] else 0
      memo_icon <- if (s$id[i] %in% with_memo) {
        sprintf('<span class="memoicon" data-docmemo="%d" title="Dokument-Memo anzeigen"><i class="fa-solid fa-note-sticky"></i></span>',
                s$id[i])
      } else ""
      sprintf('<div class="%s" data-src="%d"><i class="fa-solid fa-file-lines"></i>
               <span>%s</span>%s<span class="fmt">%s - %d Seg.</span>
               <span class="pbar" title="%.1f %% codiert"><span style="width:%.1f%%"></span></span></div>',
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
    bump(); shiny::showNotification("Importiert (Text eingefroren, Original in originals/).", type = "message")
  })

  # document browser (center top) ----------------------------------------------
  output$doc_title <- shiny::renderText({
    rv$tick
    if (is.null(rv$src)) "Dokument-Browser" else .resolve_source(rv$src)$name
  })
  output$doc <- shiny::renderUI({
    rv$tick
    id <- rv$src
    if (is.null(id)) return(shiny::tags$div(class = "jq-hint", "Links ein Dokument auswaehlen ..."))
    shiny::HTML(.render_doc_html(id, sel_mid = rv$sel_memo))
  })
  # Textauswahl aus dem Browser (jellyqda.js, Abschnitt 2). NULL = Auswahl
  # aufgehoben -> Aktionsleiste verschwindet (daher ignoreNULL = FALSE).
  shiny::observeEvent(input$selection, {
    rv$sel <- input$selection
    if (!is.null(input$selection)) rv$caret <- NULL   # Markierung statt Cursor
  }, ignoreNULL = FALSE)

  # Aktionsleiste: erscheint, sobald rv$sel gesetzt ist. Ein Button je Code
  # (class "codebtn" -> jellyqda.js schickt input$assign_code).
  output$actionbar <- shiny::renderUI({
    rv$tick
    s <- rv$sel
    if (is.null(s)) return(NULL)
    codes <- qda_codes()
    btns <- if (nrow(codes) > 0) {
      paste(vapply(seq_len(nrow(codes)), function(i) {
        sprintf('<button class="codebtn" data-codeid="%d" style="background-color:%s" title="%s">%s</button>',
                codes$id[i], esc(codes$color[i]), esc(codes$path[i]), esc(codes$label[i]))
      }, character(1)), collapse = "")
    } else '<span class="jq-sub">Noch keine Codes angelegt (Code System links)</span>'
    shiny::div(class = "actionbar",
      shiny::span(class = "selinfo", sprintf("Markiert: Zeichen %d-%d", s$start, s$end)),
      shiny::HTML(btns),
      shiny::tags$button(class = "segdefbtn", `data-segact` = "define", "Als Segment",
                         title = "Markierten Text als eigenes Segment festlegen (Strg+Z macht es r\u00fcckg\u00e4ngig)"),
      shiny::tags$button(id = "memo_only_btn", "Memo speichern",
                         title = paste("Textstellen-Memo zur Markierung anlegen (Strg+M).",
                                       "Mit Text im Feld daneben: sofort speichern; ohne: Formular im Memo-Panel")),
      shiny::textInput("memo_field", label = NULL,
                       placeholder = "Memo oder Kommentar zum Coding (optional)")
    )
  })
  # Code-Button geklickt: die gemerkte Auswahl rv$sel mit diesem Code speichern.
  # Gespeichert wird genau rv$sel$start..end -- deshalb darf rv$sel vorher nicht
  # vom Segment-Klick ueberschrieben werden (siehe BUGFIX in jellyqda.js).
  shiny::observeEvent(input$assign_code, {
    shiny::req(rv$src, rv$sel)
    s <- rv$sel
    n <- nchar(.resolve_source(rv$src)$frozen_text, type = "chars")
    qda_code(rv$src, input$assign_code, start = s$start, end = min(s$end, n),
             memo = input$memo_field %||% "")
    rv$sel <- NULL
    bump()
    shiny::showNotification("Coding gespeichert (Audit-Trail aktualisiert).", type = "message")
  })

  # "Memo speichern" in der Aktionsleiste (oder Strg+M): Textstellen-Memo.
  # Steht schon Text im Feld -> sofort speichern; sonst das Formular im
  # Memo-Panel oeffnen (frueher wurde dann der markierte Text selbst als
  # Memo gespeichert, das Memo wiederholte also nur die Textstelle).
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
      shiny::showNotification("Textstellen-Memo gespeichert (Strg+Z macht es r\u00fcckg\u00e4ngig).",
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
    shiny::div(class = "clickedbar",
      shiny::span(class = "snippet",
        sprintf("Coding #%d - %s - %s - Zeichen %d-%d: '%s'%s",
                row$id, row$source, row$code, row$start, row$end,
                if (nchar(row$text) > 90) paste0(substr(row$text, 1, 90), "...") else row$text,
                if (nzchar(row$memo)) paste0("  |  Kommentar: ", row$memo) else "")),
      shiny::actionButton("del_clicked_coding", "Loeschen", icon = fontawesome::fa("trash"),
                          class = "btn-sm btn-outline-danger")
    )
  })
  shiny::observeEvent(input$del_clicked_coding, {
    shiny::req(rv$clicked)
    qda_coding_delete(rv$clicked)
    rv$clicked <- NULL; bump()
    shiny::showNotification("Coding geloescht (Audit-Trail).", type = "message")
  })
  shiny::observeEvent(input$del_coding, {
    qda_coding_delete(input$del_coding); bump()
    shiny::showNotification("Coding geloescht (Audit-Trail).", type = "message")
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
  shiny::observeEvent(input$sel_code, { rv$sel_code <- input$sel_code })
  output$code_tree <- shiny::renderUI({
    rv$tick
    codes <- qda_codes()
    if (nrow(codes) == 0) return(shiny::tags$div(class = "jq-hint", "Noch keine Codes."))
    # Codes mit Code-Memo bekommen ein Memo-Symbol (Klick = Memos anzeigen)
    with_memo <- unique(qda_memos(kind = "code")$code_id)
    rows <- vapply(seq_len(nrow(codes)), function(i) {
      cls <- if (!is.null(rv$sel_code) && rv$sel_code == codes$id[i]) "coderow sel" else "coderow"
      memo_icon <- if (codes$id[i] %in% with_memo) {
        sprintf('<span class="memoicon" data-codememo="%d" title="Code-Memo anzeigen"><i class="fa-solid fa-note-sticky"></i></span>',
                codes$id[i])
      } else ""
      sprintf('<div class="%s" draggable="true" data-selcode="%d" data-codeid="%d" title="Klicken = Segmente anzeigen; auf anderen Code ziehen = umh\u00e4ngen">
               <span class="swatch" style="background-color:%s"></span>
               <span class="codelabel" title="%s">%s</span>%s<span class="fmt">%d</span>
               <button class="mini" data-delcode="%d" title="Code l\u00f6schen (Strg+Z macht es r\u00fcckg\u00e4ngig)"><i class="fa-solid fa-trash"></i> L\u00f6schen</button></div>',
              cls, codes$id[i], codes$id[i], esc(codes$color[i]), esc(codes$path[i]), esc(codes$label[i]),
              memo_icon, codes$n_codings[i], codes$id[i])
    }, character(1))
    shiny::HTML(paste(rows, collapse = ""))
  })
  shiny::observeEvent(input$add_code_btn, {
    shiny::req(input$new_code_label)
    parent <- input$new_code_parent
    qda_code_add(input$new_code_label,
                 parent = if (is.null(parent) || parent == "") NULL else as.integer(parent),
                 color = input$new_code_color %||% "#E69F00",
                 description = input$new_code_desc %||% "")
    shiny::updateTextInput(session, "new_code_label", value = "")
    bump()
    shiny::showNotification("Code angelegt.", type = "message")
  })
  shiny::observeEvent(input$rename_code_btn, {
    shiny::req(input$ren_code_select, input$ren_code_label)
    qda_code_rename(as.integer(input$ren_code_select), input$ren_code_label)
    bump(); shiny::showNotification("Code umbenannt.", type = "message")
  })
  shiny::observeEvent(input$delete_code_btn, {
    shiny::req(input$ren_code_select)
    qda_code_delete(as.integer(input$ren_code_select))
    bump(); shiny::showNotification("Code (inkl. Unter-Codes/Codings) geloescht.", type = "warning")
  })
  shiny::observeEvent(input$del_code_id, {
    qda_code_delete(input$del_code_id)
    bump(); shiny::showNotification("Code geloescht.", type = "warning")
  })

  # retrieved segments (center bottom) -----------------------------------------
  output$seg_head <- shiny::renderUI({
    rv$tick
    if (!is.null(rv$sel_code)) {
      lab <- qda_codes()$label[qda_codes()$id == rv$sel_code]
      if (length(lab) == 0) lab <- "?"
      shiny::span(sprintf("Retrieved Segments: %s (%d)", lab, sum(qda_codings()$code_id == rv$sel_code)))
    } else {
      shiny::span(sprintf("All Codings (%d)", nrow(qda_codings())))
    }
  })
  output$seg_panel <- shiny::renderUI({
    rv$tick
    df <- if (!is.null(rv$sel_code)) {
      d <- qda_codings()
      d[d$code_id == rv$sel_code, , drop = FALSE]
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
    if (nrow(df) == 0) return(shiny::tags$div(class = "jq-hint", "Noch keine Codings."))
    rows <- vapply(seq_len(nrow(df)), function(i) {
      snippet <- if (nchar(df$text[i]) > 80) paste0(substr(df$text[i], 1, 80), "...") else df$text[i]
      sprintf('<div class="segrow" data-goto="%d" title="Im Dokument-Browser zeigen">
               <span class="snippet">#%d <b>%s</b> &rarr; <b>%s</b> (%d-%d) %s%s</span>
               <button class="mini" data-delcoding="%d"><i class="fa-solid fa-trash"></i> Del</button></div>',
              df$id[i], df$id[i], esc(df$source[i]), esc(df$code[i]), df$start[i], df$end[i],
              esc(snippet),
              if (nzchar(df$memo[i])) sprintf('<span class="memo">Memo: %s</span>', esc(df$memo[i])) else "",
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
    bump()
    shiny::showNotification(sprintf("Suche '%s': %d Treffer", q, length(hits)), type = "message")
  })
  output$search_results <- shiny::renderUI({
    rv$tick
    hits <- rv$search
    if (is.null(hits)) return(NULL)
    if (length(hits) == 0) return(shiny::tags$div(class = "jq-hint", "Keine Treffer."))
    rows <- vapply(hits, function(h) {
      nm <- .resolve_source(h$src)$name
      sprintf('<div class="segrow" data-gotopos data-src="%d" data-pos="%d" title="Im Dokument-Browser springen">
               <span class="snippet"><b>%s</b> (Pos %d): ...%s...</span></div>',
              h$src, h$pos, esc(nm), h$pos, esc(h$snippet))
    }, character(1))
    shiny::HTML(paste0('<div class="memogroup">Treffer (Klick = springen)</div>', paste(rows, collapse = "")))
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
                             choices = c("(alle)" = "", sort(unique(opts))),
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
    shiny::showNotification("Variable gesetzt.", type = "message")
  })
  shiny::observeEvent(input$del_var, {
    parts <- strsplit(input$del_var, "|", fixed = TRUE)[[1]]
    qda_source_del_var(as.integer(parts[1]), parts[2])
    bump()
  })
  output$var_list <- shiny::renderUI({
    rv$tick
    sid <- if (!is.null(input$var_doc)) as.integer(input$var_doc) else rv$src
    if (is.null(sid)) return(NULL)
    v <- qda_source_vars(sid)
    if (length(v) == 0) return(shiny::tags$div(class = "jq-hint", "Keine Variablen."))
    rows <- vapply(seq_along(v), function(i) {
      sprintf('<div class="segrow"><span class="snippet"><b>%s</b> = %s</span>
               <button class="mini" data-delvar="1" data-varsrc="%d" data-varkey="%s"><i class="fa-solid fa-trash"></i> Del</button></div>',
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
        shiny::showNotification(paste("Umhaengen nicht moeglich:", conditionMessage(e)), type = "warning")
        NULL
      })
    if (!is.null(res)) {
      bump()
      shiny::showNotification("Code verschoben (neuer Parent).", type = "message")
    }
  })

  # memos (right column) ---------------------------------------------------------
  # Vier Memo-Arten (memos.R) + Kommentare an Codings. Alle Aktionen kommen
  # als data-*-Klicks aus jellyqda.js (Abschnitt 13) und laufen ueber die
  # qda_memo_*()-Funktionen -> Audit-Trail + Undo.
  kind_label <- c(passage = "Textstelle", document = "Dokument", code = "Code",
                  project = "Projekt", comment = "Kommentar")
  kind_icon <- c(passage = "highlighter", document = "file-lines", code = "tag",
                 project = "book", comment = "comment")
  fmt_date <- function(x) {
    d <- tryCatch(as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), error = function(e) NA)
    ifelse(is.na(d), "", format(d, "%d.%m.%Y %H:%M", tz = ""))
  }
  short <- function(x, n = 80) ifelse(nchar(x) > n, paste0(substr(x, 1, n), "\u2026"), x)

  # alle Eintraege des Panels als eine Tabelle: Memos + Kommentare an Codings
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
        passage = sprintf("%s \u00b7 Seg %s \u00b7 \u201e%s\u201c", m$source[i],
                          seg_no(m$source_id[i], m$start[i]), short(m$passage[i], 60)),
        document = m$source[i] %||% "",
        code = paste("Code:", m$code[i]),
        project = "Projekt")
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
        text = cc$memo, ref = sprintf("%s \u00b7 %s \u00b7 \u201e%s\u201c", cc$source, cc$code, short(cc$text, 60)),
        source_id = cc$source_id, code_id = cc$code_id, start = cc$start, updated = NA_character_,
        stringsAsFactors = FALSE))
    }
    out
  }

  # Toolbar: "+ Textstelle" usw.; deaktiviert, wenn der Bezug fehlt
  output$memo_toolbar <- shiny::renderUI({
    rv$tick
    b <- function(kind, ok, why) {
      shiny::tags$button(class = "newmemo", `data-newmemo` = kind,
                         disabled = if (!ok) "disabled" else NULL,
                         title = if (ok) paste0("Neues ", kind_label[[kind]], "-Memo") else why,
                         fontawesome::fa(kind_icon[[kind]]), paste0("+ ", kind_label[[kind]]))
    }
    shiny::div(class = "memotoolbar",
      b("passage", !is.null(rv$sel), "Zuerst Text im Dokument markieren"),
      b("document", !is.null(rv$src), "Zuerst ein Dokument \u00f6ffnen"),
      b("code", !is.null(rv$sel_code), "Zuerst einen Code im Code System anklicken"),
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
        sprintf("%s \u00b7 \u201e%s\u201c", src$name, short(substring(src$frozen_text, nm$start, nm$end), 90))
      },
      document = .resolve_source(nm$source)$name,
      code = paste("Code:", qda_codes()$label[qda_codes()$id == nm$code]),
      project = "Projekt (ohne Bezug)")
    shiny::div(class = paste("memocard editing new kind-", nm$kind, sep = ""),
      shiny::div(class = "mc-head", shiny::span(class = "mc-kind", fontawesome::fa(kind_icon[[nm$kind]]),
                                                paste0("Neues ", kind_label[[nm$kind]], "-Memo"))),
      shiny::div(class = "mc-ref", ref),
      shiny::tags$input(id = "memo_new_title", type = "text", class = "form-control mc-titlein",
                        placeholder = if (nm$kind == "code") "Titel, z.B. Definition / Kodierregel" else "Titel (optional)"),
      shiny::tags$textarea(id = "memo_new_text", class = "form-control", rows = 4,
                           placeholder = "Memo-Text ..."),
      shiny::div(class = "mc-btns",
        shiny::tags$button(class = "mini ok", `data-memonew` = "save", fontawesome::fa("check"), "Speichern"),
        shiny::tags$button(class = "mini", `data-memonew` = "cancel", "Abbrechen")))
  })
  shiny::observeEvent(input$memo_new_save, {
    nm <- rv$memo_new
    shiny::req(nm)
    txt <- input$memo_new_save$text %||% ""
    ttl <- input$memo_new_save$title %||% ""
    if (!nzchar(trimws(txt)) && !nzchar(trimws(ttl))) {
      shiny::showNotification("Bitte Titel oder Text eingeben.", type = "warning"); return()
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
    shiny::showNotification(paste0(qda_history()$undo, " (Strg+Z macht es r\u00fcckg\u00e4ngig)"), type = "message")
  })
  shiny::observeEvent(input$memo_new_cancel, { rv$memo_new <- NULL })

  # Filter-Leiste mit Anzahl je Art
  shiny::observeEvent(input$memo_filter, { rv$memo_filter <- input$memo_filter })
  output$memo_filters <- shiny::renderUI({
    rv$tick
    e <- memo_entries()
    kinds <- c(all = "Alle", passage = "Textstelle", document = "Dokument", code = "Code",
               project = "Projekt", comment = "Kommentare")
    chips <- vapply(names(kinds), function(k) {
      n <- if (k == "all") nrow(e) else sum(e$kind == k)
      sprintf('<button class="memochip%s" data-memofilter="%s">%s <span class="n">%d</span></button>',
              if (identical(rv$memo_filter, k)) " active" else "", k, kinds[[k]], n)
    }, character(1))
    shiny::HTML(paste0('<div class="memochips">', paste(chips, collapse = ""), '</div>'))
  })
  memo_search <- shiny::debounce(shiny::reactive(input$memo_search %||% ""), 300)

  # die Memo-Karten
  output$memos_list <- shiny::renderUI({
    rv$tick
    e <- memo_entries()
    if (nrow(e) == 0) {
      return(shiny::tags$div(class = "jq-hint",
        "Noch keine Memos. Oben eine Art w\u00e4hlen (+ Textstelle, + Dokument, + Code, + Projekt) ",
        "oder Text markieren und in der Aktionsleiste 'Memo speichern'."))
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
    if (nrow(e) == 0) return(shiny::tags$div(class = "jq-hint", "Keine passenden Memos."))
    # Reihenfolge: zuletzt geaenderte zuerst; Kommentare/Textstellen eines
    # Dokuments in Textreihenfolge, wenn nur das offene Dokument gezeigt wird
    ord <- if (isTRUE(input$memo_only_doc)) order(e$start, na.last = TRUE) else
      order(e$updated, e$id, decreasing = TRUE, na.last = TRUE)
    e <- e[ord, , drop = FALSE]
    cards <- vapply(seq_len(nrow(e)), function(i) {
      k <- e$key[i]; kind <- e$kind[i]
      focus <- if (identical(rv$memo_focus, k)) " focus" else ""
      head <- sprintf('<div class="mc-head"><span class="mc-kind"><i class="fa-solid fa-%s"></i> %s</span><span class="mc-date">%s</span></div>',
                      kind_icon[[kind]], kind_label[[kind]], esc(fmt_date(e$updated[i])))
      ref <- sprintf('<div class="mc-ref" data-memojump="%s" title="Hinspringen">%s</div>', k, esc(e$ref[i]))
      if (identical(rv$edit_entry, k)) {
        title_in <- if (kind == "comment") "" else
          sprintf('<input type="text" class="form-control mc-titlein" id="memo_title_%s" value="%s" placeholder="Titel (optional)">',
                  k, esc(e$title[i], attribute = TRUE))
        sprintf('<div class="memocard editing kind-%s%s" data-memokey="%s">%s%s%s
                 <textarea id="memo_edit_%s" class="form-control" rows="4">%s</textarea>
                 <div class="mc-btns"><button class="mini ok" data-savememo="%s"><i class="fa-solid fa-check"></i> Speichern</button>
                 <button class="mini" data-canceledit="1">Abbrechen</button></div></div>',
                kind, focus, k, head, ref, title_in, k, esc(e$text[i]), k)
      } else {
        del <- if (kind == "comment") {
          sprintf('<button class="mini danger" data-delcomment="%d" title="Kommentar entfernen (das Coding bleibt)"><i class="fa-solid fa-trash"></i> Entfernen</button>', e$id[i])
        } else {
          sprintf('<button class="mini danger" data-delmemo="%d" title="Memo l\u00f6schen (Strg+Z macht es r\u00fcckg\u00e4ngig)"><i class="fa-solid fa-trash"></i> L\u00f6schen</button>', e$id[i])
        }
        sprintf('<div class="memocard kind-%s%s" data-memokey="%s">%s%s%s<div class="mc-text">%s</div>
                 <div class="mc-btns"><button class="mini" data-editmemo="%s"><i class="fa-solid fa-pen"></i> Bearbeiten</button>%s</div></div>',
                kind, focus, k, head,
                if (nzchar(e$title[i])) sprintf('<div class="mc-title">%s</div>', esc(e$title[i])) else "",
                ref, esc(e$text[i]), k, del)
      }
    }, character(1))
    shiny::HTML(paste(cards, collapse = ""))
  })

  shiny::observeEvent(input$edit_memo_entry, { rv$edit_entry <- input$edit_memo_entry })
  shiny::observeEvent(input$cancel_edit, { rv$edit_entry <- NULL; bump() })
  # Speichern: jellyqda.js schickt {key, text, title} direkt aus den Feldern
  # (nicht ueber die verzoegerten Shiny-Inputs, sonst fehlen evtl. die
  # zuletzt getippten Zeichen). Ein blosser key (aeltere Aufrufe/Tests)
  # liest die Inputs memo_edit_<key> / memo_title_<key>.
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
    shiny::showNotification(paste0(qda_history()$undo, " (Strg+Z macht es r\u00fcckg\u00e4ngig)"), type = "message")
  })
  shiny::observeEvent(input$del_memo, {
    qda_memo_delete(input$del_memo)
    if (identical(rv$sel_memo, input$del_memo)) rv$sel_memo <- NULL
    bump()
    shiny::showNotification(paste0(qda_history()$undo, " (Strg+Z macht es r\u00fcckg\u00e4ngig)"), type = "message")
  })
  shiny::observeEvent(input$del_comment, {
    qda_coding_set_memo(input$del_comment, "")
    bump()
    shiny::showNotification("Kommentar entfernt (Strg+Z macht es r\u00fcckg\u00e4ngig).", type = "message")
  })

  # Bezug einer Karte anklicken -> hinspringen
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
  # unterstrichene Textstelle im Dokument angeklickt -> Karte zeigen
  shiny::observeEvent(input$clicked_memo, {
    key <- paste0("memo_", input$clicked_memo)
    rv$sel_memo <- input$clicked_memo
    rv$memo_focus <- key
    rv$memo_filter <- "all"
    bump()
    session$sendCustomMessage("jellyqdaMemoFocus", list(key = key))
  })
  # Memo-Symbol im Code-Baum / in der Dokumentenliste
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
    sprintf("%d Quellen - %d Codes - %d Codings - %.1f %% codiert",
            st$n_sources, st$n_codes, st$n_codings, st$pct_coded)
  })
  output$saved_line <- shiny::renderText({
    rv$tick
    sprintf("Gespeichert: %s", rv$last_saved %||% "-")
  })
  # Rueckgaengig / Wiederholen ------------------------------------------------
  # Buttons in der Topbar oder Strg+Z / Strg+Y (jellyqda.js, Abschnitt 6).
  shiny::observeEvent(input$undo_btn, {
    res <- tryCatch(qda_undo(), error = function(e) {
      shiny::showNotification(paste("R\u00fcckg\u00e4ngig nicht m\u00f6glich:", conditionMessage(e)),
                              type = "warning")
      NULL
    })
    if (!is.null(res)) {
      if (res$undone == "nothing") {
        shiny::showNotification("Nichts mehr r\u00fcckg\u00e4ngig zu machen.", type = "message")
      } else {
        rv$sel <- NULL; rv$clicked <- NULL; rv$caret <- NULL
        bump()
        shiny::showNotification(paste("R\u00fcckg\u00e4ngig:", res$detail), type = "message")
      }
    }
  })
  shiny::observeEvent(input$redo_btn, {
    res <- tryCatch(qda_redo(), error = function(e) {
      shiny::showNotification(paste("Wiederholen nicht m\u00f6glich:", conditionMessage(e)),
                              type = "warning")
      NULL
    })
    if (!is.null(res)) {
      if (res$redone == "nothing") {
        shiny::showNotification("Nichts zu wiederholen.", type = "message")
      } else {
        rv$sel <- NULL; rv$clicked <- NULL; rv$caret <- NULL
        bump()
        shiny::showNotification(paste("Wiederholt:", res$detail), type = "message")
      }
    }
  })
  # nach jeder Aenderung: Tooltips + aktiv/inaktiv der beiden Buttons setzen
  shiny::observe({
    rv$tick
    h <- qda_history()
    session$sendCustomMessage("jellyqdaHistory", list(undo = h$undo, redo = h$redo))
  })
  # click on a segment badge -> select the whole segment (action bar appears).
  # jellyqda.js sendet input$seg_click nur bei einem echten Klick auf das
  # "Seg N"-Badge, nicht nach einer Maus-Auswahl im Text.
  shiny::observeEvent(input$seg_click, {
    shiny::req(rv$src)
    segs <- .segments_for(rv$src)
    i <- as.integer(input$seg_click)
    if (i < 1 || i > nrow(segs)) return()
    rv$caret <- NULL   # der Klick aufs Badge setzt auch einen Cursor -> verwerfen
    rv$sel <- list(start = segs$start[i], end = segs$end[i],
                   text = substring(.resolve_source(rv$src)$frozen_text, segs$start[i], segs$end[i]))
    bump()
  })
  # Segmente bearbeiten -------------------------------------------------------
  # Klick in den Text ohne Markierung -> jellyqda.js schickt die
  # Cursorposition (input$caret, 0-basiert = Anzahl Zeichen davor). Dann
  # erscheint die Segment-Leiste mit Teilen / Zusammenfuehren.
  shiny::observeEvent(input$caret, {
    rv$caret <- input$caret$pos
  })
  # Segment, in dem der Cursor steht (auch direkt hinter dem letzten Zeichen)
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
    if (!is.null(rv$sel)) return(NULL)        # bei Markierung: Aktionsleiste
    cs <- caret_segment()
    if (is.null(cs)) return(NULL)
    btn <- function(act, label, title, enabled = TRUE) {
      shiny::tags$button(class = "mini segact", `data-segact` = act, title = title,
                         disabled = if (!enabled) "disabled" else NULL, label)
    }
    shiny::div(class = "segbar",
      shiny::span(class = "seginfo", sprintf("Segment %d von %d (Zeichen %d-%d)",
                                             cs$i, cs$n, cs$start, cs$end)),
      btn("split", "Hier teilen", "Neues Segment ab der Cursorposition beginnen"),
      btn("prev", "\u2191 Mit vorherigem zusammenf\u00fchren",
          "Dieses Segment an das vorherige anh\u00e4ngen", cs$i > 1),
      btn("next", "\u2193 Mit n\u00e4chstem zusammenf\u00fchren",
          "Das n\u00e4chste Segment an dieses anh\u00e4ngen", cs$i < cs$n),
      shiny::tags$button(class = "mini segclose", `data-segact` = "close", title = "Schlie\u00dfen", "\u00d7")
    )
  })
  # Aktion aus Segment-Leiste oder Aktionsleiste ("Als Segment")
  shiny::observeEvent(input$seg_action, {
    shiny::req(rv$src)
    act <- input$seg_action$act
    if (identical(act, "close")) { rv$caret <- NULL; return() }
    cs <- caret_segment()
    res <- tryCatch({
      if (act %in% c("split", "prev", "next") && is.null(cs)) {
        stop("An der Cursorposition liegt kein Segment.", call. = FALSE)
      }
      if (act == "define" && is.null(rv$sel)) stop("Bitte zuerst Text markieren.", call. = FALSE)
      switch(act,
        split  = qda_segment_split(rv$src, at = rv$caret + 1L),
        prev   = qda_segment_merge(rv$src, cs$i - 1L),
        "next" = qda_segment_merge(rv$src, cs$i),
        define = qda_segment_define(rv$src, rv$sel$start, rv$sel$end),
        stop("Unbekannte Segment-Aktion.", call. = FALSE))
      TRUE
    }, error = function(e) {
      shiny::showNotification(conditionMessage(e), type = "warning"); FALSE
    })
    if (isTRUE(res)) {
      rv$caret <- NULL; rv$sel <- NULL
      bump()
      shiny::showNotification(paste0(qda_history()$undo, "  (Strg+Z macht es r\u00fcckg\u00e4ngig)"),
                              type = "message")
    }
  })
  # ganzes Dokument nach einer Regel neu einteilen (Dokumente-Panel)
  shiny::observeEvent(input$seg_apply, {
    if (is.null(rv$src)) {
      shiny::showNotification("Bitte zuerst ein Dokument \u00f6ffnen.", type = "warning")
      return()
    }
    qda_segments_set(rv$src, input$seg_rule %||% "speaker")
    rv$caret <- NULL; rv$sel <- NULL
    bump()
    shiny::showNotification(paste0(qda_history()$undo, "  (Strg+Z macht es r\u00fcckg\u00e4ngig)"),
                            type = "message")
  })

  # help modal: legend of icons + shortcuts
  shiny::observeEvent(input$help_btn, {
    shiny::showModal(shiny::modalDialog(
      title = "Hilfe: Symbole & Tastenkuerzel",
      shiny::tags$ul(
        shiny::tags$li(shiny::strong("Strg+1..9"), " - markierten Text dem n-ten Code der Aktionsleiste zuweisen"),
        shiny::tags$li(shiny::strong("Strg+M"), " - Textstellen-Memo zur Markierung (mit Text im Memo-Feld: sofort, sonst Formular im Memo-Panel)"),
        shiny::tags$li(shiny::strong("Memos"), " - vier Arten: Textstelle (unterstrichen), Dokument, Code (z.B. Definition, Kodierregel), Projekt; dazu Kommentare an Codings. Panel rechts: + Neues Memo, Filter, Suche; Bezug anklicken = hinspringen; Strg+Enter speichert"),
        shiny::tags$li(shiny::strong("Segmente"), " - in den Text klicken: Segment hier teilen / zusammenf\u00fchren; Text markieren: 'Als Segment'; Dokumente-Panel: ganzes Dokument neu einteilen (z.B. nach Sprecherwechsel)"),
        shiny::tags$li(shiny::strong("\u00dcberlappungen"), " - graue Stellen mit Zahl = mehrere Codings; Maus dar\u00fcber zeigt sie an, Klick heftet die Liste fest"),
        shiny::tags$li(shiny::strong("Strg+Z / Strg+Y"), " - letzte Aktion r\u00fcckg\u00e4ngig machen / wiederholen (auch Code l\u00f6schen, Variablen, Summaries, Segmente)"),
        shiny::tags$li(shiny::strong("Seg-Badge"), " anklicken - ganzen Absatz markieren"),
        shiny::tags$li(shiny::strong("Symbolleiste / Chevron"), " - jeweiliges Fenster (Panel) ein-/ausklappen"),
        shiny::tags$li(shiny::strong("Mond"), " - Dark Mode; ", shiny::strong("?"), " - diese Hilfe; ", shiny::strong("X"), " - App beenden (speichert + Backup)"),
        shiny::tags$li(shiny::strong("Codebaum"), " - Code auf einen anderen Code ziehen, um ihn umzuhaengen (Re-Parent)"),
        shiny::tags$li(shiny::strong("Dokumente-Panel"), " - Dateien per Drag & Drop importieren"),
        shiny::tags$li(shiny::strong("Doppel-Codierung"), " - derselbe Text mehrfach codiert: gestrichelter pinker Rahmen")
      ),
      easyClose = TRUE, footer = shiny::modalButton("Schliessen")
    ))
  })
  shiny::observeEvent(input$backup_btn, {
    z <- qda_backup(quiet = TRUE)
    bump(); shiny::showNotification(paste("Backup:", z), type = "message")
  })
  shiny::observeEvent(input$export_btn, {
    ex <- qda_export("all")
    bump(); shiny::showNotification(paste("Exportiert:", nrow(ex), "Dateien nach exports/"), type = "message")
  })

  # code matrix (Code Matrix Browser) -------------------------------------------
  output$matrix_panel <- shiny::renderUI({
    rv$tick
    codes <- qda_codes()
    sources <- qda_sources()
    if (nrow(codes) == 0 || nrow(sources) == 0) {
      return(shiny::tags$div(class = "jq-hint", "Codes und Dokumente noetig."))
    }
    cod <- DBI::dbGetQuery(qda_con(), "SELECT code_id, source_id, COUNT(*) AS n FROM codings GROUP BY code_id, source_id")
    cnt <- matrix(0L, nrow = nrow(codes), ncol = nrow(sources),
                  dimnames = list(as.character(codes$id), as.character(sources$id)))
    if (nrow(cod) > 0) cnt[cbind(as.character(cod$code_id), as.character(cod$source_id))] <- cod$n
    maxn <- max(cnt, 1L)
    esc2 <- htmltools::htmlEscape
    head <- paste0('<tr><th>Code \\ Dokument</th>',
                   paste0('<th>', esc2(sources$name), '</th>', collapse = ""), "<th>SUM</th></tr>")
    body_rows <- vapply(seq_len(nrow(codes)), function(i) {
      cells <- vapply(seq_len(nrow(sources)), function(j) {
        n <- cnt[i, j]
        # Heatmap: Deckkraft 0.12..0.67 -- kraeftiger wuerde die Zahl in der
        # Zelle (hell wie dunkel) unter den WCAG-Kontrast von 4.5:1 druecken
        bg <- if (n > 0) sprintf(' style="background:rgba(44,111,187,%s)"', round(0.12 + 0.55 * n / maxn, 2)) else ""
        sprintf('<td class="mxcell" data-mxcode="%d" data-mxsrc="%d"%s>%s</td>',
                codes$id[i], sources$id[j], bg, if (n > 0) n else "")
      }, character(1))
      sprintf('<tr><td class="rowlab" data-selcode="%d"><span class="swatch" style="background-color:%s"></span> %s</td>%s<td><b>%d</b></td></tr>',
              codes$id[i], esc2(codes$color[i]), esc2(codes$label[i]), paste0(cells, collapse = ""), sum(cnt[i, ]))
    }, character(1))
    colsums <- vapply(seq_len(nrow(sources)), function(j) sum(cnt[, j]), integer(1))
    foot <- sprintf('<tr class="sumrow"><td>SUM</td>%s<td>%d</td></tr>',
                    paste0("<td>", colsums, "</td>", collapse = ""), sum(cnt))
    shiny::HTML(paste0('<table class="mx">', head, paste0(body_rows, collapse = ""), foot, "</table>"))
  })
  shiny::observeEvent(input$mx_cell, {
    rv$sel_code <- input$mx_cell$code
    rv$src <- input$mx_cell$source
    rv$sel <- NULL
    bump()
    shiny::showNotification("Zelle gewaehlt: Code im Browser geoeffnet.", type = "message")
  })

  # summary grid -----------------------------------------------------------------
  output$sum_matrix <- shiny::renderUI({
    rv$tick
    codes <- qda_codes()
    sources <- qda_sources()
    if (nrow(codes) == 0 || nrow(sources) == 0) {
      return(shiny::tags$div(class = "jq-hint", "Codes und Dokumente noetig."))
    }
    cod <- DBI::dbGetQuery(qda_con(), "SELECT code_id, source_id, COUNT(*) AS n FROM codings GROUP BY code_id, source_id")
    has_sum <- qda_summaries()
    has_keys <- if (nrow(has_sum)) paste(has_sum$code_id, has_sum$source_id, sep = "_") else character()
    esc2 <- htmltools::htmlEscape
    head <- paste0('<tr><th>Code \\ Dokument</th>',
                   paste0("<th>", esc2(substr(sources$name, 1, 12)), "</th>", collapse = ""), "</tr>")
    body_rows <- vapply(seq_len(nrow(codes)), function(i) {
      cells <- vapply(seq_len(nrow(sources)), function(j) {
        n <- if (nrow(cod)) sum(cod$n[cod$code_id == codes$id[i] & cod$source_id == sources$id[j]]) else 0L
        cls <- if (paste(codes$id[i], sources$id[j], sep = "_") %in% has_keys) "sumcell has" else "sumcell"
        sprintf('<td class="%s" data-sumcode="%d" data-sumsrc="%d" title="%d Codings">%s</td>',
                cls, codes$id[i], sources$id[j], n, if (n > 0) n else "")
      }, character(1))
      sprintf('<tr><td class="rowlab" data-selcode="%d"><span class="swatch" style="background-color:%s"></span> %s</td>%s</tr>',
              codes$id[i], esc2(codes$color[i]), esc2(codes$label[i]), paste0(cells, collapse = ""))
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
      return(shiny::tags$div(class = "jq-hint", "Zelle in der Summary-Grid anklicken ..."))
    }
    codes <- qda_codes(); sources <- qda_sources()
    clab <- codes$label[codes$id == sc$code]; slab <- sources$name[sources$id == sc$source]
    segs <- qda_codings()
    segs <- segs[segs$code_id == sc$code & segs$source_id == sc$source, , drop = FALSE]
    seg_rows <- if (nrow(segs) == 0) '<div class="jq-hint">keine Segmente</div>' else {
      paste(vapply(seq_len(nrow(segs)), function(i) {
        snippet <- if (nchar(segs$text[i]) > 70) paste0(substr(segs$text[i], 1, 70), "...") else segs$text[i]
        sprintf('<div class="segrow" data-goto="%d"><span class="snippet">#%d (%d-%d) %s</span></div>',
                segs$id[i], segs$id[i], segs$start[i], segs$end[i], esc(snippet))
      }, character(1)), collapse = "")
    }
    shiny::div(
      shiny::tags$b(sprintf("Zelle: %s x %s (%d Segmente)", clab, slab, nrow(segs))),
      shiny::div(class = "sumdetail-segs", shiny::HTML(seg_rows)),
      shiny::textAreaInput("sum_text", "Summary (wird gespeichert)", rows = 3, value = rv$sum_text_val %||% ""),
      shiny::actionButton("sum_save_btn", "Summary speichern", icon = fontawesome::fa("floppy-disk"), class = "btn-sm btn-primary")
    )
  })
  shiny::observeEvent(input$sum_save_btn, {
    shiny::req(rv$sum_cell)
    txt <- input$sum_text %||% ""
    qda_summary_set(rv$sum_cell$code, rv$sum_cell$source, txt)
    rv$sum_text_val <- txt
    bump()
    shiny::showNotification("Summary gespeichert (Audit-Trail).", type = "message")
  })

  # flexible layout -------------------------------------------------------------
  shiny::observeEvent(input$layout_reset, {
    session$sendCustomMessage("jellyqdaReset", 1)
  })
  # close app: save work (export + backup), then stop ---------------------------
  shiny::observeEvent(input$close_app, {
    qda_export("all")
    z <- qda_backup(quiet = TRUE)
    shiny::showNotification(paste("Gespeichert. Export + Backup:", z), type = "message", duration = 10)
    shiny::stopApp()
  })
}


