/* ==========================================================================
   jellyqda.js -- browser logic of the Shiny app qda_app()

   Included in R/app.R via .jellyqda_assets() in the <head> (source:
   inst/app/www/ in the installed package). jQuery and Shiny are already
   loaded at this point.

   Principle: the browser does almost nothing by itself. Every action is sent
   to the server with
     Shiny.setInputValue('<name>', value, {priority: 'event'})
   and handled there in R/app.R in .jellyqda_server() with
     shiny::observeEvent(input$<name>, { ... })
   'priority: event' makes the same value twice (e.g. the same code button
   twice) count as a new event.

   All clicks are "delegated" ($(document).on('click', selector, ...)), so
   that they also work for HTML that Shiny re-renders later via renderUI.

   Sections:
     1.  Helper functions (incl. jqT/jqF for English/German texts)
     2.  Text selection in the document -> character offsets (input$selection)
     3.  Clicks in the document: codings and segment badges
     4.  Clicks in lists: documents, codes, codings, search
     5.  Memos
     6.  Keyboard shortcuts (incl. Ctrl+Z / Ctrl+Y)
     7.  Drag & drop: move codes
     8.  Display: panels, dark mode, zoom, help, quit
     9.  Tables: code matrix and summary grid
     10. Messages from the server (sendCustomMessage)
     11. On page load: layout, file drop, column handles
     12. Overlapping codings: popover with all codings of a place
     13. Memo panel: new memos, filter, jump, focus
     14. Icons: <i class="fa-solid fa-NAME"> -> SVG from the icon registry
     15. Code tree (codes + subcodes) and coding bar, save, export menu
     16. Analysis tools: coding fields, in vivo, auto-coding, coding
         guideline, merging codes, case comparison, analysis window
     17. Language (EN/DE)
   ========================================================================== */


/* --------------------------------------------------------------------------
   1. Hilfsfunktionen
   -------------------------------------------------------------------------- */

// Translation of UI texts: the server puts the English catalogue into
// window.jqI18n when the UI language is English (R/i18n.R). German is the
// source language, so without a catalogue the German text is shown.
function jqT(s) {
  var d = window.jqI18n;
  return (d && Object.prototype.hasOwnProperty.call(d, s)) ? d[s] : s;
}
// jqT + placeholders {0}, {1}, ... (word order may differ between languages)
function jqF(s, args) {
  return jqT(s).replace(/\{(\d+)\}/g, function(m, i) { return args[+i]; });
}

// Absolute 0-based character offset of the position (node, offset) within
// #doc. Trick: build a range from the start of #doc to the position and
// measure its text length. Works because #doc contains exactly the frozen
// text (segment badges are CSS pseudo-elements, no DOM text).
function absOffset(doc, node, offset) {
  try {
    var r = document.createRange();
    r.selectNodeContents(doc);
    r.setEnd(node, offset);
    return r.toString().length;
  } catch (e) { return null; }
}

// true while text is selected (e.g. right after a mouse selection). A
// following 'click' event must then do nothing, otherwise the selection would
// be overwritten (see section 3).
function hasTextSelection() {
  var s = window.getSelection();
  return !!(s && !s.isCollapsed && s.toString().length > 0);
}

// Scroll to a character position in #doc: walk the text nodes in order
// until the position is reached.
function scrollToChar(doc, pos) {
  var walker = document.createTreeWalker(doc, NodeFilter.SHOW_TEXT, null);
  var n, acc = 0;
  while ((n = walker.nextNode())) {
    var len = n.nodeValue.length;
    if (acc + len >= pos) {
      // BUGFIX: a Range has no scrollIntoView (error "r.scrollIntoView is not a
      // function", jumping to search hits did not scroll). Now: measure the
      // position of the place and scroll the scrollable ancestor.
      var r = document.createRange();
      r.setStart(n, Math.max(0, pos - acc));
      r.setEnd(n, Math.min(len, Math.max(0, pos - acc) + 1));
      var rect = r.getBoundingClientRect();
      var sc = doc.parentElement;
      while (sc && sc !== document.body) {
        var oy = getComputedStyle(sc).overflowY;
        if ((oy === 'auto' || oy === 'scroll') && sc.scrollHeight > sc.clientHeight) break;
        sc = sc.parentElement;
      }
      if (sc && sc !== document.body) {
        var srect = sc.getBoundingClientRect();
        sc.scrollTo({top: sc.scrollTop + rect.top - srect.top - sc.clientHeight / 2, behavior: 'smooth'});
      } else {
        n.parentElement.scrollIntoView({behavior: 'smooth', block: 'center'});
      }
      return true;
    }
    acc += len;
  }
  return false;
}


/* --------------------------------------------------------------------------
   2. Text selection in the document -> character offsets
   When the mouse is released, the selection is sent to input$selection as
   1-based, inclusive offsets {start, end, text}. The server then shows the
   action bar ("Marked: characters X-Y" + code buttons).
   Empty selection (simple click) -> input$selection = null -> bar gone;
   instead the cursor position is sent as input$caret (for the segment bar:
   "Split here", "Merge").
   -------------------------------------------------------------------------- */

$(document).on('mouseup', function(e) {
  var doc = document.getElementById('doc');
  if (!doc || !doc.contains(e.target)) return;   // only mouse actions in the document
  var sel = window.getSelection();
  if (!sel || sel.isCollapsed) {
    Shiny.setInputValue('selection', null);
    // cursor position (0-based = number of characters before the cursor)
    if (sel && sel.rangeCount > 0) {
      var c = absOffset(doc, sel.anchorNode, sel.anchorOffset);
      if (c !== null) Shiny.setInputValue('caret', {pos: c, t: Date.now()}, {priority: 'event'});
    }
    return;
  }
  // anchor = where the selection began, focus = where it ends (may be
  // before it when selecting backwards) -> min/max
  var a = absOffset(doc, sel.anchorNode, sel.anchorOffset);
  var f = absOffset(doc, sel.focusNode, sel.focusOffset);
  if (a === null || f === null) return;
  var s0 = Math.min(a, f), e0 = Math.max(a, f);
  Shiny.setInputValue('selection',
    {start: s0 + 1, end: e0, text: sel.toString()}, {priority: 'event'});
});


/* --------------------------------------------------------------------------
   3. Clicks in the document
   -------------------------------------------------------------------------- */

// Click on an existing coding (<mark>) -> details + delete button
// (input$clicked_coding). stopPropagation, so that the segment click
// underneath is not triggered as well.
$(document).on('click', '#doc mark', function(e) {
  if (hasTextSelection()) { e.stopPropagation(); return; }   // was a selection
  // underlined passage (passage memo): show the memo in the panel. NO
  // stopPropagation -- a coding underneath is shown as well.
  if (this.classList.contains('memomark')) {
    Shiny.setInputValue('clicked_memo', parseInt(this.getAttribute('data-mid'), 10), {priority: 'event'});
    return;
  }
  e.stopPropagation();
  // grey overlap area: pin the popover with all codings
  if (this.classList.contains('ovl')) { showOverlapPopover(this, true); return; }
  Shiny.setInputValue('clicked_coding', parseInt($(this).attr('data-cid')), {priority: 'event'});
});

