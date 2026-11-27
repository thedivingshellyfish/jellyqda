// jellyqda landing page: theme toggle, sticky header, copy button, workflow tabs.
// Shared by /index.html and /de/index.html
(function () {
  var root = document.documentElement, KEY = "jellyqda_landing_theme";
  function stored() { try { return localStorage.getItem(KEY); } catch (e) { return null; } }
  var s = stored(); if (s) root.setAttribute("data-theme", s);
  document.getElementById("themeToggle").addEventListener("click", function () {
    var cur = root.getAttribute("data-theme") ||
      (window.matchMedia && matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
    var next = cur === "dark" ? "light" : "dark";
    root.setAttribute("data-theme", next);
    try { localStorage.setItem(KEY, next); } catch (e) {}
  });

  var hdr = document.getElementById("hdr");
  addEventListener("scroll", function () { hdr.classList.toggle("scrolled", scrollY > 8); }, { passive: true });

  var btn = document.getElementById("copyBtn"), label = btn.querySelector("span");
  btn.addEventListener("click", function () {
    var text = document.getElementById("installline").textContent.replace(/^>\s*/, "");
    function ok() { btn.classList.add("ok"); label.textContent = btn.dataset.copied; setTimeout(function () { btn.classList.remove("ok"); label.textContent = btn.dataset.copy; }, 1800); }
    function fallback() { var r = document.createRange(); r.selectNodeContents(document.getElementById("installline")); var sel = getSelection(); sel.removeAllRanges(); sel.addRange(r); }
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(ok, fallback); else fallback();
  });

  var tabs = [].slice.call(document.querySelectorAll(".steps button"));
  var img = document.getElementById("stageImg"), cap = document.getElementById("stageCap");
  function select(t) {
    tabs.forEach(function (x) { x.setAttribute("aria-selected", x === t ? "true" : "false"); x.tabIndex = x === t ? 0 : -1; });
    img.src = t.getAttribute("data-img"); img.alt = t.querySelector("b").textContent;
    cap.textContent = t.getAttribute("data-cap");
  }
  tabs.forEach(function (t, i) {
    t.tabIndex = i === 0 ? 0 : -1;
    t.addEventListener("click", function () { select(t); });
    t.addEventListener("keydown", function (e) {
      var d = e.key === "ArrowDown" ? 1 : e.key === "ArrowUp" ? -1 : 0;
      if (d) { e.preventDefault(); var n = tabs[(i + d + tabs.length) % tabs.length]; n.focus(); select(n); }
    });
  });
})();
