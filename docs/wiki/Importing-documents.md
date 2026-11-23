> 🌐 **English** · [Deutsch](de/Dokumente-importieren.md)

# Importing documents

<img src="../screenshots/03-dokumente-import.png" alt="Documents panel" width="298">

## Supported formats

| Format | Note |
|---|---|
| `.txt`, `.md` | the encoding (UTF-8, Latin-1, …) is detected automatically |
| `.docx` | Word documents; the text is taken over |
| `.pdf` | only PDFs with a text layer. Scanned PDFs without text produce a warning; use OCR first |

## How to

1. Choose **Segments on import**: blank lines (paragraphs), speaker turns or
   every line. More under [Segments](Segments.md). This can be changed at any
   time later.
2. Click **Files…** or **drop files on the panel**.
3. Click **Import**.

As an R script:

```r
qda_import(c("interview_01.docx", "interview_02.txt"), segments = "speaker")
```

## What happens on import

- The text is **frozen**: read once, converted to UTF-8 and stored in the
  project file. It is never read again. That is why codings never drift, even
  if you change the original file later.
- The **original file** is copied unchanged into the folder `originals/` next
  to the project file.
- Importing the same file a second time is detected and skipped.

## Variables (case attributes)

You can give every document attributes such as *age*, *role* or *duration*.
At the bottom of the documents panel: choose the document, enter variable and
value, **Set variable**.

<img src="../screenshots/04-variablen-segmente.png" alt="Variables of a document" width="298">

The variables appear as chips above the text. In the codings list you can
filter with **"Only documents with variable"**, e.g. `role=project lead`.
They are also the basis of the [case comparison](Analysis.md#case-comparison).

```r
qda_source_set_var("interview_01.docx", "age", "34")
qda_source_vars(1)
qda_source_del_var(1, "age")
```
