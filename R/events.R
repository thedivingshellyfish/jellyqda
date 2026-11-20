# Audit trail ----------------------------------------------------------------

#' List the audit trail (events table)
#'
#' Every action in a jellyqda project (import, code_add, coding_add, export,
#' backup, ...) is logged here with a UTC timestamp -- the evidence for the
#' methods section. Export it as CSV with `qda_export("audit")`.
#'
#' @return A tibble: `id`, `action`, `details` (JSON), `created_at`.
#' @export
#' @examples
#' \dontrun{
#' qda_events()
#' }
qda_events <- function() {
  con <- qda_con()
  df <- DBI::dbGetQuery(con, "SELECT id, action, details, created_at FROM events ORDER BY id")
  tibble::tibble(id = df$id, action = df$action, details = df$details,
                 created_at = df$created_at)
}
