# jellyqda 0.7.0

## New features

  * **English and German user interface.** The app, its help, the
    notifications and the HTML report are available in English and German.
    The language follows the system locale; switch it with the **DE/EN**
    button in the toolbar (remembered per browser), `qda_app(lang = "en")`
    or `qda_language("en")` for the whole R session. Audit-trail entries are
    written in the language of the moment.
  * English documentation as the main version: README, wiki (`docs/wiki/`)
    and an English example template (`inst/examples/jellyqda-template.R`);
    the German versions are kept (`README.de.md`, `docs/wiki/de/`,
    `jellyqda-vorlage.R`). Screenshots in both languages.
  * The installation script prints its messages in English or German.

## CRAN readiness

  * Runnable examples for all exported functions (in temporary folders),
    new vignette with executed code, regenerated help pages, CRAN-style
    `LICENSE`, updated `CITATION`; `R CMD check --as-cran` passes.
  * All code comments are in English.
  * `colourpicker` is no longer needed.

## Fixes

  * Translations with umlauts in the catalogue keys kept their encoding only
    in UTF-8 sessions (names in `c()` are converted at installation).

# jellyqda 0.6.0

## New features

  * **Report: margin column next to the interviews.** The document text is
    narrower; every coding starts with a small number in the colour of its
    code family, and on the right a card with the same number hangs on a
    thread in that colour: code path, comment and paraphrase; passage memos
    appear as "M1, M2 ...". Cards are placed next to the segment in which a
    coding starts, which stays reliable across page breaks.
  * **Comment field in the coding bar:** click a coding to add or change its
    comment (Enter saves).
  * **In-vivo codes:** "In vivo" in the coding bar turns the marked text into
    a new code and assigns it.
  * **Merge codes** (arrow icon in the tree, `qda_code_merge()`): codings,
    subcodes (equal labels merged too), code memos, summaries and the coding
    guideline move to the target code; one undo step.
  * **Code all search hits** (`qda_autocode()`): below the project search,
    code every match or its whole segment with one click; already coded
    places are skipped; one undo step.
  * **Coding guideline** per code (book icon, `qda_code_guide()`):
    definition, anchor examples, coding rule. "Als Ankerbeispiel" in the
    coding bar appends the clicked passage with document and segment. Shown
    while coding, in the report and in the Word codebook.
  * **Case comparison** (`qda_case_matrix()`): the code matrix can show the
    values of a document variable as columns; the report adds one table per
    variable.
  * **Analysis window** ("Analyse" in the toolbar): word frequencies
    (`qda_words()`, without stop and filler words, optionally only within a
    code), keyword in context (`qda_kwic()`, click jumps to the passage) and
    **Mayring's summarising content analysis**: paraphrase and
    generalisation per coding (`qda_coding_set_summary()`), editable as a
    table and downloadable as CSV for Excel; also a section in the report.
  * New columns: `codes.anchor`, `codes.coding_rule`, `codings.paraphrase`,
    `codings.generalization` (older projects are upgraded on open).
    `qda_codes()` and `qda_codings()` return them.

## Fixes

  * Jumping to a search hit did not scroll to the passage
    ("r.scrollIntoView is not a function").

# jellyqda 0.5.0

2026-11-23

## New features

  * **Code tree with codes and subcodes.** A code (top level) is shown in full
    colour; its subcodes carry only a border in that colour and hang on a
    line ("thread") in the same colour. Every code with subcodes can be
    collapsed and expanded (remembered per browser); a filter field and
    "expand / collapse all" sit above the tree. Counts show the codings of a
    code itself and, as "Σ", including all subcodes.
  * **Working directly in the tree:** "+ Code" in the panel header,
    "+ Subcode" on every row (up to three levels), **double click** (or F2)
    to rename, trash icon to delete with a confirmation that names the
    subcodes and codings affected, and a colour dot to change the colour of a
    whole code family. The old form below the tree is gone.
  * **Two-step coding bar.** After marking text, the codes appear as coloured
    chips (`Ctrl+1…9`). A code with subcodes unfolds them on its thread
    (`1…9` = subcode, `0` = only the code). A search field finds any code by
    its path, and Enter without a hit creates a new code and assigns it.
    Hovering a code shows its definition (description or code memo); the
    last used codes are offered again.
  * **Coding by clicking in the tree:** while text is marked, a click on a
    code in the tree codes the marked text.
  * **Re-coding:** clicking a coding offers all codes of the same family, so a
    passage can be refined to a subcode without deleting and re-coding it.
    New API function `qda_coding_recode()`.
  * **Subcode codings in the text:** light tint of the family colour,
    underline and a small label at the start (drawn by CSS, so character
    offsets stay exact).
  * **Save button** (`Ctrl+S`) in the toolbar, with "Alles gespeichert" status.
    Every action was and is saved immediately; the button additionally
    checkpoints the database and writes a backup.
  * **Report in a new tab**, served fresh by the app on every click.
  * **Report redesigned for A4 printing** (German): no colour backgrounds
    (colours only as lines and borders, so no "background graphics" needed),
    page numbers, sections Codesystem und Häufigkeiten (with share in %),
    Codebuch, Memos, Codierte Textstellen, Dokumente mit Markierungen.
  * **Export menu** in the toolbar: export everything, codebook (Word + CSV,
    now ordered and structured by the code tree), report as HTML file,
    backup, reset layout.
  * Code matrix and summary grid follow the tree order; code rows in the
    matrix show "Σ" including subcodes and collapse with the tree.
    "Retrieved Segments" of a code include its subcodes.
  * New subcodes inherit the colour of their code family; new top-level
    codes get the next unused palette colour. New API function
    `qda_code_set_color()`.
  * Notifications after coding, renaming, deleting and re-coding carry an
    "Rückgängig" (undo) link.

