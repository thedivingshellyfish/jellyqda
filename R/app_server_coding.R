# jellyqda :: app_server_coding.R -- part of the Shiny server of qda_app()
#
# Server part coding: the document browser with text selection and the
# coding bar, and the bar of a clicked coding (inspect / comment / delete).
#
# Every function here is called once per session from .jellyqda_server()
# (R/app_server.R) with the same arguments:
#   input, output, session -- as in any Shiny server
#   rv -- the reactive state of the session (see R/app_server.R)
#   shared -- helpers several parts use (bump(), esc(), notify_undo(), ...)

# document browser, text selection and the coding bar
#' @noRd
.srv_document_browser <- function(input, output, session, rv, shared) {
  bump <- shared$bump; esc <- shared$esc; code_defs <- shared$code_defs; assign_sel <- shared$assign_sel

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
  # Text selection from the browser (js/02-text-selection.js). NULL = selection
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
    # search results: all codes, filtered in the browser (js/15-code-tree.js)
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
}

# clicked coding: inspect, comment, delete, jump
#' @noRd
.srv_coding_details <- function(input, output, session, rv, shared) {
  bump <- shared$bump; esc <- shared$esc; notify_undo <- shared$notify_undo

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
      # (js/16-analysis-tools.js) -> input$save_coding_fields
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
}
