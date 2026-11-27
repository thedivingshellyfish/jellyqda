/* jellyqda app -- browser logic, part 13 of 17: Memo panel
   All js/*.js files are joined in name order into one
   <script> tag by .jellyqda_assets() (R/app.R). Overview: ../README.md */

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
