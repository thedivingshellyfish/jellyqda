# Document portraits (R/portrait.R)

test_that("qda_portrait() lists segments in text order with their codes", {
  viz_setup(); on.exit(qda_close(), add = TRUE)
  viz_code("A1", 2); viz_code("B", 2); viz_code("C", 4)
  p <- qda_portrait()
  n_seg <- nrow(jellyqda:::.segments_for(1))
  expect_equal(length(unique(p$segment)), n_seg)
  expect_equal(sort(p$code[p$segment == 2]), c("A", "B"))   # family level
  expect_true(is.na(p$code[p$segment == 1]))
  expect_equal(p$color[p$code %in% "A"][1], "#0072B2")
  first <- p[!duplicated(p$segment), ]
  expect_true(all(diff(first$pos) > 0))                     # text order
  expect_true(all(first$pos >= 0 & first$pos + first$width <= 1 + 1e-9))
  pc <- qda_portrait(level = "code")
  expect_true("A / A1" %in% pc$code)
  expect_equal(nrow(qda_portrait(source = 1)), nrow(p))
})
