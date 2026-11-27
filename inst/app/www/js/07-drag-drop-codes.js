/* jellyqda app -- browser logic, part 7 of 19: Drag & drop: move codes in the code tree (new parent)
   All js/*.js files are joined in name order into one
   <script> tag by .jellyqda_assets() (R/app.R). Overview: ../README.md */

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
