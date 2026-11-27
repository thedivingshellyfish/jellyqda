/* jellyqda app -- browser logic, part 3 of 19: Clicks in the document
   All js/*.js files are joined in name order into one
   <script> tag by .jellyqda_assets() (R/app.R). Overview: ../README.md */

/* --------------------------------------------------------------------------
   3. Clicks in the document
   -------------------------------------------------------------------------- */

// Click on an existing coding (<mark>) -> details + delete button
// (input$clicked_coding). stopPropagation, so that the segment click
// underneath is not triggered as well.
$(document).on('click', '#doc mark', function(e) {
  if (hasTextSelection()) { e.stopPropagation(); return; }   // was a selection
  // underlined passage (passage memo): show the memo in the panel. NO
  // stopPropagation -- a coding underneath is shown as well.
  if (this.classList.contains('memomark')) {
    Shiny.setInputValue('clicked_memo', parseInt(this.getAttribute('data-mid'), 10), {priority: 'event'});
    return;
  }
  e.stopPropagation();
  // grey overlap area: pin the popover with all codings
  if (this.classList.contains('ovl')) { showOverlapPopover(this, true); return; }
  Shiny.setInputValue('clicked_coding', parseInt($(this).attr('data-cid')), {priority: 'event'});
});

// Click on the "Seg N" badge -> mark the whole paragraph (input$seg_click).
//
// BUGFIX: after a mouse selection inside a paragraph the browser also fires a
// 'click' on the .segtext div. This used to overwrite the exact selection
// with the whole segment, so the whole paragraph was always coded. Now only
// a real click (no selection) in the left padding, where the badge sits,
// counts.
$(document).on('click', '.segtext', function(e) {
  if (e.target.closest('mark')) return;
  if (hasTextSelection()) return;
  var pad = parseFloat(getComputedStyle(this).paddingLeft) || 0;
  if (e.clientX - this.getBoundingClientRect().left > pad) return;
  Shiny.setInputValue('seg_click', parseInt($(this).attr('data-seg'), 10), {priority: 'event'});
});

// Segment actions: segment bar (split here / merge / x) and "As segment" in
// the action bar -> input$seg_action {act: ...}
$(document).on('click', '[data-segact]', function(e) {
  e.stopPropagation();
  Shiny.setInputValue('seg_action', {act: $(this).attr('data-segact'), t: Date.now()}, {priority: 'event'});
});

// code button in the action bar -> code the marked text with this code
$(document).on('click', '.codebtn', function() {
  Shiny.setInputValue('assign_code', parseInt($(this).attr('data-codeid')), {priority: 'event'});
});
