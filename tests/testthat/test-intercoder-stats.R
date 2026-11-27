# Agreement measures (R/intercoder_stats.R)

test_that("agreement statistics match textbook values", {
  st <- jellyqda:::.ic_stats
  # Krippendorff (2011, 'Computing Krippendorff's alpha', binary example): alpha = 0.095
  s <- st(1, 1, 3, 5)
  expect_equal(round(s$alpha, 3), 0.095)
  expect_equal(s$agreement, 0.6)
  expect_equal(round(s$kappa, 4), round((0.6 - 0.56) / 0.44, 4))
  # hand-computed: po = .7, pe = .5 -> kappa = .4; BP = 2po - 1
  s <- st(20, 5, 10, 15)
  expect_equal(s$kappa, 0.4); expect_equal(s$kappa_bp, 0.4); expect_equal(s$agreement, 0.7)
  # perfect agreement
  s <- st(4, 0, 0, 6)
  expect_equal(s$kappa, 1); expect_equal(s$alpha, 1)
  # code nobody used: undefined, not NaN
  s <- st(0, 0, 0, 10)
  expect_true(is.na(s$kappa)); expect_true(is.na(s$alpha)); expect_equal(s$agreement, 1)
  expect_false(is.nan(s$kappa))
  # vectorised + ratings after Landis & Koch
  expect_length(st(c(1, 2), c(0, 1), c(0, 1), c(3, 3))$kappa, 2)
  expect_equal(jellyqda:::.ic_rating(c(-0.1, 0.1, 0.3, 0.5, 0.7, 0.9, NA)),
               c("schlecht", "etwas", "ausreichend", "mittelm\u00e4\u00dfig", "substanziell",
                 "fast vollkommen", NA))
})
