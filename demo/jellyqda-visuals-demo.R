# jellyqda visuals demo (since 0.9.0) -------------------------------------------
# DEMO: the transcripts demo/demo_interview_*.txt are FICTIONAL; all persons,
# companies and events are invented.
#
# Imports the four demo transcripts, segments them by speaker turns and codes
# them by keywords (qda_autocode) -- quick and rough, but enough to show the
# graphics: code co-occurrence (heatmap), code network and document portraits.
#
# Run from the root of the jellyqda source folder:
#   Rscript -e 'pkgload::load_all("."); source("demo/jellyqda-visuals-demo.R")'
# Start the app afterwards (toolbar -> "Graphics"):
#   options(jellyqda.demo.app = TRUE); source("demo/jellyqda-visuals-demo.R")

suppressMessages(library(jellyqda))

files <- file.path("demo", sprintf("demo_interview_%dmin.txt", c(10, 30, 60, 120)))
if (!all(file.exists(files))) stop("Run this demo from the root of the jellyqda source folder.", call. = FALSE)
workdir <- getOption("jellyqda.demo.dir", file.path(tempdir(), "jellyqda-visuals-demo"))
unlink(workdir, recursive = TRUE)
dir.create(workdir, recursive = TRUE, showWarnings = FALSE)
step <- function(...) cat("\n=== ", ..., " ===\n", sep = "")

step("1. project, speaker turns as segments, code system")
qda_open(file.path(workdir, "visuals-demo.jellyqda"))
qda_import(files, segments = "speaker")
qda_code_add("Career path", color = "#0072B2")
qda_code_add("Small company", parent = "Career path")
qda_code_add("Corporation", parent = "Career path")
qda_code_add("Motivation", color = "#E69F00")
qda_code_add("Meaning", parent = "Motivation")
qda_code_add("Customer contact", parent = "Motivation")
qda_code_add("Team climate", color = "#009E73")
qda_code_add("Conflict", parent = "Team climate")
qda_code_add("Workload", color = "#D55E00")
qda_code_add("Future", color = "#CC79A7")

step("2. rough first pass: code the speaker turns that contain keywords")
keywords <- list(
  "Small company" = c("small company", "small firm"),
  "Corporation" = c("corporation", "big firms", "management"),
  "Career path" = c("job interview", "first job", "team lead", "university", "career"),
  "Motivation" = c("tricky problems", "freedom", "learning something new", "taken seriously", "proud"),
  "Meaning" = c("use what we build", "saved them an hour", "users we are working for", "nurses"),
  "Customer contact" = c("customer", "user tests", "on site"),
  "Team climate" = c("help each other", "retrospectives", "buddy", "Trust", "lunch together", "cake"),
  "Conflict" = c("conflict", "tense", "loud"),
  "Workload" = c("late into the evening", "work phone", "weekend", "sleep badly", "burning out",
                 "overtime", "waves", "meetings"),
  "Future" = c("five years", "own business", "grow without", "first change"))
for (code in names(keywords)) for (k in keywords[[code]]) {
  qda_autocode(k, code = code, scope = "segment", whole_word = FALSE)
}
print(qda_stats()$overall[, c("n_sources", "n_codes", "n_codings", "pct_coded")])

step("3. co-occurrence: which codes appear in the same speaker turn?")
print(utils::head(qda_cooccurrence(), 10))
print(utils::head(qda_cooccurrence(level = "top"), 6))

step("4. graphics (SVG) -- in RStudio: print() shows them in the Viewer")
qda_plot_cooccurrence(file = file.path(workdir, "cooccurrence.svg"))
qda_plot_network(file = file.path(workdir, "network.svg"))
qda_plot_portrait(file = file.path(workdir, "portraits.svg"))
cat("SVG files in", workdir, "\n")

if (isTRUE(getOption("jellyqda.demo.app"))) qda_app() else qda_close()
