test_that("qda_open creates a project file with the full schema", {
  p <- new_project()
  on.exit(qda_close(), add = TRUE)
  expect_true(file.exists(p))
  con <- qda_con()
  tables <- DBI::dbGetQuery(con, "SELECT name FROM sqlite_master WHERE type = 'table'")$name
  expect_setequal(tables, c("sources", "codes", "codings", "memos", "events",
                            "summaries", "sqlite_sequence"))
  info <- qda_project()
  expect_s3_class(info, "tbl_df")
  expect_equal(info$project, p)
  expect_equal(info$sources, 0)
})

test_that("reopening a project keeps all data", {
  p <- new_project()
  qda_code_add("Testcode")
  qda_close()
  qda_open(p)
  on.exit(qda_close(), add = TRUE)
  expect_equal(nrow(qda_codes()), 1)
  expect_equal(qda_codes()$label, "Testcode")
})

test_that("API functions fail cleanly without an open project", {
  qda_close()
  expect_error(qda_codes(), "qda_open")
  expect_error(qda_sources(), "qda_open")
  expect_false(qda_is_open())
})

test_that("events audit trail records open/create", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  ev <- qda_events()
  expect_s3_class(ev, "tbl_df")
  expect_true("project_create" %in% ev$action)
  expect_true(all(nzchar(ev$created_at)))
})
