# jellyqda :: sources.R -- qda_sources() + case variables per source
# (qda_source_vars/set_var/del_var, stored in sources.meta_json$variables).

# Sources --------------------------------------------------------------------

#' List all imported sources
#'
#' @return A tibble with one row per source: `id`, `name`, `format`, `chars`,
#'   `segments` (numbered paragraphs, see [qda_view()]), `coded_chars` and
#'   `imported_at`.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_sources()
#' qda_close()
qda_sources <- function() {
  con <- qda_con()
  s <- DBI::dbGetQuery(con, "SELECT id, name, format, meta_json FROM sources ORDER BY id")
  s$frozen_text <- .texts(s$id)     # cached (utils.R)
  cod <- DBI::dbGetQuery(con, "SELECT source_id, start, end FROM codings")
  # segments: stored ones counted in SQL; documents without stored segments
  # use the automatic blank-line segments of their text (as .segments_for())
  stored <- DBI::dbGetQuery(con, "SELECT source_id, COUNT(*) AS n FROM segments GROUP BY source_id")
  n_seg <- stored$n[match(s$id, stored$source_id)]
  auto <- is.na(n_seg)
  n_seg[auto] <- vapply(s$frozen_text[auto], function(t) nrow(.segments_of(t)), integer(1), USE.NAMES = FALSE)
  tibble::tibble(
    id = s$id,
    name = s$name,
    format = s$format,
    chars = nchar(s$frozen_text, type = "chars"),
    segments = as.integer(n_seg),
    coded_chars = .coded_chars(s$id, cod),
    imported_at = vapply(s$meta_json, function(m) {
      v <- jsonlite::fromJSON(m)$imported_at
      if (is.null(v)) NA_character_ else v
    }, character(1))
  )
}

# --- variables (case attributes) per source ---------------------------------
# Stored inside sources.meta_json$variables as a named list: key = value.

#' id, name and meta_json of a source -- without the (possibly long) text.
#' @noRd
.source_meta <- function(x) {
  con <- qda_con()
  row <- if (is.numeric(x)) DBI::dbGetQuery(con, "SELECT id, name, meta_json FROM sources WHERE id = ?", params = list(as.integer(x)))
         else DBI::dbGetQuery(con, "SELECT id, name, meta_json FROM sources WHERE name = ?", params = list(as.character(x)))
  if (nrow(row) == 0) stop(sprintf("No source found for '%s'.", x), call. = FALSE)
  if (nrow(row) > 1) stop(sprintf("'%s' matches several sources; use the id.", x), call. = FALSE)
  row
}

#' Get the variables (case attributes) of a source
#'
#' @param source Source id or name.
#' @return Named character vector, e.g. `c(age = "32", gender = "f")`.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_source_set_var(1, "age", "34")
#' qda_source_vars(1)
#' qda_close()
qda_source_vars <- function(source) {
  m <- jsonlite::fromJSON(.source_meta(source)$meta_json)
  v <- m$variables
  if (is.null(v)) return(character())
  v <- unlist(v)
  stats::setNames(as.character(v), names(v))
}

#' Set a variable (case attribute) on a source
#'
#' @param source Source id or name.
#' @param key Variable name (e.g. `"age"`).
#' @param value Value (character).
#' @return Invisibly, the named character vector of all variables.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_source_set_var(1, "age", "34")
#' qda_source_set_var(1, "role", "project lead")
#' qda_source_vars(1)
#' qda_close()
qda_source_set_var <- function(source, key, value) {
  con <- qda_con()
  src <- .source_meta(source)   # no need for the text
  m <- jsonlite::fromJSON(src$meta_json)
  if (is.null(m$variables)) m$variables <- list()
  m$variables[[as.character(key)]] <- as.character(value)
  before <- .snap("sources", src$id)
  DBI::dbExecute(con, "UPDATE sources SET meta_json = ? WHERE id = ?",
                 params = list(.to_json(m), src$id))
  log_event("source_var_set", list(source_id = src$id, key = key, value = as.character(value)),
            changes = list(.chg("sources", before, .snap("sources", src$id))),
            desc = sprintf(.t("Variable gesetzt: %s = '%s' (%s)"), key, value, src$name))
  invisible(qda_source_vars(src$id))
}

#' Delete a variable from a source
#'
#' @param source Source id or name.
#' @param key Variable name to remove.
#' @return Invisibly, the remaining named character vector.
#' @export
#' @examples
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_source_set_var(1, "age", "34")
#' qda_source_del_var(1, "age")
#' qda_source_vars(1)
#' qda_close()
qda_source_del_var <- function(source, key) {
  con <- qda_con()
  src <- .source_meta(source)   # no need for the text
  m <- jsonlite::fromJSON(src$meta_json)
  if (!is.null(m$variables)) m$variables[[as.character(key)]] <- NULL
  before <- .snap("sources", src$id)
  DBI::dbExecute(con, "UPDATE sources SET meta_json = ? WHERE id = ?",
                 params = list(.to_json(m), src$id))
  log_event("source_var_del", list(source_id = src$id, key = key),
            changes = list(.chg("sources", before, .snap("sources", src$id))),
            desc = sprintf(.t("Variable gel\u00f6scht: %s (%s)"), key, src$name))
  invisible(qda_source_vars(src$id))
}
