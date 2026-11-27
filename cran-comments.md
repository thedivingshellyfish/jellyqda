## Submission

First submission of jellyqda to CRAN.

## Test environments

* local: Linux (Ubuntu), R 4.x -- `R CMD check --as-cran`
* win-builder: R-devel and R-release   <!-- fill in after devtools::check_win_devel() / check_win_release() -->
* R-hub v2 (GitHub Actions): linux, macos, macos-arm64, windows   <!-- fill in after rhub::rhub_check() -->

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.
* Possibly misspelled words in DESCRIPTION: names and technical terms
  (Mayring, Krippendorff, Prediger, QDA, REFI, intercoder, subcodes,
  scriptable, tibbles) -- all spelled correctly.

(Locally, "unable to verify current time" and "'qpdf' is needed" appear only
because the build machine is offline and has no qpdf.)

## Notes for the reviewers

* All examples run in a temporary folder (`file.path(tempfile(), ...)`);
  nothing is written to the user's home directory or the working directory.
  Backups of projects inside `tempdir()` stay inside that folder.
* `qda_app()` starts a local 'shiny' app; its example is wrapped in
  `if (interactive())`. 'shiny', 'bslib' and 'fontawesome' are suggested
  and checked with `requireNamespace()` before use; the same holds for
  'readxl', 'writexl', 'xml2' and 'rstudioapi'.
* The package never opens a network connection; the app binds to 127.0.0.1.
* Messages follow the user's language (English by default, German in a
  German locale).
