# Helpers for the intercoder tests (test-intercoder*.R)

# Two coders, one transcript: A = active project, B = blind copy coded
# differently. Returns the path of B's file; A stays open.
ic_setup <- function() {
  pa <- new_project()
  qda_import(transcript_file(turns = 12), segments = "speaker")
  qda_code_add("Beruf"); qda_code_add("KMU", parent = "Beruf"); qda_code_add("Team")
  pb <- file.path(dirname(pa), "kodiererin_b.jellyqda")
  qda_intercoder_copy(pb)
  list(pa = pa, pb = pb)
}
seg_range <- function(i) {
  s <- jellyqda:::.segments_for(1)
  c(s$start[i], s$end[i])
}
code_seg <- function(code, i, shrink = 0L) {
  r <- seg_range(i)
  qda_code(1, code, start = r[1] + shrink, end = r[2] - shrink)
}
