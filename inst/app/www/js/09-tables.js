/* jellyqda app -- browser logic, part 9 of 17: Tables: click a cell -> show segments for (code x document)
   All js/*.js files are joined in name order into one
   <script> tag by .jellyqda_assets() (R/app.R). Overview: ../README.md */

/* --------------------------------------------------------------------------
   9. Tables: click a cell -> show segments for (code x document)
   -------------------------------------------------------------------------- */

// Code-Matrix
$(document).on('click', '.mxcell', function() {
  Shiny.setInputValue('mx_cell', {
    code: parseInt($(this).attr('data-mxcode')),
    source: parseInt($(this).attr('data-mxsrc'))
  }, {priority: 'event'});
});

// Summary Grid
$(document).on('click', '.sumcell', function() {
  Shiny.setInputValue('sum_cell', {
    code: parseInt($(this).attr('data-sumcode')),
    source: parseInt($(this).attr('data-sumsrc'))
  }, {priority: 'event'});
});
