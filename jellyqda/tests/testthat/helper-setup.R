ext <- function(f) system.file("extdata", f, package = "jellyqda")

new_project <- function(auto_snapshot = Inf) {
  d <- tempfile("qda-test-")
  dir.create(d, recursive = TRUE)
  p <- file.path(d, "testprojekt.jellyqda")
  qda_open(p, auto_snapshot = auto_snapshot)
  p
}
