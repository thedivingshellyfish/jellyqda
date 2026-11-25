/* ============================================================
   jellyqda Converter – REFI-QDA (.qdpx / .qdc, z. B. aus MAXQDA) -> .jellyqda
   Läuft komplett im Browser: ZIP lesen (DecompressionStream), XML (DOMParser),
   SQLite-Datei selbst schreiben. Keine Bibliotheken, kein Upload, keine Cookies.
   ============================================================ */
(function () {
"use strict";
const LANG = document.documentElement.lang === "de" ? "de" : "en";

/* ---------- 1. Texte ---------- */
const TX = {
  de: {
    title: "jellyqda Converter", tagline: "MAXQDA & Co. → jellyqda, direkt im Browser",
    other: { href: "../../converter/", label: "EN", title: "English version" }, home: "../", assistant: "../assistenz/",
    privT: "Deine Daten bleiben auf deinem Rechner.",
    privD: "Die Umwandlung passiert vollständig in diesem Browser-Tab. Es wird nichts hochgeladen, es gibt keine Cookies und kein Tracking. Du kannst die Seite auch speichern und offline benutzen.",
    s1: "In MAXQDA exportieren", s1d: "Exportiere dein Projekt im Austauschformat <b>REFI-QDA</b> (Dateiendung <code>.qdpx</code>). In MAXQDA findest du das im Export-Menü des Projekts als „REFI-QDA-Projekt“ (je nach Version unter <i>Start</i> bzw. <i>Projekt → Exportieren</i>). Nur den Codebaum? Dann „Codesystem als REFI-QDA-Codebuch“ (<code>.qdc</code>).",
    s1x: "Funktioniert genauso mit Exporten aus ATLAS.ti, NVivo, QDA Miner und anderen Programmen, die REFI-QDA unterstützen.",
    s2: "Datei hier ablegen", drop: "<b>.qdpx</b> oder <b>.qdc</b> hierher ziehen", or: "oder", pick: "Datei auswählen",
    working: "Wird umgewandelt …", s3: "Ergebnis prüfen & speichern",
    k: ["Dokumente", "Codes", "Codings", "Memos", "Variablen"],
    origin: "Herkunft", tree: "Codebaum", docs: "Dokumente", docCod: (n) => n + (n === 1 ? " Coding" : " Codings"), docChars: (n) => n.toLocaleString("de-DE") + " Zeichen",
    sample: "Stichprobe: Stimmen die Markierungen?", sampleD: "Zufällig ausgewählte Codings mit dem markierten Text. Wenn die Ausschnitte zum Code passen, sind die Positionen richtig übernommen.",
    again: "Neue Stichprobe", check: "Positions-Check", checkOk: (a, b) => "Bei " + a + " von " + b + " prüfbaren Markierungen stimmt der Text mit dem MAXQDA-Ausschnitt überein.",
    checkNone: "MAXQDA hat keine Textausschnitte mitgeliefert – bitte die Stichprobe von Hand prüfen.",
    checkShift: (h) => "Hinweis: Die Positionen waren " + h + " gezählt und wurden automatisch angepasst.",
    warnT: "Was nicht übernommen wurde", noWarn: "Alles übernommen – keine Hinweise.",
    fname: "Dateiname", save: "Als .jellyqda speichern", saved: "Gespeichert ✓",
    nextT: "So geht’s weiter in R",
    nextD: "Lege die Datei in deinen Projektordner und öffne sie wie jedes jellyqda-Projekt. Beim ersten Öffnen ergänzt jellyqda automatisch Indizes und Tabellen.",
    nextTips: ["Interviews mit Zeitmarken? In der App bei <b>Dokumente</b> „Segmente neu einteilen“ → <b>Sprecherwechsel</b> wählen.", "Behalte den MAXQDA-Export als Original auf – der Import steht im jellyqda-Protokoll (<code>qda_export(\"audit\")</code>).", "Prüfe ein paar Stellen direkt in der App, bevor du weiterarbeitest."],
    resetBtn: "Andere Datei umwandeln",
    w: {
      notzip: "Das ist keine gültige .qdpx-Datei (kein ZIP-Archiv).", zip64: "Sehr große ZIP-Archive (ZIP64) werden noch nicht unterstützt.", noqde: "Im Archiv fehlt die Projektbeschreibung project.qde.",
      xml: "Die XML-Datei ist fehlerhaft und kann nicht gelesen werden.", method: "Unbekannte Komprimierung im ZIP-Archiv.", nodecomp: "Dein Browser kann keine ZIP-Dateien entpacken. Bitte einen aktuellen Chrome, Edge, Firefox oder Safari verwenden.",
      wrongtype: "Bitte eine .qdpx- oder .qdc-Datei wählen.",
      pic: (n) => "Bild „" + n + "“ übersprungen (jellyqda kann nur Text).", media: (n) => "Audio/Video „" + n + "“ übersprungen – nur ein vorhandenes Transkript wird übernommen.",
      notext: (n) => "„" + n + "“ hat keinen Text im Export und wurde übersprungen.", pdfsel: (n, k) => "„" + n + "“: " + k + " Markierung(en) im PDF-Layout (Koordinaten) – nicht übertragbar.",
      outside: (n, k) => "„" + n + "“: " + k + " Markierung(en) außerhalb des Textes übersprungen.", nocode: (k) => k + " Coding(s) verweisen auf unbekannte Codes und wurden übersprungen.",
      dup: (a, b) => "Doppelter Code-Name „" + a + "“ umbenannt in „" + b + "“.", memo: "Ein Hauptcode hieß „Memo“ und wurde in „Memo (MAXQDA)“ umbenannt (jellyqda reserviert diesen Namen).",
      slash: (a) => "„/“ im Code-Namen „" + a + "“ ersetzt (jellyqda trennt Pfade mit „ / “).", bom: "Byte-Order-Mark am Textanfang entfernt.",
      links: (k) => k + " Verknüpfung(en) zwischen Elementen (Links) gibt es in jellyqda nicht.", graphs: (k) => k + " Map(s)/Grafik(en) übersprungen.",
      notesel: (k) => k + " Markierung(en) innerhalb von Memos übersprungen.", users: (k) => "Benutzer:innen (" + k + ") werden nicht übernommen; Erstellungsdaten der Memos bleiben erhalten.",
      enc: (n) => "„" + n + "“ war nicht UTF-8 und wurde umkodiert – bitte Umlaute prüfen.", codeset: (k) => k + " Code-Set(s) übersprungen (nur Dokument-Sets werden zu Variablen)."
    },
    vCase: "Fall", vSet: "Dokumentset", projMemo: "Projektbeschreibung", descMemo: "Beschreibung", conv: "umgewandelt aus",
    noname: "(ohne Namen)", foot: 'Teil von <a href="../">jellyqda</a> · <a href="../assistenz/">Assistenz</a> · <a href="https://github.com/thedivingshellyfish/jellyqda">GitHub</a>', theme: "Hell/Dunkel umschalten"
  },
  en: {
    title: "jellyqda Converter", tagline: "MAXQDA & co. → jellyqda, right in your browser",
    other: { href: "../de/konverter/", label: "DE", title: "Deutsche Version" }, home: "../", assistant: "../assistant/",
    privT: "Your data stays on your computer.",
    privD: "The conversion happens entirely in this browser tab. Nothing is uploaded, there are no cookies and no tracking. You can also save the page and use it offline.",
    s1: "Export from MAXQDA", s1d: "Export your project in the <b>REFI-QDA</b> exchange format (file extension <code>.qdpx</code>). In MAXQDA it is in the project’s export menu as “REFI-QDA Project” (depending on the version under <i>Home</i> or <i>Project → Export</i>). Only the code tree? Then “Code system as REFI-QDA codebook” (<code>.qdc</code>).",
    s1x: "Works just the same with exports from ATLAS.ti, NVivo, QDA Miner and other programs that support REFI-QDA.",
    s2: "Drop the file here", drop: "Drag a <b>.qdpx</b> or <b>.qdc</b> file here", or: "or", pick: "Choose file",
    working: "Converting …", s3: "Check & save the result",
    k: ["Documents", "Codes", "Codings", "Memos", "Variables"],
    origin: "Origin", tree: "Code tree", docs: "Documents", docCod: (n) => n + (n === 1 ? " coding" : " codings"), docChars: (n) => n.toLocaleString("en-GB") + " characters",
    sample: "Sample: are the markings right?", sampleD: "Randomly chosen codings with their marked text. If the excerpts fit the code, the positions were carried over correctly.",
    again: "New sample", check: "Position check", checkOk: (a, b) => "For " + a + " of " + b + " checkable markings the text matches the excerpt stored by MAXQDA.",
    checkNone: "MAXQDA didn’t include text excerpts – please check the sample by hand.",
    checkShift: (h) => "Note: positions were counted " + h + " and have been adjusted automatically.",
    warnT: "What was not carried over", noWarn: "Everything carried over – no notes.",
    fname: "File name", save: "Save as .jellyqda", saved: "Saved ✓",
    nextT: "Next steps in R",
    nextD: "Put the file into your project folder and open it like any jellyqda project. On first opening, jellyqda adds indexes and tables automatically.",
    nextTips: ["Interviews with timestamps? In the app under <b>Documents</b>, choose “Re-segment” → <b>speaker turns</b>.", "Keep the MAXQDA export as your original – the import is recorded in the jellyqda audit trail (<code>qda_export(\"audit\")</code>).", "Check a few passages in the app before you carry on."],
    resetBtn: "Convert another file",
    w: {
      notzip: "This is not a valid .qdpx file (not a ZIP archive).", zip64: "Very large ZIP archives (ZIP64) are not supported yet.", noqde: "The archive has no project description project.qde.",
      xml: "The XML file is broken and can’t be read.", method: "Unknown compression in the ZIP archive.", nodecomp: "Your browser can’t unpack ZIP files. Please use a current Chrome, Edge, Firefox or Safari.",
      wrongtype: "Please choose a .qdpx or .qdc file.",
      pic: (n) => "Image “" + n + "” skipped (jellyqda handles text only).", media: (n) => "Audio/video “" + n + "” skipped – only an existing transcript is carried over.",
      notext: (n) => "“" + n + "” has no text in the export and was skipped.", pdfsel: (n, k) => "“" + n + "”: " + k + " marking(s) in the PDF layout (coordinates) – can’t be carried over.",
      outside: (n, k) => "“" + n + "”: " + k + " marking(s) outside the text skipped.", nocode: (k) => k + " coding(s) refer to unknown codes and were skipped.",
      dup: (a, b) => "Duplicate code name “" + a + "” renamed to “" + b + "”.", memo: "A top-level code was called “Memo” and was renamed to “Memo (MAXQDA)” (jellyqda reserves this name).",
      slash: (a) => "Replaced “/” in the code name “" + a + "” (jellyqda separates paths with “ / ”).", bom: "Removed a byte order mark at the start of a text.",
      links: (k) => k + " link(s) between items – jellyqda has no links.", graphs: (k) => k + " map(s)/graph(s) skipped.",
      notesel: (k) => k + " marking(s) inside memos skipped.", users: (k) => "Users (" + k + ") are not carried over; memo creation dates are kept.",
      enc: (n) => "“" + n + "” was not UTF-8 and was re-encoded – please check special characters.", codeset: (k) => k + " code set(s) skipped (only document sets become variables)."
    },
    vCase: "Case", vSet: "Document set", projMemo: "Project description", descMemo: "Description", conv: "converted from",
    noname: "(no name)", foot: 'Part of <a href="../">jellyqda</a> · <a href="../assistant/">Assistant</a> · <a href="https://github.com/thedivingshellyfish/jellyqda">GitHub</a>', theme: "Switch light/dark"
  }
}[LANG];

/* ---------- 2. ZIP lesen ---------- */
const fail = (msg) => { const e = new Error(msg); e.user = true; return e; };
function unzipIndex(buf) {
  const u8 = new Uint8Array(buf), dv = new DataView(buf);
  let eocd = -1;
  for (let i = u8.length - 22; i >= Math.max(0, u8.length - 65557); i--) if (dv.getUint32(i, true) === 0x06054b50) { eocd = i; break; }
  if (eocd < 0) throw fail(TX.w.notzip);
  const n = dv.getUint16(eocd + 10, true);
  let off = dv.getUint32(eocd + 16, true);
  if (off === 0xffffffff || n === 0xffff) throw fail(TX.w.zip64);
  const dec = new TextDecoder("utf-8"), files = new Map();
  for (let k = 0; k < n; k++) {
    if (dv.getUint32(off, true) !== 0x02014b50) throw fail(TX.w.notzip);
    const method = dv.getUint16(off + 10, true), csize = dv.getUint32(off + 20, true);
    const nlen = dv.getUint16(off + 28, true), elen = dv.getUint16(off + 30, true), clen = dv.getUint16(off + 32, true), lho = dv.getUint32(off + 42, true);
    const name = dec.decode(u8.subarray(off + 46, off + 46 + nlen)).replace(/\\/g, "/");
    off += 46 + nlen + elen + clen;
    if (name.endsWith("/")) continue;
    const start = lho + 30 + dv.getUint16(lho + 26, true) + dv.getUint16(lho + 28, true);
    files.set(name.toLowerCase().replace(/^\.\//, ""), { name, method, data: u8.subarray(start, start + csize) });
  }
  return files;
}
async function unzipEntry(e) {
  if (e.method === 0) return e.data;
  if (e.method !== 8) throw fail(TX.w.method);
  if (typeof DecompressionStream === "undefined") throw fail(TX.w.nodecomp);
  const s = new Blob([e.data]).stream().pipeThrough(new DecompressionStream("deflate-raw"));
  return new Uint8Array(await new Response(s).arrayBuffer());
}
function decodeText(bytes, name, notes) {
  if (bytes[0] === 0xff && bytes[1] === 0xfe) return new TextDecoder("utf-16le").decode(bytes.subarray(2));
  if (bytes[0] === 0xfe && bytes[1] === 0xff) return new TextDecoder("utf-16be").decode(bytes.subarray(2));
  try { return new TextDecoder("utf-8", { fatal: true }).decode(bytes); }
  catch (e) { notes.push(TX.w.enc(name)); return new TextDecoder("windows-1252").decode(bytes); }
}

/* ---------- 3. REFI-QDA lesen ---------- */
const kids = (el, name) => el ? Array.from(el.children).filter((c) => c.localName === name) : [];
const kid = (el, name) => kids(el, name)[0] || null;
const desc = (el, name) => el ? Array.from(el.getElementsByTagNameNS("*", name)) : [];
const txt = (el) => el ? el.textContent.trim() : "";
const attr = (el, a) => el && el.hasAttribute(a) ? el.getAttribute(a) : null;

async function readProject(file) {
  const notes = [];
  const lower = file.name.toLowerCase();
  let doc, zip = null;
  const parseXml = (s) => {
    const d = new DOMParser().parseFromString(s.replace(/^﻿/, ""), "application/xml");
    if (d.getElementsByTagName("parsererror").length) throw fail(TX.w.xml);
    return d;
  };
  if (lower.endsWith(".qdc") || lower.endsWith(".qde") || lower.endsWith(".xml")) {
    doc = parseXml(await file.text());
  } else if (lower.endsWith(".qdpx") || lower.endsWith(".zip")) {
    zip = unzipIndex(await file.arrayBuffer());
    let qde = zip.get("project.qde");
    if (!qde) for (const [k, v] of zip) if (k.endsWith(".qde")) { qde = v; break; }
    if (!qde) throw fail(TX.w.noqde);
    doc = parseXml(new TextDecoder("utf-8").decode(await unzipEntry(qde)));
  } else throw fail(TX.w.wrongtype);

  const root = doc.documentElement;
  const readInternal = async (path, name) => {
    if (!path || !zip) return null;
    const m = /^internal:\/\/(.+)$/i.exec(path);
    const rel = (m ? "sources/" + m[1] : path.replace(/^[a-z]+:\/\//i, "")).toLowerCase();
    const e = zip.get(rel) || zip.get(rel.replace(/^sources\//, "")) || [...zip.entries()].find(([k]) => k.endsWith("/" + rel.split("/").pop()))?.[1];
    return e ? decodeText(await unzipEntry(e), name, notes) : null;
  };

  // Codes (Baum)
  const codes = [];
  const codeByGuid = new Map();
  const walk = (el, parent) => kids(el, "Code").forEach((c) => {
    const o = { guid: attr(c, "guid"), name: attr(c, "name") || TX.noname, color: attr(c, "color"), desc: txt(kid(c, "Description")), parent, notes: kids(c, "NoteRef").map((r) => attr(r, "targetGUID")) };
    codes.push(o); if (o.guid) codeByGuid.set(o.guid, o); walk(c, o);
  });
  const cb = root.localName === "CodeBook" ? root : kid(root, "CodeBook");
  walk(kid(cb, "Codes"), null);

  // Notizen (Memos)
  const noteByGuid = new Map();
  for (const n of kids(kid(root, "Notes"), "Note")) {
    let t = txt(kid(n, "PlainTextContent"));
    if (!t && attr(n, "plainTextPath")) t = ((await readInternal(attr(n, "plainTextPath"), attr(n, "name"))) || "").trim();
    const sel = kids(n, "PlainTextSelection").length;
    if (sel) notes.push(TX.w.notesel(sel));
    noteByGuid.set(attr(n, "guid"), { name: attr(n, "name") || "", text: t || txt(kid(n, "Description")), created: attr(n, "creationDateTime") || attr(n, "modifiedDateTime"), used: false });
  }

  // Variablen
  const varByGuid = new Map(kids(kid(root, "Variables"), "Variable").map((v) => [attr(v, "guid"), attr(v, "name") || "?"]));
  const readVars = (el) => {
    const out = {};
    for (const vv of kids(el, "VariableValue")) {
      const ref = attr(kid(vv, "VariableRef"), "targetGUID");
      const valEl = Array.from(vv.children).find((c) => /Value$/.test(c.localName));
      if (ref && valEl) out[varByGuid.get(ref) || ref] = valEl.textContent.trim();
    }
    return out;
  };

  // Quellen
  const sources = [];
  const srcByGuid = new Map();
  const addText = async (el, name, guid, format, outer) => {
    let text = null;
    if (attr(el, "plainTextPath")) text = await readInternal(attr(el, "plainTextPath"), name);
    if (text == null && kid(el, "PlainTextContent")) text = kid(el, "PlainTextContent").textContent;
    if (text == null) { notes.push(TX.w.notext(name)); return; }
    if (text.charCodeAt(0) === 0xfeff) { text = text.slice(1); notes.push(TX.w.bom); }
    const sels = kids(el, "PlainTextSelection").map((s) => ({
      s: +attr(s, "startPosition"), e: +attr(s, "endPosition"), name: attr(s, "name") || "",
      comment: txt(kid(s, "Description")), created: attr(s, "creationDateTime"),
      codes: kids(s, "Coding").map((c) => attr(kid(c, "CodeRef"), "targetGUID")),
      notes: kids(s, "NoteRef").map((r) => attr(r, "targetGUID"))
    }));
    const src = { guid, name, format, text, sels, desc: txt(kid(outer, "Description")), notes: kids(outer, "NoteRef").map((r) => attr(r, "targetGUID")), vars: readVars(outer) };
    sources.push(src); if (guid) srcByGuid.set(guid, src);
  };
  for (const s of Array.from(kid(root, "Sources")?.children || [])) {
    const name = attr(s, "name") || TX.noname, guid = attr(s, "guid");
    if (s.localName === "TextSource") await addText(s, name, guid, "txt", s);
    else if (s.localName === "PDFSource") {
      const rep = kid(s, "Representation");
      const pdfSel = kids(s, "PDFSelection").length;
      if (pdfSel) notes.push(TX.w.pdfsel(name, pdfSel));
      if (rep) await addText(rep, name, guid, "pdf", s); else notes.push(TX.w.notext(name));
    } else if (s.localName === "PictureSource") notes.push(TX.w.pic(name));
    else if (s.localName === "AudioSource" || s.localName === "VideoSource") {
      const tr = kids(s, "Transcript");
      if (!tr.length) notes.push(TX.w.media(name));
      for (const t of tr) await addText(t, name + (tr.length > 1 ? " – " + (attr(t, "name") || "") : ""), tr.length === 1 ? guid : attr(t, "guid"), "txt", s);
    }
  }
  // Fälle und Sets -> Variablen
  for (const c of kids(kid(root, "Cases"), "Case")) {
    const v = readVars(c), cname = attr(c, "name");
    for (const r of kids(c, "SourceRef")) {
      const src = srcByGuid.get(attr(r, "targetGUID"));
      if (src) { Object.assign(src.vars, v); if (cname) src.vars[TX.vCase] = cname; }
    }
  }
  let codeSets = 0;
  for (const st of kids(kid(root, "Sets"), "Set")) {
    const members = kids(st, "MemberSource");
    if (!members.length && kids(st, "MemberCode").length) { codeSets++; continue; }
    for (const m of members) {
      const src = srcByGuid.get(attr(m, "targetGUID"));
      if (src) src.vars[TX.vSet] = src.vars[TX.vSet] ? src.vars[TX.vSet] + ", " + attr(st, "name") : attr(st, "name");
    }
  }
  if (codeSets) notes.push(TX.w.codeset(codeSets));
  const nLinks = kids(kid(root, "Links"), "Link").length; if (nLinks) notes.push(TX.w.links(nLinks));
  const nGraphs = kids(kid(root, "Graphs"), "Graph").length; if (nGraphs) notes.push(TX.w.graphs(nGraphs));
  const nUsers = kids(kid(root, "Users"), "User").length; if (nUsers) notes.push(TX.w.users(nUsers));

  return {
    kind: root.localName === "CodeBook" ? "codebook" : "project",
    projName: attr(root, "name") || file.name.replace(/\.[^.]+$/, ""), origin: attr(root, "origin") || "",
    projDesc: txt(kid(root, "Description")), projNotes: kids(root, "NoteRef").map((r) => attr(r, "targetGUID")),
    codes, codeByGuid, noteByGuid, sources, notes
  };
}

/* ---------- 4. Text normalisieren, Positionen umrechnen ---------- */
// jellyqda: CRLF -> LF, NFC, Leerraum am Ende weg; Positionen sind Zeichen (Codepoints), 1-basiert, Ende inklusive.
// REFI-QDA: Codepoints ab 0, Ende exklusiv. Falls MAXQDA Textausschnitte mitliefert, wird die Zählweise geprüft.
const squash = (s) => s.replace(/\r\n?/g, "\n").normalize("NFC").replace(/\s+/g, " ").trim();
function detectShift(cps, sels) {
  const tests = sels.filter((s) => s.name && squash(s.name).length >= 4).slice(0, 400);
  if (!tests.length) return { ds: 0, de: 0, checked: 0, ok: 0 };
  const score = (ds, de) => tests.reduce((a, s) => {
    const got = squash(cps.slice(Math.max(0, s.s + ds), Math.max(0, s.e + de)).join("")), want = squash(s.name);
    const n = Math.min(got.length, want.length, 60);
    return a + (n >= 3 && got.slice(0, n) === want.slice(0, n) && Math.abs(got.length - want.length) <= Math.max(2, want.length * 0.02) ? 1 : 0);
  }, 0);
  const H = [[0, 0], [0, 1], [-1, 0], [-1, -1], [1, 1]];
  let best = H[0], bs = score(0, 0);
  for (const h of H.slice(1)) { const v = score(h[0], h[1]); if (v > bs * 1.5 && v > tests.length * 0.3) { best = h; bs = v; } }
  return { ds: best[0], de: best[1], checked: tests.length, ok: bs };
}
function convertText(raw, sels) {
  const cps = Array.from(raw);
  const shift = detectShift(cps, sels);
  // CRLF/CR -> LF mit Positions-Abbildung
  const map = new Int32Array(cps.length + 1), out = [];
  for (let i = 0; i < cps.length; i++) {
    map[i] = out.length;
    if (cps[i] === "\r") { if (cps[i + 1] === "\n") continue; out.push("\n"); } else out.push(cps[i]);
  }
  map[cps.length] = out.length;
  const clamp = (p) => Math.max(0, Math.min(cps.length, p));
  const pos = sels.map((s) => [map[clamp(s.s + shift.ds)], map[clamp(s.e + shift.de)]]);
  // NFC stückweise zwischen allen Markierungsgrenzen
  const bounds = Array.from(new Set([0, out.length].concat(...pos))).sort((a, b) => a - b);
  const nmap = new Map(); let text = "", len = 0;
  for (let k = 0; k < bounds.length; k++) {
    nmap.set(bounds[k], len);
    if (k < bounds.length - 1) { const piece = out.slice(bounds[k], bounds[k + 1]).join("").normalize("NFC"); text += piece; len += Array.from(piece).length; }
  }
  text = text.replace(/[ \t\n]+$/, "");
  const L = Array.from(text).length;
  const res = pos.map(([a, b]) => { const s = Math.min(nmap.get(a), L), e = Math.min(nmap.get(b), L); return e > s ? [s + 1, e] : null; });
  return { text, len: L, pos: res, shift };
}

/* ---------- 5. Modell für jellyqda bauen ---------- */
const PALETTE = ["#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7", "#999999"];
const now = () => new Date().toISOString().replace(/\.\d+Z$/, "Z");
const normColor = (c) => {
  if (!c) return null;
  const m = /^#?([0-9a-f]{8}|[0-9a-f]{6})$/i.exec(c.trim());
  if (!m) return null;
  const h = m[1].length === 8 ? m[1].slice(2) : m[1];   // #AARRGGBB -> #RRGGBB
  return "#" + h.toUpperCase();
};
async function sha256(text) {
  try { const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)); return Array.from(new Uint8Array(d)).map((b) => b.toString(16).padStart(2, "0")).join(""); }
  catch (e) { return null; }
}
async function buildModel(P, fileName) {
  const notes = P.notes.slice(), t = now();
  const origin = (P.origin || "REFI-QDA").trim();
  // Codes
  const codeRows = [], codeId = new Map(), seen = new Set();
  let pal = 0;
  P.codes.forEach((c) => {
    let label = c.name.replace(/\s+/g, " ").trim() || TX.noname;
    if (label.includes("/")) { const l2 = label.replace(/\s*\/\s*/g, " – "); notes.push(TX.w.slash(label)); label = l2; }
    const pid = c.parent ? codeId.get(c.parent) : null;
    if (!pid && label === "Memo" && !P.codes.some((x) => x.parent === c)) { label = "Memo (MAXQDA)"; notes.push(TX.w.memo); }
    let l = label, k = 2;
    while (seen.has((pid || 0) + "\u0000" + l)) l = label + " (" + k++ + ")";
    if (l !== label) notes.push(TX.w.dup(label, l));
    seen.add((pid || 0) + "\u0000" + l);
    const parentRow = pid ? codeRows[pid - 1] : null;
    const color = normColor(c.color) || (parentRow ? parentRow.color : PALETTE[pal++ % PALETTE.length]);
    const id = codeRows.length + 1;
    codeRows.push({ id, label: l, parent_id: pid, color, description: c.desc || "", src: c });
    codeId.set(c, id);
  });
  // Dokumente, Codings
  const srcRows = [], codingRows = [], memoRows = [], events = [];
  let nocode = 0, nVars = new Set(), check = { checked: 0, ok: 0, shifted: null };
  const usedNames = new Set();
  const addMemo = (ref, kind, extra) => {
    const n = P.noteByGuid.get(ref); if (!n) return;
    n.used = true;
    memoRows.push(Object.assign({ id: memoRows.length + 1, text_: n.text, created_at: n.created || t, kind, title: n.name, source_id: null, code_id: null, start: null, end: null, updated_at: n.created || t }, extra));
  };
  for (const s of P.sources) {
    const cv = convertText(s.text, s.sels);
    check.checked += cv.shift.checked; check.ok += cv.shift.ok;
    if (cv.shift.ds || cv.shift.de) check.shifted = (cv.shift.ds === -1 ? (LANG === "de" ? "ab 1" : "from 1") : "") + (cv.shift.de === 1 ? (LANG === "de" ? " mit eingeschlossenem Ende" : " with inclusive end") : "");
    let name = s.name, k = 2;
    while (usedNames.has(name)) name = s.name + " (" + k++ + ")";
    usedNames.add(name);
    const id = srcRows.length + 1;
    Object.keys(s.vars).forEach((v) => nVars.add(v));
    const meta = { file: name, original: null, sha256: await sha256(cv.text), encoding: "UTF-8", pages: null, format: s.format, imported_at: t,
      converted_from: origin, qdpx_file: fileName, variables: s.vars };
    if (!Object.keys(s.vars).length) delete meta.variables;
    srcRows.push({ id, name, format: s.format, frozen_text: cv.text, meta_json: JSON.stringify(meta), chars: cv.len, codings: 0 });
    let outside = 0;
    s.sels.forEach((sel, i) => {
      const p = cv.pos[i];
      if (!p) { if (sel.codes.length || sel.notes.length) outside++; return; }
      sel.codes.forEach((g) => {
        const c = P.codeByGuid.get(g), cid = c && codeId.get(c);
        if (!cid) { nocode++; return; }
        codingRows.push({ id: codingRows.length + 1, source_id: id, code_id: cid, start: p[0], end: p[1], memo: sel.comment || "", paraphrase: "", generalization: "" });
        srcRows[id - 1].codings++;
      });
      if (!sel.codes.length && sel.comment) memoRows.push({ id: memoRows.length + 1, text_: sel.comment, created_at: sel.created || t, kind: "passage", title: "", source_id: id, code_id: null, start: p[0], end: p[1], updated_at: sel.created || t });
      sel.notes.forEach((g) => addMemo(g, "passage", { source_id: id, start: p[0], end: p[1] }));
    });
    if (outside) notes.push(TX.w.outside(name, outside));
    if (s.desc) memoRows.push({ id: memoRows.length + 1, text_: s.desc, created_at: t, kind: "document", title: TX.descMemo, source_id: id, code_id: null, start: null, end: null, updated_at: t });
    s.notes.forEach((g) => addMemo(g, "document", { source_id: id }));
  }
  if (nocode) notes.push(TX.w.nocode(nocode));
  codeRows.forEach((c) => c.src.notes.forEach((g) => addMemo(g, "code", { code_id: c.id })));
  if (P.projDesc) memoRows.push({ id: memoRows.length + 1, text_: P.projDesc, created_at: t, kind: "project", title: TX.projMemo, source_id: null, code_id: null, start: null, end: null, updated_at: t });
  P.projNotes.forEach((g) => addMemo(g, "project", {}));
  for (const [, n] of P.noteByGuid) if (!n.used && n.text) { n.used = true; memoRows.push({ id: memoRows.length + 1, text_: n.text, created_at: n.created || t, kind: "project", title: n.name, source_id: null, code_id: null, start: null, end: null, updated_at: n.created || t }); }
  // Protokoll (nur System-Ereignisse, die Rückgängig nicht beeinflussen)
  const outName = (P.projName || "projekt").replace(/[\\/:*?"<>|]+/g, "-").trim() + ".jellyqda";
  events.push({ action: "project_create", details: JSON.stringify({ file: outName }), created_at: t });
  srcRows.forEach((s) => events.push({ action: "import", details: JSON.stringify({ source_id: s.id, file: s.name, format: s.format, chars: s.chars, sha256: JSON.parse(s.meta_json).sha256, warning: false, converted_from: origin }), created_at: t }));
  events.push({ action: "qdpx_convert", details: JSON.stringify({ file: fileName, origin, sources: srcRows.length, codes: codeRows.length, codings: codingRows.length, memos: memoRows.length, notes, desc: TX.conv + " " + fileName }), created_at: t });
  events.forEach((e, i) => e.id = i + 1);
  return { srcRows, codeRows, codingRows, memoRows, events, notes, nVars: nVars.size, check, outName, origin };
}

/* ---------- 6. SQLite-Datei schreiben ---------- */
// Minimaler Writer für das dokumentierte SQLite-Dateiformat (https://sqlite.org/fileformat2.html):
// Tabellen-B-Bäume mit Überlaufseiten. Indizes legt jellyqda beim ersten qda_open() selbst an.
const SCHEMA = {
  sources: "CREATE TABLE sources (\n      id INTEGER PRIMARY KEY AUTOINCREMENT,\n      name TEXT NOT NULL,\n      format TEXT NOT NULL,\n      frozen_text TEXT NOT NULL,\n      meta_json TEXT NOT NULL DEFAULT '{}'\n    )",
  codes: "CREATE TABLE codes (\n      id INTEGER PRIMARY KEY AUTOINCREMENT,\n      label TEXT NOT NULL,\n      parent_id INTEGER REFERENCES codes(id) ON DELETE CASCADE,\n      color TEXT NOT NULL DEFAULT '#E69F00',\n      description TEXT NOT NULL DEFAULT '',\n      anchor TEXT DEFAULT '',\n      coding_rule TEXT DEFAULT ''\n    )",
  codings: "CREATE TABLE codings (\n      id INTEGER PRIMARY KEY AUTOINCREMENT,\n      source_id INTEGER NOT NULL REFERENCES sources(id) ON DELETE CASCADE,\n      code_id INTEGER NOT NULL REFERENCES codes(id) ON DELETE CASCADE,\n      start INTEGER NOT NULL,\n      end INTEGER NOT NULL,\n      memo TEXT NOT NULL DEFAULT '',\n      paraphrase TEXT DEFAULT '',\n      generalization TEXT DEFAULT '',\n      CHECK (start >= 1 AND end >= start)\n    )",
  memos: "CREATE TABLE memos (\n      id INTEGER PRIMARY KEY AUTOINCREMENT,\n      text_ TEXT NOT NULL,\n      created_at TEXT NOT NULL,\n      kind TEXT NOT NULL DEFAULT 'project',\n      title TEXT NOT NULL DEFAULT '',\n      source_id INTEGER REFERENCES sources(id) ON DELETE CASCADE,\n      code_id INTEGER REFERENCES codes(id) ON DELETE CASCADE,\n      start INTEGER,\n      end INTEGER,\n      updated_at TEXT\n    )",
  events: "CREATE TABLE events (\n      id INTEGER PRIMARY KEY AUTOINCREMENT,\n      action TEXT NOT NULL,\n      details TEXT NOT NULL DEFAULT '{}',\n      created_at TEXT NOT NULL\n    )"
};
const COLS = {
  sources: ["id", "name", "format", "frozen_text", "meta_json"],
  codes: ["id", "label", "parent_id", "color", "description", "anchor", "coding_rule"],
  codings: ["id", "source_id", "code_id", "start", "end", "memo", "paraphrase", "generalization"],
  memos: ["id", "text_", "created_at", "kind", "title", "source_id", "code_id", "start", "end", "updated_at"],
  events: ["id", "action", "details", "created_at"]
};
function sqliteBytes(M) {
  const PS = 4096, enc = new TextEncoder(), pages = [null];
  const alloc = () => { pages.push(new Uint8Array(PS)); return pages.length; };
  const varint = (n) => { if (n < 0x80) return [n]; const g = []; while (n > 0) { g.unshift(n % 128); n = Math.floor(n / 128); } return g.map((x, i) => i < g.length - 1 ? x | 0x80 : x); };
  const intBytes = (v, n) => { const b = []; let x = v < 0 ? 2 ** (8 * n) + v : v; for (let i = 0; i < n; i++) { b.unshift(x % 256); x = Math.floor(x / 256); } return b; };
  function record(vals) {
    const types = [], body = [];
    for (const v of vals) {
      if (v === null || v === undefined) types.push(0);
      else if (typeof v === "number") {
        if (v === 0) types.push(8); else if (v === 1) types.push(9);
        else { const sizes = [[1, 1], [2, 2], [3, 3], [4, 4], [5, 6], [6, 8]]; const [t, n] = sizes.find(([, n]) => v >= -(2 ** (8 * n - 1)) && v < 2 ** (8 * n - 1)); types.push(t); body.push(...intBytes(v, n)); }
      } else { const b = enc.encode(String(v)); types.push(13 + 2 * b.length); for (let i = 0; i < b.length; i++) body.push(b[i]); }
    }
    const th = types.flatMap(varint); let hs = th.length + 1;
    while (varint(hs).length + th.length !== hs) hs = varint(hs).length + th.length;
    const out = new Uint8Array(hs + body.length);
    out.set(varint(hs)); out.set(th, varint(hs).length); out.set(body, hs);
    return out;
  }
  function leafCell(rowid, payload) {
    const U = PS, P = payload.length, X = U - 35, Mn = Math.floor((U - 12) * 32 / 255) - 23;
    let local = P;
    if (P > X) { const K = Mn + ((P - Mn) % (U - 4)); local = K <= X ? K : Mn; }
    const head = varint(P).concat(varint(rowid));
    const cell = new Uint8Array(head.length + local + (local < P ? 4 : 0));
    cell.set(head); cell.set(payload.subarray(0, local), head.length);
    if (local < P) {
      let rest = payload.subarray(local), prev = null, first = 0;
      while (rest.length) {
        const pg = alloc(), chunk = rest.subarray(0, U - 4);
        pages[pg - 1].set(chunk, 4);
        if (prev) new DataView(pages[prev - 1].buffer).setUint32(0, pg); else first = pg;
        prev = pg; rest = rest.subarray(U - 4);
      }
      new DataView(cell.buffer).setUint32(head.length + local, first);
    }
    return cell;
  }
  function writePage(pg, type, cells, right) {
    const p = pages[pg - 1], dv = new DataView(p.buffer), off = pg === 1 ? 100 : 0, hl = right != null ? 12 : 8;
    let pos = PS;
    cells.forEach((c, i) => { pos -= c.length; p.set(c, pos); dv.setUint16(off + hl + 2 * i, pos); });
    p[off] = type; dv.setUint16(off + 1, 0); dv.setUint16(off + 3, cells.length); dv.setUint16(off + 5, cells.length ? pos : PS === 65536 ? 0 : PS); p[off + 7] = 0;
    if (right != null) dv.setUint32(off + 8, right);
  }
  function buildTree(rows, rootOnPage1) {
    const cells = rows.map((r) => ({ key: r[0], c: leafCell(r[0], record(r[1])) }));
    if (rootOnPage1) {
      const used = 100 + 8 + cells.reduce((a, x) => a + 2 + x.c.length, 0);
      if (used > PS) throw new Error("schema too large for page 1");
      writePage(1, 0x0d, cells.map((x) => x.c)); return 1;
    }
    let level = [], cur = [], used = 8;
    const flushLeaf = () => { const pg = alloc(); writePage(pg, 0x0d, cur.map((x) => x.c)); level.push({ pg, key: cur.length ? cur[cur.length - 1].key : 0 }); cur = []; used = 8; };
    for (const x of cells) { if (used + 2 + x.c.length > PS && cur.length) flushLeaf(); cur.push(x); used += 2 + x.c.length; }
    flushLeaf();
    while (level.length > 1) {
      const next = []; let grp = [], u = 12;
      const flush = () => {
        const last = grp[grp.length - 1], pg = alloc();
        const ic = grp.slice(0, -1).map((g) => { const k = varint(g.key), c = new Uint8Array(4 + k.length); new DataView(c.buffer).setUint32(0, g.pg); c.set(k, 4); return c; });
        writePage(pg, 0x05, ic, last.pg); next.push({ pg, key: last.key }); grp = []; u = 12;
      };
      for (const e of level) {
        if (grp.length && u + 2 + 4 + varint(grp[grp.length - 1].key).length > PS) flush();
        if (grp.length) u += 2 + 4 + varint(grp[grp.length - 1].key).length;
        grp.push(e);
      }
      flush(); level = next;
    }
    return level[0].pg;
  }
  pages[0] = new Uint8Array(PS);
  const tables = [["sources", M.srcRows], ["codes", M.codeRows], ["codings", M.codingRows], ["memos", M.memoRows], ["events", M.events]];
  const master = [], seq = [];
  let rid = 1;
  for (const [name, rows] of tables) {
    const root = buildTree(rows.map((r) => [r.id, COLS[name].map((c) => c === "id" ? null : r[c] === undefined ? null : r[c])]));
    master.push([rid++, ["table", name, name, root, SCHEMA[name]]]);
    if (name === "sources") master.push([rid++, ["table", "sqlite_sequence", "sqlite_sequence", -1, "CREATE TABLE sqlite_sequence(name,seq)"]]);
    if (rows.length) seq.push([seq.length + 1, [name, rows[rows.length - 1].id]]);
  }
  const seqRoot = buildTree(seq);
  master.forEach((m) => { if (m[1][3] === -1) m[1][3] = seqRoot; });
  buildTree(master, true);
  const h = new DataView(pages[0].buffer);
  enc.encodeInto("SQLite format 3\u0000", pages[0]);
  h.setUint16(16, PS); pages[0][18] = 1; pages[0][19] = 1; pages[0][20] = 0; pages[0][21] = 64; pages[0][22] = 32; pages[0][23] = 32;
  h.setUint32(24, 1); h.setUint32(28, pages.length); h.setUint32(40, 1); h.setUint32(44, 4); h.setUint32(56, 1); h.setUint32(92, 1); h.setUint32(96, 3045001);
  const out = new Uint8Array(pages.length * PS);
  pages.forEach((p, i) => out.set(p, i * PS));
  return out;
}

/* ---------- 7. Oberfläche ---------- */
const $ = (id) => document.getElementById(id);
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
let RESULT = null;
const cpSlice = (text, s, e) => Array.from(text).slice(s - 1, e).join("");
function treeHtml(rows) {
  const by = new Map(); rows.forEach((r) => { const k = r.parent_id || 0; if (!by.has(k)) by.set(k, []); by.get(k).push(r); });
  const cnt = new Map(); RESULT.M.codingRows.forEach((c) => cnt.set(c.code_id, (cnt.get(c.code_id) || 0) + 1));
  const sum = (id) => (cnt.get(id) || 0) + (by.get(id) || []).reduce((a, r) => a + sum(r.id), 0);
  const rec = (pid, depth) => (by.get(pid) || []).map((r) => '<li style="--fc:' + r.color + '"><span class="' + (depth ? "sc" : "cf") + '">' + esc(r.label) + '</span><span class="n">' + sum(r.id) + "</span>" + (by.has(r.id) ? "<ul>" + rec(r.id, depth + 1) + "</ul>" : "") + "</li>").join("");
  return '<ul class="tree">' + rec(0, 0) + "</ul>";
}
function sampleHtml() {
  const M = RESULT.M, C = M.codingRows;
  if (!C.length) return "";
  const pick = C.length <= 5 ? C : Array.from({ length: 5 }, () => C[Math.floor(Math.random() * C.length)]);
  const path = (id) => { const r = M.codeRows[id - 1]; return r.parent_id ? path(r.parent_id) + " / " + r.label : r.label; };
  return pick.map((c) => {
    const s = M.srcRows[c.source_id - 1], t = cpSlice(s.frozen_text, c.start, c.end);
    return '<div class="smp"><div class="sh"><span class="dot" style="background:' + M.codeRows[c.code_id - 1].color + '"></span><b>' + esc(path(c.code_id)) + "</b><small>" + esc(s.name) + " · " + c.start + "–" + c.end + "</small></div><q>" + esc(t.length > 280 ? t.slice(0, 277) + " …" : t) + "</q></div>";
  }).join("");
}
function render() {
  const R = RESULT, M = R.M;
  const ck = M.check;
  $("result").innerHTML =
    '<div class="kpis5">' + [M.srcRows.length, M.codeRows.length, M.codingRows.length, M.memoRows.length, M.nVars].map((v, i) => "<div><b>" + v + "</b><span>" + TX.k[i] + "</span></div>").join("") + "</div>" +
    '<p class="small muted">' + TX.origin + ": <b>" + esc(M.origin || "REFI-QDA") + "</b> · " + esc(R.file) + "</p>" +
    (ck.checked ? '<div class="box ' + (ck.ok >= ck.checked * 0.9 ? "tip" : "warn") + '"><span>' + (ck.ok >= ck.checked * 0.9 ? "✅" : "⚠️") + "</span><div><b>" + TX.check + "</b>" + TX.checkOk(ck.ok, ck.checked) + (ck.shifted ? " " + TX.checkShift(ck.shifted) : "") + "</div></div>"
      : M.codingRows.length ? '<div class="box warn"><span>🔎</span><div><b>' + TX.check + "</b>" + TX.checkNone + "</div></div>" : "") +
    (M.codeRows.length ? '<h4>' + TX.tree + "</h4>" + treeHtml(M.codeRows) : "") +
    (M.srcRows.length ? "<h4>" + TX.docs + '</h4><div class="list">' + M.srcRows.map((s) => '<div class="li"><span class="t"><b>' + esc(s.name) + "</b><small>" + TX.docChars(s.chars) + " · " + TX.docCod(s.codings) + (JSON.parse(s.meta_json).variables ? " · " + esc(Object.entries(JSON.parse(s.meta_json).variables).map(([k, v]) => k + ": " + v).join(", ")) : "") + "</small></span></div>").join("") + "</div>" : "") +
    (M.codingRows.length ? "<h4>" + TX.sample + '</h4><p class="small muted" style="margin-top:0">' + TX.sampleD + '</p><div id="smp">' + sampleHtml() + '</div><button class="btn small" id="again">' + TX.again + "</button>" : "") +
    "<h4>" + TX.warnT + "</h4>" + (M.notes.length ? '<ul class="warns">' + Array.from(new Set(M.notes)).map((n) => "<li>" + esc(n) + "</li>").join("") + "</ul>" : '<p class="small">' + TX.noWarn + "</p>");
  $("fname").value = M.outName;
  $("step3").hidden = false; $("step4").hidden = false;
  const again = $("again"); if (again) again.onclick = () => { $("smp").innerHTML = sampleHtml(); };
  $("step3").scrollIntoView({ behavior: "smooth", block: "start" });
}
async function handle(file) {
  $("err").hidden = true; $("busy").hidden = false; $("step3").hidden = true; $("step4").hidden = true;
  try {
    const P = await readProject(file);
    const M = await buildModel(P, file.name);
    const bytes = sqliteBytes(M);
    RESULT = { M, bytes, file: file.name };
    render();
  } catch (e) {
    console.error(e);
    $("err").textContent = e.user ? e.message : (LANG === "de" ? "Unerwarteter Fehler: " : "Unexpected error: ") + e.message;
    $("err").hidden = false;
  } finally { $("busy").hidden = true; }
}
function save() {
  if (!RESULT) return;
  let n = $("fname").value.trim() || RESULT.M.outName;
  if (!/\.jellyqda$/i.test(n)) n += ".jellyqda";
  const url = URL.createObjectURL(new Blob([RESULT.bytes], { type: "application/vnd.sqlite3" }));
  const a = document.createElement("a"); a.href = url; a.download = n; document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 4000);
  const b = $("save"); b.textContent = TX.saved; setTimeout(() => { b.innerHTML = SAVE_LABEL; }, 2000);
  $("rcode").textContent = 'library(jellyqda)\nqda_open("' + n + '")\nqda_app()';
}
let SAVE_LABEL = "";
function init() {
  try { const t = localStorage.getItem("jellyqda-assistenz-v1"); const th = t && JSON.parse(t).theme; if (th) document.documentElement.setAttribute("data-theme", th); } catch (e) {}
  if (!document.documentElement.getAttribute("data-theme")) document.documentElement.setAttribute("data-theme", matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark");
  document.querySelectorAll("[data-t]").forEach((el) => { const v = el.dataset.t.split(".").reduce((o, k) => o[k], TX); el.innerHTML = Array.isArray(v) ? v.map((x) => "<li>" + x + "</li>").join("") : v; });
  const ol = $("langlink"); ol.href = TX.other.href; ol.textContent = TX.other.label; ol.title = TX.other.title;
  $("themebtn").setAttribute("aria-label", TX.theme);
  $("themebtn").onclick = () => {
    const th = document.documentElement.getAttribute("data-theme") === "light" ? "dark" : "light";
    document.documentElement.setAttribute("data-theme", th);
    try { const s = JSON.parse(localStorage.getItem("jellyqda-assistenz-v1") || "{}"); s.theme = th; localStorage.setItem("jellyqda-assistenz-v1", JSON.stringify(s)); } catch (e) {}
  };
  SAVE_LABEL = $("save").innerHTML;
  const dz = $("drop"), fi = $("file");
  dz.addEventListener("dragover", (e) => { e.preventDefault(); dz.classList.add("over"); });
  dz.addEventListener("dragleave", () => dz.classList.remove("over"));
  dz.addEventListener("drop", (e) => { e.preventDefault(); dz.classList.remove("over"); if (e.dataTransfer.files[0]) handle(e.dataTransfer.files[0]); });
  fi.addEventListener("change", () => { if (fi.files[0]) handle(fi.files[0]); fi.value = ""; });
  $("save").onclick = save;
  $("reset").onclick = () => { RESULT = null; $("step3").hidden = true; $("step4").hidden = true; window.scrollTo({ top: 0, behavior: "smooth" }); };
  $("rcode").textContent = 'library(jellyqda)\nqda_open("projekt.jellyqda")\nqda_app()';
}
init();
// Für Tests: window.__jq = { readProject, buildModel, sqliteBytes }
window.__jq = { readProject, buildModel, sqliteBytes };
})();
