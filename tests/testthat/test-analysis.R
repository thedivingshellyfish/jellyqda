# Analyse-Werkzeuge (0.6.0): Kodierleitfaden, Codes zusammenfuehren,
# Auto-Codieren, Mayring, Worthaeufigkeiten, KWIC, Fallvergleich, Bericht.

setup_analysis <- function() {
  new_project()
  qda_import(ext("interview_01.txt"))
  qda_code_add("A", color = "#E69F00")
  qda_code_add("A1", parent = "A")
  qda_code_add("B", color = "#56B4E9")
  qda_code_add("B1", parent = "B")
  qda_code_add("A1", parent = "B")        # same label as A/A1 -> merged on merge
  qda_code(1, 2L, start = 5L, end = 20L)  # A / A1
  qda_code(1, "B1", start = 30L, end = 40L)
  qda_code(1, "B", start = 50L, end = 60L)
}

test_that("qda_code_guide sets definition, anchor (appendable) and rule; undo works", {
  setup_analysis(); on.exit(qda_close(), add = TRUE)
  qda_code_guide("B", definition = "Def", anchor = "Bsp 1", rule = "Regel")
  qda_code_guide("B", anchor = "Bsp 2", append_anchor = TRUE)
  b <- qda_codes()[qda_codes()$label == "B", ]
  expect_equal(b$description, "Def")
  expect_equal(b$anchor, "Bsp 1\nBsp 2")
  expect_equal(b$coding_rule, "Regel")
  qda_undo()
  expect_equal(qda_codes()$anchor[qda_codes()$label == "B"], "Bsp 1")
})

test_that("qda_code_merge moves codings + subcodes, merges equal labels, undo restores", {
  setup_analysis(); on.exit(qda_close(), add = TRUE)
  qda_memo_add("Memo zu A", code = "A")
  qda_code_guide("A", definition = "Def A")
  res <- qda_code_merge("A", into = "B")
  expect_equal(res$codings_moved, 1L)
  cc <- qda_codes()
  expect_false("A" %in% cc$label)
  expect_equal(sum(cc$label == "A1"), 1L)                    # A/A1 merged into B/A1
  expect_equal(qda_codings()$code[qda_codings()$start == 5L], "A1")
  expect_equal(qda_memos(kind = "code")$code, "B")
  expect_equal(cc$description[cc$label == "B"], "Def A")
  expect_error(qda_code_merge("B", into = "B1"), "own subcodes")
  qda_undo()
  cc <- qda_codes()
  expect_true(all(c("A", "A1", "B", "B1") %in% cc$label))
  expect_equal(nrow(cc), 5L)
  expect_equal(qda_codings()$code_id[qda_codings()$start == 5L], 2L)
  expect_equal(qda_memos(kind = "code")$code, "A")
})

test_that("qda_autocode codes matches or segments, skips duplicates, one undo step", {
  setup_analysis(); on.exit(qda_close(), add = TRUE)
  n0 <- nrow(qda_codings())
  r <- qda_autocode("Projekt", "A", scope = "match")
  expect_true(nrow(r) >= 1)
  frozen <- DBI::dbGetQuery(qda_con(), "SELECT frozen_text FROM sources")$frozen_text
  expect_true(all(tolower(substring(frozen, r$start, r$end)) == "projekt"))
  expect_equal(nrow(qda_autocode("Projekt", "A", scope = "match")), 0)   # nothing new
  seg <- qda_autocode("Projekt", "B", scope = "segment")
  expect_true(all(seg$end - seg$start > nchar("Projekt")))
  qda_undo(); qda_undo()
  expect_equal(nrow(qda_codings()), n0)
  expect_error(qda_autocode("  ", "A"), "empty")
})

