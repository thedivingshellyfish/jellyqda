# jellyqda end-to-end demo (milestone 1 of the concept) -----------------------
# Import -> code -> view -> segments -> stats -> export -> backup, using the
# bundled example data. Runs completely offline. Usage:
#   Rscript -e 'pkgload::load_all("."); source("demo/jellyqda-demo.R")'
# or, with the package installed:
#   Rscript demo/jellyqda-demo.R

suppressMessages(library(jellyqda))

ext <- function(f) {
  p <- system.file("extdata", f, package = "jellyqda")
  if (!nzchar(p)) p <- file.path(find.package("jellyqda"), "inst", "extdata", f) # load_all fallback
  normalizePath(p, mustWork = TRUE)
}
workdir <- file.path(tempdir(), "jellyqda-demo")
dir.create(workdir, recursive = TRUE, showWarnings = FALSE)
proj <- file.path(workdir, "demoarbeit.jellyqda")
if (file.exists(proj)) file.remove(proj)

step <- function(...) cat("\n=== ", ..., " ===\n", sep = "")

step("1. qda_open: create project ", proj)
qda_open(proj)
print(qda_project())

step("2. qda_import: txt, md, docx, pdf (latin1 + broken pdf too)")
print(qda_import(c(ext("interview_01.txt"), ext("interview_02.md"), ext("interview_03.docx"),
                   ext("interview_latin1.txt"), ext("fieldnotes.pdf"))))
warn_msg <- NULL
res <- withCallingHandlers(
  qda_import(ext("broken_scan.pdf")),
  warning = function(w) { warn_msg <<- conditionMessage(w); invokeRestart("muffleWarning") }
)
print(res)
cat("warning caught as expected:", grepl("no usable text layer", warn_msg), "\n")
print(qda_sources())

step("3. qda_code_add: deductive codebook from the interview guide")
qda_code_add("Beruflicher Werdegang")
qda_code_add("KMU", parent = "Beruflicher Werdegang", description = "kleines Softwareunternehmen")
qda_code_add("Konzern", parent = "Beruflicher Werdegang")
qda_code_add("Motivation")
qda_code_add("Teamklima")   # inductive, created during coding
print(qda_codes())

step("4. qda_code: assign codes to segments (by segment number or offsets)")
qda_code(source = 1, segment = 2, code = "KMU", memo = "5 Jahre im KMU, vorher 2 Jahre Konzern")
qda_code(source = 1, segment = 3, code = "Beruflicher Werdegang")
qda_code(source = 1, segment = 4, code = "Motivation")
qda_code(source = 2, segment = 3, code = "Teamklima", memo = "Vertrauen ist zentral")
qda_code(source = 3, segment = 2, code = "Motivation")
qda_code(source = 4, start = 1, end = 60, code = "Beruflicher Werdegang")  # by char offsets
print(qda_codings())

step("5. qda_segments: all passages per code (Retrieved Segments)")
print(qda_segments("Motivation"))

step("6. qda_view: transcript with segment numbers (Viewer in RStudio)")
html <- qda_view(1, open = FALSE)
cat("HTML length:", nchar(html), "chars; contains 'Segment 1':",
    grepl("Segment 1", html, fixed = TRUE), "\n")

step("7. qda_stats / qda_matrix: progress")
print(qda_stats())
print(qda_matrix())

step("8. qda_export: segments, codebook, codings, audit trail")
print(qda_export("all"))

step("9. qda_backup: timestamped zip outside the project folder")
print(qda_backup())

step("10. audit trail (for the methods section)")
print(qda_events())

qda_close()
cat("\nDemo finished. Project + originals + exports + backups are in:\n ", workdir, "\n")
