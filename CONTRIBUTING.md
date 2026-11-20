# Contributing to jellyqda

Thanks for your interest! jellyqda is a small, offline-first QDA tool; keep
changes small, tested and dependency-light.

## How to work on it

```r
# clone, then in RStudio or a shell:
pkgload::load_all(".")            # dev load (no install needed)
testthat::test_local(".")         # full test suite
R CMD build . && R CMD check jellyqda_*.tar.gz --no-manual   # package check
```

- R code in `R/` must stay **ASCII-only** (umlauts -> ae/oe/ue/ss) so the
  package builds everywhere.
- Every user-facing function needs roxygen docs + at least one test in
  `tests/testthat/`.
- Never commit project data (`*.jellyqda`, `originals/`, backups, exports) —
  `.gitignore` protects you, but double-check `git status` before pushing.
- The interactive app lives entirely in `R/app.R` (UI / JS / server in one
  file on purpose); its look is customized via the CSS block there — see the
  README section "Customizing the look of `qda_app()`".

## Reporting bugs / ideas

Open an issue on GitHub. Please include your R version (`R.version.string`),
the output of `qda_events()` if relevant, and whether the problem is in the
console API or the Shiny app.
