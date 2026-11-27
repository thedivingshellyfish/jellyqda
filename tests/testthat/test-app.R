test_that(".split_segments_full preserves the exact text (offset integrity)", {
  cases <- c("a\n\nb\n\n\nc", "a\n\n \n\nb", "one line only", "", "a\n\n\n\nb",
             "Start\n\nMit Umlauten äöü und <Sonder> & Zeichen\n\nEnde")
  for (t in cases) {
    p <- jellyqda:::.split_segments_full(t)
    rebuilt <- paste0(
      vapply(seq_len(nrow(p$segs)), function(i) {
        s <- if (i > 1) p$seps[i - 1] else ""
        paste0(s, substring(t, p$segs$start[i], p$segs$end[i]))
      }, character(1)),
      collapse = "")
    expect_identical(rebuilt, t)
  }
})

test_that(".render_doc_html: DOM text equals frozen text, codings are marks", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(ext("interview_01.txt"))
  qda_code_add("Werdegang", color = "#FF0000")
  qda_code(1, segment = 2, code = "Werdegang")
  html <- jellyqda:::.render_doc_html(1)
  expect_true(grepl('<div id="doc"', html, fixed = TRUE))   # + data-codings attribute
  expect_true(grepl('class="segtext"', html, fixed = TRUE))
  expect_true(grepl("<mark", html, fixed = TRUE))
  expect_true(grepl("#FF0000", html, fixed = TRUE))
  # strip tags -> must equal the escaped frozen text exactly (offsets 1:1)
  stripped <- gsub("<[^>]*>", "", html)
  frozen <- DBI::dbGetQuery(qda_con(), "SELECT frozen_text FROM sources")$frozen_text
  expect_identical(stripped, htmltools::htmlEscape(frozen))
})

