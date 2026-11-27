# jellyqda :: app_server_tables.R -- part of the Shiny server of qda_app()
#
# Server part tables: code matrix and summary grid.
#
# Every function here is called once per session from .jellyqda_server()
# (R/app_server.R) with the same arguments:
#   input, output, session -- as in any Shiny server
#   rv -- the reactive state of the session (see R/app_server.R)
#   shared -- helpers several parts use (bump(), esc(), notify_undo(), ...)

# code matrix
#' @noRd
.srv_code_matrix <- function(input, output, session, rv, shared) {
  bump <- shared$bump

  # code matrix (Code Matrix Browser) -------------------------------------------
  # Code matrix in code-tree order. Codes with subcodes show the sum incl.
  # subcodes (Sigma); the subcode rows collapse with the code tree
  # (data-anc = ancestors, js/15-code-tree.js).
  output$matrix_panel <- shiny::renderUI({
    rv$tick
    codes <- qda_codes()
    sources <- qda_sources()
    if (nrow(codes) == 0 || nrow(sources) == 0) {
      return(shiny::tags$div(class = "jq-hint", .t("Codes und Dokumente noetig.")))
    }
    tr <- .code_tree(codes)
    esc2 <- htmltools::htmlEscape
    anc_of <- function(id) {
      out <- integer(); p <- tr$parent_id[tr$id == id]
      while (length(p) && !is.na(p)) { out <- c(out, p); p <- tr$parent_id[tr$id == p] }
      out
    }
    # columns: documents or the values of a variable (case comparison)
    vars <- sort(unique(unlist(lapply(sources$id, function(i) names(qda_source_vars(i))))))
    by <- rv$mx_by %||% ""
    if (!by %in% vars) by <- ""
    sel <- sprintf(paste0(.t('<div class="mxby"><label for="mx_by">Spalten</label>'),
                          .t('<select id="mx_by" class="form-select form-select-sm"><option value="">Dokumente</option>%s</select>%s</div>')),
                   paste(sprintf(.t('<option value="%s"%s>Fallvergleich: %s</option>'), esc2(vars, attribute = TRUE),
                                 ifelse(vars == by, " selected", ""), esc2(vars)), collapse = ""),
                   if (length(vars) == 0) .t('<span class="jq-sub">Fallvergleich: erst Variablen an Dokumenten setzen</span>') else "")
    if (nzchar(by)) {
      cm <- qda_case_matrix(by)
      groups <- setdiff(names(cm), c("code", "path", "depth"))
      nd <- attr(cm, "n_documents")
      maxn <- max(1, as.matrix(cm[, groups, drop = FALSE]))
      head <- paste0('<tr><th>Code \\ ', esc2(by), '</th>',
                     paste0('<th>', esc2(groups), ' <span class="jq-sub">(', nd[groups], .t(' Dok.)</span></th>'), collapse = ""),
                     '</tr>')
      body <- vapply(seq_len(nrow(tr)), function(i) {
        cells <- vapply(groups, function(g) {
          n <- cm[[g]][i]
          bg <- if (n > 0) sprintf(' style="background:rgba(44,111,187,%s)"', round(0.12 + 0.55 * n / maxn, 2)) else ""
          sprintf('<td class="mxcell nolink"%s>%s</td>', bg, if (n > 0) n else "")
        }, character(1))
        sub <- tr$depth[i] > 1L
        sprintf('<tr data-mxrow="%d" data-anc="%s"%s><td class="rowlab" data-selcode="%d" style="padding-left:%.1frem"><span class="swatch%s" style="--c:%s"></span> %s%s</td>%s</tr>',
                tr$id[i], paste(anc_of(tr$id[i]), collapse = " "), if (sub) "" else ' class="mxtop"', tr$id[i],
                0.3 + 0.9 * (tr$depth[i] - 1L), if (sub) " sub" else "", esc2(tr$root_color[i]), esc2(tr$label[i]),
                if (tr$has_children[i]) ' <span class="jq-sub">\u03a3</span>' else "", paste0(cells, collapse = ""))
      }, character(1))
      return(shiny::HTML(paste0(sel, '<table class="mx">', head, paste0(body, collapse = ""), "</table>",
                                .t('<p class="jq-sub mxnote">Codings je Gruppe; Codes z\u00e4hlen ihre Subcodes mit.</p>'))))
    }
    cod <- DBI::dbGetQuery(qda_con(), "SELECT code_id, source_id, COUNT(*) AS n FROM codings GROUP BY code_id, source_id")
    own <- matrix(0L, nrow = nrow(tr), ncol = nrow(sources),
                  dimnames = list(as.character(tr$id), as.character(sources$id)))
    if (nrow(cod) > 0) {
      ok <- as.character(cod$code_id) %in% rownames(own) & as.character(cod$source_id) %in% colnames(own)
      own[cbind(as.character(cod$code_id[ok]), as.character(cod$source_id[ok]))] <- cod$n[ok]
    }
    cnt <- own
    for (i in seq_len(nrow(tr))) {
      if (tr$has_children[i]) {
        ids <- as.character(.code_descendants(tr, tr$id[i]))
        cnt[i, ] <- colSums(own[ids, , drop = FALSE])
      }
    }
    maxn <- max(cnt, 1L)
    head <- paste0(.t('<tr><th>Code \\ Dokument</th>'),
                   paste0('<th>', esc2(sources$name), '</th>', collapse = ""), "<th>SUM</th></tr>")
    body_rows <- vapply(seq_len(nrow(tr)), function(i) {
      cells <- vapply(seq_len(nrow(sources)), function(j) {
        n <- cnt[i, j]
        # Heatmap: opacity 0.12..0.67 -- stronger would push the number in the
        # cell (light and dark) below the WCAG contrast of 4.5:1
        bg <- if (n > 0) sprintf(' style="background:rgba(44,111,187,%s)"', round(0.12 + 0.55 * n / maxn, 2)) else ""
        sprintf('<td class="mxcell" data-mxcode="%d" data-mxsrc="%d"%s>%s</td>',
                tr$id[i], sources$id[j], bg, if (n > 0) n else "")
      }, character(1))
      sub <- tr$depth[i] > 1L
      sprintf('<tr data-mxrow="%d" data-anc="%s"%s><td class="rowlab" data-selcode="%d" style="padding-left:%.1frem"><span class="swatch%s" style="--c:%s"></span> %s%s</td>%s<td><b>%d</b></td></tr>',
              tr$id[i], paste(anc_of(tr$id[i]), collapse = " "), if (sub) "" else ' class="mxtop"',
              tr$id[i], 0.3 + 0.9 * (tr$depth[i] - 1L), if (sub) " sub" else "",
              esc2(tr$root_color[i]), esc2(tr$label[i]),
              if (tr$has_children[i]) ' <span class="jq-sub">\u03a3</span>' else "",
              paste0(cells, collapse = ""), as.integer(sum(cnt[i, ])))
    }, character(1))
    top <- tr$depth == 1L
    colsums <- vapply(seq_len(nrow(sources)), function(j) as.integer(sum(cnt[top, j])), integer(1))
    foot <- sprintf('<tr class="sumrow"><td>SUM</td>%s<td>%d</td></tr>',
                    paste0("<td>", colsums, "</td>", collapse = ""), as.integer(sum(cnt[top, ])))
    shiny::HTML(paste0(sel, '<table class="mx">', head, paste0(body_rows, collapse = ""), foot, "</table>"))
  })
  shiny::observeEvent(input$mx_by, { rv$mx_by <- input$mx_by %||% "" })
  shiny::observeEvent(input$mx_cell, {
    rv$sel_code <- input$mx_cell$code
    rv$src <- input$mx_cell$source
    rv$sel <- NULL
    bump()
    shiny::showNotification(.t("Zelle gewaehlt: Code im Browser geoeffnet."), type = "message")
  })
}

