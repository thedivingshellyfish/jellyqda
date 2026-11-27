test_that("package source contains no network calls (100% offline guarantee)", {
  # Only possible when the source tree is available (dev / test_local);
  # under R CMD check the installed package has no R/ sources, so skip and
  # rely on the behavioral test below.
  rdir <- normalizePath(file.path(testthat::test_path(), "..", "..", "R"), mustWork = FALSE)
  skip_if_not(dir.exists(rdir))
  files <- list.files(rdir, pattern = "\\.[Rr]$", full.names = TRUE)
  expect_gt(length(files), 0)
  forbidden <- c("https?://", "download\\.file", "\\burl\\s*\\(", "readLines\\(\\s*['\"]http",
                 "\\bcurl\\b", "socketConnection", "new\\.session\\(", "\\bhttr\\b")
  hits <- character()
  for (f in files) {
    lines <- readLines(f, warn = FALSE)
    for (pat in forbidden) {
      m <- grep(pat, lines, value = TRUE)
      m <- m[!grepl("^\\s*#", m)]  # allow URLs inside comments/docs
      # XML namespace identifiers (e.g. SVG) are names, never fetched
      m <- m[!grepl("^\\s*\\.[A-Z_]+_NS <- \"http://www\\.w3\\.org/[0-9]{4}/[a-z]+\"$", m)]
      if (length(m)) hits <- c(hits, sprintf("%s: %s", basename(f), m))
    }
  }
  expect_equal(hits, character())
})

test_that("full coding session works with all network entry points disabled", {
  # Behavioral offline proof: stub the usual network functions so any call
  # would fail loudly, then run a complete coding session.
  testthat::local_mocked_bindings(
    url = function(...) stop("network blocked in test"),
    socketConnection = function(...) stop("network blocked in test"),
    .package = "base"
  )
  testthat::local_mocked_bindings(
    download.file = function(...) stop("network blocked in test"),
    .package = "utils"
  )
  p <- new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(c(ext("interview_01.txt"), ext("interview_02.md"),
               ext("interview_03.docx"), ext("fieldnotes.pdf")))
  qda_code_add("Werdegang"); qda_code_add("KMU", parent = "Werdegang")
  qda_code(1, segment = 2, code = "KMU")
  qda_code(2, segment = 3, code = "Werdegang", memo = "Vertrauen zentral")
  expect_equal(nrow(qda_segments("KMU")), 1)
  expect_gt(qda_stats()$overall$pct_coded, 0)
  expect_true(file.exists(qda_backup(quiet = TRUE)))
  expect_true(nrow(qda_export("audit")) > 0)
})
