# Report: overview / complete, progress, dialog (R/export.R, R/app_server_report.R,
# R/plot_portrait.R .portrait_merge)

report_setup <- function() {
  viz_setup()
  qda_import(ext("interview_01.txt"))
  viz_code("A1", 2); viz_code("B", 2); viz_code("C", 4)
}

test_that("report: overview leaves out the documents, progress is reported", {
  report_setup(); on.exit(qda_close(), add = TRUE)
  steps <- list()
  full <- jellyqda:::.report_html(progress = function(v, d) steps[[length(steps) + 1]] <<- list(v = v, d = d))
  v <- vapply(steps, `[[`, numeric(1), "v")
  expect_true(all(diff(v) >= 0)); expect_true(all(v >= 0 & v <= 1))
  expect_true(any(grepl("Dokument 2 von 2", vapply(steps, `[[`, character(1), "d"), fixed = TRUE)))
  expect_true(grepl('section class="doc"', full, fixed = TRUE))
  ov <- jellyqda:::.report_html(documents = FALSE)
  expect_false(grepl('section class="doc"', ov, fixed = TRUE))
  expect_true(grepl("\u00dcbersicht ohne die 2 Dokumente", ov, fixed = TRUE))
  expect_true(grepl("Codesystem und H\u00e4ufigkeiten", ov, fixed = TRUE))
  expect_lt(nchar(ov), nchar(full))
  ex <- qda_export("report", report_documents = FALSE)
  expect_false(grepl('section class="doc"', paste(readLines(ex$file, warn = FALSE), collapse = ""), fixed = TRUE))
})

test_that("time estimate and its wording", {
  report_setup(); on.exit(qda_close(), add = TRUE)
  e <- jellyqda:::.report_estimate()
  expect_equal(e$docs, 2L)
  expect_gt(e$chars, 0); expect_gt(e$full, e$overview)
  f <- jellyqda:::.fmt_seconds
  expect_equal(f(1), "unter 2 s"); expect_equal(f(21), "ca. 25 s"); expect_equal(f(130), "ca. 3 min")
})

test_that("report portraits are compact: same coverage, fewer blocks, no click targets", {
  report_setup(); on.exit(qda_close(), add = TRUE)
  x <- qda_portrait(source = 1)
  m <- jellyqda:::.portrait_merge(x)
  expect_lt(length(unique(m$segment)), length(unique(x$segment)))
  span <- function(d) { f <- d[!duplicated(d$segment), ]; c(min(f$pos), max(f$pos + f$width)) }
  expect_equal(span(m), span(x))
  expect_equal(sort(unique(m$code)), sort(unique(x$code)))
  s <- as.character(qda_plot_portrait(x, interactive = FALSE))
  expect_false(grepl('data-jump="1"', s, fixed = TRUE))
  expect_false(grepl("<title>Seg", s, fixed = TRUE))
})

test_that("app: report button opens the dialog; building works for both choices", {
  skip_if_not_installed("shiny")
  report_setup(); on.exit(qda_close(), add = TRUE)
  ui <- htmltools::renderTags(jellyqda:::.jellyqda_ui())$html
  expect_true(grepl('id="report_link"', ui, fixed = TRUE))
  shiny::testServer(jellyqda:::.jellyqda_server, {
    # (the mock session of testServer cannot register the report address, so
    # the button itself is not rendered here; the dialog logic still runs)
    session$setInputs(report_btn = 1)
    expect_silent(session$setInputs(report_make = list(kind = "overview", t = 1)))
    expect_silent(session$setInputs(report_make = list(kind = "full", t = 2)))
  })
  js <- paste(readLines(system.file("app", "www", "js", "19-report.js", package = "jellyqda")), collapse = "\n")
  expect_true(grepl("jellyqdaReportReady", js, fixed = TRUE))
  expect_true(grepl("jqReportStallMs", js, fixed = TRUE))
})