test_that("qda_app server wiring works (shiny::testServer)", {
  skip_if_not_installed("shiny")
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(c(ext("interview_01.txt"), ext("interview_02.md")))
  qda_code_add("Werdegang")
  qda_code_add("KMU", parent = "Werdegang")

  shiny::testServer(jellyqda:::.jellyqda_server, {
    # open document 1 -> doc output renders
    session$setInputs(open_source = 1)
    expect_true(!is.null(output$doc))

    # simulate a text selection (chars 10..40) and assign code 2 ("KMU")
    session$setInputs(selection = list(start = 10L, end = 40L, text = "..."),
                      memo_field = "Test-Memo")
    session$setInputs(assign_code = 2L)
    cod <- qda_codings()
    expect_equal(nrow(cod), 1)
    expect_equal(cod$code_id, 2L)
    expect_equal(cod$start, 10L)
    expect_equal(cod$end, 40L)
    expect_equal(cod$memo, "Test-Memo")
    frozen <- DBI::dbGetQuery(qda_con(), "SELECT frozen_text FROM sources WHERE id = 1")$frozen_text
    expect_equal(cod$text, substring(frozen, 10, 40))

    # memo-only button with text -> passage memo (own memos table, underlined);
    # no pseudo coding with a reserved "Memo" code any more
    session$setInputs(selection = list(start = 1L, end = 5L, text = "abc"), memo_field = "kurz")
    session$setInputs(add_memo_only = 1L)
    expect_equal(nrow(qda_codings()), 1)
    pm <- qda_memos(kind = "passage")
    expect_equal(nrow(pm), 1)
    expect_equal(pm$text_, "kurz")
    expect_equal(pm$start, 1L)
    expect_equal(pm$end, 5L)
    expect_false("Memo" %in% qda_codes()$label)
    # document renders it as underline mark; it stays highlighted (sel)
    session$setInputs(backup_btn = 1L)
    doc_html <- htmltools::renderTags(output$doc)$html
    expect_true(grepl("memomark", doc_html, fixed = TRUE))
    expect_true(grepl("memomark sel", doc_html, fixed = TRUE))
    expect_true(grepl(sprintf('data-mid="%d"', pm$id), doc_html, fixed = TRUE))
    # selection action bar contains the optional memo text field
    session$setInputs(selection = list(start = 1L, end = 5L, text = "abc"))
    ab <- htmltools::renderTags(output$actionbar)$html
    expect_true(grepl('id="memo_field"', ab, fixed = TRUE))
    expect_true(grepl('class="actionbar"', ab, fixed = TRUE))
    # memo-only button WITHOUT text -> new-memo form in the memo panel
    session$setInputs(selection = list(start = 6L, end = 9L, text = "xyz"), memo_field = "")
    session$setInputs(add_memo_only = 2L)
    expect_true(grepl('id="memo_new_text"', htmltools::renderTags(output$memo_new_form)$html, fixed = TRUE))
    session$setInputs(memo_new_save = list(text = "aus dem Formular", title = "Idee"))
    pm <- qda_memos(kind = "passage")
    expect_equal(nrow(pm), 2)
    expect_equal(pm$title[2], "Idee")
    expect_equal(c(pm$start[2], pm$end[2]), c(6L, 9L))
    # retrieved-segments panel lists the coding with its comment
    segp <- htmltools::renderTags(output$seg_panel)$html
    expect_true(grepl("data-goto", segp, fixed = TRUE))
    expect_true(grepl("Test-Memo", segp, fixed = TRUE))
    # segments header label (no code selected yet)
    expect_true(grepl("All Codings", htmltools::renderTags(output$seg_head)$html, fixed = TRUE))

    # project memos (console API) show in the memo panel with edit + delete
    # buttons (icon + German text label, visible even if the icon font fails)
    qda_memo_add("Leitfaden-Frage 3 nachschaerfen")
    expect_equal(nrow(qda_memos(kind = "project")), 1)
    session$setInputs(backup_btn = 1L)
    ml <- htmltools::renderTags(output$memos_list)$html
    expect_true(grepl("data-editmemo", ml, fixed = TRUE))
    expect_true(grepl("data-delmemo", ml, fixed = TRUE))
    expect_true(grepl("> Bearbeiten</button>", ml, fixed = TRUE))
    expect_true(grepl("> L\u00f6schen</button>", ml, fixed = TRUE))
    expect_true(grepl("nachschaerfen", ml, fixed = TRUE))
    # filter chips with counts; filter "project" hides the passage memos
    expect_true(grepl('data-memofilter="project"', htmltools::renderTags(output$memo_filters)$html, fixed = TRUE))
    session$setInputs(memo_filter = "project")
    ml <- htmltools::renderTags(output$memos_list)$html
    expect_false(grepl("aus dem Formular", ml, fixed = TRUE))
    session$setInputs(memo_filter = "all")
    session$setInputs(del_memo = qda_memos(kind = "project")$id[1])
    expect_equal(nrow(qda_memos(kind = "project")), 0)

    # "+ Code" / "+ Subcode" in the tree send input$add_code {label, parent}
    session$setInputs(add_code = list(label = "Motivation", parent = NULL))
    expect_true("Motivation" %in% qda_codes()$label)
    mot_id <- qda_codes()$id[qda_codes()$label == "Motivation"]
    session$setInputs(add_code = list(label = "intrinsisch", parent = mot_id))
    cc <- qda_codes()
    expect_equal(cc$parent_id[cc$label == "intrinsisch"], mot_id)
    # a subcode takes the colour of its code family
    expect_equal(cc$color[cc$label == "intrinsisch"], cc$color[cc$id == mot_id])
    # duplicate label under the same parent: warning, nothing added
    session$setInputs(add_code = list(label = "intrinsisch", parent = mot_id))
    expect_equal(sum(qda_codes()$label == "intrinsisch"), 1)

    # rename (double click in the tree) -> input$rename_code {id, label}
    session$setInputs(rename_code = list(id = 1L, label = "WerdegangNeu"))
    expect_true("WerdegangNeu" %in% qda_codes()$label)
    session$setInputs(rename_code = list(id = mot_id, label = "Motiv"))
    expect_true("Motiv" %in% qda_codes()$label)
    # colour of a code family
    session$setInputs(code_color = list(id = mot_id, color = "#123456"))
    cc <- qda_codes()
    expect_equal(cc$color[cc$id == mot_id], "#123456")
    expect_equal(cc$color[cc$label == "intrinsisch"], "#123456")
    # delete (after the confirmation in the tree) removes code + subcodes
    session$setInputs(del_code_id = mot_id)
    expect_false(any(c("Motiv", "intrinsisch") %in% qda_codes()$label))

    # delete the coding via the list button
    session$setInputs(del_coding = cod$id)
    expect_equal(nrow(qda_codings()), 0)

    # clicked coding bar
    qda_code(1, segment = 1, code = 1, memo = "springt hierher")
    cid <- qda_codings()$id[1]
    session$setInputs(backup_btn = 1L)   # any app action bumps the tick -> lists re-render
    session$setInputs(clicked_coding = cid)
    expect_true(!is.null(output$clicked_bar))
    # comments on codings appear in the memo panel (removable, coding stays)
    ml <- htmltools::renderTags(output$memos_list)$html
    expect_true(grepl("springt hierher", ml, fixed = TRUE))
    expect_true(grepl("data-delcomment", ml, fixed = TRUE))
    # segment rows are navigable (data-goto) and show the memo
    as_html <- function(x) htmltools::renderTags(x)$html
    expect_true(grepl("data-goto", as_html(output$seg_panel), fixed = TRUE))
    expect_true(grepl("springt hierher", as_html(output$seg_panel), fixed = TRUE))
    # code tree rows are selectable (data-selcode); selecting filters segments
    ct <- as_html(output$code_tree)
    expect_true(grepl("data-selcode", ct, fixed = TRUE))
    session$setInputs(selection = NULL)   # no marked text -> click only filters
    session$setInputs(sel_code = 1L)
    sh <- as_html(output$seg_head)
    expect_true(grepl("Retrieved Segments", sh, fixed = TRUE))
    sp <- as_html(output$seg_panel)
    expect_true(grepl("springt hierher", sp, fixed = TRUE))
    expect_false(grepl('data-codeid', sp, fixed = TRUE))
    session$setInputs(sel_code = NULL)
    # goto: click a coding -> browser switches to its source, clicked bar shows memo
    session$setInputs(open_source = 2L)
    session$setInputs(goto_coding = cid)
    expect_true(!is.null(output$clicked_bar))
    expect_true(grepl("Kommentar: springt hierher", as_html(output$clicked_bar), fixed = TRUE))
    session$setInputs(del_clicked_coding = 1L)
    expect_equal(nrow(qda_codings()), 0)

    # stats line renders
    expect_true(grepl("Quellen", output$stats_line))
    # saved-line renders
    expect_true(grepl("gespeichert", output$saved_line))

    # seg badge click selects the whole segment -> action bar appears
    session$setInputs(seg_click = 1L)
    ab2 <- as_html(output$actionbar)
    expect_true(grepl('class="actionbar"', ab2, fixed = TRUE))

    # project-wide search finds a hit and goto_pos jumps
    session$setInputs(search_q = "project lead", search_btn = 1L)
    sr <- as_html(output$search_results)
    expect_true(grepl("data-gotopos", sr, fixed = TRUE))
    session$setInputs(goto_pos = list(src = 1L, pos = 10L))
    expect_true(grepl("interview_01", as_html(output$doc_title), fixed = TRUE))

    # variables: set via UI inputs, shown as chips + filter choices
    session$setInputs(var_doc = "1", var_key = "Alter", var_val = "32", var_add_btn = 1L)
    expect_equal(qda_source_vars(1)[["Alter"]], "32")
    expect_true(grepl("Alter = 32", as_html(output$doc_vars), fixed = TRUE))
    vl <- as_html(output$var_list)
    expect_true(grepl("data-delvar", vl, fixed = TRUE))
    session$setInputs(del_var = "1|Alter")
    expect_equal(length(qda_source_vars(1)), 0)

    # reparent via drag&drop input (Untethema: parent 1 -> parent 2 = KMU)
    qda_code_add("Untethema", parent = 1L)
    session$setInputs(reparent_code = list(code = qda_codes()$id[qda_codes()$label == "Untethema"], parent = 2L))
    expect_equal(qda_codes()$path[qda_codes()$label == "Untethema"], "WerdegangNeu / KMU / Untethema")

    # undo button reverts the last action (the code_move)
    session$setInputs(undo_btn = 1L)
    expect_equal(qda_codes()$path[qda_codes()$label == "Untethema"], "WerdegangNeu / Untethema")

    # project memo via console API; per-entry inline edit + save in the memo section
    mid <- qda_memo_add("erstes Memo")$id
    key <- paste0("memo_", mid)
    session$setInputs(edit_memo_entry = key)
    session$setInputs(backup_btn = 1L)  # flush -> memo list re-renders in edit mode
    ml <- as_html(output$memos_list)
    expect_true(grepl(paste0("memo_edit_", key), ml, fixed = TRUE))  # inline editor shown
    expect_true(grepl("data-savememo", ml, fixed = TRUE))
    do.call(session$setInputs, stats::setNames(list("bearbeitet"), paste0("memo_edit_", key)))
    session$setInputs(save_memo_entry = key)
    expect_equal(qda_memos()$text_[qda_memos()$id == mid], "bearbeitet")
    session$setInputs(cancel_edit = 1L)  # no error

    # title + text sent directly with the save click (as js/05-memos.js does)
    session$setInputs(edit_memo_entry = key)
    session$setInputs(save_memo_entry = list(key = key, text = "mit Titel", title = "T1"))
    m1 <- qda_memos()[qda_memos()$id == mid, ]
    expect_equal(c(m1$text_, m1$title), c("mit Titel", "T1"))

    # passage memo: jump from its card -> document opens, passage highlighted
    session$setInputs(selection = list(start = 1L, end = 5L, text = "abc"), memo_field = "spring")
    session$setInputs(add_memo_only = 3L)
    pmid <- max(qda_memos(kind = "passage")$id)
    session$setInputs(open_source = 2L)
    session$setInputs(memo_jump = paste0("memo_", pmid))
    doc_html2 <- as_html(output$doc)
    expect_true(grepl("memomark sel", doc_html2, fixed = TRUE))
    expect_true(grepl("data-memojump", as_html(output$memos_list), fixed = TRUE))
    # clicking the underline in the text focuses the card in the panel
    session$setInputs(clicked_memo = pmid)
    expect_true(grepl("memocard kind-passage focus", as_html(output$memos_list), fixed = TRUE))
    # document memo + code memo via the "+" buttons
    session$setInputs(new_memo = list(kind = "document"))
    session$setInputs(memo_new_save = list(text = "Postskript", title = ""))
    expect_equal(qda_memos(kind = "document")$text_, "Postskript")
    session$setInputs(sel_code = 1L)
    session$setInputs(new_memo = list(kind = "code"))
    session$setInputs(memo_new_save = list(text = "Nur explizite Aussagen", title = "Kodierregel"))
    expect_equal(qda_memos(kind = "code")$title, "Kodierregel")
    expect_true(grepl("data-codememo", as_html(output$code_tree), fixed = TRUE))
    expect_true(grepl("data-docmemo", as_html(output$doc_tree), fixed = TRUE))
    # search
    session$setInputs(memo_search = "explizite")
    session$elapse(400)   # debounce of the search field (simulated time)
    ml <- as_html(output$memos_list)
    expect_true(grepl("Kodierregel", ml, fixed = TRUE))
    expect_false(grepl("Postskript", ml, fixed = TRUE))
    session$setInputs(memo_search = "")

    # code matrix renders with cells + SUM
    mtx <- as_html(output$matrix_panel)
    expect_true(grepl("mxcell", mtx, fixed = TRUE))
    expect_true(grepl("SUM", mtx, fixed = TRUE))
    session$setInputs(mx_cell = list(code = 1L, source = 2L))
    expect_true(grepl("Retrieved Segments", as_html(output$seg_head), fixed = TRUE))

    # summary grid: pick cell, write summary, save -> persisted
    smx <- as_html(output$sum_matrix)
    expect_true(grepl("sumcell", smx, fixed = TRUE))
    session$setInputs(sum_cell = list(code = 1L, source = 1L), sum_text = "Zellentext A",
                      sum_save_btn = 1L)
    expect_equal(qda_summaries(code = 1, source = 1)$text_, "Zellentext A")
    sd <- as_html(output$sum_detail)
    expect_true(grepl("Zellentext A", sd, fixed = TRUE))
  })
})

