# jellyqda :: app_server_memos.R -- part of the Shiny server of qda_app()
#
# Server part memos: the memo panel (right column) -- memos of all four
# kinds plus comments on codings.
#
# Every function here is called once per session from .jellyqda_server()
# (R/app_server.R) with the same arguments:
#   input, output, session -- as in any Shiny server
#   rv -- the reactive state of the session (see R/app_server.R)
#   shared -- helpers several parts use (bump(), esc(), notify_undo(), ...)

# memo panel (right column)
#' @noRd
.srv_memos <- function(input, output, session, rv, shared) {
  bump <- shared$bump; esc <- shared$esc

  # memos (right column) ---------------------------------------------------------
  # Four memo kinds (memos.R) + comments on codings. All actions arrive as
  # data-* clicks from js/13-memo-panel.js and go through the
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
  # Save: js/05-memos.js sends {key, text, title} directly from the fields (not
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
}
