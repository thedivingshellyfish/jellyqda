# The document browser maps a mouse selection to character offsets by
# measuring the text of #doc. That only works if the rendered HTML shows the
# frozen text EXACTLY once, character by character. These tests guard that
# invariant (regression: overlapping codings used to duplicate text, so every
# later coding was stored with shifted offsets).

test_that("rendered document text equals the frozen text (no codings)", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(transcript_file())
  src <- jellyqda:::.resolve_source(1)
  html <- jellyqda:::.render_doc_html(1)
  expect_identical(rendered_text(html), src$frozen_text)
})

test_that("overlapping codings do not duplicate text (regression)", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(transcript_file())
  qda_code_add("A"); qda_code_add("B")
  qda_code(1, "A", start = 120L, end = 160L)
  qda_code(1, "B", start = 140L, end = 200L)   # overlaps A
  src <- jellyqda:::.resolve_source(1)
  expect_identical(rendered_text(jellyqda:::.render_doc_html(1)), src$frozen_text)
})

test_that("random overlapping / nested / identical codings keep the text intact", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(transcript_file(turns = 60))
  qda_code_add("A"); qda_code_add("B"); qda_code_add("C")
  src <- jellyqda:::.resolve_source(1)
  n <- nchar(src$frozen_text)
  set.seed(42)
  for (k in 1:120) {
    s <- sample.int(n - 1L, 1)
    e <- min(n, s + sample(c(0:10, 30:500), 1))
    qda_code(1, sample(c("A", "B", "C"), 1), start = s, end = e)
  }
  qda_code(1, "A", start = 1L, end = n)          # whole document
  qda_code(1, "B", start = 50L, end = 90L)       # identical twice -> "dup"
  qda_code(1, "C", start = 50L, end = 90L)
  html <- jellyqda:::.render_doc_html(1)
  expect_identical(rendered_text(html), src$frozen_text)
  # well-formed: every <mark> is closed
  expect_equal(lengths(regmatches(html, gregexpr("<mark", html))),
               lengths(regmatches(html, gregexpr("</mark>", html))))
})

test_that("a coding stores exactly the selected text, also after overlaps", {
  # simulates what the browser does: offsets are measured in the rendered
  # text, then stored; the stored text must equal the selected text
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(transcript_file())
  qda_code_add("A"); qda_code_add("B")
  qda_code(1, "A", start = 120L, end = 160L)
  qda_code(1, "B", start = 140L, end = 200L)
  shown <- rendered_text(jellyqda:::.render_doc_html(1))
  target <- "(Unverst\u00e4ndliche Stelle)"
  pos <- regexpr(target, shown, fixed = TRUE)
  cid <- qda_code(1, "A", start = pos, end = pos + nchar(target) - 1L)$id
  cc <- qda_codings()
  expect_identical(cc$text[cc$id == cid], target)
})

test_that("umlauts and HTML special characters survive import and rendering", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(transcript_file())
  src <- jellyqda:::.resolve_source(1)
  expect_true(grepl("Nebelgl\u00f6ckchen", src$frozen_text, fixed = TRUE))
  html <- jellyqda:::.render_doc_html(1)
  expect_false(grepl("<Tag>", html, fixed = TRUE))       # escaped in HTML ...
  expect_true(grepl("<Tag>", rendered_text(html), fixed = TRUE))  # ... but shown
})

test_that("overlaps are marked grey with count, coding ids and a number badge", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(transcript_file())
  qda_code_add("A"); qda_code_add("B"); qda_code_add("C")
  a <- qda_code(1, "A", start = 120L, end = 200L)$id
  b <- qda_code(1, "B", start = 150L, end = 250L)$id
  c <- qda_code(1, "C", start = 160L, end = 170L)$id
  html <- jellyqda:::.render_doc_html(1)
  # 150-159: A+B (2), 160-170: A+B+C (3), 171-200: A+B (2 again, new run)
  expect_true(grepl(sprintf('data-cids="%d %d %d" data-n="3"', a, b, c), html, fixed = TRUE))
  expect_equal(lengths(regmatches(html, gregexpr('class="ovl ovl-start', html))), 3)
  # single-coded parts keep the code colour
  expect_true(grepl(sprintf('data-cid="%d" style="background-color:', a), html, fixed = TRUE))
  # popover data: all codings with label/position, as attribute (not text)
  attr_txt <- sub("^<div id=\"doc\" data-codings=\"([^\"]*)\".*", "\\1", html)
  attr_txt <- gsub("&quot;", "\"", attr_txt, fixed = TRUE)
  attr_txt <- gsub("&amp;", "&", attr_txt, fixed = TRUE)
  info <- jsonlite::fromJSON(attr_txt)
  expect_setequal(names(info), as.character(c(a, b, c)))
  expect_equal(info[[as.character(c)]]$start, 160L)
  expect_identical(rendered_text(html), jellyqda:::.resolve_source(1)$frozen_text)
})
