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