test_that("qda_coding_set_summary stores Mayring paraphrase + generalisation", {
  setup_analysis(); on.exit(qda_close(), add = TRUE)
  id <- qda_codings()$id[1]
  qda_coding_set_summary(id, paraphrase = "P")
  qda_coding_set_summary(id, generalization = "G")
  row <- qda_codings()[qda_codings()$id == id, ]
  expect_equal(c(row$paraphrase, row$generalization), c("P", "G"))
  qda_undo()
  expect_equal(qda_codings()$generalization[qda_codings()$id == id], "")
  # undo of an older action still works with the new columns (NULL-safe)
  qda_code_delete("A")
  qda_undo()
  expect_equal(qda_codings()$paraphrase[qda_codings()$id == id], "P")
})

test_that("qda_words, qda_kwic and qda_case_matrix", {
  setup_analysis(); on.exit(qda_close(), add = TRUE)
  w <- qda_words(n = 10)
  expect_named(w, c("word", "n", "sources"))
  expect_false(any(w$word %in% c("und", "der", "die", "ich")))      # stop words
  expect_true(all(diff(w$n) <= 0))
  wc <- qda_words(code = "B", n = Inf)                               # B + subcode B1
  expect_true(nrow(wc) >= 1)
  k <- qda_kwic("Projektleiterin", width = 15)
  expect_true(nrow(k) >= 1)
  expect_equal(tolower(k$match[1]), "projektleiterin")
  expect_equal(nrow(qda_kwic("Projekt", whole_word = TRUE)), 0)      # only inside words
  expect_true(nrow(qda_kwic("Projekt", whole_word = FALSE)) >= 1)
  qda_source_set_var(1, "Rolle", "PL")
  cm <- qda_case_matrix("Rolle")
  expect_true("PL" %in% names(cm))
  expect_equal(cm$PL[cm$path == "B"], 2L)                            # B + B1
  expect_equal(unname(attr(cm, "n_documents")["PL"]), 1L)
})

test_that("report: margin column with numbered anchors, guide, case comparison, Mayring", {
  setup_analysis(); on.exit(qda_close(), add = TRUE)
  qda_code_guide("B", definition = "Def B", anchor = "Ankerbsp", rule = "Regel B")
  qda_coding_set_summary(qda_codings()$id[1], paraphrase = "Para eins", generalization = "Gen eins")
  qda_coding_set_memo(qda_codings()$id[2], "Kommentar zwei")
  qda_memo_add("Stellenmemo", source = 1, start = 100, end = 120, title = "Idee")
  qda_source_set_var(1, "Rolle", "PL")
  html <- jellyqda:::.report_html()
  expect_true(grepl('class="rseg"', html, fixed = TRUE))
  expect_true(grepl('class="rmargin"', html, fixed = TRUE))
  expect_true(grepl('<span class="anc" style="--c:#E69F00">1</span>', html, fixed = TRUE))
  expect_true(grepl('class="anc memo">M1</span>', html, fixed = TRUE))
  expect_true(grepl("Kommentar zwei", html, fixed = TRUE))
  expect_true(grepl("Fallvergleich", html, fixed = TRUE))
  expect_true(grepl("Ankerbeispiel", html, fixed = TRUE))
  expect_true(grepl("Regel B", html, fixed = TRUE))
  expect_true(grepl("Zusammenfassende Inhaltsanalyse (Mayring)", html, fixed = TRUE))
  expect_true(grepl("Gen eins", html, fixed = TRUE))
  # the app's document HTML still has no anchors (offsets stay exact)
  app <- jellyqda:::.render_doc_html(1)
  expect_false(grepl('class="anc', app, fixed = TRUE))
})

