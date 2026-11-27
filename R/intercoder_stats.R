# jellyqda :: intercoder_stats.R -- agreement measures for two coders
#
# Pure functions, no database: the 2x2 table of one code (both / only A /
# only B / neither) -> percent agreement, Cohen's kappa, Brennan & Prediger's
# kappa, Krippendorff's alpha; the verbal rating after Landis & Koch; number
# formatting shared by the app (R/app_server_intercoder.R) and the report
# (R/report_intercoder.R).
#
# Overview of the intercoder files:
#   intercoder_stats.R    measures + rating + formatting (this file)
#   intercoder_data.R     reading both projects, matching documents/codes, units
#   intercoder_copy.R     qda_intercoder_copy()   blind copy for coder B
#   intercoder.R          qda_intercoder()        agreement per code + overall
#   intercoder_diff.R     qda_intercoder_diff()   disagreements
#   intercoder_adopt.R    qda_intercoder_adopt()  consensus: take over B's coding
#   app_server_intercoder.R / report_intercoder.R   app tab / report section

#' Agreement measures from a 2x2 table (two coders, code present/absent).
#' a = both coded, b = only A, c = only B, d = neither.
#' @noRd
.ic_stats <- function(a, b, c, d) {
  n <- a + b + c + d
  po <- ifelse(n > 0, (a + d) / n, NA_real_)
  pe <- ifelse(n > 0, ((a + b) * (a + c) + (c + d) * (b + d)) / n^2, NA_real_)
  # Cohen's kappa is undefined when chance agreement is 1 (a code that
  # nobody -- or everybody -- used): report NA instead of NaN / Inf
  kappa <- ifelse(!is.na(pe) & pe < 1, (po - pe) / (1 - pe), NA_real_)
  kappa_bp <- ifelse(n > 0, 2 * po - 1, NA_real_)   # Brennan & Prediger, 2 categories
  # Krippendorff's alpha, nominal, two coders, no missing values:
  # 2n pairable values; n1/n0 = how often "present"/"absent" was assigned
  m <- 2 * n; n1 <- 2 * a + b + c; n0 <- 2 * d + b + c
  # (undefined when only one value occurs at all, like Cohen's kappa)
  alpha <- ifelse(n > 0 & n1 > 0 & n0 > 0, 1 - (m - 1) * (b + c) / (n1 * n0), NA_real_)
  list(agreement = po, expected = pe, kappa = kappa, kappa_bp = kappa_bp, alpha = alpha)
}

#' Verbal rating of a kappa value after Landis & Koch (1977).
#' @noRd
.ic_rating <- function(k) {
  lab <- .t(c("schlecht", "etwas", "ausreichend", "mittelm\u00e4\u00dfig",
              "substanziell", "fast vollkommen"))
  out <- rep(NA_character_, length(k))
  ok <- !is.na(k)
  out[ok] <- lab[findInterval(k[ok], c(-Inf, 0, 0.205, 0.405, 0.605, 0.805), rightmost.closed = TRUE)]
  out
}

#' Number in the UI language (decimal comma in German).
#' @noRd
.ic_num <- function(x, d = 2) {
  out <- if (.lang() == "de") formatC(x, format = "f", digits = d, decimal.mark = ",")
         else formatC(x, format = "f", digits = d)
  ifelse(is.na(x), "\u2013", out)
}

#' NA -> dash (for texts such as the rating).
#' @noRd
.ic_na <- function(x) ifelse(is.na(x), "\u2013", x)

#' CSS class for a kappa / alpha value: high / medium / low.
#' @noRd
.ic_class <- function(k) {
  ifelse(is.na(k), "ic-na", ifelse(k >= 0.605, "ic-hi", ifelse(k >= 0.405, "ic-mid", "ic-lo")))
}
