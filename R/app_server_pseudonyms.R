# jellyqda :: app_server_pseudonyms.R -- part of the Shiny server of qda_app()
#
# Server part pseudonymisation at import: the link "Pseudonymisieren \u2026"
# under the import button opens a dialog for the key list (one line
# "Name = Ersatz" each, or a CSV / Excel file). The list is kept only for
# this app session (rv$pseudo) -- never in the project. While it is active,
# "Importieren" and the survey import replace the names before the text is
# frozen (R/pseudonymise.R). With files chosen, the dialog shows how often
# each name would be replaced.
#
# Called once per session from .jellyqda_server() (R/app_server.R) with
#   input, output, session, rv (reactive state), shared (helpers).

# pseudonymisation dialog
#' @noRd
.srv_pseudonyms <- function(input, output, session, rv, shared) {
  esc <- shared$esc
  rv$pseudo <- NULL          # active key list (qda_pseudonyms()) or NULL
  rv$pseudo_lines <- ""      # its text, to show it again in the dialog

  output$pseudo_state <- shiny::renderUI({
    k <- rv$pseudo
    if (is.null(k)) return(NULL)
    shiny::div(class = "jq-hint pseudo-on", sprintf(.t("Pseudonymisierung aktiv: %d Name(n) werden beim Import ersetzt."), length(k)))
  })

  shiny::observeEvent(input$pseudo_btn, {
    shiny::showModal(shiny::modalDialog(
      title = .t("Pseudonymisieren beim Import"), size = "l", easyClose = FALSE,
      shiny::p(class = "jq-sub", .t("Namen von Personen, Orten, Firmen \u2026 werden ersetzt, bevor der Text eingefroren wird \u2013 im Text und im Dokumentnamen. Die Liste bleibt nur in dieser Sitzung und wird nicht im Projekt gespeichert; die Originaldateien werden nicht nach originals/ kopiert. Bewahre deine Zuordnungsliste getrennt und sicher auf.")),
      shiny::textAreaInput("pseudo_text", .t("Eine Zeile je Name: Original = Ersatz"), value = rv$pseudo_lines, rows = 7, width = "100%",
                           placeholder = "Anna Schmidt = [Person A]\nAnna = [Person A]\nHamburg = [Stadt 1]"),
      shiny::fileInput("pseudo_file", .t("\u2026 oder eine Liste laden (CSV / Excel: Original, Ersatz)"), accept = c(".csv", ".tsv", ".txt", ".xlsx"),
                       buttonLabel = .t("Datei w\u00e4hlen\u2026"), placeholder = .t("keine Datei gew\u00e4hlt")),
      shiny::div(class = "csrow",
        shiny::checkboxInput("pseudo_word", .t("nur ganze W\u00f6rter (\u201eIna\u201c trifft nicht \u201eMartina\u201c)"), TRUE),
        shiny::checkboxInput("pseudo_case", .t("Gro\u00df-/Kleinschreibung ignorieren"), FALSE)),
      shiny::uiOutput("pseudo_preview"),
      footer = shiny::tagList(shiny::actionButton("pseudo_off", .t("Ausschalten"), class = "btn-outline-secondary"),
                              shiny::modalButton(.t("Abbrechen")),
                              shiny::actionButton("pseudo_ok", .t("\u00dcbernehmen"), class = "btn-primary"))))
  })
  shiny::observeEvent(input$pseudo_file, {
    f <- input$pseudo_file
    k <- tryCatch(qda_pseudonyms(stats::setNames(f$datapath[1], NULL)), error = function(e) { shiny::showNotification(conditionMessage(e), type = "error"); NULL })
    if (is.null(k)) return()
    shiny::updateTextAreaInput(session, "pseudo_text", value = paste(names(k), "=", k, collapse = "\n"))
  })
  key <- shiny::reactive({
    txt <- input$pseudo_text %||% ""
    if (!nzchar(trimws(txt))) return(NULL)
    tryCatch(qda_pseudonyms(txt, whole_word = isTRUE(input$pseudo_word %||% TRUE), ignore_case = isTRUE(input$pseudo_case)),
             error = function(e) NULL)
  })
  output$pseudo_preview <- shiny::renderUI({
    k <- key()
    if (is.null(k) || !length(k)) return(shiny::div(class = "jq-sub", .t("Noch keine Namen eingetragen.")))
    files <- input$import_files
    if (is.null(files)) return(shiny::div(class = "jq-sub", sprintf(.t("%d Name(n) in der Liste. W\u00e4hle unter \u201eDateien\u2026\u201c Transkripte, dann siehst du hier, wie oft jeder Name ersetzt wird."), length(k))))
    pv <- tryCatch(qda_pseudonymise_preview(files$datapath, k), error = function(e) NULL)
    if (is.null(pv)) return(NULL)
    pv$file <- files$name[match(pv$file, basename(files$datapath))]
    tot <- stats::aggregate(n ~ original + replacement, pv, sum)
    tot <- tot[match(names(k), tot$original), ]
    shiny::HTML(paste0('<table class="antable"><thead><tr><th>', .t("Original"), "</th><th>", .t("Ersatz"), "</th><th>",
      sprintf(.t("Treffer in %d Datei(en)"), length(unique(pv$file))), "</th></tr></thead><tbody>",
      paste(sprintf('<tr%s><td>%s</td><td>%s</td><td>%s</td></tr>', ifelse(tot$n == 0, ' class="zero"', ""), esc(tot$original), esc(tot$replacement),
                    ifelse(tot$n == 0, .t("0 \u2013 anders geschrieben oder schon Teil eines l\u00e4ngeren Namens?"), as.character(tot$n))), collapse = ""), "</tbody></table>"))
  })
  shiny::observeEvent(input$pseudo_ok, {
    k <- key()
    rv$pseudo <- if (length(k)) k else NULL
    rv$pseudo_lines <- input$pseudo_text %||% ""
    shiny::removeModal()
    if (length(k)) shiny::showNotification(sprintf(.t("Pseudonymisierung aktiv: %d Name(n)."), length(k)), type = "message")
  })
  shiny::observeEvent(input$pseudo_off, {
    rv$pseudo <- NULL; rv$pseudo_lines <- ""
    shiny::removeModal()
    shiny::showNotification(.t("Pseudonymisierung ausgeschaltet."), type = "message")
  })
}
