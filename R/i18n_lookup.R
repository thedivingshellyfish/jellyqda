# jellyqda :: i18n_lookup.R -- the English translation table .I18N_EN
# The English translations of the German UI texts live in four files,
# R/i18n_catalog_{app,analysis,report,features,cases}.R; this file joins them.
# Keys are the German originals as used in .t("...") calls (R/*.R) and
# jqT('...') calls (inst/app/www/js/*.js). A test checks that every key used
# in the code has an entry (tests/testthat/test-i18n.R).
# R sources the files in alphabetical order, so i18n_catalog_*.R come
# before this file ("c" < "l").
#
# To add a text: write it in German in the code as .t("...") and add a pair
#   "<German text>", "<English text>",
# to the fitting i18n_catalog_*.R file. Keep placeholders (%s, %d, {0}, ...)
# in the same order.
# Pairs instead of c("<German>" = ...): names written in c() are converted to
# the native encoding when the package is installed, which breaks umlauts in
# non-UTF-8 locales; setNames() keeps them in UTF-8.
#
# Within the catalogue files the pairs are grouped by the file that uses the
# text (see the "# --- ..." headings there). The order does not matter for the
# lookup -- a new pair can go anywhere, but the group of its file keeps things
# findable.

.I18N_PAIRS <- c(.I18N_PAIRS_APP, .I18N_PAIRS_ANALYSIS, .I18N_PAIRS_REPORT, .I18N_PAIRS_FEATURES,
                 .I18N_PAIRS_CASES)

.I18N_EN <- stats::setNames(.I18N_PAIRS[c(FALSE, TRUE)], .I18N_PAIRS[c(TRUE, FALSE)])
