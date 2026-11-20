# Export ---------------------------------------------------------------------

#' Export segments, codebook, codings or the audit trail
#'
#' Writes files into `path` (default: `exports/` next to the project file).
#'
#' * `"segments"`: all codings with extracted text -- CSV, plus `.xlsx` if the
#'   `writexl` package is installed
#' * `"codings"`: raw codings table -- CSV
#' * `"codebook"`: the code tree -- CSV and `.docx` (via officer)
#' * `"audit"`: the full events audit trail -- CSV
#' * `"report"`: a standalone HTML report -- all documents with colored coding
#'   marks, the codebook, all memos and project statistics
#' * `"all"`: all of the above
#'
#' @param what One or more of `"all"`, `"segments"`, `"codings"`, `"codebook"`,
#'   `"audit"`, `"report"`.
#' @param path Output directory (created if missing).
#' @return Invisibly, a tibble of written files: `file`, `what`, `rows`.
#' @export
#' @examples
#' \dontrun{
#' qda_export("all")
#' qda_export("audit")   # for the methods section
#' }
qda_export <- function(what = "all", path = NULL) {
  con <- qda_con()
  what <- match.arg(what, c("all", "segments", "codings", "codebook", "audit", "report"),
                    several.ok = TRUE)
  if ("all" %in% what) what <- c("segments", "codings", "codebook", "audit", "report")
  dir <- path %||% file.path(project_dir(), "exports")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  ts <- format(Sys.time(), "%Y%m%d-%H%M%S", tz = "UTC")
  written <- list()
  add <- function(file, what_, rows) {
    written[[length(written) + 1]] <<- tibble::tibble(file = file, what = what_, rows = rows)
  }
  if ("segments" %in% what) {
    df <- qda_codings()
    f <- file.path(dir, paste0("segments_", ts, ".csv"))
    readr::write_csv(df, f)
    add(f, "segments", nrow(df))
    if (requireNamespace("writexl", quietly = TRUE)) {
      f2 <- file.path(dir, paste0("segments_", ts, ".xlsx"))
      writexl::write_xlsx(as.data.frame(df), f2)
      add(f2, "segments", nrow(df))
    }
  }
  if ("codings" %in% what) {
    df <- DBI::dbGetQuery(con, "SELECT * FROM codings ORDER BY id")
    f <- file.path(dir, paste0("codings_", ts, ".csv"))
    readr::write_csv(df, f)
    add(f, "codings", nrow(df))
  }
  if ("codebook" %in% what) {
    df <- qda_codes()
    f <- file.path(dir, paste0("codebook_", ts, ".csv"))
    readr::write_csv(df, f)
    add(f, "codebook", nrow(df))
    doc <- officer::read_docx()
    doc <- officer::body_add_par(doc, "jellyqda codebook", style = "heading 1")
    if (nrow(df) > 0) {
      for (i in seq_len(nrow(df))) {
        line <- paste0(df$path[i], if (nzchar(df$description[i])) paste0(" -- ", df$description[i]) else "")
        doc <- officer::body_add_par(doc, line)
      }
    }
    f2 <- file.path(dir, paste0("codebook_", ts, ".docx"))
    print(doc, target = f2)
    add(f2, "codebook", nrow(df))
  }
  if ("audit" %in% what) {
    df <- DBI::dbGetQuery(con, "SELECT id, action, details, created_at FROM events ORDER BY id")
    f <- file.path(dir, paste0("audit_", ts, ".csv"))
    readr::write_csv(df, f)
    add(f, "audit", nrow(df))
  }
  if ("report" %in% what) {
    f <- file.path(dir, paste0("report_", ts, ".html"))
    writeLines(.report_html(), f, useBytes = TRUE)
    add(f, "report", 1L)
  }
  files <- vapply(written, function(w) w$file, character(1))
  log_event("export", list(what = what, files = files))
  invisible(do.call(rbind, written))
}

