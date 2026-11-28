# jellyqda :: app_server_documents.R -- part of the Shiny server of qda_app()
#
# Server part documents: document tree + import, full-text search,
# variables (case attributes) and editing segments.
#
# Every function here is called once per session from .jellyqda_server()
# (R/app_server.R) with the same arguments:
#   input, output, session -- as in any Shiny server
#   rv -- the reactive state of the session (see R/app_server.R)
#   shared -- helpers several parts use (bump(), esc(), notify_undo(), ...)

# document tree (left top) + import
#' @noRd
.srv_document_tree <- function(input, output, session, rv, shared) {
  bump <- shared$bump; esc <- shared$esc

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
    # rv$pseudo: active key list from the pseudonymisation dialog (R/app_server_pseudonyms.R)
    res <- tryCatch(suppressMessages(qda_import(input$import_files$datapath, names = input$import_files$name,
                                                segments = input$import_segrule %||% "blankline", pseudonyms = rv$pseudo)),
                    error = function(e) { shiny::showNotification(conditionMessage(e), type = "error"); NULL })
    if (is.null(res)) return()
    bump()
    shiny::showNotification(if (is.null(rv$pseudo)) .t("Importiert (Text eingefroren, Original in originals/).")
                            else .t("Pseudonymisiert importiert (Text eingefroren; keine Originale gespeichert)."), type = "message")
  })
}

# project-wide full-text search
#' @noRd
.srv_search <- function(input, output, session, rv, shared) {
  bump <- shared$bump; esc <- shared$esc; notify_undo <- shared$notify_undo

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
}

# document variables (case attributes)
#' @noRd
.srv_variables <- function(input, output, session, rv, shared) {
  bump <- shared$bump; esc <- shared$esc

  # variables (case attributes) per document ------------------------------------
  shiny::observe({
    rv$tick
    s <- qda_sources()
    shiny::updateSelectInput(session, "var_doc",
                             choices = stats::setNames(as.character(s$id), s$name),
                             selected = if (nrow(s) && !is.null(rv$src)) as.character(rv$src) else NULL)
    # variable filter options across all sources
    av <- .all_source_vars()       # one query for all documents (utils.R)
    opts <- unlist(lapply(av, function(v) if (length(v)) paste0(names(v), "=", v)), use.names = FALSE)
    if (is.null(opts)) opts <- character()
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
}

# edit segments
#' @noRd
.srv_segments <- function(input, output, session, rv, shared) {
  bump <- shared$bump

  # Edit segments ----------------------------------------------------------------
  # Click into the text without a selection -> js/02-text-selection.js sends the cursor
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
}
