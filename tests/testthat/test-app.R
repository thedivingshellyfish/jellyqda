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
  expect_true(grepl('<div id="doc">', html, fixed = TRUE))
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

    # memo-only button -> coding with reserved "Memo" code (underline mark)
    session$setInputs(selection = list(start = 1L, end = 5L, text = "abc"), memo_field = "kurz")
    session$setInputs(add_memo_only = 1L)
    mc <- qda_codings()
    expect_equal(nrow(mc), 2)  # KMU coding from before + Memo coding
    memo_cod <- mc[mc$code == "Memo", ]
    expect_equal(nrow(memo_cod), 1)
    expect_equal(memo_cod$memo, "kurz")
    expect_equal(memo_cod$start, 1L)
    expect_equal(memo_cod$end, 5L)
    # document renders it as underline mark (memomark, no background)
    session$setInputs(backup_btn = 1L)
    doc_html <- htmltools::renderTags(output$doc)$html
    expect_true(grepl('class="memomark"', doc_html, fixed = TRUE))
    # action bar does not offer the reserved Memo code as a button
    session$setInputs(selection = list(start = 1L, end = 5L, text = "abc"))
    ab <- htmltools::renderTags(output$actionbar)$html
    # selection action bar contains the optional memo text field
    expect_true(grepl('id="memo_field"', ab, fixed = TRUE))
    expect_true(grepl('class="actionbar"', ab, fixed = TRUE))
    memo_id <- qda_codes()$id[qda_codes()$label == "Memo"]
    expect_false(grepl(sprintf('data-codeid="%d"', memo_id), ab, fixed = TRUE))
    # retrieved-segments panel lists the memo passage (clickable, with memo)
    segp <- htmltools::renderTags(output$seg_panel)$html
    expect_true(grepl("data-goto", segp, fixed = TRUE))
    expect_true(grepl("kurz", segp, fixed = TRUE))

    # free-text memo via the memo form
    session$setInputs(memo_text = "Leitfaden-Frage 3 nachschaerfen", memo_save_btn = 1L)
    expect_equal(nrow(qda_memos()), 1)
    expect_equal(qda_memos()$text_[1], "Leitfaden-Frage 3 nachschaerfen")
    # free memo shows in the memos panel (right column) and can be deleted
    session$setInputs(backup_btn = 1L)
    ml <- htmltools::renderTags(output$memos_list)$html
    expect_true(grepl("data-delmemo", ml, fixed = TRUE))
    expect_true(grepl("nachschaerfen", ml, fixed = TRUE))
    session$setInputs(del_memo = qda_memos()$id[1])
    expect_equal(nrow(qda_memos()), 0)

    # add a code via the form
    session$setInputs(new_code_label = "Motivation", new_code_parent = "",
                      new_code_color = "#00FF00", new_code_desc = "d", add_code_btn = 1L)
    expect_true("Motivation" %in% qda_codes()$label)

    # rename + delete via selects
    session$setInputs(ren_code_select = "1", ren_code_label = "WerdegangNeu", rename_code_btn = 1L)
    expect_true("WerdegangNeu" %in% qda_codes()$label)
    mot_id <- as.character(qda_codes()$id[qda_codes()$label == "Motivation"])
    session$setInputs(ren_code_select = mot_id, delete_code_btn = 1L)
    expect_false("Motivation" %in% qda_codes()$label)

    # delete codings via the list button (KMU coding + reserved Memo coding)
    session$setInputs(del_coding = cod$id)
    session$setInputs(del_coding = memo_cod$id)
    expect_equal(nrow(qda_codings()), 0)

    # clicked coding bar
    qda_code(1, segment = 1, code = 1, memo = "springt hierher")
    cid <- qda_codings()$id[1]
    session$setInputs(backup_btn = 1L)   # any app action bumps the tick -> lists re-render
    session$setInputs(clicked_coding = cid)
    expect_true(!is.null(output$clicked_bar))
    # segment rows are navigable (data-goto) and show the memo
    as_html <- function(x) htmltools::renderTags(x)$html
    expect_true(grepl("data-goto", as_html(output$seg_panel), fixed = TRUE))
    expect_true(grepl("springt hierher", as_html(output$seg_panel), fixed = TRUE))
    # code tree rows are selectable (data-selcode); selecting filters segments
    ct <- as_html(output$code_tree)
    expect_true(grepl("data-selcode", ct, fixed = TRUE))
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
    expect_true(grepl("Memo: springt hierher", as_html(output$clicked_bar), fixed = TRUE))
    session$setInputs(del_clicked_coding = 1L)
    expect_equal(nrow(qda_codings()), 0)

    # stats line renders
    expect_true(grepl("Quellen", output$stats_line))

    # free memo via form; per-entry inline edit + save in the memo section
    session$setInputs(memo_text = "erstes Memo", memo_save_btn = 1L)
    mid <- qda_memos()$id[1]
    key <- paste0("memo_", mid)
    session$setInputs(edit_memo_entry = key)
    ml <- as_html(output$memos_list)
    expect_true(grepl(paste0("memo_edit_", key), ml, fixed = TRUE))  # inline editor shown
    do.call(session$setInputs, stats::setNames(list("bearbeitet"), paste0("memo_edit_", key)))
    session$setInputs(save_memo_entry = key)
    expect_equal(qda_memos()$text_[qda_memos()$id == mid], "bearbeitet")
    session$setInputs(cancel_edit = 1L)  # no error

    # memo-marked passage: click entry -> jump + highlight (memomark sel)
    session$setInputs(selection = list(start = 1L, end = 5L, text = "abc"), memo_field = "spring")
    session$setInputs(add_memo_only = 1L)
    mcod <- qda_codings()
    mcod <- mcod[mcod$code == "Memo", ]
    session$setInputs(goto_memo = mcod$id[1])
    doc_html2 <- as_html(output$doc)
    expect_true(grepl('memomark sel', doc_html2, fixed = TRUE))
    expect_true(grepl("data-gotomemo", as_html(output$memos_list), fixed = TRUE))
    # per-entry edit of the memo-marked passage (coding memo)
    ckey <- paste0("cod_", mcod$id[1])
    session$setInputs(edit_memo_entry = ckey)
    do.call(session$setInputs, stats::setNames(list("neu markiert"), paste0("memo_edit_", ckey)))
    session$setInputs(save_memo_entry = ckey)
    expect_equal(qda_codings()$memo[qda_codings()$id == mcod$id[1]], "neu markiert")

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
  # fixed symbol bar with collapse toggles for every window + close button
  expect_true(grepl("symbolbar", ui, fixed = TRUE))
  expect_equal(length(gregexpr('data-toggle="panel-', ui, fixed = TRUE)[[1]]), 14)  # 7 in bar + 7 in heads
  expect_true(grepl("data-closeapp", ui, fixed = TRUE))
  # left/right side-collapse buttons to free space for the document browser
  expect_true(grepl('data-side="left"', ui, fixed = TRUE))
  expect_true(grepl('data-side="right"', ui, fixed = TRUE))
  expect_true(grepl("function setSide", ui, fixed = TRUE))
  expect_true(grepl("sides", ui, fixed = TRUE))  # persisted in localStorage
  # backup / export / layout-reset grouped in one button section
  expect_true(grepl("btnsection", ui, fixed = TRUE))
  expect_true(grepl('id="backup_btn"', ui, fixed = TRUE))
  expect_true(grepl('id="export_btn"', ui, fixed = TRUE))
  expect_true(grepl('id="layout_reset"', ui, fixed = TRUE))
  # memo text field is NOT in the static top bar (it lives in the server-rendered
  # selection action bar, checked in the testServer test below)
  expect_false(grepl('id="memo_field"', ui, fixed = TRUE))
  expect_true(grepl("panel.collapsed", ui, fixed = TRUE))
  expect_true(grepl("memomark.sel", ui, fixed = TRUE))
})
