# jellyqda intercoder demo (since 0.8.0) ----------------------------------------
# DEMO: the three interviews in demo/intercoder/ are FICTIONAL; all persons,
# companies and events are invented. "anna" and "ben" are fictional coders.
#
# Two people code the same three interviews independently; jellyqda compares
# them: percent agreement, Cohen's kappa, Brennan & Prediger, Krippendorff's
# alpha, and the list of disagreements for the consensus talk.
#
# Run from the root of the jellyqda source folder:
#   Rscript -e 'pkgload::load_all("."); source("demo/jellyqda-intercoder-demo.R")'
# or, with the package installed:
#   Rscript demo/jellyqda-intercoder-demo.R
# Start the app afterwards (Analysis -> tab "Intercoder"):
#   options(jellyqda.demo.app = TRUE); source("demo/jellyqda-intercoder-demo.R")
#
# Workflow shown here:
#   1. anna sets up the project: documents, segments, code system + guideline
#   2. qda_intercoder_copy(): blind copy for ben (no codings)
#   3. both code independently, each in their own file
#   4. anna compares: qda_intercoder(), qda_intercoder_diff()
#   5. consensus: qda_intercoder_adopt() takes over one of ben's codings

suppressMessages(library(jellyqda))

files <- normalizePath(file.path("demo", "intercoder",
                                 c("interview_mara.txt", "interview_jonas.txt", "interview_selin.txt")),
                       mustWork = FALSE)
if (!all(file.exists(files))) stop("Run this demo from the root of the jellyqda source folder.", call. = FALSE)
workdir <- getOption("jellyqda.demo.dir", file.path(tempdir(), "jellyqda-intercoder-demo"))
unlink(workdir, recursive = TRUE)
dir.create(workdir, recursive = TRUE, showWarnings = FALSE)
step <- function(...) cat("\n=== ", ..., " ===\n", sep = "")

# helper: code the speaker turn of `doc` that contains `phrase`
code_turn <- function(doc, phrase, code) {
  src <- qda_sources()
  sid <- src$id[src$name == doc]
  seg <- qda_source_segments(sid)
  hit <- which(grepl(phrase, seg$text, fixed = TRUE))[1]
  if (is.na(hit)) stop("phrase not found: ", phrase, call. = FALSE)
  qda_code(sid, code, segment = seg$segment[hit])
}
# one coder's work: a list of (document, phrase, code)
code_all <- function(plan) for (p in plan) code_turn(p[1], p[2], p[3])
M <- "interview_mara.txt"; J <- "interview_jonas.txt"; S <- "interview_selin.txt"

step("1. anna: project, speaker turns as segments, code system with guideline")
pa <- file.path(workdir, "anna.jellyqda")
qda_open(pa)
qda_import(files, segments = "speaker")
qda_code_add("Career path", color = "#0072B2")
qda_code_add("Small company", parent = "Career path")
qda_code_add("Corporation", parent = "Career path")
qda_code_add("Motivation", color = "#E69F00")
qda_code_add("Meaning", parent = "Motivation")
qda_code_add("Customer contact", parent = "Motivation")
qda_code_add("Team climate", color = "#009E73")
qda_code_add("Workload", color = "#D55E00")
qda_code_guide("Small company", definition = "Experiences in small and medium-sized companies",
               rule = "Own experiences only; mere comparisons with corporations -> Corporation")
qda_code_guide("Corporation", definition = "Experiences in large companies",
               rule = "Includes contrasts ('in a corporation that would have ...')")
qda_code_guide("Meaning", definition = "What the work means for other people")
qda_code_guide("Customer contact", definition = "Direct contact with customers or users")
qda_code_guide("Workload", definition = "Time pressure, stress, boundaries between work and free time")
print(qda_sources()[, c("id", "name", "segments")])

step("2. blind copy for ben: same documents, segments and codes, no codings")
pb <- qda_intercoder_copy(file.path(workdir, "ben.jellyqda"))
cat("copy:", pb, "\n")

step("3a. anna codes")
code_all(list(
  c(M, "large corporation", "Corporation"),
  c(M, "small software company", "Small company"),
  c(M, "used every day by nurses", "Meaning"),
  c(M, "well-rehearsed team", "Team climate"),
  c(M, "late into the evening", "Workload"),
  c(M, "direct feedback", "Customer contact"),
  c(J, "medium-sized firm", "Small company"),
  c(J, "project of my own", "Small company"),
  c(J, "tricky problems", "Motivation"),
  c(J, "argument about responsibilities", "Team climate"),
  c(J, "work phone", "Workload"),
  c(S, "insurance corporation", "Corporation"),
  c(S, "Liberating", "Small company"),
  c(S, "cope better", "Meaning"),
  c(S, "Very collegial", "Team climate"),
  c(S, "High at times", "Workload"),
  c(S, "interviews and tests", "Customer contact")))
cat(nrow(qda_codings()), "codings\n")
qda_close()

step("3b. ben codes the blind copy independently")
qda_open(pb)
code_all(list(
  c(M, "large corporation", "Corporation"),
  c(M, "small software company", "Small company"),
  c(M, "used every day by nurses", "Meaning"),
  c(M, "well-rehearsed team", "Team climate"),
  c(M, "late into the evening", "Workload"),
  c(M, "direct feedback", "Customer contact"),
  c(J, "medium-sized firm", "Small company"),
  c(J, "project of my own", "Corporation"),            # ben: the comparison with a corporation
  c(J, "tricky problems", "Motivation"),
  c(J, "argument about responsibilities", "Workload"), # ben: the conflict as strain
  c(J, "work phone", "Workload"),
  c(J, "what we are actually building", "Meaning"),    # ben: anna did not code this turn
  c(S, "insurance corporation", "Corporation"),
  c(S, "Liberating", "Small company"),
  c(S, "cope better", "Meaning"),
  c(S, "Very collegial", "Team climate"),
  c(S, "High at times", "Workload"),
  c(S, "interviews and tests", "Customer contact"),
  c(S, "interviews and tests", "Meaning")))            # ben: double coding
cat(nrow(qda_codings()), "codings\n")
qda_close()

step("4. anna compares (ben's file is only read)")
qda_open(pa)
res <- qda_intercoder(pb)
print(res[, c("code", "both", "only_a", "only_b", "agreement", "kappa", "alpha", "rating")], n = Inf)
cat(sprintf("\nOverall: kappa = %.2f (%s), %.1f %% agreement, alpha = %.2f, Brennan & Prediger = %.2f\n",
            res$kappa[1], res$rating[1], 100 * res$agreement[1], res$alpha[1], res$kappa_bp[1]))
cat("\nCode families (code with subcodes):\n")
print(qda_intercoder(pb, level = "top", log = FALSE)[, c("code", "agreement", "kappa")])

step("5. disagreements -> consensus talk")
d <- qda_intercoder_diff(pb)
print(d[, c("source", "segment", "code", "coder")], n = Inf)
# after the talk: ben's coding of Jonas' last turn ("Meaning") is taken over
i <- which(d$code == "Motivation / Meaning" & d$coded_by == "B")[1]
new <- qda_intercoder_adopt(pb, d$source_id[i], d$start[i], d$end[i], d$code[i])
cat("taken over:", nrow(new), "coding(s); undo:", qda_history()$undo, "\n")

step("6. report with the intercoder section")
ex <- qda_export("report")
cat("report:", ex$file, "\n")
cat("\nProject files in", workdir, "\n")

if (isTRUE(getOption("jellyqda.demo.app"))) qda_app() else qda_close()
