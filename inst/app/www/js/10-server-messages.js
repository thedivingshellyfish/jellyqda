/* jellyqda app -- browser logic, part 10 of 19: Messages from the server (session$sendCustomMessage in R)
   All js/*.js files are joined in name order into one
   <script> tag by .jellyqda_assets() (R/app.R). Overview: ../README.md */

/* --------------------------------------------------------------------------
   10. Messages from the server (session$sendCustomMessage in R)
   -------------------------------------------------------------------------- */

// Undo/redo: the tooltip shows what would happen; without an entry the button
// is greyed out. msg = {undo: text|null, redo: text|null}
Shiny.addCustomMessageHandler('jellyqdaHistory', function(msg) {
  function set(id, label, text, key) {
    var b = document.getElementById(id);
    if (!b) return;
    b.title = text ? jqF('{0}: {1} ({2})', [label, text, key]) : jqF('Nichts zum {0} ({1})', [label, key]);
    b.classList.toggle('jq-disabled', !text);
  }
  set('undo_btn', jqT('R\u00fcckg\u00e4ngig'), msg.undo, jqT('Strg+Z'));
  set('redo_btn', jqT('Wiederholen'), msg.redo, jqT('Strg+Y'));
});

// Scroll to a coding (msg.cid) or a character position (msg.pos). Wait a
// moment, because the server is just re-rendering the document.
Shiny.addCustomMessageHandler('jellyqdaScroll', function(msg) {
  setTimeout(function() {
    var doc = document.getElementById('doc');
    if (doc && msg.pos != null) { scrollToChar(doc, msg.pos); return; }
    if (msg.mid != null) {   // passage memo
      var mm = document.querySelector('#doc mark[data-mid="' + msg.mid + '"]');
      if (mm) mm.scrollIntoView({behavior: 'smooth', block: 'center'});
      return;
    }
    // the coding may also be part of an overlap only (data-cids)
    var m = document.querySelector('#doc mark[data-cid="' + msg.cid + '"], ' +
                                   '#doc mark[data-cids~="' + msg.cid + '"]');
    if (m) {
      m.scrollIntoView({behavior: 'smooth', block: 'center'});
      m.style.outline = '3px solid #2c6fbb';                       // highlight briefly
      setTimeout(function() { m.style.outline = ''; }, 2500);
    }
  }, 250);
});
