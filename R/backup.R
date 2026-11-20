# Backup ---------------------------------------------------------------------

#' Create a timestamped zip backup of the project
#'
#' Zips the `.jellyqda` project file (and the `originals/` directory, if
#' present) into a timestamped `.zip`. The default backup directory is
#' `jellyqda-backups/` **outside** the project folder, so a backup survives a
#' broken project directory. Old backups are rotated: only the newest `keep`
#' snapshots are kept.
#'
#' An automatic snapshot is also taken after every `auto_snapshot` logged
#' actions (see [qda_open()]).
#'
#' @param path Backup directory. Defaults to `jellyqda-backups/` next to the
#'   parent of the project folder.
#' @param keep How many snapshots to keep (rotation).
#' @param quiet Suppress the message.
#' @param auto Internal: called by the auto-snapshot mechanism.
#' @return Invisibly, the path of the written zip file.
#' @export
#' @examples
#' \dontrun{
#' qda_backup()
#' qda_backup(path = "D:/usb-stick/backups", keep = 20)
#' }
qda_backup <- function(path = NULL, keep = 10, quiet = FALSE, auto = FALSE) {
  qda_con()
  p <- project_path()
  dir <- path %||% default_backup_dir()
  if (!.writable_dir(dir)) {
    dir <- file.path(dirname(p), "jellyqda-backups")
    .writable_dir(dir)
    warning(sprintf("Backup-Pfad nicht beschreibbar - fallback: %s", dir), call. = FALSE)
  }
  ts <- format(Sys.time(), "%Y%m%d-%H%M%S", tz = "UTC")
  base <- tools::file_path_sans_ext(basename(p))
  z <- file.path(dir, paste0(base, "_", ts, ".zip"))
  files <- basename(p)
  odir <- file.path(dirname(p), "originals")
  if (dir.exists(odir)) {
    files <- c(files, file.path("originals", list.files(odir, recursive = TRUE, all.files = TRUE)))
  }
  zip::zip(z, files = files, root = dirname(p))
  pat <- paste0("^", gsub("([.|()\\^{}+$*?\\[\\]])", "\\\\\\1", base),
                "_[0-9]{8}-[0-9]{6}\\.zip$")
  all <- list.files(dir, pattern = pat, full.names = TRUE)
  if (length(all) > keep) {
    unlink(sort(all)[seq_len(length(all) - keep)])
  }
  log_event(if (isTRUE(auto)) "auto_snapshot" else "backup",
            list(file = z, keep = keep, n_files = length(files)))
  if (!quiet) message("jellyqda backup written: ", z)
  invisible(z)
}
