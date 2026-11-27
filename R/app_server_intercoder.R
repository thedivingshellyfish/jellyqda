# jellyqda :: app_server_intercoder.R -- part of the Shiny server of qda_app()
#
# Server part intercoder agreement: the tab "Intercoder" in the analysis
# window (blind copy for the second coder, comparison with the second
# coder's project file, table per code, list of disagreements with "show"
# and "take over"). The statistics come from R/intercoder.R (qda_intercoder),
# R/intercoder_diff.R and R/intercoder_adopt.R; number formatting from
# R/intercoder_stats.R. The report section is in R/report_intercoder.R.
#
# Called once per session from .jellyqda_server() (R/app_server.R) with
#   input, output, session, rv (reactive state), shared (helpers).

#' The tab panel inside the analysis window (R/app_server_analysis.R).
#' @noRd
.ic_tab_ui <- function() {
  sel <- function(id, label, choices) shiny::selectInput(id, label, choices, selectize = FALSE)
  step <- function(n, title, ...) shiny::div(class = "icstep", shiny::span(class = "icnum", n),
                                            shiny::div(shiny::strong(title), ...))
  shiny::tabPanel(.t("Intercoder"), value = "intercoder",
    shiny::div(class = "icsteps",
      step("1", .t("Blind-Kopie weitergeben"),
        shiny::p(class = "jq-sub", .t("Gleiche Dokumente, Segmente und Codesystem mit Kodierleitfaden \u2013 aber ohne Ihre Codings.")),
        shiny::downloadButton("ic_copy", .t("Blind-Kopie herunterladen"), class = "btn-sm btn-outline-secondary")),
      step("2", .t("Unabh\u00e4ngig kodieren"),
        shiny::p(class = "jq-sub", .t("Die zweite Person \u00f6ffnet die Kopie in jellyqda (qda_open(), qda_app()) und kodiert, ohne Ihre Codings zu sehen."))),
      step("3", .t("Vergleichen"),
        shiny::p(class = "jq-sub", .t("Projektdatei der zweiten Person w\u00e4hlen. Sie wird nur gelesen, nie ver\u00e4ndert.")),
        shiny::fileInput("ic_file", NULL, accept = ".jellyqda", buttonLabel = .t("Datei w\u00e4hlen\u2026"),
                         placeholder = .t("keine Datei gew\u00e4hlt")))),
    shiny::div(class = "anfilters",
      sel("ic_unit", .t("Analyseeinheit"),
          stats::setNames(c("segment", "document"), .t(c("Segmente", "Dokumente")))),
      sel("ic_level", .t("Kategorien"),
          stats::setNames(c("code", "top"), .t(c("jeder Code und Subcode", "Code-Familien (Code mit Subcodes)")))),
      shiny::downloadButton("ic_csv", .t("Tabelle f\u00fcr Excel (CSV)"), class = "btn-sm btn-outline-secondary")),
    shiny::uiOutput("ic_result"))
}

