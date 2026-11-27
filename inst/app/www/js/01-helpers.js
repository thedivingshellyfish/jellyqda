/* jellyqda app -- browser logic, part 1 of 17: Helper functions
   All js/*.js files are joined in name order into one
   <script> tag by .jellyqda_assets() (R/app.R). Overview: ../README.md */

/* --------------------------------------------------------------------------
   1. Helper functions
   -------------------------------------------------------------------------- */

// Translation of UI texts: the server puts the English catalogue into
// window.jqI18n when the UI language is English (R/i18n.R). German is the
// source language, so without a catalogue the German text is shown.
function jqT(s) {
  var d = window.jqI18n;
  return (d && Object.prototype.hasOwnProperty.call(d, s)) ? d[s] : s;
}
// jqT + placeholders {0}, {1}, ... (word order may differ between languages)
function jqF(s, args) {
  return jqT(s).replace(/\{(\d+)\}/g, function(m, i) { return args[+i]; });
}

// Character counting in Unicode code points, as R does (nchar(type =
// "chars")). JavaScript's .length counts UTF-16 code units, so an emoji or
// another character outside the Basic Multilingual Plane counts as 2 there
// but as 1 in R -- every such character before a selection would shift the
// stored coding by one. All offsets sent to / received from the server go
// through these two helpers.
function jqCpLen(s) {
  var m = s.match(/[\uD800-\uDBFF][\uDC00-\uDFFF]/g);
  return s.length - (m ? m.length : 0);
}
// UTF-16 index in `s` of code point position `cp` (clamped to s.length).
function jqCpToUnit(s, cp) {
  var i = 0;
  while (cp > 0 && i < s.length) {
    var c = s.charCodeAt(i);
    i += (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length) ? 2 : 1;
    cp--;
  }
  return i;
}

// Absolute 0-based character offset of the position (node, offset) within
// #doc. Trick: build a range from the start of #doc to the position and
// measure its text length. Works because #doc contains exactly the frozen
// text (segment badges are CSS pseudo-elements, no DOM text).
function absOffset(doc, node, offset) {
  try {
    var r = document.createRange();
    r.selectNodeContents(doc);
    r.setEnd(node, offset);
    return jqCpLen(r.toString());
  } catch (e) { return null; }
}

// true while text is selected (e.g. right after a mouse selection). A
// following 'click' event must then do nothing, otherwise the selection would
// be overwritten (see section 3).
function hasTextSelection() {
  var s = window.getSelection();
  return !!(s && !s.isCollapsed && s.toString().length > 0);
}

// Scroll to a character position in #doc: walk the text nodes in order
// until the position is reached.
function scrollToChar(doc, pos) {
  var walker = document.createTreeWalker(doc, NodeFilter.SHOW_TEXT, null);
  var n, acc = 0;
  while ((n = walker.nextNode())) {
    var len = jqCpLen(n.nodeValue);   // code points, like R (see jqCpLen)
    if (acc + len >= pos) {
      // BUGFIX: a Range has no scrollIntoView (error "r.scrollIntoView is not a
      // function", jumping to search hits did not scroll). Now: measure the
      // position of the place and scroll the scrollable ancestor.
      var r = document.createRange();
      var u0 = jqCpToUnit(n.nodeValue, Math.max(0, pos - acc));
      r.setStart(n, u0);
      r.setEnd(n, jqCpToUnit(n.nodeValue, Math.max(0, pos - acc) + 1));
      var rect = r.getBoundingClientRect();
      var sc = doc.parentElement;
      while (sc && sc !== document.body) {
        var oy = getComputedStyle(sc).overflowY;
        if ((oy === 'auto' || oy === 'scroll') && sc.scrollHeight > sc.clientHeight) break;
        sc = sc.parentElement;
      }
      if (sc && sc !== document.body) {
        var srect = sc.getBoundingClientRect();
        sc.scrollTo({top: sc.scrollTop + rect.top - srect.top - sc.clientHeight / 2, behavior: 'smooth'});
      } else {
        n.parentElement.scrollIntoView({behavior: 'smooth', block: 'center'});
      }
      return true;
    }
    acc += len;
  }
  return false;
}
