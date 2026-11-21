# Generates the example data in inst/extdata/ --------------------------------
# Two short fake interview transcripts (txt UTF-8, md, docx, latin1 txt),
# one valid PDF with a text layer and one "broken" scanned PDF without one.
# Run once; outputs are committed so tests/demo work offline.

suppressMessages({library(officer)})

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)

# --- 1. fake interview as UTF-8 txt ----------------------------------------
txt1 <- "Interviewerin: Guten Tag, danke, dass Sie sich Zeit nehmen. Koennen Sie sich kurz vorstellen?

Befragte: Ja, gerne. Ich bin 34 Jahre alt und arbeite seit fuenf Jahren als Projektleiterin in einem kleinen Softwareunternehmen.

Interviewerin: Wie sind Sie zu diesem Beruf gekommen?

Befragte: Nach dem Studium der Wirtschaftsinformatik habe ich zuerst zwei Jahre in einem Konzern gearbeitet, aber das war mir zu anonym. Im KMU kann ich wirklich etwas bewegen.

Interviewerin: Was motiviert Sie bei der Arbeit?

Befragte: Vor allem die direkte Zusammenarbeit mit den Kunden. Und dass wir agile Methoden ernst nehmen, nicht nur auf dem Papier."
writeLines(txt1, "inst/extdata/interview_01.txt", useBytes = TRUE)

# --- 2. fake interview as markdown ------------------------------------------
md2 <- "# Interview 02 -- Feldnotizen-Session

**Interviewerin:** Wie erleben Sie die Zusammenarbeit im Team?

**Befragte:** Ehrlich gesagt ziemlich gut. Die regelmaessigen Retrospektiven helfen uns, Probleme frueh zu sehen.

## Abschnitt: Vertrauen

**Befragte:** Vertrauen ist fuer mich zentral. Wenn ich Fehler machen kann, ohne Angst zu haben, dann lerne ich am meisten.

**Interviewerin:** Vielen Dank fuer das Gespraech!"
writeLines(md2, "inst/extdata/interview_02.md", useBytes = TRUE)

# --- 3. fake interview as docx ----------------------------------------------
doc <- read_docx()
doc <- body_add_par(doc, "Interviewerin: Erzählen Sie von Ihrem typischen Arbeitstag.", style = "heading 2")
doc <- body_add_par(doc, "Befragte: Ich starte mit einer kurzen Abstimmung im Team, dann arbeite ich zwei bis drei Stunden fokussiert an einem Thema.")
doc <- body_add_par(doc, "Interviewerin: Was wuerden Sie als groesste Herausforderung nennen?", style = "heading 2")
doc <- body_add_par(doc, "Befragte: Die vielen Meetings. Manchmal habe ich das Gefuehl, die eigentliche Arbeit passiert abends.")
print(doc, target = "inst/extdata/interview_03.docx")

# --- 4. latin1-encoded txt (encoding detection test) -------------------------
lat <- "Interviewerin: Wie wichtig ist Weiterbildung fuer Sie?\n\nBefragte: Sehr wichtig. Ich habe letztes Jahr eine Weiterbildung zum Thema Datenschutz gemacht -- Jürgen, mein Kollege, hat sie organisiert."
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
         c("Field notes 2027-01-12",
           "Observation at the weekly team meeting:",
           "- short check-in round, everyone reports progress",
           "- blocker discussed: waiting on customer feedback",
           "- decision: retry request tomorrow"))
make_pdf("inst/extdata/broken_scan.pdf", NULL)  # scanned page, no text layer

cat("extdata files:\n")
print(list.files("inst/extdata", full.names = TRUE))
