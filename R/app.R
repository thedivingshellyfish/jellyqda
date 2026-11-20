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
#' @param open Logical; open the app in the RStudio Viewer / browser.
#' @return Invisibly `NULL` (after the app is stopped).
#' @export
#' @examples
#' \dontrun{
#' qda_open("meinarbeit.jellyqda")
#' qda_app()   # Esc stops the app
#' }
qda_app <- function(host = "127.0.0.1", port = NULL, open = TRUE) {
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
      if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
        rstudioapi::viewer(url)
      } else {
        utils::browseURL(url)
      }
    }
  }
  shiny::runApp(app, host = host, port = port,
                launch.browser = if (isTRUE(open)) launcher else FALSE)
  invisible(NULL)
}

# --- segment splitting that preserves the exact separator text --------------
# Returns segments plus the raw separators between them, so that
# paste0(seg1, sep1, seg2, sep2, ...) == original text. This guarantees the
# browser-side offset mapping (textContent of #doc) matches frozen_text 1:1.
#' @noRd
.split_segments_full <- function(text) {
  n <- nchar(text, type = "chars")
  none <- list(segs = tibble::tibble(segment = integer(), start = integer(), end = integer()),
               seps = character())
  if (is.na(n) || n == 0) return(none)
  m <- gregexpr("\n[ \t]*\n+", text, perl = TRUE)[[1]]
  if (m[1] == -1L) {
    return(list(segs = tibble::tibble(segment = 1L, start = 1L, end = n), seps = character()))
  }
  ml <- attr(m, "match.length")
  starts <- c(1L, as.integer(m + ml))
  ends <- c(as.integer(m - 1L), n)
  k <- length(starts)
  seps <- substring(text, m, m + ml - 1L)
  keep <- starts <= ends & trimws(substring(text, starts, ends)) != ""
  out_start <- integer(); out_end <- integer(); out_sep <- character(); pending <- ""
  for (i in seq_len(k)) {
    raw <- if (starts[i] <= ends[i]) substring(text, starts[i], ends[i]) else ""
    if (keep[i]) {
      if (length(out_start) > 0) out_sep[length(out_start)] <- pending
      out_start <- c(out_start, starts[i]); out_end <- c(out_end, ends[i])
      pending <- ""
    } else {
      pending <- paste0(pending, raw)
    }
    if (i < k) pending <- paste0(pending, seps[i])
  }
  list(segs = tibble::tibble(segment = seq_along(out_start), start = out_start, end = out_end),
       seps = out_sep)
}

