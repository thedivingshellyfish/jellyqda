# Helpers for the co-occurrence / portrait / graphics tests (test-units.R,
# test-cooccurrence.R, test-portrait.R, test-plots.R, test-visuals-app.R).

# One transcript with speaker turns; codes A (subcode A1), B, C.
viz_setup <- function() {
  new_project()
  qda_import(transcript_file(turns = 10), segments = "speaker")
  qda_code_add("A", color = "#0072B2"); qda_code_add("A1", parent = "A")
  qda_code_add("B", color = "#E69F00"); qda_code_add("C", color = "#009E73")
  invisible(NULL)
}
# code segment i of document 1 (optionally only a few characters of it)
viz_code <- function(code, i, len = NULL) {
  s <- jellyqda:::.segments_for(1)
  e <- if (is.null(len)) s$end[i] else s$start[i] + len - 1L
  qda_code(1, code, start = s$start[i], end = e)
}
