# Segments: rules (blank lines / speaker turns / lines), stored segments,
# split / merge / define, undo, and that codings are never affected.

seg_text <- function(id = 1) {
  s <- qda_source_segments(id)
  s$text
}

test_that("without stored segments the old blank-line segmentation applies", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(ext("interview_01.txt"))
  s <- qda_source_segments(1)
  expect_equal(attr(s, "origin"), "automatisch")
  src <- jellyqda:::.resolve_source(1)
  expect_equal(s$start, jellyqda:::.segments_of(src$frozen_text)$start)
})

test_that("speaker rule: one segment per time-stamped turn, header stays together", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(transcript_file(turns = 12), segments = "speaker")
  s <- qda_source_segments(1)
  expect_equal(attr(s, "origin"), "gespeichert")
  expect_equal(nrow(s), 1 + 12)                         # header + 12 turns
  expect_match(s$text[1], "^DUMMY-TRANSCRIPT")
  expect_match(s$text[1], "Interview-Code", fixed = TRUE)  # header not split
  expect_true(all(grepl("^\\[[0-9:]+\\] [IP]: ", s$text[-1])))
  # the line without speaker label belongs to the last turn
  expect_match(s$text[13], "Unverst\u00e4ndliche Stelle", fixed = TRUE)
})

test_that("speaker rule without time stamps uses the speaker names", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  f <- tempfile(fileext = ".txt")
  writeLines(c("Interviewerin: Guten Tag.", "Befragte: Hallo.", "Er sagte: nein.",
               "Interviewerin: Danke."), f)
  qda_import(f, segments = "speaker")
  # "Er sagte:" has a space -> not a speaker -> continues the turn
  expect_equal(seg_text(), c("Interviewerin: Guten Tag.", "Befragte: Hallo.\nEr sagte: nein.",
                             "Interviewerin: Danke."))
})

test_that("line rule and own pattern", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  f <- tempfile(fileext = ".txt")
  writeLines(c("I: a", "B1: b", "", "  ", "x", "I: c"), f)
  qda_import(f)
  qda_segments_set(1, "line")
  expect_equal(seg_text(), c("I: a", "B1: b", "x", "I: c"))
  qda_segments_set(1, "speaker", pattern = "^I:")
  expect_equal(seg_text(), c("I: a\nB1: b", "x", "I: c"))
})

test_that("split, merge, define and reset; all undoable; codings untouched", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(transcript_file(turns = 8), segments = "speaker")
  qda_code_add("A")
  qda_code(1, "A", start = 150L, end = 260L)
  coded <- qda_codings()$text
  s0 <- qda_source_segments(1)
  n0 <- nrow(s0)

  # split segment 3 in its middle
  at <- s0$start[3] + 20L
  qda_segment_split(1, at = at)
  s1 <- qda_source_segments(1)
  expect_equal(nrow(s1), n0 + 1)
  expect_equal(s1$end[3] < at && s1$start[4] >= at, TRUE)
  expect_false(grepl("^\\s|\\s$", s1$text[3]))           # trimmed
  expect_match(qda_history()$undo, "Segment 3 geteilt")

  # merge it back
  qda_segment_merge(1, 3)
  expect_equal(qda_source_segments(1)$start, s0$start)

  # define a passage spanning two segments as its own segment
  st <- s0$start[3] + 5L; en <- s0$start[4] + 5L
  qda_segment_define(1, st, en)
  s2 <- qda_source_segments(1)
  expect_true(any(s2$start == st & s2$end == en))
  expect_true(all(s2$start[-1] > s2$end[-nrow(s2)]))    # no overlaps

  # undo everything -> back to the original segments
  qda_undo(); qda_undo(); qda_undo()
  expect_equal(qda_source_segments(1)$start, s0$start)
  expect_equal(qda_source_segments(1)$end, s0$end)
  qda_redo()
  expect_equal(nrow(qda_source_segments(1)), n0 + 1)

  qda_segments_reset(1)
  expect_equal(attr(qda_source_segments(1), "origin"), "automatisch")
  qda_undo()
  expect_equal(attr(qda_source_segments(1), "origin"), "gespeichert")

  expect_identical(qda_codings()$text, coded)            # codings never change
})

test_that("invalid edits give clear errors", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(transcript_file(turns = 4), segments = "speaker")
  s <- qda_source_segments(1)
  expect_error(qda_segment_split(1, at = s$start[2]), "Anfang oder Ende")
  expect_error(qda_segment_merge(1, nrow(s)), "kein nachfolgendes")
  between <- s$end[1] + 1L                              # the blank line
  expect_error(qda_segment_split(1, at = between), "kein Segment")
  expect_error(qda_segment_define(1, between, between), "keinen Text")
})

test_that("document browser uses stored segments and keeps the text intact", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  qda_import(transcript_file(turns = 10), segments = "speaker")
  qda_code_add("A"); qda_code_add("B")
  qda_code(1, "A", start = 100L, end = 400L)            # spans several turns
  qda_code(1, "B", start = 300L, end = 500L)
  html <- jellyqda:::.render_doc_html(1)
  expect_equal(lengths(regmatches(html, gregexpr('class="segtext"', html))),
               nrow(qda_source_segments(1)))
  expect_identical(rendered_text(html), jellyqda:::.resolve_source(1)$frozen_text)
  # coding by segment number refers to the stored segments
  s <- qda_source_segments(1)
  cid <- qda_code(1, "A", segment = 3)$id
  cc <- qda_codings()
  expect_identical(cc$text[cc$id == cid], s$text[3])
  # qda_view uses them as well
  expect_true(grepl(sprintf("Segment %d", nrow(s)), qda_view(1, open = FALSE), fixed = TRUE))
})

test_that("re-importing a file does not reset edited segments", {
  new_project()
  on.exit(qda_close(), add = TRUE)
  f <- transcript_file(turns = 6)
  qda_import(f, segments = "speaker")
  qda_segment_merge(1, 2)
  n <- nrow(qda_source_segments(1))
  qda_import(f, segments = "speaker")                   # skipped: already imported
  expect_equal(nrow(qda_source_segments(1)), n)
})

test_that("older project files (without segments table) are upgraded on open", {
  p <- new_project()
  qda_import(ext("interview_01.txt"))
  DBI::dbExecute(qda_con(), "DROP TABLE segments")      # simulate an old file
  qda_close()
  qda_open(p, auto_snapshot = Inf)
  on.exit(qda_close(), add = TRUE)
  expect_equal(attr(qda_source_segments(1), "origin"), "automatisch")
  qda_segments_set(1, "speaker")
  expect_equal(attr(qda_source_segments(1), "origin"), "gespeichert")
})
