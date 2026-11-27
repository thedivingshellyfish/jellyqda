/* jellyqda app -- browser logic, part 2 of 17: Text selection in the document -> character offsets
   All js/*.js files are joined in name order into one
   <script> tag by .jellyqda_assets() (R/app.R). Overview: ../README.md */

/* --------------------------------------------------------------------------
   2. Text selection in the document -> character offsets
   When the mouse is released, the selection is sent to input$selection as
   1-based, inclusive offsets {start, end, text}. The server then shows the
   action bar ("Marked: characters X-Y" + code buttons).
   Empty selection (simple click) -> input$selection = null -> bar gone;
   instead the cursor position is sent as input$caret (for the segment bar:
   "Split here", "Merge").
   -------------------------------------------------------------------------- */

$(document).on('mouseup', function(e) {
  var doc = document.getElementById('doc');
  if (!doc || !doc.contains(e.target)) return;   // only mouse actions in the document
  var sel = window.getSelection();
  if (!sel || sel.isCollapsed) {
    Shiny.setInputValue('selection', null);
    // cursor position (0-based = number of characters before the cursor)
    if (sel && sel.rangeCount > 0) {
      var c = absOffset(doc, sel.anchorNode, sel.anchorOffset);
      if (c !== null) Shiny.setInputValue('caret', {pos: c, t: Date.now()}, {priority: 'event'});
    }
    return;
  }
  // anchor = where the selection began, focus = where it ends (may be
  // before it when selecting backwards) -> min/max
  var a = absOffset(doc, sel.anchorNode, sel.anchorOffset);
  var f = absOffset(doc, sel.focusNode, sel.focusOffset);
  if (a === null || f === null) return;
  var s0 = Math.min(a, f), e0 = Math.max(a, f);
  Shiny.setInputValue('selection',
    {start: s0 + 1, end: e0, text: sel.toString()}, {priority: 'event'});
});
