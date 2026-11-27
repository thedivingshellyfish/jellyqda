/* jellyqda app -- browser logic, part 6 of 19: Keyboard shortcuts
   All js/*.js files are joined in name order into one
   <script> tag by .jellyqda_assets() (R/app.R). Overview: ../README.md */

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
