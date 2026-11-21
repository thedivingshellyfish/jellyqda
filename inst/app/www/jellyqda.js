/* ==========================================================================
   jellyqda.js -- Browser-Logik der Shiny-App qda_app()

   Wird in R/app.R ueber .jellyqda_assets() als htmlDependency im <head>
   eingebunden (Quelle: inst/app/www/ im installierten Paket). jQuery und
   Shiny sind zu diesem Zeitpunkt schon geladen.

   Grundprinzip: Der Browser macht fast nichts selbst. Jede Aktion wird mit
     Shiny.setInputValue('<name>', wert, {priority: 'event'})
   an den Server geschickt und dort in R/app.R in .jellyqda_server() mit
     shiny::observeEvent(input$<name>, { ... })
   verarbeitet. 'priority: event' sorgt dafuer, dass auch zweimal derselbe
   Wert (z.B. zweimal derselbe Code-Button) als neues Ereignis zaehlt.

   Alle Klicks sind "delegiert" ($(document).on('click', selector, ...)),
   damit sie auch fuer HTML funktionieren, das Shiny spaeter per renderUI neu
   zeichnet.

   Aufbau:
     1.  Hilfsfunktionen
     2.  Textauswahl im Dokument -> Zeichen-Offsets       (input$selection)
     3.  Klicks im Dokument: Codings und Segment-Badges
     4.  Klicks in Listen: Dokumente, Codes, Codings, Suche
     5.  Memos
     6.  Tastenkuerzel (inkl. Strg+Z / Strg+Y)
     7.  Drag & Drop: Codes umhaengen
     8.  Darstellung: Panels, Dark Mode, Zoom, Hilfe, Beenden
     9.  Tabellen: Code-Matrix und Summary Grid
     10. Nachrichten vom Server (sendCustomMessage)
     11. Beim Laden der Seite: Layout, Datei-Drop, Spalten-Griffe
     12. Ueberlappende Codings: Popover mit allen Codings einer Stelle
     13. Memo-Panel: neue Memos, Filter, Springen, Fokus
     14. Icons: <i class="fa-solid fa-NAME"> -> SVG aus dem Icon-Verzeichnis
   ========================================================================== */


/* --------------------------------------------------------------------------
   1. Hilfsfunktionen
   -------------------------------------------------------------------------- */

// Absoluter 0-basierter Zeichen-Offset der Position (node, offset) innerhalb
// von #doc. Trick: eine Range vom Anfang von #doc bis zur Position bauen und
// deren Textlaenge messen. Funktioniert, weil #doc exakt den eingefrorenen
// Text enthaelt (Segment-Badges sind CSS-Pseudo-Elemente, kein DOM-Text).
function absOffset(doc, node, offset) {
  try {
    var r = document.createRange();
    r.selectNodeContents(doc);
    r.setEnd(node, offset);
    return r.toString().length;
  } catch (e) { return null; }
}

// true, wenn gerade Text markiert ist (z.B. direkt nach einer Maus-Auswahl).
// Dann darf ein nachfolgendes 'click'-Event nichts ausloesen, sonst wuerde die
// Auswahl ueberschrieben (siehe Abschnitt 3).
function hasTextSelection() {
  var s = window.getSelection();
  return !!(s && !s.isCollapsed && s.toString().length > 0);
}

// Zu einer Zeichenposition in #doc scrollen: Textknoten der Reihe nach
// durchlaufen, bis die Position erreicht ist.
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


/* --------------------------------------------------------------------------
   2. Textauswahl im Dokument -> Zeichen-Offsets
   Nach dem Loslassen der Maus wird die Auswahl als 1-basierte, inklusive
   Offsets {start, end, text} an input$selection geschickt. Der Server zeigt
   daraufhin die Aktionsleiste ("Markiert: Zeichen X-Y" + Code-Buttons).
   Leere Auswahl (einfacher Klick) -> input$selection = null -> Leiste weg,
   stattdessen wird die Cursorposition als input$caret geschickt (fuer die
   Segment-Leiste: "Hier teilen", "Zusammenfuehren").
   -------------------------------------------------------------------------- */