// Click on the "Seg N" badge -> mark the whole paragraph (input$seg_click).
//
// BUGFIX: after a mouse selection inside a paragraph the browser also fires a
// 'click' on the .segtext div. This used to overwrite the exact selection
// with the whole segment, so the whole paragraph was always coded. Now only
// a real click (no selection) in the left padding, where the badge sits,
// counts.
$(document).on('click', '.segtext', function(e) {
  if (e.target.closest('mark')) return;
  if (hasTextSelection()) return;
  var pad = parseFloat(getComputedStyle(this).paddingLeft) || 0;
  if (e.clientX - this.getBoundingClientRect().left > pad) return;
  Shiny.setInputValue('seg_click', parseInt($(this).attr('data-seg'), 10), {priority: 'event'});
});

// Segment actions: segment bar (split here / merge / x) and "As segment" in
// the action bar -> input$seg_action {act: ...}
$(document).on('click', '[data-segact]', function(e) {
  e.stopPropagation();
  Shiny.setInputValue('seg_action', {act: $(this).attr('data-segact'), t: Date.now()}, {priority: 'event'});
});

// code button in the action bar -> code the marked text with this code
$(document).on('click', '.codebtn', function() {
  Shiny.setInputValue('assign_code', parseInt($(this).attr('data-codeid')), {priority: 'event'});
});


/* --------------------------------------------------------------------------
   4. Clicks in lists (documents, codes, codings, variables, search)
   The data are data-* attributes in the HTML that R generates.
   -------------------------------------------------------------------------- */

// open a document (data-src = source id)
$(document).on('click', '[data-src]', function() {
  Shiny.setInputValue('open_source', parseInt($(this).attr('data-src')), {priority: 'event'});
});
// ... and remember it as "last opened" (opened again at the next start)
$(document).on('click', '[data-src]', function() {
  try { localStorage.setItem('jellyqda_last_src', $(this).attr('data-src')); } catch (err) {}
});

// Select a code in the code tree -> show its segments (with marked text the
// server codes the selection instead, see app.R). The browser sets the
// selection (blue border) itself: the tree is not re-rendered on a click,
// otherwise no double click (rename) would arrive.
$(document).on('click', '[data-selcode]', function(e) {
  if (e.target.closest('input, .cacts, .cchev, .colordot')) return;
  var id = parseInt($(this).attr('data-selcode'), 10);
  jqMarkSelCode(id);
  Shiny.setInputValue('sel_code', id, {priority: 'event'});
});

// delete a coding (from a list)
$(document).on('click', '[data-delcoding]', function(e) {
  e.stopPropagation();
  Shiny.setInputValue('del_coding', parseInt($(this).attr('data-delcoding')), {priority: 'event'});
});

// click a coding in the list -> jump there in the document browser
$(document).on('click', '[data-goto]', function(e) {
  Shiny.setInputValue('goto_coding', parseInt($(this).attr('data-goto')), {priority: 'event'});
});

// delete a document variable; value = "<source id>|<variable name>"
$(document).on('click', '[data-delvar]', function(e) {
  e.stopPropagation();
  Shiny.setInputValue('del_var',
    $(this).attr('data-varsrc') + '|' + $(this).attr('data-varkey'), {priority: 'event'});
});

// search hit -> open the document and jump to the position
$(document).on('click', '[data-gotopos]', function(e) {
  Shiny.setInputValue('goto_pos', {
    src: parseInt($(this).attr('data-src'), 10),
    pos: parseInt($(this).attr('data-pos'), 10)
  }, {priority: 'event'});
});


/* --------------------------------------------------------------------------
   5. Memos (basic functions; the memo panel itself: section 13)
   -------------------------------------------------------------------------- */

// "Save memo" in the action bar (marked text -> passage memo)
$(document).on('click', '#memo_only_btn', function() {
  Shiny.setInputValue('add_memo_only', Date.now(), {priority: 'event'});
});

// delete a memo / remove a comment from a coding
$(document).on('click', '[data-delmemo]', function(e) {
  e.stopPropagation();
  Shiny.setInputValue('del_memo', parseInt($(this).attr('data-delmemo')), {priority: 'event'});
});
$(document).on('click', '[data-delcomment]', function(e) {
  e.stopPropagation();
  Shiny.setInputValue('del_comment', parseInt($(this).attr('data-delcomment')), {priority: 'event'});
});

// Edit / save / cancel. On saving, text and title are sent directly from the
// fields: Shiny transmits text input with a delay, so the last typed
// characters could be missing otherwise.
$(document).on('click', '[data-editmemo]', function(e) {
  e.stopPropagation();
  Shiny.setInputValue('edit_memo_entry', $(this).attr('data-editmemo'), {priority: 'event'});
});
$(document).on('click', '[data-savememo]', function(e) {
  e.stopPropagation();
  var key = $(this).attr('data-savememo');
  var t = document.getElementById('memo_edit_' + key);
  var h = document.getElementById('memo_title_' + key);
  Shiny.setInputValue('save_memo_entry', {key: key, text: t ? t.value : '', title: h ? h.value : null},
                      {priority: 'event'});
});
$(document).on('click', '[data-canceledit]', function(e) {
  e.stopPropagation();
  Shiny.setInputValue('cancel_edit', Date.now(), {priority: 'event'});
});


/* --------------------------------------------------------------------------
   6. Keyboard shortcuts
   Ctrl+1..9 = n-th code of the coding bar (see section 15)
   Ctrl+M    = save memo
   Ctrl+S    = save
   Ctrl+Z    = undo
   Ctrl+Y    = redo (also Ctrl+Shift+Z)
   (Cmd instead of Ctrl on the Mac). Disabled in input fields -- there the
   browser's normal undo for the text in the field applies.
   -------------------------------------------------------------------------- */

$(document).on('keydown', function(e) {
  if (!(e.ctrlKey || e.metaKey)) return;
  // Ctrl+S = save (also from inside input fields)
  if ((e.key === 's' || e.key === 'S') && !e.shiftKey) {
    e.preventDefault(); $('#save_btn').click(); return;
  }
  var t = ((e.target && e.target.tagName) || '').toLowerCase();
  if (t === 'input' || t === 'textarea' || t === 'select') return;
  if (e.key >= '1' && e.key <= '9') {
    // n-th top-level code of the coding bar: codes directly or unfolds its
    // subcodes (then 1..9 / 0 without Ctrl, section 15)
    var btns = document.querySelectorAll('.actionbar .pk-roots .rootchip');
    var i = parseInt(e.key, 10) - 1;
    if (btns[i]) {
      e.preventDefault();
      // code with subcodes: always unfold (do not toggle), otherwise code
      if (btns[i].hasAttribute('data-openroot')) jqOpenRoot(btns[i].getAttribute('data-openroot'));
      else btns[i].click();
    }
  } else if (e.key === 'm' || e.key === 'M') {
    var b = document.getElementById('memo_only_btn');
    if (b) { e.preventDefault(); b.click(); }
  } else if ((e.key === 'z' || e.key === 'Z') && !e.shiftKey) {
    e.preventDefault(); $('#undo_btn').click();
  } else if (e.key === 'y' || e.key === 'Y' || ((e.key === 'z' || e.key === 'Z') && e.shiftKey)) {
    e.preventDefault(); $('#redo_btn').click();
  }
});


/* --------------------------------------------------------------------------
   7. Drag & drop: move codes in the code tree (new parent)
   -------------------------------------------------------------------------- */

