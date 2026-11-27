# jellyqda :: app_server_report.R -- part of the Shiny server of qda_app()
#
# Server part report: the toolbar button "Bericht" opens a dialog with two
# choices -- overview (fast, without the documents) or complete (with every
# document and its marks, A4) -- and an estimate of the time it takes. While
# the report is built, a real progress bar shows each step ("Dokument 87 von
# 150"); if nothing moves for 60 seconds, the dialog offers to keep waiting
# or to go back (inst/app/www/js/19-report.js). The finished report opens in
# a new tab, as before. The report itself: .report_html() in R/export.R.
#
# Called once per session from .jellyqda_server() (R/app_server.R) with
#   input, output, session, rv (reactive state), shared (helpers).

#' Rough time estimate for the report, in seconds (from the stress test,
#' dev/stress-test-results.md: about 3.4 s per million characters of
#' documents for the complete report; the overview hardly depends on it).
#' @noRd
.report_estimate <- function() {
  x <- DBI::dbGetQuery(qda_con(), "SELECT COUNT(*) AS n, COALESCE(SUM(length(frozen_text)), 0) AS chars FROM sources")
  list(docs = as.integer(x$n), chars = as.numeric(x$chars),
       full = 1 + 3.4e-6 * as.numeric(x$chars),
       overview = 1 + 0.4e-6 * as.numeric(x$chars))
}

#' "ca. 20 s" / "unter 2 s" / "ca. 2 min".
#' @noRd
.fmt_seconds <- function(s) {
  if (s < 2) return(.t("unter 2 s"))
  if (s < 90) return(sprintf(.t("ca. %d s"), as.integer(ceiling(s / 5) * 5)))
  sprintf(.t("ca. %d min"), as.integer(ceiling(s / 60)))
}

# report dialog
#' @noRd
.srv_report <- function(input, output, session, rv, shared) {
  store <- new.env(parent = emptyenv())      # the report built last (HTML)
  serve <- function(html) shiny::httpResponse(200L, "text/html; charset=UTF-8", enc2utf8(html),
                                              headers = list(`Cache-Control` = "no-store"))
  report_url <- tryCatch(
    session$registerDataObj("jqreport", list(), function(data, req) {
      if (is.null(store$html)) .report_response() else serve(store$html)
    }), error = function(e) NULL)

  output$report_link <- shiny::renderUI({
    if (is.null(report_url)) return(NULL)
    shiny::actionButton("report_btn", .t(" Bericht "), icon = .jq_ico("chart-column"),
                        class = "btn-sm btn-outline-secondary",
                        title = .t("Bericht erstellen: \u00dcbersicht oder vollst\u00e4ndig mit allen Dokumenten (A4, druckbar)"))
  })

  shiny::observeEvent(input$report_btn, {
    est <- .report_estimate()
    big <- est$docs >= 50
    choice <- function(title, sub) shiny::HTML(sprintf('<b>%s</b><br><span class="jq-sub">%s</span>', title, sub))
    shiny::showModal(shiny::modalDialog(
      title = .t("Bericht erstellen"), easyClose = FALSE,
      shiny::radioButtons("report_kind", NULL, selected = if (big) "overview" else "full",
        choiceNames = list(
          choice(.t("\u00dcbersicht"), sprintf(.t("Codesystem, Grafiken, Codebuch, Memos, codierte Textstellen, Intercoder \u2013 ohne die Dokumente. Dauer: %s"),
                                       .fmt_seconds(est$overview))),
          choice(.t("Vollst\u00e4ndig (A4)"), sprintf(.t("Dazu alle %d Dokumente mit Markierungen und Randspalte. Dauer: %s"),
                                          est$docs, .fmt_seconds(est$full)))),
        choiceValues = list("overview", "full")),
      if (big) shiny::p(class = "jq-sub", sprintf(.t("Gro\u00dfes Projekt (%d Dokumente): Die \u00dcbersicht ist vorausgew\u00e4hlt."), est$docs)),
      # filled by inst/app/www/js/19-report.js while the report is built
      shiny::div(id = "jq-report-progress", class = "jqprog", hidden = NA,
        shiny::div(class = "jqprog-bar", shiny::span()),
        shiny::div(class = "jqprog-detail jq-sub", .t("Wird vorbereitet \u2026"))),
      shiny::div(id = "jq-report-stall", class = "jqstall", hidden = NA,
        shiny::p(shiny::strong(.t("Seit einer Minute keine R\u00fcckmeldung.")), " ",
                 .t("Gro\u00dfe Projekte brauchen manchmal l\u00e4nger. Tipp: Die \u00dcbersicht ohne Dokumente ist meist in wenigen Sekunden fertig.")),
        shiny::tags$button(type = "button", class = "btn btn-sm btn-primary", `data-reportwait` = "1", .t("Weiter warten")),
        shiny::tags$button(type = "button", class = "btn btn-sm btn-outline-secondary", `data-reportback` = "1",
                           .t("Zur\u00fcck (Ergebnis verwerfen)"))),
      shiny::div(id = "jq-report-done", class = "jq-hint", hidden = NA),
      footer = shiny::tagList(
        shiny::modalButton(.t("Schlie\u00dfen")),
        shiny::tags$button(type = "button", class = "btn btn-primary", id = "report_make",
                           `data-reportmake` = "1", .t("Bericht erstellen")))))
  })

  # build the report (the browser has already opened an empty tab for it, so
  # no popup blocker interferes) and tell the browser where to find it
  shiny::observeEvent(input$report_make, {
    kind <- input$report_make$kind %||% "full"
    html <- NULL; err <- NULL
    shiny::withProgress(message = .t("Bericht wird erstellt"), value = 0, {
      html <- tryCatch(.report_html(documents = identical(kind, "full"),
                                    progress = function(v, d) shiny::setProgress(value = v, detail = d)),
                       error = function(e) { err <<- conditionMessage(e); NULL })
    })
    if (is.null(html)) {
      session$sendCustomMessage("jellyqdaReportReady", list(error = err %||% "?"))
      return()
    }
    store$html <- html
    session$sendCustomMessage("jellyqdaReportReady", list(
      url = paste0(report_url, "&t=", format(as.numeric(Sys.time()) * 1000, scientific = FALSE)),
      size = sprintf("%.1f MB", nchar(html, type = "bytes") / 1024^2)))
  })
}
