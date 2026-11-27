/* jellyqda app -- browser logic, part 4 of 19: Clicks in lists (documents, codes, codings, variables, search)
   All js/*.js files are joined in name order into one
   <script> tag by .jellyqda_assets() (R/app.R). Overview: ../README.md */

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
// server codes the selection instead, see R/app_server_codes.R). The browser sets the
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