$(document).on('mouseup', function(e) {
  var doc = document.getElementById('doc');
  if (!doc || !doc.contains(e.target)) return;   // nur Mausaktionen im Dokument
  var sel = window.getSelection();
  if (!sel || sel.isCollapsed) {
    Shiny.setInputValue('selection', null);
    // Cursorposition (0-basiert = Anzahl Zeichen vor dem Cursor)
    if (sel && sel.rangeCount > 0) {
      var c = absOffset(doc, sel.anchorNode, sel.anchorOffset);
      if (c !== null) Shiny.setInputValue('caret', {pos: c, t: Date.now()}, {priority: 'event'});
    }
    return;
  }
  // anchor = wo die Auswahl begann, focus = wo sie endet (kann davor liegen,
  // wenn rueckwaerts markiert wurde) -> min/max
  var a = absOffset(doc, sel.anchorNode, sel.anchorOffset);
  var f = absOffset(doc, sel.focusNode, sel.focusOffset);
  if (a === null || f === null) return;
  var s0 = Math.min(a, f), e0 = Math.max(a, f);
  Shiny.setInputValue('selection',
    {start: s0 + 1, end: e0, text: sel.toString()}, {priority: 'event'});
});


/* --------------------------------------------------------------------------
   3. Klicks im Dokument
   -------------------------------------------------------------------------- */

// Klick auf ein bestehendes Coding (<mark>) -> Details + Loeschen-Button
// (input$clicked_coding). stopPropagation, damit nicht zusaetzlich der
// Segment-Klick darunter ausgeloest wird.
$(document).on('click', '#doc mark', function(e) {
  if (hasTextSelection()) { e.stopPropagation(); return; }   // war eine Auswahl
  // unterstrichene Textstelle (Textstellen-Memo): Memo im Panel zeigen. KEIN
  // stopPropagation -- liegt darunter ein Coding, wird es ebenfalls angezeigt.
  if (this.classList.contains('memomark')) {
    Shiny.setInputValue('clicked_memo', parseInt(this.getAttribute('data-mid'), 10), {priority: 'event'});
    return;
  }
  e.stopPropagation();
  // grauer Ueberlappungs-Bereich: Popover mit allen Codings festheften
  if (this.classList.contains('ovl')) { showOverlapPopover(this, true); return; }
  Shiny.setInputValue('clicked_coding', parseInt($(this).attr('data-cid')), {priority: 'event'});
});

// Klick auf das "Seg N"-Badge -> ganzen Absatz markieren (input$seg_click).
//
// BUGFIX: Nach einer Maus-Auswahl innerhalb eines Absatzes feuert der Browser
// zusaetzlich ein 'click' auf das .segtext-div. Frueher hat das die genaue
// Auswahl mit dem ganzen Segment ueberschrieben, sodass immer der ganze
// Absatz codiert wurde. Jetzt zaehlt nur ein echter Klick (keine Auswahl)
// im linken Innenabstand, in dem das Badge sitzt.
$(document).on('click', '.segtext', function(e) {
  if (e.target.closest('mark')) return;
  if (hasTextSelection()) return;
  var pad = parseFloat(getComputedStyle(this).paddingLeft) || 0;
  if (e.clientX - this.getBoundingClientRect().left > pad) return;
  Shiny.setInputValue('seg_click', parseInt($(this).attr('data-seg'), 10), {priority: 'event'});
});

// Segment-Aktionen: Segment-Leiste (Hier teilen / Zusammenfuehren / x) und
// "Als Segment" in der Aktionsleiste -> input$seg_action {act: ...}
$(document).on('click', '[data-segact]', function(e) {
  e.stopPropagation();
  Shiny.setInputValue('seg_action', {act: $(this).attr('data-segact'), t: Date.now()}, {priority: 'event'});
});

// Code-Button in der Aktionsleiste -> markierten Text mit diesem Code codieren
$(document).on('click', '.codebtn', function() {
  Shiny.setInputValue('assign_code', parseInt($(this).attr('data-codeid')), {priority: 'event'});
});


