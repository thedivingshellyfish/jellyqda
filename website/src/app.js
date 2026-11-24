
/* ---------- Zustand (nur localStorage, keine Cookies) ---------- */
const KEY = "jellyqda-assistenz-v1";
const DEF = () => ({ theme: null, sel: {}, step: 0, read: {}, quiz: {}, tour: {}, check: {}, notice: false });
let S = DEF(), CAN_STORE = true;
try { S = Object.assign(DEF(), JSON.parse(localStorage.getItem(KEY) || "{}")); } catch (e) { CAN_STORE = false; }
function save() { try { localStorage.setItem(KEY, JSON.stringify(S)); } catch (e) { CAN_STORE = false; } }
function wipe() { try { localStorage.removeItem(KEY); } catch (e) {} const t = S.theme; S = DEF(); S.theme = t; S.notice = true; }

function applyTheme() {
  const sys = window.matchMedia && matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
  const th = S.theme || sys;
  document.documentElement.setAttribute("data-theme", th);
  document.querySelector('meta[name="theme-color"]').setAttribute("content", th === "light" ? "#f5f6fb" : "#0b1020");
}

/* ---------- Helfer ---------- */
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const I = (p) => '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + p + "</svg>";
const ICON = {
  home: I('<path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z"/>'),
  compass: I('<circle cx="12" cy="12" r="9"/><path d="m15.5 8.5-2 5-5 2 2-5z"/>'),
  book: I('<path d="M4 4.5A2.5 2.5 0 0 1 6.5 2H20v17H6.5A2.5 2.5 0 0 0 4 21.5z"/><path d="M4 21.5V4.5"/>'),
  jelly: I('<path d="M5 12a7 7 0 0 1 14 0c0 .8-.6 1.3-1.3 1.3H6.3C5.6 13.3 5 12.8 5 12z"/><path d="M8 14c0 3-1.5 4-1.5 6M11 14c0 3 1 4 0 7M14 14c0 3-1 4 0 7M17 14c0 3 1.5 4 1.5 6"/>'),
  more: I('<circle cx="5" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="19" cy="12" r="1.6"/>'),
  back: I('<path d="M15 18 9 12l6-6"/>'), chev: I('<path d="m9 6 6 6-6 6"/>'), right: I('<path d="m9 18 6-6-6-6"/>'), left: I('<path d="m15 18-6-6 6-6"/>'),
  check: I('<path d="M20 6 9 17l-5-5"/>'), copy: I('<rect x="9" y="9" width="12" height="12" rx="2"/><path d="M5 15V5a2 2 0 0 1 2-2h10"/>'),
  search: I('<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>'),
  pdf: I('<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/><path d="M12 12v6M9 15l3 3 3-3"/>'),
  sun: I('<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>'),
  moon: I('<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>'), reset: I('<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/>'),
  lock: I('<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>')
};
const LOGO = '<svg class="logo" viewBox="0 0 64 64" aria-hidden="true"><defs><linearGradient id="lg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#a78bfa"/><stop offset="1" stop-color="#38bdf8"/></linearGradient><linearGradient id="gl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".45"/><stop offset=".5" stop-color="#fff" stop-opacity="0"/></linearGradient></defs>' +
  '<rect width="64" height="64" rx="18" fill="url(#lg)"/><rect width="64" height="64" rx="18" fill="url(#gl)"/><path d="M16 32c0-9 7-16 16-16s16 7 16 16c0 2-1.5 3-3 3H19c-1.5 0-3-1-3-3z" fill="#fff"/>' +
  '<path d="M22 37c0 6-3 8-3 12M28 37c0 6 2 8 0 13M36 37c0 6-2 8 0 13M42 37c0 6 3 8 3 12" stroke="#fff" stroke-width="3" fill="none" stroke-linecap="round"/>' +
  '<circle cx="27" cy="27" r="2.3" fill="#4c3fb0"/><circle cx="37" cy="27" r="2.3" fill="#4c3fb0"/><path d="M29.5 30.5q2.5 2 5 0" stroke="#4c3fb0" stroke-width="1.6" fill="none" stroke-linecap="round"/></svg>';
const FITC = ["b", "o", "g"];
const fitTag = (f) => f == null ? "" : '<span class="fit ' + FITC[f] + '">' + UI.fit[f] + "</span>";
const box = (k, em, t, d) => '<div class="box ' + k + '"><span>' + em + "</span><div><b>" + t + "</b>" + d + "</div></div>";
const head = (t, sub, back) => '<div class="pagehead">' + (back ? '<a class="iconbtn" href="' + back + '" aria-label="' + UI.back + '">' + ICON.back + "</a>" : "") +
  '<div style="flex:1;min-width:0"><h2>' + t + "</h2>" + (sub ? '<div class="sub">' + sub + "</div>" : "") + "</div></div>";
