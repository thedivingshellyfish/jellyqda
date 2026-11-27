# Import of .txt / .md / .docx / .pdf: encodings, names, originals/ copies,
# re-imports (R/import.R)

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
  expect_true(grepl("project lead", frozen, fixed = TRUE))
  expect_true(stringi::stri_enc_isutf8(charToRaw(frozen)))
  expected <- paste(readLines(ext("interview_01.txt"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  expect_equal(frozen, expected)
})

test_that("qda_import uses provided display names (e.g. original upload names)", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  # simulate a shiny upload: temp datapath named 0.txt, original name given
  tmp <- tempfile(fileext = ".txt")
  file.copy(ext("interview_01.txt"), tmp)
  tmp0 <- file.path(dirname(tmp), "0.txt")
  file.rename(tmp, tmp0)
  res <- qda_import(tmp0, names = "Interview Leitfaden A.txt")
  expect_equal(res$name[1], "Interview Leitfaden A.txt")
  expect_equal(qda_sources()$name[1], "Interview Leitfaden A.txt")
  # original is copied under the display name, meta records it
  expect_true(file.exists(file.path(project_dir(), "originals", "Interview Leitfaden A.txt")))
  meta <- jsonlite::fromJSON(
    DBI::dbGetQuery(qda_con(), "SELECT meta_json FROM sources")$meta_json[1])
  expect_equal(meta$file, "Interview Leitfaden A.txt")
  # names = NULL falls back to basename
  res2 <- qda_import(ext("interview_02.md"))
  expect_equal(res2$name[1], "interview_02.md")
})

test_that("latin1 txt is detected and converted to UTF-8", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(ext("interview_latin1.txt"))
  frozen <- DBI::dbGetQuery(qda_con(), "SELECT frozen_text FROM sources")$frozen_text
  expect_true(grepl("J\u00fcrgen", frozen, fixed = TRUE))   # umlaut decoded correctly
  expect_true(grepl("caf\u00e9", frozen, fixed = TRUE))
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

test_that("different files with the same name get unique names, originals are kept", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  d <- tempfile("same-name-")
  dir.create(file.path(d, "a"), recursive = TRUE)
  dir.create(file.path(d, "b"))
  writeLines(c("Interview A", "", "Text von Person A."), file.path(d, "a", "interview.txt"))
  writeLines(c("Interview B", "", "Text von Person B."), file.path(d, "b", "interview.txt"))
  res <- qda_import(file.path(d, c("a", "b"), "interview.txt"))
  expect_equal(res$name, c("interview.txt", "interview (2).txt"))
  expect_equal(res$status, c("ok", "ok"))
  # both originals exist, each with its own content
  odir <- file.path(project_dir(), "originals")
  expect_equal(readLines(file.path(odir, "interview.txt"))[3], "Text von Person A.")
  expect_equal(readLines(file.path(odir, "interview (2).txt"))[3], "Text von Person B.")
  # both sources can still be addressed by name
  expect_match(jellyqda:::.resolve_source("interview.txt")$frozen_text, "Person A")
  expect_match(jellyqda:::.resolve_source("interview (2).txt")$frozen_text, "Person B")
  # a third file with that name -> "(3)"; the same file again is still skipped
  dir.create(file.path(d, "c"))
  writeLines("Interview C", file.path(d, "c", "interview.txt"))
  expect_equal(qda_import(file.path(d, "c", "interview.txt"))$name, "interview (3).txt")
  expect_match(qda_import(file.path(d, "a", "interview.txt"))$status, "already imported")
  expect_equal(nrow(qda_sources()), 3)
})

test_that(".unique_name keeps free names and counts up taken ones", {
  un <- jellyqda:::.unique_name
  expect_equal(un("x.txt", character()), "x.txt")
  expect_equal(un("x.txt", "x.txt"), "x (2).txt")
  expect_equal(un("x.txt", c("X.TXT", "x (2).txt")), "x (3).txt")   # case-insensitive
  expect_equal(un("notes", "notes"), "notes (2)")                    # no extension
})