# --- document HTML for the browser ------------------------------------------
# #doc contains exactly the frozen text as DOM text nodes (segments as
# .segtext divs, separators as plain text between them, codings as <mark>).
# Segment badges are CSS ::before pseudo-elements (not DOM text), so they do
# not disturb offset mapping.
#' @noRd
.render_doc_html <- function(source_id) {
  con <- qda_con()
  src <- .resolve_source(source_id)
  text <- src$frozen_text
  parts <- .split_segments_full(text)
  segs <- parts$segs; seps <- parts$seps
  cods <- DBI::dbGetQuery(con, "
    SELECT c.id, c.start, c.end, k.label, k.color
    FROM codings c JOIN codes k ON k.id = c.code_id
    WHERE c.source_id = ? ORDER BY c.start", params = list(src$id))
  esc <- htmltools::htmlEscape
  divs <- character()
  for (i in seq_len(nrow(segs))) {
    st <- segs$start[i]; en <- segs$end[i]
    seg_txt <- substring(text, st, en)
    ov <- cods[cods$start <= en & cods$end >= st, , drop = FALSE]
    inner <- character(); pos <- st
    if (nrow(ov) > 0) {
      for (j in seq_len(nrow(ov))) {
        cs <- max(ov$start[j], st); ce <- min(ov$end[j], en)
        if (cs > pos) inner <- c(inner, esc(substring(seg_txt, pos - st + 1, cs - st)))
        # reserved "Memo" code -> underline mark (no background), so memo
        # passages are visually distinct from real codings
        if (ov$label[j] == "Memo") {
          inner <- c(inner, sprintf('<mark class="memomark" data-cid="%d" title="Memo">%s</mark>',
                                    ov$id[j], esc(substring(seg_txt, cs - st + 1, ce - st + 1))))
        } else {
          inner <- c(inner, sprintf('<mark data-cid="%d" style="background-color:%s" title="%s">%s</mark>',
                                    ov$id[j], esc(ov$color[j]), esc(ov$label[j]),
                                    esc(substring(seg_txt, cs - st + 1, ce - st + 1))))
        }
        pos <- ce + 1
      }
    }
    if (pos <= en) inner <- c(inner, esc(substring(seg_txt, pos - st + 1, en - st + 1)))
    divs[i] <- sprintf('<div class="segtext" data-seg="%d">%s</div>', i, paste(inner, collapse = ""))
  }
  sep_nodes <- vapply(c(seps, ""), esc, character(1))
  body <- paste0(divs, sep_nodes, collapse = "")
  paste0('<div id="doc">', body, '</div>')
}

# --- custom JS: selection -> character offsets, delegated button clicks ------
#' @noRd
.jellyqda_js <- function() {
  shiny::tags$script(shiny::HTML("
    // absolute 0-based char offset of (node, offset) within #doc
    function absOffset(doc, node, offset) {
      try {
        var r = document.createRange();
        r.selectNodeContents(doc);
        r.setEnd(node, offset);
        return r.toString().length;
      } catch (e) { return null; }
    }
    $(document).on('mouseup', function(e) {
      var doc = document.getElementById('doc');
      if (!doc || !doc.contains(e.target)) return;
      var sel = window.getSelection();
      if (!sel || sel.isCollapsed) { Shiny.setInputValue('selection', null); return; }
      var a = absOffset(doc, sel.anchorNode, sel.anchorOffset);
      var f = absOffset(doc, sel.focusNode, sel.focusOffset);
      if (a === null || f === null) return;
      var s0 = Math.min(a, f), e0 = Math.max(a, f);
      Shiny.setInputValue('selection',
        {start: s0 + 1, end: e0, text: sel.toString()}, {priority: 'event'});
    });
    $(document).on('click', '[data-src]', function() {
      Shiny.setInputValue('open_source', parseInt($(this).attr('data-src')), {priority: 'event'});
    });
    $(document).on('click', '[data-selcode]', function() {
      Shiny.setInputValue('sel_code', parseInt($(this).attr('data-selcode')), {priority: 'event'});
    });
    $(document).on('click', '.codebtn', function() {
      Shiny.setInputValue('assign_code', parseInt($(this).attr('data-codeid')), {priority: 'event'});
    });
    $(document).on('click', '#memo_only_btn', function() {
      Shiny.setInputValue('add_memo_only', Date.now(), {priority: 'event'});
    });
    $(document).on('click', '[data-delcode]', function(e) {
      e.stopPropagation();
      Shiny.setInputValue('del_code_id', parseInt($(this).attr('data-delcode')), {priority: 'event'});
    });
    $(document).on('click', '[data-delcoding]', function(e) {
      e.stopPropagation();
      Shiny.setInputValue('del_coding', parseInt($(this).attr('data-delcoding')), {priority: 'event'});
    });
    $(document).on('click', '[data-delmemo]', function(e) {
      e.stopPropagation();
      Shiny.setInputValue('del_memo', parseInt($(this).attr('data-delmemo')), {priority: 'event'});
    });
    $(document).on('click', '[data-goto]', function(e) {
      Shiny.setInputValue('goto_coding', parseInt($(this).attr('data-goto')), {priority: 'event'});
    });
    $(document).on('click', '#doc mark', function(e) {
      e.stopPropagation();
      Shiny.setInputValue('clicked_coding', parseInt($(this).attr('data-cid')), {priority: 'event'});
    });
    // server asks us to scroll to a coding inside the freshly rendered document
    Shiny.addCustomMessageHandler('jellyqdaScroll', function(msg) {
      setTimeout(function() {
        var m = document.querySelector('#doc mark[data-cid=\"' + msg.cid + '\"]');
        if (m) {
          m.scrollIntoView({behavior: 'smooth', block: 'center'});
          m.style.outline = '3px solid #2c6fbb';
          setTimeout(function() { m.style.outline = ''; }, 2500);
        }
      }, 250);
    });
  "))
}

# --- UI: four-pane layout (MAXQDA workflow logic, jellyqda look) -------------
#' @noRd
.jellyqda_ui <- function() {
  fa <- fontawesome::fa
  bslib::page_fluid(
    theme = bslib::bs_theme(version = 5, primary = "#2c6fbb", font_scale = 0.95),
    shiny::tags$head(
      .jellyqda_js(),
      shiny::div(style = "display:none", fa("folder-tree"), fa("tags"), fa("highlighter"),
                 fa("note-sticky"), fa("trash"), fa("floppy-disk"), fa("file-export"),
                 fa("plus"), fa("file-lines")),
      shiny::tags$style(shiny::HTML("
        body { background:#f4f6f8; }
        .topbar { display:flex; gap:.6rem; align-items:center; background:#fff;
                  padding:.5rem .9rem; border-radius:.6rem; margin-bottom:.6rem;
                  box-shadow:0 1px 3px rgba(0,0,0,.08); flex-wrap:wrap; }
        .topbar .stats { font-weight:600; color:#2c6fbb; margin-right:auto; }
        #memo_field { width:16rem; margin-bottom:0; }
        .appgrid { display:grid; gap:.6rem; height:calc(100vh - 118px);
                   grid-template-columns:300px minmax(0,1fr) 300px;
                   grid-template-rows:minmax(0,3fr) minmax(0,2fr); }
        .pane { display:flex; flex-direction:column; min-height:0; min-width:0; }
        .pane.left, .pane.right { grid-row:1 / 3; }
        .panel { background:#fff; border-radius:.6rem; box-shadow:0 1px 3px rgba(0,0,0,.08);
                 display:flex; flex-direction:column; min-height:0; flex:1; margin-bottom:.6rem; }
        .panel:last-child { margin-bottom:0; }
        .panelhead { padding:.4rem .7rem; border-bottom:1px solid #e3e8ee; font-weight:700;
                     display:flex; gap:.45rem; align-items:center; color:#2c6fbb; flex:none; }
        .panelbody { padding:.5rem .7rem; overflow:auto; flex:1; min-height:0; }
        .browser .panelbody { display:flex; flex-direction:column; overflow:hidden; }
        .docarea { overflow:auto; flex:1; min-height:0; padding:.4rem .2rem; }
        #doc { font-family:Georgia,'Times New Roman',serif; font-size:1.02rem; line-height:1.65;
               white-space:pre-wrap; word-break:break-word; }
        .segtext { position:relative; padding-left:4.6em; margin-bottom:.15em; }
        .segtext::before { content:'Seg ' attr(data-seg); position:absolute; left:0; top:.2em;
                           font-family:monospace; font-size:.72rem; background:#eef1f4;
                           border:1px solid #d4dae0; border-radius:.35rem; padding:.1em .4em; color:#5a6672; }
        #doc mark { padding:0 .12em; border-radius:.25em; cursor:pointer; }
        #doc mark.memomark { background:transparent !important; border-bottom:3px solid #b58900;
                             border-radius:0; }
        .actionbar { flex:none; display:flex; gap:.4rem; align-items:center; background:#fff8e1;
                     border:1px solid #e0c96a; padding:.45rem .7rem; border-radius:.5rem;
                     margin-bottom:.5rem; flex-wrap:wrap; }
        .actionbar .selinfo { font-family:monospace; font-size:.85rem; color:#7a6414; margin-right:.4rem; }
        .codebtn { border:none; color:#1a1a1a; border-radius:.4rem; padding:.3rem .6rem;
                   font-size:.85rem; font-weight:600; cursor:pointer; box-shadow:0 1px 2px rgba(0,0,0,.2); }
        .codebtn:hover { filter:brightness(1.12); }
        #memo_only_btn { border:1px solid #b58900; background:#fff; border-radius:.4rem;
                         padding:.3rem .6rem; font-size:.85rem; cursor:pointer; }
        .clickedbar { flex:none; display:flex; gap:.6rem; align-items:center; background:#eef4fb;
                      border:1px solid #b9d2ec; border-radius:.5rem; padding:.4rem .7rem; margin-bottom:.5rem; }
        .coderow, .docrow, .segrow, .memorow { display:flex; gap:.45rem; align-items:center;
          background:#fff; border:1px solid #e3e8ee; border-radius:.45rem; padding:.35rem .55rem; margin-bottom:.35rem; }
        .coderow, .docrow, .segrow { cursor:pointer; }
        .coderow:hover, .docrow:hover, .segrow:hover { background:#eef4fb; }
        .coderow.sel { border-color:#2c6fbb; background:#eef4fb; }
        .swatch { width:1rem; height:1rem; border-radius:.3rem; flex:none; border:1px solid rgba(0,0,0,.25); }
        .codelabel { font-weight:600; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
        .mini { margin-left:auto; border:1px solid #d6dbe1; background:#fff; border-radius:.35rem;
                padding:.1rem .45rem; cursor:pointer; color:#b03a2e; flex:none; }
        .docrow .fmt, .coderow .fmt { margin-left:auto; font-size:.75rem; color:#6b7683; flex:none; }
        .segrow .snippet, .memorow .snippet, .snippet { font-size:.85rem; color:#333; }
        .segrow .memo, .memorow .memo { display:block; font-size:.78rem; color:#7a6414; font-style:italic; }
        .memorow { display:block; white-space:pre-wrap; }
        .placeholder { color:#8a94a0; font-style:italic; padding:1rem; text-align:center; }
        .memodetail { background:#fff8e1; border:1px solid #e0c96a; border-radius:.5rem;
                     padding:.5rem .7rem; margin-bottom:.5rem; font-size:.9rem; white-space:pre-wrap; }
        .memodetail .who { font-size:.75rem; color:#7a6414; font-weight:700; display:block; margin-bottom:.2rem; }
      "))
    ),
    shiny::div(class = "topbar",
      shiny::span(class = "stats", shiny::textOutput("stats_line", inline = TRUE)),
      shiny::textInput("memo_field", label = NULL, placeholder = "Memo (optional)"),
      shiny::actionButton("backup_btn", "Backup", icon = fa("floppy-disk"), class = "btn-sm btn-outline-secondary"),
      shiny::actionButton("export_btn", "Export", icon = fa("file-export"), class = "btn-sm btn-outline-secondary")
    ),
    shiny::div(class = "appgrid",
      # left column: document tree (top) + code system (bottom)
      shiny::div(class = "pane left",
        shiny::div(class = "panel docs",
          shiny::div(class = "panelhead", fa("folder-tree"), shiny::span("Dokumente")),
          shiny::div(class = "panelbody",
            shiny::uiOutput("doc_tree"),
            shiny::hr(),
            shiny::fileInput("import_files", NULL, multiple = TRUE,
                             accept = c(".txt", ".md", ".docx", ".pdf"), buttonLabel = "Dateien..."),
            shiny::actionButton("import_btn", "Importieren", icon = fa("plus"), class = "btn-sm btn-primary")
          )
        ),
        shiny::div(class = "panel codes",
          shiny::div(class = "panelhead", fa("tags"), shiny::span("Code System")),
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
        )
      ),
      # center: document browser (top) + retrieved segments (bottom)
      shiny::div(class = "pane center",
        shiny::div(class = "panel browser",
          shiny::div(class = "panelhead", fa("file-lines"), shiny::textOutput("doc_title", inline = TRUE)),
          shiny::div(class = "panelbody",
            shiny::uiOutput("clicked_bar"),
            shiny::uiOutput("actionbar"),
            shiny::div(class = "docarea", shiny::uiOutput("doc"))
          )
        ),
        shiny::div(class = "panel segs",
          shiny::div(class = "panelhead", fa("highlighter"), shiny::uiOutput("seg_head", inline = TRUE)),
          shiny::div(class = "panelbody", shiny::uiOutput("seg_panel"))
        )
      ),
      # right column: memos
      shiny::div(class = "pane right",
        shiny::div(class = "panel memos",
          shiny::div(class = "panelhead", fa("note-sticky"), shiny::span("Memos")),
          shiny::div(class = "panelbody",
            shiny::uiOutput("memo_detail"),
            shiny::textAreaInput("memo_text", "Neues Memo (freier Text)", rows = 3,
                                 placeholder = "z. B. Gedanken zum Leitfaden, Auffaelligkeiten ..."),
            shiny::actionButton("memo_save_btn", "Memo speichern", icon = fa("floppy-disk"),
                                class = "btn-sm btn-primary"),
            shiny::hr(),
            shiny::uiOutput("memos_list")
          )
        )
      )
    )
  )
}

# --- server -------------------------------------------------------------------
#' @noRd
.jellyqda_server <- function(input, output, session) {
  rv <- shiny::reactiveValues(src = NULL, sel = NULL, clicked = NULL, sel_code = NULL, tick = 0)
  bump <- function() rv$tick <- shiny::isolate(rv$tick) + 1
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
    if (nrow(s) == 0) return(shiny::tags$div(class = "placeholder", "Noch keine Dokumente importiert."))
    rows <- vapply(seq_len(nrow(s)), function(i) {
      cls <- if (!is.null(rv$src) && rv$src == s$id[i]) "docrow sel" else "docrow"
      sprintf('<div class="%s" data-src="%d"><i class="fa-solid fa-file-lines"></i>
               <span>%s</span><span class="fmt">%s - %d Seg.</span></div>',
              cls, s$id[i], esc(s$name[i]), esc(s$format[i]), s$segments[i])
    }, character(1))
    shiny::HTML(paste(rows, collapse = ""))
  })
  shiny::observeEvent(input$open_source, {
    rv$src <- input$open_source; rv$sel <- NULL; rv$clicked <- NULL
  })
  shiny::observeEvent(input$import_btn, {
    shiny::req(input$import_files)
    qda_import(input$import_files$datapath)
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
    if (is.null(id)) return(shiny::tags$div(class = "placeholder", "Links ein Dokument auswaehlen ..."))
    shiny::HTML(.render_doc_html(id))
  })
  shiny::observeEvent(input$selection, {
    rv$sel <- input$selection
  }, ignoreNULL = FALSE)

  output$actionbar <- shiny::renderUI({
    rv$tick
    s <- rv$sel
    if (is.null(s)) return(NULL)
    codes <- qda_codes()
    codes <- codes[codes$label != "Memo", , drop = FALSE]  # reserved code: not assignable
    btns <- if (nrow(codes) > 0) {
      paste(vapply(seq_len(nrow(codes)), function(i) {
        sprintf('<button class="codebtn" data-codeid="%d" style="background-color:%s" title="%s">%s</button>',
                codes$id[i], esc(codes$color[i]), esc(codes$path[i]), esc(codes$label[i]))
      }, character(1)), collapse = "")
    } else '<span style="color:#8a94a0">Noch keine Codes angelegt (Code System links)</span>'
    shiny::div(class = "actionbar",
      shiny::span(class = "selinfo", sprintf("Markiert: Zeichen %d-%d", s$start, s$end)),
      shiny::HTML(btns),
      shiny::tags$button(id = "memo_only_btn", "Nur Memo")
    )
  })
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

  # reserved code for memo passages (rendered as underline, not background)
  memo_code_id <- function() {
    con <- qda_con()
    row <- DBI::dbGetQuery(con, "SELECT id FROM codes WHERE label = 'Memo' AND IFNULL(parent_id, 0) = 0")
    if (nrow(row) > 0) return(row$id[1])
    qda_code_add("Memo", color = "#999999",
                 description = "reserviert fuer Memo-Markierungen (Unterstreichung)")
    DBI::dbGetQuery(con, "SELECT id FROM codes WHERE label = 'Memo' AND IFNULL(parent_id, 0) = 0")$id[1]
  }
  shiny::observeEvent(input$add_memo_only, {
    shiny::req(rv$src, rv$sel)
    s <- rv$sel
    frozen <- .resolve_source(rv$src)$frozen_text
    n <- nchar(frozen, type = "chars")
    end <- min(s$end, n)
    txt <- substring(frozen, s$start, end)
    memo_txt <- input$memo_field %||% ""
    if (!nzchar(memo_txt)) memo_txt <- txt
    # store as coding with the reserved Memo code -> underlined in the browser
    qda_code(rv$src, memo_code_id(), start = s$start, end = end, memo = memo_txt)
    rv$sel <- NULL
    bump()
    shiny::showNotification("Memo-Markierung gespeichert (Absatz unterstrichen).", type = "message")
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
                if (nzchar(row$memo)) paste0("  |  Memo: ", row$memo) else "")),
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
    if (nrow(codes) == 0) return(shiny::tags$div(class = "placeholder", "Noch keine Codes."))
    rows <- vapply(seq_len(nrow(codes)), function(i) {
      cls <- if (!is.null(rv$sel_code) && rv$sel_code == codes$id[i]) "coderow sel" else "coderow"
      sprintf('<div class="%s" data-selcode="%d" title="Klicken = Segmente abajo anzeigen">
               <span class="swatch" style="background-color:%s"></span>
               <span class="codelabel" title="%s">%s</span><span class="fmt">%d</span>
               <button class="mini" data-delcode="%d" title="Code loeschen"><i class="fa-solid fa-trash"></i></button></div>',
              cls, codes$id[i], esc(codes$color[i]), esc(codes$path[i]), esc(codes$label[i]),
              codes$n_codings[i], codes$id[i])
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
      shiny::span(sprintf("Alle Codings (%d) - Code links anklicken fuer seine Segmente",
                          nrow(qda_codings())))
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
    if (nrow(df) == 0) return(shiny::tags$div(class = "placeholder", "Noch keine Codings."))
    rows <- vapply(seq_len(nrow(df)), function(i) {
      snippet <- if (nchar(df$text[i]) > 80) paste0(substr(df$text[i], 1, 80), "...") else df$text[i]
      sprintf('<div class="segrow" data-goto="%d" title="Im Dokument-Browser zeigen">
               <span class="snippet">#%d <b>%s</b> &rarr; <b>%s</b> (%d-%d) %s%s</span>
               <button class="mini" data-delcoding="%d"><i class="fa-solid fa-trash"></i></button></div>',
              df$id[i], df$id[i], esc(df$source[i]), esc(df$code[i]), df$start[i], df$end[i],
              esc(snippet),
              if (nzchar(df$memo[i])) sprintf('<span class="memo">Memo: %s</span>', esc(df$memo[i])) else "",
              df$id[i])
    }, character(1))
    shiny::HTML(paste(rows, collapse = ""))
  })

  # memos (right column) ---------------------------------------------------------
  output$memo_detail <- shiny::renderUI({
    rv$tick
    cid <- rv$clicked
    if (is.null(cid)) {
      return(shiny::tags$div(class = "memodetail",
        shiny::tags$span(class = "who", "Memo"),
        "Text markieren oder ein Coding anklicken, um sein Memo hier zu sehen."))
    }
    df <- qda_codings()
    row <- df[df$id == cid, , drop = FALSE]
    if (nrow(row) == 0) return(NULL)
    shiny::tags$div(class = "memodetail",
      shiny::tags$span(class = "who", sprintf("Memo zu Coding #%d (%s / %s)", row$id, row$source, row$code)),
      if (nzchar(row$memo)) row$memo else shiny::tags$em("(kein Memo)"))
  })
  shiny::observeEvent(input$memo_save_btn, {
    txt <- input$memo_text
    shiny::req(txt)
    if (!nzchar(trimws(txt))) return()
    qda_memo_add(txt)
    shiny::updateTextAreaInput(session, "memo_text", value = "")
    bump()
    shiny::showNotification("Memo gespeichert (Audit-Trail).", type = "message")
  })
  output$memos_list <- shiny::renderUI({
    rv$tick
    m <- qda_memos()
    if (nrow(m) == 0) return(shiny::tags$div(class = "placeholder", "Noch keine freien Memos."))
    rows <- vapply(seq_len(nrow(m)), function(i) {
      sprintf('<div class="memorow"><span class="snippet">#%d - %s - %s</span>
               <button class="mini" data-delmemo="%d" title="Memo loeschen"><i class="fa-solid fa-trash"></i></button></div>',
              m$id[i], esc(m$created_at[i]), esc(m$text_[i]), m$id[i])
    }, character(1))
    shiny::HTML(paste(rows, collapse = ""))
  })
  shiny::observeEvent(input$del_memo, {
    qda_memo_delete(input$del_memo)
    bump()
    shiny::showNotification("Memo geloescht (Audit-Trail).", type = "message")
  })

  # header: stats + backup + export ---------------------------------------------
  output$stats_line <- shiny::renderText({
    rv$tick
    st <- qda_stats()$overall
    sprintf("%d Quellen - %d Codes - %d Codings - %.1f %% codiert",
            st$n_sources, st$n_codes, st$n_codings, st$pct_coded)
  })
  shiny::observeEvent(input$backup_btn, {
    z <- qda_backup(quiet = TRUE)
    bump(); shiny::showNotification(paste("Backup:", z), type = "message")
  })
  shiny::observeEvent(input$export_btn, {
    ex <- qda_export("all")
    bump(); shiny::showNotification(paste("Exportiert:", nrow(ex), "Dateien nach exports/"), type = "message")
  })
}