/* --------------------------------------------------------------------------
   4. Klicks in Listen (Dokumente, Codes, Codings, Variablen, Suche)
   Die Daten stehen als data-*-Attribute im HTML, das R erzeugt.
   -------------------------------------------------------------------------- */

// Dokument oeffnen (data-src = source id)
$(document).on('click', '[data-src]', function() {
  Shiny.setInputValue('open_source', parseInt($(this).attr('data-src')), {priority: 'event'});
});
// ... und als "zuletzt geoeffnet" merken (wird beim naechsten Start wieder geoeffnet)
$(document).on('click', '[data-src]', function() {
  try { localStorage.setItem('jellyqda_last_src', $(this).attr('data-src')); } catch (err) {}
});

// Code im Code-Baum auswaehlen -> zugehoerige Segmente anzeigen
$(document).on('click', '[data-selcode]', function() {
  Shiny.setInputValue('sel_code', parseInt($(this).attr('data-selcode')), {priority: 'event'});
});

// Code loeschen (Del-Button im Code-Baum)
$(document).on('click', '[data-delcode]', function(e) {
  e.stopPropagation();
  Shiny.setInputValue('del_code_id', parseInt($(this).attr('data-delcode')), {priority: 'event'});
});

// Coding loeschen (aus einer Liste)
$(document).on('click', '[data-delcoding]', function(e) {
  e.stopPropagation();
  Shiny.setInputValue('del_coding', parseInt($(this).attr('data-delcoding')), {priority: 'event'});
});

// Coding in der Liste anklicken -> im Dokument-Browser dorthin springen
$(document).on('click', '[data-goto]', function(e) {
  Shiny.setInputValue('goto_coding', parseInt($(this).attr('data-goto')), {priority: 'event'});
});

// Dokument-Variable loeschen; Wert = "<source id>|<variablenname>"
$(document).on('click', '[data-delvar]', function(e) {
  e.stopPropagation();
  Shiny.setInputValue('del_var',
    $(this).attr('data-varsrc') + '|' + $(this).attr('data-varkey'), {priority: 'event'});
});

// Suchtreffer -> Dokument oeffnen und zur Position springen
$(document).on('click', '[data-gotopos]', function(e) {
  Shiny.setInputValue('goto_pos', {
    src: parseInt($(this).attr('data-src'), 10),
    pos: parseInt($(this).attr('data-pos'), 10)
  }, {priority: 'event'});
});


/* --------------------------------------------------------------------------
   5. Memos (Grundfunktionen; das Memo-Panel selbst: Abschnitt 13)
   -------------------------------------------------------------------------- */

// "Memo speichern" in der Aktionsleiste (markierter Text -> Textstellen-Memo)
$(document).on('click', '#memo_only_btn', function() {
  Shiny.setInputValue('add_memo_only', Date.now(), {priority: 'event'});
});

// Memo loeschen / Kommentar an einem Coding entfernen
$(document).on('click', '[data-delmemo]', function(e) {
  e.stopPropagation();
  Shiny.setInputValue('del_memo', parseInt($(this).attr('data-delmemo')), {priority: 'event'});
});
$(document).on('click', '[data-delcomment]', function(e) {
  e.stopPropagation();
  Shiny.setInputValue('del_comment', parseInt($(this).attr('data-delcomment')), {priority: 'event'});
});

// Bearbeiten / Speichern / Abbrechen. Beim Speichern werden Text und Titel
// direkt aus den Feldern mitgeschickt: Shiny uebertraegt Eingaben in
// Textfeldern verzoegert, sonst koennten die zuletzt getippten Zeichen fehlen.
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
   6. Tastenkuerzel
   Strg+1..9 = n-ter Code-Button der Aktionsleiste
   Strg+M    = Memo speichern
   Strg+Z    = Rueckgaengig
   Strg+Y    = Wiederholen (auch Strg+Umschalt+Z)
   (auf dem Mac jeweils Cmd statt Strg). In Eingabefeldern deaktiviert --
   dort gilt das normale Rueckgaengig des Browsers fuer den Text im Feld.
   -------------------------------------------------------------------------- */

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
  } else if ((e.key === 'z' || e.key === 'Z') && !e.shiftKey) {
    e.preventDefault(); $('#undo_btn').click();
  } else if (e.key === 'y' || e.key === 'Y' || ((e.key === 'z' || e.key === 'Z') && e.shiftKey)) {
    e.preventDefault(); $('#redo_btn').click();
  }
});


