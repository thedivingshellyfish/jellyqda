# jellyqda 0.9.3

## New features

  * **Code queries (AND / OR / NOT).** New tab **Abfrage / Query** in the
    analysis window and `qda_query()`: passages that contain all of some
    codes, at least one of others and none of a third group, in the same
    segment or document, optionally only in documents with certain variable
    values ("Workload AND Leadership, but NOT Family, only nurses"). Subcodes
    count with their code (can be switched off). Hits are listed with
    "Show", can be **saved as a code** (`qda_query_to_code()`, one undo step)
    and downloaded as CSV.
  * **Survey import.** Open answers from online surveys (SoSci Survey,
    LimeSurvey, Qualtrics, Google Forms ...) as CSV or Excel: button
    **Fragebogen importieren / Import a survey** in the documents panel,
    `qda_survey_columns()` and `qda_import_survey()`. One document per
    respondent, every open answer a segment, chosen columns as document
    variables, optionally pre-coded by question. The dialog suggests the
    column roles and shows a preview. Re-importing skips respondents already
    there. Excel needs the suggested package 'readxl'; CSV works without.
    Fictional example: `inst/extdata/survey_demo.csv`
    (`data-raw/make_survey_demo.R`).

## Other

  * The old German copies in the wiki folder (`docs/wiki/Analysieren.md`
    ...) are removed; the German wiki lives in `docs/wiki/de/`.

# jellyqda 0.9.2

  * **Wiki on the website:** the guide from `docs/wiki/` is built as HTML
    pages in the style of the website (sidebar, light/dark, English and
    German) at <https://thedivingshellyfish.github.io/jellyqda/wiki/>, with
    every push to `main` (`dev/wiki/build_wiki.sh`, pandoc). The wiki source
    stays in `docs/wiki/`; links between pages and screenshots are rewritten
    automatically.
  * **Website:** new section "New in 0.8 and 0.9" (intercoder, graphics,
    REFI-QDA export, report dialog) in English and German; version and links
    to the new web wiki updated; the site icon is loaded from the site itself.
  * **Browser-tab icon:** the app and the report show the jellyqda logo
    (embedded, works offline).
  * **CRAN:** a project lying directly in R's temporary folder (examples,
    tests) keeps its backups inside its folder, so nothing is left behind in
    the temporary folder ("detritus" note of `R CMD check`); the
    `qda_backup()` example no longer writes there either.

# jellyqda 0.9.1

## New features

  * **Report dialog.** The **Report** button opens a dialog with two
    choices and the expected time for this project: **overview** (code
    system, graphics, codebook, memos, coded passages, intercoder -- without
    the documents; a few seconds even with 150 interviews) or **complete**
    (with every document, A4). From 50 documents on the overview is
    preselected.
  * **Progress bar** while the report is built ("Document 87 of 150 ..."),
    in the dialog and for "Save report as HTML file" / "Export everything".
    The report opens in a tab the browser opened right away, so popup
    blockers do not interfere.
  * **If nothing moves for a minute** the dialog offers "keep waiting" or
    "back" (the result is then discarded).
  * **"Working ..."** at the bottom of the window whenever a step takes
    longer than 0.8 s.
  * `qda_export("report", report_documents = FALSE)` writes the overview.

## Performance

  * Report portraits are drawn compactly (no tooltips, neighbouring
    segments with the same codes merged): with 150 interviews the overview
    report shrinks from 8.5 to 4.2 MB, the portraits from 5.3 to 0.95 MB.

# jellyqda 0.9.0

## New features

  * **Graphics** (toolbar button **Grafiken / Graphics**, three tabs):
      * **Code co-occurrence** as a heatmap: which codes occur together, and
        how often (`qda_cooccurrence()`, `qda_plot_cooccurrence()`).
        "Together" means in the same segment (default), in the same
        document, or overlapping codings; every code or code families;
        count or Jaccard index. A click on a cell lists the passages
        (`qda_cooccurrence_passages()`).
      * **Code network**: codes as circles (size = frequency, colour = code
        family), lines for co-occurrence (width = how often); layout as a
        circle in code-tree order or by connections (`qda_plot_network()`).
      * **Document portraits**: one strip per document from start to end,
        every segment a block in the colours of its codes -- where in the
        interviews do the themes come up? (`qda_portrait()`,
        `qda_plot_portrait()`). A click jumps to the passage.
    All graphics are plain SVG made by R: no new dependencies, offline, in
    the RStudio Viewer, the app (light and dark mode) and the report; every
    mark has a tooltip; "Save as SVG" in the app or `file =` in R.
  * **Report:** new sections "Code co-occurrence" (heatmap + network) and
    "Document portraits".
  * **REFI-QDA export (.qdpx)** for MAXQDA, ATLAS.ti, NVivo, QualCoder and
    other programs: `qda_export_qdpx()`, `qda_export("qdpx")`, export menu in
    the app. Code system with colours and coding guideline, documents,
    codings with comments and Mayring fields, all memos, document variables.
    Validated against the REFI-QDA project schema (QDA-XML 1.0).