# --- standalone HTML report ---------------------------------------------------
#' @noRd
.report_html <- function() {
  con <- qda_con()
  esc <- htmltools::htmlEscape
  st <- qda_stats()$overall
  codes <- qda_codes()
  srcs <- DBI::dbGetQuery(con, "SELECT id, name, format, meta_json FROM sources ORDER BY id")
  memos <- qda_memos()
  css <- paste(
    "body{font-family:Georgia,serif;max-width:60rem;margin:2rem auto;color:#222;line-height:1.55}",
    "h1{border-bottom:3px solid #2c6fbb;padding-bottom:.3rem}",
    "h2{margin-top:2.2rem;border-bottom:1px solid #ccc;padding-bottom:.2rem}",
    "#doc{margin:.6rem 0 1.4rem 0}",
    ".segtext{position:relative;padding-left:3.2rem;margin:.35rem 0}",
    ".segtext::before{content:'Seg ' attr(data-seg);position:absolute;left:0;top:.15rem;font-size:.68rem;color:#8a94a0;font-family:sans-serif}",
    "mark{padding:0 .12em;border-radius:.25em}",
    "mark.memomark{background:transparent;border-bottom:3px solid #b58900}",
    "mark.dup{outline:2px dashed #d81b60;outline-offset:1px}",
    "table{border-collapse:collapse;font-size:.85rem}td,th{border:1px solid #ccc;padding:.15rem .5rem}",
    ".swatch{display:inline-block;width:.8em;height:.8em;border-radius:.2em;margin-right:.4em;vertical-align:-.05em}",
    ".meta{color:#6b7683;font-size:.8rem;font-family:sans-serif}",
    ".memo{background:#fff8e1;border:1px solid #e0c96a;border-radius:.4rem;padding:.4rem .6rem;margin:.3rem 0;font-size:.9rem}",
    sep = "\n")
  cb_rows <- if (nrow(codes) == 0) "" else paste(vapply(seq_len(nrow(codes)), function(i) {
    sprintf('<tr><td><span class="swatch" style="background-color:%s"></span>%s</td><td>%d</td><td>%s</td></tr>',
            esc(codes$color[i]), esc(codes$path[i]), codes$n_codings[i], esc(codes$description[i]))
  }, character(1)), collapse = "")
  src_html <- if (nrow(srcs) == 0) "<p><em>No sources.</em></p>" else paste(vapply(seq_len(nrow(srcs)), function(i) {
    m <- jsonlite::fromJSON(srcs$meta_json[i])
    vars <- if (!is.null(m$variables) && length(m$variables) > 0) {
      paste0('<div class="meta">', paste(names(m$variables), unlist(m$variables), sep = " = ", collapse = " | "), "</div>")
    } else ""
    paste0("<h2>", esc(srcs$name[i]), "</h2>",
           '<div class="meta">', esc(srcs$format[i]), " | ",
           nchar(.resolve_source(srcs$id[i])$frozen_text, type = "chars"), " chars</div>",
           vars, .render_doc_html(srcs$id[i]))
  }, character(1)), collapse = "\n")
  memo_html <- if (nrow(memos) == 0) "" else paste(vapply(seq_len(nrow(memos)), function(i) {
    sprintf('<div class="memo"><b>#%d</b> <span class="meta">%s</span><br>%s</div>',
            memos$id[i], esc(memos$created_at[i]), esc(memos$text_[i]))
  }, character(1)), collapse = "\n")
  paste0(
    "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>jellyqda report - ",
    esc(basename(project_path())), "</title><style>", css, "</style></head><body>\n",
    "<h1>jellyqda report: ", esc(basename(project_path())), "</h1>\n",
    '<div class="meta">generated ', format(Sys.time(), tz = "UTC"), " UTC | ",
    st$n_sources, " sources | ", st$n_codes, " codes | ", st$n_codings, " codings | ",
    st$n_memos, " memos | ", sprintf("%.1f", st$pct_coded), "% coded</div>\n",
    "<h2>Codebook</h2><table><tr><th>Code</th><th>n</th><th>Description</th></tr>", cb_rows, "</table>\n",
    "<h2>Memos</h2>", memo_html, "\n",
    "<h2>Documents with coding marks</h2>", src_html, "\n",
    "</body></html>"
  )
}