var dragCode = null;   // id of the code being dragged
$(document).on('dragstart', '.coderow', function(e) {
  dragCode = parseInt($(this).attr('data-codeid'), 10);
  document.body.classList.add('jq-dragcode');
});
$(document).on('dragend', '.coderow', function() {
  document.body.classList.remove('jq-dragcode');
});
// bottom of the tree: "Drop here = top level" (a subcode becomes a code again)
$(document).on('dragover', '.ctree-topdrop', function(e) {
  if (dragCode !== null) { e.preventDefault(); this.classList.add('over'); }
});
$(document).on('dragleave', '.ctree-topdrop', function() { this.classList.remove('over'); });
$(document).on('drop', '.ctree-topdrop', function(e) {
  if (dragCode === null) return;
  e.preventDefault();
  Shiny.setInputValue('reparent_code', {code: dragCode, parent: null}, {priority: 'event'});
  dragCode = null;
  document.body.classList.remove('jq-dragcode');
});
$(document).on('dragover', '.coderow', function(e) {
  if (dragCode !== null) e.preventDefault();   // preventDefault = "Drop hier erlaubt"
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


/* --------------------------------------------------------------------------
   8. Display: show/hide panels, dark mode, zoom, help, quit
   Settings are remembered in the browser's localStorage.
   -------------------------------------------------------------------------- */

// show/hide a panel (toolbar or chevron in the panel header)
$(document).on('click', '[data-toggle]', function(e) {
  e.stopPropagation();
  var p = document.getElementById($(this).attr('data-toggle'));
  if (p) p.classList.toggle('collapsed');
  if (window.jellyqdaSaveLayout) window.jellyqdaSaveLayout();
});

// Dark Mode umschalten (Bootstrap 5.3 Color Mode + Overrides in jellyqda.css)
$(document).on('click', '[data-dark]', function(e) {
  e.preventDefault();
  var dark = document.documentElement.getAttribute('data-bs-theme') === 'dark';
  document.documentElement.setAttribute('data-bs-theme', dark ? 'light' : 'dark');
  try { localStorage.setItem('jellyqda_dark', dark ? '0' : '1'); } catch (err) {}
});

// Font size in the document browser (A-/A+): via the CSS variable --jqzoom,
// so it survives every re-rendering of the document.
function applyZoom(z) {
  z = Math.min(1.6, Math.max(0.7, z));   // limits: 70 % to 160 %
  document.documentElement.style.setProperty('--jqzoom', z);
  try { localStorage.setItem('jellyqda_zoom', String(z)); } catch (err) {}
}
$(document).on('click', '[data-zoom]', function(e) {
  e.preventDefault();
  var cur = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--jqzoom')) || 1;
  applyZoom(cur + parseFloat($(this).attr('data-zoom')));
});

// help dialog (shown by the server as modalDialog)
$(document).on('click', '[data-help]', function(e) {
  e.preventDefault();
  Shiny.setInputValue('help_btn', Date.now(), {priority: 'event'});
});

// quit the app (the server exports, makes a backup and stops)
$(document).on('click', '[data-closeapp]', function(e) {
  if (confirm(jqT('jellyqda beenden? Arbeit wird gespeichert (Export + Backup).'))) {
    Shiny.setInputValue('close_app', Date.now(), {priority: 'event'});
  }
});


/* --------------------------------------------------------------------------
   9. Tables: click a cell -> show segments for (code x document)
   -------------------------------------------------------------------------- */

// Code-Matrix
$(document).on('click', '.mxcell', function() {
  Shiny.setInputValue('mx_cell', {
    code: parseInt($(this).attr('data-mxcode')),
    source: parseInt($(this).attr('data-mxsrc'))
  }, {priority: 'event'});
});

// Summary Grid
$(document).on('click', '.sumcell', function() {
  Shiny.setInputValue('sum_cell', {
    code: parseInt($(this).attr('data-sumcode')),
    source: parseInt($(this).attr('data-sumsrc'))
  }, {priority: 'event'});
});


/* --------------------------------------------------------------------------
   10. Nachrichten vom Server (session$sendCustomMessage in R)
   -------------------------------------------------------------------------- */

// Undo/redo: the tooltip shows what would happen; without an entry the button
// is greyed out. msg = {undo: text|null, redo: text|null}
Shiny.addCustomMessageHandler('jellyqdaHistory', function(msg) {
  function set(id, label, text, key) {
    var b = document.getElementById(id);
    if (!b) return;
    b.title = text ? jqF('{0}: {1} ({2})', [label, text, key]) : jqF('Nichts zum {0} ({1})', [label, key]);
    b.classList.toggle('jq-disabled', !text);
  }
  set('undo_btn', jqT('R\u00fcckg\u00e4ngig'), msg.undo, jqT('Strg+Z'));
  set('redo_btn', jqT('Wiederholen'), msg.redo, jqT('Strg+Y'));
});

// Scroll to a coding (msg.cid) or a character position (msg.pos). Wait a
// moment, because the server is just re-rendering the document.
Shiny.addCustomMessageHandler('jellyqdaScroll', function(msg) {
  setTimeout(function() {
    var doc = document.getElementById('doc');
    if (doc && msg.pos != null) { scrollToChar(doc, msg.pos); return; }
    if (msg.mid != null) {   // passage memo
      var mm = document.querySelector('#doc mark[data-mid="' + msg.mid + '"]');
      if (mm) mm.scrollIntoView({behavior: 'smooth', block: 'center'});
      return;
    }
    // the coding may also be part of an overlap only (data-cids)
    var m = document.querySelector('#doc mark[data-cid="' + msg.cid + '"], ' +
                                   '#doc mark[data-cids~="' + msg.cid + '"]');
    if (m) {
      m.scrollIntoView({behavior: 'smooth', block: 'center'});
      m.style.outline = '3px solid #2c6fbb';                       // highlight briefly
      setTimeout(function() { m.style.outline = ''; }, 2500);
    }
  }, 250);
});


/* --------------------------------------------------------------------------
   11. On page load (as soon as the HTML is complete)
   -------------------------------------------------------------------------- */

$(function() {
  var grid = document.querySelector('.appgrid');

  // ---- 11a. Save / restore the layout -------------------------------------
  // Remembered: column widths, which panel is in which column, and which
  // panels are collapsed.
  window.jellyqdaSaveLayout = function() { saveLayout(); };

  function saveLayout() {
    try {
      var panes = {};
      document.querySelectorAll('.pane').forEach(function(p) {
        panes[p.dataset.pane] = Array.from(p.querySelectorAll('.panel')).map(function(el) { return el.id; });
      });
      localStorage.setItem('jellyqda_layout', JSON.stringify({
        cols: grid.style.gridTemplateColumns || getComputedStyle(grid).gridTemplateColumns,
        panes: panes,
        collapsed: Array.from(document.querySelectorAll('.panel.collapsed')).map(function(el) { return el.id; })
      }));
    } catch (e) {}
  }

  function restoreLayout() {
    try {
      var L = JSON.parse(localStorage.getItem('jellyqda_layout') || 'null');
      if (!L) return;
      if (L.cols) grid.style.gridTemplateColumns = L.cols;
      ['left', 'center', 'right'].forEach(function(name) {
        var pane = document.querySelector('.pane[data-pane=' + name + ']');
        if (!pane) return;
        (L.panes[name] || []).forEach(function(pid) {
          var el = document.getElementById(pid);
          if (el) pane.appendChild(el);
        });
      });
      (L.collapsed || []).forEach(function(pid) {
        var el = document.getElementById(pid);
        if (el) el.classList.add('collapsed');
      });
    } catch (e) {}
  }
  restoreLayout();

  // ---- 11b. Restore zoom, dark mode and the last opened document
  try {
    var z = parseFloat(localStorage.getItem('jellyqda_zoom'));
    if (z) document.documentElement.style.setProperty('--jqzoom', z);
    if (localStorage.getItem('jellyqda_dark') === '1') {
      document.documentElement.setAttribute('data-bs-theme', 'dark');
    }
    var last = parseInt(localStorage.getItem('jellyqda_last_src'), 10);
    if (last) Shiny.setInputValue('open_source', last);
  } catch (e2) {}

  // ---- 11c. Drag panels by their header into another column -------------
  // The panel is inserted at the mouse position (before the panel over whose
  // upper half it is dropped).
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
    // The document browser and segments always stay in the middle column, so
    // they cannot be hidden by accident with a side column.
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

  // ---- 11d. Change column widths with the handles between the columns ----
  // data-a / data-b = index of the left / right grid column of the handle.
  // Minimum widths: 200px left, 300px or 0.5fr right.
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

  // ---- 11e. Drop files on the documents panel -> import field -------------
  // BUGFIX: this block used to run immediately in the <head>, when
  // #panel-docs did not exist yet, and therefore always stopped (drag & drop
  // of files never worked). Now it runs once the page is loaded.
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
      // put the files into the (hidden) Shiny fileInput and fire its
      // 'change' event -> Shiny uploads them as with "Files..."
      var dt = new DataTransfer();
      for (var i = 0; i < e.dataTransfer.files.length; i++) dt.items.add(e.dataTransfer.files[i]);
      inp.files = dt.files;
      inp.dispatchEvent(new Event('change', {bubbles: true}));
    });
  })();

  // ---- 11f. "Reset layout" (the server sends jellyqdaReset) --------------
  // BUGFIX: Shiny requires a handler with exactly one argument. There used to
  // be function() without an argument -> Shiny threw an error, the handler
  // was never registered and "Reset layout" did nothing.
  Shiny.addCustomMessageHandler('jellyqdaReset', function(msg) {
    try { localStorage.removeItem('jellyqda_layout'); } catch (e) {}
    location.reload();
  });
});


