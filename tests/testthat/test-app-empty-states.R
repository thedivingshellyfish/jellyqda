# Every output of the app must render without error in "empty" states:
# no documents, no codes, no codings, no memos. (Regression: with no memos
# at all the memo panel showed "arguments imply differing number of rows:
# 1, 0", because paste0("memo_", integer(0)) returns "memo_", not
# character(0).)

app_outputs <- c("doc_tree", "doc", "doc_title", "actionbar", "segbar", "clicked_bar",
                 "code_tree", "seg_head", "seg_panel", "search_results", "var_list",
                 "doc_vars", "matrix_panel", "sum_matrix", "sum_detail", "memo_toolbar",
                 "memo_new_form", "memo_filters", "memos_list", "stats_line", "saved_line")

render_all_outputs <- function(setup) {
  new_project()
  on.exit(qda_close(), add = TRUE)
  setup()
  errors <- character()
  shiny::testServer(jellyqda:::.jellyqda_server, {
    if (nrow(qda_sources()) > 0) session$setInputs(open_source = 1L)
    for (only_doc in c(FALSE, TRUE)) {
      session$setInputs(memo_only_doc = only_doc, memo_search = "")
      for (o in app_outputs) {
        msg <- tryCatch({ output[[o]]; "" }, error = function(e) conditionMessage(e))
        if (nzchar(msg)) errors <<- c(errors, paste0(o, ": ", msg))
      }
    }
  })
  errors
}

test_that("all app outputs render in an empty project", {
  skip_if_not_installed("shiny")
  expect_identical(render_all_outputs(function() NULL), character())
})

test_that("all app outputs render with a document but no codes, codings or memos", {
  skip_if_not_installed("shiny")
  expect_identical(render_all_outputs(function() qda_import(transcript_file())), character())
})

test_that("all app outputs render with codes but no codings or memos", {
  skip_if_not_installed("shiny")
  expect_identical(render_all_outputs(function() {
    qda_import(transcript_file()); qda_code_add("A")
  }), character())
})

test_that("memo panel without memos shows the hint, not an error", {
  skip_if_not_installed("shiny")
  new_project()
  on.exit(qda_close(), add = TRUE)
  shiny::testServer(jellyqda:::.jellyqda_server, {
    html <- htmltools::renderTags(output$memos_list)$html
    expect_true(grepl("Noch keine Memos", html, fixed = TRUE))
    expect_true(grepl('data-memofilter="all"', htmltools::renderTags(output$memo_filters)$html, fixed = TRUE))
  })
})
