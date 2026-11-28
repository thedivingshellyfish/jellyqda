# jellyqda :: app_server_survey.R -- part of the Shiny server of qda_app()
#
# Server part survey import: the button "Fragebogen importieren" in the
# documents panel opens a dialog. After choosing a CSV or Excel file the
# dialog suggests the column roles (id, open answers, variables; see
# .survey_roles() in R/import_survey.R), shows how the first document will
# look and imports on "Importieren".
#
# Called once per session from .jellyqda_server() (R/app_server.R) with
#   input, output, session, rv (reactive state), shared (helpers).

# survey import dialog
#' @noRd
.srv_survey <- function(input, output, session, rv, shared) {
  bump <- shared$bump; esc <- shared$esc
  rv$survey <- NULL      # list(path, name, df, roles) of the chosen file

  shiny::observeEvent(input$survey_btn, {
    rv$survey <- NULL
    shiny::showModal(shiny::modalDialog(
      title = .t("Fragebogen importieren"), size = "l", easyClose = FALSE,
      shiny::p(class = "jq-sub", .t("Offene Antworten aus einer Online-Umfrage (SoSci Survey, LimeSurvey, Qualtrics, Google Forms \u2026), gespeichert als CSV oder Excel: Jede befragte Person wird ein Dokument, jede offene Antwort ein Segment, ausgew\u00e4hlte Spalten werden Variablen.")),
      shiny::fileInput("survey_file", NULL, accept = c(".csv", ".tsv", ".xlsx", ".xls"),
                       buttonLabel = .t("Datei w\u00e4hlen\u2026"), placeholder = .t("keine Datei gew\u00e4hlt")),
      shiny::uiOutput("survey_setup"),
      footer = shiny::tagList(shiny::modalButton(.t("Abbrechen")),
                              shiny::actionButton("survey_go", .t("Importieren"), class = "btn-primary"))))
  })

  shiny::observeEvent(input$survey_file, {
    f <- input$survey_file
    res <- tryCatch({
      df <- .read_survey(f$datapath[1], name = f$name[1])
      list(path = f$datapath[1], name = f$name[1], df = df, roles = .survey_roles(df))
    }, error = function(e) list(error = conditionMessage(e)))
    rv$survey <- res
  })

  output$survey_setup <- shiny::renderUI({
    s <- rv$survey
    if (is.null(s)) return(NULL)
    if (!is.null(s$error)) return(shiny::div(class = "jq-hint ic-error", s$error))
    r <- s$roles; cols <- r$column
    lab <- function(cl) { x <- gsub("\\s+", " ", cl); ifelse(nchar(x) > 70, paste0(substr(x, 1, 69), "\u2026"), x) }
    choices <- stats::setNames(cols, lab(cols))
    shiny::tagList(
      shiny::p(shiny::strong(sprintf(.t("%d Personen, %d Spalten."), nrow(s$df), length(cols))), " ",
               .t("Die Rollen der Spalten sind vorgeschlagen \u2013 bitte pr\u00fcfen.")),
      shiny::selectInput("survey_id", .t("ID der Person"), selectize = FALSE,
                         c(stats::setNames("", .t("(Zeilennummer)")), choices),
                         selected = cols[r$role == "id"][1] %||% ""),
      shiny::selectizeInput("survey_text", .t("Offene Fragen (werden Text)"), choices, multiple = TRUE,
                            selected = cols[r$role == "text"], width = "100%"),
      shiny::selectizeInput("survey_vars", .t("Variablen (z. B. Alter, Studiengang)"), choices, multiple = TRUE,
                            selected = cols[r$role == "variable"], width = "100%"),
      shiny::checkboxInput("survey_code", .t("Antworten nach Frage vorcodieren (ein Code je Frage)"), TRUE),
      shiny::textInput("survey_prefix", .t("Dokumentnamen beginnen mit"), sub("\\.[A-Za-z0-9]+$", "", s$name)),
      shiny::uiOutput("survey_preview"))
  })

  output$survey_preview <- shiny::renderUI({
    s <- rv$survey
    if (is.null(s) || !is.null(s$error)) return(NULL)
    text <- input$survey_text
    if (!length(text)) return(shiny::div(class = "jq-hint", .t("Mindestens eine offene Frage w\u00e4hlen.")))
    df <- s$df
    for (i in seq_len(nrow(df))) {                       # first respondent with an answer
      ans <- .survey_clean(vapply(text, function(cl) df[[cl]][i], character(1)))
      if (any(nzchar(ans))) break
    }
    d <- .survey_doc(text[nzchar(ans)], ans[nzchar(ans)])
    idv <- if (nzchar(input$survey_id %||% "")) df[[input$survey_id]][i] else sprintf("%03d", i)
    vars <- input$survey_vars
    vtxt <- if (length(vars)) paste(sprintf("%s = %s", vars, vapply(vars, function(cl) df[[cl]][i], character(1))), collapse = " \u00b7 ") else ""
    shiny::div(class = "svprev",
      shiny::p(class = "jq-sub", sprintf(.t("Vorschau: Dokument \u201e%s\u201c"), paste0(input$survey_prefix %||% "", "_", idv))),
      shiny::tags$pre(substr(d$body, 1, 1200)),
      if (nzchar(vtxt)) shiny::p(class = "jq-sub", shiny::strong(.t("Variablen: ")), vtxt))
  })

  shiny::observeEvent(input$survey_go, {
    s <- rv$survey
    if (is.null(s) || !is.null(s$error)) { shiny::showNotification(.t("Bitte zuerst eine Datei w\u00e4hlen."), type = "warning"); return() }
    res <- tryCatch(
      shiny::withProgress(message = .t("Fragebogen wird importiert"), value = 0.3,
        qda_import_survey(s$path, text = input$survey_text, vars = input$survey_vars %||% character(),
                          id = if (nzchar(input$survey_id %||% "")) input$survey_id else NA,
                          code_questions = isTRUE(input$survey_code),
                          prefix = { p <- trimws(input$survey_prefix %||% ""); if (nzchar(p)) p else NULL },
                          name = s$name, pseudonyms = rv$pseudo)),   # R/app_server_pseudonyms.R
      error = function(e) { shiny::showNotification(conditionMessage(e), type = "error"); NULL })
    if (is.null(res)) return()
    shiny::removeModal(); rv$survey <- NULL; bump()
    shiny::showNotification(sprintf(.t("%d Dokument(e) aus dem Fragebogen importiert, %d \u00fcbersprungen (ohne Antwort oder schon vorhanden)."),
                                    nrow(res), attr(res, "skipped") %||% 0L), type = "message")
  })
}