/* --------------------------------------------------------------------------
   12. Overlapping codings: popover
   Places with 2+ codings are grey (<mark class="ovl" data-cids="3 7 9">)
   and carry a number at the start (CSS ::before). Mouse over it -> after a
   short delay a popover shows all codings of this place (code, position,
   memo) with the buttons "Show" / "Delete".
   A click on the place pins the popover; a click next to it or Esc closes
   it.
   R delivers the details of every coding as JSON in the attribute
   data-codings of #doc (see .render_doc_html() in R/render.R).
   The popover hangs on <body>, i.e. outside #doc -- otherwise its text
   would distort the character offsets.
   -------------------------------------------------------------------------- */

var jqPop = null;          // the popover element (created once)
var jqPopShowTimer = null;
var jqPopHideTimer = null;

function jqEsc(s) {
  return String(s == null ? '' : s).replace(/[&<>"']/g, function(c) {
    return {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[c];
  });
}

function codingDetails() {
  // Note: the Shiny output area is itself called "doc" (output$doc) and
  // contains the rendered <div id="doc" data-codings=...>. Therefore look for
  // the element WITH the attribute, not getElementById('doc').
  var doc = document.querySelector('#doc[data-codings]');
  if (!doc) return {};
  try { return JSON.parse(doc.getAttribute('data-codings') || '{}'); } catch (e) { return {}; }
}

function hideOverlapPopover() {
  clearTimeout(jqPopShowTimer); clearTimeout(jqPopHideTimer);
  if (jqPop) { jqPop.style.display = 'none'; jqPop.dataset.pinned = ''; }
}

function showOverlapPopover(mark, pinned) {
  // stop running timers: a pending hover popover would otherwise "release"
  // one that was just pinned by a click
  clearTimeout(jqPopHideTimer); clearTimeout(jqPopShowTimer);
  if (!jqPop) {
    jqPop = document.createElement('div');
    jqPop.id = 'jq-popover';
    jqPop.setAttribute('role', 'dialog');
    document.body.appendChild(jqPop);
    // mouse inside the popover -> keep it open so the buttons can be reached
    jqPop.addEventListener('mouseenter', function() { clearTimeout(jqPopHideTimer); });
    jqPop.addEventListener('mouseleave', scheduleHideOverlapPopover);
  }
  // suppress the native tooltip (title), otherwise two windows appear
  if (mark.hasAttribute('title')) {
    mark.setAttribute('data-title', mark.getAttribute('title'));
    mark.removeAttribute('title');
  }
  var data = codingDetails();
  var ids = (mark.getAttribute('data-cids') || '').split(' ').filter(Boolean);
  var rows = ids.map(function(id) {
    var c = data[id];
    if (!c) return '';
    return '<div class="jqp-row">' +
      '<span class="swatch" style="background-color:' + jqEsc(c.color) + '"></span>' +
      '<div class="jqp-main"><div><b>' + jqEsc(c.label) + '</b> ' +
      '<span class="jqp-pos">' + jqF('Zeichen {0}–{1}', [c.start, c.end]) + '</span></div>' +
      '<div class="jqp-text">' + jqF('„{0}“', [jqEsc(c.text) + (c.end - c.start > 90 ? ' …' : '')]) + '</div>' +
      (c.memo ? '<div class="jqp-memo">Memo: ' + jqEsc(c.memo) + '</div>' : '') +
      '</div>' +
      '<div class="jqp-btns">' +
      '<button class="mini jqp-show" data-jqp-show="' + id + '" title="' + jqT('Details in der Leiste ueber dem Text') + '">' + jqT('Anzeigen') + '</button>' +
      '<button class="mini" data-delcoding="' + id + '" title="' + jqT('Dieses Coding loeschen (Strg+Z macht es rueckgaengig)') + '">' + jqT('Löschen') + '</button>' +
      '</div></div>';
  }).join('');
  jqPop.innerHTML = '<div class="jqp-head">' + jqF('{0} Codings an dieser Stelle', [ids.length]) +
    (pinned ? '<button class="jqp-close" title="' + jqT('Schliessen (Esc)') + '">×</button>' : '') + '</div>' + rows;
  jqPop.dataset.pinned = pinned ? '1' : '';
  jqPop.style.display = 'block';
  // position below the start of the place (where the number sits), within
  // the window
  var r = mark.getClientRects()[0] || mark.getBoundingClientRect();
  var w = jqPop.offsetWidth, h = jqPop.offsetHeight;
  var left = Math.min(r.left, window.innerWidth - w - 8);
  var top = r.bottom + 4;
  if (top + h > window.innerHeight - 8) top = Math.max(8, r.top - h - 4);   // otherwise above
  jqPop.style.left = Math.max(8, left) + 'px';
  jqPop.style.top = top + 'px';
}

function scheduleHideOverlapPopover() {
  clearTimeout(jqPopShowTimer);
  if (jqPop && jqPop.dataset.pinned) return;   // pinned: stays open
  jqPopHideTimer = setTimeout(hideOverlapPopover, 300);
}

// Mouse over a grey place -> popover after a short delay. Not while a
// selection is being made with the mouse button pressed.
$(document).on('mouseenter', '#doc mark.ovl', function(e) {
  if (e.buttons || hasTextSelection()) return;
  if (jqPop && jqPop.dataset.pinned) return;
  var mark = this;
  clearTimeout(jqPopShowTimer); clearTimeout(jqPopHideTimer);
  jqPopShowTimer = setTimeout(function() { showOverlapPopover(mark, false); }, 250);
});
$(document).on('mouseleave', '#doc mark.ovl', scheduleHideOverlapPopover);

// "Show" -> like a click on a single coding (bar above the text)
$(document).on('click', '[data-jqp-show]', function(e) {
  e.stopPropagation();
  Shiny.setInputValue('clicked_coding', parseInt($(this).attr('data-jqp-show'), 10), {priority: 'event'});
  hideOverlapPopover();
});
// "Delete" uses the existing [data-delcoding] handler (section 4); the
// document is re-rendered afterwards -> close the popover
$(document).on('click', '#jq-popover [data-delcoding]', function() { setTimeout(hideOverlapPopover, 0); });
$(document).on('click', '#jq-popover .jqp-close', hideOverlapPopover);

// a click outside or Esc closes it; so does scrolling in the document
$(document).on('mousedown', function(e) {
  if (jqPop && jqPop.style.display === 'block' && !jqPop.contains(e.target) &&
      !(e.target.closest && e.target.closest('#doc mark.ovl'))) hideOverlapPopover();
});
$(document).on('keydown', function(e) { if (e.key === 'Escape') hideOverlapPopover(); });
document.addEventListener('scroll', function(e) {
  if (jqPop && jqPop.style.display === 'block' && e.target.classList &&
      e.target.classList.contains('docarea')) hideOverlapPopover();
}, true);
// the document is re-rendered (e.g. after delete/undo) -> close the popover
$(document).on('shiny:value', function(e) { if (e.name === 'doc') hideOverlapPopover(); });


/* --------------------------------------------------------------------------
   13. Memo panel
   "+ Passage/Document/Code/Project"     -> input$new_memo {kind}
   form "Save"/"Cancel"                  -> input$memo_new_save {text, title}
   filter chips                          -> input$memo_filter
   click the reference of a card         -> input$memo_jump (key)
   memo icon in code tree / document     -> input$code_memo / input$doc_memo
   server -> jellyqdaMemoFocus {key}: open the panel, scroll to the card
   -------------------------------------------------------------------------- */

$(document).on('click', '[data-newmemo]', function(e) {
  e.stopPropagation();
  if (this.disabled) return;
  Shiny.setInputValue('new_memo', {kind: this.getAttribute('data-newmemo'), t: Date.now()}, {priority: 'event'});
});
$(document).on('click', '[data-memonew]', function(e) {
  e.stopPropagation();
  if (this.getAttribute('data-memonew') === 'cancel') {
    Shiny.setInputValue('memo_new_cancel', Date.now(), {priority: 'event'});
    return;
  }
  var t = document.getElementById('memo_new_text'), h = document.getElementById('memo_new_title');
  Shiny.setInputValue('memo_new_save', {text: t ? t.value : '', title: h ? h.value : '', t: Date.now()},
                      {priority: 'event'});
});
// Ctrl+Enter in the memo field = save
$(document).on('keydown', '#memo_new_text, #memo_new_title, .memocard.editing textarea', function(e) {
  if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
    e.preventDefault();
    var card = this.closest('.memocard');
    var btn = card && card.querySelector('[data-memonew="save"], [data-savememo]');
    if (btn) btn.click();
  }
});
$(document).on('click', '[data-memofilter]', function(e) {
  e.stopPropagation();
  Shiny.setInputValue('memo_filter', this.getAttribute('data-memofilter'), {priority: 'event'});
});
$(document).on('click', '[data-memojump]', function(e) {
  e.stopPropagation();
  Shiny.setInputValue('memo_jump', this.getAttribute('data-memojump'), {priority: 'event'});
});
$(document).on('click', '[data-codememo]', function(e) {
  e.stopPropagation();   // do not select the code as well
  Shiny.setInputValue('code_memo', parseInt(this.getAttribute('data-codememo'), 10), {priority: 'event'});
});
$(document).on('click', '[data-docmemo]', function(e) {
  e.stopPropagation();   // do not open the document as well
  Shiny.setInputValue('doc_memo', parseInt(this.getAttribute('data-docmemo'), 10), {priority: 'event'});
});
Shiny.addCustomMessageHandler('jellyqdaMemoFocus', function(msg) {
  var panel = document.getElementById('panel-memos');
  if (panel && panel.classList.contains('collapsed')) {
    panel.classList.remove('collapsed');
    if (window.jellyqdaSaveLayout) window.jellyqdaSaveLayout();
  }
  // wait until the server has re-rendered the panel
  setTimeout(function() {
    if (msg.key === 'new') {
      var t = document.getElementById('memo_new_text');
      if (t) { t.scrollIntoView({block: 'nearest'}); t.focus(); }
      return;
    }
    if (!msg.key) return;
    var c = document.querySelector('.memocard[data-memokey="' + msg.key + '"]');
    if (c) c.scrollIntoView({behavior: 'smooth', block: 'nearest'});
  }, 350);
});


