# jellyqda :: app_server_merge.R -- part of the Shiny server of qda_app()
#
# Server part merging projects: "Projekt zusammenf\u00fchren \u2026" in the export
# menu opens a dialog. After choosing the .jellyqda file of a team member the
# dialog shows what would be added (qda_merge(dry_run = TRUE), R/merge.R);
# "Zusammenf\u00fchren" merges -- after an automatic backup, because merging is
# not undone with Ctrl+Z.
#
# Called once per session from .jellyqda_server() (R/app_server.R) with
#   input, output, session, rv (reactive state), shared (helpers).

# merge dialog
#' @noRd
.srv_merge <- function(input, output, session, rv, shared) {
  bump <- shared$bump; esc <- shared$esc
  rv$merge <- NULL      # list(path, name) of the chosen file

  shiny::observeEvent(input$merge_btn, {
    rv$merge <- NULL
    shiny::showModal(shiny::modalDialog(
      title = .t("Projekt zusammenf\u00fchren"), size = "l", easyClose = FALSE,
      shiny::p(class = "jq-sub", .t("Holt die Arbeit aus einer anderen Projektdatei \u2013 z. B. der Kopie, die eine Kollegin kodiert hat \u2013 in dieses Projekt: Codings, neue Codes, Memos, Variablen, F\u00e4lle und auf Wunsch Dokumente, die hier fehlen. Dokumente werden am Text erkannt, Codes am Pfad; nichts wird doppelt \u00fcbernommen. Die andere Datei wird nur gelesen.")),
      shiny::fileInput("merge_file", NULL, accept = ".jellyqda", buttonLabel = .t("Datei w\u00e4hlen\u2026"),
                       placeholder = .t("keine Datei gew\u00e4hlt")),
      shiny::checkboxInput("merge_add_docs", .t("Dokumente, die hier fehlen, hinzuf\u00fcgen"), TRUE),
      shiny::uiOutput("merge_preview"),
      footer = shiny::tagList(shiny::modalButton(.t("Abbrechen")),
                              shiny::actionButton("merge_go", .t("Zusammenf\u00fchren"), class = "btn-primary"))))
  })
  shiny::observeEvent(input$merge_file, {
    f <- input$merge_file
    rv$merge <- list(path = f$datapath[1], name = f$name[1])
  })
  table_html <- function(res) {
    lab <- c(documents = .t("Dokumente"), codes = .t("Codes"), codings = .t("Codings"), memos = .t("Memos"),
             variables = .t("Variablen"), summaries = .t("Summary Grid"), cases = .t("F\u00e4lle"))
    paste0('<table class="antable"><thead><tr><th></th><th>', .t("neu"), "</th><th>", .t("schon da"), "</th><th>", .t("Konflikte"),
           "</th></tr></thead><tbody>", paste(sprintf("<tr><td>%s</td><td><b>%d</b></td><td>%d</td><td>%s</td></tr>",
             lab[res$what], res$added, res$already, ifelse(res$conflicts > 0, sprintf("<b>%d</b>", res$conflicts), "0")), collapse = ""),
           "</tbody></table>")
  }
  output$merge_preview <- shiny::renderUI({
    m <- rv$merge
    if (is.null(m)) return(NULL)
    res <- tryCatch(qda_merge(m$path, add_documents = isTRUE(input$merge_add_docs), dry_run = TRUE),
                    error = function(e) structure(list(), error = conditionMessage(e)))
    if (!is.null(attr(res, "error"))) return(shiny::div(class = "jq-hint ic-error", attr(res, "error")))
    shiny::tagList(
      shiny::p(shiny::strong(sprintf(.t("Vorschau f\u00fcr %s:"), m$name))),
      shiny::HTML(table_html(res)),
      if (sum(res$conflicts)) shiny::p(class = "jq-sub", .t("Konflikte: Wo beide Projekte einen anderen Wert haben (Variable, Summary Grid), beh\u00e4lt dieses Projekt seinen Wert.")),
      if (isTRUE(attr(res, "skipped_documents") > 0)) shiny::p(class = "jq-sub", sprintf(.t("%d Dokument(e) fehlen hier und werden mit ihren Codings ausgelassen."), attr(res, "skipped_documents"))),
      shiny::p(class = "jq-sub", .t("Vor dem Zusammenf\u00fchren legt jellyqda automatisch ein Backup an \u2013 r\u00fcckg\u00e4ngig machst du es, indem du dieses Backup wiederherstellst.")))
  })
  shiny::observeEvent(input$merge_go, {
    m <- rv$merge
    if (is.null(m)) { shiny::showNotification(.t("Bitte zuerst eine Datei w\u00e4hlen."), type = "warning"); return() }
    res <- tryCatch(shiny::withProgress(message = .t("Projekte werden zusammengef\u00fchrt"), value = 0.4,
                                        qda_merge(m$path, add_documents = isTRUE(input$merge_add_docs))),
                    error = function(e) { shiny::showNotification(conditionMessage(e), type = "error"); NULL })
    if (is.null(res)) return()
    shiny::removeModal(); rv$merge <- NULL; bump()
    get <- function(w) res$added[res$what == w]
    shiny::showNotification(sprintf(.t("Zusammengef\u00fchrt: %d Codings, %d Codes, %d Memos, %d Dokumente neu (Backup angelegt)."),
                                    get("codings"), get("codes"), get("memos"), get("documents")), type = "message", duration = 8)
  })
}
