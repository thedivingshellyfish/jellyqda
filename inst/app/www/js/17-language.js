/* jellyqda app -- browser logic, part 17 of 19: Language (EN/DE)
   All js/*.js files are joined in name order into one
   <script> tag by .jellyqda_assets() (R/app.R). Overview: ../README.md */

/* --------------------------------------------------------------------------
   17. Language (EN/DE)
   The EN/DE button links to "?lang=xx"; the choice is remembered in the
   browser and applied again when the app is opened without "?lang=".
   -------------------------------------------------------------------------- */
$(document).on('click', '[data-setlang]', function() {
  try { localStorage.setItem('jellyqda_lang', this.getAttribute('data-setlang')); } catch (e) {}
});
(function() {
  try {
    var want = localStorage.getItem('jellyqda_lang');
    var has = /[?&]lang=/.test(window.location.search);
    if (want && !has && want !== window.jqLang) {
      window.location.replace(window.location.pathname + '?lang=' + want);
    }
  } catch (e) {}
})();
