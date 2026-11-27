# jellyqda :: export_qdpx.R -- qda_export_qdpx(): the whole project as a
# REFI-QDA project file (.qdpx), the exchange format of MAXQDA, ATLAS.ti,
# NVivo, QualCoder, Quirkos, ... (QDA-XML project 1.0, 2019).
#
# A .qdpx file is a ZIP archive with
#   project.qde      XML: users, code book, variables, sources, notes
#   sources/<GUID>.txt   the frozen text of every document (UTF-8)
# Mapping jellyqda -> REFI-QDA:
#   codes (tree, colour)            -> CodeBook/Codes/Code (nested)
#   coding guideline                -> Code/Description (definition, anchor
#                                      examples, coding rule)
#   documents                       -> Sources/TextSource (plainTextPath)
#   codings (+ comment, Mayring)    -> PlainTextSelection + Coding;
#                                      comment/paraphrase -> Description
#   passage memos                   -> PlainTextSelection with Description
#                                      only (read as annotation by QualCoder)
#   document / code / project memos -> Notes/Note + NoteRef
#   document variables              -> Variables + VariableValue (text)
# Positions: REFI counts characters from 0, end exclusive; jellyqda from 1,
# end inclusive -> startPosition = start - 1, endPosition = end.
# Segments, summaries (summary grid) and the audit trail have no place in
# REFI-QDA and are not exported. GUIDs are derived from the project and the
# row ids, so exporting twice gives the same GUIDs.

#' Deterministic GUID (UUID version 4 layout) from a key.
#' @noRd
.qdpx_guid <- function(...) {
  h <- vapply(paste("jellyqda", ..., sep = "|"), digest::digest, character(1),
              algo = "md5", serialize = FALSE, USE.NAMES = FALSE)
  sprintf("%s-%s-4%s-%s%s-%s", substr(h, 1, 8), substr(h, 9, 12), substr(h, 14, 16),
          c("8", "9", "a", "b")[strtoi(substr(h, 17, 17), 16L) %% 4 + 1], substr(h, 18, 20),
          substr(h, 21, 32))
}

#' Escape text for XML (and drop characters XML 1.0 does not allow).
#' @noRd
.qdpx_esc <- function(x) {
  x <- gsub("[\x01-\x08\x0B\x0C\x0E-\x1F]", "", enc2utf8(as.character(x)), perl = TRUE)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub("\"", "&quot;", x, fixed = TRUE)
}

#' Time stamp in xsd:dateTime format.
#' @noRd
.qdpx_time <- function(x = NULL) {
  if (is.null(x) || is.na(x) || !nzchar(x)) return(.now())
  if (grepl("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", x)) x else .now()
}

