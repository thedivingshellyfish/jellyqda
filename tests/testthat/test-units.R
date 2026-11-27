# Units of analysis shared by intercoder and co-occurrence (R/units.R)

test_that(".mark_units() marks every unit a coding touches, also across units", {
  units <- data.frame(source_id = c(1, 1, 1, 2), source = "x", segment = c(1, 2, 3, 1),
                      start = c(1, 11, 21, 1), end = c(10, 20, 30, 50))
  cd <- data.frame(sid = c(1, 1, 2, 1), start = c(5, 18, 40, 31), end = c(12, 19, 45, 35),
                   cat = c("A", "B", "A", "B"))
  M <- jellyqda:::.mark_units(units, cd, c("A", "B"))
  expect_equal(M[, 1], c(TRUE, TRUE, FALSE, TRUE))     # 5-12 touches units 1 and 2
  expect_equal(M[, 2], c(FALSE, TRUE, FALSE, FALSE))   # 31-35 is between units: nothing
  M3 <- jellyqda:::.mark_units(units, cd, c("A", "B"), min_overlap = 3)
  expect_equal(M3[, 1], c(TRUE, FALSE, FALSE, TRUE))   # only 2 characters in unit 2
  expect_equal(dim(jellyqda:::.mark_units(units, cd[0, ], c("A", "B"))), c(4L, 2L))
})

test_that(".mark_units() agrees with a brute-force check on random data", {
  set.seed(3)
  st <- cumsum(sample(5:40, 60, TRUE)); units <- data.frame(source_id = 1, source = "x",
    segment = 1:60, start = st, end = st + sample(1:4, 60, TRUE))
  cd <- data.frame(sid = 1, start = sample(1:1500, 200, TRUE), cat = sample(c("A", "B", "C"), 200, TRUE))
  cd$end <- cd$start + sample(0:60, 200, TRUE)
  M <- jellyqda:::.mark_units(units, cd, c("A", "B", "C"))
  brute <- sapply(c("A", "B", "C"), function(k) vapply(seq_len(nrow(units)), function(u) {
    x <- cd[cd$cat == k, ]
    any(pmin(units$end[u], x$end) - pmax(units$start[u], x$start) + 1 >= 1)
  }, logical(1)))
  expect_equal(unname(M), unname(brute))
})
