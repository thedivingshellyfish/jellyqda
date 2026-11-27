/* jellyqda app -- browser logic, part 12 of 17: Overlapping codings: popover
   All js/*.js files are joined in name order into one
   <script> tag by .jellyqda_assets() (R/app.R). Overview: ../README.md */

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
      '<button class="mini jqp-show" data-jqp-show="' + id + '" title="' + jqT('Details in der Leiste über dem Text') + '">' + jqT('Anzeigen') + '</button>' +
      '<button class="mini" data-delcoding="' + id + '" title="' + jqT('Dieses Coding löschen (Strg+Z macht es rückgängig)') + '">' + jqT('Löschen') + '</button>' +
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
