# jellyqda :: intercoder_data.R -- the data behind an intercoder comparison
#
# Reads the active project (coder A) and the other project file (coder B,
# opened READ-ONLY, never changed) and builds the comparison:
#   * documents are matched by their frozen text (identical text = same
#     document, names may differ),
#   * codes by their path ("Parent / Child"), or by the path of their
#     top-level code (level = "top", code families),
#   * units of analysis are the segments of the ACTIVE project (or whole
#     documents); a unit counts as coded with a code when a coding of that
#     code overlaps it by at least `min_overlap` characters (R/units.R).
# Result of .ic_build(): two logical matrices units x categories (MA, MB).
# Used by intercoder.R, intercoder_diff.R and intercoder_adopt.R.

#' Hash of a frozen text: identical text = identical document.
#' @noRd
.ic_hash <- function(x) {
  vapply(enc2utf8(.utf8(as.character(x))), digest::digest, character(1),
         algo = "md5", serialize = FALSE, USE.NAMES = FALSE)
}

#' Path of the other project file (with extension), checked.
#' @noRd
.ic_other_path <- function(other) {
  if (missing(other) || is.null(other) || !nzchar(as.character(other)[1])) {
    stop("`other`: path to the .jellyqda file of the second coder is required.", call. = FALSE)
  }
  p <- as.character(other)[1]
  if (!file.exists(p) && file.exists(paste0(p, ".jellyqda"))) p <- paste0(p, ".jellyqda")
  if (!file.exists(p)) stop(sprintf("Project file not found: %s", p), call. = FALSE)
  p <- normalizePath(p, mustWork = TRUE)
  if (identical(p, normalizePath(project_path(), mustWork = FALSE))) {
    stop("`other` is the active project itself; choose the file of the second coder.", call. = FALSE)
  }
  p
}

#' Sources, codes (with path and root) and codings of one project connection.
#' @noRd
.ic_read <- function(con) {
  tabs <- DBI::dbListTables(con)
  if (!all(c("sources", "codes", "codings") %in% tabs)) {
    stop("This file is not a jellyqda project (tables missing).", call. = FALSE)
  }
  src <- DBI::dbGetQuery(con, "SELECT id, name, frozen_text FROM sources ORDER BY id")
  src$frozen_text <- .utf8(src$frozen_text); src$name <- .utf8(src$name)
  src$hash <- if (nrow(src)) .ic_hash(src$frozen_text) else character()
  codes <- DBI::dbGetQuery(con, "SELECT id, label, parent_id, color FROM codes ORDER BY id")
  codes$label <- .utf8(codes$label)
  tr <- .code_tree(codes)
  tr$path <- .code_paths(tr)
  tr$root_path <- tr$path[match(tr$root_id, tr$id)]
  cods <- DBI::dbGetQuery(con, "SELECT id, source_id, code_id, start, end FROM codings ORDER BY id")
  list(sources = src, codes = tr, codings = cods)
}

#' Read the other project READ-ONLY.
#' @noRd
.ic_read_other <- function(path) {
  bad <- function(e) stop(sprintf("This file is not a jellyqda project: %s", basename(path)), call. = FALSE)
  con <- tryCatch(suppressWarnings(DBI::dbConnect(RSQLite::SQLite(), path, flags = RSQLite::SQLITE_RO,
                                                  synchronous = NULL)), error = bad)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  out <- tryCatch(.ic_read(con), error = function(e) {
    if (grepl("not a jellyqda", conditionMessage(e))) stop(e) else bad(e)
  })
  out$path <- path
  out
}

#' Default coder names: the file names without extension.
#' @noRd
.ic_coders <- function(coders, path_b) {
  nm <- function(p) sub("\\.jellyqda$", "", basename(p), ignore.case = TRUE)
  if (is.null(coders)) coders <- c(nm(project_path()), nm(path_b))
  coders <- as.character(coders)
  if (length(coders) != 2 || any(!nzchar(coders))) stop("`coders` needs two names.", call. = FALSE)
  if (coders[1] == coders[2]) coders <- paste(coders, c("(A)", "(B)"))
  coders
}

#' The comparison data: units, categories and the two logical matrices.
#' @noRd
.ic_build <- function(other, unit = "segment", level = "code", source = NULL,
                      min_overlap = 1L, coders = NULL) {
  qda_con()
  path_b <- .ic_other_path(other)
  A <- .ic_read(qda_con())
  B <- .ic_read_other(path_b)
  coders <- .ic_coders(coders, path_b)
  min_overlap <- max(1L, as.integer(min_overlap))

  # documents: matched by identical frozen text
  sa <- A$sources
  if (!is.null(source)) {
    ids <- vapply(source, function(s) .resolve_source(s)$id, numeric(1))
    sa <- sa[sa$id %in% ids, , drop = FALSE]
  }
  b_of <- B$sources$id[match(sa$hash, B$sources$hash)]
  matched <- sa[!is.na(b_of), , drop = FALSE]
  b_of <- b_of[!is.na(b_of)]
  missing_docs <- sa$name[!sa$hash %in% B$sources$hash]

  # units of analysis (R/units.R)
  units <- .units_for(matched, unit)

  # categories: code path, or the path of the top-level code (whole family)
  key_col <- if (level == "top") "root_path" else "path"
  cat_of <- function(P, code_ids) P$codes[[key_col]][match(code_ids, P$codes$id)]
  ca <- A$codings[A$codings$source_id %in% matched$id, , drop = FALSE]
  ca$sid <- ca$source_id
  ca$cat <- cat_of(A, ca$code_id)
  cb <- B$codings[B$codings$source_id %in% b_of, , drop = FALSE]
  cb$sid <- matched$id[match(cb$source_id, b_of)]   # B's documents -> A's ids
  cb$cat <- cat_of(B, cb$code_id)
  ca <- ca[!is.na(ca$cat), , drop = FALSE]; cb <- cb[!is.na(cb$cat), , drop = FALSE]

  # order: as in A's code tree, then codes only B has
  tree_keys <- unique(A$codes[[key_col]])
  used <- unique(c(ca$cat, cb$cat))
  cats <- c(tree_keys[tree_keys %in% used], sort(setdiff(used, tree_keys)))

  mark <- function(cd) .mark_units(units, cd, cats, min_overlap)   # R/units.R
  list(units = units, cats = cats, MA = mark(ca), MB = mark(cb),
       A = A, B = B, ca = ca, cb = cb, matched = matched, b_of = b_of,
       missing_docs = missing_docs, coders = coders, path_b = path_b,
       unit = unit, level = level, min_overlap = min_overlap,
       in_a = cats %in% A$codes[[key_col]], in_b = cats %in% B$codes[[key_col]])
}

#' The last intercoder comparison recorded in the audit trail (or NULL).
#' Used by the report.
#' @noRd
.ic_last <- function() {
  ev <- DBI::dbGetQuery(qda_con(),
    "SELECT details, created_at FROM events WHERE action = 'intercoder' ORDER BY id DESC LIMIT 1")
  if (nrow(ev) == 0) return(NULL)
  d <- tryCatch(jsonlite::fromJSON(.utf8(ev$details[1])), error = function(e) NULL)
  if (is.null(d)) return(NULL)
  d$created_at <- ev$created_at[1]
  d
}
