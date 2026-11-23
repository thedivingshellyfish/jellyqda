# jellyqda :: events.R -- qda_events(): read the audit trail (events table)
# log_event() lives in utils.R; undo.R consumes this trail.

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
#' qda_open(file.path(tempfile(), "example.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path")
#' qda_code_add("SME", parent = "Career path")
#' qda_events()
#' qda_close()
qda_events <- function() {
  con <- qda_con()
  df <- DBI::dbGetQuery(con, "SELECT id, action, details, created_at FROM events ORDER BY id")
  tibble::tibble(id = df$id, action = df$action, details = df$details,
                 created_at = df$created_at)
}