function ring(p) {
  const r = 32, c = 2 * Math.PI * r;
  return '<svg viewBox="0 0 78 78"><defs><linearGradient id="rg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="var(--accent)"/><stop offset="1" stop-color="var(--accent2)"/></linearGradient></defs><circle cx="39" cy="39" r="' + r + '" stroke="var(--line)" stroke-width="8" fill="none"/>' +
    (p > 0 ? '<circle cx="39" cy="39" r="' + r + '" stroke="url(#rg)" stroke-width="8" fill="none" stroke-linecap="round" stroke-dasharray="' + (c * p).toFixed(1) + " " + c.toFixed(1) + '"/>' : "") + "</svg>";
}
const codeStore = [];
function hlR(code) {
  return esc(code).replace(/(#.*)$/gm, '<span class="c-com">$1</span>')
    .replace(/(&quot;[^&]*?&quot;)/g, '<span class="c-str">$1</span>')
    .replace(/\b(qda_\w+|library|source)\(/g, '<span class="c-fn">$1</span>(');
}
function codeBox(code, label, prose) {
  const id = codeStore.push(code) - 1;
  return '<div class="codebox"><div class="codebar"><span class="lang">' + (label || "R") + '</span><button data-act="copy" data-id="' + id + '">' + ICON.copy + " " + UI.copy + "</button></div>" +
    '<pre class="' + (prose ? "prose" : "") + '">' + (prose ? esc(code) : hlR(code)) + "</pre></div>";
}
const shot = (f, cap) => '<figure class="shot" data-missing="' + esc(UI.shotMissing) + '"><img src="' + IMG + f + '" alt="' + esc(cap) + '" loading="lazy" onerror="this.parentNode.classList.add(\'noimg\')"><figcaption>' + cap + "</figcaption></figure>";
const lgTag = (k) => '<span class="tag ' + LG[k].cls + '">' + LG[k].name + "</span>";
const supTag = (s) => '<span class="fit ' + FITC[s] + '">' + UI.supPre + UI.sup[s] + "</span>";
function toast(msg) { const t = document.getElementById("toast"); t.textContent = msg; t.classList.add("show"); clearTimeout(toast.h); toast.h = setTimeout(() => t.classList.remove("show"), 1800); }

/* ---------- Passung ---------- */
function fitSt(sel, s) { return sel.iv ? IV[sel.iv].st[s] : null; }
function fitLg(sel, l) {
  const f = [];
  if (sel.iv) f.push(IV[sel.iv].lg[l]);
  if (sel.st) f.push(ST[sel.st].lg[l]);
  return f.length ? Math.min.apply(null, f) : null;
}
function fitPr(sel, p) {
  const f = [];
  if (sel.iv) f.push(IV[sel.iv].good.includes(p) ? 2 : IV[sel.iv].ok.includes(p) ? 1 : 0);
  if (sel.lg) f.push(PR[p].lg[sel.lg]);
  return f.length ? Math.min.apply(null, f) : null;
}
const STEPS = ["zi", "iv", "st", "lg", "pr", "plan"];
function links(sel) {
  return {
    iv: sel.zi && sel.iv ? (ZI[sel.zi].iv.includes(sel.iv) ? 2 : 1) : null,
    st: sel.iv && sel.st ? fitSt(sel, sel.st) : null,
    lg: sel.iv && sel.lg ? fitLg(sel, sel.lg) : null,
    pr: sel.pr ? fitPr(sel, sel.pr) : null
  };
}
function score(sel) {
  const v = Object.values(links(sel)).filter((x) => x != null);
  if (!v.length) return null;
  return v.reduce((a, b) => a + b, 0) / (2 * v.length) * (Math.min.apply(null, v) === 0 ? .6 : 1);
}

/* ---------- Visualisierungen ---------- */
const VS = { logik: "mix", spek: null, karte: null, may: 0, kreis: 0, gq: "" };
function vis(name) { return '<div class="vis" id="vis-' + name + '">' + VIS[name]() + "</div>"; }
function rerenderVis(name) { const el = document.getElementById("vis-" + name); if (el) el.innerHTML = VIS[name](); }
const arrowDefs = "<defs>" + ["de", "in", "mix", "ab"].map((k) => '<marker id="ar-' + k + '" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0 10 5 0 10z" fill="var(--' + k + ')"/></marker>').join("") + "</defs>";
const VIS = {
  quali: () => { const X = VISTX.quali; return '<div class="tblwrap"><table class="tbl"><tr>' + X.head.map((h) => "<th>" + h + "</th>").join("") + "</tr>" +
    X.rows.map((r) => "<tr><td><b>" + r[0] + "</b></td><td>" + r[1] + '</td><td class="muted">' + r[2] + "</td></tr>").join("") + "</table></div>"; },
  logik: () => {
    const m = VS.logik, X = VISTX.logik, l = X.l;
    const lay = (y, t) => '<rect class="svgbox" x="70" y="' + y + '" width="200" height="40" rx="12"/><text class="svgt" x="170" y="' + (y + 19) + '" text-anchor="middle">' + t[0] + '</text><text class="svgs" x="170" y="' + (y + 32) + '" text-anchor="middle">' + t[1] + "</text>";
    const ar = (x1, y1, x2, y2, k, lbl, lx, anchor) => '<path d="M' + x1 + " " + y1 + " L" + x2 + " " + y2 + '" stroke="var(--' + k + ')" stroke-width="3" marker-end="url(#ar-' + k + ')"/>' + (lbl ? '<text class="svgs" x="' + lx + '" y="' + ((y1 + y2) / 2 + 4) + '" text-anchor="' + anchor + '" style="fill:var(--' + k + ')">' + lbl + "</text>" : "");
    let a = "";
    if (m === "de") a = ar(170, 62, 170, 106, "de", l.ableiten, 180, "start") + ar(170, 152, 170, 196, "de", l.anwenden, 180, "start");
    if (m === "in") a = ar(170, 196, 170, 152, "in", l.buendeln, 180, "start") + ar(170, 106, 170, 62, "in", l.verall, 180, "start");
    if (m === "mix") a = ar(120, 62, 120, 106, "de", l.haupt[0], 110, "end") + '<text class="svgs" x="110" y="98" text-anchor="end" style="fill:var(--de)">' + l.haupt[1] + "</text>" + ar(120, 152, 120, 196, "de", l.anwenden, 110, "end") +
      ar(220, 196, 220, 152, "in", l.sub[0], 230, "start") + '<text class="svgs" x="230" y="188" text-anchor="start" style="fill:var(--in)">' + l.sub[1] + "</text>" + ar(220, 106, 220, 62, "in", l.schaerfen, 230, "start");
    if (m === "ab") a = '<path d="M275 216 C330 200 330 40 275 22" stroke="var(--ab)" stroke-width="3" fill="none" marker-end="url(#ar-ab)"/><path d="M65 22 C10 40 10 200 65 216" stroke="var(--ab)" stroke-width="3" fill="none" marker-end="url(#ar-ab)"/>' +
      '<text class="svgs" x="318" y="122" text-anchor="middle" style="fill:var(--ab)" transform="rotate(-90 318 122)">' + l.ab1 + '</text><text class="svgs" x="22" y="122" text-anchor="middle" style="fill:var(--ab)" transform="rotate(-90 22 122)">' + l.ab2 + "</text>";
    return '<div class="seg" role="tablist">' + ["de", "in", "mix", "ab"].map((k) => '<button data-act="vis-logik" data-k="' + k + '" class="' + (m === k ? "on" : "") + '">' + LG[k].name + "</button>").join("") + "</div>" +
      '<svg viewBox="0 0 340 240" role="img" aria-label="' + X.aria + LG[m].name + '">' + arrowDefs + lay(20, X.layers[0]) + lay(110, X.layers[1]) + lay(196, X.layers[2]) + a + "</svg>" +
      '<div class="cap">' + X.txt[m] + "</div>";
  },
  spektrum: () => {
    const X = VISTX.spek, ids = Object.keys(IV).sort((a, b) => (IV[a].pos[0] + IV[a].pos[1]) - (IV[b].pos[0] + IV[b].pos[1]));
    let h = '<div class="spaxis"><span></span><div>' + X.axis.map((t) => "<span>" + t + "</span>").join("") + "</div></div>";
    ids.forEach((k) => {
      const iv = IV[k], c = (iv.pos[0] + iv.pos[1]) / 2;
      h += '<button class="sprow' + (VS.spek === k ? " on" : "") + '" data-act="vis-spek" data-k="' + k + '"><b>' + iv.em + " " + iv.name + '</b><span class="track"><s style="left:' + (iv.pos[0] * 100) + "%;width:" + ((iv.pos[1] - iv.pos[0]) * 100) + '%"></s><i style="left:' + (c * 100) + '%"></i></span></button>';
    });
    h += '<div class="cap">' + X.cap + "</div>";
    if (VS.spek) {
      const iv = IV[VS.spek];
      h += '<div class="panel detail" style="margin:10px 0 0"><h3>' + iv.em + " " + iv.name + '</h3><p class="small muted" style="margin:0 0 8px">' + iv.by + "</p><p>" + iv.short + '</p><p class="small"><b>' + X.wissen + "</b> " + iv.wissen + "</p>" +
        '<a class="btn small primary" href="#/compass" data-act="pick-iv" data-k="' + VS.spek + '">' + ICON.compass + X.take + "</a></div>";
    }
    return h;
  },
  karte: () => {
    const X = VISTX.karte, px = (x) => 34 + x * 280, py = (y) => 262 - y * 236;
    let s = '<svg viewBox="0 0 340 300" role="img" aria-label="' + X.aria + '">' +
      '<defs><linearGradient id="kx" x1="0" x2="1"><stop offset="0" stop-color="var(--de)" stop-opacity=".18"/><stop offset="1" stop-color="var(--in)" stop-opacity=".18"/></linearGradient></defs>' +
      '<rect x="34" y="26" width="280" height="236" rx="12" fill="url(#kx)" stroke="var(--line)"/>' +
      '<line x1="174" y1="26" x2="174" y2="262" stroke="var(--line2)" stroke-dasharray="4 4"/><line x1="34" y1="144" x2="314" y2="144" stroke="var(--line2)" stroke-dasharray="4 4"/>' +
      '<text class="svgs" x="34" y="282">' + X.x[0] + '</text><text class="svgs" x="314" y="282" text-anchor="end">' + X.x[1] + "</text>" +
      '<text class="svgs" x="18" y="262" transform="rotate(-90 18 262)">' + X.y[0] + '</text><text class="svgs" x="18" y="26" text-anchor="end" transform="rotate(-90 18 26)">' + X.y[1] + "</text>";
    const sel = S.sel.pr;
    Object.keys(PR).forEach((k) => {
      const p = PR[k], x = px(p.x), y = py(p.y), on = VS.karte === k || (!VS.karte && sel === k);
      const col = ["var(--bad)", "var(--warn)", "var(--good)"][p.sup];
      s += '<g data-act="vis-karte" data-k="' + k + '" style="cursor:pointer"><circle cx="' + x + '" cy="' + y + '" r="16" fill="transparent"/>' +
        (on ? '<circle cx="' + x + '" cy="' + y + '" r="11" fill="none" stroke="var(--text)" stroke-width="2"/>' : "") +
        '<circle cx="' + x + '" cy="' + y + '" r="6.5" fill="' + col + '" stroke="var(--card)" stroke-width="2"/>' +
        '<text class="svgt" style="font-size:10.5px" x="' + (x + (p.la === "l" ? -11 : 11)) + '" y="' + (y + 4) + '" text-anchor="' + (p.la === "l" ? "end" : "start") + '">' + p.short + "</text></g>";
    });
    s += '</svg><div class="chips small" style="gap:12px;margin-top:4px">' + [2, 1, 0].map((i) => '<span class="fit ' + FITC[i] + '">' + UI.sup[i] + "</span>").join("") + "</div>";
    const k = VS.karte || sel;
    return s + (k ? prCard(k, true) : '<div class="cap">' + X.cap + "</div>");
  },
  prozess: () => {
    const X = VISTX.prozess;
    return '<ul class="steps">' + X.P.map((p, i) => "<li><b>" + p[0] + "</b><small>" + p[1] + "</small>" + (p[2] ? '<span class="tag n" style="margin-top:4px">🪼 ' + p[2] + "</span>" : "") +
      (i === 3 ? '<div class="small" style="color:var(--ab);margin-top:6px">' + X.loop + "</div>" : "") + "</li>").join("") + "</ul>";
  },
  baum: () => {
    const X = VISTX.baum;
    return '<ul class="tree">' + X.T.map((c) => '<li style="--fc:' + c[0] + '"><span class="cf">' + c[1] + '</span><span class="n">Σ ' + c[2] + "</span><ul>" + c[3].map((s) => "<li><span>" + s[0] + '</span><span class="n">' + s[1] + "</span></li>").join("") + "</ul></li>").join("") + "</ul>" +
      '<div class="cap">' + X.cap + "</div>";
  },
  mayring: () => {
    const X = VISTX.mayring, n = VS.may;
    let h = '<div class="seg">' + X.L.map((l, i) => '<button data-act="vis-may" data-k="' + i + '" class="' + (n === i ? "on" : "") + '">' + (i + 1) + ". " + l + "</button>").join("") + "</div>";
    h += '<div class="tblwrap mt"><table class="tbl mtable"><tr>' + X.th.slice(0, n + 1).map((t) => "<th>" + t + "</th>").join("") + "</tr>";
    X.D.forEach((d) => {
      h += "<tr><td>" + d[0] + "</td>" + (n >= 1 ? '<td class="' + (n === 1 ? "new" : "") + '">' + d[1] + "</td>" : "") + (n >= 2 ? '<td class="' + (n === 2 ? "new" : "") + '">' + d[2] + "</td>" : "") +
        (n >= 3 ? '<td class="new"><span class="mcat" style="background:' + X.K[d[3]][1] + '">' + X.K[d[3]][0] + "</span></td>" : "") + "</tr>";
    });
    return h + '</table></div><div class="cap">' + X.cap[n] + "</div>";
  },
  kreis: () => {
    const X = VISTX.kreis, P = X.P, cx = 170, cy = 150, R = 112, sel = VS.kreis;
    let s = '<svg viewBox="0 0 340 300" role="img" aria-label="' + X.aria + '">' +
      '<circle cx="' + cx + '" cy="' + cy + '" r="' + R + '" fill="none" stroke="var(--line2)" stroke-width="2" stroke-dasharray="3 5"/>' +
      '<circle cx="' + cx + '" cy="' + cy + '" r="48" fill="color-mix(in srgb, var(--accent) 22%, var(--card))" stroke="var(--accent)" stroke-width="2"/>' +
      '<text class="svgt" x="' + cx + '" y="' + (cy - 3) + '" text-anchor="middle">' + X.center[0] + '</text><text class="svgt" x="' + cx + '" y="' + (cy + 12) + '" text-anchor="middle">' + X.center[1] + "</text>";
    P.forEach((p, i) => {
      const a = -Math.PI / 2 + i * 2 * Math.PI / 7, x = cx + R * Math.cos(a), y = cy + R * Math.sin(a), on = i === sel;
      s += '<line x1="' + (cx + 50 * Math.cos(a)) + '" y1="' + (cy + 50 * Math.sin(a)) + '" x2="' + (cx + (R - 22) * Math.cos(a)) + '" y2="' + (cy + (R - 22) * Math.sin(a)) + '" stroke="' + (on ? "var(--accent)" : "var(--line2)") + '" stroke-width="' + (on ? 2.5 : 1.5) + '"/>' +
        '<g data-act="vis-kreis" data-k="' + i + '" style="cursor:pointer"><circle cx="' + x + '" cy="' + y + '" r="21" fill="' + (on ? "var(--accent)" : "var(--card)") + '" stroke="var(--accent)" stroke-width="2"/>' +
        '<text x="' + x + '" y="' + (y + 5) + '" text-anchor="middle" style="font:800 14px system-ui;fill:' + (on ? "#fff" : "var(--text)") + '">' + (i + 1) + "</text></g>";
    });
    const p = P[sel];
    return s + '</svg><div class="panel detail" style="margin:6px 0 0"><h3>' + X.phase + (sel + 1) + ": " + p[0] + '</h3><p style="margin:0 0 8px">' + p[1] + '</p><span class="tag n">🪼 ' + p[2] + "</span></div>";
  },
  transkript: () => VISTX.transkript
};

function prCard(k, inVis) {
  const p = PR[k];
  return '<div class="panel detail" style="margin:' + (inVis ? "10px 0 0" : "0") + '"><h3>' + p.name + '</h3><p class="small muted" style="margin:0 0 8px">' + p.by + "</p>" +
    '<div class="chips" style="gap:6px;margin-bottom:8px">' + Object.keys(LG).filter((l) => p.lg[l] === 2).map(lgTag).join("") + supTag(p.sup) + "</div><p>" + p.what + "</p>" +
    "<h4>" + UI.det.steps + '</h4><ol class="steps">' + p.steps.map((s) => "<li><small>" + s + "</small></li>").join("") + "</ol>" + box("jq", "🪼", UI.det.injq, p.jq) + "</div>";
}

/* ---------- Kompass ---------- */
function vKompass() {
  const sel = S.sel, k = Math.min(S.step, 5), id = STEPS[k], K = UI.komp;
  let h = head(K.title, K.sub);
  h += '<div class="stepper">' + STEPS.map((s, i) => '<button data-act="go-step" data-k="' + i + '" class="' + (i === k ? "on" : (sel[s] || (s === "plan" && sel.pr)) ? "done" : "") + '"' + (i === 5 && !sel.pr ? " disabled" : "") + "><i></i><span>" + (i + 1) + " " + UI.steps[i] + "</span></button>").join("") + "</div>";
  if (id === "plan") return h + vPlan();
  const q = K.q[id];
  const sub = id === "iv" ? (sel.zi ? q[2] : q[1]) : id === "st" ? q[1] + "<b>" + (sel.iv ? IV[sel.iv].name : "–") + "</b>" : q[1];
  h += '<p class="q">' + q[0] + '</p><p class="qsub">' + sub + "</p>";
  let items = [];
  if (id === "zi") items = Object.keys(ZI).map((x) => [x, ZI[x], null, ""]);
  if (id === "iv") items = Object.keys(IV).map((x) => [x, IV[x], null, sel.zi && ZI[sel.zi].iv.includes(x) ? '<span class="fit r">' + UI.rec + "</span>" : ""]);
  if (id === "st") items = Object.keys(ST).map((x) => [x, ST[x], fitSt(sel, x), ""]);
  if (id === "lg") items = Object.keys(LG).map((x) => [x, LG[x], fitLg(sel, x), sel.zi && ZI[sel.zi].lg === x ? '<span class="fit r">' + UI.toGoal + "</span>" : ""]);
  if (id === "pr") items = Object.keys(PR).map((x) => [x, PR[x], fitPr(sel, x), supTag(PR[x].sup)]).sort((a, b) => (b[2] || 0) - (a[2] || 0));
  if (id === "iv" && sel.zi) items.sort((a, b) => (b[3] ? 1 : 0) - (a[3] ? 1 : 0));
  h += '<div class="choices">' + items.map((it) => {
    const [key, o, f, extra] = it, on = sel[id] === key;
    return '<button class="choice' + (on ? " on" : "") + (f === 0 && !on ? " dim" : "") + '" data-act="choose" data-step="' + id + '" data-k="' + key + '" aria-pressed="' + on + '">' +
      '<span class="ct">' + (o.em ? '<span class="em">' + o.em + "</span>" : "") + "<b>" + o.name + (o.by && id === "pr" ? ' <small class="muted" style="font-weight:600">(' + o.by + ")</small>" : "") + "</b></span>" +
      "<small>" + (o.short.length > 140 ? o.short.slice(0, 137) + "…" : o.short) + "</small>" +
      (f != null || extra ? '<span class="fits">' + fitTag(f) + extra + "</span>" : "") + "</button>";
  }).join("") + "</div>";
  if (sel[id]) h += detail(id, sel[id]);
  h += '<div class="wnav">' + (k > 0 ? '<button class="btn" data-act="go-step" data-k="' + (k - 1) + '">' + ICON.left + " " + UI.back + "</button>" : "") +
    '<button class="btn primary" data-act="go-step" data-k="' + (k + 1) + '"' + (sel[id] ? "" : " disabled") + ">" + (k === 4 ? K.showPlan : UI.next) + " " + ICON.right + "</button></div>";
  return h;
}

function detail(id, key) {
  const sel = S.sel, D = UI.det;
  let h = '<div class="panel detail" id="detail">';
  if (id === "zi") {
    const z = ZI[key];
    h += "<h3>" + z.em + " " + z.name + "</h3><p>" + z.short + "</p><h4>" + D.ivFor + '</h4><div class="chips">' + z.iv.map((x) => '<span class="tag n">' + IV[x].em + " " + IV[x].name + "</span>").join("") + "</div>" +
      "<h4>" + D.lgFor + "</h4>" + lgTag(z.lg);
  }
  if (id === "iv") {
    const iv = IV[key];
    h += "<h3>" + iv.em + " " + iv.name + "</h3>" + (iv.alt ? '<p class="small muted" style="margin:-4px 0 6px">' + iv.alt + "</p>" : "") + '<p class="small muted" style="margin:0 0 8px">' + D.after + " " + iv.by + "</p><p>" + iv.short + "</p>" +
      "<h4>" + D.wissen + "</h4><p>" + iv.wissen + "</p><h4>" + D.ablauf + '</h4><div class="timeline">' + iv.ablauf.map((a) => "<div><b>" + a[0] + "</b>" + a[1] + "</div>").join("") + "</div>" +
      "<h4>" + D.achten + '</h4><ul class="md">' + iv.achten.map((a) => "<li>" + a + "</li>").join("") + "</ul>" +
      "<h4>" + D.ausw + "</h4><p>" + iv.auswertung + "</p>" +
      "<h4>" + D.next + '</h4><p class="small">' + D.nextSt + " " + Object.keys(ST).map((s) => ST[s].name.split(" ")[0] + " " + fitTag(iv.st[s])).join(" &nbsp; ") + "</p>";
  }
  if (id === "st") {
    const st = ST[key];
    h += "<h3>" + st.em + " " + st.name + " " + fitTag(fitSt(sel, key)) + "</h3>" + (sel.iv ? '<p class="small">' + IV[sel.iv].stNote[key] + "</p>" : "") + "<p>" + st.short + "</p>" +
      "<h4>" + D.beispiel + "</h4><p><i>" + st.frage + "</i></p><h4>" + D.ausw + '</h4><ul class="md">' + st.folgen.map((a) => "<li>" + a + "</li>").join("") + "</ul>" +
      box("jq", "🪼", D.seg, st.seg);
  }
  if (id === "lg") {
    const l = LG[key];
    h += "<h3>" + l.em + " " + l.name + " " + fitTag(fitLg(sel, key)) + "</h3>" + (sel.iv ? '<p class="small">' + IV[sel.iv].lgNote + "</p>" : "") + "<p>" + l.short + "</p>" +
      "<h4>" + D.wann + "</h4><p>" + l.wann + "</p>" + box("warn", "⚠️", D.risiko, l.risiko) + box("jq", "🪼", D.tools, l.tools);
  }
  if (id === "pr") return '<div id="detail" class="detail"><p class="small" style="margin:0 0 8px">' + fitTag(fitPr(sel, key)) + " " + PRWHY(sel, key) + "</p>" + prCard(key, false) + "</div>";
  return h + "</div>";
}

function vPlan() {
  const sel = S.sel, P = UI.plan;
  if (!(sel.iv && sel.st && sel.lg && sel.pr)) return '<div class="panel">' + P.notAll + "</div>";
  const l = links(sel), sc = score(sel), iv = IV[sel.iv], st = ST[sel.st], lg = LG[sel.lg], pr = PR[sel.pr];
  const col = (f) => f == null ? "var(--line)" : ["var(--bad)", "var(--warn)", "var(--good)"][f];
  const node = (lab, val, f, why, step) => '<li style="--nc:var(--accent);--lc:' + col(f) + '"><div class="fl">' + lab + '</div><div class="fv">' + val + ' <a href="#/compass" data-act="go-step" data-k="' + step + '" class="small noprint">' + P.change + "</a></div>" + (why ? '<div class="fw">' + why + "</div>" : "") + "</li>";
  const date = new Date().toLocaleDateString(UI.lang === "de" ? "de-DE" : "en-GB", { day: "numeric", month: "long", year: "numeric" });
  let h = '<div class="printhead">' + LOGO + "<div><b>" + P.printTitle + "</b><span>" + P.printMade + date + "</span></div></div>";
  h += '<div class="hero"><div class="row"><div class="ring">' + ring(sc) + '<div class="v"><div>' + Math.round(sc * 100) + "%<small>" + P.stimmig + "</small></div></div></div><div><h3>" + P.title + "</h3><p>" +
    P.verdict[sc > .85 ? 2 : sc > .6 ? 1 : 0] + '</p></div></div><div class="btnrow noprint"><button class="btn small primary" data-act="print">' + ICON.pdf + " " + P.pdf + '</button><button class="btn small" data-act="restart">' + ICON.reset + " " + P.restart + '</button></div><p class="small noprint" style="position:relative;z-index:1;margin:8px 0 0;color:var(--muted)">' + P.pdfHint + "</p></div>";
  h += '<div class="panel"><h3>' + P.faden + '</h3><p class="small muted" style="margin:0 0 12px">' + P.fadenLegend + '</p><ul class="faden">' +
    (sel.zi ? node(P.nodes[0], ZI[sel.zi].em + " " + ZI[sel.zi].name, l.iv, "", 0) : "") +
    node(P.nodes[1], iv.em + " " + iv.name, l.st, sel.zi ? (l.iv === 2 ? P.goalOk : P.goalNo) : "", 1) +
    node(P.nodes[2], st.em + " " + st.name, l.lg, iv.stNote[sel.st], 2) +
    node(P.nodes[3], lgTag(sel.lg), l.pr, iv.lgNote, 3) +
    node(P.nodes[4], pr.name + ' <span class="muted small">(' + pr.by + ")</span>", null, PRWHY(sel, sel.pr), 4) + "</ul></div>";
  const tips = [].concat(iv.achten.slice(0, 3), [lg.risiko], st.folgen.slice(0, 1));
  if (pr.sup === 0) tips.push(P.sup0(pr.name));
  if (pr.sup === 1) tips.push(pr.jq);
  h += '<div class="panel"><h3>' + P.achten + '</h3><ul class="md">' + tips.map((t) => "<li>" + t + "</li>").join("") + "</ul></div>";
  h += '<div class="panel"><h3>' + P.stepsT + pr.name + '</h3><ol class="steps">' + pr.steps.map((s) => "<li><small>" + s + "</small></li>").join("") + "</ol></div>";
  h += '<div class="panel"><h3>' + P.jq + '</h3><ol class="steps">' + PLAN(sel).map((s) => "<li><b>" + s.t + "</b><small>" + s.d + "</small>" + (s.r ? codeBox(s.r) : "") + "</li>").join("") + "</ol>" +
    '<p class="small noprint"><a href="#/tool">' + P.allSteps + "</a></p></div>";
  h += '<div class="panel"><h3>' + P.method + '</h3><p class="small muted" style="margin:0">' + P.methodNote + "</p>" + codeBox(METHOD(sel), UI.textLabel, true) + "</div>";
  const keys = [].concat(IVLIT[sel.iv] || [], pr.lit || [], ["steinke"]).filter((v, i, a) => a.indexOf(v) === i);
  h += '<div class="panel"><h3>' + P.lit + "</h3>" + keys.map((k) => '<p class="small" style="margin:0 0 8px">' + LIT[k] + "</p>").join("") + '<p class="small muted" style="margin:0">' + P.litNote + "</p></div>";
  h += '<div class="printfoot">jellyqda · ' + P.printUrl + "</div>";
  return h;
}

/* ---------- Weitere Ansichten ---------- */
function progress() {
  const mods = MOD.filter((m) => S.read[m.id]).length, tour = TOUR.filter((t, i) => S.tour[i]).length;
  const ckTot = CHECK.reduce((a, c) => a + c.items.length, 0), ck = CHECK.reduce((a, c) => a + c.items.filter((x, i) => S.check[c.id + i]).length, 0);
  const komp = S.sel.pr ? 1 : 0;
  return { mods, tour, ck, ckTot, p: (komp * 4 + mods + tour + ck / ckTot * 5) / (4 + MOD.length + TOUR.length + 5) };
}
function noticeBar() {
  if (S.notice) return "";
  const N = UI.notice;
  return '<div class="notice" role="note"><span style="font-size:20px">' + "🔒" + '</span><div class="t"><b>' + N.t + "</b>" + N.d + '</div><a class="btn small ghost" href="#/more/set">' + N.more + '</a><button class="btn small" data-act="notice-ok">' + N.ok + "</button></div>";
}
function vHome() {
  const P = progress(), sel = S.sel, H = UI.home;
  const th = document.documentElement.getAttribute("data-theme");
  let h = '<div class="top">' + LOGO + '<div class="grow"><h1>' + UI.title + "</h1><p>" + UI.tagline + '</p></div><a class="iconbtn langbtn" href="' + UI.other.href + location.hash + '" title="' + UI.other.title + '" lang="' + UI.other.label.toLowerCase() + '">' + UI.other.label + '</a><button class="iconbtn" data-act="theme" aria-label="' + UI.themeToggle + '">' + (th === "light" ? ICON.moon : ICON.sun) + "</button></div>";
  h += noticeBar();
  h += '<div class="hero"><div class="row"><div class="ring">' + ring(P.p) + '<div class="v"><div>' + Math.round(P.p * 100) + "%<small>" + H.progress + "</small></div></div></div><div><h3>" +
    (sel.pr ? H.heroDone : H.heroNew) + "</h3><p>" + (sel.pr ? IV[sel.iv].name + " · " + LG[sel.lg].name + " · " + PR[sel.pr].name : H.heroText) + "</p></div></div>" +
    '<div class="kpis"><div class="kpi"><b>' + P.mods + " / " + MOD.length + "</b><span>" + H.kpi[0] + '</span></div><div class="kpi"><b>' + P.tour + " / " + TOUR.length + "</b><span>" + H.kpi[1] + '</span></div><div class="kpi"><b>' + P.ck + " / " + P.ckTot + "</b><span>" + H.kpi[2] + "</span></div></div>" +
    '<div class="btnrow"><a class="btn primary" href="#/compass">' + ICON.compass + (sel.pr ? H.seePlan : sel.zi ? H.cont : H.start) + "</a></div></div>";
  h += '<div class="sectiontitle"><h3>' + H.startWith + '</h3></div><div class="tiles">' +
    tile("#/compass", "🧭", "#8b7cf6", H.tiles[0], sel.pr) + tile("#/basics", "📚", "#38bdf8", H.tiles[1], P.mods === MOD.length) +
    tile("#/tool", "🪼", "#34d399", H.tiles[2], P.tour === TOUR.length) + tile("#/more/check", "✅", "#fbbf24", H.tiles[3], P.ck === P.ckTot) + "</div>";
  h += '<div class="sectiontitle"><h3>' + H.faq + '</h3></div><div class="list">' + H.faqs.map((f, i) => li(f[0], f[1], f[2], i === H.faqs.length - 1 ? GLOSS.length + f[3] : f[3])).join("") + "</div>";
  return h + foot();
}
const tile = (href, ic, c, t, done) => '<a class="tile" style="--dc:' + c + ';text-decoration:none" href="' + href + '">' + (done ? '<span class="done">' + ICON.check + "</span>" : "") + '<span class="h"><span class="ic">' + ic + "</span><span><b>" + t[0] + "</b></span></span><p>" + t[1] + "</p></a>";
const li = (href, ic, t, s) => '<a class="li" style="text-decoration:none" href="' + href + '"><span style="font-size:20px">' + ic + '</span><span class="t"><b>' + t + "</b>" + (s ? "<small>" + s + "</small>" : "") + "</span>" + ICON.chev + "</a>";
const foot = () => '<div class="foot">' + UI.foot + "</div>";

function vBasics() {
  const B = UI.basics;
  let h = head(B.title, B.read(MOD.filter((m) => S.read[m.id]).length, MOD.length));
  h += '<div class="tiles">' + MOD.map((m) => {
    const q = m.quiz.filter((x, i) => S.quiz[m.id + i] === x.a).length;
    return '<a class="tile" style="--dc:' + m.color + ';text-decoration:none" href="#/basics/' + m.id + '">' + (S.read[m.id] ? '<span class="done">' + ICON.check + "</span>" : "") +
      '<span class="h"><span class="ic">' + m.icon + "</span><span><b>" + m.title + "</b><small>" + B.quiz + " " + q + "/" + m.quiz.length + "</small></span></span><p>" + m.blurb + "</p></a>";
  }).join("") + "</div>";
  return h + foot();
}
function vModule(id) {
  const B = UI.basics, i = MOD.findIndex((m) => m.id === id), m = MOD[i];
  if (!m) return vBasics();
  let h = head(m.icon + " " + m.title, B.crumb + " · " + (i + 1) + " / " + MOD.length, "#/basics");
  h += '<div class="panel">' + m.body() + "</div>";
  h += '<div class="panel"><h3>' + B.quizT + "</h3>" + m.quiz.map((q, qi) => {
    const k = m.id + qi, ans = S.quiz[k];
    return '<div class="mt"><b>' + q.q + '</b><div class="opts">' + q.o.map((o, oi) => {
      const cls = ans == null ? "" : oi === q.a ? " right" : oi === ans ? " wrong" : "";
      return '<button class="opt' + cls + '" data-act="quiz" data-k="' + k + '" data-o="' + oi + '"' + (ans != null ? " disabled" : "") + '><span class="k">' + "ABCD"[oi] + "</span><span>" + o + "</span></button>";
    }).join("") + "</div>" + (ans != null ? '<div class="verdict"><b class="' + (ans === q.a ? "ok" : "no") + '">' + (ans === q.a ? B.right : B.wrong) + "</b>" + q.ex + "</div>" : "") + "</div>";
  }).join("") + "</div>";
  h += '<div class="btnrow">' + (i > 0 ? '<a class="btn" href="#/basics/' + MOD[i - 1].id + '">' + ICON.left + " " + UI.back + "</a>" : "") +
    '<button class="btn' + (S.read[id] ? "" : " primary") + '" data-act="read" data-k="' + id + '">' + ICON.check + (S.read[id] ? B.isRead : B.mark) + "</button>" +
    (i < MOD.length - 1 ? '<a class="btn" href="#/basics/' + MOD[i + 1].id + '">' + UI.next + " " + ICON.right + "</a>" : "") + "</div>";
  return h;
}
function vTour() {
  const T = UI.tour, n = TOUR.filter((t, i) => S.tour[i]).length;
  let h = head(T.title, T.done(n, TOUR.length));
  h += '<div class="panel" style="padding:12px 14px"><div class="bar"><i style="width:' + (100 * n / TOUR.length) + '%"></i></div></div>';
  h += '<div class="list">' + TOUR.map((t, i) => '<a class="li" style="text-decoration:none" href="#/tool/' + (i + 1) + '"><span class="num' + (S.tour[i] ? " ok" : "") + '">' + (S.tour[i] ? "✓" : i + 1) + '</span><span class="t"><b>' + t.t + '</b><small><span class="tag ' + T.tags[t.tag][0] + '">' + T.tags[t.tag][1] + "</span></small></span>" + ICON.chev + "</a>").join("") + "</div>";
  return h + '<p class="hint">' + T.more + "</p>";
}
function vTourStep(n) {
  const T = UI.tour, i = n - 1, t = TOUR[i];
  if (!t) return vTour();
  let h = head(t.t, T.step + " " + n + " / " + TOUR.length + ' · <span class="tag ' + T.tags[t.tag][0] + '">' + T.tags[t.tag][1] + "</span>", "#/tool");
  h += '<div class="panel"><div class="md"><p>' + t.txt + "</p></div>" + t.img.map((x) => shot(x[0], x[1])).join("") + (t.r ? '<div class="small muted mt">' + T.asR + "</div>" + codeBox(t.r) : "") +
    t.tips.map((x) => box("tip", "💡", T.tip, x)).join("") + "</div>";
  h += '<div class="btnrow">' + (i > 0 ? '<a class="btn" href="#/tool/' + (n - 1) + '" aria-label="' + UI.back + '">' + ICON.left + "</a>" : "") +
    '<button class="btn' + (S.tour[i] ? "" : " primary") + '" data-act="tour" data-k="' + i + '">' + ICON.check + (S.tour[i] ? T.isDone : T.doneNext) + "</button>" +
    (i < TOUR.length - 1 ? '<a class="btn" href="#/tool/' + (n + 1) + '" aria-label="' + UI.next + '">' + ICON.right + "</a>" : "") + "</div>";
  return h;
}
function vMore(sub) {
  const M = UI.more;
  sub = sub || "check";
  let h = head(M.title, M.sub);
  h += '<div class="seg" style="margin-bottom:14px">' + M.tabs.map((x) => '<a href="#/more/' + x[0] + '" style="text-decoration:none"><button class="' + (sub === x[0] ? "on" : "") + '" tabindex="-1">' + x[1] + "</button></a>").join("") + "</div>";
  if (sub === "check") {
    CHECK.forEach((c) => {
      const d = c.items.filter((x, i) => S.check[c.id + i]).length;
      h += '<div class="sectiontitle"><h3>' + c.em + " " + c.t + "</h3><span>" + d + " / " + c.items.length + '</span></div><div class="list">' +
        c.items.map((it, i) => { const k = c.id + i; return '<label class="ck' + (S.check[k] ? " on" : "") + '"><input type="checkbox" data-act="check" data-k="' + k + '"' + (S.check[k] ? " checked" : "") + "><span>" + it + "</span></label>"; }).join("") + "</div>";
    });
  }
  if (sub === "glossar") h += '<div class="searchbox">' + ICON.search + '<input id="gq" type="search" placeholder="' + M.search + '" aria-label="' + M.search + '" value="' + esc(VS.gq) + '"></div><div class="list" id="gl">' + glossList(VS.gq) + "</div>";
  if (sub === "lit") h += '<div class="list">' + Object.keys(LIT).map((k) => '<div class="lit">' + LIT[k] + "</div>").join("") + '</div><p class="hint">' + M.litHint + "</p>";
  if (sub === "set") {
    const th = S.theme || "auto";
    h += '<div class="panel"><h3>' + M.privT + '</h3><div class="md">' + M.priv + "</div>" + (CAN_STORE ? "" : box("warn", "⚠️", "", M.noStore)) + "</div>";
    h += '<div class="list"><div class="setrow"><div class="t"><b>' + M.theme + "</b><small>" + M.themeSub + '</small></div><div class="seg">' +
      M.themes.map((x) => '<button data-act="settheme" data-k="' + x[0] + '" class="' + (th === x[0] ? "on" : "") + '">' + x[1] + "</button>").join("") + "</div></div>" +
      '<div class="setrow"><div class="t"><b>' + M.wipe + "</b><small>" + M.wipeSub + '</small></div><button class="btn small" data-act="wipe">' + ICON.reset + M.wipeBtn + "</button></div></div>";
  }
  return h + foot();
}
function glossList(q) {
  const ql = q.trim().toLowerCase();
  const hl = (s) => ql ? esc(s).replace(new RegExp("(" + ql.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + ")", "gi"), "<mark>$1</mark>") : esc(s);
  const r = GLOSS.filter((g) => !ql || (g[0] + " " + g[1]).toLowerCase().includes(ql));
  return r.length ? r.map((g) => '<div class="gl"><b>' + hl(g[0]) + "</b><div>" + hl(g[1]) + "</div></div>").join("") : '<div class="gl muted">' + UI.more.noHit + "</div>";
}

/* ---------- Router & Events ---------- */
const TABS = [["home", "#/", ICON.home], ["compass", "#/compass", ICON.compass], ["basics", "#/basics", ICON.book], ["tool", "#/tool", ICON.jelly], ["more", "#/more", ICON.more]];
function render(keepScroll) {
  const parts = location.hash.replace(/^#\/?/, "").split("/");
  const r = parts[0] || "home";
  let html;
  if (r === "compass") html = vKompass();
  else if (r === "basics") html = parts[1] ? vModule(parts[1]) : vBasics();
  else if (r === "tool") html = parts[1] ? vTourStep(+parts[1]) : vTour();
  else if (r === "more") html = vMore(parts[1]);
  else html = vHome();
  const y = window.scrollY;
  document.getElementById("app").innerHTML = '<div class="view">' + html + "</div>";
  window.scrollTo(0, keepScroll ? y : 0);
  document.getElementById("tabbar").innerHTML = '<div class="in">' + TABS.map((t, i) => '<a class="tab' + (r === t[0] ? " on" : "") + '" href="' + t[1] + '">' + t[2] + "<span>" + UI.tabs[i] + "</span></a>").join("") + "</div>";
}
window.addEventListener("hashchange", () => render(false));

document.addEventListener("click", (e) => {
  const el = e.target.closest("[data-act]");
  if (!el) return;
  const a = el.dataset.act, k = el.dataset.k;
  if (a === "choose") {
    S.sel[el.dataset.step] = k; save(); render(true);
    const d = document.getElementById("detail");
    if (d && window.innerWidth < 700) d.scrollIntoView({ behavior: "smooth", block: "start" });
  } else if (a === "go-step") {
    e.preventDefault();
    if (el.disabled) return;
    S.step = Math.max(0, Math.min(5, +k)); save();
    if (location.hash !== "#/compass") location.hash = "#/compass"; else render(false);
  } else if (a === "restart") {
    S.sel = {}; S.step = 0; save(); render(false);
  } else if (a === "print") {
    window.print();
  } else if (a === "copy") {
    const txt = codeStore[+el.dataset.id], done = () => toast(UI.copied);
    if (navigator.clipboard) navigator.clipboard.writeText(txt).then(done, () => fallbackCopy(txt, done)); else fallbackCopy(txt, done);
  } else if (a === "quiz") {
    S.quiz[k] = +el.dataset.o; save(); render(true);
  } else if (a === "read") {
    S.read[k] = !S.read[k]; save(); render(true); if (S.read[k]) toast(UI.basics.good);
  } else if (a === "tour") {
    const i = +k, was = S.tour[i]; S.tour[i] = !was; save();
    if (!was && i < TOUR.length - 1) location.hash = "#/tool/" + (i + 2); else render(true);
  } else if (a === "theme") {
    S.theme = document.documentElement.getAttribute("data-theme") === "light" ? "dark" : "light"; save(); applyTheme(); render(true);
  } else if (a === "settheme") {
    S.theme = k === "auto" ? null : k; save(); applyTheme(); render(true);
  } else if (a === "notice-ok") {
    S.notice = true; save(); render(true);
  } else if (a === "wipe") {
    if (confirm(UI.more.wipeQ)) { wipe(); render(true); toast(UI.more.wiped); }
  } else if (a === "pick-iv") {
    S.sel.iv = k; S.step = 2; save();
  } else if (a.startsWith("vis-")) {
    const n = a.slice(4);
    if (n === "logik") VS.logik = k;
    if (n === "spek") VS.spek = VS.spek === k ? null : k;
    if (n === "karte") VS.karte = k;
    if (n === "may") VS.may = +k;
    if (n === "kreis") VS.kreis = +k;
    rerenderVis({ logik: "logik", spek: "spektrum", karte: "karte", may: "mayring", kreis: "kreis" }[n]);
  }
});
document.addEventListener("change", (e) => {
  const el = e.target;
  if (el.dataset && el.dataset.act === "check") { S.check[el.dataset.k] = el.checked; save(); el.closest(".ck").classList.toggle("on", el.checked); }
});
document.addEventListener("input", (e) => {
  if (e.target.id === "gq") { VS.gq = e.target.value; document.getElementById("gl").innerHTML = glossList(VS.gq); }
});
function fallbackCopy(txt, cb) {
  const ta = document.createElement("textarea"); ta.value = txt; ta.style.position = "fixed"; ta.style.opacity = "0";
  document.body.appendChild(ta); ta.select(); try { document.execCommand("copy"); cb(); } catch (e) {} ta.remove();
}
if (window.matchMedia) matchMedia("(prefers-color-scheme: light)").addEventListener("change", () => { if (!S.theme) { applyTheme(); render(true); } });
applyTheme();
render(false);
})();
</script>
</body>
</html>