test_that("qda_app refuses to start without an open project / shiny", {
  qda_close()
  expect_error(jellyqda::qda_app(), "qda_open")
})

test_that("qda_app opens in a new window by default (new_window = TRUE)", {
  expect_true("new_window" %in% names(formals(jellyqda::qda_app)))
  expect_true(formals(jellyqda::qda_app)$new_window)
})

test_that("qda_app UI has the flexible pane layout (draggable panels, handles, presets)", {
  skip_if_not_installed("shiny")
  new_project()
  on.exit(qda_close(), add = TRUE)
  rt <- htmltools::renderTags(jellyqda:::.jellyqda_ui())
  ui <- paste(rt$head, rt$html, collapse = "\n")
  expect_true(grepl('class="appgrid"', ui, fixed = TRUE))
  expect_true(grepl("colhandle", ui, fixed = TRUE))
  expect_true(grepl('data-pane="left"', ui, fixed = TRUE))
  expect_true(grepl('data-pane="center"', ui, fixed = TRUE))
  expect_true(grepl('data-pane="right"', ui, fixed = TRUE))
  for (pid in c("panel-docs", "panel-codes", "panel-matrix", "panel-browser",
                "panel-segs", "panel-memos", "panel-summary")) {
    expect_true(grepl(paste0('id="', pid, '"'), ui, fixed = TRUE))
  }
  expect_true(grepl('draggable="true"', ui, fixed = TRUE))
  expect_false(grepl("layout_preset", ui, fixed = TRUE))  # sizing dropdown removed
  expect_true(grepl("localStorage", ui, fixed = TRUE))
  # fixed symbol bar: panel collapse toggles (7) + dark/help/close; NO side collapse
  expect_true(grepl("symbolbar", ui, fixed = TRUE))
  expect_true(grepl("data-closeapp", ui, fixed = TRUE))
  expect_equal(length(gregexpr('data-toggle="panel-', ui, fixed = TRUE)[[1]]), 14)  # 7 in bar + 7 in heads
  expect_true(grepl("panel.collapsed", ui, fixed = TRUE))  # collapse CSS + JS
  expect_false(grepl("data-side=", ui, fixed = TRUE))      # left/right side collapse stays removed
  expect_false(grepl("setSide", ui, fixed = TRUE))
  # panel headers: icon left, label right (hlabel), resize handles between columns
  expect_equal(length(gregexpr('class="hlabel"', ui, fixed = TRUE)[[1]]), 7)
  expect_equal(length(gregexpr('class="colhandle"', ui, fixed = TRUE)[[1]]), 2)
  # document browser + segments can never be dragged into a side column
  expect_true(grepl("dragEl.id === 'panel-browser'", ui, fixed = TRUE))
  # inline edit handler for memo entries + no free-memo form in the static UI
  expect_true(grepl("[data-editmemo]", ui, fixed = TRUE))
  expect_false(grepl('id="memo_text"', ui, fixed = TRUE))
  # new controls: undo, dark mode, help, zoom, search, variables
  expect_true(grepl('id="undo_btn"', ui, fixed = TRUE))
  expect_true(grepl('id="saved_line"', ui, fixed = TRUE))
  expect_true(grepl('data-dark="1"', ui, fixed = TRUE))
  expect_true(grepl('data-help="1"', ui, fixed = TRUE))
  expect_true(grepl('data-zoom="0.1"', ui, fixed = TRUE))
  expect_true(grepl('id="search_q"', ui, fixed = TRUE))
  expect_true(grepl('id="var_doc"', ui, fixed = TRUE))
  # new JS: shortcuts, zoom, seg click, search jump, reparent, file drop, resume
  expect_true(grepl("keydown", ui, fixed = TRUE))
  expect_true(grepl("seg_click", ui, fixed = TRUE))
  expect_true(grepl("goto_pos", ui, fixed = TRUE))
  expect_true(grepl("reparent_code", ui, fixed = TRUE))
  expect_true(grepl("scrollToChar", ui, fixed = TRUE))
  expect_true(grepl("jellyqda_last_src", ui, fixed = TRUE))
  expect_true(grepl("data-bs-theme", ui, fixed = TRUE))
  # doc rows carry a progress bar, code rows are draggable with data-codeid
  expect_true(grepl("pbar", ui, fixed = TRUE))
  # backup / export / layout-reset grouped in one button section
  expect_true(grepl("btnsection", ui, fixed = TRUE))
  expect_true(grepl('id="backup_btn"', ui, fixed = TRUE))
  expect_true(grepl('id="export_btn"', ui, fixed = TRUE))
  expect_true(grepl('id="layout_reset"', ui, fixed = TRUE))
  # memo text field is NOT in the static top bar (it lives in the server-rendered
  # selection action bar, checked in the testServer test below)
  expect_false(grepl('id="memo_field"', ui, fixed = TRUE))
  expect_true(grepl("memomark.sel", ui, fixed = TRUE))
})