/* --------------------------------------------------------------------------
   14. Icons
   The app loads NO Font Awesome font (fontawesome::fa() in R returns SVG).
   Server HTML with <i class="fa-solid fa-NAME"></i> would therefore be
   invisible (0x0 pixels). Here every such <i> is replaced by a copy of the
   matching SVG from the invisible icon registry #jq-icons -- on load and for
   everything Shiny re-renders later.
   -------------------------------------------------------------------------- */

function jqIcons(root) {
  if (!root || !root.querySelectorAll) return;
  var list = root.matches && root.matches('i.fa-solid') ? [root] : root.querySelectorAll('i.fa-solid');
  Array.prototype.forEach.call(list, function(i) {
    var name = null;
    i.classList.forEach(function(c) { if (c.indexOf('fa-') === 0 && c !== 'fa-solid') name = c.slice(3); });
    var src = name && document.querySelector('#jq-icons [data-faicon="' + name + '"] svg');
    if (!src) return;
    var svg = src.cloneNode(true);
    svg.classList.add('jq-ico');
    i.replaceWith(svg);
  });
}
$(function() {
  jqIcons(document.body);
  new MutationObserver(function(muts) {
    muts.forEach(function(m) { m.addedNodes.forEach(function(n) { if (n.nodeType === 1) jqIcons(n); }); });
  }).observe(document.body, {childList: true, subtree: true});
});


/* --------------------------------------------------------------------------
   15. Code tree (codes + subcodes) and coding bar
   The server renders tree and bar (R/app.R). Everything that only concerns
   the view happens here in the browser: expand/collapse (remembered in
   localStorage), filtering, input fields for "+ Code" / "+ Subcode" /
   renaming, the confirmation before deleting, the subcode row and the
   search of the coding bar. Only the result goes to the server:
     input$add_code {label, parent}   input$rename_code {id, label}
     input$del_code_id                 input$code_color {id, color}
     input$recode_coding               input$add_code_assign {label}
   -------------------------------------------------------------------------- */