# summary grid
#' @noRd
.srv_summary_grid <- function(input, output, session, rv, shared) {
  bump <- shared$bump; esc <- shared$esc

  # summary grid -----------------------------------------------------------------
  output$sum_matrix <- shiny::renderUI({
    rv$tick
    codes <- qda_codes()
    sources <- qda_sources()
    if (nrow(codes) == 0 || nrow(sources) == 0) {
      return(shiny::tags$div(class = "jq-hint", .t("Codes und Dokumente noetig.")))
    }
    cod <- DBI::dbGetQuery(qda_con(), "SELECT code_id, source_id, COUNT(*) AS n FROM codings GROUP BY code_id, source_id")
    has_sum <- qda_summaries()
    has_keys <- if (nrow(has_sum)) paste(has_sum$code_id, has_sum$source_id, sep = "_") else character()
    esc2 <- htmltools::htmlEscape
    codes <- .code_tree(codes)
    head <- paste0(.t('<tr><th>Code \\ Dokument</th>'),
                   paste0("<th>", esc2(substr(sources$name, 1, 12)), "</th>", collapse = ""), "</tr>")
    body_rows <- vapply(seq_len(nrow(codes)), function(i) {
      cells <- vapply(seq_len(nrow(sources)), function(j) {
        n <- if (nrow(cod)) sum(cod$n[cod$code_id == codes$id[i] & cod$source_id == sources$id[j]]) else 0L
        cls <- if (paste(codes$id[i], sources$id[j], sep = "_") %in% has_keys) "sumcell has" else "sumcell"
        sprintf('<td class="%s" data-sumcode="%d" data-sumsrc="%d" title="%d Codings">%s</td>',
                cls, codes$id[i], sources$id[j], n, if (n > 0) n else "")
      }, character(1))
      sprintf('<tr><td class="rowlab" data-selcode="%d" style="padding-left:%.1frem"><span class="swatch%s" style="--c:%s"></span> %s</td>%s</tr>',
              codes$id[i], 0.3 + 0.9 * (codes$depth[i] - 1L), if (codes$depth[i] > 1L) " sub" else "",
              esc2(codes$root_color[i]), esc2(codes$label[i]), paste0(cells, collapse = ""))
    }, character(1))
    shiny::HTML(paste0('<table class="mx">', head, paste0(body_rows, collapse = ""), "</table>"))
  })
  shiny::observeEvent(input$sum_cell, {
    rv$sum_cell <- list(code = input$sum_cell$code, source = input$sum_cell$source)
    s <- qda_summaries()
    row <- s[s$code_id == rv$sum_cell$code & s$source_id == rv$sum_cell$source, , drop = FALSE]
    rv$sum_text_val <- if (nrow(row)) row$text_[1] else ""
  })
  output$sum_detail <- shiny::renderUI({
    rv$tick
    sc <- rv$sum_cell
    if (is.null(sc)) {
      return(shiny::tags$div(class = "jq-hint", .t("Zelle in der Summary-Grid anklicken ...")))
    }
    codes <- qda_codes(); sources <- qda_sources()
    clab <- codes$label[codes$id == sc$code]; slab <- sources$name[sources$id == sc$source]
    segs <- qda_codings()
    segs <- segs[segs$code_id == sc$code & segs$source_id == sc$source, , drop = FALSE]
    seg_rows <- if (nrow(segs) == 0) .t('<div class="jq-hint">keine Segmente</div>') else {
      paste(vapply(seq_len(nrow(segs)), function(i) {
        snippet <- if (nchar(segs$text[i]) > 70) paste0(substr(segs$text[i], 1, 70), "...") else segs$text[i]
        sprintf('<div class="segrow" data-goto="%d"><span class="snippet">#%d (%d-%d) %s</span></div>',
                segs$id[i], segs$id[i], segs$start[i], segs$end[i], esc(snippet))
      }, character(1)), collapse = "")
    }
    shiny::div(
      shiny::tags$b(sprintf(.t("Zelle: %s x %s (%d Segmente)"), clab, slab, nrow(segs))),
      shiny::div(class = "sumdetail-segs", shiny::HTML(seg_rows)),
      shiny::textAreaInput("sum_text", .t("Summary (wird gespeichert)"), rows = 3, value = rv$sum_text_val %||% ""),
      shiny::actionButton("sum_save_btn", .t("Summary speichern"), icon = .jq_ico("floppy-disk"), class = "btn-sm btn-primary")
    )
  })
  shiny::observeEvent(input$sum_save_btn, {
    shiny::req(rv$sum_cell)
    txt <- input$sum_text %||% ""
    qda_summary_set(rv$sum_cell$code, rv$sum_cell$source, txt)
    rv$sum_text_val <- txt
    bump()
    shiny::showNotification(.t("Summary gespeichert (Audit-Trail)."), type = "message")
  })
}
