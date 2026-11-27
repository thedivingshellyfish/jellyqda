# jellyqda :: export.R -- qda_export(): CSV/XLSX/DOCX exports + standalone
# HTML report (.report_html(), reuses .render_doc_html() from render.R).
# Writes to exports/ next to the project file; every export is logged.

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
#' * `"qdpx"`: the whole project in the REFI-QDA exchange format for MAXQDA,
#'   ATLAS.ti, NVivo, QualCoder ... (see [qda_export_qdpx()])
#' * `"all"`: all of the above except `"qdpx"`
#'
#' @param what One or more of `"all"`, `"segments"`, `"codings"`, `"codebook"`,
#'   `"audit"`, `"report"`, `"qdpx"`.
#' @param path Output directory (created if missing).
#' @param report_documents Logical; include every document with its marks in
#'   the report (`TRUE`, default). `FALSE` writes the overview only, which is
#'   much faster and smaller for large projects.
#' @return Invisibly, a tibble of written files: `file`, `what`, `rows`.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path")
#' qda_code_add("SME", parent = "Career path")
#' qda_code(1, "SME", segment = 2)
#' out <- qda_export("all")
#' basename(out$file)
#' qda_export("audit")   # for the methods section
#' qda_close()
qda_export <- function(what = "all", path = NULL, report_documents = TRUE) {
  con <- qda_con()
  what <- match.arg(what, c("all", "segments", "codings", "codebook", "audit", "report", "qdpx"),
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
    # in code-tree order; depth 1 = code, 2+ = subcode
    df <- .code_tree(qda_codes())
    df <- df[, c("id", "label", "parent_id", "color", "description", "anchor", "coding_rule", "path", "n_codings", "depth")]
    f <- file.path(dir, paste0("codebook_", ts, ".csv"))
    readr::write_csv(df, f)
    add(f, "codebook", nrow(df))
    cm <- qda_memos(kind = "code")
    doc <- officer::read_docx()
    doc <- officer::body_add_par(doc, .t("Codebuch"), style = "heading 1")
    if (nrow(df) > 0) {
      for (i in seq_len(nrow(df))) {
        # Code = Ueberschrift 2, Subcode = Ueberschrift 3, tiefer = fetter Absatz
        title <- sprintf(.t("%s (%d Codings)"), df$label[i], df$n_codings[i])
        doc <- if (df$depth[i] <= 2L) {
          officer::body_add_par(doc, title, style = if (df$depth[i] == 1L) "heading 2" else "heading 3")
        } else {
          officer::body_add_fpar(doc, officer::fpar(officer::ftext(
            paste0(strrep("    ", df$depth[i] - 3L), "\u21b3 ", title), officer::fp_text(bold = TRUE))))
        }
        if (df$depth[i] > 1L) doc <- officer::body_add_par(doc, paste(.t("Pfad:"), gsub(" / ", " > ", df$path[i], fixed = TRUE)))
        if (nzchar(df$description[i])) doc <- officer::body_add_par(doc, paste(.t("Definition:"), df$description[i]))
        if (nzchar(df$anchor[i])) doc <- officer::body_add_par(doc, paste(.t("Ankerbeispiel:"), df$anchor[i]))
        if (nzchar(df$coding_rule[i])) doc <- officer::body_add_par(doc, paste(.t("Kodierregel:"), df$coding_rule[i]))
        m <- cm[!is.na(cm$code_id) & cm$code_id == df$id[i], , drop = FALSE]
        for (j in seq_len(nrow(m))) {
          doc <- officer::body_add_par(doc, paste0(if (nzchar(m$title[j])) paste0(m$title[j], ": ") else "", m$text_[j]))
        }
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
    # (the app sets .jellyqda_env$progress for a progress bar, R/app_server_analysis.R)
    writeLines(.report_html(documents = report_documents, progress = .jellyqda_env$progress), f, useBytes = TRUE)
    add(f, "report", 1L)
  }
  if ("qdpx" %in% what) {   # R/export_qdpx.R
    f <- qda_export_qdpx(file.path(dir, paste0(sub("\\.jellyqda$", "", basename(project_path())), "_", ts, ".qdpx")))
    add(f, "qdpx", nrow(qda_sources()))
  }
  files <- vapply(written, function(w) w$file, character(1))
  log_event("export", list(what = what, files = files))
  invisible(do.call(rbind, written))
}

# --- standalone HTML report ---------------------------------------------------
# Print-ready on A4 (Ctrl+P in the browser): colours only appear in borders,
# lines and underlines, never as filled areas -- so the report looks complete
# even without the print option "background graphics".
# Sections: code system and frequencies (with share in %), case comparison,
# codebook (coding guideline), memos, coded passages, Mayring summary,
# documents with marks and margin column. UI language: .t() (R/i18n.R).
#' @noRd
.report_html <- function(documents = TRUE, progress = NULL) {
  # progress(value 0..1, detail): optional callback for a progress bar (the
  # app shows it in the report dialog, R/app_server_report.R)
  step <- function(v, detail) if (is.function(progress)) progress(v, detail)
  step(0.02, .t("Codesystem und H\u00e4ufigkeiten"))
  con <- qda_con()
  esc <- htmltools::htmlEscape
  st <- qda_stats()$overall
  codes <- .code_tree(qda_codes())
  srcs <- DBI::dbGetQuery(con, "SELECT id, name, format, meta_json FROM sources ORDER BY id")
  memos <- qda_memos()
  cods <- qda_codings()
  proj <- basename(project_path())
  num <- function(x, d = 1) if (.lang() == "de") formatC(x, format = "f", digits = d, big.mark = ".", decimal.mark = ",") else formatC(x, format = "f", digits = d, big.mark = ",")
  path_lab <- function(p) gsub(" / ", " \u203a ", p, fixed = TRUE)

  css <- paste(
    paste0("@page{size:A4;margin:16mm 15mm 18mm 15mm;",
           "@bottom-left{content:'jellyqda \\00b7 ", gsub("['\\\\\n]", "", proj), "';font:8pt sans-serif;color:#666}",
           if (.lang() == "de") "@bottom-right{content:'Seite ' counter(page) ' von ' counter(pages);font:8pt sans-serif;color:#666}}"
           else "@bottom-right{content:'Page ' counter(page) ' of ' counter(pages);font:8pt sans-serif;color:#666}}"),
    ":root{--ink:#1a1a1a;--muted:#5a5a5a;--rule:#cfcfcf}",
    "*{box-sizing:border-box}",
    "html{background:#c9d0d8}",
    "body{margin:0;padding:24px 12px 48px;font:10.5pt/1.5 'Segoe UI',system-ui,-apple-system,Helvetica,Arial,sans-serif;color:var(--ink)}",
    ".sheet{width:210mm;max-width:100%;min-height:297mm;margin:0 auto 24px;background:#fff;padding:18mm 17mm 16mm;box-shadow:0 2px 12px rgba(0,0,0,.25)}",
    ".bar{width:210mm;max-width:100%;margin:0 auto 14px;display:flex;gap:12px;align-items:center;justify-content:space-between;font-size:9.5pt;color:#1d2630}",
    ".bar button{font:inherit;border:1px solid #2c6fbb;background:#2c6fbb;color:#fff;border-radius:6px;padding:5px 12px;cursor:pointer}",
    "h1{font-size:19pt;margin:0 0 2px}",
    "h2{font-size:12.5pt;margin:22px 0 8px;padding-bottom:3px;border-bottom:1.5px solid var(--ink);break-after:avoid}",
    "h3{font-size:10.5pt;margin:14px 0 6px;break-after:avoid}",
    ".meta{color:var(--muted);font-size:9pt}",
    ".kpis{display:flex;flex-wrap:wrap;gap:6px 26px;margin:14px 0 4px;font-size:9pt;color:var(--muted)}",
    ".kpis b{display:block;font-size:15pt;color:var(--ink);font-variant-numeric:tabular-nums}",
    "table{border-collapse:collapse;width:100%;font-size:9pt;font-variant-numeric:tabular-nums}",
    ".rsvg{margin:6px 0 12px;break-inside:avoid}.rsvg svg{max-width:100%;height:auto}",
    "th{overflow-wrap:anywhere;font-weight:600;color:var(--muted);font-size:7.5pt;text-transform:uppercase;letter-spacing:.05em;text-align:right;padding:4px 5px;border-bottom:1px solid var(--ink);vertical-align:bottom}",
    "td{padding:4px 5px;border-bottom:1px solid var(--rule);text-align:right;vertical-align:top}",
    "th:first-child,td:first-child{text-align:left}",
    "tr{break-inside:avoid}",
    "tr.top td{font-weight:600}",
    "tr.total td{border-top:1.5px solid var(--ink);border-bottom:0;font-weight:700}",
    ".rc{display:flex;align-items:center;gap:6px}",
    ".sw{display:inline-block;width:10px;height:10px;border-radius:2px;border:5px solid var(--c);flex:none}",
    ".sw.sub{border-width:2px}",
    ".pc{display:flex;align-items:center;justify-content:flex-end;gap:6px;white-space:nowrap}",
    ".pc .track{width:70px;height:7px;position:relative;border-left:1px solid var(--rule)}",
    ".pc .fill{position:absolute;left:0;top:0;height:7px;border-top:7px solid var(--c)}",
    ".pc .fill.sub{border:1.5px solid var(--c)}",
    ".legend{font-size:8pt;color:var(--muted);margin-top:6px}",
    ".cb td{font-size:9pt}",
    ".memo{border-left:3px solid #b58900;padding:2px 0 2px 9px;margin:0 0 9px;break-inside:avoid}",
    ".memo .ref{display:block;font-size:8pt;color:var(--muted)}",
    ".quote{border-left:3px solid var(--c);padding:1px 0 1px 9px;margin:0 0 9px;break-inside:avoid}",
    ".quote .ref{display:block;font-size:8pt;color:var(--muted)}",
    ".quote q{font-family:Georgia,'Times New Roman',serif;quotes:none}",
    ".quote .cmt{display:block;font-size:8.5pt;color:var(--muted);font-style:italic}",
    ".doc + .doc{page-break-before:always;break-before:page}",
    ".gl{margin:0 0 3px}.gl span{display:inline-block;min-width:92px;font-size:7.5pt;text-transform:uppercase;letter-spacing:.04em;color:var(--muted)}",
    "table.may td{font-size:8.5pt}",
    # document: text on the left, margin column on the right, threads in the colour of the code family
    ".rdoc{margin:.4rem 0 1rem}",
    ".rseg{display:grid;grid-template-columns:minmax(0,1fr) 36%;column-gap:18px;margin:.15rem 0 .45rem;break-inside:auto}",
    ".rtext{white-space:pre-wrap;font-family:Georgia,'Times New Roman',serif;font-size:9.5pt;line-height:1.7;min-width:0}",
    ".rmargin{display:flex;flex-direction:column;gap:5px;border-left:1px dotted var(--rule);padding-left:9px;min-width:0}",
    ".card{position:relative;border-left:3px solid var(--c,#888);padding:1px 0 2px 7px;font-size:7.8pt;line-height:1.35;break-inside:avoid}",
    ".card::before{content:'';position:absolute;left:-28px;top:.75em;width:24px;border-top:1.5px solid var(--c,#888)}",
    ".card .rc{display:inline-flex;gap:4px;vertical-align:baseline}",
    ".card .cmt{color:var(--muted);font-style:italic;margin-top:1px}",
    ".card.mcard{--c:#b58900}",
    ".anc{display:inline-block;min-width:1.45em;padding:0 .2em;margin-right:3px;border:1.2px solid var(--c,#888);border-radius:.8em;font:700 6.5pt/1.3 'Segoe UI',system-ui,sans-serif;color:var(--ink);text-align:center;vertical-align:.3em;white-space:nowrap}",
    ".anc.memo{--c:#b58900;border-style:dashed}",
    ".card > .anc{vertical-align:.1em}",
    ".segtext{position:relative;padding-left:2.6rem}",
    ".segtext::before{content:'Seg ' attr(data-seg);position:absolute;left:0;top:.2rem;font:7pt sans-serif;color:#8a8a8a}",
    ".segtext.pre::before{content:''}",
    # marks without background: underline in the colour of the code family
    ".rdoc mark{background:none!important;color:inherit;padding:0;border-bottom:2.5px solid var(--c,#777)}",
    ".rdoc mark.sub{border-bottom-style:dashed}",
    ".rdoc mark.sub.tagstart::before{content:attr(data-tag);font:600 6.5pt/1.2 sans-serif;border:1px solid var(--c);border-radius:2px;padding:0 3px;margin-right:3px;vertical-align:.2em}",
    ".rdoc mark.ovl{border-bottom:2.5px dotted #555}",
    ".rdoc mark.ovl.ovl-start::before{content:attr(data-n);font:700 6.5pt/1.2 sans-serif;border:1px solid #555;border-radius:8px;padding:0 3px;margin-right:2px;vertical-align:.2em}",
    ".rdoc mark.memomark{border-bottom:1.5px solid #b58900}",
    ".rdoc mark.dup{outline:1.5px dashed #d81b60;outline-offset:1px}",
    "@media print{html{background:none}body{padding:0}.sheet{width:auto;min-height:0;margin:0;padding:0;box-shadow:none}.bar{display:none}}",
    sep = "\n")

  # 1 code system and frequencies ------------------------------------------------
  n_src <- nrow(srcs)
  # many or long document names: columns D1, D2 ... + legend (fits on A4)
  short <- n_src > 4 || any(nchar(srcs$name) > 16)
  doc_head <- if (short) sprintf("D%d", seq_len(n_src)) else esc(sub("\\.[A-Za-z0-9]+$", "", srcs$name))
  own <- matrix(0, nrow = nrow(codes), ncol = n_src)
  if (nrow(cods) && nrow(codes) && n_src) {
    for (k in seq_len(nrow(cods))) {
      i <- match(cods$code_id[k], codes$id); j <- match(cods$source_id[k], srcs$id)
      if (!is.na(i) && !is.na(j)) own[i, j] <- own[i, j] + 1
    }
  }
  cnt <- own
  for (i in seq_len(nrow(codes))) {
    if (codes$has_children[i]) cnt[i, ] <- colSums(own[codes$id %in% .code_descendants(codes, codes$id[i]), , drop = FALSE])
  }
  total <- sum(own)
  freq_html <- if (nrow(codes) == 0) .t("<p class=\"meta\">Noch keine Codes.</p>") else {
    rows <- vapply(seq_len(nrow(codes)), function(i) {
      sub <- codes$depth[i] > 1L
      sm <- sum(cnt[i, ]); pct <- if (total > 0) 100 * sm / total else 0
      sprintf('<tr class="%s" style="--c:%s"><td><span class="rc" style="padding-left:%dpx"><span class="sw%s"></span>%s</span></td>%s<td><b>%d</b></td><td><span class="pc">%s %%<span class="track">%s</span></span></td></tr>',
              if (sub) "" else "top", esc(codes$root_color[i]), (codes$depth[i] - 1L) * 14L,
              if (sub) " sub" else "", esc(codes$label[i]),
              paste0("<td>", ifelse(cnt[i, ] > 0, as.integer(cnt[i, ]), "\u2013"), "</td>", collapse = ""),
              as.integer(sm), num(pct),
              if (sm > 0) sprintf('<span class="fill%s" style="width:%.1f%%"></span>', if (sub) " sub" else "", pct) else "")
    }, character(1))
    top <- codes$depth == 1L
    colsum <- if (n_src) colSums(cnt[top, , drop = FALSE]) else numeric()
    paste0('<table><thead><tr><th>Code</th>', paste0("<th>", doc_head, "</th>", collapse = ""),
           .t('<th>Summe</th><th>Anteil</th></tr></thead><tbody>'), paste(rows, collapse = ""),
           sprintf(.t('<tr class="total"><td>Gesamt</td>%s<td>%d</td><td><span class="pc">%s %%<span class="track"></span></span></td></tr>'),
                   paste0("<td>", as.integer(colsum), "</td>", collapse = ""), as.integer(total),
                   num(if (total > 0) 100 else 0)),
           "</tbody></table>",
           .t('<p class="legend">Anteil = Codings eines Codes an allen Codings. Codes z\u00e4hlen ihre Subcodes mit; '),
           .t('die Anteile der Codes auf oberster Ebene ergeben zusammen 100 %.'),
           if (short) paste0(.t(" Dokumente: "), paste(sprintf("D%d = %s", seq_len(n_src), esc(srcs$name)), collapse = "; "), ".") else "",
           "</p>")
  }

  # coding guideline: definition, anchor examples, coding rule, code memos ----
  cm <- memos[memos$kind == "code", , drop = FALSE]
  nl2br <- function(x) gsub("\n", "<br>", esc(x), fixed = TRUE)
  def_of <- function(i) {
    blank <- function(x) is.null(x) || is.na(x) || !nzchar(trimws(x))
    m <- cm[!is.na(cm$code_id) & cm$code_id == codes$id[i], , drop = FALSE]
    parts <- c(
      if (!blank(codes$description[i])) paste0(.t('<div class="gl"><span>Definition</span>'), nl2br(codes$description[i]), "</div>"),
      if (!blank(codes$anchor[i])) paste0(.t('<div class="gl"><span>Ankerbeispiel</span>'), nl2br(codes$anchor[i]), "</div>"),
      if (!blank(codes$coding_rule[i])) paste0(.t('<div class="gl"><span>Kodierregel</span>'), nl2br(codes$coding_rule[i]), "</div>"),
      if (nrow(m)) paste0('<div class="gl"><span>Memo</span>',
                          paste0(ifelse(nzchar(m$title), paste0("<b>", esc(m$title), ":</b> "), ""), nl2br(m$text_), collapse = "<br>"),
                          "</div>"))
    if (length(parts)) paste(parts, collapse = "") else "<span class=\"meta\">\u2013</span>"
  }
  cb_html <- if (nrow(codes) == 0) "" else paste0(
    .t('<table class="cb"><thead><tr><th>Code</th><th style="text-align:left">Kodierleitfaden</th><th>n</th></tr></thead><tbody>'),
    paste(vapply(seq_len(nrow(codes)), function(i) {
      sub <- codes$depth[i] > 1L
      sprintf('<tr style="--c:%s"><td style="width:28%%"><span class="rc" style="padding-left:%dpx"><span class="sw%s"></span>%s</span></td><td style="text-align:left">%s</td><td>%d</td></tr>',
              esc(codes$root_color[i]), (codes$depth[i] - 1L) * 14L, if (sub) " sub" else "",
              if (sub) esc(codes$label[i]) else paste0("<b>", esc(codes$label[i]), "</b>"),
              def_of(i), codes$n_codings[i])
    }, character(1)), collapse = ""), "</tbody></table>")

  # case comparison: codes x values of each document variable ---------------------
  vars <- sort(unique(unlist(lapply(srcs$id, function(i) names(qda_source_vars(i))))))
  case_html <- if (length(vars) == 0 || nrow(codes) == 0) "" else paste(vapply(vars, function(v) {
    cmx <- qda_case_matrix(v)
    groups <- setdiff(names(cmx), c("code", "path", "depth"))
    nd <- attr(cmx, "n_documents")
    rows <- vapply(seq_len(nrow(codes)), function(i) {
      sub <- codes$depth[i] > 1L
      sprintf('<tr class="%s" style="--c:%s"><td><span class="rc" style="padding-left:%dpx"><span class="sw%s"></span>%s</span></td>%s</tr>',
              if (sub) "" else "top", esc(codes$root_color[i]), (codes$depth[i] - 1L) * 14L, if (sub) " sub" else "",
              esc(codes$label[i]),
              paste0("<td>", vapply(groups, function(g) { n <- cmx[[g]][i]; if (n > 0) as.character(n) else "\u2013" }, character(1)),
                     "</td>", collapse = ""))
    }, character(1))
    paste0("<h3>", esc(v), "</h3><table><thead><tr><th>Code</th>",
           paste0("<th>", esc(groups), "<br>(", nd[groups], " Dok.)</th>", collapse = ""),
           "</tr></thead><tbody>", paste(rows, collapse = ""), "</tbody></table>")
  }, character(1)), collapse = "\n")

  # numbers of the codings per document (anchor in the text <-> margin column)
  cnum <- if (nrow(cods)) stats::ave(seq_len(nrow(cods)), cods$source_id, FUN = seq_along) else integer()
  names(cnum) <- cods$id
  doc_no <- stats::setNames(seq_len(n_src), srcs$id)
  doc_tag <- function(sid) if (short) sprintf("D%d", doc_no[[as.character(sid)]]) else srcs$name[srcs$id == sid]

  # summarising content analysis (Mayring): only when there are paraphrases ----
  may <- cods[nzchar(cods$paraphrase) | nzchar(cods$generalization), , drop = FALSE]
  mayring_html <- if (nrow(may) == 0) "" else {
    k <- match(may$code_id, codes$id)
    paste0(.t('<p class="meta">Paraphrase \u2192 Generalisierung \u2192 Reduktion (Code). Nr. = Anker im Dokument (Abschnitt Dokumente).</p>'),
           .t('<table class="may"><thead><tr><th>Fall \u00b7 Nr.</th><th style="text-align:left">Paraphrase</th>'),
           .t('<th style="text-align:left">Generalisierung</th><th style="text-align:left">Reduktion</th></tr></thead><tbody>'),
           paste(sprintf('<tr style="--c:%s"><td style="text-align:left">%s \u00b7 %d</td><td style="text-align:left">%s</td><td style="text-align:left">%s</td><td style="text-align:left"><span class="rc"><span class="sw%s"></span>%s</span></td></tr>',
                         esc(codes$root_color[k]), esc(vapply(may$source_id, doc_tag, character(1))), cnum[as.character(may$id)],
                         esc(may$paraphrase), esc(may$generalization), ifelse(codes$depth[k] > 1L, " sub", ""),
                         esc(path_lab(codes$path[k]))), collapse = ""),
           "</tbody></table>")
  }

  # 3 Memos (nach Art) --------------------------------------------------------
  memo_html <- if (nrow(memos) == 0) .t("<p class=\"meta\">Keine Memos.</p>") else {
    groups <- c(project = .t("Projekt-Memos"), document = .t("Dokument-Memos"),
                code = .t("Code-Memos"), passage = .t("Textstellen-Memos"))
    paste(vapply(names(groups), function(k) {
      mk <- memos[memos$kind == k, , drop = FALSE]
      if (nrow(mk) == 0) return("")
      items <- vapply(seq_len(nrow(mk)), function(i) {
        ref <- switch(k,
          document = esc(mk$source[i]),
          code = paste("Code:", esc(mk$code[i])),
          passage = sprintf(.t("%s, Zeichen %d\u2013%d: \u201e%s\u201c"), esc(mk$source[i]), mk$start[i], mk$end[i],
                            esc(mk$passage[i])),
          .t("Projekt"))
        sprintf('<div class="memo"><span class="ref">#%d \u00b7 %s \u00b7 %s</span>%s%s</div>',
                mk$id[i], esc(substr(mk$created_at[i], 1, 10)), ref,
                if (nzchar(mk$title[i])) paste0("<b>", esc(mk$title[i]), "</b><br>") else "",
                esc(mk$text_[i]))
      }, character(1))
      paste0("<h3>", groups[[k]], " (", nrow(mk), ")</h3>", paste(items, collapse = "\n"))
    }, character(1)), collapse = "\n")
  }

  # coded passages (in code-tree order) -------------------------------------------
  quote_html <- if (nrow(cods) == 0) .t("<p class=\"meta\">Noch keine Codings.</p>") else {
    paste(vapply(seq_len(nrow(codes)), function(i) {
      ck <- cods[cods$code_id == codes$id[i], , drop = FALSE]
      if (nrow(ck) == 0) return("")
      items <- vapply(seq_len(nrow(ck)), function(j) {
        sprintf(.t('<div class="quote" style="--c:%s"><span class="ref">%s \u00b7 Nr. %d \u00b7 Zeichen %d\u2013%d</span><q>%s</q>%s%s</div>'),
                esc(codes$root_color[i]), esc(ck$source[j]), cnum[as.character(ck$id[j])], ck$start[j], ck$end[j], esc(ck$text[j]),
                if (nzchar(ck$memo[j])) paste0(.t('<span class="cmt">Kommentar: '), esc(ck$memo[j]), "</span>") else "",
                if (nzchar(ck$paraphrase[j]) || nzchar(ck$generalization[j])) {
                  paste0('<span class="cmt">', if (nzchar(ck$paraphrase[j])) paste0(.t("Paraphrase: "), esc(ck$paraphrase[j])) else "",
                         if (nzchar(ck$paraphrase[j]) && nzchar(ck$generalization[j])) " \u00b7 " else "",
                         if (nzchar(ck$generalization[j])) paste0(.t("Generalisierung: "), esc(ck$generalization[j])) else "", "</span>")
                } else "")
      }, character(1))
      sprintf('<h3 style="--c:%s"><span class="rc"><span class="sw%s"></span>%s (%d)</span></h3>%s',
              esc(codes$root_color[i]), if (codes$depth[i] > 1L) " sub" else "",
              esc(path_lab(codes$path[i])), nrow(ck), paste(items, collapse = "\n"))
    }, character(1)), collapse = "\n")
  }

  # Documents with marks and margin column -----------------------------------
  # Per segment: the text on the left (codings underlined, a number at the
  # start of each coding), on the right the margin column with one card per
  # coding (code, comment, paraphrase) and passage memo, connected by a thread
  # in the colour of the code family. Cards are placed next to the segment in
  # which a coding starts -- so the reference stays clear across page breaks.
  step(0.12, .t("Grafiken und Intercoder"))
  # documents = FALSE ("overview"): the documents section is left out -- in
  # large projects it is by far the biggest and slowest part
  src_html <- if (!isTRUE(documents)) "" else if (n_src == 0) .t("<p class=\"meta\">Keine Dokumente.</p>") else paste(vapply(seq_len(n_src), function(i) {
    step(0.15 + 0.83 * (i - 1) / n_src, sprintf(.t("Dokument %d von %d: %s"), i, n_src, srcs$name[i]))
    m <- jsonlite::fromJSON(srcs$meta_json[i])
    vars_i <- if (!is.null(m$variables) && length(m$variables) > 0) {
      paste0('<div class="meta">', esc(paste(names(m$variables), unlist(m$variables), sep = " = ", collapse = " \u00b7 ")), "</div>")
    } else ""
    paste0('<section class="doc"><h2>', if (short) sprintf("D%d \u00b7 ", i) else "", esc(srcs$name[i]), "</h2>",
           '<div class="meta">', esc(srcs$format[i]), " \u00b7 ",
           nchar(.resolve_source(srcs$id[i])$frozen_text, type = "chars"), .t(" Zeichen</div>"),
           vars_i, .report_doc_html(srcs$id[i], codes, cods[cods$source_id == srcs$id[i], , drop = FALSE],
                                     cnum, memos), "</section>")
  }, character(1)), collapse = "\n")

  ic_html <- .ic_report_html(esc, path_lab)   # last intercoder check (R/report_intercoder.R)
  cooc_html <- .viz_report_cooc()             # graphics (R/report_visuals.R)
  portrait_html <- .viz_report_portraits()

  sec <- 0L
  h2 <- function(title, style = "") { sec <<- sec + 1L; sprintf('<h2%s>%d %s</h2>', style, sec, title) }
  paste0(
    "<!DOCTYPE html><html lang=\"", .lang(), "\"><head><meta charset=\"utf-8\">",
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
    if (nzchar(fav <- .jq_favicon_uri())) sprintf("<link rel=\"icon\" type=\"image/svg+xml\" href=\"%s\">", fav) else "",
    .t("<title>Bericht \u00b7 "), esc(proj), "</title><style>", css, "</style></head><body>\n",
    .t('<div class="bar"><span>A4-Druckansicht \u00b7 Strg+P druckt oder speichert als PDF (keine Hintergrundgrafiken n\u00f6tig)</span>'),
    .t('<button type="button" onclick="window.print()">Drucken / PDF</button></div>\n'),
    '<article class="sheet">\n',
    .t("<h1>Bericht: "), esc(proj), "</h1>\n",
    .t('<div class="meta">Qualitative Inhaltsanalyse \u00b7 erstellt am '), format(Sys.time(), if (.lang() == "de") "%d.%m.%Y, %H:%M" else "%Y-%m-%d, %H:%M"),
    .t(" mit jellyqda "), as.character(utils::packageVersion("jellyqda")), "</div>\n",
    '<div class="kpis"><span><b>', st$n_sources, .t("</b>Dokumente</span><span><b>"), st$n_codes,
    .t("</b>Codes</span><span><b>"), st$n_codings, .t("</b>Codings</span><span><b>"), st$n_memos,
    .t("</b>Memos</span><span><b>"), num(st$pct_coded), .t(" %</b>codiert</span></div>\n"),
    h2(.t("Codesystem und H\u00e4ufigkeiten")), freq_html, "\n",
    if (nzchar(case_html)) paste0(h2(.t("Fallvergleich")),
      .t('<p class="meta">Codings je Gruppe von Dokumenten (Dokument-Variablen); Codes z\u00e4hlen ihre Subcodes mit.</p>'), case_html, "\n"),
    h2(.t("Codebuch (Kodierleitfaden)")), cb_html, "\n",
    h2("Memos"), memo_html, "\n",
    h2(.t("Codierte Textstellen")), quote_html, "\n",
    if (nzchar(mayring_html)) paste0(h2(.t("Zusammenfassende Inhaltsanalyse (Mayring)")), mayring_html, "\n"),
    if (nzchar(cooc_html)) paste0(h2(.t("Code-\u00dcberschneidungen")), cooc_html, "\n"),
    if (nzchar(portrait_html)) paste0(h2(.t("Dokument-Portraits")), portrait_html, "\n"),
    if (nzchar(ic_html)) paste0(h2(.t("Intercoder-\u00dcbereinstimmung")), ic_html, "\n"),
    if (isTRUE(documents)) paste0(
      h2(.t("Dokumente mit Markierungen"), ' style="break-before:page"'),
      .t('<p class="meta">Im Text: Unterstreichung in der Farbe der Code-Familie (gestrichelt mit Etikett = Subcode, '),
      .t('gepunktet = mehrere Codings), davor die Nummer des Codings. Rechts am Rand: Code, Kommentar und Memos '),
      .t('zu den Codings, die in diesem Abschnitt beginnen.</p>'), src_html, "\n")
    else sprintf(.t('<p class="meta">\u00dcbersicht ohne die %d Dokumente mit Markierungen. Den vollst\u00e4ndigen Bericht erstellen Sie \u00fcber \u201eBericht\u201c \u2192 \u201eVollst\u00e4ndig\u201c oder qda_export(\"report\").</p>'), n_src),
    "</article></body></html>"
  )
}


# One document for the report: segments as rows with a margin column.
#' @noRd
.report_doc_html <- function(source_id, codes, cods_src, cnum, memos) {
  esc <- htmltools::htmlEscape
  src <- .resolve_source(source_id)
  text <- src$frozen_text
  lay <- .seg_layout(text, .segments_for(src))
  segs <- lay$segs
  rc <- .codings_of(src$id)
  pm <- .passage_memos_of(src$id)
  dup <- .dup_ids(rc)
  mm <- memos[memos$kind == "passage" & !is.na(memos$source_id) & memos$source_id == src$id, , drop = FALSE]
  mm <- mm[order(mm$start, mm$id), , drop = FALSE]
  mnum <- stats::setNames(seq_len(nrow(mm)), mm$id)
  anchors <- list(cod = cnum[as.character(rc$id)], memo = mnum)
  names(anchors$cod) <- rc$id
  seg_of <- function(pos) {
    k <- which(segs$start <= pos & segs$end >= pos)
    if (length(k)) return(k[1])
    k <- which(segs$start >= pos)                 # between two segments: the next one
    if (length(k)) k[1] else nrow(segs)
  }
  cseg <- if (nrow(cods_src)) vapply(cods_src$start, seg_of, integer(1)) else integer()
  mseg <- if (nrow(mm)) vapply(mm$start, seg_of, integer(1)) else integer()
  k_code <- match(cods_src$code_id, codes$id)
  card <- function(j) {
    k <- k_code[j]
    sprintf('<div class="card" style="--c:%s"><span class="anc" style="--c:%s">%d</span><span class="rc"><span class="sw%s"></span><b>%s</b></span>%s%s</div>',
            esc(codes$root_color[k]), esc(codes$root_color[k]), cnum[as.character(cods_src$id[j])],
            if (codes$depth[k] > 1L) " sub" else "", esc(gsub(" / ", " \u203a ", codes$path[k], fixed = TRUE)),
            if (nzchar(cods_src$memo[j])) paste0('<div class="cmt">', esc(cods_src$memo[j]), "</div>") else "",
            if (nzchar(cods_src$paraphrase[j])) paste0('<div class="cmt">P: ', esc(cods_src$paraphrase[j]), "</div>") else "")
  }
  mcard <- function(j) {
    sprintf(.t('<div class="card mcard"><span class="anc memo">M%d</span><b>Memo</b>%s<div class="cmt">%s</div></div>'),
            mnum[[as.character(mm$id[j])]], if (nzchar(mm$title[j])) paste0(": ", esc(mm$title[j])) else "",
            esc(mm$text_[j]))
  }
  rows <- vapply(seq_len(nrow(segs)), function(i) {
    cards <- c(vapply(which(cseg == i), card, character(1)), vapply(which(mseg == i), mcard, character(1)))
    sprintf('<div class="rseg"><div class="rtext"><div class="segtext" data-seg="%d">%s</div></div><aside class="rmargin">%s</aside></div>',
            i, .marked_html(text, segs$start[i], segs$end[i], rc, dup, NULL, pm, anchors = anchors),
            paste(cards, collapse = ""))
  }, character(1))
  pre <- if (nzchar(trimws(lay$prefix))) sprintf('<div class="rseg"><div class="rtext"><div class="segtext pre">%s</div></div><aside class="rmargin"></aside></div>', esc(lay$prefix)) else ""
  paste0('<div class="rdoc">', pre, paste(rows, collapse = ""), "</div>")
}