// --- 15a. expand/collapse, remembered per browser -----------------------------
function jqCollapsed() {
  try { return JSON.parse(localStorage.getItem('jellyqda_codes_collapsed') || '[]'); }
  catch (e) { return []; }
}
function jqSetCollapsed(list) {
  try { localStorage.setItem('jellyqda_codes_collapsed', JSON.stringify(list)); } catch (e) {}
}
var jqSelCode = null;
function jqMarkSelCode(id) {
  jqSelCode = id;
  document.querySelectorAll('.ctree .coderow.sel').forEach(function(r) { r.classList.remove('sel'); });
  var r = document.querySelector('.ctree .coderow[data-selcode="' + id + '"]');
  if (r) r.classList.add('sel');
}
// apply the state again after every re-rendering of tree/matrix
function jqApplyTree() {
  var col = jqCollapsed();
  document.querySelectorAll('.ctree .cnode').forEach(function(li) {
    li.classList.toggle('collapsed', col.indexOf(parseInt(li.getAttribute('data-cnode'), 10)) >= 0);
  });
  document.querySelectorAll('tr[data-anc]').forEach(function(tr) {
    var anc = (tr.getAttribute('data-anc') || '').split(' ').filter(Boolean).map(Number);
    tr.hidden = anc.some(function(a) { return col.indexOf(a) >= 0; });
  });
  document.querySelectorAll('tr[data-mxrow]').forEach(function(tr) {
    tr.classList.toggle('mxcollapsed', col.indexOf(parseInt(tr.getAttribute('data-mxrow'), 10)) >= 0);
  });
  if (jqSelCode !== null) jqMarkSelCode(jqSelCode);
  jqFilterTree();
}
$(document).on('shiny:value', function(e) {
  if (e.name === 'code_tree' || e.name === 'matrix_panel' || e.name === 'sum_matrix') {
    setTimeout(jqApplyTree, 0);
  }
  if (e.name === 'actionbar') setTimeout(jqPickerReady, 0);
});
$(document).on('click', '[data-codetoggle]', function(e) {
  e.stopPropagation();
  var id = parseInt($(this).attr('data-codetoggle'), 10);
  var col = jqCollapsed(), i = col.indexOf(id);
  if (i >= 0) col.splice(i, 1); else col.push(id);
  jqSetCollapsed(col); jqApplyTree();
});
$(document).on('click', '[data-codeall]', function(e) {
  e.preventDefault();
  var ids = [];
  if ($(this).attr('data-codeall') === 'close') {
    document.querySelectorAll('.ctree .cnode').forEach(function(li) {
      if (li.querySelector(':scope > .cchildren')) ids.push(parseInt(li.getAttribute('data-cnode'), 10));
    });
  }
  jqSetCollapsed(ids); jqApplyTree();
});
// click on the Sigma of a code in the matrix = expand/collapse its subcodes
$(document).on('click', '.mx tr[data-mxrow] .jq-sub', function(e) {
  e.stopPropagation();
  var id = parseInt(this.closest('tr').getAttribute('data-mxrow'), 10);
  var col = jqCollapsed(), i = col.indexOf(id);
  if (i >= 0) col.splice(i, 1); else col.push(id);
  jqSetCollapsed(col); jqApplyTree();
});

// --- 15b. Filter -----------------------------------------------------------
function jqFilterTree() {
  var f = document.getElementById('code_filter');
  var q = f ? f.value.trim().toLowerCase() : '';
  document.querySelectorAll('.ctree .cnode').forEach(function(li) {
    if (!q) { li.classList.remove('nomatch', 'filteropen'); return; }
    var hit = Array.from(li.querySelectorAll('.coderow')).some(function(r) {
      return (r.getAttribute('data-label') || '').toLowerCase().indexOf(q) >= 0;
    });
    li.classList.toggle('nomatch', !hit);
    li.classList.toggle('filteropen', hit);
  });
}
$(document).on('input', '#code_filter', jqFilterTree);

// --- 15c. + Code / + Subcode: input field directly in the tree ---------------
function jqAddInput(container, parent, placeholder) {
  document.querySelectorAll('.ctree .cadd').forEach(function(el) { el.remove(); });
  var li = document.createElement('li');
  li.className = 'cnode cadd';
  li.innerHTML = '<input type="text" class="form-control form-control-sm" aria-label="Name">';
  var inp = li.querySelector('input');
  inp.placeholder = placeholder;
  container.appendChild(li);
  inp.focus();
  inp.addEventListener('keydown', function(e) {
    if (e.key === 'Enter' && inp.value.trim()) {
      e.preventDefault();
      Shiny.setInputValue('add_code', {label: inp.value.trim(), parent: parent, t: Date.now()}, {priority: 'event'});
      li.remove();
    } else if (e.key === 'Escape') { li.remove(); }
  });
  inp.addEventListener('blur', function() { setTimeout(function() { if (li.isConnected && !inp.value.trim()) li.remove(); }, 150); });
}
$(document).on('click', '[data-addroot]', function(e) {
  e.preventDefault(); e.stopPropagation();
  var p = document.getElementById('panel-codes');
  if (p && p.classList.contains('collapsed')) p.classList.remove('collapsed');
  var ul = document.querySelector('.ctree');
  if (!ul) return;
  var empty = document.querySelector('.ctree-empty'); if (empty) empty.hidden = true;
  jqAddInput(ul, null, jqT('Neuer Code – Enter'));
});
$(document).on('click', '[data-addsub]', function(e) {
  e.stopPropagation();
  var id = parseInt($(this).attr('data-addsub'), 10);
  var li = document.querySelector('.ctree .cnode[data-cnode="' + id + '"]');
  if (!li) return;
  var col = jqCollapsed(), i = col.indexOf(id);
  if (i >= 0) { col.splice(i, 1); jqSetCollapsed(col); jqApplyTree(); }
  var ul = li.querySelector(':scope > .cchildren');
  if (!ul) { ul = document.createElement('ul'); ul.className = 'cchildren'; li.appendChild(ul); }
  var lab = li.querySelector(':scope > .coderow').getAttribute('data-label');
  jqAddInput(ul, id, jqF('Neuer Subcode unter „{0}“ – Enter', [lab]));
});

// --- 15d. Rename: double click, pen icon or F2 --------------------------------
function jqRename(row) {
  if (!row || row.querySelector('.crename')) return;
  var span = row.querySelector('.codelabel');
  var id = parseInt(row.getAttribute('data-codeid'), 10);
  var old = row.getAttribute('data-label');
  var inp = document.createElement('input');
  inp.type = 'text'; inp.className = 'crename'; inp.value = old;
  inp.setAttribute('aria-label', jqF('Neuer Name für {0}', [old]));
  span.replaceWith(inp);
  row.draggable = false;
  inp.focus(); inp.select();
  var done = false;
  function finish(save) {
    if (done) return; done = true;
    var v = inp.value.trim();
    inp.replaceWith(span); row.draggable = true;
    if (save && v && v !== old) {
      span.textContent = v;
      Shiny.setInputValue('rename_code', {id: id, label: v, t: Date.now()}, {priority: 'event'});
    }
  }
  inp.addEventListener('keydown', function(e) {
    e.stopPropagation();
    if (e.key === 'Enter') { e.preventDefault(); finish(true); }
    else if (e.key === 'Escape') { e.preventDefault(); finish(false); }
  });
  inp.addEventListener('blur', function() { finish(true); });
  inp.addEventListener('click', function(e) { e.stopPropagation(); });
  inp.addEventListener('dblclick', function(e) { e.stopPropagation(); });
}
$(document).on('dblclick', '.ctree .coderow', function(e) {
  if (e.target.closest('.cacts, .cchev, .colordot, input')) return;
  e.preventDefault();
  if (window.getSelection) window.getSelection().removeAllRanges();
  jqRename(this);
});
$(document).on('click', '[data-renamecode]', function(e) {
  e.stopPropagation();
  jqRename(this.closest('.coderow'));
});
$(document).on('keydown', function(e) {
  if (e.key !== 'F2') return;
  var t = ((e.target && e.target.tagName) || '').toLowerCase();
  if (t === 'input' || t === 'textarea') return;
  var row = document.querySelector('.ctree .coderow.sel');
  if (row) { e.preventDefault(); jqRename(row); }
});

