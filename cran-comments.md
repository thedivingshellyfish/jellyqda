## Submission

First submission of jellyqda to CRAN.

## R CMD check results

0 errors | 0 warnings | 1 note

* "checking for future file timestamps ... unable to verify current time"
  -- only in the offline build environment used for the check.

## Notes for the reviewers

* All examples run in a temporary folder (`file.path(tempfile(), ...)`);
  nothing is written to the user's home directory or the working directory.
* `qda_app()` starts a local 'shiny' app; its example is wrapped in
  `if (interactive())`.
* The package never opens a network connection; the app binds to 127.0.0.1.
