test_that("qda_undo reverts coding_add / coding_delete / coding_memo", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(ext("interview_01.txt"))
  qda_code_add("A")
  qda_code_add("B")
  qda_code(1, "A", start = 10L, end = 40L, memo = "erstes")
  expect_equal(nrow(qda_codings()), 1)
  r1 <- qda_undo()   # undo coding_add
  expect_equal(r1$undone, "coding_add")
  expect_equal(nrow(qda_codings()), 0)
  cid <- qda_code(1, "A", start = 10L, end = 40L, memo = "m1")$id
  qda_coding_set_memo(cid, "geaendert")
  expect_equal(qda_codings()$memo[1], "geaendert")
  qda_undo()         # undo coding_memo
  expect_equal(qda_codings()$memo[1], "m1")
  qda_coding_delete(cid)
  expect_equal(nrow(qda_codings()), 0)
  qda_undo()         # undo coding_delete -> row restored incl. memo
  expect_equal(nrow(qda_codings()), 1)
  expect_equal(qda_codings()$memo[1], "m1")
  expect_equal(qda_codings()$start[1], 10L)
})

test_that("qda_undo walks backwards through history (memo + code actions)", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_code_add("X")
  qda_memo_add("hallo")
  qda_undo()  # undo memo_add
  expect_equal(nrow(qda_memos()), 0)
  qda_undo()  # undo code_add
  expect_false("X" %in% qda_codes()$label)
  r <- qda_undo()  # nothing undoable left (project_create skipped)
  expect_equal(r$undone, "nothing")
  mid <- qda_memo_add("wieder da")$id
  qda_memo_update(mid, "neu")
  expect_equal(qda_memos()$text_[qda_memos()$id == mid], "neu")
  qda_undo()  # undo memo_update
  expect_equal(qda_memos()$text_[qda_memos()$id == mid], "wieder da")
  qda_memo_delete(mid)
  qda_undo()  # undo memo_delete -> restored
  expect_equal(nrow(qda_memos()), 1)
  qda_code_add("Y")
  qda_code_rename("Y", "Z")
  qda_undo()  # undo rename
  expect_true("Y" %in% qda_codes()$label)
})

test_that("qda_code_move re-parents and rejects cycles", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_code_add("A")
  qda_code_add("B", parent = "A")
  qda_code_add("C")
  qda_code_move("C", "B")
  expect_equal(qda_codes()$path[qda_codes()$label == "C"], "A / B / C")
  expect_error(qda_code_move("A", "C"), "sub-codes")
  expect_error(qda_code_move("A", "A"), "own parent")
  qda_code_move("C", NULL)  # back to top level
  expect_equal(qda_codes()$path[qda_codes()$label == "C"], "C")
})

test_that("source variables: set / get / delete, kept in meta_json", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(ext("interview_01.txt"))
  expect_equal(length(qda_source_vars(1)), 0)
  qda_source_set_var(1, "Alter", "32")
  qda_source_set_var(1, "Geschlecht", "w")
  v <- qda_source_vars(1)
  expect_equal(v[["Alter"]], "32")
  expect_equal(v[["Geschlecht"]], "w")
  # other meta fields survive
  m <- jsonlite::fromJSON(DBI::dbGetQuery(qda_con(), "SELECT meta_json FROM sources")$meta_json)
  expect_equal(m$file, "interview_01.txt")
  qda_source_del_var(1, "Alter")
  expect_equal(names(qda_source_vars(1)), "Geschlecht")
})

test_that("qda_export('report') writes a standalone HTML report", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(ext("interview_01.txt"))
  qda_code_add("Werdegang")
  qda_code(1, "Werdegang", start = 10L, end = 40L)
  qda_memo_add("wichtiger Gedanke")
  out <- qda_export("report")
  f <- out$file[out$what == "report"]
  expect_true(file.exists(f))
  html <- paste(readLines(f, warn = FALSE), collapse = "\n")
  expect_true(grepl("<mark", html, fixed = TRUE))
  expect_true(grepl("Werdegang", html, fixed = TRUE))
  expect_true(grepl("wichtiger Gedanke", html, fixed = TRUE))
  expect_true(grepl("Codebuch", html, fixed = TRUE))
  expect_true(grepl("interview_01.txt", html, fixed = TRUE))
})

test_that("HTML report is A4-printable: no colour backgrounds, shares in percent", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(ext("interview_01.txt"))
  qda_code_add("A", color = "#E69F00")
  qda_code_add("A1", parent = "A")
  qda_code_add("B", color = "#56B4E9")
  qda_code(1, "A1", start = 10L, end = 20L)
  qda_code(1, "A", start = 30L, end = 40L)
  qda_code(1, "B", start = 50L, end = 60L)
  qda_code(1, "B", start = 70L, end = 80L)
  html <- jellyqda:::.report_html()
  expect_true(grepl("size:A4", html, fixed = TRUE))
  expect_true(grepl("background:none!important", html, fixed = TRUE))  # marks print without backgrounds
  expect_true(grepl("50,0 %", html, fixed = TRUE))   # A incl. A1 = 2 of 4
  expect_true(grepl("25,0 %", html, fixed = TRUE))   # A1 = 1 of 4
  expect_true(grepl("100,0 %", html, fixed = TRUE))  # total row
  expect_true(grepl("Codesystem und Häufigkeiten", html, fixed = TRUE))
  expect_true(grepl("Codierte Textstellen", html, fixed = TRUE))
  # no filled colour areas in the report's own markup (only borders/lines)
  css <- regmatches(html, regexpr("<style>.*</style>", html))
  expect_false(grepl("background:var(--c)", css, fixed = TRUE))
  # the @page rule (page numbers) must be one line: a line break inside its
  # CSS strings would make the browser drop the whole stylesheet
  expect_true(grepl("@page\\{size:A4[^\n]*counter\\(pages\\)[^\n]*\\}\\}", html))
})
