/* jellyqda app -- browser logic, part 8 of 19: Display: show/hide panels, dark mode, zoom, help, quit
   All js/*.js files are joined in name order into one
   <script> tag by .jellyqda_assets() (R/app.R). Overview: ../README.md */

/* --------------------------------------------------------------------------
   8. Display: show/hide panels, dark mode, zoom, help, quit
   Settings are remembered in the browser's localStorage.
   -------------------------------------------------------------------------- */

// show/hide a panel (toolbar or chevron in the panel header)
$(document).on('click', '[data-toggle]', function(e) {
  e.stopPropagation();
  var p = document.getElementById($(this).attr('data-toggle'));
  if (p) p.classList.toggle('collapsed');
  if (window.jellyqdaSaveLayout) window.jellyqdaSaveLayout();
});

// Toggle dark mode (Bootstrap 5.3 color mode + overrides in css/07-dark-mode.css)
$(document).on('click', '[data-dark]', function(e) {
  e.preventDefault();
  var dark = document.documentElement.getAttribute('data-bs-theme') === 'dark';
  document.documentElement.setAttribute('data-bs-theme', dark ? 'light' : 'dark');
  try { localStorage.setItem('jellyqda_dark', dark ? '0' : '1'); } catch (err) {}
});

// Font size in the document browser (A-/A+): via the CSS variable --jqzoom,
// so it survives every re-rendering of the document.
function applyZoom(z) {
  z = Math.min(1.6, Math.max(0.7, z));   // limits: 70 % to 160 %
  document.documentElement.style.setProperty('--jqzoom', z);
  try { localStorage.setItem('jellyqda_zoom', String(z)); } catch (err) {}
}
$(document).on('click', '[data-zoom]', function(e) {
  e.preventDefault();
  var cur = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--jqzoom')) || 1;
  applyZoom(cur + parseFloat($(this).attr('data-zoom')));
});

// help dialog (shown by the server as modalDialog)
$(document).on('click', '[data-help]', function(e) {
  e.preventDefault();
  Shiny.setInputValue('help_btn', Date.now(), {priority: 'event'});
});

// quit the app (the server exports, makes a backup and stops)
$(document).on('click', '[data-closeapp]', function(e) {
  if (confirm(jqT('jellyqda beenden? Arbeit wird gespeichert (Export + Backup).'))) {
    Shiny.setInputValue('close_app', Date.now(), {priority: 'event'});
  }
});
