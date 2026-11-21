# jellyqda :: stats.R -- qda_stats(): overall + per_source + per_code progress
# (coded chars use a union of intervals so overlaps count once).

# Statistics -----------------------------------------------------------------

#' Progress statistics of the active project
#'
#' @return A named list of tibbles:
#'   * `overall`: one row -- number of sources, codes, codings, memos, events,
#'     total characters, coded characters (union of coding intervals) and
#'     `pct_coded`
#'   * `per_code`: one row per code -- `n_codings`, coded `chars`
#'   * `per_source`: one row per source -- `chars`, `coded_chars`, `pct_coded`
#' @export
#' @examples
#' \dontrun{
#' qda_stats()
#' }
qda_stats <- function() {
  con <- qda_con()
  src <- DBI::dbGetQuery(con, "SELECT id, name, frozen_text FROM sources ORDER BY id")
  cod <- DBI::dbGetQuery(con, "SELECT source_id, code_id, start, end FROM codings")
  codes <- qda_codes()
  q <- function(sql) DBI::dbGetQuery(con, sql)[[1]]

  per_source <- tibble::tibble(
    id = src$id,
    name = src$name,
    chars = nchar(src$frozen_text, type = "chars"),
    coded_chars = vapply(src$id, function(i) {
      x <- cod[cod$source_id == i, , drop = FALSE]
      if (nrow(x) == 0) 0L else .union_len(x$start, x$end)
    }, integer(1))
  )
  per_source$pct_coded <- ifelse(per_source$chars > 0,
                                 round(100 * per_source$coded_chars / per_source$chars, 1), 0)

  per_code <- tibble::tibble(
    id = codes$id, label = codes$label, path = codes$path,
    n_codings = codes$n_codings,
    chars = vapply(codes$id, function(i) {
      x <- cod[cod$code_id == i, , drop = FALSE]
      if (nrow(x) == 0) 0L else sum(x$end - x$start + 1L)
    }, integer(1))
  )

  chars_total <- sum(per_source$chars)
  chars_coded <- sum(per_source$coded_chars)
  overall <- tibble::tibble(
    n_sources = q("SELECT COUNT(*) FROM sources"),
    n_codes = q("SELECT COUNT(*) FROM codes"),
    n_codings = q("SELECT COUNT(*) FROM codings"),
    n_memos = q("SELECT COUNT(*) FROM memos"),
    n_events = q("SELECT COUNT(*) FROM events"),
    chars_total = chars_total,
    chars_coded = chars_coded,
    pct_coded = if (chars_total > 0) round(100 * chars_coded / chars_total, 1) else 0
  )
  list(overall = overall, per_code = per_code, per_source = per_source)
}

#' Code x source matrix (V1.5)
#'
#' Counts of codings per code (rows) and source (columns), like the MAXQDA
#' Code Matrix Browser -- in R simply a crossing table.
#'
#' @return A tibble: `code` plus one column per source with the counts.
#' @export
qda_matrix <- function() {
  con <- qda_con()
  cod <- DBI::dbGetQuery(con, "
    SELECT k.label AS code, s.name AS source
    FROM codings c JOIN codes k ON k.id = c.code_id JOIN sources s ON s.id = c.source_id")
  codes <- qda_codes()
  sources <- qda_sources()
  if (nrow(cod) == 0) {
    out <- tibble::tibble(code = codes$label)
    for (nm in sources$name) out[[nm]] <- 0L
    return(out)
  }
  m <- stats::xtabs(~ factor(code, levels = codes$label) +
                      factor(source, levels = sources$name), data = cod)
  out <- tibble::as_tibble(as.data.frame.matrix(m), rownames = "code")
  out$code <- as.character(out$code)
  out
}
