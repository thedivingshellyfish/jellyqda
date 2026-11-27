# Survey import (R/import_survey.R, R/app_server_survey.R)

survey_file <- function() ext("survey_demo.csv")

test_that("qda_survey_columns() suggests id, open answers, variables, ignore", {
  r <- qda_survey_columns(survey_file())
  role <- stats::setNames(r$role, r$column)
  expect_equal(unname(role["respondent"]), "id")
  expect_equal(unname(role["submitted"]), "ignore")                 # one value per row
  expect_equal(sum(r$role == "text"), 3L)
  expect_true(all(c("age_group", "field_of_study", "semester") %in% r$column[r$role == "variable"]))
  expect_equal(attr(r, "rows"), 12L)
})

test_that("import: one document per respondent, one segment per answer, variables", {
  new_project(); on.exit(qda_close(), add = TRUE)
  res <- qda_import_survey(survey_file())
  expect_equal(nrow(res), 11L); expect_equal(attr(res, "skipped"), 1L)   # DEMO_11 answered nothing
  expect_true(all(res$format == "survey"))
  expect_equal(res$name[1], "survey_demo_DEMO_01")
  s <- qda_source_segments(1)
  expect_true(nrow(s) >= 2)
  expect_match(s$text[1], "^Why did you choose your field of study\\?\n")
  v <- qda_source_vars(1)
  expect_true(all(c("age_group", "field_of_study", "semester") %in% names(v)))
  expect_false("submitted" %in% names(v))
  expect_true(file.exists(file.path(project_dir(), "originals", "survey_demo.csv")))
  again <- qda_import_survey(survey_file())                               # nothing twice
  expect_equal(nrow(again), 0L); expect_equal(attr(again, "skipped"), 12L)
})

test_that("pre-coding by question marks exactly the answers (umlauts, line breaks)", {
  new_project(); on.exit(qda_close(), add = TRUE)
  f <- tempfile(fileext = ".csv")
  writeLines(enc2utf8(c("id;gruppe;Was belastet Sie im Studium?;Was würde helfen?",
                        "a1;A;\"Prüfungen übereinander,\r\n\r\nund Nächte ohne Schlaf.\";Mehr Zeit",
                        "a2;B;;Ruhige Lernräume im Gebäude",
                        "a3;A;Gruppenarbeit mit Leuten, die nichts beitragen und spät antworten;")), f, useBytes = TRUE)
  res <- qda_import_survey(f, text = c("Was belastet Sie im Studium?", "Was würde helfen?"),
                           vars = "gruppe", id = "id", code_questions = TRUE, prefix = "s")
  expect_equal(res$name, c("s_a1", "s_a2", "s_a3"))
  cd <- qda_codings()
  expect_equal(nrow(cd), 4L)
  expect_true(all(cd$text %in% c("Prüfungen übereinander,\nund Nächte ohne Schlaf.", "Mehr Zeit",
                                  "Ruhige Lernräume im Gebäude",
                                  "Gruppenarbeit mit Leuten, die nichts beitragen und spät antworten")))
  sub <- qda_codes()$path[grepl(" / ", qda_codes()$path, fixed = TRUE)]
  expect_equal(length(sub), 2L); expect_true(all(grepl("^(Fragen|Questions) / ", sub)))
  expect_equal(qda_source_vars("s_a2")[["gruppe"]], "B")
  # the coded answers can be queried by question and group
  q <- qda_query(all = "Was belastet Sie im Studium?", vars = list(gruppe = "A"))
  expect_equal(sort(q$source), c("s_a1", "s_a3"))
  qda_undo()                                                         # codings by question: one step
  expect_equal(nrow(qda_codings()), 0L)
})

test_that("Excel files (with readxl) and errors", {
  new_project(); on.exit(qda_close(), add = TRUE)
  skip_if_not_installed("writexl"); skip_if_not_installed("readxl")
  x <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(utils::read.csv(survey_file(), check.names = FALSE, colClasses = "character"), x)
  res <- qda_import_survey(x, prefix = "xl")
  expect_equal(nrow(res), 11L)
  expect_error(qda_import_survey(survey_file(), text = "gibt es nicht"), "not in the survey")
  bad <- tempfile(fileext = ".sav"); writeLines("x", bad)
  expect_error(qda_survey_columns(bad), "Unsupported")
})

test_that("app: survey dialog suggests roles, previews and imports", {
  skip_if_not_installed("shiny")
  new_project(); on.exit(qda_close(), add = TRUE)
  as_html <- function(x) htmltools::renderTags(x)$html
  shiny::testServer(jellyqda:::.jellyqda_server, {
    session$setInputs(survey_btn = 1)
    session$setInputs(survey_file = data.frame(name = "survey_demo.csv", size = 1, type = "", datapath = survey_file(),
                                               stringsAsFactors = FALSE))
    setup <- as_html(output$survey_setup)
    expect_true(grepl("12 Personen", setup, fixed = TRUE))
    session$setInputs(survey_id = "respondent", survey_text = c("Why did you choose your field of study?"),
                      survey_vars = "field_of_study", survey_code = TRUE, survey_prefix = "web")
    expect_true(grepl("web_DEMO_01", as_html(output$survey_preview), fixed = TRUE))
    session$setInputs(survey_go = 1)
    expect_equal(nrow(qda_sources()), 11L)
    expect_equal(qda_sources()$name[1], "web_DEMO_01")
    expect_true(nrow(qda_codings()) > 0)
  })
})
