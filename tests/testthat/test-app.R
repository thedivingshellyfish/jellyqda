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

    # memo-only button -> free memo with the quoted selection
    session$setInputs(selection = list(start = 1L, end = 5L, text = "abc"))
    session$setInputs(add_memo_only = 1L)
    expect_equal(nrow(qda_memos()), 1)
    expect_true(grepl("Zeichen 1", qda_memos()$text_[1], fixed = TRUE))

    # add a code via the form
    session$setInputs(new_code_label = "Motivation", new_code_parent = "",
                      new_code_color = "#00FF00", new_code_desc = "d", add_code_btn = 1L)
    expect_true("Motivation" %in% qda_codes()$label)

    # rename + delete via selects
    session$setInputs(ren_code_select = "1", ren_code_label = "WerdegangNeu", rename_code_btn = 1L)
    expect_true("WerdegangNeu" %in% qda_codes()$label)
    session$setInputs(ren_code_select = "3", delete_code_btn = 1L)
    expect_false("Motivation" %in% qda_codes()$label)

    # delete a coding via the list button
    session$setInputs(del_coding = cod$id)
    expect_equal(nrow(qda_codings()), 0)

    # clicked coding bar
    qda_code(1, segment = 1, code = 1)
    session$setInputs(clicked_coding = qda_codings()$id[1])
    expect_true(!is.null(output$clicked_bar))
    session$setInputs(del_clicked_coding = 1L)
    expect_equal(nrow(qda_codings()), 0)

    # stats line renders
    expect_true(grepl("Quellen", output$stats_line))
  })
})

test_that("qda_app refuses to start without an open project / shiny", {
  qda_close()
  expect_error(jellyqda::qda_app(), "qda_open")
})
