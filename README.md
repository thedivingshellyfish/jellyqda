# jellyqda

**RStudio-native, fully offline coding of interview transcripts.**

jellyqda is a small R package for qualitative coding (QDA) of interview
transcripts and field notes — built for a master's thesis, designed to never
touch the network. All project data lives in **one SQLite file per project**
(`*.jellyqda`); imported text is **frozen** at import time, so character
offsets in codings never drift. Every action is recorded in an audit trail
(`events` table) that can be exported for the methods section.

- 100 % offline, local-only storage (DSGVO-friendly: no cloud, no uploads)
- Import `.txt`, `.md`, `.docx`, `.pdf` (encoding detection, UTF-8)
- Scriptable API, everything returns tibbles, Viewer output via `qda_view()`
- Timestamped zip backups with rotation, outside the project folder
- Free forever (MIT license)

## Install

```r
# from a local clone (no CRAN dependency needed)
install.packages("path/to/jellyqda", repos = NULL, type = "source")
# dependencies: DBI, RSQLite, readr, stringi, officer, pdftools, tibble,
#               jsonlite, htmltools, digest, zip
```

## Quickstart

```r
library(jellyqda)

qda_open("meinarbeit.jellyqda")                       # open or create a project
qda_import(c("interview_01.txt", "interview_02.docx")) # freeze texts (+ originals/)
qda_code_add("Beruflicher Werdegang")                 # deductive start codebook
qda_code_add("KMU", parent = "Beruflicher Werdegang")

qda_view(1)                                           # transcript in the Viewer, numbered segments
qda_code(source = 1, segment = 3, code = "KMU", memo = "5 Jahre KMU")
qda_code(source = 1, start = 120, end = 340, code = "Beruflicher Werdegang") # or by offsets

qda_segments("KMU")                                   # all passages per code
qda_codes()                                           # codebook tree
qda_stats()                                           # progress: % of material coded
qda_export("all")                                     # segments / codebook / audit as files
qda_backup()                                          # timestamped zip snapshot
```

## API (V1)

| function | job |
|---|---|
| `qda_open(path)` | open or create the project file |
| `qda_import(files)` | import txt/md/docx/pdf, freeze text |
| `qda_sources()` | list sources |
| `qda_view(source)` | transcript with segment numbers + colored codings in the Viewer |
| `qda_codes()` / `qda_code_add(label, parent)` | codebook tree |
| `qda_code_rename()` / `qda_code_delete()` | codebook maintenance (audited) |
| `qda_code(source, code, segment | start, end, memo)` | assign a code |
| `qda_codings()` / `qda_coding_delete()` | list / remove codings |
| `qda_segments(code)` | all segments per code |
| `qda_memo_add()` / `qda_memos()` | free memos |
| `qda_export(what)` | `segments` / `codings` / `codebook` / `audit` / `all` |
| `qda_backup(path, keep)` | timestamped zip, rotating, outside the project folder |
| `qda_stats()` | progress overview |
| `qda_matrix()` | code x source counts (V1.5) |

## Interactive app (V2): `qda_app()`

One command starts a local web UI (loopback `127.0.0.1` only — still fully
offline) in the RStudio Viewer pane:

```r
qda_open("meinarbeit.jellyqda")
qda_app()     # Esc stops the app; open the printed URL in more browser
              # windows/tabs for a multi-window setup (shared session)
```

Panels: **Dokumente** (document tree + import), **Codes** (code tree with
color swatches, add/rename/delete, color picker), **Codings**, **Memos**, and
the **document browser**: mark text with the mouse, then click a colored code
button (or "Nur Memo") — the coding is stored at the exact character offsets
in the same `.jellyqda` file, with audit event. Click a highlight to inspect
or delete its coding. In the **Codings** list, click any row to jump the
document browser straight to that passage (highlighted, memo shown). In
**Memos** you can save free-text memos. Backup/Export buttons in the top bar.
Needs `shiny`, `bslib`, `colourpicker`, `fontawesome` (Suggests; install once).

Note: RStudio itself cannot show toolbar icons that act on a text selection
inside the Viewer — that is why the interactive UI is a local Shiny app, the
"V2 door" reserved in the concept (§3).

## Demo & tests

```r
pkgload::load_all(".")          # dev
source("demo/jellyqda-demo.R")  # end-to-end demo with bundled example data
testthat::test_local(".")       # full test suite (incl. offline guarantee)
```

Example data (fake transcripts + a broken PDF) lives in `inst/extdata/`.

## Data hygiene

- The R package lives in git; **interview data never enters a repo**
  (`.gitignore` excludes `*.jellyqda`, `originals/`, backups, exports).
- `qda_backup()` after each session; an auto-snapshot fires after every
  `auto_snapshot` actions (default 25, see `qda_open()`).
- Original transcript files are kept unchanged in `originals/`.

Documentation is in English; see `vignette("jellyqda")` after installation.
