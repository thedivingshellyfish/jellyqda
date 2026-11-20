test_that("qda_memo_update overwrites a memo and is audited", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_memo_add("alt")
  qda_memo_update(1, "neu")
  expect_equal(qda_memos()$text_, "neu")
  expect_error(qda_memo_update(99, "x"), "No memo")
  ev <- DBI::dbGetQuery(qda_con(), "SELECT action FROM events")$action
  expect_true("memo_update" %in% ev)
})

test_that("summary grid cells: set/get/overwrite, audited", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(ext("interview_01.txt"))
  qda_code_add("A")
  qda_summary_set("A", 1, "erste Fassung")
  qda_summary_set("A", "interview_01.txt", "ueberschrieben")
  s <- qda_summaries()
  expect_equal(nrow(s), 1)
  expect_equal(s$text_, "ueberschrieben")
  expect_equal(qda_summaries(code = "A", source = 1)$text_, "ueberschrieben")
  expect_equal(nrow(qda_summaries(code = "A")), 1)
  ev <- DBI::dbGetQuery(qda_con(), "SELECT action FROM events")$action
  expect_true(all(c("summary_set") %in% ev))
  # table exists in schema
  tables <- DBI::dbGetQuery(qda_con(), "SELECT name FROM sqlite_master WHERE type='table'")$name
  expect_true("summaries" %in% tables)
})
