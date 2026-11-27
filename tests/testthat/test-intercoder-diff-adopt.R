# Disagreements and consensus (R/intercoder_diff.R, R/intercoder_adopt.R)

test_that("qda_intercoder_diff() and qda_intercoder_adopt() (one undo step)", {
  x <- ic_setup(); on.exit(qda_close(), add = TRUE)
  code_seg("KMU", 2); code_seg("Team", 4)
  qda_close(); qda_open(x$pb)
  code_seg("KMU", 2); code_seg("Team", 5)
  r5 <- seg_range(5)
  qda_code(1, "Team", start = r5[1], end = r5[1] + 9L)     # a second, overlapping coding
  qda_close(); qda_open(x$pa)

  d <- qda_intercoder_diff(x$pb)
  expect_equal(nrow(d), 2)
  expect_equal(d$coded_by, c("A", "B"))
  expect_equal(d$coder, c("testprojekt", "kodiererin_b"))
  expect_equal(d$segment, c(4L, 5L))
  expect_equal(d$b_codings, c(0L, 2L))
  expect_equal(d$text[2], substring(jellyqda:::.resolve_source(1)$frozen_text, d$start[2], d$end[2]))
  expect_equal(nrow(qda_intercoder_diff(x$pb, code = "Beruf / KMU")), 0)

  n0 <- nrow(qda_codings())
  new <- qda_intercoder_adopt(x$pb, d$source_id[2], d$start[2], d$end[2], d$code[2])
  expect_equal(nrow(new), 2)
  expect_equal(nrow(qda_codings()), n0 + 2)
  expect_true(all(qda_codings()$code[qda_codings()$id %in% new$id] == "Team"))
  expect_equal(nrow(qda_intercoder_diff(x$pb)), 1)          # only A's own disagreement is left
  # again: nothing new (duplicates skipped)
  expect_equal(nrow(qda_intercoder_adopt(x$pb, 1, d$start[2], d$end[2], "Team")), 0)
  expect_error(qda_intercoder_adopt(x$pb, 1, d$start[1], d$end[1], "Team"), "no coding")
  # one undo step removes both
  expect_match(qda_history()$undo, "kodiererin_b")
  qda_undo()
  expect_equal(nrow(qda_codings()), n0)
  # family level: B's subcode codings come along
  qda_close(); qda_open(x$pb); code_seg("KMU", 6); qda_close(); qda_open(x$pa)
  d6 <- qda_intercoder_diff(x$pb, level = "top")
  d6 <- d6[d6$segment == 6L, ]
  expect_equal(d6$code, "Beruf")
  a6 <- qda_intercoder_adopt(x$pb, 1, d6$start, d6$end, "Beruf", level = "top")
  expect_equal(qda_codings()$code[qda_codings()$id == a6$id], "KMU")
})
