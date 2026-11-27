# Code co-occurrence (R/cooccurrence.R)

test_that("qda_cooccurrence() counts codes in the same segment", {
  viz_setup(); on.exit(qda_close(), add = TRUE)
  viz_code("A1", 2); viz_code("B", 2)          # A1 + B together
  viz_code("A1", 3); viz_code("B", 3, 5)       # again (B only a few characters)
  viz_code("C", 4); viz_code("B", 5)
  r <- qda_cooccurrence()
  expect_s3_class(r, "tbl_df")
  expect_equal(nrow(r), 1)
  expect_equal(c(r$code_a, r$code_b), c("A / A1", "B"))
  expect_equal(c(r$n, r$n_a, r$n_b), c(2L, 2L, 3L))
  expect_equal(r$jaccard, 2 / 3)
  codes <- attr(r, "codes")
  expect_equal(codes$code, c("A / A1", "B", "C"))       # tree order, unused 'A' left out
  expect_equal(codes$color[1], "#0072B2")               # family colour
  expect_equal(attr(r, "info")$units, nrow(jellyqda:::.segments_for(1)))
  # code families: A1 counts for A
  top <- qda_cooccurrence(level = "top")
  expect_equal(c(top$code_a, top$code_b), c("A", "B"))
  # documents as units: every pair of used codes is together
  doc <- qda_cooccurrence(unit = "document")
  expect_equal(nrow(doc), 3)
  expect_true(all(doc$n == 1L))
})

test_that("unit = 'overlap' counts overlapping codings only", {
  viz_setup(); on.exit(qda_close(), add = TRUE)
  s <- jellyqda:::.segments_for(1)
  qda_code(1, "A", start = s$start[2], end = s$start[2] + 20)
  qda_code(1, "B", start = s$start[2] + 10, end = s$start[2] + 40)   # overlaps A
  qda_code(1, "C", start = s$start[2] + 30, end = s$start[2] + 50)   # overlaps B, not A
  r <- qda_cooccurrence(unit = "overlap")
  expect_equal(nrow(r), 2)
  expect_setequal(paste(r$code_a, r$code_b), c("A B", "B C"))
  expect_true(all(is.na(r$jaccard)))
  expect_equal(nrow(qda_cooccurrence(unit = "overlap", min_overlap = 12)), 0)
  # same segment: all three together
  expect_equal(nrow(qda_cooccurrence()), 3)
})

test_that("qda_cooccurrence_passages() returns the units with both codes", {
  viz_setup(); on.exit(qda_close(), add = TRUE)
  viz_code("A1", 2); viz_code("B", 2); viz_code("B", 3); viz_code("C", 3)
  p <- qda_cooccurrence_passages("A1", "B")             # label works
  expect_equal(p$segment, 2L)
  expect_equal(p$text, qda_source_segments(1)$text[2])
  expect_equal(nrow(qda_cooccurrence_passages("A / A1", "C")), 0)
  expect_equal(nrow(qda_cooccurrence_passages("A", "B", level = "top")), 1)
  ov <- qda_cooccurrence_passages("B", "C", unit = "overlap")
  expect_equal(nrow(ov), 1)
  expect_error(qda_cooccurrence_passages("gibt es nicht", "B"), "No code")
})

test_that("empty projects give empty results", {
  new_project(); on.exit(qda_close(), add = TRUE)
  expect_equal(nrow(qda_cooccurrence()), 0)
  qda_import(ext("interview_01.txt"))
  expect_equal(nrow(qda_cooccurrence(unit = "overlap")), 0)
  expect_equal(nrow(attr(qda_cooccurrence(), "codes")), 0)
})
