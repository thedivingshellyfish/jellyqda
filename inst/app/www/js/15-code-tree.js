/* jellyqda app -- browser logic, part 15 of 19: Code tree (codes + subcodes) and coding bar
   All js/*.js files are joined in name order into one
   <script> tag by .jellyqda_assets() (R/app.R). Overview: ../README.md */

/* --------------------------------------------------------------------------
   15. Code tree (codes + subcodes) and coding bar
   The server renders tree and bar (R/app_server_codes.R, R/app_server_coding.R). Everything that only concerns
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
