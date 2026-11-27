# jellyqda :: app_server_codes.R -- part of the Shiny server of qda_app()
#
# Server part codes: the code system tree, retrieved segments of the
# selected code and re-parenting codes by drag & drop.
#
# Every function here is called once per session from .jellyqda_server()
# (R/app_server.R) with the same arguments:
#   input, output, session -- as in any Shiny server
#   rv -- the reactive state of the session (see R/app_server.R)
#   shared -- helpers several parts use (bump(), esc(), notify_undo(), ...)

# code system tree (left bottom)
#' @noRd
.srv_code_system <- function(input, output, session, rv, shared) {
  bump <- shared$bump; esc <- shared$esc; notify_undo <- shared$notify_undo; code_agg <- shared$code_agg; assign_sel <- shared$assign_sel

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
  # filtering run in the browser (js/15-code-tree.js) and only send the
  # result to the server. The tree does NOT read rv$sel_code, so that a click
  # does not re-render it (the double click would get lost otherwise);
  # js/15-code-tree.js marks the selection.
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
  # new code / subcode (input field in the tree, js/15-code-tree.js) -> {label, parent}
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
  # merge two codes (selection in the tree, js/16-analysis-tools.js) -> {from, into}
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
  # delete (after the confirmation in the tree, js/15-code-tree.js)
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
}

# retrieved segments (center bottom)
#' @noRd
.srv_retrieved_segments <- function(input, output, session, rv, shared) {
  esc <- shared$esc

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
}

# re-parent a code by drag & drop
#' @noRd
.srv_code_reparent <- function(input, output, session, rv, shared) {
  bump <- shared$bump

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
}