// --- 15e. Delete with confirmation (names subcodes and codings) --------------
$(document).on('click', '[data-delcode]', function(e) {
  e.stopPropagation();
  var row = this.closest('.coderow');
  if (!row) return;
  document.querySelectorAll('.ctree .cconfirm').forEach(function(el) { el.remove(); });
  var id = parseInt(row.getAttribute('data-codeid'), 10);
  var nsub = parseInt(row.getAttribute('data-nsub') || '0', 10);
  var ncod = parseInt(row.getAttribute('data-ncod') || '0', 10);
  var box = document.createElement('div');
  box.className = 'cconfirm';
  box.innerHTML = '<span></span><div class="btns">' +
    '<button class="btn btn-sm btn-outline-secondary" data-cno="1">' + jqT('Abbrechen') + '</button>' +
    '<button class="btn btn-sm btn-danger" data-cyes="1">' + jqT('Löschen') + '</button></div>';
  box.querySelector('span').innerHTML = jqF('„{0}“{1} und {2} löschen?', [
    '<b>' + jqEsc(row.getAttribute('data-label')) + '</b>',
    nsub ? jqF(nsub === 1 ? ' mit {0} Subcode' : ' mit {0} Subcodes', [nsub]) : '',
    jqF(ncod === 1 ? '{0} Coding' : '{0} Codings', [ncod])]);
  row.insertAdjacentElement('afterend', box);
  box.querySelector('[data-cno]').addEventListener('click', function(ev) { ev.stopPropagation(); box.remove(); });
  box.querySelector('[data-cyes]').addEventListener('click', function(ev) {
    ev.stopPropagation(); box.remove();
    Shiny.setInputValue('del_code_id', id, {priority: 'event'});
  });
  box.querySelector('[data-cyes]').focus();
});

// --- 15f. Colour of the code family --------------------------------------------
$(document).on('click', '.colordot', function(e) { e.stopPropagation(); });
$(document).on('change', 'input[data-codecolor]', function() {
  Shiny.setInputValue('code_color', {id: parseInt($(this).attr('data-codecolor'), 10), color: this.value},
                      {priority: 'event'});
});

// --- 15g. Coding bar: unfold subcodes, search, definition, keys -----------
function jqOpenRoot(id) {
  document.querySelectorAll('.actionbar .subline').forEach(function(d) {
    d.hidden = String(id) !== d.getAttribute('data-subfor');
  });
  document.querySelectorAll('.actionbar .rootchip[data-openroot]').forEach(function(b) {
    b.classList.toggle('open', String(id) === b.getAttribute('data-openroot'));
  });
}
$(document).on('click', '.actionbar [data-openroot]', function(e) {
  e.preventDefault();
  var id = $(this).attr('data-openroot');
  jqOpenRoot(this.classList.contains('open') ? null : id);
});
function jqPickerReady() {
  var bar = document.querySelector('.actionbar');
  if (!bar) return;
  jqIcons(bar);
}
function jqSearch(q) {
  var bar = document.querySelector('.actionbar');
  if (!bar) return;
  q = (q || '').trim().toLowerCase();
  var res = bar.querySelector('.pk-results');
  var roots = bar.querySelector('.pk-roots');
  if (!q) {
    res.hidden = true; roots.hidden = false;
    var open = bar.querySelector('.rootchip.open');
    jqOpenRoot(open ? open.getAttribute('data-openroot') : null);
    return;
  }
  roots.hidden = true;
  bar.querySelectorAll('.subline').forEach(function(d) { d.hidden = true; });
  var n = 0;
  res.querySelectorAll('.codebtn').forEach(function(b) {
    var hit = (b.getAttribute('data-path') || '').indexOf(q) >= 0;
    b.hidden = !hit; if (hit) n++;
  });
  res.querySelector('.pk-none').hidden = n > 0;
  res.hidden = false;
}
$(document).on('input', '#code_search', function() { jqSearch(this.value); });
$(document).on('keydown', '#code_search', function(e) {
  if (e.key === 'Escape') { this.value = ''; jqSearch(''); return; }
  if (e.key !== 'Enter') return;
  e.preventDefault();
  var first = document.querySelector('.actionbar .pk-results .codebtn:not([hidden])');
  if (first) { first.click(); return; }
  var v = this.value.trim();
  if (v) Shiny.setInputValue('add_code_assign', {label: v, t: Date.now()}, {priority: 'event'});
});
// definition (description or code memo) when hovering over a code
$(document).on('mouseenter focus', '.actionbar [data-def]', function() {
  var box = document.getElementById('pk_def');
  if (!box) return;
  var d = this.getAttribute('data-def') || '';
  var path = (this.getAttribute('title') || '').split(' – ')[0];
  box.innerHTML = '<b>' + jqT('Definition') + '</b> ' + jqEsc(path) + ': ' +
    (d ? jqEsc(d) : '<i>' + jqT('noch keine – im Memo-Panel ein Code-Memo anlegen') + '</i>');
});
// without Ctrl: 0 = only the code, 1..9 = subcode of the unfolded family
$(document).on('keydown', function(e) {
  if (e.ctrlKey || e.metaKey || e.altKey) return;
  var t = ((e.target && e.target.tagName) || '').toLowerCase();
  if (t === 'input' || t === 'textarea' || t === 'select') return;
  var line = document.querySelector('.actionbar .subline:not([hidden])');
  if (!line) return;
  if (e.key === 'Escape') { jqOpenRoot(null); return; }
  if (e.key >= '0' && e.key <= '9') {
    var b = e.key === '0' ? line.querySelector('.codebtn.self')
                          : line.querySelectorAll('.codebtn.sub')[parseInt(e.key, 10) - 1];
    if (b) { e.preventDefault(); b.click(); }
  }
});

// --- 15h. Re-code (bar of a clicked coding) ----------------------------------
$(document).on('click', '[data-recode]', function(e) {
  e.stopPropagation();
  if (this.classList.contains('cur')) return;
  Shiny.setInputValue('recode_coding', parseInt($(this).attr('data-recode'), 10), {priority: 'event'});
});