## Performance

  * Stress test with 15, 50 and 150 fictional interviews (`dev/stress_test.R`,
    results in `dev/stress-test-results.md`).
  * Units of analysis are found with `findInterval()` (R/units.R, shared by
    intercoder agreement, co-occurrence and portraits).

## Code organisation

  * New files, one per topic: `units.R`, `cooccurrence.R`, `portrait.R`,
    `plot_svg.R`, `plot_cooccurrence.R`, `plot_network.R`,
    `plot_portrait.R`, `app_server_visuals.R`, `report_visuals.R`,
    `export_qdpx.R`; `css/10-visuals.css`, `js/18-visuals.js`;
    `data-raw/transcript_generator.R`; tests per topic.
  * New demo `demo/jellyqda-visuals-demo.R`.

# jellyqda 0.8.0

## New features

  * **Intercoder agreement.** Two people code the same material
    independently, each in their own project file; jellyqda compares them.
    New tab **Intercoder** in the analysis window and four functions:
      * `qda_intercoder_copy()`: blind copy of the project for the second
        coder -- same documents, segments, code system and coding guideline
        (code memos), but no codings, summaries, other memos or audit trail.
      * `qda_intercoder()`: percent agreement, **Cohen's kappa** (with the
        rating after Landis & Koch), **Brennan & Prediger's kappa** and
        **Krippendorff's alpha** (nominal), per code and overall (pooled, plus
        the mean kappa). Units of analysis are the segments (e.g. speaker
        turns) or whole documents; categories are every code and subcode or
        code families. A unit counts as coded when a coding touches it
        (`min_overlap`), so both coders need not mark the same words.
        Documents are matched by their text, codes by their path.
      * `qda_intercoder_diff()`: every unit where only one coder coded --
        the material for the consensus discussion. In the app: **Show** jumps
        to the passage.
      * `qda_intercoder_adopt()`: take over the other coder's coding(s) of a
        unit (consensus coding); one undo step. In the app: **Take over**.
  * The other project file is opened read-only and never changed.
  * Every comparison is recorded in the audit trail; the report gets a
    section **Intercoder agreement** with the last independent comparison
    (values after taking over codings are not recorded on purpose).
  * The analysis window remembers its last tab.
  * New demo `demo/jellyqda-intercoder-demo.R`: three fictional interviews,
    two coders, comparison and consensus. New wiki page "Intercoder
    agreement" (English and German).

## Example data and demos

  * **New English example files**, clearly marked as fictional: every file
    in `inst/extdata/` and `demo/` starts with a "DEMO FILE - fictional"
    line, and both folders have a README. The short examples in
    `inst/extdata/` keep their names (`interview_01.txt` ...); the demo
    transcripts are now `demo/demo_interview_10min.txt` ... `120min.txt`
    (an invented study "Working in small software companies") and replace
    the German nonsense-word dummies. Generated by `data-raw/make_extdata.R`
    and the new `data-raw/make_demo_transcripts.R`.
  * `qda_words()` also leaves out **English stop words and fillers**
    ("the", "and", "um", "you know" ...). The lists moved to their own file
    `R/stopwords.R`.
  * Code organisation: the intercoder functions live in one file each
    (`R/intercoder*.R`, overview in `R/intercoder_stats.R`), the report
    section in `R/report_intercoder.R`; tests in `test-intercoder*.R`.

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

  * **Codings no longer shift after emoji.** The browser counted text length
    in UTF-16 code units, R counts characters, so every emoji (or other
    character outside the Basic Multilingual Plane) before a selection moved
    the stored coding by one character. Selection, cursor and "jump to"
    positions now count characters exactly like R.
  * **`qda_import()` never overwrites an original.** A different file with a
    name that is already taken (e.g. `a/interview.txt` and `b/interview.txt`)
    is imported as `interview (2).txt`; before, its copy replaced the first
    original in `originals/` and the name matched two sources.
  * **Umlauts in the German interface.** Undo/redo tooltips, notifications and
    audit-trail texts showed "geaendert", "geloescht", "fuer" etc.; all
    German texts now use real umlauts. A test guards against regressions.
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
