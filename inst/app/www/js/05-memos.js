/* jellyqda app -- browser logic, part 5 of 17: Memos (basic functions; the memo panel itself: section 13)
   All js/*.js files are joined in name order into one
   <script> tag by .jellyqda_assets() (R/app.R). Overview: ../README.md */

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
