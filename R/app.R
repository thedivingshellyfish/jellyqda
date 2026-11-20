# qda_app: local Shiny UI (V2) -------------------------------------------------
# One command starts a local-only web UI (127.0.0.1, no internet) inside the
# RStudio Viewer pane -- the "V2 door" reserved in concept section 3.
#
# Layout follows the MAXQDA *workflow logic* (concept section 6), in jellyqda's
# own look (the concept explicitly forbids copying MAXQDA's colors/icons):
#   left column   : Documents tree (top) + Code System tree (bottom)
#   center        : Document Browser (top, select text -> code/memo buttons)
#                   + Retrieved Segments for the selected code (bottom)
#   right column  : Memos (memo of the clicked coding + free memos)
# All data flows through the same qda_*() API into the same .jellyqda file.

#' Start the jellyqda app (local Shiny UI) for the active project
#'
#' Launches a local Shiny app on `127.0.0.1` (loopback only -- fully offline)
#' and opens it in the RStudio Viewer pane when running inside RStudio.
#' The layout shows all panes at once: document tree, code system, document
#' browser (mark text with the mouse, then click a code button or the memo
#' button to store the coding at the exact character offsets), retrieved
#' segments per selected code, and the memo panel.
#'
#' The call blocks the console while the app runs (press Esc to stop), like
#' any Shiny app. Open the printed URL in additional browser windows/tabs for
#' a multi-window setup -- all windows share the same session and project.
#'
#' Requires the suggested packages `shiny`, `bslib`, `colourpicker` and
#' `fontawesome` (install once; runtime needs no internet).
#'
#' @param host Host to bind; loopback only, default `"127.0.0.1"`.
#' @param port Port; `NULL` picks a random free port.
#' @param open Logical; open the app at all.
#' @param new_window Logical; open the app in a **new browser window**
#'   (default, recommended -- the RStudio Viewer pane is small). With
#'   `new_window = FALSE` it opens inside the RStudio Viewer pane instead.
#' @return Invisibly `NULL` (after the app is stopped).
#' @export
#' @examples
#' \dontrun{
#' qda_open("meinarbeit.jellyqda")
#' qda_app()                    # new browser window; Esc stops the app
#' qda_app(new_window = FALSE)  # inside the RStudio Viewer pane
#' }
qda_app <- function(host = "127.0.0.1", port = NULL, open = TRUE, new_window = TRUE) {
  if (!qda_is_open()) {
    stop("No jellyqda project is open. Call qda_open(path) first.", call. = FALSE)
  }
  for (p in c("shiny", "bslib", "colourpicker", "fontawesome")) {
    if (!requireNamespace(p, quietly = TRUE)) {
      stop(sprintf("qda_app() needs the package '%s' (install once, runtime stays offline): install.packages('%s')", p, p), call. = FALSE)
    }
  }
  app <- shiny::shinyApp(ui = .jellyqda_ui(), server = .jellyqda_server)
  launcher <- function(url) {
    cat("jellyqda app (lokal, offline):", url, "\n")
    if (isTRUE(open)) {
      if (isTRUE(new_window)) {
        utils::browseURL(url)  # eigenes Browser-Fenster
      } else if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
        rstudioapi::viewer(url)  # RStudio Viewer-Pane
      } else {
        utils::browseURL(url)
      }
    }
  }
  shiny::runApp(app, host = host, port = port,
                launch.browser = if (isTRUE(open)) launcher else FALSE)
  invisible(NULL)
}

# --- segment splitting that preserves the exact separator text --------------
# Returns segments plus the raw separators between them, so that
# paste0(seg1, sep1, seg2, sep2, ...) == original text. This guarantees the
# browser-side offset mapping (textContent of #doc) matches frozen_text 1:1.
#' @noRd
.split_segments_full <- function(text) {
  n <- nchar(text, type = "chars")
  none <- list(segs = tibble::tibble(segment = integer(), start = integer(), end = integer()),
               seps = character())
  if (is.na(n) || n == 0) return(none)
  m <- gregexpr("\n[ \t]*\n+", text, perl = TRUE)[[1]]
  if (m[1] == -1L) {
    return(list(segs = tibble::tibble(segment = 1L, start = 1L, end = n), seps = character()))
  }
  ml <- attr(m, "match.length")
  starts <- c(1L, as.integer(m + ml))
  ends <- c(as.integer(m - 1L), n)
  k <- length(starts)
  seps <- substring(text, m, m + ml - 1L)
  keep <- starts <= ends & trimws(substring(text, starts, ends)) != ""
  out_start <- integer(); out_end <- integer(); out_sep <- character(); pending <- ""
  for (i in seq_len(k)) {
    raw <- if (starts[i] <= ends[i]) substring(text, starts[i], ends[i]) else ""
    if (keep[i]) {
      if (length(out_start) > 0) out_sep[length(out_start)] <- pending
      out_start <- c(out_start, starts[i]); out_end <- c(out_end, ends[i])
      pending <- ""
    } else {
      pending <- paste0(pending, raw)
    }
    if (i < k) pending <- paste0(pending, seps[i])
  }
  list(segs = tibble::tibble(segment = seq_along(out_start), start = out_start, end = out_end),
       seps = out_sep)
}

