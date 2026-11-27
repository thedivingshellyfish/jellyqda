# Intercoder in the report and the app (R/report_intercoder.R,
# R/app_server_intercoder.R)

test_that("report shows the last intercoder check", {
  x <- ic_setup(); on.exit(qda_close(), add = TRUE)
  expect_false(grepl("Intercoder", jellyqda:::.report_html(), fixed = TRUE))
  code_seg("KMU", 2)
  qda_close(); qda_open(x$pb); code_seg("KMU", 2); code_seg("KMU", 3); qda_close(); qda_open(x$pa)
  qda_intercoder(x$pb)
  html <- jellyqda:::.report_html()
  expect_true(grepl("Intercoder-\u00dcbereinstimmung", html, fixed = TRUE))
  expect_true(grepl("Cohens Kappa", html, fixed = TRUE))
  expect_true(grepl("kodiererin_b", html, fixed = TRUE))
  expect_true(grepl("Beruf \u203a KMU", html, fixed = TRUE))
})

test_that("app: intercoder tab, comparison, take over, CSV", {
  skip_if_not_installed("shiny")
  x <- ic_setup(); on.exit(qda_close(), add = TRUE)
  code_seg("KMU", 2)
  qda_close(); qda_open(x$pb); code_seg("KMU", 2); code_seg("Team", 3); qda_close(); qda_open(x$pa)
  as_html <- function(x) htmltools::renderTags(x)$html
  ui <- as_html(jellyqda:::.ic_tab_ui())
  expect_true(grepl('id="ic_file"', ui, fixed = TRUE))
  expect_true(grepl('id="ic_copy"', ui, fixed = TRUE))
  shiny::testServer(jellyqda:::.jellyqda_server, {
    expect_true(grepl("Noch kein Vergleich", as_html(output$ic_result), fixed = TRUE))
    session$setInputs(ic_unit = "segment", ic_level = "code",
                      ic_file = data.frame(name = "kodiererin_b.jellyqda", size = 1,
                                           type = "", datapath = x$pb, stringsAsFactors = FALSE))
    h <- as_html(output$ic_result)
    expect_true(grepl("Cohens Kappa", h, fixed = TRUE))
    expect_true(grepl("kodiererin_b", h, fixed = TRUE))
    expect_true(grepl('data-icadopt="1"', h, fixed = TRUE))
    expect_true(grepl('data-icgoto="1"', h, fixed = TRUE))
    n_ev <- sum(qda_events()$action == "intercoder")
    expect_equal(n_ev, 1)
    r3 <- seg_range(3)
    session$setInputs(ic_adopt = list(src = 1L, start = r3[1], end = r3[2], code = "Team", t = 1))
    expect_true(any(qda_codings()$code == "Team"))
    h2 <- as_html(output$ic_result)
    expect_true(grepl("Keine Abweichungen", h2, fixed = TRUE))
    expect_true(grepl("Konsens", h2, fixed = TRUE))
    expect_equal(sum(qda_events()$action == "intercoder"), n_ev)   # consensus is not logged
    session$setInputs(ic_unit = "document")                      # still consensus: not logged
    expect_equal(sum(qda_events()$action == "intercoder"), n_ev)
    expect_true(grepl("Konsens", as_html(output$ic_result), fixed = TRUE))
    csv <- output$ic_csv
    expect_true(file.exists(csv))
    expect_true(any(grepl("kappa", readLines(csv, warn = FALSE))))
    blind <- output$ic_copy
    expect_true(file.exists(blind))
  })
})

test_that("app: English labels for the intercoder tab", {
  skip_if_not_installed("shiny")
  old <- jellyqda:::.jq_i18n$lang
  assign("lang", "en", envir = jellyqda:::.jq_i18n)
  on.exit(assign("lang", old, envir = jellyqda:::.jq_i18n), add = TRUE)
  ui <- htmltools::renderTags(jellyqda:::.ic_tab_ui())$html
  expect_true(grepl("Download blind copy", ui, fixed = TRUE))
  expect_true(grepl("Unit of analysis", ui, fixed = TRUE))
  expect_equal(jellyqda:::.ic_rating(0.7), "substantial")
  expect_equal(jellyqda:::.ic_num(0.5), "0.50")
})
