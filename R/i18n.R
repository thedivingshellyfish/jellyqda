# jellyqda :: i18n.R -- user interface language (English / German)
#
# The UI texts are written in German in the code and wrapped in .t("...");
# R/i18n_catalog.R holds their English translations. .t() returns the text
# in the current language. The browser code (inst/app/www/js/) uses jqT('...')
# with the same catalogue, sent to the page by .jq_i18n_script().
#
# Current language, in this order:
#   1. set for the running app / qda_language("en")     (.jq_i18n$lang)
#   2. option jellyqda.lang                              ("en" or "de")
#   3. the system locale: German locale -> "de", otherwise "en"

.jq_i18n <- new.env(parent = emptyenv())

#' @noRd
.lang_default <- function() {
  loc <- c(Sys.getenv("LANGUAGE"), Sys.getenv("LC_ALL"), Sys.getenv("LC_MESSAGES"), Sys.getenv("LANG"),
           tryCatch(Sys.getlocale("LC_COLLATE"), error = function(e) ""))
  loc <- loc[nzchar(loc) & !loc %in% c("C", "POSIX", "C.UTF-8")]
  if (length(loc) && grepl("^(de|German)", loc[1], ignore.case = TRUE)) "de" else "en"
}

#' @noRd
.valid_lang <- function(x) {
  x <- tolower(as.character(x %||% ""))[1]
  if (!is.na(x) && x %in% c("en", "de")) x else NULL
}

#' Current UI language ("en" or "de").
#' @noRd
.lang <- function() {
  .valid_lang(.jq_i18n$lang) %||% .valid_lang(getOption("jellyqda.lang")) %||% .lang_default()
}

#' Translate German UI text(s) into the current language (vectorised).
#' Unknown texts are returned unchanged.
#' @noRd
.t <- function(x) {
  if (.lang() == "de" || length(x) == 0) return(x)
  i <- match(x, names(.I18N_EN))
  out <- ifelse(is.na(i), x, unname(.I18N_EN[i]))
  names(out) <- names(x)
  out
}

#' Get or set the language of the app and the report
#'
#' jellyqda's user interface and the HTML report are available in English and
#' German. By default the language follows the option `jellyqda.lang` or,
#' if unset, the system locale (German locale: German, otherwise English).
#' In the app the language can also be switched with the EN/DE button in the
#' toolbar.
#'
#' @param lang `"en"` or `"de"` to set the language for this R session;
#'   `NULL` (default) only returns the current language.
#' @return The current language code, invisibly when setting it.
#' @export
#' @examples
#' qda_language()          # current language
#' old <- qda_language("de")
#' qda_language("en")
qda_language <- function(lang = NULL) {
  if (is.null(lang)) return(.lang())
  l <- .valid_lang(lang)
  if (is.null(l)) stop("lang must be \"en\" or \"de\".", call. = FALSE)
  old <- .lang()
  .jq_i18n$lang <- l
  invisible(old)
}

#' Language from a URL query string such as "?lang=en" (or NULL).
#' @noRd
.lang_from_query <- function(q) {
  if (is.null(q) || !nzchar(q)) return(NULL)
  m <- regmatches(q, regexpr("(^|[?&])lang=([a-zA-Z]+)", q))
  if (length(m) == 0) return(NULL)
  .valid_lang(sub(".*lang=", "", m))
}

#' <script> that tells the browser code (inst/app/www/js/) the language and, for English, the
#' catalogue used by jqT().
#' @noRd
.jq_i18n_script <- function(lang = .lang()) {
  cat <- if (lang == "en") as.list(.I18N_EN) else list()
  json <- if (length(cat)) as.character(jsonlite::toJSON(cat, auto_unbox = TRUE)) else "{}"
  htmltools::tags$script(htmltools::HTML(sprintf(
    "window.jqLang = %s; window.jqI18n = %s;",
    jsonlite::toJSON(lang, auto_unbox = TRUE), gsub("</", "<\\/", json, fixed = TRUE))))
}
