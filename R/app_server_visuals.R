# jellyqda :: app_server_visuals.R -- part of the Shiny server of qda_app()
#
# Server part graphics: the window "Grafiken" (toolbar button) with three
# tabs -- code co-occurrence (heatmap), code network, document portraits.
# Data: R/cooccurrence.R, R/portrait.R; drawings: R/plot_*.R (SVG).
# A click on a cell / line lists the passages where both codes occur; a
# click on a portrait block or "Zeigen" jumps to the passage (both handled in
# inst/app/www/js/18-visuals.js; the jump reuses input$kwic_goto from
# R/app_server_analysis.R).
#
# Called once per session from .jellyqda_server() (R/app_server.R) with
#   input, output, session, rv (reactive state), shared (helpers).

# graphics window
#' @noRd
.srv_visuals <- function(input, output, session, rv, shared) {
  esc <- shared$esc
  sel <- function(id, label, choices, selected = NULL)
    shiny::selectInput(id, label, choices, selected = selected, selectize = FALSE)
  unit_choices <- function() stats::setNames(c("segment", "document", "overlap"),
    .t(c("im selben Segment", "im selben Dokument", "Codings \u00fcberlappen")))
  level_choices <- function() stats::setNames(c("code", "top"),
    .t(c("jeder Code und Subcode", "Code-Familien (Code mit Subcodes)")))
  dl <- function(id) shiny::downloadButton(id, .t("Als SVG speichern"), class = "btn-sm btn-outline-secondary")

  rv$viz_pair <- NULL
  shiny::observeEvent(input$visuals_btn, {
    rv$viz_pair <- NULL
    shiny::showModal(shiny::modalDialog(
      title = .t("Grafiken"), size = "xl", easyClose = TRUE,
      footer = shiny::modalButton(.t("Schlie\u00dfen")),
      shiny::div(class = "anfilters",
        sel("viz_unit", .t("Gemeinsam hei\u00dft"), unit_choices(), rv$viz_unit),
        sel("viz_level", .t("Kategorien"), level_choices(), rv$viz_level)),
      shiny::tabsetPanel(id = "viz_tab", type = "tabs", selected = rv$viz_tab %||% "cooc",
        shiny::tabPanel(.t("\u00dcberschneidungen"), value = "cooc",
          shiny::div(class = "anfilters",
            sel("viz_measure", .t("Zahl in der Zelle"),
                stats::setNames(c("n", "jaccard"), .t(c("Anzahl", "Jaccard (0\u20131)"))), rv$viz_measure),
            dl("viz_cooc_svg")),
          shiny::p(class = "jq-sub", .t("Welche Codes kommen gemeinsam vor? Je dunkler, desto h\u00e4ufiger. Zelle anklicken = Textstellen unten.")),
          shiny::div(class = "vizbox", shiny::uiOutput("viz_cooc")),
          shiny::uiOutput("viz_pair_list")),
        shiny::tabPanel(.t("Code-Netzwerk"), value = "net",
          shiny::div(class = "anfilters",
            shiny::numericInput("viz_min_n", .t("Linien ab (mal gemeinsam)"), rv$viz_min_n %||% 1, min = 1, step = 1),
            sel("viz_layout", .t("Anordnung"),
                stats::setNames(c("circle", "force"), .t(c("Kreis (Codebaum-Reihenfolge)", "nach Verbindungen"))), rv$viz_layout),
            dl("viz_net_svg")),
          shiny::p(class = "jq-sub", .t("Kreis = Code (Gr\u00f6\u00dfe = H\u00e4ufigkeit), Linie = gemeinsam (St\u00e4rke = wie oft). Linie anklicken = Textstellen unten.")),
          shiny::div(class = "vizbox", shiny::uiOutput("viz_net")),
          shiny::uiOutput("viz_pair_list2")),
        shiny::tabPanel(.t("Dokument-Portraits"), value = "portrait",
          shiny::div(class = "anfilters", dl("viz_portrait_svg")),
          shiny::p(class = "jq-sub", .t("Jedes Dokument von Anfang (links) bis Ende (rechts), jedes Segment ein Block in der Farbe seiner Code-Familien. Block anklicken = zur Stelle springen.")),
          shiny::div(class = "vizbox", shiny::uiOutput("viz_portrait"))))))
  })
  # remember the settings for the next time the window opens
  shiny::observeEvent(input$viz_tab, rv$viz_tab <- input$viz_tab)
  shiny::observeEvent(input$viz_unit, { rv$viz_unit <- input$viz_unit; rv$viz_pair <- NULL })
  shiny::observeEvent(input$viz_level, { rv$viz_level <- input$viz_level; rv$viz_pair <- NULL })
  shiny::observeEvent(input$viz_measure, rv$viz_measure <- input$viz_measure)
  shiny::observeEvent(input$viz_min_n, rv$viz_min_n <- input$viz_min_n)
  shiny::observeEvent(input$viz_layout, rv$viz_layout <- input$viz_layout)

  unit <- function() input$viz_unit %||% "segment"
  level <- function() input$viz_level %||% "code"
  cooc <- shiny::reactive({ rv$tick; qda_cooccurrence(unit = unit(), level = level()) })
  as_html <- function(svg) shiny::HTML(as.character(svg))
  min_n <- function() { v <- suppressWarnings(as.integer(input$viz_min_n %||% 1)); if (is.na(v)) 1L else v }
  output$viz_cooc <- shiny::renderUI(as_html(qda_plot_cooccurrence(cooc(), measure = input$viz_measure %||% "n")))
  output$viz_net <- shiny::renderUI(as_html(qda_plot_network(cooc(), min_n = min_n(), layout = input$viz_layout %||% "circle")))
  output$viz_portrait <- shiny::renderUI({
    rv$tick
    # portraits always by code family: subcodes share the family colour, so a
    # legend per subcode could not be told apart
    as_html(qda_plot_portrait(qda_portrait(level = "top")))
  })

  # click on a cell / line -> passages of both codes
  shiny::observeEvent(input$viz_pair, rv$viz_pair <- input$viz_pair)
  pair_list <- function() {
    p <- rv$viz_pair
    if (is.null(p)) return(NULL)
    d <- tryCatch(qda_cooccurrence_passages(p$a, p$b, unit = unit(), level = level()),
                  error = function(e) NULL)
    if (is.null(d)) return(NULL)
    lab <- function(x) gsub(" / ", " \u203a ", x, fixed = TRUE)
    short <- function(x, n = 240) { x <- gsub("\\s+", " ", x); ifelse(nchar(x) > n, paste0(substr(x, 1, n), "\u2026"), x) }
    shown <- utils::head(d, 100)
    rows <- if (nrow(shown) == 0) "" else vapply(seq_len(nrow(shown)), function(i) {
      r <- shown[i, ]
      where <- if (is.na(r$segment)) esc(r$source) else sprintf('%s<br><span class="jq-sub">Seg %d</span>', esc(r$source), r$segment)
      sprintf('<tr><td class="kref">%s</td><td class="mtext">%s</td><td class="icbtns"><button class="btn btn-sm btn-outline-secondary" data-jump="1" data-src="%d" data-pos="%d">%s</button></td></tr>',
              where, esc(short(r$text)), r$source_id, r$start, .t("Zeigen"))
    }, character(1))
    shiny::HTML(paste0(
      sprintf(.t('<h6 class="ich">%s + %s: %d Stelle(n)%s</h6>'), esc(lab(p$a)), esc(lab(p$b)), nrow(d),
              if (nrow(d) > 100) .t(" (die ersten 100 gezeigt)") else ""),
      '<div class="vizpairs"><table class="antable icdiff"><tbody>', paste(rows, collapse = ""), "</tbody></table></div>"))
  }
  output$viz_pair_list <- shiny::renderUI(pair_list())
  output$viz_pair_list2 <- shiny::renderUI(pair_list())

  svg_dl <- function(name, make) shiny::downloadHandler(
    filename = function() paste0(name, "_", format(Sys.time(), "%Y%m%d-%H%M"), ".svg"),
    content = function(file) make(file))
  output$viz_cooc_svg <- svg_dl("cooccurrence", function(f) qda_plot_cooccurrence(cooc(), measure = input$viz_measure %||% "n", file = f))
  output$viz_net_svg <- svg_dl("network", function(f) qda_plot_network(cooc(), min_n = min_n(), layout = input$viz_layout %||% "circle", file = f))
  output$viz_portrait_svg <- svg_dl("portraits", function(f) qda_plot_portrait(qda_portrait(level = "top"), file = f))
}
