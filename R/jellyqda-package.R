#' jellyqda: RStudio-native, fully offline coding of interview transcripts
#'
#' @description
#' jellyqda is a small QDA tool for coding interview transcripts (and other
#' texts such as field notes) directly in RStudio, completely offline.
#'
#' The core idea: all project data lives in **one SQLite file** per project
#' (e.g. `meinarbeit.jellyqda`). Imported text is **frozen** into the database
#' at import time and never re-extracted, so character offsets in codings stay
#' stable forever.
#'
#' Typical workflow:
#'
#' ```r
#' qda_open("meinarbeit.jellyqda")                 # open or create a project
#' qda_import(c("interview_01.txt", "feldnotizen.pdf"))
#' qda_code_add("Beruflicher Werdegang")           # deductive code from the guide
#' qda_view(1)                                     # transcript in the Viewer, with segment numbers
#' qda_code(source = 1, segment = 3, code = "Beruflicher Werdegang", memo = "5 Jahre KMU")
#' qda_segments("Beruflicher Werdegang")           # all segments coded with this code
#' qda_stats()                                     # progress: % of material coded
#' qda_export("all")                               # segments/codebook/audit as files
#' qda_backup()                                    # timestamped zip snapshot
#' ```
#'
#' Everything returns tibbles, nothing leaves the laptop, and every action is
#' written to the `events` audit trail. See `vignette("jellyqda")` for details.
#'
#' @name jellyqda
#' @keywords internal
"_PACKAGE"