// --- 15j. "Undo" in a notification, export menu ----------------------------
$(document).on('click', '[data-undonow]', function(e) {
  e.preventDefault();
  $('#undo_btn').click();
  var n = this.closest('.shiny-notification');
  if (n) n.remove();
});
// export menu (<details>): close after a choice or a click next to it
$(document).on('click', '.jq-menu-list button', function() {
  var d = this.closest('details'); if (d) d.open = false;
});
$(document).on('click', function(e) {
  document.querySelectorAll('details.jq-menu[open]').forEach(function(d) {
    if (!d.contains(e.target)) d.open = false;
  });
});


/* --------------------------------------------------------------------------
   16. Analyse-Werkzeuge (ab 0.6.0)
   -------------------------------------------------------------------------- */

// --- 16a. Coding bar: save comment, paraphrase, generalisation ------------
function jqSaveCodingFields(id) {
  function v(i) { var el = document.getElementById(i); return el ? el.value : ''; }
  Shiny.setInputValue('save_coding_fields',
    {id: id, memo: v('cb_comment'), paraphrase: v('cb_para'), generalization: v('cb_gen'), t: Date.now()},
    {priority: 'event'});
}
$(document).on('click', '[data-savecoding]', function(e) {
  e.preventDefault(); jqSaveCodingFields(parseInt($(this).attr('data-savecoding'), 10));
});
$(document).on('keydown', '.cbfields input', function(e) {
  if (e.key === 'Enter') {
    e.preventDefault();
    jqSaveCodingFields(parseInt(this.closest('.cbfields').getAttribute('data-cbid'), 10));
  }
});
$(document).on('click', '[data-anchorfrom]', function(e) {
  e.preventDefault();
  Shiny.setInputValue('anchor_from_coding', parseInt($(this).attr('data-anchorfrom'), 10), {priority: 'event'});
});

// --- 16b. In vivo: the marked text becomes a code ----------------------------
$(document).on('click', '[data-invivo]', function(e) {
  e.preventDefault();
  Shiny.setInputValue('invivo', Date.now(), {priority: 'event'});
});

// --- 16c. Code all search hits -------------------------------------------
$(document).on('click', '[data-autocode]', function(e) {
  e.preventDefault();
  var c = document.getElementById('autocode_code'), sc = document.getElementById('autocode_scope');
  if (!c) return;
  Shiny.setInputValue('autocode', {code: parseInt(c.value, 10), scope: sc ? sc.value : 'match', t: Date.now()},
                      {priority: 'event'});
});

// --- 16d. Coding guideline (dialog) ----------------------------------------
$(document).on('click', '[data-guidecode]', function(e) {
  e.stopPropagation();
  Shiny.setInputValue('guide_code', parseInt($(this).attr('data-guidecode'), 10), {priority: 'event'});
});
$(document).on('click', '[data-guidesave]', function(e) {
  e.preventDefault();
  function v(i) { var el = document.getElementById(i); return el ? el.value : ''; }
  Shiny.setInputValue('guide_save', {id: parseInt($(this).attr('data-guidesave'), 10),
    def: v('guide_def'), anchor: v('guide_anchor'), rule: v('guide_rule'), t: Date.now()}, {priority: 'event'});
});

// --- 16e. Merge codes: selection directly below the row ---------------------
$(document).on('click', '[data-mergecode]', function(e) {
  e.stopPropagation();
  var row = this.closest('.coderow');
  var li = row.closest('.cnode');
  document.querySelectorAll('.ctree .cconfirm').forEach(function(el) { el.remove(); });
  var from = parseInt(row.getAttribute('data-codeid'), 10);
  // target: any other code except its own subcodes
  var own = Array.from(li.querySelectorAll('.coderow')).map(function(r) { return r.getAttribute('data-codeid'); });
  var opts = Array.from(document.querySelectorAll('.ctree .coderow')).filter(function(r) {
    return own.indexOf(r.getAttribute('data-codeid')) < 0;
  }).map(function(r) {
    return '<option value="' + r.getAttribute('data-codeid') + '">' + jqEsc(r.getAttribute('data-path') || r.getAttribute('data-label')) + '</option>';
  }).join('');
  var box = document.createElement('div');
  box.className = 'cconfirm cmerge';
  box.innerHTML = '<span></span>' +
    (opts ? '<select class="form-select form-select-sm" aria-label="' + jqT('Ziel-Code') + '">' + opts + '</select>' : '<span class="jq-sub">' + jqT('Kein anderer Code vorhanden.') + '</span>') +
    '<span class="jq-sub">' + jqT('Alle Codings, Subcodes, Code-Memos und der Kodierleitfaden wandern mit. Strg+Z macht es rückgängig.') + '</span>' +
    '<div class="btns"><button class="btn btn-sm btn-outline-secondary" data-cno="1">' + jqT('Abbrechen') + '</button>' +
    (opts ? '<button class="btn btn-sm btn-primary" data-cyes="1">' + jqT('Zusammenführen') + '</button>' : '') + '</div>';
  box.querySelector('span').innerHTML = jqF('„{0}“ zusammenführen mit:', ['<b>' + jqEsc(row.getAttribute('data-label')) + '</b>']);
  row.insertAdjacentElement('afterend', box);
  box.addEventListener('click', function(ev) { ev.stopPropagation(); });
  box.querySelector('[data-cno]').addEventListener('click', function() { box.remove(); });
  var yes = box.querySelector('[data-cyes]');
  if (yes) yes.addEventListener('click', function() {
    var into = parseInt(box.querySelector('select').value, 10);
    box.remove();
    Shiny.setInputValue('merge_code', {from: from, into: into, t: Date.now()}, {priority: 'event'});
  });
});

// --- 16f. Code matrix: columns = documents or a variable (case comparison) ---
$(document).on('change', '#mx_by', function() {
  Shiny.setInputValue('mx_by', this.value, {priority: 'event'});
});

// --- 16g. Analysis window ----------------------------------------------------
$(document).on('click', '[data-kwicword]', function(e) {
  e.preventDefault();
  Shiny.setInputValue('kwic_word', $(this).attr('data-kwicword'), {priority: 'event'});
});
$(document).on('click', 'tr[data-kwicsrc]', function() {
  Shiny.setInputValue('kwic_goto', {src: parseInt(this.getAttribute('data-kwicsrc'), 10),
    pos: parseInt(this.getAttribute('data-kwicpos'), 10), t: Date.now()}, {priority: 'event'});
});
// Mayring table: save when leaving a field
$(document).on('change', 'textarea[data-mayid]', function() {
  var ta = this;
  Shiny.setInputValue('mayring_save', {id: parseInt(ta.getAttribute('data-mayid'), 10),
    field: ta.getAttribute('data-mayfield'), value: ta.value, t: Date.now()}, {priority: 'event'});
  ta.classList.add('saved');
  setTimeout(function() { ta.classList.remove('saved'); }, 1200);
});


/* --------------------------------------------------------------------------
   17. Language (EN/DE)
   The EN/DE button links to "?lang=xx"; the choice is remembered in the
   browser and applied again when the app is opened without "?lang=".
   -------------------------------------------------------------------------- */
$(document).on('click', '[data-setlang]', function() {
  try { localStorage.setItem('jellyqda_lang', this.getAttribute('data-setlang')); } catch (e) {}
});
(function() {
  try {
    var want = localStorage.getItem('jellyqda_lang');
    var has = /[?&]lang=/.test(window.location.search);
    if (want && !has && want !== window.jqLang) {
      window.location.replace(window.location.pathname + '?lang=' + want);
    }
  } catch (e) {}
})();
