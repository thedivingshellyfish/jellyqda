# jellyqda :: app_server_project.R -- part of the Shiny server of qda_app()
#
# Server part project: header (stats, save, backup, export), undo / redo,
# layout reset and closing the app.
#
# Every function here is called once per session from .jellyqda_server()
# (R/app_server.R) with the same arguments:
#   input, output, session -- as in any Shiny server
#   rv -- the reactive state of the session (see R/app_server.R)
#   shared -- helpers several parts use (bump(), esc(), notify_undo(), ...)

# header: stats, save, backup, export
#' @noRd
.srv_header <- function(input, output, session, rv, shared) {
  bump <- shared$bump

  # header: stats + backup + export ---------------------------------------------
  output$stats_line <- shiny::renderText({
    rv$tick
    st <- qda_stats()$overall
    sprintf(.t("%d Quellen - %d Codes - %d Codings - %.1f %% codiert"),
            st$n_sources, st$n_codes, st$n_codings, st$pct_coded)
  })
  output$saved_line <- shiny::renderText({
    rv$tick
    sprintf(.t("Alles gespeichert \u00b7 %s"), rv$last_saved %||% "-")
  })
  # Save (button or Ctrl+S): checkpoint the database + restore point
  shiny::observeEvent(input$save_btn, {
    tryCatch(DBI::dbGetQuery(qda_con(), "PRAGMA wal_checkpoint(TRUNCATE)"), error = function(e) NULL)
    z <- tryCatch(qda_backup(quiet = TRUE), error = function(e) NULL)
    bump()
    shiny::showNotification(
      if (is.null(z)) .t("Gespeichert.") else paste(.t("Gespeichert \u00b7 Sicherungspunkt:"), basename(z)),
      type = "message")
  })
}

# undo / redo
#' @noRd
.srv_undo_redo <- function(input, output, session, rv, shared) {
  bump <- shared$bump

  # Undo / redo ------------------------------------------------------------------
  # Buttons in the top bar or Ctrl+Z / Ctrl+Y (js/06-shortcuts.js).
  shiny::observeEvent(input$undo_btn, {
    res <- tryCatch(qda_undo(), error = function(e) {
      shiny::showNotification(paste(.t("R\u00fcckg\u00e4ngig nicht m\u00f6glich:"), conditionMessage(e)),
                              type = "warning")
      NULL
    })
    if (!is.null(res)) {
      if (res$undone == "nothing") {
        shiny::showNotification(.t("Nichts mehr r\u00fcckg\u00e4ngig zu machen."), type = "message")
      } else {
        rv$sel <- NULL; rv$clicked <- NULL; rv$caret <- NULL
        bump()
        shiny::showNotification(paste(.t("R\u00fcckg\u00e4ngig:"), res$detail), type = "message")
      }
    }
  })
  shiny::observeEvent(input$redo_btn, {
    res <- tryCatch(qda_redo(), error = function(e) {
      shiny::showNotification(paste(.t("Wiederholen nicht m\u00f6glich:"), conditionMessage(e)),
                              type = "warning")
      NULL
    })
    if (!is.null(res)) {
      if (res$redone == "nothing") {
        shiny::showNotification(.t("Nichts zu wiederholen."), type = "message")
      } else {
        rv$sel <- NULL; rv$clicked <- NULL; rv$caret <- NULL
        bump()
        shiny::showNotification(paste(.t("Wiederholt:"), res$detail), type = "message")
      }
    }
  })
  # after every change: set tooltips + enabled/disabled state of both buttons
  shiny::observe({
    rv$tick
    h <- qda_history()
    session$sendCustomMessage("jellyqdaHistory", list(undo = h$undo, redo = h$redo))
  })
  # click on a segment badge -> select the whole segment (action bar appears).
  # js/03-document-clicks.js sends input$seg_click only for a real click on the "Seg N"
  # badge, not after a mouse selection in the text.
  shiny::observeEvent(input$seg_click, {
    shiny::req(rv$src)
    segs <- .segments_for(rv$src)
    i <- as.integer(input$seg_click)
    if (i < 1 || i > nrow(segs)) return()
    rv$caret <- NULL   # the click on the badge also sets a cursor -> discard it
    rv$sel <- list(start = segs$start[i], end = segs$end[i],
                   text = substring(.resolve_source(rv$src)$frozen_text, segs$start[i], segs$end[i]))
    bump()
  })
}

# flexible layout
#' @noRd
.srv_layout <- function(input, output, session, rv, shared) {
  # flexible layout -------------------------------------------------------------
  shiny::observeEvent(input$layout_reset, {
    session$sendCustomMessage("jellyqdaReset", 1)
  })
}

# close the app
#' @noRd
.srv_close_app <- function(input, output, session, rv, shared) {
  # close app: save work (export + backup), then stop ---------------------------
  shiny::observeEvent(input$close_app, {
    qda_export("all")
    z <- qda_backup(quiet = TRUE)
    shiny::showNotification(paste(.t("Gespeichert. Export + Backup:"), z), type = "message", duration = 10)
    shiny::stopApp()
  })
}
