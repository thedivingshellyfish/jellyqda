# jellyqda :: utils.R -- internal state & helpers shared by all files
# .jellyqda_env (active project), project_path()/project_dir(), qda_con(),
# .resolve_source/code/coding(), .to_json/fromJSON, .now(), esc helpers,
# .writable_dir(), .union_len(), log_event() (writes events + auto-snapshot).

# Internal state and helpers -------------------------------------------------

.jellyqda_env <- new.env(parent = emptyenv())

.PALETTE <- c("#E69F00", "#56B4E9", "#009E73", "#F0E442",
              "#0072B2", "#D55E00", "#CC79A7", "#999999")

`%||%` <- function(a, b) if (is.null(a)) b else a

.now <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

.to_json <- function(x) {
  if (length(x) == 0) return("{}")
  jsonlite::toJSON(x, auto_unbox = TRUE)
}

#' @noRd
qda_is_open <- function() {
  !is.null(.jellyqda_env$con) && DBI::dbIsValid(.jellyqda_env$con)
}

#' @noRd
qda_con <- function() {
  if (!qda_is_open()) {
    stop("No jellyqda project is open. Call qda_open(path) first.", call. = FALSE)
  }
  .jellyqda_env$con
}

#' @noRd
project_path <- function() .jellyqda_env$path

#' @noRd
project_dir <- function() dirname(.jellyqda_env$path)

#' @noRd
.writable_dir <- function(d) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(d)) return(FALSE)
  f <- tempfile("wtest", d)
  ok <- tryCatch({ writeLines("x", f); unlink(f); TRUE }, error = function(e) FALSE)
  ok
}

#' @noRd
default_backup_dir <- function() {
  # backups live OUTSIDE the project folder when possible (concept section 7);
  # if the parent is not writable (e.g. project directly in $HOME), fall back
  # to a backups folder next to the project file
  pdir <- dirname(project_path())
  outside <- normalizePath(file.path(pdir, "..", "jellyqda-backups"), mustWork = FALSE)
  if (.writable_dir(outside)) return(outside)
  file.path(pdir, "jellyqda-backups")
}

#' Write one row to the events audit trail; triggers auto-snapshot if due.
#' @noRd
log_event <- function(action, details = list(), changes = NULL, desc = NULL) {
  con <- qda_con()
  # undo/redo: optional before/after snapshot of the affected rows
  # (see history.R) and a German one-line description for the UI
  if (!is.null(desc)) details$desc <- desc
  if (!is.null(changes)) details$changes <- changes
  json <- if (is.null(changes)) .to_json(details) else
    jsonlite::toJSON(details, auto_unbox = TRUE, dataframe = "rows", na = "null")
  DBI::dbAppendTable(con, "events", data.frame(
    action = action,
    details = as.character(json),
    created_at = .now(),
    stringsAsFactors = FALSE
  ))
  n <- .jellyqda_env$auto_snapshot
  if (is.finite(n) && n > 0 && !isTRUE(.jellyqda_env$auto_busy)) {
    last <- DBI::dbGetQuery(
      con,
      "SELECT COALESCE(MAX(id), 0) AS id FROM events
       WHERE action IN ('backup', 'auto_snapshot')"
    )$id
    since <- DBI::dbGetQuery(
      con,
      sprintf("SELECT COUNT(*) AS n FROM events WHERE id > %d", as.integer(last))
    )$n
    if (since >= n) {
      .jellyqda_env$auto_busy <- TRUE
      on.exit(.jellyqda_env$auto_busy <- FALSE, add = TRUE)
      tryCatch(qda_backup(quiet = TRUE, auto = TRUE), error = function(e) NULL)
    }
  }
  invisible(NULL)
}

#' Mark character columns coming from SQLite as UTF-8 (SQLite stores UTF-8).
#' @noRd
.utf8 <- function(x) {
  if (is.character(x)) Encoding(x) <- "UTF-8"
  x
}

