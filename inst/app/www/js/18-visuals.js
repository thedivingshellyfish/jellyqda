/* jellyqda app -- browser logic, part 18 of 19: Graphics window (since 0.9.0)
   All js/*.js files are joined in name order into one
   <script> tag by .jellyqda_assets() (R/app.R). Overview: ../README.md */

/* --------------------------------------------------------------------------
   18. Graphics: heatmap cells and network lines (data-a / data-b) send the
   pair of codes to the server, which lists the passages; portrait blocks
   and "Zeigen" buttons (data-jump) jump to the passage (same input as
   keyword in context: kwic_goto, R/app_server_analysis.R).
   -------------------------------------------------------------------------- */
$(document).on('click', '.jqv [data-a]', function(e) {
  e.preventDefault();
  Shiny.setInputValue('viz_pair', {a: this.getAttribute('data-a'), b: this.getAttribute('data-b'), t: Date.now()},
                      {priority: 'event'});
});
$(document).on('click', '[data-jump]', function(e) {
  e.preventDefault();
  Shiny.setInputValue('kwic_goto', {src: parseInt(this.getAttribute('data-src'), 10),
    pos: parseInt(this.getAttribute('data-pos'), 10), t: Date.now()}, {priority: 'event'});
});