#' Export the project as REFI-QDA project file (.qdpx)
#'
#' Writes the whole project -- documents, code system with colours and
#' coding guideline, codings with comments, memos and document variables --
#' into one `.qdpx` file in the REFI-QDA exchange format. MAXQDA, ATLAS.ti,
#' NVivo, QualCoder and other programs can import it, so a jellyqda project
#' can be continued elsewhere, shared with colleagues who use other software,
#' or archived in an open format.
#'
#' Not part of the format and therefore not exported: segments, the summary
#' grid and the audit trail. Mayring paraphrases and generalisations are
#' added to the comment of their coding. Positions follow the standard
#' (characters counted from 0, end exclusive).
#'
#' @param path File to write. Default: `exports/<project>_<time>.qdpx`
#'   next to the project file.
#' @param user Name of the user shown in the other program.
#' @return Invisibly, the path of the written file.
#' @references REFI-QDA Standard, project exchange (QDA-XML project 1.0,
#'   2019): <https://www.qdasoftware.org/>
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path")
#' qda_code(1, "Career path", segment = 3, memo = "first job")
#' f <- qda_export_qdpx(file.path(tempdir(), "example.qdpx"))
#' zip::zip_list(f)$filename
#' qda_close()
qda_export_qdpx <- function(path = NULL, user = NULL) {
  con <- qda_con()
  proj <- sub("\\.jellyqda$", "", basename(project_path()), ignore.case = TRUE)
  if (is.null(path)) {
    d <- file.path(project_dir(), "exports"); dir.create(d, showWarnings = FALSE, recursive = TRUE)
    path <- file.path(d, sprintf("%s_%s.qdpx", proj, format(Sys.time(), "%Y%m%d-%H%M%S")))
  }
  if (!grepl("\\.qdpx$", path, ignore.case = TRUE)) path <- paste0(path, ".qdpx")
  g <- function(...) .qdpx_guid(proj, ...)
  user <- if (is.null(user)) proj else as.character(user)
  ug <- g("user")
  now <- .now()
  e <- .qdpx_esc
  attr_user <- sprintf('creatingUser="%s"', ug)

  src <- DBI::dbGetQuery(con, "SELECT id, name, frozen_text, meta_json FROM sources ORDER BY id")
  src$frozen_text <- .utf8(src$frozen_text); src$name <- .utf8(src$name)
  codes <- DBI::dbGetQuery(con, "SELECT id, label, parent_id, color, description, anchor, coding_rule FROM codes ORDER BY id")
  for (k in c("label", "description", "anchor", "coding_rule")) codes[[k]] <- .utf8(codes[[k]])
  cods <- DBI::dbGetQuery(con, "SELECT id, source_id, code_id, start, end, memo, paraphrase, generalization FROM codings ORDER BY source_id, start, id")
  memos <- DBI::dbGetQuery(con, "SELECT id, kind, title, text_, source_id, code_id, start, end, created_at FROM memos ORDER BY id")
  for (k in c("memo", "paraphrase", "generalization")) cods[[k]] <- .utf8(ifelse(is.na(cods[[k]]), "", cods[[k]]))
  memos$text_ <- .utf8(memos$text_); memos$title <- .utf8(ifelse(is.na(memos$title), "", memos$title))
  nz <- function(x) !is.na(x) & nzchar(trimws(x))

  # --- code book (nested) -------------------------------------------------------
  memo_note <- function(m) g("memo", m)
  code_xml <- function(id, indent) {
    r <- codes[codes$id == id, ]
    desc <- c(if (nz(r$description)) r$description,
              if (nz(r$anchor)) paste0(.t("Ankerbeispiele: "), r$anchor),
              if (nz(r$coding_rule)) paste0(.t("Kodierregel: "), r$coding_rule))
    col <- if (grepl("^#[0-9A-Fa-f]{6}$", r$color %||% "")) sprintf(' color="%s"', toupper(r$color)) else ""
    kids <- codes$id[!is.na(codes$parent_id) & codes$parent_id == id]
    notes <- memos$id[memos$kind == "code" & !is.na(memos$code_id) & memos$code_id == id]
    pad <- strrep("  ", indent)
    paste0(pad, sprintf('<Code guid="%s" name="%s" isCodable="true"%s>', g("code", id), e(r$label), col),
           if (length(desc)) sprintf("<Description>%s</Description>", e(paste(desc, collapse = "\n\n"))) else "",
           paste(sprintf('<NoteRef targetGUID="%s"/>', vapply(notes, memo_note, character(1))), collapse = ""),
           if (length(kids)) paste0("\n", paste(vapply(kids, code_xml, character(1), indent = indent + 1), collapse = "\n"), "\n", pad) else "",
           "</Code>")
  }
  tops <- codes$id[is.na(codes$parent_id) | !codes$parent_id %in% codes$id]
  codebook <- if (length(tops)) paste0("<CodeBook><Codes>\n",
    paste(vapply(tops, code_xml, character(1), indent = 1), collapse = "\n"), "\n</Codes></CodeBook>\n") else ""

  # --- variables ------------------------------------------------------------------
  vars_of <- lapply(src$meta_json, function(j) {
    m <- tryCatch(jsonlite::fromJSON(j), error = function(err) list())
    v <- m$variables %||% list()
    if (length(v)) unlist(v) else character()
  })
  var_names <- sort(unique(unlist(lapply(vars_of, names))))
  variables <- if (length(var_names)) paste0("<Variables>\n", paste(sprintf(
    '  <Variable guid="%s" name="%s" typeOfVariable="Text"/>', g("var", var_names), e(var_names)), collapse = "\n"),
    "\n</Variables>\n") else ""

  # --- sources --------------------------------------------------------------------
  tmp <- tempfile("qdpx"); dir.create(file.path(tmp, "sources"), recursive = TRUE)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  src_xml <- vapply(seq_len(nrow(src)), function(i) {
    sid <- src$id[i]; sg <- g("source", sid)
    writeBin(charToRaw(enc2utf8(src$frozen_text[i])), file.path(tmp, "sources", paste0(sg, ".txt")))
    cd <- cods[cods$source_id == sid, , drop = FALSE]
    sel <- vapply(seq_len(nrow(cd)), function(j) {
      r <- cd[j, ]
      desc <- c(if (nz(r$memo)) r$memo,
                if (nz(r$paraphrase)) paste0(.t("Paraphrase: "), r$paraphrase),
                if (nz(r$generalization)) paste0(.t("Generalisierung: "), r$generalization))
      sprintf('  <PlainTextSelection guid="%s" startPosition="%d" endPosition="%d" %s creationDateTime="%s">%s<Coding guid="%s" %s creationDateTime="%s"><CodeRef targetGUID="%s"/></Coding></PlainTextSelection>',
              g("selection", r$id), r$start - 1L, r$end, attr_user, now,
              if (length(desc)) sprintf("<Description>%s</Description>", e(paste(desc, collapse = "\n"))) else "",
              g("coding", r$id), attr_user, now, g("code", r$code_id))
    }, character(1))
    pm <- memos[memos$kind == "passage" & !is.na(memos$source_id) & memos$source_id == sid &
                  !is.na(memos$start), , drop = FALSE]
    ann <- vapply(seq_len(nrow(pm)), function(j) {
      txt <- if (nz(pm$title[j])) paste0(pm$title[j], ": ", pm$text_[j]) else pm$text_[j]
      sprintf('  <PlainTextSelection guid="%s" startPosition="%d" endPosition="%d" %s creationDateTime="%s"><Description>%s</Description><NoteRef targetGUID="%s"/></PlainTextSelection>',
              g("passage", pm$id[j]), pm$start[j] - 1L, pm$end[j], attr_user, .qdpx_time(pm$created_at[j]),
              e(txt), memo_note(pm$id[j]))
    }, character(1))
    dm <- memos$id[memos$kind == "document" & !is.na(memos$source_id) & memos$source_id == sid]
    v <- vars_of[[i]]
    vv <- if (length(v)) paste(sprintf('  <VariableValue><VariableRef targetGUID="%s"/><TextValue>%s</TextValue></VariableValue>',
                                       g("var", names(v)), e(v)), collapse = "\n") else ""
    paste0(sprintf('<TextSource guid="%s" name="%s" plainTextPath="internal://%s.txt" %s creationDateTime="%s">\n',
                   sg, e(src$name[i]), sg, attr_user, now),
           paste(c(sel, ann), collapse = "\n"), if (length(c(sel, ann))) "\n" else "",
           paste(sprintf('  <NoteRef targetGUID="%s"/>\n', vapply(dm, memo_note, character(1))), collapse = ""),
           if (nzchar(vv)) paste0(vv, "\n") else "",
           "</TextSource>")
  }, character(1))
  sources <- if (nrow(src)) paste0("<Sources>\n", paste(src_xml, collapse = "\n"), "\n</Sources>\n") else ""

  # --- notes (all memos; passage memos are also annotations above) -----------------
  kind_lab <- c(passage = .t("Textstellen-Memo"), document = .t("Dokument-Memo"),
                code = .t("Code-Memo"), project = .t("Projekt-Memo"))
  notes <- if (nrow(memos)) paste0("<Notes>\n", paste(vapply(seq_len(nrow(memos)), function(j) {
    m <- memos[j, ]
    nm <- if (nz(m$title)) m$title else unname(kind_lab[m$kind] %||% "Memo")
    sprintf('  <Note guid="%s" name="%s" %s creationDateTime="%s"><PlainTextContent>%s</PlainTextContent></Note>',
            memo_note(m$id), e(nm), attr_user, .qdpx_time(m$created_at), e(m$text_))
  }, character(1)), collapse = "\n"), "\n</Notes>\n") else ""
  proj_notes <- memos$id[memos$kind == "project"]

  xml <- paste0(
    '<?xml version="1.0" encoding="utf-8"?>\n',
    sprintf('<Project xmlns="urn:QDA-XML:project:1.0" name="%s" origin="jellyqda %s" creatingUserGUID="%s" creationDateTime="%s">\n',
            e(proj), as.character(utils::packageVersion("jellyqda")), ug, now),
    sprintf('<Users><User guid="%s" name="%s"/></Users>\n', ug, e(user)),
    codebook, variables, sources, notes,
    sprintf("<Description>%s</Description>\n", e(sprintf(.t("Exportiert aus jellyqda (%s) am %s."), basename(project_path()), now))),
    paste(sprintf('<NoteRef targetGUID="%s"/>\n', vapply(proj_notes, memo_note, character(1))), collapse = ""),
    "</Project>\n")
  writeBin(charToRaw(enc2utf8(xml)), file.path(tmp, "project.qde"))
  path <- normalizePath(path, mustWork = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(path)) unlink(path)
  zip::zip(path, files = c("project.qde", "sources"), root = tmp, recurse = TRUE)
  log_event("export", list(what = "qdpx", files = basename(path), sources = nrow(src), codings = nrow(cods)))
  invisible(path)
}
