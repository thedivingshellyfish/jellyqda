/* jellyqda app -- browser logic, part 14 of 17: Icons
   All js/*.js files are joined in name order into one
   <script> tag by .jellyqda_assets() (R/app.R). Overview: ../README.md */

/* --------------------------------------------------------------------------
   14. Icons
   The app loads NO Font Awesome font (fontawesome::fa() in R returns SVG).
   Server HTML with <i class="fa-solid fa-NAME"></i> would therefore be
   invisible (0x0 pixels). Here every such <i> is replaced by a copy of the
   matching SVG from the invisible icon registry #jq-icons -- on load and for
   everything Shiny re-renders later.
   -------------------------------------------------------------------------- */

function jqIcons(root) {
  if (!root || !root.querySelectorAll) return;
  var list = root.matches && root.matches('i.fa-solid') ? [root] : root.querySelectorAll('i.fa-solid');
  Array.prototype.forEach.call(list, function(i) {
    var name = null;
    i.classList.forEach(function(c) { if (c.indexOf('fa-') === 0 && c !== 'fa-solid') name = c.slice(3); });
    var src = name && document.querySelector('#jq-icons [data-faicon="' + name + '"] svg');
    if (!src) return;
    var svg = src.cloneNode(true);
    svg.classList.add('jq-ico');
    i.replaceWith(svg);
  });
}
$(function() {
  jqIcons(document.body);
  new MutationObserver(function(muts) {
    muts.forEach(function(m) { m.addedNodes.forEach(function(n) { if (n.nodeType === 1) jqIcons(n); }); });
  }).observe(document.body, {childList: true, subtree: true});
});
