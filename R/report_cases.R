# jellyqda :: report_cases.R -- section "Cases" of the HTML report
#
# Called from .report_html() (R/export.R) when the project has cases:
#   1. a table of the cases: name, what belongs to them, case variables
#   2. codes x cases (codings per case, codes count their subcodes) -- only
#      up to 12 cases, otherwise the table would not fit on A4
#   3. per case variable: codes x values (like the case comparison of
#      document variables)
# Uses the CSS of the report (tables, .rc/.sw colour marks).

#' @param codes code tree (.code_tree(), with root_color)
#' @param esc HTML escaping function
#' @return HTML string ("" if there are no cases)
#' @noRd
.report_cases_html <- function(codes, esc) {
  cs <- qda_cases()
  if (nrow(cs) == 0) return("")
  vars <- setdiff(names(cs), c("id", "name", "description", "documents", "passages", "sources"))
  what <- ifelse(cs$passages > 0,
                 sprintf(.t("%d Stelle(n) in %s"), cs$passages, esc(cs$sources)),
                 esc(cs$sources))
  head <- paste0("<th>", c(.t("Fall"), .t("Bestandteile"), esc(vars)), "</th>", collapse = "")
  body <- vapply(seq_len(nrow(cs)), function(i) {
    paste0("<tr><td><b>", esc(cs$name[i]), "</b>", if (nzchar(cs$description[i] %||% "")) paste0("<br><span class=\"meta\">", esc(cs$description[i]), "</span>") else "",
           '</td><td style="text-align:left">', what[i], "</td>",
           paste0("<td>", vapply(vars, function(v) esc(cs[[v]][i] %||% "") %||% "", character(1)), "</td>", collapse = ""), "</tr>")
  }, character(1))
  out <- paste0("<table><thead><tr>", head, "</tr></thead><tbody>", paste(body, collapse = ""), "</tbody></table>")
  if (nrow(codes) == 0) return(out)
  mx <- function(cm, label, counts = TRUE) {
    groups <- setdiff(names(cm), c("code", "path", "depth"))
    n <- if (counts) attr(cm, "n_units") else NULL
    rows <- vapply(seq_len(nrow(codes)), function(i) {
      sub <- codes$depth[i] > 1L
      sprintf('<tr class="%s" style="--c:%s"><td><span class="rc" style="padding-left:%dpx"><span class="sw%s"></span>%s</span></td>%s</tr>',
              if (sub) "" else "top", esc(codes$root_color[i]), (codes$depth[i] - 1L) * 14L, if (sub) " sub" else "",
              esc(codes$label[i]),
              paste0("<td>", vapply(groups, function(g) { k <- cm[[g]][i]; if (k > 0) as.character(k) else "\u2013" }, character(1)),
                     "</td>", collapse = ""))
    }, character(1))
    paste0(if (nzchar(label)) paste0("<h3>", esc(label), "</h3>") else "", "<table><thead><tr><th>Code</th>",
           paste0("<th>", esc(groups), if (!is.null(n)) paste0("<br>(", n[groups], .t(" F\u00e4lle)")) else "", "</th>", collapse = ""),
           "</tr></thead><tbody>", paste(rows, collapse = ""), "</tbody></table>")
  }
  if (nrow(cs) <= 12) out <- paste0(out, "<h3>", .t("Codes je Fall"), "</h3>", mx(qda_case_matrix(unit = "case"), "", counts = FALSE))
  for (v in vars) out <- paste0(out, mx(qda_case_matrix(v, unit = "case"), v))
  out
}
