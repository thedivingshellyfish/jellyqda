# Frozen text: offsets stay exact, coding by offsets, stable segment numbers
# (R/import.R, R/coding.R, R/segments.R)

test_that("frozen text is stable and offsets extract exactly the segment text", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(ext("interview_01.txt"))
  con <- qda_con()
  frozen_before <- DBI::dbGetQuery(con, "SELECT frozen_text FROM sources")$frozen_text

  qda_code_add("Beruf")
  qda_code(source = 1, segment = 2, code = "Beruf", memo = "Werdegang")
  seg <- qda_segments("Beruf")
  expect_equal(nrow(seg), 1)

  # the coded text must equal the segment text of the frozen source
  segs <- jellyqda:::.segments_of(frozen_before)
  expect_equal(seg$text, substring(frozen_before, segs$start[2], segs$end[2]))
  expect_equal(seg$start, segs$start[2])
  expect_equal(seg$end, segs$end[2])

  # re-import must not change the frozen text (regression: offsets must not drift)
  qda_import(ext("interview_01.txt"))
  frozen_after <- DBI::dbGetQuery(con, "SELECT frozen_text FROM sources")$frozen_text
  expect_identical(frozen_after, frozen_before)
})

test_that("coding by explicit offsets works and is validated", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(ext("interview_01.txt"))
  qda_code_add("Motivation")
  con <- qda_con()
  frozen <- DBI::dbGetQuery(con, "SELECT frozen_text FROM sources")$frozen_text
  n <- nchar(frozen, type = "chars")
  qda_code(1, "Motivation", start = 10, end = 40)
  seg <- qda_segments("Motivation")
  expect_equal(seg$text, substring(frozen, 10, 40))
  expect_error(qda_code(1, "Motivation", start = 5, end = n + 100), "Invalid offsets")
  expect_error(qda_code(1, "Motivation", start = 50, end = 20), "Invalid offsets")
  expect_error(qda_code(1, "Motivation", segment = 999), "no segment")
  expect_error(qda_code(1, "Motivation"), "Provide either")
})

test_that("segment numbering is deterministic for the same frozen text", {
  t <- "a\n\nb\n\n\nc"
  s1 <- jellyqda:::.segments_of(t)
  s2 <- jellyqda:::.segments_of(t)
  expect_identical(s1, s2)
  expect_equal(s1$segment, 1:3)
  expect_equal(substring(t, s1$start, s1$end), c("a", "b", "c"))
})
