# jellyqda :: app_ui.R -- page layout of qda_app(): top bar, symbol bar,
# 3-pane grid with 7 draggable panels. Look: inst/app/www/css/,
# behaviour in the browser: inst/app/www/js/.

# --- UI: four-pane layout (MAXQDA workflow logic, jellyqda look) -------------
#' @noRd
.jellyqda_ui <- function(req = NULL) {
  # language for this page: ?lang=xx in the address, else the current one
  l <- .lang_from_query(if (is.null(req)) NULL else req$QUERY_STRING)
  if (!is.null(l)) .jq_i18n$lang <- l
  lang <- .lang()
  fa <- fontawesome::fa
  bslib::page_fluid(
    lang = lang,
    theme = bslib::bs_theme(version = 5, primary = "#2c6fbb", font_scale = 0.82),
    shiny::tags$head(
      .jq_i18n_script(lang),  # language + English catalogue for jqT() in js/01-helpers.js
      .jellyqda_assets(),   # CSS + JS from inst/app/www/ (see above)
      .jq_favicon(),        # jellyqda logo in the browser tab (R/app_helpers.R)
      # Icon registry (invisible): fontawesome::fa() returns SVG graphics, NOT
      # an icon font. HTML written by the server uses
      # <i class="fa-solid fa-NAME"></i>, which without a font would be 0x0
      # pixels (invisible). js/14-icons.js replaces every such <i>
      # with a copy of the SVG from this registry.
      # New icon in server HTML? -> add its name to .jq_icon_names()
      # (a test checks this: test-app-icons.R, "icon registry").
      .jq_icon_registry()
    ),
    shiny::div(class = "topbar",
      shiny::span(class = "stats", shiny::textOutput("stats_line", inline = TRUE)),
      shiny::span(class = "savedline", shiny::span(class = "savedot"),
                  shiny::textOutput("saved_line", inline = TRUE)),
      shiny::div(class = "btnsection",
        # Save (Ctrl+S): every action is in the project file immediately
        # anyway; the button additionally checkpoints it and creates a restore
        # point (backup).
        shiny::actionButton("save_btn", .t("Speichern"), icon = .jq_ico("floppy-disk"),
                            class = "btn-sm btn-primary jq-save",
                            title = .t("Speichern + Sicherungspunkt anlegen (Strg+S)")),
        # Undo / redo (Ctrl+Z / Ctrl+Y). The tooltip shows exactly what will
        # happen; the server updates it via "jellyqdaHistory".
        shiny::actionButton("undo_btn", NULL, icon = .jq_ico("rotate-left"),
                            class = "btn-sm btn-outline-secondary jq-iconbtn", title = .t("R\u00fcckg\u00e4ngig (Strg+Z)")),
        shiny::actionButton("redo_btn", NULL, icon = .jq_ico("rotate-right"),
                            class = "btn-sm btn-outline-secondary jq-iconbtn", title = .t("Wiederholen (Strg+Y)")),
        shiny::span(class = "symsep"),
        # Report: button -> dialog (overview / complete) with progress bar;
        # the report opens in its own tab (R/app_server_report.R)
        shiny::uiOutput("report_link", inline = TRUE),
        # Analysis: word frequencies, keyword in context, Mayring table
        shiny::actionButton("analysis_btn", .t("Analyse"), icon = .jq_ico("magnifying-glass-chart"),
                            class = "btn-sm btn-outline-secondary",
                            title = .t("Worth\u00e4ufigkeiten, Stichwort im Kontext, Zusammenfassung nach Mayring, Intercoder-\u00dcbereinstimmung")),
        # Graphics: code co-occurrence, code network, document portraits
        shiny::actionButton("visuals_btn", .t("Grafiken"), icon = .jq_ico("diagram-project"),
                            class = "btn-sm btn-outline-secondary",
                            title = .t("Code-\u00dcberschneidungen, Code-Netzwerk, Dokument-Portraits")),
        # Export menu (<details>: opens without extra JavaScript)
        shiny::tags$details(class = "jq-menu",
          shiny::tags$summary(class = "btn btn-sm btn-outline-secondary",
                              fa("file-export"), .t(" Export "), fa("chevron-down")),
          shiny::div(class = "jq-menu-list",
            shiny::actionButton("export_btn", .t("Alles exportieren (CSV, Excel, Word, Bericht)"),
                                icon = .jq_ico("file-export"), class = "btn-sm jq-menuitem"),
            shiny::actionButton("export_codebook_btn", .t("Codebuch mit Hierarchie (Word + CSV)"),
                                icon = .jq_ico("file-word"), class = "btn-sm jq-menuitem"),
            shiny::actionButton("export_qdpx_btn", .t("REFI-QDA (.qdpx) f\u00fcr MAXQDA, ATLAS.ti, NVivo, QualCoder"),
                                icon = .jq_ico("box-archive"), class = "btn-sm jq-menuitem"),
            shiny::actionButton("export_report_btn", .t("Bericht als HTML-Datei speichern"),
                                icon = .jq_ico("chart-column"), class = "btn-sm jq-menuitem"),
            shiny::tags$hr(),
            # merge the copy of a team member (R/app_server_merge.R)
            shiny::actionButton("merge_btn", .t("Projekt zusammenf\u00fchren \u2026"), icon = .jq_ico("code-merge"),
                                class = "btn-sm jq-menuitem"),
            shiny::actionButton("backup_btn", .t("Backup anlegen (.zip)"), icon = .jq_ico("box-archive"),
                                class = "btn-sm jq-menuitem"),
            shiny::actionButton("layout_reset", .t("Layout zur\u00fccksetzen"), icon = .jq_ico("table-columns"),
                                class = "btn-sm jq-menuitem")
          )
        )
      ),
      shiny::div(class = "symbolbar",
        shiny::span(class = "symgroup",
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-docs", title = .t("Dokumente ein-/ausklappen"), fa("folder-tree")),
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-codes", title = .t("Code System ein-/ausklappen"), fa("tags")),
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-matrix", title = .t("Code-Matrix ein-/ausklappen"), fa("table-cells"))),
        shiny::span(class = "symsep"),
        shiny::span(class = "symgroup",
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-browser", title = .t("Dokument-Browser ein-/ausklappen"), fa("file-lines")),
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-segs", title = .t("All Codings ein-/ausklappen"), fa("highlighter"))),
        shiny::span(class = "symsep"),
        shiny::span(class = "symgroup",
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-memos", title = .t("Memos ein-/ausklappen"), fa("note-sticky")),
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-summary", title = .t("Summary Grid ein-/ausklappen"), fa("table-list"))),
        shiny::span(class = "symsep"),
        shiny::tags$button(class = "symbtn", `data-dark` = "1", title = .t("Dark Mode umschalten"), fa("moon")),
        shiny::tags$button(class = "symbtn", `data-help` = "1", title = .t("Hilfe: Symbole, Tastenk\u00fcrzel"), fa("circle-question")),
        # language switch: link to the other language (remembered by js/17-language.js)
        shiny::tags$a(class = "symbtn langbtn", href = if (lang == "en") "?lang=de" else "?lang=en",
                      `data-setlang` = if (lang == "en") "de" else "en",
                      title = if (lang == "en") "Deutsche Oberfl\u00e4che" else "English user interface",
                      if (lang == "en") "DE" else "EN"),
        shiny::span(class = "symsep"),
        shiny::tags$button(class = "symbtn closeapp", `data-closeapp` = "1", title = .t("App beenden (speichert + stoppt)"), fa("xmark"))
      )
    ),
    shiny::div(class = "appgrid",
      # left column: document tree (top) + code system (bottom)
      shiny::div(class = "pane left", `data-pane` = "left",
        shiny::div(class = "panel docs", id = "panel-docs",
shiny::div(class = "panelhead", draggable = "true", fa("folder-tree"), shiny::span(class = "hlabel", .t("Dokumente")), shiny::span(class = "toggler", `data-toggle` = "panel-docs", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody",
            shiny::uiOutput("doc_tree"),
            shiny::hr(),
            # segmentation for newly imported documents (can be changed later)
            shiny::selectInput("import_segrule", .t("Segmente beim Import"),
                               choices = .segrule_choices(), selected = "blankline"),
            shiny::fileInput("import_files", NULL, multiple = TRUE,
                             accept = c(".txt", ".md", ".docx", ".pdf"), buttonLabel = .t("Dateien...")),
            shiny::p(class = "jq-hint", style = "padding:.2rem;margin:.2rem 0",
                     .t("oder Dateien hierher ziehen")),
            shiny::actionButton("import_btn", .t("Importieren"), icon = .jq_ico("plus"), class = "btn-sm btn-primary"),
            # optional key list: names are replaced before the text is frozen (R/app_server_pseudonyms.R)
            shiny::actionLink("pseudo_btn", .t("Pseudonymisieren \u2026"), icon = .jq_ico("user-secret"), class = "pseudo-link"),
            shiny::uiOutput("pseudo_state"),
            # open answers of an online survey (CSV / Excel), R/app_server_survey.R
            shiny::actionButton("survey_btn", .t("Fragebogen importieren \u2026"), icon = .jq_ico("table-list"),
                                class = "btn-sm btn-outline-secondary", style = "margin-top:.35rem"),
            # cases independent of documents (R/app_server_cases.R)
            shiny::actionButton("cases_btn", .t("F\u00e4lle \u2026"), icon = .jq_ico("users"),
                                class = "btn-sm btn-outline-secondary", style = "margin-top:.35rem",
                                title = .t("Personen, Teams, Organisationen \u2013 unabh\u00e4ngig von den Dokumenten")),
            shiny::hr(),
            shiny::selectInput("var_doc", .t("Variablen f\u00fcr Dokument"), choices = character()),
            shiny::div(style = "display:flex; gap:.3rem;",
              shiny::textInput("var_key", NULL, placeholder = .t("Variable (z.B. Alter)")),
              shiny::textInput("var_val", NULL, placeholder = .t("Wert"))),
            shiny::actionButton("var_add_btn", .t("Variable setzen"), icon = .jq_ico("plus"), class = "btn-sm btn-secondary"),
            shiny::uiOutput("var_list"),
            shiny::hr(),
            # Re-segment the open document.
            # Split/merge single segments: click into the text (segment bar)
            # or mark text -> "As segment".
            shiny::selectInput("seg_rule", .t("Segmente des offenen Dokuments"),
                               choices = .segrule_choices(), selected = "speaker"),
            shiny::actionButton("seg_apply", .t("Neu einteilen"), icon = .jq_ico("scissors"),
                                class = "btn-sm btn-secondary",
                                title = .t("Segmente nach der gew\u00e4hlten Regel neu einteilen (Codings bleiben erhalten, Strg+Z macht es r\u00fcckg\u00e4ngig)"))
          )
        ),
        shiny::div(class = "panel codes", id = "panel-codes",
shiny::div(class = "panelhead", draggable = "true", fa("tags"), shiny::span(class = "hlabel", "Code System"),
                     # "+ Code": new top-level code, directly in the tree (js/15-code-tree.js)
                     shiny::tags$button(class = "addroot", `data-addroot` = "1",
                                        title = .t("Neuen Code anlegen"), "+ Code"),
                     shiny::span(class = "toggler", `data-toggle` = "panel-codes", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody",
            # tools: filter, expand/collapse all (all in the browser, js/15-code-tree.js)
            shiny::div(class = "treetools",
              shiny::tags$input(type = "search", id = "code_filter", class = "form-control form-control-sm",
                                placeholder = .t("Codes filtern \u2026"), `aria-label` = .t("Codes filtern")),
              shiny::tags$button(class = "btn btn-sm btn-outline-secondary", `data-codeall` = "open",
                                 title = .t("Alle ausklappen"), "\u229e"),
              shiny::tags$button(class = "btn btn-sm btn-outline-secondary", `data-codeall` = "close",
                                 title = .t("Alle einklappen"), "\u229f")),
            shiny::uiOutput("code_tree"),
            shiny::div(class = "jq-hint codelegend",
              shiny::span(.t("Doppelklick = umbenennen \u00b7 Zahl = eigene Codings \u00b7 \u03a3 = mit Subcodes")),
              shiny::span(.t("Auf anderen Code ziehen = umh\u00e4ngen \u00b7 Farbpunkt = Farbe der Code-Familie")))
          )
        ),
        shiny::div(class = "panel matrix", id = "panel-matrix",
          shiny::div(class = "panelhead", draggable = "true", fa("table-cells"), shiny::span(class = "hlabel", .t("Code-Matrix")),
                     shiny::span(class = "toggler", `data-toggle` = "panel-matrix", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody", shiny::uiOutput("matrix_panel"))
        )
      ),
      shiny::div(class = "colhandle", `data-a` = "0", `data-b` = "2"),
      # center: document browser (top) + retrieved segments (bottom)
      shiny::div(class = "pane center", `data-pane` = "center",
        shiny::div(class = "panel browser", id = "panel-browser",
          shiny::div(class = "panelhead", draggable = "true", fa("file-lines"), shiny::span(class = "hlabel", shiny::textOutput("doc_title", inline = TRUE)),
                     shiny::span(class = "zoombtns",
                                 shiny::tags$button(`data-zoom` = "-0.1", title = .t("Schrift kleiner"), "A-"),
                                 shiny::tags$button(`data-zoom` = "0.1", title = .t("Schrift gr\u00f6\u00dfer"), "A+")),
                     shiny::span(class = "toggler", `data-toggle` = "panel-browser", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody",
            shiny::uiOutput("clicked_bar"),
            shiny::uiOutput("actionbar"),
            shiny::uiOutput("segbar"),
            shiny::uiOutput("doc_vars"),
            shiny::div(class = "docarea", shiny::uiOutput("doc"))
          )
        ),
        shiny::div(class = "panel segs", id = "panel-segs",
shiny::div(class = "panelhead", draggable = "true", fa("highlighter"), shiny::span(class = "hlabel", shiny::uiOutput("seg_head", inline = TRUE)), shiny::span(class = "toggler", `data-toggle` = "panel-segs", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody",
            shiny::div(style = "display:flex; gap:.3rem; margin-bottom:.3rem;",
              shiny::textInput("search_q", NULL, placeholder = .t("Im ganzen Projekt suchen ...")),
              shiny::actionButton("search_btn", .t("Suchen"), icon = .jq_ico("magnifying-glass"), class = "btn-sm btn-secondary")),
            shiny::selectInput("var_filter", .t("Nur Dokumente mit Variable"), choices = stats::setNames("", .t("(alle)"))),
            shiny::uiOutput("search_results"),
            shiny::uiOutput("seg_panel")
          )
        )
      ),
      shiny::div(class = "colhandle", `data-a` = "2", `data-b` = "4"),
      # right column: memos
      shiny::div(class = "pane right", `data-pane` = "right",
        shiny::div(class = "panel memos", id = "panel-memos",
shiny::div(class = "panelhead", draggable = "true", fa("note-sticky"), shiny::span(class = "hlabel", "Memos"), shiny::span(class = "toggler", `data-toggle` = "panel-memos", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody memopanel",
            # new memos: one button per kind, active only with a matching reference
            shiny::uiOutput("memo_toolbar"),
            # form for a new memo (appears after a click on "+ ...")
            shiny::uiOutput("memo_new_form"),
            # filter (kind), search, open document only
            shiny::uiOutput("memo_filters"),
            shiny::div(class = "memosearch",
              shiny::textInput("memo_search", NULL, placeholder = .t("Memos durchsuchen ...")),
              shiny::checkboxInput("memo_only_doc", .t("nur offenes Dokument"), value = FALSE)),
            # the memo cards
            shiny::uiOutput("memos_list")
          )
        ),
        shiny::div(class = "panel summary", id = "panel-summary",
          shiny::div(class = "panelhead", draggable = "true", fa("table-list"), shiny::span(class = "hlabel", "Summary Grid"),
                     shiny::span(class = "toggler", `data-toggle` = "panel-summary", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody",
            shiny::p(class = "jq-sub",
                     .t("Zelle anklicken = Segmente + Summary bearbeiten.")),
            shiny::uiOutput("sum_matrix"),
            shiny::hr(),
            shiny::uiOutput("sum_detail")
          )
        )
      )
    )
  )
}