/* --------------------------------------------------------------------------
   7. Drag & Drop: Codes im Code-Baum umhaengen (neuer Parent)
   -------------------------------------------------------------------------- */

var dragCode = null;   // id des gerade gezogenen Codes
$(document).on('dragstart', '.coderow', function(e) {
  dragCode = parseInt($(this).attr('data-codeid'), 10);
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
   8. Darstellung: Panels ein-/ausklappen, Dark Mode, Zoom, Hilfe, Beenden
   Einstellungen werden im localStorage des Browsers gemerkt.
   -------------------------------------------------------------------------- */

// Panel ein-/ausklappen (Symbolleiste oder Chevron in der Panel-Kopfzeile)
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

// Schriftgroesse im Dokument-Browser (A-/A+): ueber die CSS-Variable --jqzoom,
// damit sie auch nach jedem Neuzeichnen des Dokuments erhalten bleibt.
function applyZoom(z) {
  z = Math.min(1.6, Math.max(0.7, z));   // Grenzen: 70 % bis 160 %
  document.documentElement.style.setProperty('--jqzoom', z);
  try { localStorage.setItem('jellyqda_zoom', String(z)); } catch (err) {}
}
$(document).on('click', '[data-zoom]', function(e) {
  e.preventDefault();
  var cur = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--jqzoom')) || 1;
  applyZoom(cur + parseFloat($(this).attr('data-zoom')));
});

// Hilfe-Dialog (wird vom Server als modalDialog angezeigt)
$(document).on('click', '[data-help]', function(e) {
  e.preventDefault();
  Shiny.setInputValue('help_btn', Date.now(), {priority: 'event'});
});

// App beenden (Server exportiert, macht ein Backup und stoppt)
$(document).on('click', '[data-closeapp]', function(e) {
  if (confirm('jellyqda beenden? Arbeit wird gespeichert (Export + Backup).')) {
    Shiny.setInputValue('close_app', Date.now(), {priority: 'event'});
  }
});


/* --------------------------------------------------------------------------
   9. Tabellen: Zelle anklicken -> Segmente fuer (Code x Dokument) anzeigen
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

// Rueckgaengig/Wiederholen: Tooltip zeigt, was passieren wuerde; ohne
// Eintrag wird der Button ausgegraut. msg = {undo: Text|null, redo: Text|null}
Shiny.addCustomMessageHandler('jellyqdaHistory', function(msg) {
  function set(id, label, text, key) {
    var b = document.getElementById(id);
    if (!b) return;
    b.title = text ? label + ': ' + text + ' (' + key + ')' : 'Nichts zum ' + label + ' (' + key + ')';
    b.classList.toggle('jq-disabled', !text);
  }
  set('undo_btn', 'R\u00fcckg\u00e4ngig', msg.undo, 'Strg+Z');
  set('redo_btn', 'Wiederholen', msg.redo, 'Strg+Y');
});

// Zu einem Coding (msg.cid) oder einer Zeichenposition (msg.pos) scrollen.
// Kurz warten, weil das Dokument vom Server gerade erst neu gezeichnet wird.
Shiny.addCustomMessageHandler('jellyqdaScroll', function(msg) {
  setTimeout(function() {
    var doc = document.getElementById('doc');
    if (doc && msg.pos != null) { scrollToChar(doc, msg.pos); return; }
    if (msg.mid != null) {   // Textstellen-Memo
      var mm = document.querySelector('#doc mark[data-mid="' + msg.mid + '"]');
      if (mm) mm.scrollIntoView({behavior: 'smooth', block: 'center'});
      return;
    }
    // das Coding kann auch nur Teil einer Ueberlappung sein (data-cids)
    var m = document.querySelector('#doc mark[data-cid="' + msg.cid + '"], ' +
                                   '#doc mark[data-cids~="' + msg.cid + '"]');
    if (m) {
      m.scrollIntoView({behavior: 'smooth', block: 'center'});
      m.style.outline = '3px solid #2c6fbb';                       // kurz hervorheben
      setTimeout(function() { m.style.outline = ''; }, 2500);
    }
  }, 250);
});


/* --------------------------------------------------------------------------
   11. Beim Laden der Seite (sobald das HTML vollstaendig da ist)
   -------------------------------------------------------------------------- */

$(function() {
  var grid = document.querySelector('.appgrid');

  // ---- 11a. Layout speichern / wiederherstellen ---------------------------
  // Gemerkt werden: Spaltenbreiten, welches Panel in welcher Spalte liegt,
  // und welche Panels eingeklappt sind.
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

  // ---- 11b. Zoom, Dark Mode und zuletzt geoeffnetes Dokument wiederherstellen
  try {
    var z = parseFloat(localStorage.getItem('jellyqda_zoom'));
    if (z) document.documentElement.style.setProperty('--jqzoom', z);
    if (localStorage.getItem('jellyqda_dark') === '1') {
      document.documentElement.setAttribute('data-bs-theme', 'dark');
    }
    var last = parseInt(localStorage.getItem('jellyqda_last_src'), 10);
    if (last) Shiny.setInputValue('open_source', last);
  } catch (e2) {}

  // ---- 11c. Panels an der Kopfzeile in eine andere Spalte ziehen -----------
  // Das Panel wird an der Mausposition eingefuegt (vor dem Panel, ueber
  // dessen oberer Haelfte losgelassen wird).
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
    // Dokument-Browser und Segmente bleiben immer in der mittleren Spalte,
    // damit man sie nicht versehentlich mit einer Seitenspalte wegklappt.
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

  // ---- 11d. Spaltenbreite mit den Griffen zwischen den Spalten aendern -----
  // data-a / data-b = Index der linken / rechten Grid-Spalte des Griffs.
  // Mindestbreiten: 200px links, 300px bzw. 0.5fr rechts.
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

  // ---- 11e. Dateien auf das Dokumente-Panel ziehen -> Import-Feld ----------
  // BUGFIX: Dieser Block lief frueher sofort im <head>, als #panel-docs noch
  // gar nicht existierte, und brach deshalb immer ab (Drag & Drop von Dateien
  // ging nie). Jetzt laeuft er erst, wenn die Seite geladen ist.
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
      // Dateien in das (versteckte) Shiny-fileInput uebertragen und dessen
      // 'change'-Event ausloesen -> Shiny laedt sie hoch wie bei "Dateien..."
      var dt = new DataTransfer();
      for (var i = 0; i < e.dataTransfer.files.length; i++) dt.items.add(e.dataTransfer.files[i]);
      inp.files = dt.files;
      inp.dispatchEvent(new Event('change', {bubbles: true}));
    });
  })();

  // ---- 11f. "Layout reset" (Server schickt jellyqdaReset) ------------------
  // BUGFIX: Shiny verlangt einen Handler mit genau einem Argument. Frueher
  // stand hier function() ohne Argument -> Shiny warf einen Fehler, der
  // Handler wurde nie registriert und "Layout reset" tat nichts.
  Shiny.addCustomMessageHandler('jellyqdaReset', function(msg) {
    try { localStorage.removeItem('jellyqda_layout'); } catch (e) {}
    location.reload();
  });
});


