> 🌐 **English** · [Deutsch](de/R-Funktionen.md)

# R functions

Everything the app can do also works as R code: handy for reproducible
analyses. All functions return **tibbles**. Detailed help for every function:
`?qda_code` etc. A commented template is in
`inst/examples/jellyqda-template.R` (German: `jellyqda-vorlage.R`).

## Project

| Function | Purpose |
|---|---|
| `qda_open(path, auto_snapshot = 25)` | open or create a project |
| `qda_close()` | close the project |
| `qda_project()` | overview: file, size, number of entries |
| `qda_app(new_window = TRUE, lang = NULL)` | start the app (`lang = "en"` or `"de"`) |
| `qda_language(lang)` | get/set the language of app and report |

## Documents

| Function | Purpose |
|---|---|
| `qda_import(files, segments = "blankline")` | import and freeze txt/md/docx/pdf |
| `qda_sources()` | all documents |
| `qda_view(source)` | document with marks in the Viewer |
| `qda_source_vars()` / `qda_source_set_var()` / `qda_source_del_var()` | variables |

## Segments

| Function | Purpose |
|---|---|
| `qda_source_segments(source)` | segments of a document |
| `qda_segments_set(source, rule, pattern)` | re-segment: `"blankline"`, `"speaker"`, `"line"` |
| `qda_segment_split(source, at)` | split a segment |
| `qda_segment_merge(source, segment)` | merge with the next one |
| `qda_segment_define(source, start, end)` | define a segment of your own |
| `qda_segments_reset(source)` | back to automatic (blank lines) |

## Codes and codings

| Function | Purpose |
|---|---|
| `qda_codes()` | code system (with path and counts) |
| `qda_code_add(label, parent, color, description)` | create a code or subcode |
| `qda_code_rename()` / `qda_code_move()` / `qda_code_delete()` | rename, move (make a subcode), delete |
| `qda_code_set_color(code, color)` | change the colour of a code family |
| `qda_code_guide(code, definition, anchor, rule)` | coding guideline of a code |
| `qda_code_merge(from, into)` | merge two codes |
| `qda_code(source, code, segment | start, end, memo)` | assign a code |
| `qda_autocode(pattern, code, scope)` | code every occurrence of a term |
| `qda_codings(source, code)` | codings with text |
| `qda_coding_set_memo(coding, memo)` | set a comment |
| `qda_coding_recode(coding, code)` | re-code a coding (e.g. to a subcode) |
| `qda_coding_set_summary(coding, paraphrase, generalization)` | Mayring: paraphrase, generalisation |
| `qda_coding_delete(coding)` | delete a coding |
| `qda_segments(code)` | all passages of a code |

## Memos

| Function | Purpose |
|---|---|
| `qda_memo_add(text, source, start, end, code, title, kind)` | create a memo (the kind follows from the arguments) |
| `qda_memos(kind, source, code)` | list/filter memos |
| `qda_memo_update(memo, text, title)` | edit |
| `qda_memo_delete(memo)` | delete |

## Analysis, backup, history

| Function | Purpose |
|---|---|
| `qda_stats()` | progress overall and per document |
| `qda_matrix()` | codes × documents |
| `qda_case_matrix(by)` | case comparison: codes × values of a variable |
| `qda_words(source, code, n)` | word frequencies |
| `qda_kwic(pattern, width)` | keyword in context |
| `qda_query(all, any, none, vars)` | passages by a combination of codes (AND / OR / NOT), optionally by document variables |
| `qda_query_to_code(hits, code)` | code the hits of a query |
| `qda_survey_columns(file)` / `qda_import_survey(file)` | import open answers from a survey (CSV / Excel) |
| `qda_cooccurrence(unit, level)` | code co-occurrence: pairs of codes that occur together |
| `qda_cooccurrence_passages(code_a, code_b)` | the passages where two codes occur together |
| `qda_portrait(source, level)` | document portrait: which codes in which segment |
| `qda_plot_cooccurrence()` / `qda_plot_network()` / `qda_plot_portrait()` | the graphics as SVG (Viewer or `file =`) |
| `qda_export_qdpx(path)` | REFI-QDA project file for MAXQDA, ATLAS.ti, NVivo, QualCoder |
| `qda_intercoder_copy(path)` | blind copy of the project for a second coder (no codings) |
| `qda_intercoder(other, unit, level)` | intercoder agreement: percent, Cohen's kappa, Brennan & Prediger, Krippendorff's alpha |
| `qda_intercoder_diff(other)` | units on which the two coders disagree |
| `qda_intercoder_adopt(other, source, start, end, code)` | consensus: take over the other coder's coding |
| `qda_summary_set()` / `qda_summaries()` | summary grid |
| `qda_export(what, path)` | `"segments"`, `"codings"`, `"codebook"`, `"audit"`, `"report"`, `"all"` |
| `qda_backup(path, keep = 10)` | ZIP backup |
| `qda_undo()` / `qda_redo()` / `qda_history()` | undo / redo |
| `qda_events()` | audit trail |

## Example: complete workflow

```r
library(jellyqda)
qda_open("my-thesis.jellyqda")
qda_import(list.files("transcripts", full.names = TRUE), segments = "speaker")

qda_code_add("Career path", description = "Stations of the career")
qda_code_add("SME", parent = "Career path")
qda_code_guide("SME", rule = "Only explicit statements")

qda_code(source = 1, segment = 3, code = "SME")
qda_segments("SME")

library(dplyr)
qda_codings() |> count(code, source)      # frequencies
qda_export("all"); qda_backup()
```

## RStudio addins

The RStudio menu **Addins** has two entries for the open project:
*jellyqda: Backup project* and *jellyqda: Show coding stats*.
