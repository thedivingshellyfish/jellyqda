# Generates the example data in inst/extdata/ --------------------------------
#
# DEMO FILES: every interview, person, company and event in these files is
# FICTIONAL, invented for jellyqda's examples, tests and vignette. Any
# resemblance to real persons or organisations is coincidental.
#
# Files (all in English, so the examples work internationally):
#   interview_01.txt      career path of a project lead (UTF-8 text)
#   interview_02.md       team collaboration and trust (Markdown)
#   interview_03.docx     a typical working day (Word)
#   interview_latin1.txt  further training; Latin-1 encoded ON PURPOSE
#                         (tests the encoding detection: "J\u00fcrgen", "caf\u00e9")
#   fieldnotes.pdf        field notes with a text layer (PDF)
#   broken_scan.pdf       a "scanned" page WITHOUT text layer (import warning)
#
# Every file starts with a line that marks it as a fictional demo file.
# Run once from the package root:  Rscript data-raw/make_extdata.R
# The outputs are committed, so tests, examples and the vignette work offline.
# See also data-raw/make_demo_transcripts.R (longer transcripts in demo/).

suppressMessages({library(officer)})

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
DEMO_NOTE <- "DEMO FILE - fictional interview written for jellyqda. All persons, companies and events are invented."

# --- 1. interview as UTF-8 txt: career path ------------------------------------
txt1 <- paste(DEMO_NOTE, "

Interviewer: Good morning, and thank you for taking the time. Could you briefly introduce yourself?

Respondent: Sure. I am 34 years old and I have been working as a project lead in a small software company for five years.

Interviewer: How did you get into this job?

Respondent: After studying business informatics I first worked for two years in a large corporation, but it felt too anonymous. In a small company I can really make a difference. A colleague from university told me about the opening.

Interviewer: What motivates you at work?

Respondent: Above all the direct contact with our customers. And that we take agile methods seriously, not just on paper. My family sometimes jokes that I talk more about the project than about our holidays.", sep = "")
writeLines(txt1, "inst/extdata/interview_01.txt", useBytes = TRUE)

# --- 2. interview as markdown: team and trust ------------------------------------
md2 <- "# Interview 02 -- team session (DEMO FILE, fictional)

> Demo file written for jellyqda. All persons and events are invented.

**Interviewer:** How do you experience the collaboration in your team?

**Respondent:** Honestly, quite good. Our regular retrospectives help us to spot problems early, and a colleague usually brings coffee.

## Section: trust

**Respondent:** Trust is central for me. If I can make mistakes without being afraid, that is when I learn the most.

**Interviewer:** Thank you very much for the conversation!"
writeLines(md2, "inst/extdata/interview_02.md", useBytes = TRUE)

# --- 3. interview as docx: a typical working day -------------------------------
doc <- read_docx()
doc <- body_add_par(doc, "DEMO FILE - fictional interview written for jellyqda. All persons and events are invented.")
doc <- body_add_par(doc, "Interviewer: Tell me about a typical working day.", style = "heading 2")
doc <- body_add_par(doc, "Respondent: I start with a short stand-up with the team, then I work for two or three hours on one topic without interruptions.")
doc <- body_add_par(doc, "Interviewer: What would you call your biggest challenge?", style = "heading 2")
doc <- body_add_par(doc, "Respondent: All the meetings. Sometimes I feel the real work only happens in the evening, when the project chat is finally quiet.")
print(doc, target = "inst/extdata/interview_03.docx")

# --- 4. Latin-1 encoded txt (encoding detection test) --------------------------
lat <- paste0("DEMO FILE - fictional interview (Latin-1 encoded on purpose). All persons are invented.\n\n",
              "Interviewer: How important is further training for you?\n\n",
              "Respondent: Very important. Last year I took a course on data protection -- J\u00fcrgen, ",
              "my colleague from the caf\u00e9 team, organised it.")
lat_latin1 <- iconv(lat, from = "UTF-8", to = "ISO-8859-1")
writeBin(charToRaw(lat_latin1), "inst/extdata/interview_latin1.txt")

# --- 5. minimal PDF writer (with or without text layer) ----------------------
make_pdf <- function(path, text_lines = NULL) {
  esc <- function(x) gsub("([\\\\()])", "\\\\\\1", x)
  stream <- if (is.null(text_lines)) "" else paste0(
    "BT /F1 12 Tf 72 720 Td 16 TL\n",
    paste0("(", esc(text_lines), ") Tj T*\n", collapse = ""), "ET\n")
  objs <- c(
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    paste0("<< /Length ", nchar(stream, type = "bytes"), " >>\nstream\n", stream, "endstream"),
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
  )
  out <- "%PDF-1.4\n"
  offsets <- integer(length(objs))
  for (i in seq_along(objs)) {
    offsets[i] <- nchar(out, type = "bytes")
    out <- paste0(out, i, " 0 obj\n", objs[i], "\nendobj\n")
  }
  xref_pos <- nchar(out, type = "bytes")
  n <- length(objs) + 1L
  xref <- paste0("xref\n0 ", n, "\n0000000000 65535 f \n",
                 paste0(sprintf("%010d 00000 n ", offsets), "\n", collapse = ""))
  trailer <- paste0("trailer\n<< /Size ", n, " /Root 1 0 R >>\nstartxref\n",
                    xref_pos, "\n%%EOF\n")
  writeBin(charToRaw(paste0(out, xref, trailer)), path)
  invisible(path)
}

make_pdf("inst/extdata/fieldnotes.pdf",
         c("DEMO FILE - fictional field notes. All persons and events are invented.",
           "Field notes 2027-01-12",
           "Observation at the weekly team meeting:",
           "- short check-in round, everyone reports progress",
           "- blocker discussed: waiting on customer feedback",
           "- decision: retry the request tomorrow"))
make_pdf("inst/extdata/broken_scan.pdf", NULL)  # scanned page, no text layer

cat("extdata files:\n")
print(list.files("inst/extdata", full.names = TRUE))