test_that("code tree, coding bar, recode and report link (codes + subcodes)", {
  skip_if_not_installed("shiny")
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(ext("interview_01.txt"))
  qda_code_add("Berufsweg", color = "#E69F00", description = "Stationen des Werdegangs")
  qda_code_add("KMU", parent = "Berufsweg")
  qda_code_add("Familie", parent = "KMU")
  qda_code_add("Ambivalenz")
  qda_code(1, "KMU", start = 10L, end = 30L)
  qda_code(1, "Berufsweg", start = 40L, end = 60L)
  as_html <- function(x) htmltools::renderTags(x)$html

  shiny::testServer(jellyqda:::.jellyqda_server, {
    session$setInputs(open_source = 1L)
    # tree: nested list, family colour as --c, subcode rows, Sigma with subcodes
    ct <- as_html(output$code_tree)
    expect_true(grepl('class="ctree"', ct, fixed = TRUE))
    expect_true(grepl('class="cnode lvl1" data-cnode="1" style="--c:#E69F00"', ct, fixed = TRUE))
    expect_true(grepl('class="cnode lvl2" data-cnode="2" style="--c:#E69F00"', ct, fixed = TRUE))
    expect_true(grepl('class="cnode lvl3" data-cnode="3"', ct, fixed = TRUE))
    expect_true(grepl("Σ 2", ct, fixed = TRUE))            # Berufsweg: 1 own + 1 KMU
    expect_true(grepl('data-addsub="1"', ct, fixed = TRUE))      # "+ Subcode"
    expect_false(grepl('data-addsub="3"', ct, fixed = TRUE))     # max. 3 levels
    expect_true(grepl('data-codecolor="1"', ct, fixed = TRUE))   # colour only on top level
    expect_false(grepl('data-codecolor="2"', ct, fixed = TRUE))
    expect_true(grepl('data-nsub="2" data-ncod="2"', ct, fixed = TRUE))  # for the delete question

    # coding bar: root chips, subline with "(nur Code)" + subcodes, search list
    session$setInputs(selection = list(start = 70L, end = 90L, text = "x"))
    ab <- as_html(output$actionbar)
    expect_true(grepl('data-openroot="1"', ab, fixed = TRUE))    # Berufsweg has subcodes
    expect_true(grepl('class="codebtn rootchip" data-codeid="4"', ab, fixed = TRUE))  # Ambivalenz codes directly
    expect_true(grepl('data-subfor="1"', ab, fixed = TRUE))
    expect_true(grepl("(nur Code)", ab, fixed = TRUE))
    expect_true(grepl('data-path="berufsweg / kmu / familie"', ab, fixed = TRUE))
    expect_true(grepl("Stationen des Werdegangs", ab, fixed = TRUE))  # definition
    expect_true(grepl('id="code_search"', ab, fixed = TRUE))

    # clicking a code in the tree while text is marked codes the marked text
    session$setInputs(sel_code = 3L)
    cod <- qda_codings()
    expect_equal(nrow(cod), 3)
    expect_equal(cod$code_id[cod$start == 70L], 3L)
    expect_null(output$actionbar)

    # search field: Enter without hit -> new top-level code + coding
    session$setInputs(selection = list(start = 100L, end = 120L, text = "y"))
    session$setInputs(add_code_assign = list(label = "Neu aus Suche"))
    expect_true("Neu aus Suche" %in% qda_codes()$label)
    expect_equal(nrow(qda_codings()), 4)

    # recode: click a coding -> family chips -> recode to the subcode
    cid <- qda_codings()$id[qda_codings()$start == 40L]
    session$setInputs(clicked_coding = cid)
    cb <- as_html(output$clicked_bar)
    expect_true(grepl('data-recode="2"', cb, fixed = TRUE))
    expect_true(grepl("recodebtn cur", cb, fixed = TRUE))
    session$setInputs(recode_coding = 2L)
    expect_equal(qda_codings()$code_id[qda_codings()$id == cid], 2L)
    session$setInputs(undo_btn = 1L)
    expect_equal(qda_codings()$code_id[qda_codings()$id == cid], 1L)

    # retrieved segments of a code include its subcodes
    session$setInputs(selection = NULL)
    session$setInputs(sel_code = 1L)
    expect_true(grepl("+ Subcodes (3)", as_html(output$seg_head), fixed = TRUE))

    # matrix in tree order with ancestors for collapsing
    mx <- as_html(output$matrix_panel)
    expect_true(grepl('data-mxrow="3" data-anc="2 1"', mx, fixed = TRUE))

    # subcode codings: tint + underline + label tag (data-tag, no DOM text)
    d <- as_html(output$doc)
    expect_true(grepl('class="sub tagstart"', d, fixed = TRUE))
    expect_true(grepl('data-tag="KMU"', d, fixed = TRUE))
    expect_true(grepl("rgba(230,159,0,0.3)", d, fixed = TRUE))

    # save button writes a backup; report link points to a session URL
    n_ev <- nrow(qda_events())
    session$setInputs(save_btn = 1L)
    expect_true(any(grepl("backup", qda_events()$action[-seq_len(n_ev)])))
  })
  # the report tab is served fresh on every request
  r <- jellyqda:::.report_response()
  expect_equal(r$status, 200L)
  expect_true(grepl("text/html", r$content_type, fixed = TRUE))
  expect_true(grepl("Berufsweg", r$content, fixed = TRUE))
})

test_that("qda_coding_recode and qda_code_set_color are undoable", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(ext("interview_01.txt"))
  qda_code_add("A", color = "#E69F00")
  qda_code_add("A1", parent = "A")
  expect_equal(qda_codes()$color[qda_codes()$label == "A1"], "#E69F00")  # inherits
  qda_code(1, "A", start = 5L, end = 9L)
  id <- qda_codings()$id[1]
  qda_coding_recode(id, "A1")
  expect_equal(qda_codings()$code_id, 2L)
  qda_undo()
  expect_equal(qda_codings()$code_id, 1L)
  qda_code_set_color("A", "#0072B2")
  expect_equal(unique(qda_codes()$color), "#0072B2")
  qda_undo()
  expect_equal(unique(qda_codes()$color), "#E69F00")
  expect_error(qda_code_set_color("A", "blau"), "hex")
  # the helper keeps tree order and depth
  tr <- jellyqda:::.code_tree(qda_codes())
  expect_equal(tr$label, c("A", "A1"))
  expect_equal(tr$depth, c(1L, 2L))
})
