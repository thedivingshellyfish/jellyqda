# jellyqda :: open.R -- project lifecycle: qda_open()/qda_close()/qda_project()
# One '.jellyqda' SQLite file per project; .jellyqda_env in utils.R holds
# the active connection; schema is created/migrated in schema.R.

# Open / close a project -----------------------------------------------------

#' Open (or create) a jellyqda project file
#'
#' Opens the SQLite project file at `path` (created together with its schema
#' if it does not exist yet) and makes it the active project for all other
#' `qda_*()` functions. The `.jellyqda` extension is appended if missing.
#'
#' @param path Path to the project file, e.g. `"meinarbeit.jellyqda"`.
#' @param auto_snapshot Integer. After this many logged actions an automatic
#'   backup snapshot is written (see [qda_backup()]). Set to `Inf` to disable.
#' @return Invisibly, a one-row tibble with project information
#'   (see [qda_project()]).
#' @export
#' @examples
#' \dontrun{
#' qda_open("meinarbeit.jellyqda")
#' qda_project()
#' }
qda_open <- function(path, auto_snapshot = 25) {
  if (missing(path)) {
    stop("qda_open(path): path to a .jellyqda project file is required.", call. = FALSE)
  }
  path <- normalizePath(as.character(path), mustWork = FALSE)
  if (!grepl("\\.jellyqda$", path, ignore.case = TRUE)) path <- paste0(path, ".jellyqda")
  path <- normalizePath(path, mustWork = FALSE)
  if (qda_is_open()) qda_close()
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  is_new <- !file.exists(path)
  con <- DBI::dbConnect(RSQLite::SQLite(), path)
  DBI::dbExecute(con, "PRAGMA busy_timeout = 5000")
  DBI::dbExecute(con, "PRAGMA foreign_keys = ON")
  create_schema(con)
  .jellyqda_env$con <- con
  .jellyqda_env$path <- path
  .jellyqda_env$auto_snapshot <- auto_snapshot
  .jellyqda_env$auto_busy <- FALSE
  log_event(if (is_new) "project_create" else "project_open",
            list(file = basename(path)))
  invisible(qda_project())
}

#' Close the active project
#'
#' Writes a final `project_close` event and disconnects from the SQLite file.
#'
#' @return Invisibly `NULL`.
#' @export
qda_close <- function() {
  if (!qda_is_open()) return(invisible(NULL))
  tryCatch(
    log_event("project_close", list(file = basename(.jellyqda_env$path))),
    error = function(e) NULL
  )
  DBI::dbDisconnect(.jellyqda_env$con)
  .jellyqda_env$con <- NULL
  .jellyqda_env$path <- NULL
  invisible(NULL)
}

#' Show information about the active project
#'
#' @return A one-row tibble: project file, size, row counts of all tables and
#'   the default backup directory.
#' @export
qda_project <- function() {
  if (!qda_is_open()) {
    stop("No jellyqda project is open. Call qda_open(path) first.", call. = FALSE)
  }
  con <- qda_con()
  p <- project_path()
  q <- function(sql) DBI::dbGetQuery(con, sql)[[1]]
  tibble::tibble(
    project = p,
    size_bytes = file.info(p)$size,
    sources = q("SELECT COUNT(*) FROM sources"),
    codes = q("SELECT COUNT(*) FROM codes"),
    codings = q("SELECT COUNT(*) FROM codings"),
    memos = q("SELECT COUNT(*) FROM memos"),
    events = q("SELECT COUNT(*) FROM events"),
    backup_dir = default_backup_dir()
  )
}
