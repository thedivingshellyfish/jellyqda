/* jellyqda app -- browser logic, part 11 of 17: On page load (as soon as the HTML is complete)
   All js/*.js files are joined in name order into one
   <script> tag by .jellyqda_assets() (R/app.R). Overview: ../README.md */

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
