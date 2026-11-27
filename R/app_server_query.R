# jellyqda :: app_server_query.R -- part of the Shiny server of qda_app()
#
# Server part code query: the tab "Abfrage" in the analysis window. Three
# fields -- all of these codes (AND), at least one (OR), none (NOT) -- plus a
# filter on document variables; the hits are listed with "Zeigen" (jump to
# the passage, handled in inst/app/www/js/18-visuals.js), can be saved as a
# code and downloaded as CSV. The query itself: R/query.R.
#
# Called once per session from .jellyqda_server() (R/app_server.R) with
#   input, output, session, rv (reactive state), shared (helpers).

#' The tab panel inside the analysis window (R/app_server_analysis.R).
#' @noRd
.query_tab_ui <- function() {
  tr <- .code_categories()
  codes <- stats::setNames(tr$path, paste0(strrep("\u00a0\u00a0", tr$depth - 1L), gsub(" / ", " \u203a ", tr$path, fixed = TRUE)))
  av <- .all_source_vars()
  vopts <- sort(unique(unlist(lapply(av, function(v) if (length(v)) paste0(names(v), " = ", v)), use.names = FALSE)))
  multi <- function(id, label, choices, ph) shiny::selectizeInput(id, label, choices, multiple = TRUE,
                                                                   options = list(placeholder = ph))
  shiny::tabPanel(.t("Abfrage"), value = "query",
    shiny::p(class = "jq-sub", .t("Welche Stellen enthalten bestimmte Codes zusammen? Z. B. \u201eBelastung UND F\u00fchrung im selben Segment, aber NICHT Familie\u201c \u2013 auf Wunsch nur bei Dokumenten mit bestimmten Variablen.")),
    shiny::div(class = "qgrid",
      multi("q_all", .t("Alle diese Codes (UND)"), codes, .t("Codes w\u00e4hlen \u2026")),
      multi("q_any", .t("Mindestens einer (ODER)"), codes, .t("Codes w\u00e4hlen \u2026")),
      multi("q_none", .t("Keiner dieser Codes (NICHT)"), codes, .t("Codes w\u00e4hlen \u2026")),
      multi("q_vars", .t("Nur Dokumente mit"), vopts,
            if (length(vopts)) .t("Variable = Wert \u2026") else .t("noch keine Variablen"))),
    shiny::div(class = "anfilters",
      shiny::selectInput("q_unit", .t("Gemeinsam hei\u00dft"), selectize = FALSE,
        stats::setNames(c("segment", "document"), .t(c("im selben Segment", "im selben Dokument")))),
      shiny::checkboxInput("q_sub", .t("Subcodes z\u00e4hlen mit"), TRUE)),
    shiny::uiOutput("q_result"),
    shiny::div(class = "qsave",
      shiny::textInput("q_code", NULL, placeholder = .t("Name f\u00fcr einen neuen oder vorhandenen Code")),
      shiny::actionButton("q_save", .t("Treffer als Code speichern"), class = "btn-sm btn-outline-primary"),
      shiny::downloadButton("q_csv", .t("Tabelle f\u00fcr Excel (CSV)"), class = "btn-sm btn-outline-secondary")))
}

