# English / German user interface (R/i18n.R, R/i18n_catalog.R)

# set the UI language for one test; restored by the caller's on.exit()
set_lang <- function(lang) {
  old <- jellyqda:::.jq_i18n$lang
  assign("lang", lang, envir = jellyqda:::.jq_i18n)
  old
}

pkg_root <- function() {
  # source package (devtools::test / R CMD check) or installed package
  for (p in c(test_path("..", ".."), system.file(package = "jellyqda"))) {
    if (dir.exists(file.path(p, "R")) || dir.exists(file.path(p, "app", "www", "js"))) return(p)
  }
  NULL
}

test_that("every .t() text in the R code has an English translation", {
  root <- test_path("..", "..")
  skip_if_not(dir.exists(file.path(root, "R")), "source files not available")
  keys <- character()
  for (f in list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE)) {
    pd <- utils::getParseData(parse(f, keep.source = TRUE))
    calls <- which(pd$token == "SYMBOL_FUNCTION_CALL" & pd$text == ".t")
    for (i in calls) {
      expr_id <- pd$parent[pd$parent[i] == pd$id][1]          # the call expression
      kids <- pd[pd$parent == expr_id, ]
      arg <- kids$id[kids$token == "expr"][2]                 # first argument
      s <- pd[pd$parent == arg & pd$token == "STR_CONST", "text"]
      if (length(s)) keys <- c(keys, eval(parse(text = s)))
    }
  }
  expect_true(length(keys) > 300)
  missing <- setdiff(unique(keys), names(jellyqda:::.I18N_EN))
  expect_equal(missing, character())
})

test_that("every jqT()/jqF() text in the browser code (app/www/js) has an English translation", {
  js <- list.files(system.file("app", "www", "js", package = "jellyqda"),
                   pattern = "\\.js$", full.names = TRUE)
  expect_true(length(js) > 0)
  src <- paste(unlist(lapply(js, readLines, encoding = "UTF-8", warn = FALSE)), collapse = "\n")
  m <- regmatches(src, gregexpr("jq[TF]\\('((?:[^'\\\\]|\\\\.)*)'", src, perl = TRUE))[[1]]
  lits <- sub("^jq[TF]\\('", "", sub("'$", "", m))
  keys <- vapply(lits, function(x) jsonlite::fromJSON(paste0('["', gsub('"', '\\\\"', x), '"]')), character(1))
  expect_true(length(keys) > 20)
  expect_equal(setdiff(unique(unname(keys)), names(jellyqda:::.I18N_EN)), character())
})

test_that("translations keep the placeholders of the German text", {
  cat <- jellyqda:::.I18N_EN
  ph <- function(x) regmatches(x, gregexpr("%[0-9.]*[sdf%]|\\{[0-9]\\}", x))
  same <- mapply(function(a, b) identical(a, b), ph(names(cat)), ph(unname(cat)))
  expect_equal(names(cat)[!same], character())
})

test_that("qda_language() switches the language; .t() follows it", {
  old_l <- set_lang(NULL); on.exit(set_lang(old_l), add = TRUE)
  old <- getOption("jellyqda.lang"); on.exit(options(jellyqda.lang = old), add = TRUE)
  options(jellyqda.lang = "de")
  expect_equal(qda_language(), "de")
  expect_equal(jellyqda:::.t("Speichern"), "Speichern")
  qda_language("en")
  expect_equal(qda_language(), "en")
  expect_equal(jellyqda:::.t("Speichern"), "Save")
  expect_equal(jellyqda:::.t("unbekannter Text"), "unbekannter Text")
  expect_error(qda_language("fr"), "en")
  expect_equal(jellyqda:::.lang_from_query("?lang=de&x=1"), "de")
  expect_null(jellyqda:::.lang_from_query("?x=1"))
})

test_that("English UI, app outputs and report", {
  skip_if_not_installed("shiny")
  old_l <- set_lang("en"); on.exit(set_lang(old_l), add = TRUE)
  new_project(); on.exit(qda_close(), add = TRUE)
  qda_import(ext("interview_01.txt"))
  qda_code_add("A"); qda_code_add("A1", parent = "A")
  qda_code(1, "A1", start = 10L, end = 30L)
  rt <- htmltools::renderTags(jellyqda:::.jellyqda_ui())
  ui <- paste(rt$head, rt$html)
  expect_true(grepl("Save + create a restore point (Ctrl+S)", ui, fixed = TRUE))
  expect_true(grepl("Documents", ui, fixed = TRUE))
  expect_true(grepl('window.jqLang = "en"', ui, fixed = TRUE))
  expect_true(grepl('data-setlang="de"', ui, fixed = TRUE))
  expect_false(grepl("Speichern", rt$html, fixed = TRUE))
  # German page via ?lang=de
  rt_de <- htmltools::renderTags(jellyqda:::.jellyqda_ui(list(QUERY_STRING = "?lang=de")))
  expect_true(grepl("Speichern", rt_de$html, fixed = TRUE))
  set_lang("en")
  shiny::testServer(jellyqda:::.jellyqda_server, {
    session$setInputs(open_source = 1L, selection = list(start = 40L, end = 60L, text = "x"))
    ab <- htmltools::renderTags(output$actionbar)$html
    expect_true(grepl("Marked: characters 40-60", ab, fixed = TRUE))
    expect_true(grepl("(code only)", ab, fixed = TRUE))
    expect_true(grepl("All saved", output$saved_line, fixed = TRUE))
    expect_true(grepl("sources", output$stats_line, fixed = TRUE))
  })
  html <- jellyqda:::.report_html()
  expect_true(grepl('<html lang="en">', html, fixed = TRUE))
  expect_true(grepl("Code system and frequencies", html, fixed = TRUE))
  expect_true(grepl("Page ' counter(page)", html, fixed = TRUE))
  expect_false(grepl("Codesystem und", html, fixed = TRUE))
  # audit-trail descriptions follow the language of the moment
  qda_code_add("B")
  expect_true(grepl("^Code created", utils::tail(qda_events()$details, 1)) ||
                any(grepl("Code created", qda_events()$details, fixed = TRUE)))
})