#' Resolve a source argument (id or unique name) to its row.
#' @noRd
.resolve_source <- function(x) {
  con <- qda_con()
  if (is.numeric(x)) {
    row <- DBI::dbGetQuery(con, "SELECT * FROM sources WHERE id = ?",
                          params = list(as.integer(x)))
  } else {
    row <- DBI::dbGetQuery(con, "SELECT * FROM sources WHERE name = ?",
                          params = list(as.character(x)))
  }
  if (nrow(row) == 0) stop(sprintf("No source found for '%s'.", x), call. = FALSE)
  if (nrow(row) > 1) stop(sprintf("'%s' matches several sources; use the id.", x), call. = FALSE)
  row$frozen_text <- .utf8(row$frozen_text)
  row
}

#' Resolve a code argument (id or unique label) to its row.
#' @noRd
.resolve_code <- function(x) {
  con <- qda_con()
  if (is.numeric(x)) {
    row <- DBI::dbGetQuery(con, "SELECT * FROM codes WHERE id = ?",
                          params = list(as.integer(x)))
  } else {
    row <- DBI::dbGetQuery(con, "SELECT * FROM codes WHERE label = ?",
                          params = list(as.character(x)))
  }
  if (nrow(row) == 0) stop(sprintf("No code found for '%s'.", x), call. = FALSE)
  if (nrow(row) > 1) stop(sprintf("'%s' matches several codes; use the id.", x), call. = FALSE)
  row
}

#' @noRd
.resolve_coding <- function(x) {
  con <- qda_con()
  if (is.numeric(x)) {
    row <- DBI::dbGetQuery(con, "SELECT * FROM codings WHERE id = ?",
                          params = list(as.integer(x)))
  } else {
    stop("coding must be given as its numeric id", call. = FALSE)
  }
  if (nrow(row) == 0) stop(sprintf("No coding found with id '%s'.", x), call. = FALSE)
  row
}

#' Split frozen text into numbered segments (paragraphs separated by blank
#' lines). Offsets are 1-based, inclusive character positions into `text`.
#' Deterministic: same frozen text always yields the same segments.
#' @noRd
.segments_of <- function(text) {
  n <- nchar(text, type = "chars")
  if (is.na(n) || n == 0) {
    return(tibble::tibble(segment = integer(), start = integer(), end = integer()))
  }
  m <- gregexpr("\n[ \t]*\n+", text, perl = TRUE)[[1]]
  if (m[1] == -1) {
    starts <- 1L; ends <- n
  } else {
    starts <- c(1L, as.integer(m + attr(m, "match.length")))
    ends <- c(as.integer(m - 1L), n)
    keep <- starts <= ends
    starts <- starts[keep]; ends <- ends[keep]
  }
  keep <- trimws(substring(text, starts, ends)) != ""
  starts <- starts[keep]; ends <- ends[keep]
  tibble::tibble(segment = seq_along(starts), start = starts, end = ends)
}

#' Length of the union of [start, end] intervals (chars covered by codings).
#' @noRd
.union_len <- function(starts, ends) {
  if (length(starts) == 0) return(0L)
  o <- order(starts)
  s <- starts[o]; e <- ends[o]
  tot <- 0L; cs <- s[1]; ce <- e[1]
  if (length(s) > 1) {
    for (i in 2:length(s)) {
      if (s[i] <= ce + 1) {
        ce <- max(ce, e[i])
      } else {
        tot <- tot + (ce - cs + 1L); cs <- s[i]; ce <- e[i]
      }
    }
  }
  tot + (ce - cs + 1L)
}

#' Hierarchical "parent / child" paths for a codes data frame.
#' @noRd
.code_paths <- function(df) {
  if (nrow(df) == 0) return(character())
  label_of <- stats::setNames(df$label, as.character(df$id))
  parent_of <- stats::setNames(df$parent_id, as.character(df$id))
  vapply(df$id, function(i) {
    parts <- character(); cur <- as.character(i); guard <- 0L
    while (!is.na(cur) && nzchar(cur) && guard < 1000L) {
      parts <- c(label_of[[cur]], parts)
      cur <- parent_of[[cur]]
      if (!is.na(cur)) cur <- as.character(cur)
      guard <- guard + 1L
    }
    paste(parts, collapse = " / ")
  }, character(1))
}
