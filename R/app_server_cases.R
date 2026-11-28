# jellyqda :: app_server_cases.R -- part of the Shiny server of qda_app()
#
# Server part cases: the button "F\u00e4lle \u2026" in the documents panel opens a
# dialog to create cases, fill them (open document, marked passage, all
# turns of each speaker, one case per value of a document variable), set
# case variables, rename and delete. Everything goes through the functions
# of R/cases*.R, so every step can be undone with Ctrl+Z. The code matrix
# compares cases (R/app_server_tables.R).
#
# Clicks on "\u00d7" in the lists use Shiny.setInputValue() directly
# (case_unassign, case_var_del), no extra browser code needed.
#
# Called once per session from .jellyqda_server() (R/app_server.R) with
#   input, output, session, rv (reactive state), shared (helpers).

# cases dialog
#' @noRd
.srv_cases <- function(input, output, session, rv, shared) {
  bump <- shared$bump; esc <- shared$esc; notify_undo <- shared$notify_undo
  rv$case_sel <- NULL          # id of the case shown in the dialog
  run <- function(expr, ok = NULL) {
    res <- tryCatch({ force(expr); TRUE }, error = function(e) { shiny::showNotification(conditionMessage(e), type = "error"); FALSE })
    if (res) { bump(); if (!is.null(ok)) notify_undo(ok) }
    invisible(res)
  }

  shiny::observeEvent(input$cases_btn, {
    shiny::showModal(shiny::modalDialog(
      title = .t("F\u00e4lle"), size = "l", easyClose = TRUE,
      shiny::p(class = "jq-sub", .t("Ein Fall ist das, was du vergleichen willst \u2013 eine Person, ein Team, eine Organisation. Er kann aus mehreren Dokumenten bestehen (eine Person, zwei Interviews) oder aus Textstellen (eine Person in einem Gruppeninterview). Die Code-Matrix vergleicht dann F\u00e4lle und Fallvariablen.")),
      shiny::uiOutput("cases_body"),
      footer = shiny::modalButton(.t("Schlie\u00dfen"))))
  })

  output$cases_body <- shiny::renderUI({
    rv$tick
    cs <- qda_cases()
    vars <- sort(unique(unlist(lapply(.all_source_vars(), names))))
    if (!is.null(rv$case_sel) && !rv$case_sel %in% cs$id) rv$case_sel <- NULL
    sel <- rv$case_sel %||% (if (nrow(cs)) cs$id[1] else NULL)
    has_doc <- !is.null(rv$src)
    new_row <- shiny::div(class = "csrow",
      shiny::textInput("case_new", NULL, placeholder = .t("Name des neuen Falls (z. B. Person A)")),
      shiny::checkboxInput("case_new_doc", .t("mit dem offenen Dokument"), has_doc),
      shiny::actionButton("case_add_btn", .t("Fall anlegen"), icon = .jq_ico("plus"), class = "btn-sm btn-primary"))
    build_row <- shiny::div(class = "csrow",
      shiny::actionButton("case_speakers_btn", .t("Ein Fall je Sprecher*in (offenes Dokument)"), icon = .jq_ico("users"),
                          class = "btn-sm btn-outline-secondary",
                          title = .t("F\u00fcr Gruppeninterviews: alle Beitr\u00e4ge einer Person werden ein Fall (Segmente nach Sprecherwechsel)")),
      if (length(vars)) shiny::tagList(
        shiny::selectInput("case_var_key", NULL, vars, selectize = FALSE),
        shiny::actionButton("case_fromvar_btn", .t("Ein Fall je Wert"), icon = .jq_ico("layer-group"), class = "btn-sm btn-outline-secondary",
                            title = .t("F\u00fcr mehrere Dokumente je Fall: Dokumente mit demselben Wert werden ein Fall")))
      else shiny::span(class = "jq-sub", .t("Tipp: Mit einer Dokument-Variable (z. B. Person = P07) wird aus mehreren Interviews ein Fall.")))
    if (nrow(cs) == 0) {
      return(shiny::tagList(new_row, build_row, shiny::div(class = "jq-hint", .t("Noch keine F\u00e4lle."))))
    }
    c1 <- cs[cs$id == sel, ]
    m <- qda_case_members(sel)
    short <- function(x, n = 90) { x <- gsub("\\s+", " ", x); ifelse(nchar(x) > n, paste0(substr(x, 1, n), "\u2026"), x) }
    mem <- if (nrow(m) == 0) shiny::div(class = "jq-sub", .t("Noch nichts zugeordnet.")) else shiny::HTML(paste0(
      '<ul class="cslist">', paste(sprintf('<li><b>%s</b> %s <button class="mini" title="%s" onclick="Shiny.setInputValue(\'case_unassign\', %d, {priority: \'event\'})">\u00d7</button></li>',
        esc(m$source), ifelse(is.na(m$start), .t("(ganzes Dokument)"), paste0("\u00b7 \u201e", esc(short(m$text)), "\u201c")),
        .t("Aus dem Fall nehmen"), m$id), collapse = ""), "</ul>"))
    v <- qda_case_vars(sel)
    vl <- if (length(v)) shiny::HTML(paste0('<ul class="cslist">', paste(sprintf('<li>%s = <b>%s</b> <button class="mini" onclick="Shiny.setInputValue(\'case_var_del\', \'%s\', {priority: \'event\'})">\u00d7</button></li>',
        esc(names(v)), esc(v), gsub("'", "\\\\'", esc(names(v)))), collapse = ""), "</ul>")) else NULL
    selt <- rv$sel
    overview <- paste0('<table class="antable"><thead><tr><th>', .t("Fall"), "</th><th>", .t("Dokumente"), "</th><th>", .t("Stellen"), "</th><th>",
      .t("Variablen"), "</th></tr></thead><tbody>", paste(vapply(seq_len(nrow(cs)), function(i) {
        vv <- qda_case_vars(cs$id[i])
        sprintf("<tr><td>%s</td><td>%d</td><td>%d</td><td>%s</td></tr>", esc(cs$name[i]), cs$documents[i], cs$passages[i],
                esc(paste(names(vv), vv, sep = " = ", collapse = " \u00b7 ")))
      }, character(1)), collapse = ""), "</tbody></table>")
    shiny::tagList(new_row, build_row, shiny::hr(),
      shiny::div(class = "csgrid",
        shiny::div(
          shiny::selectInput("case_sel", .t("Fall bearbeiten"), stats::setNames(cs$id, cs$name), selected = sel, selectize = FALSE),
          shiny::div(class = "csrow",
            shiny::textInput("case_rename", NULL, value = c1$name),
            shiny::actionButton("case_rename_btn", .t("Umbenennen"), class = "btn-sm btn-outline-secondary"),
            shiny::actionButton("case_delete_btn", .t("Fall l\u00f6schen"), icon = .jq_ico("trash"), class = "btn-sm btn-outline-danger")),
          shiny::h6(.t("Geh\u00f6rt zum Fall")), mem,
          shiny::div(class = "csrow",
            shiny::actionButton("case_assign_doc", .t("Offenes Dokument zuordnen"), icon = .jq_ico("file-lines"),
                                class = "btn-sm btn-outline-primary", disabled = if (!has_doc) "disabled"),
            shiny::actionButton("case_assign_sel", .t("Markierte Stelle zuordnen"), icon = .jq_ico("highlighter"),
                                class = "btn-sm btn-outline-primary", disabled = if (is.null(selt) || !has_doc) "disabled")),
          if (!is.null(selt) && has_doc) shiny::p(class = "jq-sub", sprintf(.t("Markiert: \u201e%s\u201c"), short(selt$text %||% "", 70)))),
        shiny::div(
          shiny::h6(.t("Fallvariablen")), vl,
          shiny::div(class = "csrow",
            shiny::textInput("case_var_k", NULL, placeholder = .t("Variable (z.B. Alter)")),
            shiny::textInput("case_var_v", NULL, placeholder = .t("Wert")),
            shiny::actionButton("case_var_set", .t("Setzen"), class = "btn-sm btn-secondary")))),
      shiny::hr(), shiny::h6(.t("Alle F\u00e4lle")), shiny::HTML(overview))
  })

  shiny::observeEvent(input$case_sel, { rv$case_sel <- as.integer(input$case_sel) }, ignoreInit = TRUE)
  cur <- function() rv$case_sel %||% qda_cases()$id[1]

  shiny::observeEvent(input$case_add_btn, {
    nm <- trimws(input$case_new %||% "")
    if (!nzchar(nm)) { shiny::showNotification(.t("Bitte einen Namen f\u00fcr den Fall eingeben."), type = "warning"); return() }
    src <- if (isTRUE(input$case_new_doc) && !is.null(rv$src)) rv$src else NULL
    if (run(qda_case_add(nm, sources = src), sprintf(.t("Fall angelegt: %s"), nm))) {
      rv$case_sel <- qda_cases()$id[qda_cases()$name == nm]
    }
  })
  shiny::observeEvent(input$case_speakers_btn, {
    if (is.null(rv$src)) { shiny::showNotification(.t("Erst ein Dokument \u00f6ffnen."), type = "warning"); return() }
    run(qda_cases_from_speakers(rv$src), .t("F\u00e4lle aus den Sprecher*innen angelegt"))
  })
  shiny::observeEvent(input$case_fromvar_btn, {
    shiny::req(input$case_var_key)
    run(qda_cases_from_variable(input$case_var_key), sprintf(.t("Ein Fall je Wert von %s"), input$case_var_key))
  })
  shiny::observeEvent(input$case_rename_btn, run(qda_case_update(cur(), name = input$case_rename), .t("Fall umbenannt")))
  shiny::observeEvent(input$case_delete_btn, run(qda_case_delete(cur()), .t("Fall gel\u00f6scht")))
  shiny::observeEvent(input$case_assign_doc, { shiny::req(rv$src); run(qda_case_assign(cur(), rv$src), .t("Dokument zugeordnet")) })
  shiny::observeEvent(input$case_assign_sel, {
    shiny::req(rv$src, rv$sel)
    run(qda_case_assign(cur(), rv$src, start = rv$sel$start, end = rv$sel$end), .t("Stelle zugeordnet"))
  })
  shiny::observeEvent(input$case_unassign, run(qda_case_unassign(cur(), member = as.integer(input$case_unassign)), .t("Aus dem Fall genommen")))
  shiny::observeEvent(input$case_var_set, {
    k <- trimws(input$case_var_k %||% "")
    if (!nzchar(k)) { shiny::showNotification(.t("Bitte einen Variablennamen eingeben."), type = "warning"); return() }
    run(qda_case_set_var(cur(), k, input$case_var_v %||% ""), sprintf(.t("Fallvariable gesetzt: %s"), k))
  })
  shiny::observeEvent(input$case_var_del, run(qda_case_del_var(cur(), input$case_var_del), .t("Fallvariable gel\u00f6scht")))
}