## Fixes

  * Button icons failed with shiny < 1.8.1 ("Invalid icon"), e.g. with the
    shiny package from the Ubuntu/Debian repositories.
  * The variable list could log an error when no document was selected.

# jellyqda 0.4.2

2026-11-21

## Critical fixes

  * **Overlapping codings could corrupt later codings.** The overlapping text
    was rendered twice in the document, which silently shifted every coding
    made afterwards in the same document. `qda_view()` and the HTML report
    were affected as well. If you worked with overlaps in an older project,
    please review the codings made after an overlap (`qda_codings()`,
    column `text`).
  * Coding a selection could store the whole paragraph instead, because the
    click on the "Seg" badge fired after marking.
  * Drag & drop file import and "Layout reset" did not work.
  * Invisible elements: hint texts appeared as gray boxes, many icons
    (e.g. the delete icons) had zero size, and progress bars were missing.
  * The memo panel showed an error message in projects without memos.

## New features

  * **Undo & redo for everything** (`Ctrl+Z` / `Ctrl+Y`), including deleting
    a code with all sub-codes, codings and memos, variables, summaries and
    segments. The tooltip shows what will happen; the history survives an
    app restart.
  * **Overlapping codings** are now displayed as gray marks with a count and
    color stripes; hovering shows all codings at that spot with buttons to
    show or delete each one.
  * **Segments by blank lines, speaker changes or lines** (`[00:01:12] P: ...`),
    at import time or later. Segments can be split, merged, or defined from
    a text selection.
  * **Memos in four kinds**: passage (underlined in the text), document
    (postscript), code (definition or coding rule) and project (research
    diary), plus comments attached to codings. The new memo panel has
    filter, search and jump-to-target; memo symbols appear in the code
    system and the document list.
  * Dark mode reworked: all texts and buttons checked for WCAG AA contrast,
    in light mode as well.
  * One-file installer `install_jellyqda.R`, also runnable directly:
    `source("https://raw.githubusercontent.com/thedivingshellyfish/jellyqda/main/install_jellyqda.R")`.
  * New README and wiki with screenshots for every feature (offline copy in
    `docs/wiki/`).

## Changes

  * The pseudo-code "Memo" is gone. Old memo markings are converted to
    passage memos automatically on first open; undo does not reach beyond
    that conversion.
  * "Memo speichern" without text now opens a form instead of saving the
    marked passage itself as a memo.
  * The app interface is labeled in German throughout.
  * The HTML report groups memos by kind and preserves the transcripts'
    line breaks.
  * The Excel export (`writexl`) is installed by the installer as well.

## New and extended functions

  * New: `qda_redo()`, `qda_history()`, `qda_segments_set()`,
    `qda_segment_split()`, `qda_segment_merge()`, `qda_segment_define()`,
    `qda_segments_reset()`, `qda_source_segments()`.
  * Extended: `qda_import(..., segments = "speaker")`,
    `qda_memo_add(text, source, start, end, code, title)`,
    `qda_memos(kind, source, code)`, `qda_memo_update(memo, text, title)`.

## Under the hood

  * CSS and JavaScript moved into separate, thoroughly commented files in
    `inst/app/www/`.
  * 74 automated tests, including: the displayed text always matches the
    stored text character by character, every part of the app runs cleanly
    in empty projects, and every icon is visible.
  * `R CMD check` passes with 0 errors, 0 warnings, 0 notes.

# jellyqda 0.1.0

2026-11-20

  * Initial public release. RStudio-native, fully offline qualitative coding
    of interview transcripts: import of `.txt`, `.md`, `.docx`, `.pdf`,
    deductive and inductive code system with colors, drag-and-drop panel
    layout, project-wide search, document variables, code matrix, summary
    grid, timestamped rotating ZIP backups, scriptable console API (every
    function returns a tibble) and a full audit trail for the methods
    section (`qda_export("audit")`).
  * A project is a single local SQLite file (`*.jellyqda`); imported text is
    frozen at import time, so character offsets in codings never drift.
  * No network access is ever required or attempted; the app runs only on
    `127.0.0.1`.
