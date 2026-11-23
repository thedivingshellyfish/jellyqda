# Memos: four kinds, filters, undo, cascade on code delete, migration of the
# old "Memo" pseudo-code, rendering and export.

test_that("the kind follows from the arguments", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(transcript_file())
  qda_code_add("A")
  qda_memo_add("Tagebuch")
  qda_memo_add("Postskript", source = 1)
  qda_memo_add("Definition", code = "A", title = "Def")
  qda_memo_add("Metapher?", source = 1, start = 120, end = 140)
  m <- qda_memos()
  expect_equal(m$kind, c("project", "document", "code", "passage"))
  expect_equal(m$code[3], "A")
  expect_equal(m$title[3], "Def")
  src <- jellyqda:::.resolve_source(1)
  expect_identical(m$passage[4], substring(src$frozen_text, 120, 140))
  expect_equal(nrow(qda_memos(kind = "code")), 1)
  expect_equal(nrow(qda_memos(source = 1)), 2)
  expect_equal(nrow(qda_memos(code = "A")), 1)
})

test_that("invalid memos give clear errors", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(transcript_file())
  expect_error(qda_memo_add("x", source = 1, start = 0, end = 5), "Invalid offsets")
  expect_error(qda_memo_add("x", kind = "code"), "needs `code`")
  expect_error(qda_memo_add("x", kind = "document"), "needs `source`")
  expect_error(qda_memo_update(99, "x"), "No memo")
})

test_that("update changes text and/or title; everything is undoable", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(transcript_file())
  id <- qda_memo_add("alt", source = 1, title = "T")$id
  qda_memo_update(id, title = "T2")
  expect_equal(qda_memos()$text_, "alt")
  expect_equal(qda_memos()$title, "T2")
  qda_memo_update(id, "neu")
  expect_equal(qda_memos()$text_, "neu")
  qda_undo(); qda_undo()
  expect_equal(c(qda_memos()$text_, qda_memos()$title), c("alt", "T"))
  qda_memo_delete(id)
  expect_equal(nrow(qda_memos()), 0)
  qda_undo()
  expect_equal(qda_memos()$kind, "document")
})

test_that("deleting a code removes its code memos -- and undo restores them", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_code_add("A")
  qda_memo_add("Kodierregel", code = "A")
  qda_code_delete("A")
  expect_equal(nrow(qda_memos()), 0)
  qda_undo()
  expect_equal(qda_memos()$code, "A")
})

test_that("old projects: 'Memo' pseudo-codings become passage memos on open", {
  p <- new_project()
  qda_import(transcript_file())
  con <- qda_con()
  # build the old structure by hand (as written by earlier versions)
  qda_code_add("Thema")
  DBI::dbExecute(con, "INSERT INTO codes (label, color, description) VALUES ('Memo', '#999999', 'reserviert')")
  mid <- DBI::dbGetQuery(con, "SELECT id FROM codes WHERE label = 'Memo'")$id
  DBI::dbExecute(con, "INSERT INTO codings (source_id, code_id, start, end, memo) VALUES (1, ?, 120, 140, 'alte Idee')",
                 params = list(mid))
  DBI::dbExecute(con, "INSERT INTO codings (source_id, code_id, start, end, memo) VALUES (1, 1, 150, 160, 'Kommentar')")
  qda_close()

  qda_open(p, auto_snapshot = Inf)
  on.exit(qda_close(), add = TRUE)
  m <- qda_memos()
  expect_equal(m$kind, "passage")
  expect_equal(m$text_, "alte Idee")
  expect_equal(c(m$start, m$end), c(120L, 140L))
  expect_false("Memo" %in% qda_codes()$label)
  expect_equal(qda_codings()$memo, "Kommentar")             # real coding untouched
  expect_true("memo_migrate" %in% qda_events()$action)
  expect_null(qda_history()$undo)                            # undo barrier
  # second open: nothing to do
  qda_close(); qda_open(p, auto_snapshot = Inf)
  expect_equal(sum(qda_events()$action == "memo_migrate"), 1)
  expect_equal(nrow(qda_memos()), 1)
})

test_that("a hand-made 'Memo' code with sub-codes is not migrated", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_code_add("Memo"); qda_code_add("Unter", parent = "Memo")
  expect_equal(jellyqda:::.migrate_memo_codings(), 0L)
  expect_true("Memo" %in% qda_codes()$label)
})

test_that("passage memos are underlined in the text; text stays intact", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(transcript_file())
  qda_code_add("A")
  qda_code(1, "A", start = 100L, end = 200L)
  id <- qda_memo_add("Idee", source = 1, start = 150, end = 250)$id
  html <- jellyqda:::.render_doc_html(1, sel_mid = id)
  expect_true(grepl(sprintf('class="memomark sel" data-mid="%d"', id), html, fixed = TRUE))
  expect_identical(rendered_text(html), jellyqda:::.resolve_source(1)$frozen_text)
  # memos do not count as codings / codes
  expect_equal(nrow(qda_codings()), 1)
  expect_equal(nrow(qda_codes()), 1)
})

test_that("HTML report groups memos by kind", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(transcript_file())
  qda_code_add("A")
  qda_memo_add("Tagebuch")
  qda_memo_add("Regel", code = "A")
  qda_memo_add("Idee", source = 1, start = 120, end = 140)
  html <- jellyqda:::.report_html()
  expect_true(grepl("Projekt-Memos (1)", html, fixed = TRUE))
  expect_true(grepl("Code-Memos (1)", html, fixed = TRUE))
  expect_true(grepl("Textstellen-Memos (1)", html, fixed = TRUE))
  expect_false(grepl("Dokument-Memos", html, fixed = TRUE))
})