test_that("app: coding fields, anchor, in vivo, merge, autocode, case matrix, analysis", {
  skip_if_not_installed("shiny")
  setup_analysis(); on.exit(qda_close(), add = TRUE)
  qda_source_set_var(1, "Rolle", "PL")
  as_html <- function(x) htmltools::renderTags(x)$html
  shiny::testServer(jellyqda:::.jellyqda_server, {
    session$setInputs(open_source = 1L)
    cid <- qda_codings()$id[qda_codings()$start == 30L]
    session$setInputs(clicked_coding = cid)
    cb <- as_html(output$clicked_bar)
    expect_true(grepl('id="cb_comment"', cb, fixed = TRUE))
    expect_true(grepl('id="cb_para"', cb, fixed = TRUE))
    expect_true(grepl("data-anchorfrom", cb, fixed = TRUE))
    session$setInputs(save_coding_fields = list(id = cid, memo = "neu", paraphrase = "pp", generalization = "gg"))
    row <- qda_codings()[qda_codings()$id == cid, ]
    expect_equal(c(row$memo, row$paraphrase, row$generalization), c("neu", "pp", "gg"))
    session$setInputs(anchor_from_coding = cid)
    expect_true(grepl("interview_01.txt", qda_codes()$anchor[qda_codes()$label == "B1"], fixed = TRUE))

    # in vivo: marked text becomes a top-level code and is coded
    session$setInputs(selection = list(start = 100L, end = 130L, text = "  „Ganz wichtiger Satz“, "))
    expect_true(grepl("data-invivo", as_html(output$actionbar), fixed = TRUE))
    session$setInputs(invivo = 1L)
    expect_true("Ganz wichtiger Satz" %in% qda_codes()$label)
    expect_equal(qda_codings()$code[qda_codings()$start == 100L], "Ganz wichtiger Satz")

    # tree has guide + merge buttons; merge via input
    ct <- as_html(output$code_tree)
    expect_true(grepl("data-guidecode", ct, fixed = TRUE))
    expect_true(grepl("data-mergecode", ct, fixed = TRUE))
    iv <- qda_codes()$id[qda_codes()$label == "Ganz wichtiger Satz"]
    session$setInputs(merge_code = list(from = iv, into = 3L))
    expect_false("Ganz wichtiger Satz" %in% qda_codes()$label)
    session$setInputs(guide_save = list(id = 3L, def = "D", anchor = "", rule = "R"))
    expect_equal(qda_codes()$coding_rule[qda_codes()$id == 3L], "R")

    # search + autocode form
    session$setInputs(search_q = "Projekt", search_btn = 1L)
    expect_true(grepl("data-autocode", as_html(output$search_results), fixed = TRUE))
    n0 <- nrow(qda_codings())
    session$setInputs(autocode = list(code = 4L, scope = "match"))
    expect_true(nrow(qda_codings()) > n0)

    # matrix: variable selector and case comparison
    expect_true(grepl('id="mx_by"', as_html(output$matrix_panel), fixed = TRUE))
    session$setInputs(mx_by = "Rolle")
    expect_true(grepl("PL", as_html(output$matrix_panel), fixed = TRUE))

    # analysis tables
    session$setInputs(words_n = 20, words_src = "", words_code = "")
    expect_true(grepl("data-kwicword", as_html(output$words_table), fixed = TRUE))
    session$setInputs(kwic_q = "Projektleiterin", kwic_src = "", kwic_whole = TRUE)
    expect_true(grepl("data-kwicsrc", as_html(output$kwic_table), fixed = TRUE))
    session$setInputs(may_code = "", may_src = "")
    expect_true(grepl("data-mayid", as_html(output$mayring_table), fixed = TRUE))
    session$setInputs(mayring_save = list(id = cid, field = "paraphrase", value = "aus Tabelle"))
    expect_equal(qda_codings()$paraphrase[qda_codings()$id == cid], "aus Tabelle")
  })
})

test_that(".invivo_label cleans and shortens the marked text", {
  f <- jellyqda:::.invivo_label
  expect_equal(f("  „Das war's halt“. "), "Das war's halt")
  long <- f(paste(rep("Wort", 30), collapse = " "))
  expect_true(nchar(long) <= 61)
  expect_true(endsWith(long, "…"))
})
