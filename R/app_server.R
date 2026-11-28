# jellyqda :: app_server.R -- the Shiny server of qda_app()
#
# .jellyqda_server() holds the reactive state of a session (rv) and the
# helpers several parts share, then registers the parts. Each part lives in
# its own file, grouped by topic:
#
#   R/app_server_documents.R -- document tree, search, variables, segments
#   R/app_server_coding.R    -- document browser, coding bar, clicked coding
#   R/app_server_codes.R     -- code system, retrieved segments, re-parenting
#   R/app_server_memos.R     -- memo panel
#   R/app_server_project.R   -- header, undo / redo, layout, closing the app
#   R/app_server_analysis.R  -- analysis window
#   R/app_server_tables.R    -- code matrix and summary grid
#
# The parts are registered in a fixed order (the order of the former single
# server function), so observers are created in the same order as before.

# --- server -------------------------------------------------------------------
#' @noRd
.jellyqda_server <- function(input, output, session) {
  # language of this session (same rule as the page: ?lang=xx, else current)
  l <- .lang_from_query(shiny::isolate(session$clientData$url_search))
  if (!is.null(l)) .jq_i18n$lang <- l
  # Reactive state of the session:
  #   src       -- id of the open document
  #   sel       -- current text selection list(start, end, text), 1-based,
  #                from js/02-text-selection.js (input$selection) or the
  #                segment badge
  #   clicked   -- id of the clicked coding (blue bar)
  #   sel_code  -- code selected in the code tree
  #   sel_memo  -- passage memo highlighted in the text
  #   memo_filter / memo_new / memo_focus -- state of the memo panel
  #   tick      -- counter; every change to the database calls bump(), and
  #                all outputs that read rv$tick re-render
  rv <- shiny::reactiveValues(src = NULL, sel = NULL, clicked = NULL, sel_code = NULL,
                              edit_entry = NULL, sum_cell = NULL, sel_memo = NULL, tick = 0,
                              search = NULL, var_filter = "",
                              memo_filter = "all", memo_new = NULL, memo_focus = NULL)
  bump <- function() {
    rv$tick <- shiny::isolate(rv$tick) + 1
    rv$last_saved <- format(Sys.time(), "%H:%M:%S")
  }
  rv$last_saved <- format(Sys.time(), "%H:%M:%S")
  esc <- htmltools::htmlEscape

  # notification with an "Undo" link (js/15-code-tree.js then clicks #undo_btn)
  notify_undo <- function(msg, type = "message") {
    shiny::showNotification(msg, type = type, duration = 7,
      action = shiny::tags$a(href = "#", `data-undonow` = "1", .t("R\u00fcckg\u00e4ngig")))
  }
  # most recently assigned codes (row "Recent" in the coding bar)
  rv$recent <- integer()

  # definition + coding rule (coding guideline), else the newest code memo
  code_defs <- function(codes) {
    cm <- qda_memos(kind = "code")
    vapply(seq_len(nrow(codes)), function(i) {
      d <- trimws(codes$description[i] %||% "")
      r <- trimws(if (is.null(codes$coding_rule) || is.na(codes$coding_rule[i])) "" else codes$coding_rule[i])
      if (!nzchar(d)) {
        m <- cm[!is.na(cm$code_id) & cm$code_id == codes$id[i], , drop = FALSE]
        d <- if (nrow(m)) trimws(m$text_[nrow(m)]) else ""
      }
      paste0(d, if (nzchar(r)) paste0(if (nzchar(d)) " \u00b7 " else "", .t("Regel: "), r) else "")
    }, character(1))
  }
  # Anzahl Codings je Code inkl. aller Subcodes
  code_agg <- function(codes) {
    vapply(codes$id, function(i) sum(codes$n_codings[codes$id %in% .code_descendants(codes, i)]),
           numeric(1))
  }

  # Report: dialog (overview / complete), progress bar, own browser tab --
  # see R/app_server_report.R

  # Store the marked text with a code (coding bar, code tree, search).
  # Exactly rv$sel$start..end is stored -- so rv$sel must not be overwritten
  # by the segment click before (see BUGFIX in js/03-document-clicks.js).
  assign_sel <- function(code_id) {
    s <- rv$sel
    n <- nchar(.resolve_source(rv$src)$frozen_text, type = "chars")
    res <- qda_code(rv$src, as.integer(code_id), start = s$start, end = min(s$end, n),
                    memo = shiny::isolate(input$memo_field) %||% "")
    rv$recent <- utils::head(unique(c(as.integer(code_id), rv$recent)), 3)
    rv$sel <- NULL
    bump()
    path <- qda_codes()$path[qda_codes()$id == code_id]
    notify_undo(sprintf(.t("Codiert: %s"), gsub(" / ", " \u203a ", path, fixed = TRUE)))
    invisible(res)
  }

  # helpers shared by the server parts (R/app_server_*.R)
  shared <- list(bump = bump, esc = esc, notify_undo = notify_undo,
                 code_defs = code_defs, code_agg = code_agg, assign_sel = assign_sel)

  # server parts, in this order
  .srv_document_tree(input, output, session, rv, shared)
  .srv_document_browser(input, output, session, rv, shared)
  .srv_coding_details(input, output, session, rv, shared)
  .srv_code_system(input, output, session, rv, shared)
  .srv_retrieved_segments(input, output, session, rv, shared)
  .srv_search(input, output, session, rv, shared)
  .srv_variables(input, output, session, rv, shared)
  .srv_code_reparent(input, output, session, rv, shared)
  .srv_memos(input, output, session, rv, shared)
  .srv_header(input, output, session, rv, shared)
  .srv_undo_redo(input, output, session, rv, shared)
  .srv_segments(input, output, session, rv, shared)
  .srv_analysis(input, output, session, rv, shared)
  .srv_intercoder(input, output, session, rv, shared)
  .srv_visuals(input, output, session, rv, shared)
  .srv_report(input, output, session, rv, shared)
  .srv_query(input, output, session, rv, shared)
  .srv_survey(input, output, session, rv, shared)
  .srv_cases(input, output, session, rv, shared)
  .srv_merge(input, output, session, rv, shared)
  .srv_pseudonyms(input, output, session, rv, shared)
  .srv_code_matrix(input, output, session, rv, shared)
  .srv_summary_grid(input, output, session, rv, shared)
  .srv_layout(input, output, session, rv, shared)
  .srv_close_app(input, output, session, rv, shared)
}
