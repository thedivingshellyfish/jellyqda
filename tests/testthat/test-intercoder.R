# Intercoder comparison (R/intercoder.R, R/intercoder_data.R)

test_that("qda_intercoder(): 2x2 tables per code and overall on segments", {
  x <- ic_setup(); on.exit(qda_close(), add = TRUE)
  n <- nrow(jellyqda:::.segments_for(1))
  # A: KMU on 2, 3; Team on 5
  code_seg("KMU", 2); code_seg("KMU", 3); code_seg("Team", 5)
  qda_close(); qda_open(x$pb)
  # B: KMU on 2 (only a few chars inside the segment), Team on 5 and 6
  code_seg("KMU", 2, shrink = 5L); code_seg("Team", 5); code_seg("Team", 6)
  qda_close(); qda_open(x$pa)

  r <- qda_intercoder(x$pb)
  expect_s3_class(r, "tbl_df")
  expect_equal(r$scope, c("overall", "code", "code"))
  expect_equal(r$code[-1], c("Beruf / KMU", "Team"))          # unused 'Beruf' left out
  kmu <- r[r$code == "Beruf / KMU", ]
  expect_equal(c(kmu$both, kmu$only_a, kmu$only_b, kmu$neither), c(1L, 1L, 0L, n - 2L))
  team <- r[r$code == "Team", ]
  expect_equal(c(team$both, team$only_a, team$only_b, team$neither), c(1L, 0L, 1L, n - 2L))
  ref <- jellyqda:::.ic_stats(1, 1, 0, n - 2)
  expect_equal(kmu$kappa, ref$kappa); expect_equal(kmu$alpha, ref$alpha)
  ov <- r[1, ]
  expect_equal(ov$units, n)
  expect_equal(c(ov$both, ov$only_a, ov$only_b, ov$neither), c(2L, 1L, 1L, 2L * n - 4L))
  expect_equal(ov$mean_kappa, mean(c(kmu$kappa, team$kappa)))
  info <- attr(r, "info")
  expect_equal(info$coder_a, "testprojekt"); expect_equal(info$coder_b, "kodiererin_b")
  expect_equal(length(info$documents), 1)
  # recorded in the audit trail, but not undoable
  expect_equal(utils::tail(qda_events()$action, 1), "intercoder")
  expect_equal(jellyqda:::.ic_last()$overall$units, n)
  expect_false(grepl("Intercoder", qda_history()$undo %||% ""))
  # B's file is never changed
  h <- unname(tools::md5sum(x$pb))
  qda_intercoder(x$pb, log = FALSE); qda_intercoder_diff(x$pb)
  expect_equal(unname(tools::md5sum(x$pb)), h)

  # code families: KMU counts for 'Beruf'
  top <- qda_intercoder(x$pb, level = "top", log = FALSE)
  expect_equal(top$code[-1], c("Beruf", "Team"))
  # documents as units: both coded both codes somewhere -> full agreement
  doc <- qda_intercoder(x$pb, unit = "document", log = FALSE)
  expect_equal(doc$units[1], 1L)
  expect_equal(doc$agreement[-1], c(1, 1))
  expect_true(all(is.na(doc$kappa[-1])))                    # one unit: kappa undefined
  # min_overlap: B's short KMU coding does not count with a high threshold
  strict <- qda_intercoder(x$pb, min_overlap = 1e6, log = FALSE)
  expect_true(all(strict$both == 0L))
})

test_that("documents are matched by text, not by name; missing ones are reported", {
  x <- ic_setup(); on.exit(qda_close(), add = TRUE)
  qda_import(ext("interview_01.txt"))                          # only in A
  code_seg("Team", 2)
  qda_close(); qda_open(x$pb)
  DBI::dbExecute(jellyqda:::qda_con(), "UPDATE sources SET name = 'umbenannt.txt'")
  code_seg("Team", 2)
  qda_close(); qda_open(x$pa)
  r <- qda_intercoder(x$pb, log = FALSE)
  info <- attr(r, "info")
  expect_equal(info$missing_documents, "interview_01.txt")
  expect_equal(r$kappa[r$code == "Team"], 1)
  expect_equal(nrow(qda_intercoder_diff(x$pb)), 0)
  # restricting to one document
  r1 <- qda_intercoder(x$pb, source = 1, log = FALSE)
  expect_equal(attr(r1, "info")$missing_documents, character())
})

test_that("codes only one coder has are included and flagged", {
  x <- ic_setup(); on.exit(qda_close(), add = TRUE)
  qda_close(); qda_open(x$pb)
  qda_code_add("Neu bei B")
  code_seg("Neu bei B", 3)
  qda_close(); qda_open(x$pa)
  r <- qda_intercoder(x$pb, log = FALSE)
  row <- r[r$code == "Neu bei B", ]
  expect_equal(row$only_b, 1L); expect_false(row$in_a); expect_true(row$in_b)
  d <- qda_intercoder_diff(x$pb)
  expect_equal(d$coded_by, "B")
  expect_error(qda_intercoder_adopt(x$pb, 1, d$start, d$end, d$code), "create it first")
})

test_that("errors: missing file, same file, no common documents", {
  x <- ic_setup(); on.exit(qda_close(), add = TRUE)
  expect_error(qda_intercoder(file.path(tempdir(), "gibt-es-nicht.jellyqda")), "not found")
  expect_error(qda_intercoder(x$pa), "active project")
  expect_error(qda_intercoder(), "required")
  # extension may be left out
  expect_s3_class(qda_intercoder(sub("\\.jellyqda$", "", x$pb), log = FALSE), "tbl_df")
  other <- tempfile(fileext = ".jellyqda")
  qda_close(); qda_open(other); qda_import(ext("interview_01.txt")); qda_close(); qda_open(x$pa)
  r <- qda_intercoder(other, log = FALSE)
  expect_equal(length(attr(r, "info")$documents), 0)
  expect_equal(r$units, 0L)
  bad <- tempfile(fileext = ".jellyqda"); writeLines("kein sqlite", bad)
  expect_error(qda_intercoder(bad), "not a jellyqda project")
})