# --- document HTML for the browser ------------------------------------------
# #doc contains exactly the frozen text as DOM text nodes (segments as
# .segtext divs, separators as plain text between them, codings as <mark>).
# Segment badges are CSS ::before pseudo-elements (not DOM text), so they do
# not disturb offset mapping.
#' @noRd
.render_doc_html <- function(source_id, sel_cid = NULL) {
  con <- qda_con()
  src <- .resolve_source(source_id)
  text <- src$frozen_text
  parts <- .split_segments_full(text)
  segs <- parts$segs; seps <- parts$seps
  cods <- DBI::dbGetQuery(con, "
    SELECT c.id, c.start, c.end, k.label, k.color
    FROM codings c JOIN codes k ON k.id = c.code_id
    WHERE c.source_id = ? ORDER BY c.start", params = list(src$id))
  # double-coded passages (identical range coded more than once) get a dashed outline
  key <- paste(cods$start, cods$end)
  dup_ids <- if (nrow(cods) > 0) cods$id[duplicated(key) | duplicated(key, fromLast = TRUE)] else integer()
  esc <- htmltools::htmlEscape
  divs <- character()
  for (i in seq_len(nrow(segs))) {
    st <- segs$start[i]; en <- segs$end[i]
    seg_txt <- substring(text, st, en)
    ov <- cods[cods$start <= en & cods$end >= st, , drop = FALSE]
    inner <- character(); pos <- st
    if (nrow(ov) > 0) {
      for (j in seq_len(nrow(ov))) {
        cs <- max(ov$start[j], st); ce <- min(ov$end[j], en)
        if (cs > pos) inner <- c(inner, esc(substring(seg_txt, pos - st + 1, cs - st)))
        # reserved "Memo" code -> underline mark (no background), so memo
        # passages are visually distinct from real codings
        if (ov$label[j] == "Memo") {
          cls <- if (!is.null(sel_cid) && ov$id[j] == sel_cid) "memomark sel" else "memomark"
          if (ov$id[j] %in% dup_ids) cls <- paste(cls, "dup")
          inner <- c(inner, sprintf('<mark class="%s" data-cid="%d" title="Memo">%s</mark>',
                                    cls, ov$id[j], esc(substring(seg_txt, cs - st + 1, ce - st + 1))))
        } else {
          inner <- c(inner, sprintf('<mark class="%s" data-cid="%d" style="background-color:%s" title="%s">%s</mark>',
                                    if (ov$id[j] %in% dup_ids) "dup" else "", ov$id[j], esc(ov$color[j]), esc(ov$label[j]),
                                    esc(substring(seg_txt, cs - st + 1, ce - st + 1))))
        }
        pos <- ce + 1
      }
    }
    if (pos <= en) inner <- c(inner, esc(substring(seg_txt, pos - st + 1, en - st + 1)))
    divs[i] <- sprintf('<div class="segtext" data-seg="%d">%s</div>', i, paste(inner, collapse = ""))
  }
  sep_nodes <- vapply(c(seps, ""), esc, character(1))
  body <- paste0(divs, sep_nodes, collapse = "")
  paste0('<div id="doc">', body, '</div>')
}

# --- custom JS: selection -> character offsets, delegated button clicks ------
#' @noRd
.jellyqda_js <- function() {
  shiny::tags$script(shiny::HTML("
    // absolute 0-based char offset of (node, offset) within #doc
    function absOffset(doc, node, offset) {
      try {
        var r = document.createRange();
        r.selectNodeContents(doc);
        r.setEnd(node, offset);
        return r.toString().length;
      } catch (e) { return null; }
    }
    $(document).on('mouseup', function(e) {
      var doc = document.getElementById('doc');
      if (!doc || !doc.contains(e.target)) return;
      var sel = window.getSelection();
      if (!sel || sel.isCollapsed) { Shiny.setInputValue('selection', null); return; }
      var a = absOffset(doc, sel.anchorNode, sel.anchorOffset);
      var f = absOffset(doc, sel.focusNode, sel.focusOffset);
      if (a === null || f === null) return;
      var s0 = Math.min(a, f), e0 = Math.max(a, f);
      Shiny.setInputValue('selection',
        {start: s0 + 1, end: e0, text: sel.toString()}, {priority: 'event'});
    });
    $(document).on('click', '[data-src]', function() {
      Shiny.setInputValue('open_source', parseInt($(this).attr('data-src')), {priority: 'event'});
    });
    $(document).on('click', '[data-selcode]', function() {
      Shiny.setInputValue('sel_code', parseInt($(this).attr('data-selcode')), {priority: 'event'});
    });
    $(document).on('click', '.codebtn', function() {
      Shiny.setInputValue('assign_code', parseInt($(this).attr('data-codeid')), {priority: 'event'});
    });
    $(document).on('click', '#memo_only_btn', function() {
      Shiny.setInputValue('add_memo_only', Date.now(), {priority: 'event'});
    });
    $(document).on('click', '[data-delcode]', function(e) {
      e.stopPropagation();
      Shiny.setInputValue('del_code_id', parseInt($(this).attr('data-delcode')), {priority: 'event'});
    });
    $(document).on('click', '[data-delcoding]', function(e) {
      e.stopPropagation();
      Shiny.setInputValue('del_coding', parseInt($(this).attr('data-delcoding')), {priority: 'event'});
    });
    $(document).on('click', '[data-delmemo]', function(e) {
      e.stopPropagation();
      Shiny.setInputValue('del_memo', parseInt($(this).attr('data-delmemo')), {priority: 'event'});
    });
    $(document).on('click', '[data-goto]', function(e) {
      Shiny.setInputValue('goto_coding', parseInt($(this).attr('data-goto')), {priority: 'event'});
    });
    $(document).on('click', '#doc mark', function(e) {
      e.stopPropagation();
      Shiny.setInputValue('clicked_coding', parseInt($(this).attr('data-cid')), {priority: 'event'});
    });
    // server asks us to scroll to a coding inside the freshly rendered document
    Shiny.addCustomMessageHandler('jellyqdaScroll', function(msg) {
      setTimeout(function() {
        var doc = document.getElementById('doc');
        if (doc && msg.pos != null) { scrollToChar(doc, msg.pos); return; }
        var m = document.querySelector('#doc mark[data-cid=\"' + msg.cid + '\"]');
        if (m) {
          m.scrollIntoView({behavior: 'smooth', block: 'center'});
          m.style.outline = '3px solid #2c6fbb';
          setTimeout(function() { m.style.outline = ''; }, 2500);
        }
      }, 250);
    });
    $(document).on('click', '[data-editmemo]', function(e) {
      e.stopPropagation();
      Shiny.setInputValue('edit_memo_entry', $(this).attr('data-editmemo'), {priority: 'event'});
    });
    $(document).on('click', '[data-gotomemo]', function(e) {
      Shiny.setInputValue('goto_memo', parseInt($(this).attr('data-gotomemo')), {priority: 'event'});
    });
    $(document).on('click', '[data-savememo]', function(e) {
      e.stopPropagation();
      Shiny.setInputValue('save_memo_entry', $(this).attr('data-savememo'), {priority: 'event'});
    });
    $(document).on('click', '[data-canceledit]', function(e) {
      e.stopPropagation();
      Shiny.setInputValue('cancel_edit', Date.now(), {priority: 'event'});
    });
    $(document).on('click', '[data-cleardetail]', function(e) {
      e.stopPropagation();
      Shiny.setInputValue('clear_detail', Date.now(), {priority: 'event'});
    });
    $(document).on('click', '[data-delvar]', function(e) {
      e.stopPropagation();
      Shiny.setInputValue('del_var',
        $(this).attr('data-varsrc') + '|' + $(this).attr('data-varkey'), {priority: 'event'});
    });
    // keyboard shortcuts: Ctrl+1..9 = n-th code button of the action bar, Ctrl+M = memo save
    $(document).on('keydown', function(e) {
      if (!(e.ctrlKey || e.metaKey)) return;
      var t = ((e.target && e.target.tagName) || '').toLowerCase();
      if (t === 'input' || t === 'textarea' || t === 'select') return;
      if (e.key >= '1' && e.key <= '9') {
        var btns = document.querySelectorAll('.actionbar .codebtn');
        var i = parseInt(e.key, 10) - 1;
        if (btns[i]) { e.preventDefault(); btns[i].click(); }
      } else if (e.key === 'm' || e.key === 'M') {
        var b = document.getElementById('memo_only_btn');
        if (b) { e.preventDefault(); b.click(); }
      }
    });
    // click a segment badge -> select the whole segment
    $(document).on('click', '.segtext', function(e) {
      if (e.target.closest('mark')) return;
      Shiny.setInputValue('seg_click', parseInt($(this).attr('data-seg'), 10), {priority: 'event'});
    });
    // search result -> jump to that position in its document
    $(document).on('click', '[data-gotopos]', function(e) {
      Shiny.setInputValue('goto_pos', {
        src: parseInt($(this).attr('data-src'), 10),
        pos: parseInt($(this).attr('data-pos'), 10)
      }, {priority: 'event'});
    });
    // re-parent codes by drag & drop inside the code tree
    var dragCode = null;
    $(document).on('dragstart', '.coderow', function(e) {
      dragCode = parseInt($(this).attr('data-codeid'), 10);
    });
    $(document).on('dragover', '.coderow', function(e) {
      if (dragCode !== null) e.preventDefault();
    });
    $(document).on('drop', '.coderow', function(e) {
      if (dragCode === null) return;
      e.preventDefault();
      var target = parseInt($(this).attr('data-codeid'), 10);
      if (target && target !== dragCode) {
        Shiny.setInputValue('reparent_code', {code: dragCode, parent: target}, {priority: 'event'});
      }
      dragCode = null;
    });
    // drop files onto the documents panel -> forward to the file input
    (function() {
      var panel = document.getElementById('panel-docs');
      var inp = document.getElementById('import_files');
      if (!panel || !inp) return;
      panel.addEventListener('dragover', function(e) {
        var types = e.dataTransfer ? e.dataTransfer.types : [];
        if (types && Array.prototype.indexOf.call(types, 'Files') >= 0) {
          e.preventDefault(); panel.classList.add('dropfiles');
        }
      });
      panel.addEventListener('dragleave', function() { panel.classList.remove('dropfiles'); });
      panel.addEventListener('drop', function(e) {
        panel.classList.remove('dropfiles');
        if (!e.dataTransfer || !e.dataTransfer.files || e.dataTransfer.files.length === 0) return;
        e.preventDefault();
        var dt = new DataTransfer();
        for (var i = 0; i < e.dataTransfer.files.length; i++) dt.items.add(e.dataTransfer.files[i]);
        inp.files = dt.files;
        inp.dispatchEvent(new Event('change', {bubbles: true}));
      });
    })();
    // dark mode toggle (Bootstrap 5.3 color mode + our CSS overrides)
    $(document).on('click', '[data-dark]', function(e) {
      e.preventDefault();
      var dark = document.documentElement.getAttribute('data-bs-theme') === 'dark';
      document.documentElement.setAttribute('data-bs-theme', dark ? 'light' : 'dark');
      try { localStorage.setItem('jellyqda_dark', dark ? '0' : '1'); } catch (err) {}
    });
    $(document).on('click', '[data-help]', function(e) {
      e.preventDefault();
      Shiny.setInputValue('help_btn', Date.now(), {priority: 'event'});
    });
    // remember last open document (session resume on next start)
    $(document).on('click', '[data-src]', function() {
      try { localStorage.setItem('jellyqda_last_src', $(this).attr('data-src')); } catch (err) {}
    });
    // browser zoom (persisted, applied via CSS var so re-renders keep it)
    function applyZoom(z) {
      z = Math.min(1.6, Math.max(0.7, z));
      document.documentElement.style.setProperty('--jqzoom', z);
      try { localStorage.setItem('jellyqda_zoom', String(z)); } catch (err) {}
    }
    $(document).on('click', '[data-zoom]', function(e) {
      e.preventDefault();
      var cur = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--jqzoom')) || 1;
      applyZoom(cur + parseFloat($(this).attr('data-zoom')));
    });
    // scroll to a character position inside #doc
    function scrollToChar(doc, pos) {
      var walker = document.createTreeWalker(doc, NodeFilter.SHOW_TEXT, null);
      var n, acc = 0;
      while ((n = walker.nextNode())) {
        var len = n.nodeValue.length;
        if (acc + len >= pos) {
          var r = document.createRange();
          r.setStart(n, Math.max(0, pos - acc));
          r.collapse(true);
          r.scrollIntoView({behavior: 'smooth', block: 'center'});
          return true;
        }
        acc += len;
      }
      return false;
    }
    $(document).on('click', '[data-closeapp]', function(e) {
      if (confirm('jellyqda beenden? Arbeit wird gespeichert (Export + Backup).')) {
        Shiny.setInputValue('close_app', Date.now(), {priority: 'event'});
      }
    });
    $(document).on('click', '[data-toggle]', function(e) {
      e.stopPropagation();
      var p = document.getElementById($(this).attr('data-toggle'));
      if (p) p.classList.toggle('collapsed');
      if (window.jellyqdaSaveLayout) window.jellyqdaSaveLayout();
    });
    $(document).on('click', '[data-side]', function(e) {
      e.stopPropagation();
      var side = $(this).attr('data-side');
      var pane = document.querySelector('.pane[data-pane=\"' + side + '\"]');
      if (pane && window.jellyqdaSetSide) window.jellyqdaSetSide(side, pane.style.display !== 'none');
    });
    $(document).on('click', '.mxcell', function() {
      Shiny.setInputValue('mx_cell', {
        code: parseInt($(this).attr('data-mxcode')),
        source: parseInt($(this).attr('data-mxsrc'))
      }, {priority: 'event'});
    });
    $(document).on('click', '.sumcell', function() {
      Shiny.setInputValue('sum_cell', {
        code: parseInt($(this).attr('data-sumcode')),
        source: parseInt($(this).attr('data-sumsrc'))
      }, {priority: 'event'});
    });
    // ---- flexible layout: drag panels between panes, resize columns ---------
    $(function() {
      var grid = document.querySelector('.appgrid');
      function colTracks() {
        return (grid.style.gridTemplateColumns || getComputedStyle(grid).gridTemplateColumns).split(/\\s+/);
      }
      // collapse/expand a whole side pane (left or right) to free space for the browser
      function setSide(which, collapsed, skipSave) {
        var pane = document.querySelector('.pane[data-pane=\"' + which + '\"]');
        if (!pane) return;
        // safety: never hide a pane that contains the center panels
        if (collapsed && pane.querySelector('#panel-browser, #panel-segs')) return;
        var handle = which === 'left'
          ? document.querySelector('.colhandle[data-a=\"0\"]')
          : document.querySelector('.colhandle[data-b=\"4\"]');
        var cols = colTracks();
        if (collapsed) {
          if (which === 'left') { if (!pane.dataset.w) pane.dataset.w = cols[0]; cols[0] = '0px'; cols[1] = '0px'; }
          else { if (!pane.dataset.w) pane.dataset.w = cols[4]; cols[3] = '0px'; cols[4] = '0px'; }
          pane.style.display = 'none';
          if (handle) handle.style.display = 'none';
        } else {
          if (which === 'left') { cols[0] = pane.dataset.w || '300px'; cols[1] = '6px'; }
          else { cols[3] = '6px'; cols[4] = pane.dataset.w || '300px'; }
          pane.style.display = '';
          if (handle) handle.style.display = '';
          delete pane.dataset.w;
        }
        grid.style.gridTemplateColumns = cols.join(' ');
        var btn = document.querySelector('.symbtn[data-side=\"' + which + '\"]');
        if (btn) btn.classList.toggle('active', collapsed);
        if (!skipSave) saveLayout();
      }
      window.jellyqdaSetSide = setSide;
      window.jellyqdaSaveLayout = function() { saveLayout(); };
      function saveLayout() {
        try {
          var panes = {};
          document.querySelectorAll('.pane').forEach(function(p) {
            panes[p.dataset.pane] = Array.from(p.querySelectorAll('.panel')).map(function(el) { return el.id; });
          });
          var collapsed = Array.from(document.querySelectorAll('.panel.collapsed')).map(function(el) { return el.id; });
          var cols = colTracks();
          var paneL = document.querySelector('.pane[data-pane=\"left\"]');
          var paneR = document.querySelector('.pane[data-pane=\"right\"]');
          var sides = { left: !!(paneL && paneL.style.display === 'none'),
                        right: !!(paneR && paneR.style.display === 'none') };
          if (sides.left && paneL.dataset.w) { cols[0] = paneL.dataset.w; cols[1] = '6px'; }
          if (sides.right && paneR.dataset.w) { cols[3] = '6px'; cols[4] = paneR.dataset.w; }
          localStorage.setItem('jellyqda_layout', JSON.stringify({
            cols: cols.join(' '),
            panes: panes,
            collapsed: collapsed,
            sides: sides
          }));
        } catch (e) {}
      }
      function restoreLayout() {
        try {
          var L = JSON.parse(localStorage.getItem('jellyqda_layout') || 'null');
          if (!L) return;
          if (L.cols) grid.style.gridTemplateColumns = L.cols;
          ['left', 'center', 'right'].forEach(function(name) {
            var pane = document.querySelector('.pane[data-pane=\"' + name + '\"]');
            if (!pane) return;
            pane.style.display = '';
            (L.panes[name] || []).forEach(function(pid) {
              var el = document.getElementById(pid);
              if (el) pane.appendChild(el);
            });
          });
          (L.collapsed || []).forEach(function(pid) {
            var el = document.getElementById(pid);
            if (el) el.classList.add('collapsed');
          });
          setSide('left', !!(L.sides && L.sides.left), true);
          setSide('right', !!(L.sides && L.sides.right), true);
        } catch (e) {}
      }
      restoreLayout();
      // restore zoom, dark mode and the last open document (session resume)
      try {
        var z = parseFloat(localStorage.getItem('jellyqda_zoom'));
        if (z) document.documentElement.style.setProperty('--jqzoom', z);
        if (localStorage.getItem('jellyqda_dark') === '1') {
          document.documentElement.setAttribute('data-bs-theme', 'dark');
        }
        var last = parseInt(localStorage.getItem('jellyqda_last_src'), 10);
        if (last) Shiny.setInputValue('open_source', last);
      } catch (e2) {}
      // drag panels by their header into any pane (insert at mouse position)
      var dragEl = null;
      document.addEventListener('dragstart', function(e) {
        var h = e.target.closest('.panelhead');
        if (h) { dragEl = h.closest('.panel'); dragEl.classList.add('dragging'); }
      });
      document.addEventListener('dragend', function() {
        if (dragEl) dragEl.classList.remove('dragging');
        dragEl = null; saveLayout();
      });
      document.addEventListener('dragover', function(e) {
        var pane = e.target.closest('.pane');
        if (pane && dragEl) { e.preventDefault(); pane.classList.add('droptarget'); }
      });
      document.addEventListener('dragleave', function(e) {
        var pane = e.target.closest('.pane');
        if (pane && !pane.contains(e.relatedTarget)) pane.classList.remove('droptarget');
      });
      document.addEventListener('drop', function(e) {
        var pane = e.target.closest('.pane');
        if (!pane || !dragEl) return;
        // the document browser + segments always stay in the center column,
        // so the side collapse buttons can never hide them
        if ((dragEl.id === 'panel-browser' || dragEl.id === 'panel-segs') &&
            pane.dataset.pane !== 'center') return;
        e.preventDefault();
        var others = Array.from(pane.querySelectorAll('.panel:not(.dragging)'));
        var before = null;
        for (var i = 0; i < others.length; i++) {
          var r = others[i].getBoundingClientRect();
          if (e.clientY < r.top + r.height / 2) { before = others[i]; break; }
        }
        if (before) pane.insertBefore(dragEl, before); else pane.appendChild(dragEl);
        pane.classList.remove('droptarget');
        saveLayout();
      });
      // column resize handles between the panes
      document.querySelectorAll('.colhandle').forEach(function(h) {
        h.addEventListener('mousedown', function(e) {
          e.preventDefault();
          var cols = (grid.style.gridTemplateColumns || getComputedStyle(grid).gridTemplateColumns).split(' ');
          var a = parseInt(h.dataset.a, 10), b = parseInt(h.dataset.b, 10);
          var startX = e.clientX, startA = parseFloat(cols[a]), startB = parseFloat(cols[b]);
          var bPx = cols[b].indexOf('px') > -1;
          function move(ev) {
            var dx = ev.clientX - startX;
            cols[a] = Math.max(200, startA + dx) + 'px';
            if (bPx) cols[b] = Math.max(300, startB - dx) + 'px';
            else cols[b] = Math.max(0.5, startB - dx / 400) + 'fr';
            grid.style.gridTemplateColumns = cols.join(' ');
          }
          function up() {
            document.removeEventListener('mousemove', move);
            document.removeEventListener('mouseup', up);
            saveLayout();
          }
          document.addEventListener('mousemove', move);
          document.addEventListener('mouseup', up);
        });
      });
      Shiny.addCustomMessageHandler('jellyqdaReset', function() {
        try { localStorage.removeItem('jellyqda_layout'); } catch (e) {}
        location.reload();
      });
    });
  "))
}

# --- UI: four-pane layout (MAXQDA workflow logic, jellyqda look) -------------
#' @noRd
.jellyqda_ui <- function() {
  fa <- fontawesome::fa
  bslib::page_fluid(
    theme = bslib::bs_theme(version = 5, primary = "#2c6fbb", font_scale = 0.82),
    shiny::tags$head(
      .jellyqda_js(),
      shiny::div(style = "display:none", fa("folder-tree"), fa("tags"), fa("highlighter"),
                 fa("note-sticky"), fa("trash"), fa("floppy-disk"), fa("file-export"),
                 fa("plus"), fa("file-lines"), fa("table-columns"), fa("pen"), fa("chevron-down"),
                 fa("table-cells"), fa("table-list"), fa("xmark"), fa("check"),
                 fa("angles-left"), fa("angles-right"), fa("rotate-left"), fa("moon"),
                 fa("circle-question"), fa("magnifying-glass"), fa("trash")),
      shiny::tags$style(shiny::HTML("
        body { background:#f4f6f8; }
        .topbar { display:flex; gap:.6rem; align-items:center; background:#fff;
                  padding:.5rem .9rem; border-radius:.6rem; margin-bottom:.6rem;
                  box-shadow:0 1px 3px rgba(0,0,0,.08); flex-wrap:wrap; }
        .topbar .stats { font-weight:600; color:#2c6fbb; margin-right:auto; font-size:.82rem; }
        .btnsection { display:flex; gap:.4rem; align-items:center; }
        .actionbar #memo_field { width:12rem; margin-bottom:0; }
        .appgrid { display:grid; gap:0; height:calc(100vh - 118px);
                   grid-template-columns:300px 6px minmax(0,1fr) 6px 300px; }
        .colhandle { cursor:col-resize; background:#e2e7ec; border-radius:3px; }
        .colhandle:hover { background:#2c6fbb; }
        .pane { display:flex; flex-direction:column; min-height:0; min-width:0; gap:.6rem;
                padding:0 .3rem; overflow:hidden; }
        .pane.droptarget { outline:2px dashed #2c6fbb; outline-offset:-2px; border-radius:.6rem; }
        .panel { background:#fff; border-radius:.6rem; box-shadow:0 1px 3px rgba(0,0,0,.08);
                 display:flex; flex-direction:column; min-height:0; flex:1; }
        .panel.dragging { opacity:.45; }
        .panelhead { padding:.35rem .7rem; border-bottom:1px solid #e3e8ee; font-weight:700;
                     display:flex; gap:.45rem; align-items:center; color:#2c6fbb; flex:none;
                     cursor:grab; user-select:none; font-size:.82rem; }
        .panelhead:active { cursor:grabbing; }
        .panelbody { padding:.5rem .7rem; overflow:auto; flex:1; min-height:0; }
        .browser .panelbody { display:flex; flex-direction:column; overflow:hidden; }
        .docarea { overflow:auto; flex:1; min-height:0; padding:.4rem .2rem; }
        #doc { font-family:Georgia,'Times New Roman',serif; font-size:calc(.95rem * var(--jqzoom, 1)); line-height:1.6;
               white-space:pre-wrap; word-break:break-word; }
        .segtext { position:relative; padding-left:4.6em; margin-bottom:.15em; cursor:pointer; }
        .segtext::before { content:'Seg ' attr(data-seg); position:absolute; left:0; top:.2em;
                           font-family:monospace; font-size:.72rem; background:#eef1f4;
                           border:1px solid #d4dae0; border-radius:.35rem; padding:.1em .4em; color:#5a6672; }
        .segtext:hover::before { background:#2c6fbb; color:#fff; border-color:#2c6fbb; }
        #doc mark.dup, mark.dup { outline:2px dashed #d81b60; outline-offset:1px; }
        .pbar { display:block; height:4px; background:#e2e7ec; border-radius:2px; margin-top:.15rem; overflow:hidden; }
        .pbar > span { display:block; height:100%; background:#2c6fbb; }
        .docvars { font-size:.7rem; color:#6b7683; margin:.1rem 0 .3rem 0; }
        .docvars .chip { background:#eef1f4; border:1px solid #d4dae0; border-radius:.6rem;
                         padding:.05rem .45rem; margin-right:.25rem; white-space:nowrap; }
        .zoombtns { margin-left:auto; display:flex; gap:.2rem; }
        .zoombtns button { border:1px solid #d6dbe1; background:#fff; border-radius:.3rem;
                           font-size:.68rem; padding:0 .35rem; cursor:pointer; line-height:1.5; }
        .dropfiles { outline:2px dashed #2c6fbb; outline-offset:-3px; }
        #doc mark { padding:0 .12em; border-radius:.25em; cursor:pointer; }
        #doc mark.memomark { background:transparent !important; border-bottom:3px solid #b58900;
                             border-radius:0; }
        #doc mark.memomark.sel { border-bottom:5px solid #d81b60; background:rgba(216,27,96,.14) !important; }
        .actionbar { flex:none; display:flex; gap:.4rem; align-items:center; background:#fff8e1;
                     border:1px solid #e0c96a; padding:.45rem .7rem; border-radius:.5rem;
                     margin-bottom:.5rem; flex-wrap:wrap; }
        .actionbar .selinfo { font-family:monospace; font-size:.76rem; color:#7a6414; margin-right:.4rem; }
        .codebtn { border:none; color:#1a1a1a; border-radius:.4rem; padding:.25rem .55rem;
                   font-size:.76rem; font-weight:600; cursor:pointer; box-shadow:0 1px 2px rgba(0,0,0,.2); }
        .codebtn:hover { filter:brightness(1.12); }
        #memo_only_btn { border:1px solid #b58900; background:#fff; border-radius:.4rem;
                         padding:.25rem .55rem; font-size:.76rem; cursor:pointer; }
        .clickedbar { flex:none; display:flex; gap:.6rem; align-items:center; background:#eef4fb;
                      border:1px solid #b9d2ec; border-radius:.5rem; padding:.4rem .7rem; margin-bottom:.5rem; }
        .coderow, .docrow, .segrow, .memorow { display:flex; gap:.45rem; align-items:center;
          background:#fff; border:1px solid #e3e8ee; border-radius:.45rem; padding:.35rem .55rem; margin-bottom:.35rem; }
        .coderow, .docrow, .segrow { cursor:pointer; }
        .coderow:hover, .docrow:hover, .segrow:hover { background:#eef4fb; }
        .coderow.sel { border-color:#2c6fbb; background:#eef4fb; }
        .swatch { width:1rem; height:1rem; border-radius:.3rem; flex:none; border:1px solid rgba(0,0,0,.25); }
        .codelabel { font-weight:600; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
        .mini { margin-left:.25rem; border:1px solid #d6dbe1; background:#fff; border-radius:.35rem;
                font-size:.62rem; line-height:1.2; padding:.1rem .3rem; white-space:nowrap;
                cursor:pointer; color:#b03a2e; flex:none; }
        .docrow .fmt, .coderow .fmt { margin-left:auto; font-size:.68rem; color:#6b7683; flex:none; }
        .segrow .snippet, .memorow .snippet, .snippet { font-size:.76rem; color:#333; }
        .segrow .memo, .memorow .memo { display:block; font-size:.78rem; color:#7a6414; font-style:italic; }
        .memorow { display:block; white-space:pre-wrap; }
        .memogroup { font-size:.68rem; font-weight:700; color:#7a6414; margin:.4rem 0 .2rem 0;
                     text-transform:uppercase; letter-spacing:.04em; }
        .memorow.memomark-row { cursor:pointer; border-left:3px solid #b58900; }
        .memorow.memomark-row:hover { background:#fff8e1; }
        .memorow.editing { border-color:#2c6fbb; }
        .memorow.editing textarea { border:1px solid #b9d2ec; border-radius:.35rem; padding:.2rem .4rem;
                                    font-size:.78rem; margin-bottom:.2rem; }
        .mini.ok { color:#1e7e34; }
        .placeholder { color:#8a94a0; font-style:italic; padding:1rem; text-align:center; }
        .memodetail { background:#fff8e1; border:1px solid #e0c96a; border-radius:.5rem;
                     padding:.45rem .6rem; margin-bottom:.45rem; font-size:.8rem; white-space:pre-wrap; }
        .memodetail .who { font-size:.75rem; color:#7a6414; font-weight:700; display:block; margin-bottom:.2rem; }
        .panel.collapsed { flex:0 0 auto; }
        .panel.collapsed .panelbody { display:none; }
        .toggler { margin-left:auto; cursor:pointer; color:#8a94a0; }
        .panel.collapsed .toggler i { transform:rotate(-90deg); }
        .symbolbar { display:flex; gap:.3rem; align-items:center; padding-left:.4rem;
                     border-left:1px solid #e3e8ee; }
        .symbolbar .symgroup { display:flex; gap:.2rem; align-items:center; }
        .symbolbar .symsep { width:1px; height:1.1rem; background:#d6dbe1; }
        .symbolbar .symbtn { border:1px solid #d6dbe1; background:#fff; border-radius:.35rem;
                            padding:.1rem .35rem; cursor:pointer; color:#2c6fbb; font-size:.8rem; }
        .symbolbar .symbtn:hover { background:#eef4fb; }
        .symbolbar .symbtn.active { background:#2c6fbb; color:#fff; border-color:#2c6fbb; }
        .symbolbar .symbtn.off { color:#b6bec8; background:#f4f6f8; }
        .symbolbar .closeapp { color:#b03a2e; border-color:#e0b4ae; }
        table.mx { border-collapse:collapse; width:100%; font-size:.74rem; }
        table.mx th, table.mx td { border:1px solid #e3e8ee; padding:.18rem .35rem; text-align:center; }
        table.mx th { background:#f4f6f8; position:sticky; top:0; }
        table.mx td.rowlab { text-align:left; font-weight:600; cursor:pointer; white-space:nowrap; }
        table.mx td.rowlab:hover { background:#eef4fb; }
        td.mxcell { cursor:pointer; min-width:2.2rem; }
        td.mxcell:hover { outline:2px solid #2c6fbb; }
        td.sumcell { cursor:pointer; min-width:2.2rem; background:#fbfcfe; }
        td.sumcell:hover { outline:2px solid #b58900; }
        td.sumcell.has { background:#fff8e1; }
        tr.sumrow td { font-weight:700; background:#f4f6f8; }
        .sumdetail-segs { max-height:10rem; overflow:auto; margin-bottom:.4rem; }
        /* ---- dark mode (toggled via [data-bs-theme=dark] on <html>) ---- */
        [data-bs-theme=\"dark\"] body { background:#16191d; color:#dfe3e8; }
        [data-bs-theme=\"dark\"] .topbar { background:#1e2329; border-color:#343b44; }
        [data-bs-theme=\"dark\"] .topbar .stats { color:#7fb0e8; }
        [data-bs-theme=\"dark\"] .panel { background:#1e2329; border-color:#343b44; }
        [data-bs-theme=\"dark\"] .panelhead { background:#252b33; color:#dfe3e8; border-color:#343b44; }
        [data-bs-theme=\"dark\"] .panelbody { color:#dfe3e8; }
        [data-bs-theme=\"dark\"] .colhandle { background:#343b44; }
        [data-bs-theme=\"dark\"] .docarea { background:#16191d; }
        [data-bs-theme=\"dark\"] #doc { color:#e6e8eb; }
        [data-bs-theme=\"dark\"] .segtext::before { background:#252b33; border-color:#343b44; color:#9aa4b0; }
        [data-bs-theme=\"dark\"] .docrow:hover, [data-bs-theme=\"dark\"] .coderow:hover,
        [data-bs-theme=\"dark\"] .segrow:hover, [data-bs-theme=\"dark\"] .memorow.memomark-row:hover {
          background:#252b33; }
        [data-bs-theme=\"dark\"] .docrow.sel, [data-bs-theme=\"dark\"] .coderow.sel { background:#274060; }
        [data-bs-theme=\"dark\"] .docrow, [data-bs-theme=\"dark\"] .coderow, [data-bs-theme=\"dark\"] .segrow,
        [data-bs-theme=\"dark\"] .memorow { color:#dfe3e8; border-color:#343b44; }
        [data-bs-theme=\"dark\"] .symbolbar .symbtn, [data-bs-theme=\"dark\"] .zoombtns button,
        [data-bs-theme=\"dark\"] .mini { background:#252b33; border-color:#3a4250; color:#c8d2de; }
        [data-bs-theme=\"dark\"] .symbolbar .symbtn.active { background:#2c6fbb; color:#fff; }
        [data-bs-theme=\"dark\"] .symbolbar .symsep { background:#3a4250; }
        [data-bs-theme=\"dark\"] .actionbar { background:#2a2f1e; border-color:#4a4426; }
        [data-bs-theme=\"dark\"] .actionbar .selinfo { color:#d8c26a; }
        [data-bs-theme=\"dark\"] .clickedbar { background:#252b33; border-color:#343b44; color:#dfe3e8; }
        [data-bs-theme=\"dark\"] .memodetail { background:#2a2f1e; border-color:#4a4426; color:#e8e0c0; }
        [data-bs-theme=\"dark\"] .memodetail .who, [data-bs-theme=\"dark\"] .memogroup { color:#d8c26a; }
        [data-bs-theme=\"dark\"] .placeholder { color:#7c8794; }
        [data-bs-theme=\"dark\"] .memorow.memomark-row { border-left-color:#b58900; }
        [data-bs-theme=\"dark\"] .pbar { background:#343b44; }
        [data-bs-theme=\"dark\"] .docvars .chip { background:#252b33; border-color:#3a4250; color:#9aa4b0; }
        [data-bs-theme=\"dark\"] .form-control, [data-bs-theme=\"dark\"] .form-select,
        [data-bs-theme=\"dark\"] textarea { background-color:#252b33; color:#dfe3e8; border-color:#3a4250; }
        [data-bs-theme=\"dark\"] .btn-outline-secondary { color:#c8d2de; border-color:#3a4250; }
        [data-bs-theme=\"dark\"] hr { border-color:#343b44; }
        [data-bs-theme=\"dark\"] table.mx th, [data-bs-theme=\"dark\"] tr.sumrow td { background:#252b33; }
        [data-bs-theme=\"dark\"] table.mx th, [data-bs-theme=\"dark\"] table.mx td { border-color:#343b44; color:#dfe3e8; }
        [data-bs-theme=\"dark\"] td.sumcell { background:#1e2329; }
        [data-bs-theme=\"dark\"] td.sumcell.has { background:#2a2f1e; }
      "))
    ),
    shiny::div(class = "topbar",
      shiny::span(class = "stats", shiny::textOutput("stats_line", inline = TRUE)),
      shiny::span(class = "savedline", shiny::textOutput("saved_line", inline = TRUE)),
      shiny::div(class = "btnsection",
        shiny::actionButton("undo_btn", "Undo", icon = fa("rotate-left"), class = "btn-sm btn-outline-secondary"),
        shiny::actionButton("backup_btn", "Backup", icon = fa("floppy-disk"), class = "btn-sm btn-outline-secondary"),
        shiny::actionButton("export_btn", "Export", icon = fa("file-export"), class = "btn-sm btn-outline-secondary"),
        shiny::actionButton("layout_reset", "Layout reset", icon = fa("table-columns"),
                            class = "btn-sm btn-outline-secondary")
      ),
      shiny::div(class = "symbolbar", title = "Fenster ein-/ausklappen",
        shiny::span(class = "symgroup",
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-docs", title = "Dokumente", fa("folder-tree")),
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-codes", title = "Code System", fa("tags")),
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-matrix", title = "Code-Matrix", fa("table-cells"))),
        shiny::span(class = "symsep"),
        shiny::span(class = "symgroup",
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-browser", title = "Dokument-Browser", fa("file-lines")),
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-segs", title = "Retrieved Segments", fa("highlighter"))),
        shiny::span(class = "symsep"),
        shiny::span(class = "symgroup",
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-memos", title = "Memos", fa("note-sticky")),
          shiny::tags$button(class = "symbtn", `data-toggle` = "panel-summary", title = "Summary Grid", fa("table-list"))),
        shiny::span(class = "symsep"),
        shiny::tags$button(class = "symbtn", `data-side` = "left",
                           title = "Nur LINKE Spalte ein-/ausklappen (Dokument-Browser bleibt)",
                           fa("angles-left")),
        shiny::tags$button(class = "symbtn", `data-side` = "right",
                           title = "Nur RECHTE Spalte ein-/ausklappen (Dokument-Browser bleibt)",
                           fa("angles-right")),
        shiny::span(class = "symsep"),
        shiny::tags$button(class = "symbtn", `data-dark` = "1", title = "Dark Mode umschalten", fa("moon")),
        shiny::tags$button(class = "symbtn", `data-help` = "1", title = "Hilfe: Symbole, Tastenkuerzel", fa("circle-question")),
        shiny::span(class = "symsep"),
        shiny::tags$button(class = "symbtn closeapp", `data-closeapp` = "1", title = "App beenden (speichert + stoppt)", fa("xmark"))
      )
    ),
    shiny::div(class = "appgrid",
      # left column: document tree (top) + code system (bottom)
      shiny::div(class = "pane left", `data-pane` = "left",
        shiny::div(class = "panel docs", id = "panel-docs",
          shiny::div(class = "panelhead", draggable = "true", fa("folder-tree"), shiny::span("Dokumente"), shiny::span(class = "toggler", `data-toggle` = "panel-docs", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody",
            shiny::uiOutput("doc_tree"),
            shiny::hr(),
            shiny::fileInput("import_files", NULL, multiple = TRUE,
                             accept = c(".txt", ".md", ".docx", ".pdf"), buttonLabel = "Dateien..."),
            shiny::p(class = "placeholder", style = "padding:.2rem;margin:.2rem 0",
                     "oder Dateien hierher ziehen"),
            shiny::actionButton("import_btn", "Importieren", icon = fa("plus"), class = "btn-sm btn-primary"),
            shiny::hr(),
            shiny::selectInput("var_doc", "Variablen fuer Dokument", choices = character()),
            shiny::div(style = "display:flex; gap:.3rem;",
              shiny::textInput("var_key", NULL, placeholder = "Variable (z.B. Alter)"),
              shiny::textInput("var_val", NULL, placeholder = "Wert")),
            shiny::actionButton("var_add_btn", "Variable setzen", icon = fa("plus"), class = "btn-sm btn-secondary"),
            shiny::uiOutput("var_list")
          )
        ),
        shiny::div(class = "panel codes", id = "panel-codes",
          shiny::div(class = "panelhead", draggable = "true", fa("tags"), shiny::span("Code System"), shiny::span(class = "toggler", `data-toggle` = "panel-codes", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody",
            shiny::uiOutput("code_tree"),
            shiny::hr(),
            shiny::textInput("new_code_label", "Neuer Code", placeholder = "Label"),
            shiny::selectInput("new_code_parent", "Parent", choices = c("(kein Parent)" = "")),
            colourpicker::colourInput("new_code_color", "Farbe", value = "#E69F00"),
            shiny::textInput("new_code_desc", "Beschreibung", placeholder = "optional"),
            shiny::actionButton("add_code_btn", "Code anlegen", icon = fa("plus"), class = "btn-sm btn-primary"),
            shiny::hr(),
            shiny::selectInput("ren_code_select", "Code waehlen", choices = character()),
            shiny::textInput("ren_code_label", "Umbenennen in", placeholder = "neues Label"),
            shiny::actionButton("rename_code_btn", "Umbenennen", class = "btn-sm btn-secondary"),
            shiny::actionButton("delete_code_btn", "Loeschen", icon = fa("trash"), class = "btn-sm btn-outline-danger")
          )
        ),
        shiny::div(class = "panel matrix", id = "panel-matrix",
          shiny::div(class = "panelhead", draggable = "true", fa("table-cells"), shiny::span("Code-Matrix"),
                     shiny::span(class = "toggler", `data-toggle` = "panel-matrix", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody", shiny::uiOutput("matrix_panel"))
        )
      ),
      shiny::div(class = "colhandle", `data-a` = "0", `data-b` = "2"),
      # center: document browser (top) + retrieved segments (bottom)
      shiny::div(class = "pane center", `data-pane` = "center",
        shiny::div(class = "panel browser", id = "panel-browser",
          shiny::div(class = "panelhead", draggable = "true", fa("file-lines"), shiny::textOutput("doc_title", inline = TRUE),
                     shiny::span(class = "zoombtns",
                                 shiny::tags$button(`data-zoom` = "-0.1", title = "Schrift kleiner", "A-"),
                                 shiny::tags$button(`data-zoom` = "0.1", title = "Schrift groesser", "A+")),
                     shiny::span(class = "toggler", `data-toggle` = "panel-browser", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody",
            shiny::uiOutput("clicked_bar"),
            shiny::uiOutput("actionbar"),
            shiny::uiOutput("doc_vars"),
            shiny::div(class = "docarea", shiny::uiOutput("doc"))
          )
        ),
        shiny::div(class = "panel segs", id = "panel-segs",
          shiny::div(class = "panelhead", draggable = "true", fa("highlighter"), shiny::uiOutput("seg_head", inline = TRUE), shiny::span(class = "toggler", `data-toggle` = "panel-segs", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody",
            shiny::div(style = "display:flex; gap:.3rem; margin-bottom:.3rem;",
              shiny::textInput("search_q", NULL, placeholder = "Im ganzen Projekt suchen ..."),
              shiny::actionButton("search_btn", "Suchen", icon = fa("magnifying-glass"), class = "btn-sm btn-secondary")),
            shiny::selectInput("var_filter", "Nur Dokumente mit Variable", choices = c("(alle)" = "")),
            shiny::uiOutput("search_results"),
            shiny::uiOutput("seg_panel")
          )
        )
      ),
      shiny::div(class = "colhandle", `data-a` = "2", `data-b` = "4"),
      # right column: memos
      shiny::div(class = "pane right", `data-pane` = "right",
        shiny::div(class = "panel memos", id = "panel-memos",
          shiny::div(class = "panelhead", draggable = "true", fa("note-sticky"), shiny::span("Memos"), shiny::span(class = "toggler", `data-toggle` = "panel-memos", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody",
            shiny::uiOutput("memo_detail"),
            shiny::p(class = "placeholder",
                     "Memo anlegen (einheitlicher Weg): Text im Dokument-Browser markieren, Memo-Text in der Aktionsleiste eingeben, dann 'Memo speichern'."),
            shiny::hr(),
            shiny::uiOutput("memos_list")
          )
        ),
        shiny::div(class = "panel summary", id = "panel-summary",
          shiny::div(class = "panelhead", draggable = "true", fa("table-list"), shiny::span("Summary Grid"),
                     shiny::span(class = "toggler", `data-toggle` = "panel-summary", fontawesome::fa("chevron-down"))),
          shiny::div(class = "panelbody",
            shiny::p(style = "font-size:.78rem;color:#6b7683;margin:0 0 .4rem 0",
                     "Zelle anklicken = Segmente + Summary bearbeiten."),
            shiny::uiOutput("sum_matrix"),
            shiny::hr(),
            shiny::uiOutput("sum_detail")
          )
        )
      )
    )
  )
}

# --- server -------------------------------------------------------------------
#' @noRd
.jellyqda_server <- function(input, output, session) {
  rv <- shiny::reactiveValues(src = NULL, sel = NULL, clicked = NULL, sel_code = NULL,
                              edit_entry = NULL, sum_cell = NULL, sel_memo = NULL, tick = 0,
                              search = NULL, var_filter = "")
  bump <- function() {
    rv$tick <- shiny::isolate(rv$tick) + 1
    rv$last_saved <- format(Sys.time(), "%H:%M:%S")
  }
  rv$last_saved <- format(Sys.time(), "%H:%M:%S")
  esc <- htmltools::htmlEscape

  code_choices <- function() {
    c <- qda_codes()
    if (nrow(c) == 0) return(c("(kein Parent)" = ""))
    out <- stats::setNames(as.character(c$id), c$label)
    c("(kein Parent)" = "", out)
  }
  shiny::observe({
    rv$tick
    shiny::updateSelectInput(session, "new_code_parent", choices = code_choices())
    shiny::updateSelectInput(session, "ren_code_select",
                             choices = stats::setNames(as.character(qda_codes()$id), qda_codes()$label))
  })

  # document tree (left top) ---------------------------------------------------
  output$doc_tree <- shiny::renderUI({
    rv$tick
    s <- qda_sources()
    if (nrow(s) == 0) return(shiny::tags$div(class = "placeholder", "Noch keine Dokumente importiert."))
    ps <- qda_stats()$per_source
    rows <- vapply(seq_len(nrow(s)), function(i) {
      cls <- if (!is.null(rv$src) && rv$src == s$id[i]) "docrow sel" else "docrow"
      pct <- if (s$id[i] %in% ps$id) ps$pct_coded[match(s$id[i], ps$id)] else 0
      sprintf('<div class="%s" data-src="%d"><i class="fa-solid fa-file-lines"></i>
               <span>%s</span><span class="fmt">%s - %d Seg.</span>
               <span class="pbar" title="%.1f %% codiert"><span style="width:%.1f%%"></span></span></div>',
              cls, s$id[i], esc(s$name[i]), esc(s$format[i]), s$segments[i], pct, pct)
    }, character(1))
    shiny::HTML(paste(rows, collapse = ""))
  })
  shiny::observeEvent(input$open_source, {
    rv$src <- input$open_source; rv$sel <- NULL; rv$clicked <- NULL
  })
  shiny::observeEvent(input$import_btn, {
    shiny::req(input$import_files)
    # original upload names (datapath is only a temp name like 0.pdf)
    qda_import(input$import_files$datapath, names = input$import_files$name)
    bump(); shiny::showNotification("Importiert (Text eingefroren, Original in originals/).", type = "message")
  })

  # document browser (center top) ----------------------------------------------
  output$doc_title <- shiny::renderText({
    rv$tick
    if (is.null(rv$src)) "Dokument-Browser" else .resolve_source(rv$src)$name
  })
  output$doc <- shiny::renderUI({
    rv$tick
    id <- rv$src
    if (is.null(id)) return(shiny::tags$div(class = "placeholder", "Links ein Dokument auswaehlen ..."))
    shiny::HTML(.render_doc_html(id, sel_cid = rv$sel_memo))
  })
  shiny::observeEvent(input$selection, {
    rv$sel <- input$selection
  }, ignoreNULL = FALSE)

  output$actionbar <- shiny::renderUI({
    rv$tick
    s <- rv$sel
    if (is.null(s)) return(NULL)
    codes <- qda_codes()
    codes <- codes[codes$label != "Memo", , drop = FALSE]  # reserved code: not assignable
    btns <- if (nrow(codes) > 0) {
      paste(vapply(seq_len(nrow(codes)), function(i) {
        sprintf('<button class="codebtn" data-codeid="%d" style="background-color:%s" title="%s">%s</button>',
                codes$id[i], esc(codes$color[i]), esc(codes$path[i]), esc(codes$label[i]))
      }, character(1)), collapse = "")
    } else '<span style="color:#8a94a0">Noch keine Codes angelegt (Code System links)</span>'
    shiny::div(class = "actionbar",
      shiny::span(class = "selinfo", sprintf("Markiert: Zeichen %d-%d", s$start, s$end)),
      shiny::HTML(btns),
      shiny::tags$button(id = "memo_only_btn", "Memo speichern",
                         title = "Markierten Text als Memo-Markierung speichern (Auswahl bleibt sichtbar)"),
      shiny::textInput("memo_field", label = NULL, placeholder = "Memo (optional)")
    )
  })
  shiny::observeEvent(input$assign_code, {
    shiny::req(rv$src, rv$sel)
    s <- rv$sel
    n <- nchar(.resolve_source(rv$src)$frozen_text, type = "chars")
    qda_code(rv$src, input$assign_code, start = s$start, end = min(s$end, n),
             memo = input$memo_field %||% "")
    rv$sel <- NULL
    bump()
    shiny::showNotification("Coding gespeichert (Audit-Trail aktualisiert).", type = "message")
  })

  # reserved code for memo passages (rendered as underline, not background)
  memo_code_id <- function() {
    con <- qda_con()
    row <- DBI::dbGetQuery(con, "SELECT id FROM codes WHERE label = 'Memo' AND IFNULL(parent_id, 0) = 0")
    if (nrow(row) > 0) return(row$id[1])
    qda_code_add("Memo", color = "#999999",
                 description = "reserviert fuer Memo-Markierungen (Unterstreichung)")
    DBI::dbGetQuery(con, "SELECT id FROM codes WHERE label = 'Memo' AND IFNULL(parent_id, 0) = 0")$id[1]
  }
  shiny::observeEvent(input$add_memo_only, {
    shiny::req(rv$src, rv$sel)
    s <- rv$sel
    frozen <- .resolve_source(rv$src)$frozen_text
    n <- nchar(frozen, type = "chars")
    end <- min(s$end, n)
    txt <- substring(frozen, s$start, end)
    memo_txt <- input$memo_field %||% ""
    if (!nzchar(memo_txt)) memo_txt <- txt
    # store as coding with the reserved Memo code -> underlined in the browser.
    # the selection stays visible: the new mark is rendered as "selected"
    # (thick underline) until the user selects something else.
    res <- qda_code(rv$src, memo_code_id(), start = s$start, end = end, memo = memo_txt)
    rv$sel_memo <- res$id
    bump()
    shiny::showNotification("Memo gespeichert - Markierung bleibt im Browser hervorgehoben.", type = "message")
  })

  # click on a highlight -> inspect / delete ----------------------------------
  shiny::observeEvent(input$clicked_coding, { rv$clicked <- input$clicked_coding })
  output$clicked_bar <- shiny::renderUI({
    rv$tick
    cid <- rv$clicked
    if (is.null(cid)) return(NULL)
    df <- qda_codings()
    row <- df[df$id == cid, , drop = FALSE]
    if (nrow(row) == 0) { rv$clicked <- NULL; return(NULL) }
    shiny::div(class = "clickedbar",
      shiny::span(class = "snippet",
        sprintf("Coding #%d - %s - %s - Zeichen %d-%d: '%s'%s",
                row$id, row$source, row$code, row$start, row$end,
                if (nchar(row$text) > 90) paste0(substr(row$text, 1, 90), "...") else row$text,
                if (nzchar(row$memo)) paste0("  |  Memo: ", row$memo) else "")),
      shiny::actionButton("del_clicked_coding", "Loeschen", icon = fontawesome::fa("trash"),
                          class = "btn-sm btn-outline-danger")
    )
  })
  shiny::observeEvent(input$del_clicked_coding, {
    shiny::req(rv$clicked)
    qda_coding_delete(rv$clicked)
    rv$clicked <- NULL; bump()
    shiny::showNotification("Coding geloescht (Audit-Trail).", type = "message")
  })
  shiny::observeEvent(input$del_coding, {
    qda_coding_delete(input$del_coding); bump()
    shiny::showNotification("Coding geloescht (Audit-Trail).", type = "message")
  })
  # click a segment/coding in a list -> jump to it in the document browser ----
  shiny::observeEvent(input$goto_coding, {
    df <- qda_codings()
    row <- df[df$id == input$goto_coding, , drop = FALSE]
    if (nrow(row) == 0) return()
    rv$src <- row$source_id
    rv$sel <- NULL
    rv$clicked <- row$id
    bump()
    session$sendCustomMessage("jellyqdaScroll", list(cid = row$id))
  })

  # code system (left bottom) ---------------------------------------------------
  shiny::observeEvent(input$sel_code, { rv$sel_code <- input$sel_code })
  output$code_tree <- shiny::renderUI({
    rv$tick
    codes <- qda_codes()
    if (nrow(codes) == 0) return(shiny::tags$div(class = "placeholder", "Noch keine Codes."))
    rows <- vapply(seq_len(nrow(codes)), function(i) {
      cls <- if (!is.null(rv$sel_code) && rv$sel_code == codes$id[i]) "coderow sel" else "coderow"
      sprintf('<div class="%s" draggable="true" data-selcode="%d" data-codeid="%d" title="Klicken = Segmente anzeigen; auf anderen Code ziehen = umhaengen">
               <span class="swatch" style="background-color:%s"></span>
               <span class="codelabel" title="%s">%s</span><span class="fmt">%d</span>
               <button class="mini" data-delcode="%d" title="Code loeschen"><i class="fa-solid fa-trash"></i> Del</button></div>',
              cls, codes$id[i], codes$id[i], esc(codes$color[i]), esc(codes$path[i]), esc(codes$label[i]),
              codes$n_codings[i], codes$id[i])
    }, character(1))
    shiny::HTML(paste(rows, collapse = ""))
  })
  shiny::observeEvent(input$add_code_btn, {
    shiny::req(input$new_code_label)
    parent <- input$new_code_parent
    qda_code_add(input$new_code_label,
                 parent = if (is.null(parent) || parent == "") NULL else as.integer(parent),
                 color = input$new_code_color %||% "#E69F00",
                 description = input$new_code_desc %||% "")
    shiny::updateTextInput(session, "new_code_label", value = "")
    bump()
    shiny::showNotification("Code angelegt.", type = "message")
  })
  shiny::observeEvent(input$rename_code_btn, {
    shiny::req(input$ren_code_select, input$ren_code_label)
    qda_code_rename(as.integer(input$ren_code_select), input$ren_code_label)
    bump(); shiny::showNotification("Code umbenannt.", type = "message")
  })
  shiny::observeEvent(input$delete_code_btn, {
    shiny::req(input$ren_code_select)
    qda_code_delete(as.integer(input$ren_code_select))
    bump(); shiny::showNotification("Code (inkl. Unter-Codes/Codings) geloescht.", type = "warning")
  })
  shiny::observeEvent(input$del_code_id, {
    qda_code_delete(input$del_code_id)
    bump(); shiny::showNotification("Code geloescht.", type = "warning")
  })

  # retrieved segments (center bottom) -----------------------------------------
  output$seg_head <- shiny::renderUI({
    rv$tick
    if (!is.null(rv$sel_code)) {
      lab <- qda_codes()$label[qda_codes()$id == rv$sel_code]
      if (length(lab) == 0) lab <- "?"
      shiny::span(sprintf("Retrieved Segments: %s (%d)", lab, sum(qda_codings()$code_id == rv$sel_code)))
    } else {
      shiny::span(sprintf("All Codings (%d)", nrow(qda_codings())))
    }
  })
  output$seg_panel <- shiny::renderUI({
    rv$tick
    df <- if (!is.null(rv$sel_code)) {
      d <- qda_codings()
      d[d$code_id == rv$sel_code, , drop = FALSE]
    } else {
      qda_codings()
    }
    # optional filter: only documents having a certain variable value
    if (!is.null(rv$var_filter) && nzchar(rv$var_filter)) {
      kv <- strsplit(rv$var_filter, "=", fixed = TRUE)[[1]]
      keep <- vapply(qda_sources()$id, function(sid) {
        v <- qda_source_vars(sid)
        !is.null(v[[kv[1]]]) && v[[kv[1]]] == kv[2]
      }, logical(1))
      df <- df[df$source_id %in% qda_sources()$id[keep], , drop = FALSE]
    }
    if (nrow(df) == 0) return(shiny::tags$div(class = "placeholder", "Noch keine Codings."))
    rows <- vapply(seq_len(nrow(df)), function(i) {
      snippet <- if (nchar(df$text[i]) > 80) paste0(substr(df$text[i], 1, 80), "...") else df$text[i]
      sprintf('<div class="segrow" data-goto="%d" title="Im Dokument-Browser zeigen">
               <span class="snippet">#%d <b>%s</b> &rarr; <b>%s</b> (%d-%d) %s%s</span>
               <button class="mini" data-delcoding="%d"><i class="fa-solid fa-trash"></i> Del</button></div>',
              df$id[i], df$id[i], esc(df$source[i]), esc(df$code[i]), df$start[i], df$end[i],
              esc(snippet),
              if (nzchar(df$memo[i])) sprintf('<span class="memo">Memo: %s</span>', esc(df$memo[i])) else "",
              df$id[i])
    }, character(1))
    shiny::HTML(paste(rows, collapse = ""))
  })

  # project-wide full-text search ----------------------------------------------
  shiny::observeEvent(input$search_btn, {
    q <- input$search_q
    if (is.null(q) || !nzchar(trimws(q))) return()
    q <- trimws(q)
    hits <- list()
    for (sid in qda_sources()$id) {
      txt <- .resolve_source(sid)$frozen_text
      low <- tolower(txt); ql <- tolower(q)
      pos <- 1L
      while (length(hits) < 200) {
        p <- regexpr(ql, substring(low, pos), fixed = TRUE)
        if (p < 0) break
        at <- pos + p - 1L
        hits[[length(hits) + 1]] <- list(
          src = sid, pos = at,
          snippet = substring(txt, max(1L, at - 40L), min(nchar(txt, "chars"), at + nchar(q, "chars") + 40L)))
        pos <- at + 1L
      }
    }
    rv$search <- hits
    bump()
    shiny::showNotification(sprintf("Suche '%s': %d Treffer", q, length(hits)), type = "message")
  })
  output$search_results <- shiny::renderUI({
    rv$tick
    hits <- rv$search
    if (is.null(hits)) return(NULL)
    if (length(hits) == 0) return(shiny::tags$div(class = "placeholder", "Keine Treffer."))
    rows <- vapply(hits, function(h) {
      nm <- .resolve_source(h$src)$name
      sprintf('<div class="segrow" data-gotopos data-src="%d" data-pos="%d" title="Im Dokument-Browser springen">
               <span class="snippet"><b>%s</b> (Pos %d): ...%s...</span></div>',
              h$src, h$pos, esc(nm), h$pos, esc(h$snippet))
    }, character(1))
    shiny::HTML(paste0('<div class="memogroup">Treffer (Klick = springen)</div>', paste(rows, collapse = "")))
  })
  shiny::observeEvent(input$goto_pos, {
    rv$src <- input$goto_pos$src
    rv$sel <- NULL; rv$clicked <- NULL
    bump()
    session$sendCustomMessage("jellyqdaScroll", list(pos = input$goto_pos$pos))
  })

  # variables (case attributes) per document ------------------------------------
  shiny::observe({
    rv$tick
    s <- qda_sources()
    shiny::updateSelectInput(session, "var_doc",
                             choices = stats::setNames(as.character(s$id), s$name),
                             selected = if (nrow(s) && !is.null(rv$src)) as.character(rv$src) else NULL)
    # variable filter options across all sources
    opts <- character()
    for (sid in s$id) {
      v <- qda_source_vars(sid)
      if (length(v)) opts <- c(opts, paste0(names(v), "=", v))
    }
    shiny::updateSelectInput(session, "var_filter",
                             choices = c("(alle)" = "", sort(unique(opts))),
                             selected = rv$var_filter %||% "")
  })
  shiny::observeEvent(input$var_filter, { rv$var_filter <- input$var_filter %||% "" })
  shiny::observeEvent(input$var_add_btn, {
    shiny::req(input$var_doc, input$var_key)
    if (!nzchar(trimws(input$var_key))) return()
    qda_source_set_var(as.integer(input$var_doc), trimws(input$var_key), input$var_val %||% "")
    shiny::updateTextInput(session, "var_key", value = "")
    shiny::updateTextInput(session, "var_val", value = "")
    bump()
    shiny::showNotification("Variable gesetzt.", type = "message")
  })
  shiny::observeEvent(input$del_var, {
    parts <- strsplit(input$del_var, "|", fixed = TRUE)[[1]]
    qda_source_del_var(as.integer(parts[1]), parts[2])
    bump()
  })
  output$var_list <- shiny::renderUI({
    rv$tick
    sid <- if (!is.null(input$var_doc)) as.integer(input$var_doc) else rv$src
    if (is.null(sid)) return(NULL)
    v <- qda_source_vars(sid)
    if (length(v) == 0) return(shiny::tags$div(class = "placeholder", "Keine Variablen."))
    rows <- vapply(seq_along(v), function(i) {
      sprintf('<div class="segrow"><span class="snippet"><b>%s</b> = %s</span>
               <button class="mini" data-delvar="1" data-varsrc="%d" data-varkey="%s"><i class="fa-solid fa-trash"></i> Del</button></div>',
              esc(names(v)[i]), esc(v[i]), sid, esc(names(v)[i]))
    }, character(1))
    shiny::HTML(paste(rows, collapse = ""))
  })
  # JS: del-var button carries data-varsrc/data-varkey -> single input
  output$doc_vars <- shiny::renderUI({
    rv$tick
    if (is.null(rv$src)) return(NULL)
    v <- qda_source_vars(rv$src)
    if (length(v) == 0) return(NULL)
    shiny::div(class = "docvars",
      lapply(seq_along(v), function(i) shiny::span(class = "chip", paste0(names(v)[i], " = ", v[i]))))
  })

  # re-parent a code by drag & drop in the code tree ----------------------------
  shiny::observeEvent(input$reparent_code, {
    res <- tryCatch(
      qda_code_move(input$reparent_code$code, input$reparent_code$parent),
      error = function(e) {
        shiny::showNotification(paste("Umhaengen nicht moeglich:", conditionMessage(e)), type = "warning")
        NULL
      })
    if (!is.null(res)) {
      bump()
      shiny::showNotification("Code verschoben (neuer Parent).", type = "message")
    }
  })

  # memos (right column) ---------------------------------------------------------
  output$memo_detail <- shiny::renderUI({
    rv$tick
    cid <- rv$clicked
    if (is.null(cid)) {
      return(shiny::tags$div(class = "memodetail",
        shiny::tags$span(class = "who", "Memo"),
        "Text markieren oder ein Coding anklicken, um sein Memo hier zu sehen."))
    }
    df <- qda_codings()
    row <- df[df$id == cid, , drop = FALSE]
    if (nrow(row) == 0) return(NULL)
    shiny::tags$div(class = "memodetail",
      shiny::tags$span(class = "who", sprintf("Memo zu Coding #%d (%s / %s)", row$id, row$source, row$code)),
      shiny::tags$button(class = "mini", `data-cleardetail` = "1",
                         title = "Bereich loeschen (schliessen)", "X"),
      if (nzchar(row$memo)) row$memo else shiny::tags$em("(kein Memo)"))
  })
  # memo section: two groups -- memo-marked passages (jump to text) + free memos.
  # every entry has inline edit (pen), delete (trash) and save (in edit mode).
  output$memos_list <- shiny::renderUI({
    rv$tick
    esc2 <- esc
    # group 1: codings with the reserved Memo code (= underlined passages)
    mc <- DBI::dbGetQuery(qda_con(), "
      SELECT c.id, c.source_id, s.name AS source, c.start, c.end, c.memo
      FROM codings c JOIN codes k ON k.id = c.code_id JOIN sources s ON s.id = c.source_id
      WHERE k.label = 'Memo' ORDER BY c.source_id, c.start")
    mk_rows <- if (nrow(mc) == 0) character() else vapply(seq_len(nrow(mc)), function(i) {
      key <- paste0("cod_", mc$id[i])
      if (!is.null(rv$edit_entry) && rv$edit_entry == key) {
        sprintf('<div class="memorow editing"><textarea id="memo_edit_%s" rows="2" style="width:100%%">%s</textarea>
                 <button class="mini ok" data-savememo="%s" title="Speichern"><i class="fa-solid fa-check"></i> Save</button>
                 <button class="mini" data-canceledit="1" title="Abbrechen"><i class="fa-solid fa-xmark"></i> X</button></div>',
                key, esc2(mc$memo[i]), key)
      } else {
        lab <- if (nzchar(mc$memo[i])) mc$memo[i] else paste0("Zeichen ", mc$start[i], "-", mc$end[i])
        sprintf('<div class="memorow memomark-row" data-gotomemo="%d" title="Zur Markierung springen">
                 <span class="snippet">#%d %s (%d-%d): %s</span>
                 <button class="mini" data-editmemo="%s" title="Memo bearbeiten"><i class="fa-solid fa-pen"></i> Edit</button>
                 <button class="mini" data-delcoding="%d" title="Markierung loeschen"><i class="fa-solid fa-trash"></i> Del</button></div>',
                mc$id[i], mc$id[i], esc2(mc$source[i]), mc$start[i], mc$end[i], esc2(lab), key, mc$id[i])
      }
    }, character(1))
    # group 2: free memos
    m <- qda_memos()
    fm_rows <- if (nrow(m) == 0) character() else vapply(seq_len(nrow(m)), function(i) {
      key <- paste0("memo_", m$id[i])
      if (!is.null(rv$edit_entry) && rv$edit_entry == key) {
        sprintf('<div class="memorow editing"><textarea id="memo_edit_%s" rows="2" style="width:100%%">%s</textarea>
                 <button class="mini ok" data-savememo="%s" title="Speichern"><i class="fa-solid fa-check"></i> Save</button>
                 <button class="mini" data-canceledit="1" title="Abbrechen"><i class="fa-solid fa-xmark"></i> X</button></div>',
                key, esc2(m$text_[i]), key)
      } else {
        sprintf('<div class="memorow"><span class="snippet">#%d - %s - %s</span>
                 <button class="mini" data-editmemo="%s" title="Memo bearbeiten"><i class="fa-solid fa-pen"></i> Edit</button>
                 <button class="mini" data-delmemo="%d" title="Memo loeschen"><i class="fa-solid fa-trash"></i> Del</button></div>',
                m$id[i], esc2(m$created_at[i]), esc2(m$text_[i]), key, m$id[i])
      }
    }, character(1))
    if (length(mk_rows) == 0 && length(fm_rows) == 0) {
      return(shiny::tags$div(class = "placeholder", "Noch keine Memos."))
    }
    shiny::HTML(paste0(
      if (length(mk_rows)) c('<div class="memogroup">Memo-Markierungen (Klick = zur Stelle springen)</div>', mk_rows) else "",
      if (length(fm_rows)) c('<div class="memogroup">Freie Memos</div>', fm_rows) else ""
    ))
  })
  shiny::observeEvent(input$edit_memo_entry, { rv$edit_entry <- input$edit_memo_entry })
  shiny::observeEvent(input$cancel_edit, { rv$edit_entry <- NULL; bump() })
  # "Bereich loeschen" on the memo detail card: close/clear the detail area
  shiny::observeEvent(input$clear_detail, { rv$clicked <- NULL; rv$sel_memo <- NULL; bump() })
  shiny::observeEvent(input$save_memo_entry, {
    key <- input$save_memo_entry
    txt <- input[[paste0("memo_edit_", key)]]
    if (is.null(txt)) return()
    parts <- strsplit(key, "_", fixed = TRUE)[[1]]
    if (parts[1] == "cod") {
      qda_coding_set_memo(as.integer(parts[2]), txt)
      shiny::showNotification("Memo-Markierung aktualisiert (Audit-Trail).", type = "message")
    } else {
      qda_memo_update(as.integer(parts[2]), txt)
      shiny::showNotification("Memo aktualisiert (Audit-Trail).", type = "message")
    }
    rv$edit_entry <- NULL
    bump()
  })
  shiny::observeEvent(input$del_memo, {
    qda_memo_delete(input$del_memo)
    bump()
    shiny::showNotification("Memo geloescht (Audit-Trail).", type = "message")
  })
  # click a memo-marked passage -> jump to it in the browser and highlight it
  shiny::observeEvent(input$goto_memo, {
    df <- qda_codings()
    row <- df[df$id == input$goto_memo, , drop = FALSE]
    if (nrow(row) == 0) return()
    rv$src <- row$source_id
    rv$sel <- NULL
    rv$clicked <- row$id
    rv$sel_memo <- row$id
    bump()
    session$sendCustomMessage("jellyqdaScroll", list(cid = row$id))
  })

  # header: stats + backup + export ---------------------------------------------
  output$stats_line <- shiny::renderText({
    rv$tick
    st <- qda_stats()$overall
    sprintf("%d Quellen - %d Codes - %d Codings - %.1f %% codiert",
            st$n_sources, st$n_codes, st$n_codings, st$pct_coded)
  })
  output$saved_line <- shiny::renderText({
    rv$tick
    sprintf("Gespeichert: %s", rv$last_saved %||% "-")
  })
  shiny::observeEvent(input$undo_btn, {
    res <- tryCatch(qda_undo(), error = function(e) {
      shiny::showNotification(paste("Undo nicht moeglich:", conditionMessage(e)), type = "warning")
      NULL
    })
    if (!is.null(res)) {
      bump()
      shiny::showNotification(paste("Undo:", res$detail), type = "message")
    }
  })
  # click on a segment badge -> select the whole segment (action bar appears)
  shiny::observeEvent(input$seg_click, {
    shiny::req(rv$src)
    segs <- .split_segments_full(.resolve_source(rv$src)$frozen_text)$segs
    i <- as.integer(input$seg_click)
    if (i < 1 || i > nrow(segs)) return()
    rv$sel <- list(start = segs$start[i], end = segs$end[i],
                   text = substring(.resolve_source(rv$src)$frozen_text, segs$start[i], segs$end[i]))
    bump()
  })
  # help modal: legend of icons + shortcuts
  shiny::observeEvent(input$help_btn, {
    shiny::showModal(shiny::modalDialog(
      title = "Hilfe: Symbole & Tastenkuerzel",
      shiny::tags$ul(
        shiny::tags$li(shiny::strong("Strg+1..9"), " - markierten Text dem n-ten Code der Aktionsleiste zuweisen"),
        shiny::tags$li(shiny::strong("Strg+M"), " - Memo speichern (Text markiert + Memo-Text in der Aktionsleiste)"),
        shiny::tags$li(shiny::strong("Seg-Badge"), " anklicken - ganzen Absatz markieren"),
        shiny::tags$li(shiny::strong("Symbolleiste oben"), " - jedes Icon klappt sein Fenster ein/aus; << und >> klappen nur die linke/rechte Spalte ein (Dokument-Browser bleibt)"),
        shiny::tags$li(shiny::strong("Mond"), " - Dark Mode; ", shiny::strong("?"), " - diese Hilfe; ", shiny::strong("X"), " - App beenden (speichert + Backup)"),
        shiny::tags$li(shiny::strong("Codebaum"), " - Code auf einen anderen Code ziehen, um ihn umzuhaengen (Re-Parent)"),
        shiny::tags$li(shiny::strong("Dokumente-Panel"), " - Dateien per Drag & Drop importieren"),
        shiny::tags$li(shiny::strong("Doppel-Codierung"), " - derselbe Text mehrfach codiert: gestrichelter pinker Rahmen")
      ),
      easyClose = TRUE, footer = shiny::modalButton("Schliessen")
    ))
  })
  shiny::observeEvent(input$backup_btn, {
    z <- qda_backup(quiet = TRUE)
    bump(); shiny::showNotification(paste("Backup:", z), type = "message")
  })
  shiny::observeEvent(input$export_btn, {
    ex <- qda_export("all")
    bump(); shiny::showNotification(paste("Exportiert:", nrow(ex), "Dateien nach exports/"), type = "message")
  })

  # code matrix (Code Matrix Browser) -------------------------------------------
  output$matrix_panel <- shiny::renderUI({
    rv$tick
    codes <- qda_codes()
    sources <- qda_sources()
    if (nrow(codes) == 0 || nrow(sources) == 0) {
      return(shiny::tags$div(class = "placeholder", "Codes und Dokumente noetig."))
    }
    cod <- DBI::dbGetQuery(qda_con(), "SELECT code_id, source_id, COUNT(*) AS n FROM codings GROUP BY code_id, source_id")
    cnt <- matrix(0L, nrow = nrow(codes), ncol = nrow(sources),
                  dimnames = list(as.character(codes$id), as.character(sources$id)))
    if (nrow(cod) > 0) cnt[cbind(as.character(cod$code_id), as.character(cod$source_id))] <- cod$n
    maxn <- max(cnt, 1L)
    esc2 <- htmltools::htmlEscape
    head <- paste0('<tr><th>Code \\ Dokument</th>',
                   paste0('<th>', esc2(sources$name), '</th>', collapse = ""), "<th>SUM</th></tr>")
    body_rows <- vapply(seq_len(nrow(codes)), function(i) {
      cells <- vapply(seq_len(nrow(sources)), function(j) {
        n <- cnt[i, j]
        bg <- if (n > 0) sprintf(' style="background:rgba(44,111,187,%s)"', round(0.15 + 0.75 * n / maxn, 2)) else ""
        sprintf('<td class="mxcell" data-mxcode="%d" data-mxsrc="%d"%s>%s</td>',
                codes$id[i], sources$id[j], bg, if (n > 0) n else "")
      }, character(1))
      sprintf('<tr><td class="rowlab" data-selcode="%d"><span class="swatch" style="background-color:%s"></span> %s</td>%s<td><b>%d</b></td></tr>',
              codes$id[i], esc2(codes$color[i]), esc2(codes$label[i]), paste0(cells, collapse = ""), sum(cnt[i, ]))
    }, character(1))
    colsums <- vapply(seq_len(nrow(sources)), function(j) sum(cnt[, j]), integer(1))
    foot <- sprintf('<tr class="sumrow"><td>SUM</td>%s<td>%d</td></tr>',
                    paste0("<td>", colsums, "</td>", collapse = ""), sum(cnt))
    shiny::HTML(paste0('<table class="mx">', head, paste0(body_rows, collapse = ""), foot, "</table>"))
  })
  shiny::observeEvent(input$mx_cell, {
    rv$sel_code <- input$mx_cell$code
    rv$src <- input$mx_cell$source
    rv$sel <- NULL
    bump()
    shiny::showNotification("Zelle gewaehlt: Code im Browser geoeffnet.", type = "message")
  })

  # summary grid -----------------------------------------------------------------
  output$sum_matrix <- shiny::renderUI({
    rv$tick
    codes <- qda_codes()
    sources <- qda_sources()
    if (nrow(codes) == 0 || nrow(sources) == 0) {
      return(shiny::tags$div(class = "placeholder", "Codes und Dokumente noetig."))
    }
    cod <- DBI::dbGetQuery(qda_con(), "SELECT code_id, source_id, COUNT(*) AS n FROM codings GROUP BY code_id, source_id")
    has_sum <- qda_summaries()
    has_keys <- if (nrow(has_sum)) paste(has_sum$code_id, has_sum$source_id, sep = "_") else character()
    esc2 <- htmltools::htmlEscape
    head <- paste0('<tr><th>Code \\ Dokument</th>',
                   paste0("<th>", esc2(substr(sources$name, 1, 12)), "</th>", collapse = ""), "</tr>")
    body_rows <- vapply(seq_len(nrow(codes)), function(i) {
      cells <- vapply(seq_len(nrow(sources)), function(j) {
        n <- if (nrow(cod)) sum(cod$n[cod$code_id == codes$id[i] & cod$source_id == sources$id[j]]) else 0L
        cls <- if (paste(codes$id[i], sources$id[j], sep = "_") %in% has_keys) "sumcell has" else "sumcell"
        sprintf('<td class="%s" data-sumcode="%d" data-sumsrc="%d" title="%d Codings">%s</td>',
                cls, codes$id[i], sources$id[j], n, if (n > 0) n else "")
      }, character(1))
      sprintf('<tr><td class="rowlab" data-selcode="%d"><span class="swatch" style="background-color:%s"></span> %s</td>%s</tr>',
              codes$id[i], esc2(codes$color[i]), esc2(codes$label[i]), paste0(cells, collapse = ""))
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
      return(shiny::tags$div(class = "placeholder", "Zelle in der Summary-Grid anklicken ..."))
    }
    codes <- qda_codes(); sources <- qda_sources()
    clab <- codes$label[codes$id == sc$code]; slab <- sources$name[sources$id == sc$source]
    segs <- qda_codings()
    segs <- segs[segs$code_id == sc$code & segs$source_id == sc$source, , drop = FALSE]
    seg_rows <- if (nrow(segs) == 0) '<div class="placeholder">keine Segmente</div>' else {
      paste(vapply(seq_len(nrow(segs)), function(i) {
        snippet <- if (nchar(segs$text[i]) > 70) paste0(substr(segs$text[i], 1, 70), "...") else segs$text[i]
        sprintf('<div class="segrow" data-goto="%d"><span class="snippet">#%d (%d-%d) %s</span></div>',
                segs$id[i], segs$id[i], segs$start[i], segs$end[i], esc(snippet))
      }, character(1)), collapse = "")
    }
    shiny::div(
      shiny::tags$b(sprintf("Zelle: %s x %s (%d Segmente)", clab, slab, nrow(segs))),
      shiny::div(class = "sumdetail-segs", shiny::HTML(seg_rows)),
      shiny::textAreaInput("sum_text", "Summary (wird gespeichert)", rows = 3, value = rv$sum_text_val %||% ""),
      shiny::actionButton("sum_save_btn", "Summary speichern", icon = fontawesome::fa("floppy-disk"), class = "btn-sm btn-primary")
    )
  })
  shiny::observeEvent(input$sum_save_btn, {
    shiny::req(rv$sum_cell)
    txt <- input$sum_text %||% ""
    qda_summary_set(rv$sum_cell$code, rv$sum_cell$source, txt)
    rv$sum_text_val <- txt
    bump()
    shiny::showNotification("Summary gespeichert (Audit-Trail).", type = "message")
  })

  # flexible layout -------------------------------------------------------------
  shiny::observeEvent(input$layout_reset, {
    session$sendCustomMessage("jellyqdaReset", 1)
  })
  # close app: save work (export + backup), then stop ---------------------------
  shiny::observeEvent(input$close_app, {
    qda_export("all")
    z <- qda_backup(quiet = TRUE)
    shiny::showNotification(paste("Gespeichert. Export + Backup:", z), type = "message", duration = 10)
    shiny::stopApp()
  })
}


