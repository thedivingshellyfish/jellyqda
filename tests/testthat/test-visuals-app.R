# Graphics in the app and the report (R/app_server_visuals.R, R/report_visuals.R)

test_that("app: graphics window, pair list, SVG download", {
  skip_if_not_installed("shiny")
  viz_setup(); on.exit(qda_close(), add = TRUE)
  viz_code("A1", 2); viz_code("B", 2); viz_code("C", 3)
  as_html <- function(x) htmltools::renderTags(x)$html
  shiny::testServer(jellyqda:::.jellyqda_server, {
    session$setInputs(viz_unit = "segment", viz_level = "code", viz_measure = "n",
                      viz_min_n = 1, viz_layout = "circle")
    expect_true(grepl("<svg", as_html(output$viz_cooc), fixed = TRUE))
    expect_true(grepl("<circle", as_html(output$viz_net), fixed = TRUE))
    expect_true(grepl("data-jump", as_html(output$viz_portrait), fixed = TRUE))
    session$setInputs(viz_pair = list(a = "A / A1", b = "B", t = 1))
    pl <- as_html(output$viz_pair_list)
    expect_true(grepl("1 Stelle", pl, fixed = TRUE))
    expect_true(grepl('data-jump="1"', pl, fixed = TRUE))
    expect_true(file.exists(output$viz_cooc_svg))
    expect_true(file.exists(output$viz_portrait_svg))
  })
  ui <- htmltools::renderTags(jellyqda:::.jellyqda_ui())$html
  expect_true(grepl('id="visuals_btn"', ui, fixed = TRUE))
})

test_that("report: co-occurrence and portraits sections", {
  viz_setup(); on.exit(qda_close(), add = TRUE)
  expect_false(grepl("Dokument-Portraits", jellyqda:::.report_html(), fixed = TRUE))
  viz_code("A1", 2); viz_code("B", 2)
  html <- jellyqda:::.report_html()
  expect_true(grepl("Code-\u00dcberschneidungen", html, fixed = TRUE))
  expect_true(grepl("Dokument-Portraits", html, fixed = TRUE))
  expect_true(grepl('class="rsvg"', html, fixed = TRUE))
})
