# Pseudonymisation at import (R/pseudonymise.R, qda_import(pseudonyms = ),
# qda_import_survey(pseudonyms = ))

test_that("key lists are read from vectors, lines and CSV; longest names first", {
  k <- qda_pseudonyms(c("Anna = [Person A]", "Anna Schmidt = [Person A]", "", "Hamburg=[City 1]"))
  expect_equal(names(k), c("Anna Schmidt", "Hamburg", "Anna"))
  expect_equal(unname(k[["Hamburg"]]), "[City 1]")
  f <- tempfile(fileext = ".csv")
  writeLines(enc2utf8(c("original;replacement", "M\u00fcller;[Person B]", "Ben;[Person C]")), f, useBytes = TRUE)
  k2 <- qda_pseudonyms(f)
  expect_equal(names(k2), c("M\u00fcller", "Ben"))
  expect_identical(qda_pseudonyms(k2), k2)                         # already a key list
  expect_equal(names(qda_pseudonyms(c("Ben" = "[P]"))), "Ben")
})

test_that("replacement: whole words, case, no chains, counts", {
  k <- qda_pseudonyms(c("Anna" = "[Anna-Ersatz]", "Ersatz" = "X", "Ina" = "[I]"))
  r <- jellyqda:::.pseudo_apply("Anna and Martina met Ina. ANNA left.", k)
  expect_equal(r$text, "[Anna-Ersatz] and Martina met [I]. ANNA left.")   # "Ersatz" inside a replacement stays
  expect_equal(unname(r$counts[c("Anna", "Ina")]), c(1L, 1L))
  ki <- qda_pseudonyms(c("Anna" = "[A]"), ignore_case = TRUE)
  expect_equal(jellyqda:::.pseudo_apply("ANNA, anna", ki)$text, "[A], [A]")
  kp <- qda_pseudonyms(c("Ann" = "[A]"), whole_word = FALSE)
  expect_equal(jellyqda:::.pseudo_apply("Anna", kp)$text, "[A]a")
})

test_that("pseudonymised import: text and name replaced, no original copy, no names in the project", {
  p <- new_project(); on.exit(qda_close(), add = TRUE)
  f <- file.path(tempfile(), "interview_Anna_Schmidt.txt"); dir.create(dirname(f))
  writeLines(c("I: Anna Schmidt, how did you start in Hamburg?", "B: Anna is fine. I came from Hamburg with Ben."), f)
  key <- c("Anna Schmidt" = "[Person A]", "Anna" = "[Person A]", "Schmidt" = "[Person A]",
           "Hamburg" = "[City 1]", "Ben" = "[Person B]")
  prev <- qda_pseudonymise_preview(f, key)
  expect_equal(prev$n[prev$original == "Hamburg"], 2L)
  expect_equal(prev$n[prev$original == "Anna"], 2L)              # in the text + in the file name
  expect_message(res <- qda_import(f, pseudonyms = key), "not copied")
  expect_match(res$status, "pseudonymised \\(7 replacements\\)")
  s <- qda_sources()
  expect_equal(s$name, "interview_[Person A]_[Person A].txt")
  txt <- qda_source_segments(1)$text
  expect_false(any(grepl("Anna|Hamburg|Ben|Schmidt", txt)))
  expect_match(txt[1], "[Person A], how did you start in [City 1]", fixed = TRUE)
  expect_false(dir.exists(file.path(dirname(p), "originals")) && length(list.files(file.path(dirname(p), "originals"))) > 0)
  con <- DBI::dbConnect(RSQLite::SQLite(), p); on.exit(DBI::dbDisconnect(con), add = TRUE)
  all_text <- paste(unlist(lapply(DBI::dbListTables(con), function(t) DBI::dbGetQuery(con, sprintf("SELECT * FROM %s", t)))), collapse = " ")
  expect_false(grepl("Anna|Hamburg|Schmidt", all_text))          # not in any table, not in the audit trail
})

test_that("pseudonymised survey import", {
  new_project(); on.exit(qda_close(), add = TRUE)
  f <- file.path(tempfile(), "survey.csv"); dir.create(dirname(f))
  writeLines(c("id,answer,city", "Anna,My colleague Ben helped me a lot in the first weeks.,Hamburg",
               "Ben,Nothing to add really. Anna knows more than I do.,Kiel"), f)
  qda_import_survey(f, text = "answer", vars = "city", id = "id",
                    pseudonyms = c("Anna" = "[P1]", "Ben" = "[P2]", "Hamburg" = "[City 1]"))
  s <- qda_sources()
  expect_equal(s$name, c("survey_[P1]", "survey_[P2]"))
  expect_match(qda_source_segments(1)$text, "My colleague [P2] helped", fixed = TRUE)
  expect_equal(qda_source_vars(1)[["city"]], "[City 1]")
  expect_equal(length(list.files(file.path(dirname(project_path()), "originals"))), 0L)
})