# code query tab
#' @noRd
.srv_query <- function(input, output, session, rv, shared) {
  bump <- shared$bump; esc <- shared$esc
  # "key = value" chips -> list(key = c(values)); several values of one
  # variable mean OR, different variables mean AND
  vars_of <- function(x) {
    if (!length(x)) return(NULL)
    kv <- strsplit(x, " = ", fixed = TRUE)
    keys <- vapply(kv, `[`, character(1), 1); vals <- vapply(kv, function(p) paste(p[-1], collapse = " = "), character(1))
    split(vals, keys)
  }
  hits <- shiny::reactive({
    rv$tick
    if (!length(input$q_all) && !length(input$q_any)) return(NULL)
    tryCatch(qda_query(all = input$q_all, any = input$q_any, none = input$q_none,
                       vars = vars_of(input$q_vars), unit = input$q_unit %||% "segment",
                       subcodes = isTRUE(input$q_sub %||% TRUE)),
             error = function(e) structure(list(), error = conditionMessage(e)))
  })
  output$q_result <- shiny::renderUI({
    h <- hits()
    if (is.null(h)) return(shiny::div(class = "jq-hint", .t("Mindestens einen Code bei UND oder ODER w\u00e4hlen.")))
    if (!is.null(attr(h, "error"))) return(shiny::div(class = "jq-hint ic-error", attr(h, "error")))
    info <- attr(h, "info")
    unit_lab <- if (identical(info$unit, "document")) .t("Dokumente") else .t("Segmente")
    if (.lang() == "en") unit_lab <- tolower(unit_lab)
    head <- sprintf(.t('<p class="jq-sub"><b>%d Treffer</b> in %d Dokument(en) \u00b7 durchsucht: %d %s in %d Dokument(en)</p>'),
                    nrow(h), length(unique(h$source_id)), info$units, unit_lab, info$documents)
    if (nrow(h) == 0) return(shiny::HTML(paste0(head, '<div class="jq-hint">', .t("Keine Stelle erf\u00fcllt diese Abfrage."), "</div>")))
    shown <- utils::head(h, 200)
    short <- function(x, n = 260) { x <- gsub("\\s+", " ", x); ifelse(nchar(x) > n, paste0(substr(x, 1, n), "\u2026"), x) }
    where <- ifelse(is.na(shown$segment), esc(shown$source),
                    sprintf('%s<br><span class="jq-sub">Seg %s</span>', esc(shown$source), shown$segment))
    chips <- vapply(strsplit(shown$codes, ", ", fixed = TRUE), function(cs)
      paste(sprintf('<span class="qchip">%s</span>', esc(gsub(" / ", " \u203a ", cs, fixed = TRUE))), collapse = " "), character(1))
    rows <- sprintf('<tr><td class="kref">%s</td><td class="mtext">%s<div class="qchips">%s</div></td><td class="icbtns"><button class="btn btn-sm btn-outline-secondary" data-jump="1" data-src="%d" data-pos="%d">%s</button></td></tr>',
                    where, esc(short(shown$text)), chips, shown$source_id, shown$start, .t("Zeigen"))
    shiny::HTML(paste0(head, if (nrow(h) > 200) .t('<p class="jq-sub">Die ersten 200 Treffer sind gezeigt; die CSV-Tabelle enth\u00e4lt alle.</p>') else "",
                       '<div class="vizpairs"><table class="antable icdiff"><tbody>', paste(rows, collapse = ""), "</tbody></table></div>"))
  })
  shiny::observeEvent(input$q_save, {
    h <- hits(); name <- trimws(input$q_code %||% "")
    if (is.null(h) || !is.null(attr(h, "error")) || nrow(h) == 0) {
      shiny::showNotification(.t("Keine Treffer zum Speichern."), type = "warning"); return()
    }
    if (!nzchar(name)) { shiny::showNotification(.t("Bitte einen Namen f\u00fcr den Code eingeben."), type = "warning"); return() }
    res <- tryCatch(qda_query_to_code(h, name), error = function(e) { shiny::showNotification(conditionMessage(e), type = "error"); NULL })
    if (is.null(res)) return()
    bump()
    shiny::showNotification(sprintf(.t("%d Stelle(n) mit \u201e%s\u201c codiert (Strg+Z macht es r\u00fcckg\u00e4ngig)."), nrow(res), name), type = "message")
  })
  output$q_csv <- shiny::downloadHandler(
    filename = function() paste0("query_", format(Sys.time(), "%Y%m%d-%H%M"), ".csv"),
    content = function(file) {
      h <- hits()
      out <- if (is.null(h) || !is.null(attr(h, "error"))) data.frame(source = character()) else as.data.frame(h)
      readr::write_excel_csv2(out, file)
    })
}
