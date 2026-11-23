# Contributing to jellyqda

Thanks for your interest! jellyqda is a small, offline-first QDA tool; keep
changes small, tested and dependency-light.

## How to work on it

```r
# clone, then in RStudio or a shell:
pkgload::load_all(".")            # dev load (no install needed)
testthat::test_local(".")         # full test suite
R CMD build . && R CMD check --as-cran jellyqda_*.tar.gz   # package check
```

- R code in `R/` must stay **ASCII-only** (use `\u00e4` etc. for umlauts) so
  the package builds everywhere; code comments are written in English.
- User-facing texts are written in German as `.t("...")` (R) or `jqT('...')`
  (JS) and translated in `R/i18n_catalog.R`. `tests/testthat/test-i18n.R`
  fails if a translation is missing or loses a placeholder.
- Every user-facing function needs roxygen docs + at least one test in
  `tests/testthat/`.
- Never commit project data (`*.jellyqda`, `originals/`, backups, exports) —
  `.gitignore` protects you, but double-check `git status` before pushing.
- The interactive app: UI and server in `R/app.R`, look in
  `inst/app/www/jellyqda.css`, browser logic in `inst/app/www/jellyqda.js` --
  see the README section "Customising the look and the texts".
- Examples must run in a temporary folder (`file.path(tempfile(), "x.jellyqda")`)
  so that `R CMD check --as-cran` stays clean.

## Reporting bugs / ideas

Open an issue on GitHub. Please include your R version (`R.version.string`),
the output of `qda_events()` if relevant, and whether the problem is in the
console API or the Shiny app.