/* --------------------------------------------------------------------------
   12. Ueberlappende Codings: Popover
   Stellen mit 2+ Codings sind grau (<mark class="ovl" data-cids="3 7 9">)
   und tragen am Anfang eine Zahl (CSS ::before). Maus darueber -> nach
   kurzer Verzoegerung erscheint ein Popover mit allen Codings dieser Stelle
   (Code, Position, Memo) und den Buttons "Anzeigen" / "Loeschen".
   Klick auf die Stelle heftet das Popover fest; Klick daneben oder Esc
   schliesst es.
   Die Details zu jedem Coding liefert R als JSON im Attribut data-codings
   von #doc (siehe .render_doc_html() in R/app.R).
   Das Popover haengt an <body>, also ausserhalb von #doc -- sonst wuerde
   sein Text die Zeichen-Offsets verfaelschen.
   -------------------------------------------------------------------------- */

var jqPop = null;          // das Popover-Element (einmalig erzeugt)
var jqPopShowTimer = null;
var jqPopHideTimer = null;

function jqEsc(s) {
  return String(s == null ? '' : s).replace(/[&<>"']/g, function(c) {
    return {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[c];
  });
}

function codingDetails() {
  // Achtung: der Shiny-Ausgabebereich heisst selbst "doc" (output$doc) und
  // enthaelt das gerenderte <div id="doc" data-codings=...>. Deshalb gezielt
  // das Element MIT dem Attribut suchen, nicht getElementById('doc').
  var doc = document.querySelector('#doc[data-codings]');
  if (!doc) return {};
  try { return JSON.parse(doc.getAttribute('data-codings') || '{}'); } catch (e) { return {}; }
}

function hideOverlapPopover() {
  clearTimeout(jqPopShowTimer); clearTimeout(jqPopHideTimer);
  if (jqPop) { jqPop.style.display = 'none'; jqPop.dataset.pinned = ''; }
}

function showOverlapPopover(mark, pinned) {
  // laufende Timer stoppen: sonst wuerde ein noch ausstehendes Hover-Popover
  // ein gerade per Klick festgeheftetes wieder "loslassen"
  clearTimeout(jqPopHideTimer); clearTimeout(jqPopShowTimer);
  if (!jqPop) {
    jqPop = document.createElement('div');
    jqPop.id = 'jq-popover';
    jqPop.setAttribute('role', 'dialog');
    document.body.appendChild(jqPop);
    // Maus im Popover -> offen lassen, damit man die Buttons erreicht
    jqPop.addEventListener('mouseenter', function() { clearTimeout(jqPopHideTimer); });
    jqPop.addEventListener('mouseleave', scheduleHideOverlapPopover);
  }
  // natives Tooltip (title) unterdruecken, sonst erscheinen zwei Fenster
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
      '<span class="jqp-pos">Zeichen ' + c.start + '–' + c.end + '</span></div>' +
      '<div class="jqp-text">„' + jqEsc(c.text) + (c.end - c.start > 90 ? ' …' : '') + '“</div>' +
      (c.memo ? '<div class="jqp-memo">Memo: ' + jqEsc(c.memo) + '</div>' : '') +
      '</div>' +
      '<div class="jqp-btns">' +
      '<button class="mini jqp-show" data-jqp-show="' + id + '" title="Details in der Leiste ueber dem Text">Anzeigen</button>' +
      '<button class="mini" data-delcoding="' + id + '" title="Dieses Coding loeschen (Strg+Z macht es rueckgaengig)">Löschen</button>' +
      '</div></div>';
  }).join('');
  jqPop.innerHTML = '<div class="jqp-head">' + ids.length + ' Codings an dieser Stelle' +
    (pinned ? '<button class="jqp-close" title="Schliessen (Esc)">×</button>' : '') + '</div>' + rows;
  jqPop.dataset.pinned = pinned ? '1' : '';
  jqPop.style.display = 'block';
  // unter dem Anfang der Stelle (dort sitzt die Zahl) positionieren,
  // innerhalb des Fensters halten
  var r = mark.getClientRects()[0] || mark.getBoundingClientRect();
  var w = jqPop.offsetWidth, h = jqPop.offsetHeight;
  var left = Math.min(r.left, window.innerWidth - w - 8);
  var top = r.bottom + 4;
  if (top + h > window.innerHeight - 8) top = Math.max(8, r.top - h - 4);   // sonst darueber
  jqPop.style.left = Math.max(8, left) + 'px';
  jqPop.style.top = top + 'px';
}

