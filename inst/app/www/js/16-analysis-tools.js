/* jellyqda app -- browser logic, part 16 of 19: Analysis tools (since 0.6.0)
   All js/*.js files are joined in name order into one
   <script> tag by .jellyqda_assets() (R/app.R). Overview: ../README.md */

/* --------------------------------------------------------------------------
   16. Analysis tools (since 0.6.0)
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

// --- 16h. Intercoder agreement (since 0.8.0) ------------------------------------
// "Zeigen": jump to the unit in the document browser (same as keyword in context)
$(document).on('click', '[data-icgoto]', function(e) {
  e.preventDefault();
  Shiny.setInputValue('kwic_goto', {src: parseInt(this.getAttribute('data-src'), 10),
    pos: parseInt(this.getAttribute('data-pos'), 10), t: Date.now()}, {priority: 'event'});
});
// "Übernehmen": copy coder B's coding of this unit into the active project
$(document).on('click', '[data-icadopt]', function(e) {
  e.preventDefault();
  var b = this;
  b.disabled = true;
  Shiny.setInputValue('ic_adopt', {src: parseInt(b.getAttribute('data-src'), 10),
    start: parseInt(b.getAttribute('data-start'), 10), end: parseInt(b.getAttribute('data-end'), 10),
    code: b.getAttribute('data-code'), t: Date.now()}, {priority: 'event'});
});
