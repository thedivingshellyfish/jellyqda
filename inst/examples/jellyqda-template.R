# ============================================================================
# jellyqda template: a coding session for your thesis
# (German version: jellyqda-vorlage.R in the same folder)
# ============================================================================
# How to work with it in RStudio:
#   1. Open this script (or copy it into your own script).
#   2. Enter your real names at "project_file" and "my_files" below.
#   3. Run it line by line: cursor in a line -> Ctrl+Enter (selecting
#      everything + Ctrl+Enter works as well).
#
# Key ideas of jellyqda:
#   - One project file (*.jellyqda) holds EVERYTHING: texts, codes, codings,
#     memos and the audit trail. qda_backup() is all you need for backups.
#   - On import the text is "frozen" once (copied into the database). It is
#     never extracted again -> character offsets stay stable forever.
#   - 100 % offline: no internet connection is ever made.
# ============================================================================

library(jellyqda)

# --- 0. Open the project (creates the file the first time) ------------------
project_file <- "my-thesis.jellyqda"   # <- YOUR project folder/file name
qda_open(project_file)
qda_project()   # overview: file, size, number of sources/codes/codings/events

# --- 1. Import transcripts -----------------------------------------------------
# txt, md, docx and pdf are treated alike. The text is normalised to UTF-8 and
# frozen; the original is kept unchanged in originals/.
# (PDF without a text layer -> warning; run OCR manually if needed.)
my_files <- c(
  "interview_01.docx",
  "interview_02.txt"
  # "interview_03.md",
  # "fieldnotes.pdf"
)
qda_import(my_files, segments = "speaker")   # segments by speaker turns
qda_sources()   # all sources: id, name, format, characters, segments

# To try it with the example data of the package instead:
# qda_import(system.file("extdata",
#   c("interview_01.txt", "interview_02.md", "interview_03.docx", "fieldnotes.pdf"),
#   package = "jellyqda"))

# --- 2. Build the codebook (deductive: from the interview guide/theory) --------
qda_code_add("Career path")
qda_code_add("SME",         parent = "Career path")   # subcode
qda_code_add("Corporation", parent = "Career path")
qda_code_add("Motivation")
# coding guideline: definition, anchor example, coding rule
qda_code_guide("SME", definition = "Statements about working in a small or medium-sized enterprise",
               rule = "Only explicit statements; comparisons with corporations -> 'Corporation'")
qda_codes()     # code tree with path (e.g. "Career path / SME") and colour

# --- 3. Coding --------------------------------------------------------------------
# The viewer shows the transcript with segment numbers (segment 1, 2, 3 ...).
qda_view(1)                    # open source id 1 in the viewer pane
qda_view("interview_01.docx")  # works with the name as well

# Code a segment (+ comment):
qda_code(source = 1, segment = 3, code = "SME", memo = "5 years in an SME")

# Or by character positions (1-based, start and end inclusive):
qda_code(source = 1, start = 120, end = 340, code = "Motivation")

# Inductive codes are created freely while coding:
qda_code_add("Team climate")
qda_code(source = 2, segment = 5, code = "Team climate", memo = "trust is central")

# Code every occurrence of a term at once (one undo step):
qda_autocode("colleague", code = "Team climate", scope = "segment")

# All passages of a code as a table (with text excerpt and comment):
qda_segments("SME")

# All codings (filterable by source and code):
qda_codings()
qda_codings(source = 1, code = "Motivation")

# Re-code a coding, e.g. from the code to a subcode:
# qda_coding_recode(2, "SME")

# Mayring: paraphrase and generalisation of a coding
# qda_coding_set_summary(1, paraphrase = "...", generalization = "...")

# Delete a single coding (recorded in the audit trail):
# qda_coding_delete(7)   # e.g. the coding with id 7

# Rename / merge / delete codes (recorded as well; deleting removes subcodes):
qda_code_rename("SME", "SME experience")
# qda_code_merge("Corporation", into = "Career path")
# qda_code_delete("Corporation")

# --- 4. Memos ------------------------------------------------------------------------
qda_memo_add("Question 3 of the guide was unclear -- ask again in the next interview")
qda_memo_add("Only explicit statements", code = "Motivation", title = "Coding rule")
qda_memos()

# --- 5. Analysis, export, backup -------------------------------------------------
qda_stats()            # overall: what share of the material is coded?
qda_matrix()           # cross table code x document (number of codings)
qda_words(n = 30)      # word frequencies without stop words
qda_kwic("team")       # keyword in context
# qda_source_set_var(1, "role", "project lead"); qda_case_matrix("role")

qda_export("all")    # segments_*.csv/xlsx, codings_*.csv, codebook_*.csv/docx,
                     # audit_*.csv, report_*.html -- all in exports/ next to the project
qda_export("audit")  # only the audit trail -> evidence for the methods chapter

qda_backup()         # timestamped zip in jellyqda-backups/ (OUTSIDE the
                     # project folder); old backups rotate automatically
# qda_backup(path = "D:/usb-stick/backups", keep = 20)   # own backup path

qda_events()         # complete audit trail as a table (every action + time stamp)

# --- 5b. Optional: interactive app ---------------------------------------------------
# One command starts a local web interface (127.0.0.1 only, offline): documents
# and code tree on the left, document browser in the middle. Mark text -> click
# a code -> the coding is stored at the exact character positions. Esc stops
# the app. The report opens in a new browser tab and prints on A4.
# qda_app()               # language follows your system; or:
# qda_app(lang = "en")    # English user interface
# qda_app(lang = "de")    # German user interface

# --- 5c. Optional: intercoder agreement (a second person codes) -----------------------
# 1. Blind copy for the second person: same documents, segments and codes,
#    but none of your codings. Hand it over (USB stick, encrypted mail ...).
# qda_intercoder_copy("coder_b.jellyqda")
# 2. The second person opens it with qda_open("coder_b.jellyqda") and codes.
# 3. Compare (the other file is only read): kappa, alpha, agreement per code
# qda_intercoder("coder_b.jellyqda")
# qda_intercoder_diff("coder_b.jellyqda")   # disagreements -> consensus talk
# In the app: Analysis -> tab "Intercoder".

# --- 6. End the session ----------------------------------------------------------------
qda_close()

# Remember: never put the .jellyqda file, originals/, exports/ or backups into
# git -- only your R code. The interview data stay on your computer.