function scheduleHideOverlapPopover() {
  clearTimeout(jqPopShowTimer);
  if (jqPop && jqPop.dataset.pinned) return;   // festgeheftet: bleibt offen
  jqPopHideTimer = setTimeout(hideOverlapPopover, 300);
}

// Maus ueber grauer Stelle -> Popover nach kurzer Verzoegerung. Nicht
// waehrend gerade mit gedrueckter Maustaste markiert wird.
$(document).on('mouseenter', '#doc mark.ovl', function(e) {
  if (e.buttons || hasTextSelection()) return;
  if (jqPop && jqPop.dataset.pinned) return;
  var mark = this;
  clearTimeout(jqPopShowTimer); clearTimeout(jqPopHideTimer);
  jqPopShowTimer = setTimeout(function() { showOverlapPopover(mark, false); }, 250);
});
$(document).on('mouseleave', '#doc mark.ovl', scheduleHideOverlapPopover);

// "Anzeigen" -> wie ein Klick auf ein einzelnes Coding (Leiste ueber dem Text)
$(document).on('click', '[data-jqp-show]', function(e) {
  e.stopPropagation();
  Shiny.setInputValue('clicked_coding', parseInt($(this).attr('data-jqp-show'), 10), {priority: 'event'});
  hideOverlapPopover();
});
// "Loeschen" nutzt den vorhandenen [data-delcoding]-Handler (Abschnitt 4);
// danach wird das Dokument neu gezeichnet -> Popover schliessen
$(document).on('click', '#jq-popover [data-delcoding]', function() { setTimeout(hideOverlapPopover, 0); });
$(document).on('click', '#jq-popover .jqp-close', hideOverlapPopover);

