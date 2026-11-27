# jellyqda :: app_server_analysis.R -- part of the Shiny server of qda_app()
#
# Server part analysis: the analysis window (word frequencies, keyword in
# context, Mayring summary, coding fields, case comparison ...).
#
# Every function here is called once per session from .jellyqda_server()
# (R/app_server.R) with the same arguments:
#   input, output, session -- as in any Shiny server
#   rv -- the reactive state of the session (see R/app_server.R)
#   shared -- helpers several parts use (bump(), esc(), notify_undo(), ...)

# analysis window
#' @noRd
.srv_analysis <- function(input, output, session, rv, shared) {
  bump <- shared$bump; esc <- shared$esc

  # Analysis window ---------------------------------------------------------------
  # Four tabs: word frequencies (qda_words), keyword in context (qda_kwic),
  # summary after Mayring (paraphrase/generalisation per coding) and
  # intercoder agreement (R/app_server_intercoder.R).
  an_choices <- function() {
    src <- qda_sources(); tr <- .code_tree(qda_codes())
    list(docs = c(stats::setNames("", .t("(alle Dokumente)")), stats::setNames(as.character(src$id), src$name)),
         codes = c(stats::setNames("", .t("(alle Codes)")), stats::setNames(as.character(tr$id),
                   paste0(strrep("\u00a0\u00a0", tr$depth - 1L), tr$label))))
  }
  rv$may_tick <- 0
  shiny::observeEvent(input$analysis_btn, {
    ch <- an_choices()
    sel <- function(id, label, choices) shiny::selectInput(id, label, choices, selectize = FALSE)
    shiny::showModal(shiny::modalDialog(
      title = .t("Analyse"), size = "xl", easyClose = TRUE,
      footer = shiny::modalButton(.t("Schlie\u00dfen")),
      shiny::tabsetPanel(id = "analysis_tab", type = "tabs", selected = rv$an_tab %||% "words",
        shiny::tabPanel(.t("Worth\u00e4ufigkeiten"), value = "words",
          shiny::div(class = "anfilters",
            sel("words_src", .t("Dokument"), ch$docs),
            sel("words_code", .t("nur Text in Codings von"), ch$codes),
            shiny::numericInput("words_n", .t("Anzahl W\u00f6rter"), 40, min = 10, max = 500, step = 10)),
          shiny::p(class = "jq-sub", .t("Ohne Zahlen, Zeitmarken, F\u00fcll- und Stoppw\u00f6rter. Wort anklicken = Stichwort im Kontext.")),
          shiny::uiOutput("words_table")),
        shiny::tabPanel(.t("Stichwort im Kontext"), value = "kwic",
          shiny::div(class = "anfilters",
            shiny::textInput("kwic_q", .t("Wort oder Phrase"), placeholder = .t("z. B. Familie")),
            sel("kwic_src", .t("Dokument"), ch$docs),
            shiny::checkboxInput("kwic_whole", .t("nur ganze W\u00f6rter"), TRUE)),
          shiny::uiOutput("kwic_table")),
        shiny::tabPanel(.t("Zusammenfassung (Mayring)"), value = "mayring",
          shiny::div(class = "anfilters",
            sel("may_code", .t("Code (mit Subcodes)"), ch$codes),
            sel("may_src", .t("Dokument"), ch$docs),
            shiny::downloadButton("may_csv", .t("Tabelle f\u00fcr Excel (CSV)"), class = "btn-sm btn-outline-secondary")),
          shiny::p(class = "jq-sub", shiny::strong(.t("Paraphrase")), .t(" = Inhalt kurz in eigenen Worten \u00b7 "),
                   shiny::strong(.t("Generalisierung")), .t(" = auf das Abstraktionsniveau der Analyse gehoben \u00b7 "),
                   shiny::strong(.t("Reduktion")), .t(" = der Code. Gespeichert wird beim Verlassen eines Feldes.")),
          shiny::uiOutput("mayring_table")),
        .ic_tab_ui())))   # intercoder agreement (R/app_server_intercoder.R)
  })
  # reopening the window shows the tab used last (e.g. after "show" in a list)
  shiny::observeEvent(input$analysis_tab, rv$an_tab <- input$analysis_tab)
  output$words_table <- shiny::renderUI({
    rv$tick
    n <- suppressWarnings(as.integer(input$words_n %||% 40)); if (is.na(n)) n <- 40L
    w <- qda_words(source = if (nzchar(input$words_src %||% "")) as.integer(input$words_src) else NULL,
                   code = if (nzchar(input$words_code %||% "")) as.integer(input$words_code) else NULL,
                   n = n)
    if (nrow(w) == 0) return(shiny::div(class = "jq-hint", .t("Keine W\u00f6rter gefunden.")))
    mx <- max(w$n)
    rows <- sprintf('<tr><td class="num">%d</td><td><button class="linkword" data-kwicword="%s">%s</button></td><td class="num">%d</td><td class="wbar"><span style="width:%.1f%%"></span></td><td class="num">%d</td></tr>',
                    seq_len(nrow(w)), esc(w$word, attribute = TRUE), esc(w$word), w$n, 100 * w$n / mx, w$sources)
    shiny::HTML(paste0(.t('<table class="antable words"><thead><tr><th>#</th><th>Wort</th><th>H\u00e4ufigkeit</th><th></th><th>Dokumente</th></tr></thead><tbody>'),
                       paste(rows, collapse = ""), "</tbody></table>"))
  })
  shiny::observeEvent(input$kwic_word, {
    shiny::updateTextInput(session, "kwic_q", value = input$kwic_word)
    shiny::updateTabsetPanel(session, "analysis_tab", selected = "kwic")
  })
  output$kwic_table <- shiny::renderUI({
    q <- trimws(input$kwic_q %||% "")
    if (nchar(q) < 2) return(shiny::div(class = "jq-hint", .t("Mindestens zwei Zeichen eingeben.")))
    k <- qda_kwic(q, source = if (nzchar(input$kwic_src %||% "")) as.integer(input$kwic_src) else NULL,
                  width = 60, whole_word = isTRUE(input$kwic_whole))
    if (nrow(k) == 0) return(shiny::div(class = "jq-hint", sprintf(.t("Keine Treffer f\u00fcr \u201e%s\u201c."), q)))
    shown <- utils::head(k, 300)
    rows <- sprintf(.t('<tr class="kwicrow" data-kwicsrc="%d" data-kwicpos="%d" title="Im Dokument zeigen"><td class="kref">%s<br><span class="jq-sub">Seg %s</span></td><td class="kl">%s</td><td class="km">%s</td><td class="kr">%s</td></tr>'),
                    shown$source_id, shown$start, esc(shown$source), ifelse(is.na(shown$segment), "-", shown$segment),
                    esc(shown$left), esc(shown$match), esc(shown$right))
    shiny::HTML(paste0(sprintf(.t('<p class="jq-sub">%d Treffer in %d Dokument(en)%s. Zeile anklicken = im Dokument zeigen.</p>'),
                               nrow(k), length(unique(k$source_id)), if (nrow(k) > 300) .t(" (die ersten 300 gezeigt)") else ""),
                       '<table class="antable kwic"><tbody>', paste(rows, collapse = ""), "</tbody></table>"))
  })
  shiny::observeEvent(input$kwic_goto, {
    shiny::removeModal()
    rv$src <- as.integer(input$kwic_goto$src); rv$sel <- NULL; rv$clicked <- NULL
    bump()
    session$sendCustomMessage("jellyqdaScroll", list(pos = as.integer(input$kwic_goto$pos)))
  })
  may_rows <- function() {
    cd <- qda_codings()
    tr <- .code_tree(qda_codes())
    if (nzchar(input$may_code %||% "")) cd <- cd[cd$code_id %in% .code_descendants(tr, as.integer(input$may_code)), , drop = FALSE]
    if (nzchar(input$may_src %||% "")) cd <- cd[cd$source_id == as.integer(input$may_src), , drop = FALSE]
    k <- match(cd$code_id, tr$id)
    cd$path <- gsub(" / ", " \u203a ", tr$path[k], fixed = TRUE)
    cd$color <- tr$root_color[k]
    cd$depth <- tr$depth[k]
    cd
  }
  output$mayring_table <- shiny::renderUI({
    rv$may_tick   # not rv$tick: the field would lose the focus on saving otherwise
    cd <- may_rows()
    if (nrow(cd) == 0) return(shiny::div(class = "jq-hint", .t("Keine Codings f\u00fcr diese Auswahl.")))
    short <- function(x, n = 320) ifelse(nchar(x) > n, paste0(substr(x, 1, n), "\u2026"), x)
    rows <- sprintf(paste0(.t('<tr><td class="mref">%s<br><span class="jq-sub">#%d \u00b7 Z. %d\u2013%d</span></td>'),
                           '<td class="mtext">%s</td>',
                           '<td><textarea class="form-control form-control-sm" rows="3" data-mayid="%d" data-mayfield="paraphrase" aria-label="Paraphrase">%s</textarea></td>',
                           .t('<td><textarea class="form-control form-control-sm" rows="3" data-mayid="%d" data-mayfield="generalization" aria-label="Generalisierung">%s</textarea></td>'),
                           '<td class="mcode"><span class="swatch%s" style="--c:%s"></span> %s</td></tr>'),
                    esc(cd$source), cd$id, cd$start, cd$end, esc(short(gsub("\\s+", " ", cd$text))),
                    cd$id, esc(cd$paraphrase), cd$id, esc(cd$generalization),
                    ifelse(cd$depth > 1L, " sub", ""), esc(cd$color), esc(cd$path))
    shiny::HTML(paste0(.t('<table class="antable mayring"><thead><tr><th>Fall</th><th>Textstelle</th><th>Paraphrase</th><th>Generalisierung</th><th>Reduktion (Code)</th></tr></thead><tbody>'),
                       paste(rows, collapse = ""), "</tbody></table>"))
  })
  shiny::observeEvent(input$mayring_save, {
    m <- input$mayring_save
    val <- trimws(m$value %||% "")
    res <- tryCatch(
      if (identical(m$field, "paraphrase")) qda_coding_set_summary(as.integer(m$id), paraphrase = val)
      else qda_coding_set_summary(as.integer(m$id), generalization = val),
      error = function(e) { shiny::showNotification(conditionMessage(e), type = "warning"); NULL })
    if (!is.null(res)) bump()
  })
  output$may_csv <- shiny::downloadHandler(
    filename = function() paste0("mayring_", format(Sys.time(), "%Y%m%d-%H%M"), ".csv"),
    content = function(file) {
      cd <- may_rows()
      readr::write_excel_csv2(data.frame(Fall = cd$source, Coding = cd$id, Start = cd$start, Ende = cd$end,
                                         Textstelle = cd$text, Paraphrase = cd$paraphrase,
                                         Generalisierung = cd$generalization, Reduktion = cd$path,
                                         check.names = FALSE), file)
    })

  # help modal: legend of icons + shortcuts
  shiny::observeEvent(input$help_btn, {
    shiny::showModal(shiny::modalDialog(
      title = .t("Hilfe: Symbole & Tastenk\u00fcrzel"),
      shiny::tags$ul(
        shiny::tags$li(shiny::strong(.t("Kodier-Leiste")), .t(" - Text markieren, dann Code anklicken. Hat ein Code Subcodes, klappt der Klick sie aus; \u201e(nur Code)\u201c vergibt den Code selbst. Suchfeld: Code \u00fcber den Pfad finden, Enter ohne Treffer legt einen neuen Code an")),
        shiny::tags$li(shiny::strong(.t("Strg+1..9")), .t(" - n-ter Code der Kodier-Leiste; danach "), shiny::strong("1..9"), .t(" = Subcode, "), shiny::strong("0"), .t(" = nur der Code, "), shiny::strong("Esc"), .t(" = zuklappen")),
        shiny::tags$li(shiny::strong(.t("Codebaum")), .t(" - \u201e+ Code\u201c oben, \u201e+ Subcode\u201c an der Zeile; "), shiny::strong(.t("Doppelklick")), .t(" (oder F2) = umbenennen; Papierkorb = l\u00f6schen (mit R\u00fcckfrage); Farbpunkt = Farbe der Code-Familie; Pfeil = ein-/ausklappen. Ist Text markiert, codiert ein Klick auf einen Code")),
        shiny::tags$li(shiny::strong(.t("Coding anklicken")), .t(" - Details, Umkodieren innerhalb der Code-Familie, Kommentar, Mayring (Paraphrase/Generalisierung), Ankerbeispiel, L\u00f6schen")),
        shiny::tags$li(shiny::strong(.t("In vivo")), .t(" - Kodier-Leiste: der markierte Text wird zum neuen Code")),
        shiny::tags$li(shiny::strong(.t("Buch / Pfeil am Code")), .t(" - Kodierleitfaden (Definition, Ankerbeispiel, Kodierregel) / mit anderem Code zusammenf\u00fchren")),
        shiny::tags$li(shiny::strong(.t("Suche")), .t(" - \u201eAlle Treffer codieren\u201c codiert jede Fundstelle (oder ihr Segment) in einem Schritt")),
        shiny::tags$li(shiny::strong(.t("Code-Matrix: Spalten")), .t(" - Fallvergleich nach einer Dokument-Variable")),
        shiny::tags$li(shiny::strong(.t("Analyse")), .t(" - Worth\u00e4ufigkeiten, Stichwort im Kontext, Zusammenfassung nach Mayring, Intercoder-\u00dcbereinstimmung (Kappa)")),
        shiny::tags$li(shiny::strong(.t("Strg+S")), .t(" - Speichern + Sicherungspunkt (gespeichert wird ohnehin jede Aktion sofort)")),
        shiny::tags$li(shiny::strong(.t("Bericht")), .t(" - \u00f6ffnet den Bericht in einem neuen Tab, druckbar auf A4 (Strg+P)")),
        shiny::tags$li(shiny::strong(.t("Strg+M")), .t(" - Textstellen-Memo zur Markierung (mit Text im Memo-Feld: sofort, sonst Formular im Memo-Panel)")),
        shiny::tags$li(shiny::strong("Memos"), .t(" - vier Arten: Textstelle (unterstrichen), Dokument, Code (z.B. Definition, Kodierregel), Projekt; dazu Kommentare an Codings. Panel rechts: + Neues Memo, Filter, Suche; Bezug anklicken = hinspringen; Strg+Enter speichert")),
        shiny::tags$li(shiny::strong(.t("Segmente")), .t(" - in den Text klicken: Segment hier teilen / zusammenf\u00fchren; Text markieren: 'Als Segment'; Dokumente-Panel: ganzes Dokument neu einteilen (z.B. nach Sprecherwechsel)")),
        shiny::tags$li(shiny::strong(.t("\u00dcberlappungen")), .t(" - graue Stellen mit Zahl = mehrere Codings; Maus dar\u00fcber zeigt sie an, Klick heftet die Liste fest")),
        shiny::tags$li(shiny::strong(.t("Strg+Z / Strg+Y")), .t(" - letzte Aktion r\u00fcckg\u00e4ngig machen / wiederholen (auch Code l\u00f6schen, Variablen, Summaries, Segmente)")),
        shiny::tags$li(shiny::strong(.t("Seg-Badge")), .t(" anklicken - ganzen Absatz markieren")),
        shiny::tags$li(shiny::strong(.t("Symbolleiste / Chevron")), .t(" - jeweiliges Fenster (Panel) ein-/ausklappen")),
        shiny::tags$li(shiny::strong(.t("Mond")), .t(" - Dark Mode; "), shiny::strong("?"), .t(" - diese Hilfe; "), shiny::strong("X"), .t(" - App beenden (speichert + Backup)")),
        shiny::tags$li(shiny::strong(.t("Umh\u00e4ngen")), .t(" - Code auf einen anderen Code ziehen = wird dessen Subcode")),
        shiny::tags$li(shiny::strong(.t("Dokumente-Panel")), .t(" - Dateien per Drag & Drop importieren")),
        shiny::tags$li(shiny::strong(.t("Doppel-Codierung")), .t(" - derselbe Text mehrfach codiert: gestrichelter pinker Rahmen"))
      ),
      easyClose = TRUE, footer = shiny::modalButton(.t("Schliessen"))
    ))
  })
  shiny::observeEvent(input$backup_btn, {
    z <- qda_backup(quiet = TRUE)
    bump(); shiny::showNotification(paste(.t("Backup:"), z), type = "message")
  })
  shiny::observeEvent(input$export_codebook_btn, {
    ex <- qda_export("codebook")
    bump(); shiny::showNotification(paste(.t("Codebuch exportiert:"), paste(basename(ex$file), collapse = ", ")), type = "message")
  })
  shiny::observeEvent(input$export_qdpx_btn, {   # R/export_qdpx.R
    f <- tryCatch(qda_export_qdpx(), error = function(e) { shiny::showNotification(conditionMessage(e), type = "error"); NULL })
    if (!is.null(f)) { bump(); shiny::showNotification(paste(.t("REFI-QDA-Datei gespeichert:"), basename(f)), type = "message") }
  })
  # exports that contain the report show its progress (R/export.R)
  with_report_progress <- function(expr) {
    shiny::withProgress(message = .t("Bericht wird erstellt"), value = 0, {
      .jellyqda_env$progress <- function(v, d) shiny::setProgress(value = v, detail = d)
      on.exit(.jellyqda_env$progress <- NULL, add = TRUE)
      expr
    })
  }
  shiny::observeEvent(input$export_report_btn, {
    ex <- with_report_progress(qda_export("report"))
    bump(); shiny::showNotification(paste(.t("Bericht gespeichert:"), basename(ex$file)), type = "message")
  })
  shiny::observeEvent(input$export_btn, {
    ex <- with_report_progress(qda_export("all"))
    bump(); shiny::showNotification(paste(.t("Exportiert:"), nrow(ex), .t("Dateien nach exports/")), type = "message")
  })
}