# intercoder tab
#' @noRd
.srv_intercoder <- function(input, output, session, rv, shared) {
  bump <- shared$bump; esc <- shared$esc
  # project files of a second coder can be larger than shiny's 5 MB default
  old <- options(shiny.maxRequestSize = max(getOption("shiny.maxRequestSize", 5 * 1024^2), 1024^3))
  session$onSessionEnded(function() options(old))

  rv$ic <- NULL          # list(path, name) of the uploaded file
  rv$ic_res <- NULL      # list(stats, diff, consensus)

  output$ic_copy <- shiny::downloadHandler(
    filename = function() paste0(sub("\\.jellyqda$", "", basename(project_path())), "_blind.jellyqda"),
    content = function(file) {
      tmp <- file.path(tempfile("jqcopy"), "copy.jellyqda")
      qda_intercoder_copy(tmp)
      file.copy(tmp, file, overwrite = TRUE)
      unlink(dirname(tmp), recursive = TRUE)
      bump()
    })

  coders <- function() c(sub("\\.jellyqda$", "", basename(project_path()), ignore.case = TRUE),
                         sub("\\.jellyqda$", "", rv$ic$name, ignore.case = TRUE))
  compute <- function(log) {
    if (is.null(rv$ic)) return(NULL)
    unit <- input$ic_unit %||% "segment"; level <- input$ic_level %||% "code"
    tryCatch({
      st <- qda_intercoder(rv$ic$path, unit = unit, level = level, coders = coders(), log = log)
      df <- qda_intercoder_diff(rv$ic$path, unit = unit, level = level, coders = coders())
      list(stats = st, diff = df, unit = unit, level = level)
    }, error = function(e) list(error = conditionMessage(e)))
  }
  # a new file or new settings: compute and record in the audit trail (the
  # independent result, before any consensus); after taking over codings the
  # numbers are recomputed WITHOUT a new audit-trail entry
  shiny::observeEvent(input$ic_file, {
    f <- input$ic_file
    rv$ic <- list(path = f$datapath[1], name = f$name[1])
    res <- compute(log = TRUE); if (!is.null(res)) res$consensus <- FALSE
    rv$ic_res <- res; bump()
  })
  shiny::observeEvent(list(input$ic_unit, input$ic_level), {
    if (is.null(rv$ic)) return()
    # after a consensus step the numbers are no longer independent: show them,
    # but do not record them
    cons <- isTRUE(rv$ic_res$consensus)
    res <- compute(log = !cons); if (!is.null(res)) res$consensus <- cons
    rv$ic_res <- res; bump()
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$ic_adopt, {
    a <- input$ic_adopt
    if (is.null(rv$ic)) return()
    res <- tryCatch(qda_intercoder_adopt(rv$ic$path, as.integer(a$src), as.integer(a$start), as.integer(a$end),
                                         a$code, level = rv$ic_res$level %||% "code"),
                    error = function(e) { shiny::showNotification(conditionMessage(e), type = "warning"); NULL })
    if (is.null(res)) return()
    shiny::showNotification(sprintf(.t("%d Coding(s) \u00fcbernommen (Strg+Z macht es r\u00fcckg\u00e4ngig)."), nrow(res)),
                            type = "message")
    new <- compute(log = FALSE); if (!is.null(new)) new$consensus <- TRUE
    rv$ic_res <- new; bump()
  })

  output$ic_result <- shiny::renderUI({
    res <- rv$ic_res
    if (is.null(res)) return(shiny::div(class = "jq-hint",
      .t("Noch kein Vergleich. W\u00e4hlen Sie in Schritt 3 die Projektdatei der zweiten Person.")))
    if (!is.null(res$error)) return(shiny::div(class = "jq-hint ic-error", res$error))
    st <- res$stats; info <- attr(st, "info"); ov <- st[st$scope == "overall", ]
    per <- st[st$scope == "code", ]
    if (length(info$documents) == 0) return(shiny::div(class = "jq-hint ic-error",
      .t("Keine gemeinsamen Dokumente: Die Texte der beiden Projekte sind verschieden. Hat die zweite Person eine Blind-Kopie dieses Projekts kodiert?")))
    tr <- .code_tree(qda_codes()); tr$path <- .code_paths(tr)
    col_of <- function(p) { k <- match(p, tr$path); ifelse(is.na(k), "#999999", tr$root_color[k]) }
    lab <- function(p) gsub(" / ", " \u203a ", p, fixed = TRUE)
    unit_lab <- if (res$unit == "segment") .t("Segmente") else .t("Dokumente")
    if (.lang() == "en") unit_lab <- tolower(unit_lab)
    pct <- function(x) paste0(.ic_num(100 * x, 1), " %")

    head <- sprintf(.t('<p class="jq-sub">Verglichen: <b>%s</b> (A) mit <b>%s</b> (B) \u00b7 %d Dokument(e) \u00b7 %d %s als Analyseeinheit</p>'),
                    esc(info$coder_a), esc(info$coder_b), length(info$documents), ov$units, unit_lab)
    warn <- character()
    if (length(info$missing_documents)) warn <- c(warn, sprintf(.t("Nicht verglichen (Text in B anders oder fehlt): %s"),
                                                                 esc(paste(info$missing_documents, collapse = ", "))))
    only_b <- per$code[!per$in_a]
    if (length(only_b)) warn <- c(warn, sprintf(.t("Codes nur bei B (nicht in diesem Projekt): %s"),
                                                esc(paste(lab(only_b), collapse = ", "))))
    if (isTRUE(res$consensus)) warn <- c(warn, .t("Werte nach \u00dcbernahme von Codings (Konsens). Im Protokoll und Bericht steht das unabh\u00e4ngige Ergebnis."))
    warn_html <- if (length(warn)) paste0('<ul class="icwarn">', paste0("<li>", warn, "</li>", collapse = ""), "</ul>") else ""

    card <- function(value, label, sub, cls = "") sprintf('<div class="iccard %s"><b>%s</b><span>%s</span><small>%s</small></div>',
                                                          cls, value, label, sub)
    cards <- paste0('<div class="iccards">',
      card(.ic_num(ov$kappa), .t("Cohens Kappa"), esc(.ic_na(ov$rating)), .ic_class(ov$kappa)),
      card(pct(ov$agreement), .t("\u00dcbereinstimmung"), sprintf(.t("%d von %d Entscheidungen"), ov$both + ov$neither, ov$both + ov$neither + ov$only_a + ov$only_b)),
      card(.ic_num(ov$alpha), .t("Krippendorffs Alpha"), .t("ab 0,80 zuverl\u00e4ssig"), .ic_class(ov$alpha)),
      card(.ic_num(ov$kappa_bp), .t("Brennan & Prediger"), .t("robust bei seltenen Codes")),
      card(.ic_num(ov$mean_kappa), .t("Mittleres Kappa"), sprintf(.t("\u00fcber %d Codes"), sum(!is.na(per$kappa)))),
      "</div>")

    bar <- function(k) if (is.na(k)) "" else sprintf('<span class="icbar %s" style="width:%.0f%%"></span>', .ic_class(k), 100 * max(0, k))
    rows <- vapply(seq_len(nrow(per)), function(i) {
      r <- per[i, ]
      sprintf('<tr><td><span class="swatch" style="--c:%s"></span> %s</td><td class="num">%d</td><td class="num">%d</td><td class="num">%d</td><td class="num">%s</td><td class="num %s"><b>%s</b></td><td class="icbarcell">%s</td><td class="num">%s</td><td>%s</td></tr>',
              esc(col_of(r$code)), esc(lab(r$code)), r$both, r$only_a, r$only_b, pct(r$agreement),
              .ic_class(r$kappa), .ic_num(r$kappa), bar(r$kappa), .ic_num(r$alpha), esc(.ic_na(r$rating)))
    }, character(1))
    tbl <- paste0(sprintf(.t('<table class="antable ictable"><thead><tr><th>Code</th><th>beide</th><th>nur %s</th><th>nur %s</th><th>\u00dcbereinst.</th><th>Kappa</th><th></th><th>Alpha</th><th>Bewertung</th></tr></thead><tbody>'),
                          esc(info$coder_a), esc(info$coder_b)),
                  paste(rows, collapse = ""), "</tbody></table>",
                  .t('<p class="jq-sub">Bewertung nach Landis &amp; Koch (1977): unter 0 schlecht \u00b7 bis 0,20 etwas \u00b7 bis 0,40 ausreichend \u00b7 bis 0,60 mittelm\u00e4\u00dfig \u00b7 bis 0,80 substanziell \u00b7 dar\u00fcber fast vollkommen. Kappa \u201e\u2013\u201c = nicht berechenbar (Code nur von einer Seite und dort \u00fcberall bzw. nie vergeben).</p>'))

    df <- res$diff
    shown <- utils::head(df, 200)
    short <- function(x, n = 220) { x <- gsub("\\s+", " ", x); ifelse(nchar(x) > n, paste0(substr(x, 1, n), "\u2026"), x) }
    drows <- if (nrow(shown) == 0) "" else vapply(seq_len(nrow(shown)), function(i) {
      r <- shown[i, ]
      where <- if (is.na(r$segment)) esc(r$source) else sprintf("%s<br><span class=\"jq-sub\">Seg %d</span>", esc(r$source), r$segment)
      adopt <- if (r$coded_by == "B" && r$b_codings > 0) sprintf(
        '<button class="btn btn-sm btn-outline-primary" data-icadopt="1" data-src="%d" data-start="%d" data-end="%d" data-code="%s" title="%s">%s</button>',
        r$source_id, r$start, r$end, esc(r$code, attribute = TRUE),
        esc(sprintf(.t("Coding von %s in dieses Projekt \u00fcbernehmen"), info$coder_b), attribute = TRUE), .t("\u00dcbernehmen")) else ""
      sprintf('<tr><td class="kref">%s</td><td><span class="swatch" style="--c:%s"></span> %s</td><td><span class="icwho %s">%s</span></td><td class="mtext">%s</td><td class="icbtns"><button class="btn btn-sm btn-outline-secondary" data-icgoto="1" data-src="%d" data-pos="%d">%s</button> %s</td></tr>',
              where, esc(col_of(r$code)), esc(lab(r$code)), if (r$coded_by == "A") "a" else "b",
              esc(sprintf(.t("nur %s"), r$coder)), esc(short(r$text)), r$source_id, r$start, .t("Zeigen"), adopt)
    }, character(1))
    diff_html <- if (nrow(df) == 0) paste0('<div class="jq-hint">', .t("Keine Abweichungen \u2013 beide haben alle Einheiten gleich kodiert."), "</div>") else
      paste0(sprintf(.t('<p class="jq-sub">%d Abweichung(en)%s. Grundlage f\u00fcr die Konsens-Diskussion: \u201eZeigen\u201c springt zur Stelle, \u201e\u00dcbernehmen\u201c kopiert das Coding von B (Strg+Z macht es r\u00fcckg\u00e4ngig).</p>'),
                     nrow(df), if (nrow(df) > 200) .t(" (die ersten 200 gezeigt)") else ""),
             '<table class="antable icdiff"><tbody>', paste(drows, collapse = ""), "</tbody></table>")

    shiny::HTML(paste0(head, warn_html, cards, tbl,
                       "<h6 class=\"ich\">", .t("Abweichungen"), "</h6>", diff_html))
  })

  output$ic_csv <- shiny::downloadHandler(
    filename = function() paste0("intercoder_", format(Sys.time(), "%Y%m%d-%H%M"), ".csv"),
    content = function(file) {
      st <- rv$ic_res$stats
      if (is.null(st)) st <- tibble::tibble(scope = character())
      out <- as.data.frame(st)
      out$in_a <- NULL; out$in_b <- NULL
      readr::write_excel_csv2(out, file)
    })
}
