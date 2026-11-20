# RStudio addins -------------------------------------------------------------
# Thin no-argument wrappers so the Addins menu can trigger the daily workflow.

#' @noRd
qda_addin_backup <- function() {
  if (!qda_is_open()) {
    message("No jellyqda project open. Call qda_open(path) first.")
    return(invisible(NULL))
  }
  qda_backup()
}

#' @noRd
qda_addin_stats <- function() {
  if (!qda_is_open()) {
    message("No jellyqda project open. Call qda_open(path) first.")
    return(invisible(NULL))
  }
  print(qda_stats())
}
