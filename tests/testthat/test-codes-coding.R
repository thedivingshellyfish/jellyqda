test_that("codes form a tree with paths; duplicates under same parent rejected", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_code_add("Werdegang")
  qda_code_add("KMU", parent = "Werdegang")
  qda_code_add("Konzern", parent = "Werdegang")
  qda_code_add("KMU")  # different parent -> allowed
  codes <- qda_codes()
  expect_equal(nrow(codes), 4)
  expect_equal(codes$path[codes$label == "KMU" & codes$parent_id == 1][1], "Werdegang / KMU")
  expect_error(qda_code_add("KMU", parent = "Werdegang"), "already exists")
})

test_that("rename and delete are audited", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_code_add("Alt")
  qda_code_rename("Alt", "Neu")
  expect_equal(qda_codes()$label, "Neu")
  qda_code_add("Kind", parent = "Neu")
  qda_import(ext("interview_01.txt"))
  qda_code(1, segment = 1, code = "Kind")
  del <- qda_code_delete("Neu")
  expect_equal(del$codes_deleted, 2)
  expect_equal(del$codings_deleted, 1)
  expect_equal(nrow(qda_codes()), 0)
  expect_equal(nrow(qda_codings()), 0)
  ev <- DBI::dbGetQuery(qda_con(), "SELECT action FROM events")$action
  expect_true(all(c("code_rename", "code_delete", "coding_add") %in% ev))
})

test_that("qda_codings filters and extracts text; coding_delete removes one", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(c(ext("interview_01.txt"), ext("interview_02.md")))
  qda_code_add("A"); qda_code_add("B")
  qda_code(1, segment = 1, code = "A")
  qda_code(2, segment = 2, code = "B")
  qda_code(1, segment = 3, code = "B")
  expect_equal(nrow(qda_codings()), 3)
  expect_equal(nrow(qda_codings(code = "B")), 2)
  expect_equal(nrow(qda_codings(source = 2)), 1)
  expect_true(all(nchar(qda_codings()$text) > 0))
  id <- qda_codings(code = "A")$id
  qda_coding_delete(id)
  expect_equal(nrow(qda_codings()), 2)
})

test_that("memos work and are audited", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_memo_add("Leitfaden-Frage 3 nachschärfen")
  m <- qda_memos()
  expect_equal(nrow(m), 1)
  expect_equal(m$text_, "Leitfaden-Frage 3 nachschärfen")
  ev <- DBI::dbGetQuery(qda_con(), "SELECT action FROM events")$action
  expect_true("memo_add" %in% ev)
})

test_that("qda_memo_delete removes a memo and is audited", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_memo_add("eins"); qda_memo_add("zwei")
  qda_memo_delete(1)
  expect_equal(qda_memos()$text_, "zwei")
  expect_error(qda_memo_delete(99), "No memo")
  ev <- DBI::dbGetQuery(qda_con(), "SELECT action FROM events")$action
  expect_true("memo_delete" %in% ev)
})
