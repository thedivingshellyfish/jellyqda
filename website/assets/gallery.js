// jellyqda landing page :: gallery.js -- the feature gallery ("jellyqda at a
// glance"). Shared by /index.html and /de/index.html; styles: gallery.css.
//   * a feature button scrolls the track to its card (and the gallery into
//     view if it is off screen)
//   * the arrows page one card back or forward; Left/Right keys on the track
//   * the button of the visible card is marked (aria-current), the arrows are
//     disabled at both ends; which card is visible is found by an
//     IntersectionObserver, so scrolling by hand or touch works the same
// Without JavaScript the track still scrolls by hand (scroll snap).
(function () {
  var track = document.querySelector(".gtrack");
  if (!track) return;
  var cards = [].slice.call(track.querySelectorAll(".gcard"));
  var buttons = [].slice.call(document.querySelectorAll(".gnav button[data-go]"));
  var prev = document.querySelector(".gprev"), next = document.querySelector(".gnext");
  var gallery = document.querySelector(".gallery");

  var current = 0;                   // index of the visible card (set by the observer below)
  function index() { return current; }
  function show(i, instant) {
    i = Math.max(0, Math.min(cards.length - 1, i));
    // neighbours slide in; a far jump (several cards) lands at once and fades in,
    // instead of rushing past every card on the way
    var far = Math.abs(i - current) > 1;
    var smooth = !instant && !far && !matchMedia("(prefers-reduced-motion: reduce)").matches;
    track.scrollTo({ left: cards[i].offsetLeft - cards[0].offsetLeft, behavior: smooth ? "smooth" : "auto" });
    if (far && !instant) { cards[i].classList.remove("gfade"); void cards[i].offsetWidth; cards[i].classList.add("gfade"); }
    current = i; mark();
  }
  function mark() {
    var id = cards[current].id;
    buttons.forEach(function (b) { b.setAttribute("aria-current", b.dataset.go === id ? "true" : "false"); });
    prev.disabled = current === 0; next.disabled = current === cards.length - 1;
  }
  // the card that fills most of the track is the current one (also when scrolled by hand or touch)
  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { if (e.isIntersecting && e.intersectionRatio >= 0.6) { current = cards.indexOf(e.target); mark(); } });
    }, { root: track, threshold: [0.6] });
    cards.forEach(function (c) { io.observe(c); });
  }

  buttons.forEach(function (b) {
    b.addEventListener("click", function () {
      var i = cards.findIndex(function (c) { return c.id === b.dataset.go; });
      var r = gallery.getBoundingClientRect();
      if (r.top < 0 || r.bottom > innerHeight) {
        // two smooth scrolls at once (page + track) can cut each other short:
        // bring the gallery into view first, then page the track
        gallery.scrollIntoView({ behavior: "smooth", block: "center" });
        setTimeout(function () { show(i); }, 400);
      } else show(i);
    });
  });
  prev.addEventListener("click", function () { show(index() - 1); });
  next.addEventListener("click", function () { show(index() + 1); });
  track.addEventListener("keydown", function (e) {
    if (e.key === "ArrowRight") { e.preventDefault(); show(index() + 1); }
    if (e.key === "ArrowLeft") { e.preventDefault(); show(index() - 1); }
  });
  addEventListener("resize", function () { show(current, true); });
  // a link to #g-<feature> opens the gallery at that card
  function fromHash() {
    var c = /^#g-/.test(location.hash) && document.getElementById(location.hash.slice(1));
    if (c && cards.indexOf(c) >= 0) { show(cards.indexOf(c), true); gallery.scrollIntoView({ block: "center" }); }
  }
  addEventListener("hashchange", fromHash);
  addEventListener("load", fromHash);
  mark();
})();
