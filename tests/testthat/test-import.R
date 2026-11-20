test_that("all four import formats work and freeze text", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  res <- qda_import(c(ext("interview_01.txt"), ext("interview_02.md"),
                      ext("interview_03.docx"), ext("fieldnotes.pdf")))
  expect_equal(nrow(res), 4)
  expect_true(all(res$status == "ok"))
  expect_true(all(res$chars > 0))
  src <- qda_sources()
  expect_equal(nrow(src), 4)
  expect_setequal(src$format, c("txt", "md", "docx", "pdf"))
  # frozen text is stored, not re-extracted, as valid UTF-8 bytes
  con <- qda_con()
  frozen <- DBI::dbGetQuery(con, "SELECT frozen_text FROM sources WHERE name = 'interview_01.txt'")$frozen_text
  expect_true(grepl("Projektleiterin", frozen, fixed = TRUE))
  expect_true(stringi::stri_enc_isutf8(charToRaw(frozen)))
  expected <- paste(readLines(ext("interview_01.txt"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  expect_equal(frozen, expected)
})

test_that("latin1 txt is detected and converted to UTF-8", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(ext("interview_latin1.txt"))
  frozen <- DBI::dbGetQuery(qda_con(), "SELECT frozen_text FROM sources")$frozen_text
  expect_true(grepl("Jürgen", frozen, fixed = TRUE))   # umlaut decoded correctly
  expect_true(stringi::stri_enc_isutf8(charToRaw(frozen)))
})

test_that("broken PDF (no text layer) imports with a warning, original kept", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  expect_warning(
    res <- qda_import(ext("broken_scan.pdf")),
    "no usable text layer"
  )
  expect_match(res$status, "warning")
  expect_true(file.exists(file.path(project_dir(), "originals", "broken_scan.pdf")))
})

test_that("originals/ copies are made for every import", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(c(ext("interview_01.txt"), ext("interview_03.docx")))
  odir <- file.path(project_dir(), "originals")
  expect_true(file.exists(file.path(odir, "interview_01.txt")))
  expect_true(file.exists(file.path(odir, "interview_03.docx")))
})

test_that("re-importing the same file is skipped (text extracted only once)", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(ext("interview_01.txt"))
  res <- qda_import(ext("interview_01.txt"))
  expect_match(res$status, "already imported")
  expect_equal(nrow(qda_sources()), 1)
})

test_that("unsupported formats are rejected", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  f <- tempfile(fileext = ".xlsx")
  writeLines("x", f)
  expect_error(qda_import(f), "Unsupported format")
})
