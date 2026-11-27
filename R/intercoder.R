# jellyqda :: intercoder.R -- qda_intercoder(): intercoder agreement between
# the active project (coder A) and a second coder's project file (coder B).
# Workflow and the other intercoder files: see the overview in
# R/intercoder_stats.R. Every comparison is written to the audit trail
# (action "intercoder", not undoable); the report shows the last one.

#' Intercoder agreement between this project and a second coder's project
#'
#' Compares the codings of the **active project** (coder A) with those of
#' a second project file (coder B, usually made with
#' [qda_intercoder_copy()]) and computes, per code and overall:
#'
#' * **percent agreement** -- share of units both coders treated alike,
#' * **Cohen's kappa** -- agreement corrected for chance (Cohen 1960),
#'   with the verbal rating after Landis & Koch (1977),
#' * **Brennan & Prediger's kappa** -- chance agreement fixed at 1/2; stable
#'   for rare codes, where Cohen's kappa is low despite high agreement,
#' * **Krippendorff's alpha** (nominal) -- common in content analysis;
#'   values from .800 are usually considered reliable, .667 to .800 allow
#'   tentative conclusions (Krippendorff 2004).
#'
#' **Units of analysis** are the segments of the active project (e.g.
#' speaker turns) or whole documents. A unit counts as coded with a code when
#' a coding of that code overlaps it by at least `min_overlap` characters, so
#' the two coders do not have to mark exactly the same characters.
#' Documents are matched by their text (names may differ), codes by their
#' path. Codes nobody used in the compared documents are left out.
#'
#' The other file is only read, never changed. Each comparison is recorded
#' in the audit trail (for the methods section) and shown in the report.
#'
#' @param other Path to the second coder's `.jellyqda` file.
#' @param unit `"segment"` (default) or `"document"`.
#' @param level `"code"` (every code and subcode on its own) or `"top"`
#'   (a code together with all its subcodes, i.e. code families).
#' @param source Optional documents (ids or names of the active project) to
#'   compare; default all documents both projects contain.
#' @param min_overlap Minimum number of characters a coding must overlap a
#'   unit to count.
#' @param coders Two names for the coders; default the two file names.
#' @param log Logical; record the result in the audit trail.
#' @return A tibble with one row per code plus a first row `scope =
#'   "overall"` (all codes pooled): `scope`, `code` (path), `units`,
#'   `both`, `only_a`, `only_b`, `neither`, `agreement`, `kappa`,
#'   `kappa_bp`, `alpha`, `rating`, `in_a`, `in_b` (the code exists in the
#'   project of A / B). The overall row also has `mean_kappa` (mean over the
#'   codes). Attribute `"info"`: coders, files, compared and missing
#'   documents, unit and level.
#' @references
#' Cohen, J. (1960). A coefficient of agreement for nominal scales.
#' *Educational and Psychological Measurement*, 20(1), 37--46.
#'
#' Brennan, R. L., & Prediger, D. J. (1981). Coefficient kappa: Some uses,
#' misuses, and alternatives. *Educational and Psychological Measurement*,
#' 41(3), 687--699.
#'
#' Landis, J. R., & Koch, G. G. (1977). The measurement of observer agreement
#' for categorical data. *Biometrics*, 33(1), 159--174.
#'
#' Krippendorff, K. (2004). *Content Analysis: An Introduction to Its
#' Methodology* (2nd ed.). Sage.
#' @seealso [qda_intercoder_copy()], [qda_intercoder_diff()],
#'   [qda_intercoder_adopt()]
#' @export
#' @examples
#' dir <- tempfile()
#' qda_open(file.path(dir, "coder_a.jellyqda"))
#' qda_import(system.file("extdata", "interview_01.txt", package = "jellyqda"))
#' qda_code_add("Career path"); qda_code_add("Team")
#' b <- qda_intercoder_copy(file.path(dir, "coder_b.jellyqda"))
#' qda_code(1, "Career path", segment = 2); qda_code(1, "Team", segment = 3)
#' qda_close()
#' qda_open(b)                       # coder B codes independently
#' qda_code(1, "Career path", segment = 2); qda_code(1, "Team", segment = 4)
#' qda_close()
#' qda_open(file.path(dir, "coder_a.jellyqda"))
#' qda_intercoder(b)
#' qda_intercoder(b, level = "top", unit = "document")
#' qda_close()
qda_intercoder <- function(other, unit = c("segment", "document"), level = c("code", "top"),
                           source = NULL, min_overlap = 1L, coders = NULL, log = TRUE) {
  unit <- match.arg(unit); level <- match.arg(level)
  x <- .ic_build(other, unit, level, source, min_overlap, coders)
  MA <- x$MA; MB <- x$MB
  a <- colSums(MA & MB); b <- colSums(MA & !MB); c <- colSums(!MA & MB); d <- colSums(!MA & !MB)
  st <- .ic_stats(a, b, c, d)
  per <- tibble::tibble(scope = rep("code", length(x$cats)), code = x$cats,
                        units = as.integer(a + b + c + d), both = as.integer(a),
                        only_a = as.integer(b), only_b = as.integer(c), neither = as.integer(d),
                        agreement = st$agreement, kappa = st$kappa, kappa_bp = st$kappa_bp,
                        alpha = st$alpha, rating = .ic_rating(st$kappa),
                        in_a = x$in_a, in_b = x$in_b, mean_kappa = NA_real_)
  A <- sum(a); B <- sum(b); C <- sum(c); D <- sum(d)
  so <- .ic_stats(A, B, C, D)
  mk <- if (any(!is.na(st$kappa))) mean(st$kappa, na.rm = TRUE) else NA_real_
  overall <- tibble::tibble(scope = "overall", code = .t("(alle Codes)"), units = nrow(x$units),
                            both = as.integer(A), only_a = as.integer(B), only_b = as.integer(C),
                            neither = as.integer(D), agreement = so$agreement, kappa = so$kappa,
                            kappa_bp = so$kappa_bp, alpha = so$alpha, rating = .ic_rating(so$kappa),
                            in_a = NA, in_b = NA, mean_kappa = mk)
  res <- rbind(overall, per)
  info <- list(coder_a = x$coders[1], coder_b = x$coders[2],
               file_a = basename(project_path()), file_b = basename(x$path_b),
               documents = x$matched$name, missing_documents = x$missing_docs,
               unit = unit, level = level, min_overlap = x$min_overlap,
               created_at = .now())
  attr(res, "info") <- info
  if (isTRUE(log)) {
    r3 <- function(v) ifelse(is.na(v), NA, round(v, 3))
    log_event("intercoder", c(info, list(
      overall = list(units = nrow(x$units), agreement = r3(so$agreement), kappa = r3(so$kappa),
                     kappa_bp = r3(so$kappa_bp), alpha = r3(so$alpha), mean_kappa = r3(mk)),
      codes = data.frame(code = per$code, units = per$units, both = per$both,
                         only_a = per$only_a, only_b = per$only_b,
                         agreement = r3(per$agreement), kappa = r3(per$kappa),
                         alpha = r3(per$alpha), stringsAsFactors = FALSE),
      desc = sprintf(.t("Intercoder-\u00dcbereinstimmung mit %s: Kappa = %s, %s %% \u00fcbereinstimmend (%d Einheiten)"),
                     basename(x$path_b), if (is.na(so$kappa)) "-" else formatC(so$kappa, format = "f", digits = 2),
                     if (is.na(so$agreement)) "-" else formatC(100 * so$agreement, format = "f", digits = 1),
                     nrow(x$units)))))
  }
  res
}
