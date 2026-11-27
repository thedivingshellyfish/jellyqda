# Server-rendered HTML uses <i class="fa-solid fa-NAME"></i>. The app loads
# no Font Awesome web font (fontawesome::fa() returns SVG), so js/14-icons.js
# swaps each <i> for the SVG of the same name from the hidden icon registry
# (#jq-icons). An icon that is missing there would be invisible (0x0 px) --
# as the memo icon in the code tree was before this test existed.

test_that("every icon used in server-rendered HTML is in the icon registry", {
  skip_if_not_installed("shiny")
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(transcript_file(), segments = "speaker")
  qda_code_add("A")
  qda_code(1, "A", start = 100L, end = 150L, memo = "Kommentar")
  qda_memo_add("Projekt")
  qda_memo_add("Dok", source = 1)
  qda_memo_add("Code", code = "A")
  qda_memo_add("Stelle", source = 1, start = 120, end = 140)
  used <- character()
  shiny::testServer(jellyqda:::.jellyqda_server, {
    session$setInputs(open_source = 1L, sel_code = 1L,
                      selection = list(start = 5L, end = 9L, text = "x"))
    session$setInputs(var_doc = "1")
    keys <- c(paste0("memo_", qda_memos()$id), "cod_1")
    for (k in c(NA, keys)) {            # every card once in edit mode
      if (!is.na(k)) session$setInputs(edit_memo_entry = k)
      for (o in c("doc_tree", "code_tree", "memos_list", "memo_toolbar", "memo_filters",
                  "seg_panel", "var_list", "clicked_bar", "actionbar", "segbar", "sum_matrix")) {
        html <- tryCatch(htmltools::renderTags(output[[o]])$html, error = function(e) "")
        used <<- c(used, regmatches(html, gregexpr("fa-solid fa-[a-z0-9-]+", html))[[1]])
      }
    }
  })
  used <- unique(sub("fa-solid fa-", "", used))
  expect_true(length(used) >= 5)                       # the test really saw icons
  expect_true("note-sticky" %in% used)                 # memo icon in code/doc tree
  expect_equal(setdiff(used, jellyqda:::.jq_icon_names()), character())
  # the registry itself renders one SVG per name
  reg <- htmltools::renderTags(jellyqda:::.jq_icon_registry())$html
  for (n in jellyqda:::.jq_icon_names()) {
    expect_true(grepl(sprintf('data-faicon="%s"><svg', n), reg, fixed = TRUE), info = n)
  }
})

test_that("browser-tab icon: jellyqda logo embedded in app and report (offline)", {
  skip_if_not_installed("shiny")
  uri <- jellyqda:::.jq_favicon_uri()
  expect_match(uri, "^data:image/svg\\+xml;base64,")
  svg <- rawToChar(jsonlite::base64_dec(sub("^data:image/svg\\+xml;base64,", "", uri)))
  expect_match(svg, "jellyqda")
  new_project(); on.exit(qda_close(), add = TRUE)
  ui <- htmltools::renderTags(jellyqda:::.jellyqda_ui())
  expect_true(grepl('rel="icon"', paste(ui$head, ui$html), fixed = TRUE))
  expect_true(grepl('rel="icon"', jellyqda:::.report_html(), fixed = TRUE))
})
