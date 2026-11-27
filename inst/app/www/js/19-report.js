/* jellyqda app -- browser logic, part 19 of 19: Report dialog and busy hint (since 0.9.1)
   All js/*.js files are joined in name order into one
   <script> tag by .jellyqda_assets() (R/app.R). Overview: ../README.md */

/* --------------------------------------------------------------------------
   19a. Report dialog (R/app_server_report.R)
   "Bericht erstellen" opens an empty tab right away (a click may open tabs,
   a message from the server later may not -- popup blockers), shows the
   progress of the server (Shiny progress messages, mirrored into the dialog)
   and, once the report is ready, loads it into that tab. If the progress
   does not move for 60 seconds the dialog offers "keep waiting" or "back".
   R cannot be interrupted while it builds the report; "back" discards the
   result when it arrives.
   -------------------------------------------------------------------------- */
var jqReport = { win: null, active: false, cancelled: false, last: 0, timer: null };
window.jqReportStallMs = window.jqReportStallMs || 60000;

function jqReportShow(id, on) { var el = document.getElementById(id); if (el) el.hidden = !on; }
function jqReportReset() {
  jqReport.active = false;
  clearInterval(jqReport.timer);
  document.body.classList.remove('jq-reporting');
  var b = document.getElementById('report_make'); if (b) b.disabled = false;
  jqReportShow('jq-report-stall', false);
}
$(document).on('click', '[data-reportmake]', function(e) {
  e.preventDefault();
  var kind = ($('input[name="report_kind"]:checked').val()) || 'full';
  jqReport.cancelled = false; jqReport.active = true; jqReport.last = Date.now();
  jqReport.win = window.open('', '_blank');
  if (jqReport.win) {
    jqReport.win.document.write('<!DOCTYPE html><meta charset="utf-8"><title>' + jqT('Bericht wird erstellt') +
      '</title><p style="font:15px system-ui,sans-serif;margin:2rem;color:#444">' + jqT('Bericht wird erstellt … Dieser Tab füllt sich, sobald er fertig ist.') + '</p>');
  }
  this.disabled = true;
  document.body.classList.add('jq-reporting');
  jqReportShow('jq-report-done', false);
  jqReportShow('jq-report-progress', true);
  $('#jq-report-progress .jqprog-bar span').css('width', '2%');
  $('#jq-report-progress .jqprog-detail').text(jqT('Wird vorbereitet …'));
  clearInterval(jqReport.timer);
  jqReport.timer = setInterval(function() {
    if (jqReport.active && Date.now() - jqReport.last > window.jqReportStallMs) jqReportShow('jq-report-stall', true);
  }, 1000);
  Shiny.setInputValue('report_make', {kind: kind, t: Date.now()}, {priority: 'event'});
});
// mirror Shiny's progress messages into the dialog
$(document).on('shiny:message', function(e) {
  var p = e.message && e.message.progress;
  if (!p || !jqReport.active || !p.message) return;
  var m = p.message;
  if (typeof m.value === 'number') $('#jq-report-progress .jqprog-bar span').css('width', Math.max(2, Math.round(m.value * 100)) + '%');
  if (m.detail) $('#jq-report-progress .jqprog-detail').text(m.detail);
  jqReport.last = Date.now();
  jqReportShow('jq-report-stall', false);
});
$(document).on('click', '[data-reportwait]', function() {
  jqReport.last = Date.now(); jqReportShow('jq-report-stall', false);
});
$(document).on('click', '[data-reportback]', function() {
  jqReport.cancelled = true;
  if (jqReport.win && !jqReport.win.closed) jqReport.win.close();
  jqReportReset();
  jqReportShow('jq-report-progress', false);
  $('#shiny-modal').modal('hide');
});
Shiny.addCustomMessageHandler('jellyqdaReportReady', function(msg) {
  var cancelled = jqReport.cancelled;
  jqReportReset();
  if (cancelled) return;                                   // "back" was chosen: discard
  $('#jq-report-progress .jqprog-bar span').css('width', '100%');
  var done = document.getElementById('jq-report-done');
  if (msg.error) {
    if (jqReport.win && !jqReport.win.closed) jqReport.win.close();
    if (done) { done.textContent = jqT('Der Bericht konnte nicht erstellt werden:') + ' ' + msg.error; done.hidden = false; }
    return;
  }
  if (jqReport.win && !jqReport.win.closed) {
    jqReport.win.location.href = msg.url;
    if (done) { done.textContent = jqF('Fertig ({0}). Der Bericht ist im neuen Tab geöffnet.', [msg.size]); done.hidden = false; }
    setTimeout(function() { $('#shiny-modal').modal('hide'); }, 1500);
  } else if (done) {                                       // tab blocked: offer a link
    done.innerHTML = jqF('Fertig ({0}).', [jqEsc(msg.size)]) + ' <a href="' + jqEsc(msg.url) + '" target="_blank" rel="noopener">' +
      jqT('Bericht öffnen') + '</a>';
    done.hidden = false;
  }
});

/* --------------------------------------------------------------------------
   19b. Busy hint: whenever the server needs longer than 0.8 s, a small
   "Wird verarbeitet ..." appears at the bottom, so a slow step is not taken
   for a hang (Shiny's own busy indicators need shiny >= 1.8.1).
   -------------------------------------------------------------------------- */
var jqBusyTimer = null;
$(document).on('shiny:busy', function() {
  clearTimeout(jqBusyTimer);
  jqBusyTimer = setTimeout(function() { document.body.classList.add('jq-busy'); }, 800);
});
$(document).on('shiny:idle', function() {
  clearTimeout(jqBusyTimer);
  document.body.classList.remove('jq-busy');
});
$(function() {
  var el = document.createElement('div');
  el.className = 'jq-busy-pill'; el.setAttribute('role', 'status'); el.setAttribute('aria-live', 'polite');
  el.textContent = jqT('Wird verarbeitet …');
  document.body.appendChild(el);
});
