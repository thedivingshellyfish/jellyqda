# Undo / redo (history.R): every content change must be revertible and
# re-applicable, and undo -> redo must give back exactly the same state.

setup_rich_project <- function() {
  new_project()
  qda_import(transcript_file())
  qda_code_add("Eltern")
  qda_code_add("Kind", parent = "Eltern")
  qda_code(1, "Eltern", start = 10L, end = 50L)
  qda_code(1, "Kind", start = 60L, end = 90L, memo = "m1")
  qda_summary_set("Kind", 1, "Zusammenfassung")
  qda_source_set_var(1, "Alter", "34")
  qda_memo_add("freies Memo")
}

test_that("code_delete is undoable incl. sub-codes, codings and summaries", {
  setup_rich_project()
  on.exit(qda_close(), add = TRUE)
  before <- project_state()
  qda_code_delete("Eltern")
  expect_equal(nrow(qda_codes()), 0)
  expect_equal(nrow(qda_codings()), 0)
  expect_equal(nrow(qda_summaries()), 0)
  expect_match(qda_history()$undo, "Code gel\u00f6scht")
  qda_undo()
  expect_identical(project_state(), before)
  qda_redo()
  expect_equal(nrow(qda_codes()), 0)
  qda_undo()
  expect_identical(project_state(), before)
})

test_that("variables, summaries, memos, renames and moves are undoable", {
  setup_rich_project()
  on.exit(qda_close(), add = TRUE)
  before <- project_state()
  qda_source_set_var(1, "Alter", "35")
  qda_source_del_var(1, "Alter")
  qda_summary_set("Kind", 1, "neu")
  qda_memo_update(1, "geaendert")
  qda_coding_set_memo(2, "m2")
  qda_code_rename("Kind", "Kind2")
  qda_code_move("Kind2", NULL)
  qda_coding_delete(1)
  after <- project_state()
  for (i in 1:8) qda_undo()
  expect_identical(project_state(), before)
  for (i in 1:8) qda_redo()
  expect_identical(project_state(), after)
})

test_that("a new action clears the redo list", {
  setup_rich_project()
  on.exit(qda_close(), add = TRUE)
  qda_undo()
  expect_false(is.null(qda_history()$redo))
  qda_code_add("Neu")
  expect_null(qda_history()$redo)
  expect_equal(qda_redo()$redone, "nothing")
})

test_that("undo walks back to an empty project and stops there", {
  setup_rich_project()
  on.exit(qda_close(), add = TRUE)
  repeat if (qda_undo()$undone == "nothing") break
  expect_equal(nrow(qda_codes()), 0)
  expect_equal(nrow(qda_codings()), 0)
  expect_equal(nrow(qda_memos()), 0)
  expect_equal(length(qda_source_vars(1)), 0)
  expect_null(qda_history()$undo)
})

test_that("undo/redo survive closing and reopening the project", {
  p <- new_project()
  qda_import(transcript_file())
  qda_code_add("A")
  qda_code(1, "A", start = 5L, end = 20L)
  qda_undo()
  qda_close()
  qda_open(p, auto_snapshot = Inf)
  on.exit(qda_close(), add = TRUE)
  expect_match(qda_history()$redo, "Coding hinzugef\u00fcgt")
  qda_redo()
  expect_equal(nrow(qda_codings()), 1)
})

test_that("events from older versions (no snapshot) still use the old undo", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(transcript_file())
  qda_code_add("A")
  con <- qda_con()
  # simulate an old-style coding_add event without snapshot
  DBI::dbExecute(con, "INSERT INTO codings (source_id, code_id, start, end, memo) VALUES (1, 1, 5, 9, '')")
  id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
  jellyqda:::log_event("coding_add", list(coding_id = id, source_id = 1, code_id = 1,
                                          start = 5, end = 9, memo = ""))
  r <- qda_undo()
  expect_equal(r$undone, "coding_add")
  expect_equal(nrow(qda_codings()), 0)
  expect_error(qda_redo(), "jellyqda-Version")   # no umlaut: locale-independent
  # old-style code_delete has no data -> skipped, never blocks the stack
  jellyqda:::log_event("code_delete", list(code_id = 99, label = "weg"))
  expect_match(qda_history()$undo, "Code angelegt")
})
