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
#' \dontrun{
#' qda_sources()
#' }
qda_sources <- function() {
  con <- qda_con()
  s <- DBI::dbGetQuery(con, "SELECT id, name, format, frozen_text, meta_json FROM sources ORDER BY id")
  s$frozen_text <- .utf8(s$frozen_text)
  cod <- DBI::dbGetQuery(con, "SELECT source_id, start, end FROM codings")
  tibble::tibble(
    id = s$id,
    name = s$name,
    format = s$format,
    chars = nchar(s$frozen_text, type = "chars"),
    segments = vapply(s$frozen_text, function(t) nrow(.segments_of(t)), integer(1)),
    coded_chars = vapply(s$id, function(i) {
      x <- cod[cod$source_id == i, , drop = FALSE]
      if (nrow(x) == 0) 0L else .union_len(x$start, x$end)
    }, integer(1)),
    imported_at = vapply(s$meta_json, function(m) {
      v <- jsonlite::fromJSON(m)$imported_at
      if (is.null(v)) NA_character_ else v
    }, character(1))
  )
}

# --- variables (case attributes) per source ---------------------------------
# Stored inside sources.meta_json$variables as a named list: key = value.

#' Get the variables (case attributes) of a source
#'
#' @param source Source id or name.
#' @return Named character vector, e.g. `c(age = "32", gender = "f")`.
#' @export
qda_source_vars <- function(source) {
  m <- jsonlite::fromJSON(.resolve_source(source)$meta_json)
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
qda_source_set_var <- function(source, key, value) {
  con <- qda_con()
  src <- .resolve_source(source)
  m <- jsonlite::fromJSON(src$meta_json)
  if (is.null(m$variables)) m$variables <- list()
  m$variables[[as.character(key)]] <- as.character(value)
  DBI::dbExecute(con, "UPDATE sources SET meta_json = ? WHERE id = ?",
                 params = list(.to_json(m), src$id))
  log_event("source_var_set", list(source_id = src$id, key = key, value = as.character(value)))
  invisible(qda_source_vars(src$id))
}

#' Delete a variable from a source
#'
#' @param source Source id or name.
#' @param key Variable name to remove.
#' @return Invisibly, the remaining named character vector.
#' @export
qda_source_del_var <- function(source, key) {
  con <- qda_con()
  src <- .resolve_source(source)
  m <- jsonlite::fromJSON(src$meta_json)
  if (!is.null(m$variables)) m$variables[[as.character(key)]] <- NULL
  DBI::dbExecute(con, "UPDATE sources SET meta_json = ? WHERE id = ?",
                 params = list(.to_json(m), src$id))
  log_event("source_var_del", list(source_id = src$id, key = key))
  invisible(qda_source_vars(src$id))
}
