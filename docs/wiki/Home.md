> 🌐 **English** · [Deutsch](de/Home.md)

# jellyqda wiki

**jellyqda** is a small, free tool for the **qualitative analysis of
interviews** in R and RStudio: completely offline, no cloud. This wiki
explains every function step by step with screenshots.

<img src="../screenshots/01-uebersicht.png" alt="Overview of the app" width="1440">

## Getting started

1. **[Installation](Installation.md):** once, one line in R
2. **[First steps](First-steps.md):** create a project, start the app, code the first interview
3. **[The user interface](User-interface.md):** what is where, adjusting the layout, dark mode, language

## Working with jellyqda

| Topic | What it is about |
|---|---|
| [Importing documents](Importing-documents.md) | load transcripts (txt, md, docx, pdf), open answers from surveys (CSV, Excel), variables such as age or role |
| [Coding](Coding.md) | build the code system with codes and subcodes, mark text, assign codes, overlaps |
| [Segments](Segments.md) | paragraphs or speaker turns, splitting and merging segments |
| [Memos](Memos.md) | passage, document, code and project memos, comments |
| [Analysis](Analysis.md) | coding guideline, in vivo, merging codes, coding search hits, case comparison, word frequencies, keyword in context, Mayring, queries (AND / OR / NOT) |
| [Intercoder agreement](Intercoder-agreement.md) | blind copy for a second coder, Cohen's kappa, Krippendorff's alpha, disagreements and consensus |
| [Graphics](Graphics.md) | code co-occurrence (heatmap), code network, document portraits |
| [Evaluation & export](Evaluation-and-export.md) | codings per code, search, code matrix, summary grid, export, A4 report |
| [Undo & data safety](Undo-and-data-safety.md) | Ctrl+Z/Ctrl+Y, audit trail, backups, privacy |

## Reference

- [Keyboard shortcuts](Keyboard-shortcuts.md)
- [R functions](R-functions.md): everything works as a script, too
- [Troubleshooting](Troubleshooting.md)

## The idea in three sentences

A project is **one single file** (`my-thesis.jellyqda`) on your computer. On
import the text is **frozen**; all codings and memos remember the exact
character position and never drift. Every action is logged with a time stamp
and can be undone.