// Klick ausserhalb oder Esc schliesst; ebenso Scrollen im Dokument
$(document).on('mousedown', function(e) {
  if (jqPop && jqPop.style.display === 'block' && !jqPop.contains(e.target) &&
      !(e.target.closest && e.target.closest('#doc mark.ovl'))) hideOverlapPopover();
});
$(document).on('keydown', function(e) { if (e.key === 'Escape') hideOverlapPopover(); });
document.addEventListener('scroll', function(e) {
  if (jqPop && jqPop.style.display === 'block' && e.target.classList &&
      e.target.classList.contains('docarea')) hideOverlapPopover();
}, true);
// Dokument wird neu gezeichnet (z.B. nach Loeschen/Undo) -> Popover zu
$(document).on('shiny:value', function(e) { if (e.name === 'doc') hideOverlapPopover(); });


/* --------------------------------------------------------------------------
   13. Memo-Panel
   "+ Textstelle/Dokument/Code/Projekt" -> input$new_memo {kind}
   Formular "Speichern"/"Abbrechen"     -> input$memo_new_save {text, title}
   Filter-Chips                          -> input$memo_filter
   Bezug einer Karte anklicken           -> input$memo_jump (key)
   Memo-Symbol im Code-Baum / Dokument   -> input$code_memo / input$doc_memo
   Server -> jellyqdaMemoFocus {key}: Panel aufklappen, zur Karte scrollen
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
// Strg+Enter im Memo-Feld = Speichern
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
  e.stopPropagation();   // nicht zusaetzlich den Code auswaehlen
  Shiny.setInputValue('code_memo', parseInt(this.getAttribute('data-codememo'), 10), {priority: 'event'});
});
$(document).on('click', '[data-docmemo]', function(e) {
  e.stopPropagation();   // Dokument nicht zusaetzlich oeffnen
  Shiny.setInputValue('doc_memo', parseInt(this.getAttribute('data-docmemo'), 10), {priority: 'event'});
});
Shiny.addCustomMessageHandler('jellyqdaMemoFocus', function(msg) {
  var panel = document.getElementById('panel-memos');
  if (panel && panel.classList.contains('collapsed')) {
    panel.classList.remove('collapsed');
    if (window.jellyqdaSaveLayout) window.jellyqdaSaveLayout();
  }
  // warten, bis der Server das Panel neu gezeichnet hat
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
   Die App laedt KEINE Font-Awesome-Schrift (fontawesome::fa() in R liefert
   SVG). Server-HTML mit <i class="fa-solid fa-NAME"></i> waere deshalb
   unsichtbar (0x0 Pixel). Hier wird jedes solche <i> durch eine Kopie des
   passenden SVG aus dem unsichtbaren Icon-Verzeichnis #jq-icons ersetzt --
   beim Laden und fuer alles, was Shiny spaeter neu zeichnet.
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
