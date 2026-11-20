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

The layout shows all panes at once (workflow logic follows MAXQDA per concept
§6 — in jellyqda's own look, the concept forbids copying MAXQDA's
colors/icons/layout):

| MAXQDA window | jellyqda pane (in `qda_app()`) | API |
|---|---|---|
| Document System | left top: **Dokumente** tree + import | `qda_sources()` |
| Code System | left bottom: **Code System** tree, color swatches, add/rename/delete | `qda_codes()` |
| Document Browser | center top: mark text → colored code buttons / "Nur Memo" | `qda_view()` |
| Retrieved Segments | center bottom: segments of the code selected in the tree (click → jump) | `qda_segments()` |
| (Memo panel) | right: **Memos** — memo of the clicked coding + free memos (editable) | `qda_memos()` |
| Code Matrix Browser | left: **Code-Matrix** — codes x documents counts, SUM row/col, cell intensity; click cell = open code+document | `qda_matrix()` |
| Summary Grid | right: **Summary Grid** — click a cell: its segments + editable summary text per cell (saved, audited) | `qda_summary_set()` / `qda_summaries()` |

Memos are editable: pen icon loads a memo into the text area, "Memo
speichern" overwrites it (`qda_memo_update()`), "Abbrechen" cancels. Every
panel has a collapse chevron in its header, and the fixed symbol bar in the
top bar toggles each window (Dokumente, Codes, Matrix, Browser, Segments,
Memos, Summary) — collapsed state is persisted with the layout.

Marking text + clicking a code button stores the coding at the exact
character offsets in the same `.jellyqda` file (audit event included); click a
highlight to inspect/delete it. **"Nur Memo"** stores the passage under a
reserved *Memo* code rendered as an **underline**. Backup/Export buttons in
the top bar.

**Flexible panes:** drag any panel by its header into another column (e.g.
Memos to the right, browser stays center), drag the gray column borders to
resize, or use the layout preset in the top bar ("Standard" / "Browser gross"
/ "Nur Browser") plus "Layout reset". The arrangement is saved in the
browser's localStorage and restored on the next start. Needs `shiny`,
`bslib`, `colourpicker`, `fontawesome` (Suggests; install once).

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
