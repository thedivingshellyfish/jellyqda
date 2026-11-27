# jellyqda :: report_intercoder.R -- section "Intercoder agreement" of the
# HTML report (.report_html() in R/export.R): the values of the last
# comparison recorded in the audit trail (.ic_last(), R/intercoder_data.R).

#' Report section for the last recorded intercoder comparison ("" if none).
#' @noRd
.ic_report_html <- function(esc, path_lab) {
  d <- tryCatch(.ic_last(), error = function(e) NULL)
  if (is.null(d) || is.null(d$overall)) return("")
  o <- d$overall
  v <- function(x) if (is.null(x) || length(x) == 0 || is.na(x)) NA_real_ else as.numeric(x)
  when <- tryCatch(format(as.POSIXct(d$created_at, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
                          if (.lang() == "de") "%d.%m.%Y" else "%Y-%m-%d"), error = function(e) "")
  unit_lab <- if (identical(d$unit, "document")) .t("Dokumente") else .t("Segmente")
  if (.lang() == "en") unit_lab <- tolower(unit_lab)
  lvl_lab <- if (identical(d$level, "top")) .t("Code-Familien (Code mit Subcodes)") else .t("jeder Code und Subcode")
  cd <- d$codes
  rows <- if (is.null(cd) || length(cd) == 0 || nrow(as.data.frame(cd)) == 0) "" else {
    cd <- as.data.frame(cd)
    paste(vapply(seq_len(nrow(cd)), function(i) sprintf(
      "<tr><td>%s</td><td>%d</td><td>%d</td><td>%d</td><td>%s %%</td><td><b>%s</b></td><td>%s</td></tr>",
      esc(path_lab(cd$code[i])), as.integer(cd$both[i]), as.integer(cd$only_a[i]), as.integer(cd$only_b[i]),
      .ic_num(100 * v(cd$agreement[i]), 1), .ic_num(v(cd$kappa[i])), .ic_num(v(cd$alpha[i]))), character(1)),
      collapse = "")
  }
  paste0(
    sprintf(.t('<p class="meta">Zwei Personen haben unabh\u00e4ngig kodiert: %s (A) und %s (B), %s. Analyseeinheit: %d %s; Kategorien: %s.</p>'),
            esc(d$coder_a %||% "A"), esc(d$coder_b %||% "B"), when, as.integer(v(o$units)), unit_lab, lvl_lab),
    sprintf(.t('<div class="kpis"><span><b>%s</b>Cohens Kappa (%s)</span><span><b>%s %%</b>\u00dcbereinstimmung</span><span><b>%s</b>Krippendorffs Alpha</span><span><b>%s</b>Brennan &amp; Prediger</span></div>'),
            .ic_num(v(o$kappa)), esc(.ic_na(.ic_rating(v(o$kappa)))), .ic_num(100 * v(o$agreement), 1),
            .ic_num(v(o$alpha)), .ic_num(v(o$kappa_bp))),
    if (nzchar(rows)) paste0(.t("<table><thead><tr><th>Code</th><th>beide</th><th>nur A</th><th>nur B</th><th>\u00dcbereinst.</th><th>Kappa</th><th>Alpha</th></tr></thead><tbody>"),
                             rows, "</tbody></table>") else "",
    .t('<p class="meta">Kappa nach Cohen (1960), Bewertung nach Landis &amp; Koch (1977); Alpha nach Krippendorff (2004), nominal. Werte vor einer Konsens-Kodierung.</p>'))
}
