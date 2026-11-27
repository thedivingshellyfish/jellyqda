# Code query (R/query.R, R/app_server_query.R)

query_setup <- function() {
  viz_setup()                                   # helper-visuals.R: codes A (A1), B, C
  qda_import(ext("interview_01.txt"))
  viz_code("A1", 2); viz_code("B", 2)           # seg 2: A1 + B
  viz_code("A", 3);  viz_code("B", 3); viz_code("C", 3)   # seg 3: A + B + C
  viz_code("C", 4)                              # seg 4: C
  qda_code(2, "B", segment = 3)                 # document 2
  qda_source_set_var(1, "role", "nurse"); qda_source_set_var(2, "role", "doctor")
}

test_that("AND / OR / NOT on segments, with and without subcodes", {
  query_setup(); on.exit(qda_close(), add = TRUE)
  expect_equal(qda_query(all = c("A", "B"))$segment, c(2L, 3L))           # A1 counts for A
  expect_equal(qda_query(all = c("A", "B"), subcodes = FALSE)$segment, 3L)
  expect_equal(qda_query(all = c("A", "B"), none = "C")$segment, 2L)
  any <- qda_query(any = c("A1", "C"))
  expect_equal(any$segment[any$source_id == 1], c(2L, 3L, 4L))
  expect_equal(nrow(qda_query(all = "A / A1", any = "C")), 0)
  q <- qda_query(all = "B")
  expect_equal(sort(unique(q$source_id)), c(1L, 2L))
  expect_equal(q$codes[1], "B")
  expect_equal(q$text[1], qda_source_segments(1)$text[2])
  info <- attr(q, "info")
  expect_equal(info$documents, 2L); expect_true(info$units > 5)
})

test_that("variable filter and documents as units", {
  query_setup(); on.exit(qda_close(), add = TRUE)
  expect_equal(unique(qda_query(all = "B", vars = list(role = "nurse"))$source_id), 1L)
  expect_equal(unique(qda_query(all = "B", vars = list(role = c("nurse", "doctor")))$source_id), c(1L, 2L))
  expect_equal(nrow(qda_query(all = "B", vars = list(role = "nobody"))), 0)
  d <- qda_query(all = c("A", "C"), unit = "document")
  expect_equal(d$source_id, 1L); expect_true(is.na(d$segment))
  expect_error(qda_query(none = "C"), "at least one")
  expect_error(qda_query(all = "gibt es nicht"), "No code")
})

test_that("qda_query_to_code(): new code, one undo step, no duplicates", {
  query_setup(); on.exit(qda_close(), add = TRUE)
  h <- qda_query(all = c("A", "B"))
  n0 <- nrow(qda_codings())
  r <- qda_query_to_code(h, "A and B")
  expect_equal(nrow(r), 2)
  expect_true("A and B" %in% qda_codes()$label)
  expect_equal(nrow(qda_codings()), n0 + 2)
  expect_equal(nrow(qda_query_to_code(h, "A and B")), 0)       # already coded
  qda_undo()                                                   # the codings
  expect_equal(nrow(qda_codings()), n0)
  expect_true("A and B" %in% qda_codes()$label)
  r2 <- qda_query_to_code(h, "C")                              # existing code
  expect_equal(unique(r2$code_id), qda_codes()$id[qda_codes()$label == "C"])
})

test_that("app: query tab, hits, save as code, CSV", {
  skip_if_not_installed("shiny")
  query_setup(); on.exit(qda_close(), add = TRUE)
  ui <- htmltools::renderTags(jellyqda:::.query_tab_ui())$html
  expect_true(grepl('id="q_all"', ui, fixed = TRUE))
  expect_true(grepl("role = nurse", ui, fixed = TRUE))
  as_html <- function(x) htmltools::renderTags(x)$html
  shiny::testServer(jellyqda:::.jellyqda_server, {
    session$setInputs(q_all = NULL, q_any = NULL, q_none = NULL, q_vars = NULL, q_unit = "segment", q_sub = TRUE)
    expect_true(grepl("Mindestens einen Code", as_html(output$q_result), fixed = TRUE))
    session$setInputs(q_all = c("A", "B"))
    h <- as_html(output$q_result)
    expect_true(grepl("2 Treffer", h, fixed = TRUE))
    expect_true(grepl('data-jump="1"', h, fixed = TRUE))
    session$setInputs(q_vars = "role = doctor")
    expect_true(grepl("Keine Stelle", as_html(output$q_result), fixed = TRUE))
    session$setInputs(q_vars = NULL, q_code = "AB", q_save = 1)
    expect_true("AB" %in% qda_codes()$label)
    expect_true(file.exists(output$q_csv))
  })
})
