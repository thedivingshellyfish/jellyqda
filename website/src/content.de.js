/* ---------- 1. Inhalte: Interviewformen ---------- */
// st = Passung zum Strukturierungsgrad (2 passt gut, 1 möglich, 0 eher nicht)
// lg = Passung zur Auswertungslogik; good/ok = typische Auswertungsverfahren
const IV = {
  pzi: {
    em: "🎯", name: "Problemzentriertes Interview", by: "Witzel",
    short: "Subjektive Sicht auf ein gesellschaftlich relevantes Problem – Erzählen und gezieltes Nachfragen im Wechsel.",
    wissen: "Erfahrungen, Sichtweisen und Handlungsbegründungen der Befragten zu einem klar umrissenen Problem.",
    pos: [.42, .52],
    st: { offen: 1, halboffen: 2, strukturiert: 0 },
    stNote: { offen: "Geht, wenn du den Leitfaden nur als Gedächtnisstütze im Kopf hast – das PZI braucht aber dein Vorwissen als Rahmen.", halboffen: "Genau dafür gemacht: Leitfaden als Gerüst, Erzählungen bekommen Raum.", strukturiert: "Feste Fragen verhindern die Nachfragen (Sondierungen), von denen das PZI lebt." },
    lg: { de: 1, in: 1, mix: 2, ab: 1 },
    lgNote: "Witzel beschreibt das PZI ausdrücklich als Wechselspiel von Induktion und Deduktion – deduktiv-induktiv ist der Normalfall.",
    ablauf: [["Kurzfragebogen", "Sozialdaten vorab, damit sie das Gespräch nicht stören"], ["Erzählaufforderung", "offener Einstieg ins Problemfeld"], ["Allgemeine Sondierung", "Erzählungen vertiefen: „Wie war das genau?“"], ["Spezifische Sondierung", "Zurückspiegeln, Verständnisfragen, ggf. Konfrontation"], ["Ad-hoc-Fragen", "Leitfadenthemen, die noch fehlen"], ["Postskript", "direkt danach: Eindrücke, Atmosphäre, Auffälligkeiten"]],
    achten: ["Dein Vorwissen ist erlaubt und gewollt – aber als <b>sensibilisierendes Konzept</b>, nicht als Hypothesen, die du abfragst.", "Der Leitfaden ist eine Gedächtnisstütze, kein Fragebogen: Reihenfolge flexibel halten.", "Verständnisfragen und Zurückspiegeln nicht suggestiv formulieren („Sie meinen also, dass …?“ sparsam einsetzen).", "Postskript gleich nach dem Gespräch schreiben – es wird später ein Dokument-Memo in jellyqda."],
    auswertung: "Hauptkategorien kannst du aus den Leitfadenthemen ableiten, Subkategorien entstehen am Material. Typisch: inhaltlich strukturierende QIA nach Kuckartz oder eine Kombination aus Mayrings strukturierender und zusammenfassender Analyse.",
    good: ["kuckartz_s", "mayring_s", "mayring_z", "thema"], ok: ["gt", "kuckartz_t", "kuckartz_e", "flick"]
  },
  exp_theo: {
    em: "🧠", name: "Theoriegenerierendes Experteninterview", alt: "auch „theoretisierendes“ Experteninterview", by: "Bogner, Littig & Menz; Meuser & Nagel",
    short: "Expert:innen als Träger:innen von Deutungswissen – Ziel ist eine Theorie über ihre Sichtweisen und Handlungslogiken.",
    wissen: "Deutungswissen: subjektive Relevanzen, Regeln, Sichtweisen und Interpretationen der Expert:innen – oft implizit, nicht einfach abfragbar.",
    pos: [.4, .55],
    st: { offen: 1, halboffen: 2, strukturiert: 0 },
    stNote: { offen: "Möglich, wenn du sehr explorativ arbeitest – aber ohne Leitfaden wird der Vergleich zwischen Expert:innen schwer.", halboffen: "Passt: Der Leitfaden sichert Vergleichbarkeit und kompetentes Auftreten, lässt aber Raum für Deutungen.", strukturiert: "Deutungswissen zeigt sich in Begründungen und Beispielen – feste Fragen schneiden genau das ab." },
    lg: { de: 0, in: 2, mix: 2, ab: 1 },
    lgNote: "Theorie soll aus dem Material entstehen. Induktiv oder deduktiv-induktiv (Hauptthemen aus dem Leitfaden, Konzepte am Material) passen; rein deduktiv widerspricht dem Ziel.",
    ablauf: [["Feldzugang & Rolle", "Wer ist warum Expert:in? Sampling begründen"], ["Einstieg", "Funktion, Aufgaben, Werdegang"], ["Leitfadenblöcke", "offene Fragen zu Problemsichten und Entscheidungen"], ["Nachfragen", "Begründungen, Beispiele, Gegenbeispiele"], ["Abschluss", "„Was haben wir nicht angesprochen?“"], ["Postskript", "Interaktion & Rollenzuschreibung notieren"]],
    achten: ["Frag nicht nur nach Fakten („Wie läuft X ab?“), sondern nach <b>Begründungen und Bewertungen</b> („Warum halten Sie das für sinnvoll?“) – dort steckt das Deutungswissen.", "Reflektiere, als was dich die Expert:innen wahrnehmen (Co-Expert:in, Laie, Kritiker:in …) – das prägt die Antworten. Ins Postskript damit.", "Kleine Felder = hohe Wiedererkennbarkeit: Funktion, Organisation und Anekdoten konsequent pseudonymisieren.", "Den Expert:innen-Status im Methodenteil begründen (Wissen kraft Position, Erfahrung, Zuständigkeit)."],
    auswertung: "Ziel ist Konzept- und Theoriebildung: textnah kodieren (auch in vivo), dann thematisch über alle Interviews vergleichen und schrittweise abstrahieren. Klassisch ist die Auswertung nach Meuser & Nagel; auch Grounded Theory oder Kuckartz mit starkem induktiven Anteil passen.",
    good: ["meuser", "gt", "kuckartz_s"], ok: ["mayring_z", "thema", "kuckartz_t"]
  },
  exp_sys: {
    em: "🗂️", name: "Systematisierendes Experteninterview", by: "Bogner, Littig & Menz; Gläser & Laudel",
    short: "Expert:innen als Quelle für exklusives Fakten- und Prozesswissen – möglichst vollständig und vergleichbar.",
    wissen: "Technisches Wissen und Prozesswissen: Abläufe, Zuständigkeiten, Ereignisse, die nur sie kennen.",
    pos: [.6, .78],
    st: { offen: 0, halboffen: 2, strukturiert: 1 },
    stNote: { offen: "Ohne Leitfaden fehlen dir am Ende Informationen, die du systematisch brauchst.", halboffen: "Passt: Leitfaden aus der Theorie, Raum für Nachfragen zu Details.", strukturiert: "Möglich, wenn das Feld schon gut bekannt ist – du verlierst aber unerwartete Informationen." },
    lg: { de: 2, in: 0, mix: 2, ab: 0 },
    lgNote: "Du suchst Informationen zu theoretisch bestimmten Dimensionen – deduktiv mit offenem Kategoriensystem (neue Ausprägungen dürfen dazukommen).",
    ablauf: [["Theorie & Variablen", "Was genau musst du wissen?"], ["Leitfaden", "Themenblöcke je Dimension"], ["Interview", "gezielt, aber mit Detailnachfragen"], ["Prüfen", "Widersprüche zwischen Quellen notieren"]],
    achten: ["Leitfaden theoriebasiert und vollständig – jede Frage sollte einer Untersuchungsdimension zugeordnet sein.", "Angaben verschiedener Expert:innen vergleichen (Triangulation), Widersprüche in Memos festhalten.", "Nicht zu früh nach Bewertungen fragen, sonst färbt das die Faktenschilderung."],
    auswertung: "Informationen werden entlang vorab definierter Kategorien aus dem Text gezogen (Extraktion nach Gläser & Laudel) – das Kategoriensystem bleibt offen für neue Ausprägungen. Alternativ Mayrings strukturierende Inhaltsanalyse.",
    good: ["glaeser", "mayring_s", "kuckartz_s"], ok: ["kuckartz_e", "meuser"]
  },
  exp_expl: {
    em: "🧭", name: "Exploratives Experteninterview", by: "Bogner, Littig & Menz",
    short: "Erste Orientierung in einem neuen Feld – oft als Vorstudie für Leitfaden oder Hypothesen.",
    wissen: "Kontextwissen über ein noch unbekanntes Feld: Wer ist wichtig? Welche Themen gibt es?",
    pos: [.2, .5],
    st: { offen: 2, halboffen: 2, strukturiert: 0 },
    stNote: { offen: "Passt: Du weißt noch wenig – lass dir das Feld erklären.", halboffen: "Passt: Ein grober Themenleitfaden hilft, nichts Wichtiges zu vergessen.", strukturiert: "Zu früh: Für feste Fragen kennst du das Feld noch nicht gut genug." },
    lg: { de: 0, in: 2, mix: 1, ab: 1 },
    lgNote: "Explorativ heißt: Themen aus dem Material gewinnen – induktiv.",
    ablauf: [["Feld skizzieren", "Akteure, Themen, Begriffe"], ["Offenes Gespräch", "grobe Themenliste"], ["Notizen / Protokoll", "Transkript nicht immer nötig"], ["Ergebnis", "Leitfaden oder Fragestellung schärfen"]],
    achten: ["Als Vorstudie kennzeichnen – die Ergebnisse tragen meist nicht als eigenständiger Befund.", "Breit fragen, Begriffe des Feldes sammeln (sie werden später deine In-vivo-Codes).", "Ein ausführliches Gesprächsprotokoll kann reichen – in jellyqda importierst du es wie ein Transkript."],
    auswertung: "Themen und Begriffe induktiv sammeln und ordnen, z. B. zusammenfassend nach Mayring oder mit einer thematischen Analyse. Ergebnis ist oft ein besserer Leitfaden.",
    good: ["mayring_z", "thema", "kuckartz_s"], ok: ["gt"]
  },
  narrativ: {
    em: "📖", name: "Narratives Interview", by: "Schütze",
    short: "Eine große Stegreiferzählung, z. B. die eigene Lebensgeschichte – die Befragten bestimmen Struktur und Relevanzen.",
    wissen: "Erfahrungsaufschichtung und Prozessstrukturen des Lebenslaufs, wie sie sich in der Erzählung zeigen.",
    pos: [.02, .14],
    st: { offen: 2, halboffen: 0, strukturiert: 0 },
    stNote: { offen: "Nur so: Die Erzählung darf nicht durch Fragen gesteuert werden.", halboffen: "Ein Leitfaden im Hauptteil zerstört die Stegreiferzählung. Nachfragen gibt es erst danach.", strukturiert: "Widerspricht dem Verfahren grundsätzlich." },
    lg: { de: 0, in: 1, mix: 0, ab: 2 },
    lgNote: "Narrative Interviews werden meist rekonstruktiv (sequenziell, abduktiv) ausgewertet. Reine Kategorienzuordnung zerschneidet die Erzählung.",
    ablauf: [["Erzählaufforderung", "eine einzige, gut vorbereitete Eingangsfrage"], ["Haupterzählung", "nicht unterbrechen, nur aktiv zuhören"], ["Immanente Nachfragen", "an Lücken der Erzählung anknüpfen"], ["Exmanente Nachfragen", "eigene Themen, Warum-Fragen"], ["Bilanzierung", "Eigentheorien der Erzählenden"]],
    achten: ["Erzählaufforderung im Pretest prüfen – sie entscheidet über das ganze Interview.", "Pausen aushalten, nicht unterbrechen, keine Bewertungen.", "Viel Zeit einplanen; genau transkribieren (Pausen, Abbrüche, Betonungen), weil die Analyse an der Form ansetzt.", "Interpretation möglichst in einer Gruppe (Interpretationswerkstatt)."],
    auswertung: "Narrationsanalyse: Textsorten unterscheiden (Erzählung, Beschreibung, Argumentation), Sequenz für Sequenz interpretieren, dann kontrastiv vergleichen. jellyqda hilft beim Markieren der Sequenzen und mit Memos – die eigentliche Interpretation passiert im Kopf und in der Gruppe.",
    good: ["narration", "gt", "doku"], ok: ["thema"]
  },
  episodisch: {
    em: "🧩", name: "Episodisches Interview", by: "Flick",
    short: "Verbindet Erzählungen konkreter Situationen mit Fragen nach Begriffen und Definitionen.",
    wissen: "Episodisches Wissen (Erlebtes in Situationen) und semantisches Wissen (Begriffe, Zusammenhänge).",
    pos: [.3, .5],
    st: { offen: 1, halboffen: 2, strukturiert: 0 },
    stNote: { offen: "Geht, aber der gezielte Wechsel zwischen Erzählung und Begriffsfrage braucht einen Leitfaden.", halboffen: "Passt: Leitfaden mit Erzählaufforderungen und Definitionsfragen.", strukturiert: "Situationserzählungen brauchen Raum – feste Fragen sind zu eng." },
    lg: { de: 1, in: 1, mix: 2, ab: 1 },
    lgNote: "Flicks thematisches Kodieren arbeitet fallbezogen und dann vergleichend mit einer am Material entwickelten thematischen Struktur – meist deduktiv-induktiv.",
    ablauf: [["Interviewprinzip erklären", "„Ich bitte Sie immer wieder, Situationen zu erzählen“"], ["Erzählaufforderungen", "„Erzählen Sie eine Situation, in der …“"], ["Begriffsfragen", "„Was verbinden Sie mit …?“"], ["Alltag & Wandel", "Routinen, Veränderungen"], ["Abschluss", "Feedback, Postskript"]],
    achten: ["Das Prinzip zu Beginn erklären, sonst erzählen Befragte nur abstrakt.", "Bewusst zwischen Situation und Definition wechseln.", "Nach konkreten Beispielen fragen, wenn Antworten allgemein bleiben."],
    auswertung: "Thematisches Kodieren (Flick): erst jeden Fall kurz beschreiben und einzeln kodieren, dann eine gemeinsame thematische Struktur bilden und Fälle vergleichen – Summary Grid und Fallvergleich in jellyqda passen dazu.",
    good: ["flick", "kuckartz_s", "thema"], ok: ["mayring_z", "gt"]
  },
  fokussiert: {
    em: "🎬", name: "Fokussiertes Interview", by: "Merton & Kendall",
    short: "Alle Befragten erleben denselben Stimulus (Film, Text, Situation) – das Interview fragt nach den Reaktionen darauf.",
    wissen: "Subjektive Reaktionen und Deutungen zu einem gemeinsamen, vorher analysierten Stimulus.",
    pos: [.5, .72],
    st: { offen: 0, halboffen: 2, strukturiert: 1 },
    stNote: { offen: "Ohne Leitfaden verlierst du den Bezug zum Stimulus.", halboffen: "Passt: Leitfaden aus der Stimulus-Analyse, offen für unerwartete Reaktionen.", strukturiert: "Möglich, aber Merton & Kendall betonen ausdrücklich Nicht-Beeinflussung und Breite." },
    lg: { de: 2, in: 1, mix: 2, ab: 0 },
    lgNote: "Aus der Analyse des Stimulus entstehen Annahmen und Kategorien – oft deduktiv oder deduktiv-induktiv.",
    ablauf: [["Stimulus analysieren", "Annahmen über Wirkungen"], ["Leitfaden", "aus der Analyse"], ["Stimulus zeigen", "gemeinsame Situation"], ["Interview", "unstrukturiert → zunehmend strukturiert"]],
    achten: ["Gütekriterien nach Merton & Kendall: Nicht-Beeinflussung, Spezifität, Erfassung eines breiten Spektrums, Tiefgründigkeit.", "Spezifische Reaktionen erfragen („Welche Szene …?“), nicht allgemeine Meinungen."],
    auswertung: "Kategorien aus der Stimulus-Analyse vorab festlegen (strukturierend), unerwartete Reaktionen induktiv ergänzen.",
    good: ["mayring_s", "kuckartz_s"], ok: ["thema", "kuckartz_e"]
  },
  leitfaden: {
    em: "📋", name: "Leitfadeninterview (allgemein)", alt: "halbstandardisiertes / teilstrukturiertes Interview", by: "Helfferich u. a.",
    short: "Der Allrounder in Abschlussarbeiten: Themenblöcke, offene Fragen, flexible Nachfragen.",
    wissen: "Erfahrungen, Einschätzungen und Begründungen zu vorab festgelegten Themen.",
    pos: [.45, .8],
    st: { offen: 0, halboffen: 2, strukturiert: 1 },
    stNote: { offen: "Dann ist es eher ein narratives Interview – überlege, ob das zu deiner Frage passt.", halboffen: "Passt: so offen wie möglich, so strukturierend wie nötig.", strukturiert: "Möglich, wenn Vergleichbarkeit wichtiger ist als Tiefe." },
    lg: { de: 1, in: 1, mix: 2, ab: 0 },
    lgNote: "Leitfadenthemen liefern Hauptkategorien, Antworten liefern Subkategorien – deduktiv-induktiv ist naheliegend.",
    ablauf: [["Leitfaden nach SPSS", "Sammeln, Prüfen, Sortieren, Subsumieren"], ["Pretest", "mind. ein Probeinterview"], ["Interview", "Erzählaufforderung je Block, dann Nachfragen"], ["Postskript", "direkt danach"]],
    achten: ["Leitfaden mit dem SPSS-Prinzip (Helfferich) entwickeln: Fragen <b>s</b>ammeln, <b>p</b>rüfen, <b>s</b>ortieren, <b>s</b>ubsumieren.", "Offene Erzählaufforderungen statt Ja/Nein-Fragen.", "Leitfaden im Pretest testen und anpassen – Änderungen dokumentieren."],
    auswertung: "Inhaltlich strukturierende QIA (Kuckartz) oder strukturierende QIA (Mayring) mit induktiven Ergänzungen.",
    good: ["kuckartz_s", "mayring_s", "mayring_z", "thema"], ok: ["kuckartz_t", "kuckartz_e", "gt", "glaeser"]
  },
  gruppe: {
    em: "👥", name: "Gruppendiskussion / Fokusgruppe", by: "Bohnsack; Lamnek",
    short: "Mehrere Personen diskutieren zu einem Grundreiz – sichtbar werden kollektive Orientierungen oder ein Meinungsspektrum.",
    wissen: "Kollektive Orientierungen (Gruppendiskussion) oder Meinungsvielfalt (Fokusgruppe).",
    pos: [.12, .5],
    st: { offen: 2, halboffen: 2, strukturiert: 0 },
    stNote: { offen: "Passt für Gruppendiskussionen: die Selbstläufigkeit ist das Ziel.", halboffen: "Passt für Fokusgruppen mit Moderationsleitfaden.", strukturiert: "Reihum feste Fragen = mehrere Einzelinterviews, die Gruppe geht verloren." },
    lg: { de: 1, in: 2, mix: 2, ab: 2 },
    lgNote: "Kollektive Orientierungen werden rekonstruktiv ausgewertet (dokumentarische Methode); Fokusgruppen meist inhaltsanalytisch.",
    ablauf: [["Grundreiz", "offene Eingangsfrage oder Stimulus"], ["Selbstläufige Diskussion", "Moderation hält sich zurück"], ["Immanente Nachfragen", ""], ["Exmanente Nachfragen", "fehlende Themen"]],
    achten: ["Klar entscheiden: Ist die Gruppe oder die einzelne Person die Analyseeinheit?", "Transkript mit eindeutigen Sprecherkürzeln (Am, Bf …) – in jellyqda werden daraus Segmente.", "Zurückhaltend moderieren, Vielredende freundlich bremsen."],
    auswertung: "Rekonstruktiv mit der dokumentarischen Methode (formulierende und reflektierende Interpretation) oder inhaltsanalytisch nach Kuckartz bei Fokusgruppen.",
    good: ["doku", "kuckartz_s", "thema"], ok: ["mayring_z", "mayring_s"]
  }
};

/* ---------- Offenheit ---------- */
const ST = {
  offen: {
    em: "🌊", name: "Offen (narrativ)", short: "Eine Erzählaufforderung, kaum Vorgaben. Die Befragten strukturieren selbst.",
    frage: "„Erzählen Sie doch bitte, wie es dazu kam, dass Sie … – alles, was Ihnen wichtig ist.“",
    folgen: ["Material ist sehr unterschiedlich lang und aufgebaut; Themen tauchen an unvorhersehbaren Stellen auf.", "Induktive oder rekonstruktive Auswertung liegt nahe.", "Ein vorab festes Kategoriensystem passt selten."],
    seg: "Segmente nach <b>Absätzen</b> (oder später von Hand nach Sinnabschnitten) – Sprecherwechsel sind selten, die Redebeiträge riesig.",
    segmode: "blankline", lg: { de: 0, in: 2, mix: 1, ab: 2 }
  },
  halboffen: {
    em: "🧵", name: "Halboffen (leitfadengestützt)", short: "Leitfaden mit Themenblöcken und offenen Fragen, Reihenfolge flexibel, Nachfragen erlaubt.",
    frage: "„Wie erleben Sie die Zusammenarbeit im Team?“ – danach: „Können Sie ein Beispiel erzählen?“",
    folgen: ["Leitfadenthemen liefern ein Gerüst für Hauptkategorien, die Antworten liefern Subkategorien.", "Achtung: Antworten zu einem Thema stehen nicht nur bei „ihrer“ Frage – das ganze Interview kodieren, nicht nur Frage-Antwort-Paare.", "Deduktiv-induktiv ist der Normalfall."],
    seg: "Segmente nach <b>Sprecherwechsel</b> (<code>[00:01:12] B: …</code>) – jede Antwort ein Segment.",
    segmode: "speaker", lg: { de: 1, in: 2, mix: 2, ab: 1 }
  },
  strukturiert: {
    em: "🧱", name: "Strukturiert (fester Leitfaden)", short: "Feste Fragen in fester Reihenfolge, ggf. mit Antwortvorgaben.",
    frage: "„Frage 4: Wie zufrieden sind Sie mit … – bitte begründen Sie kurz.“",
    folgen: ["Hohe Vergleichbarkeit, wenig Tiefe und Überraschung.", "Deduktive Kategorien liegen nahe; Häufigkeiten werden verführerisch – sie bleiben aber qualitativ zu deuten.", "Nahe an der standardisierten Befragung: prüfen, ob ein Fragebogen nicht besser passt."],
    seg: "Segmente nach <b>Sprecherwechsel</b>; jede Antwort ist einer Frage zugeordnet.",
    segmode: "speaker", lg: { de: 2, in: 1, mix: 1, ab: 0 }
  }
};

/* ---------- Auswertungslogik ---------- */
const LG = {
  de: { em: "⬇️", name: "Deduktiv", cls: "de", short: "Kategorien vorab aus Theorie, Forschungsstand oder Leitfaden – dann am Material anwenden.",
    wann: "Wenn es eine tragfähige Theorie gibt und du sie anwenden, prüfen oder ausdifferenzieren willst.",
    risiko: "Du findest nur, was du suchst. Neues fällt durchs Raster – plane deshalb eine Kategorie „Sonstiges“ und Memos für Überraschungen ein.",
    tools: "Kodierleitfaden, Codesystem vorab, Suchtreffer codieren, Code-Matrix" },
  in: { em: "⬆️", name: "Induktiv", cls: "in", short: "Kategorien entstehen schrittweise aus dem Material.",
    wann: "Wenn ein Feld wenig erforscht ist oder die Sicht der Befragten im Mittelpunkt steht.",
    risiko: "Ganz ohne Vorwissen geht es nie. Leg dein Vorwissen offen und achte darauf, nicht in hunderten Mini-Codes zu versinken – regelmäßig verdichten.",
    tools: "In-vivo-Codes, Memos, Codes zusammenführen, Mayring-Tabelle, Worthäufigkeiten, Stichwort im Kontext" },
  mix: { em: "🔁", name: "Deduktiv-induktiv", cls: "mix", short: "Hauptkategorien vorab (z. B. aus dem Leitfaden), Subkategorien am Material.",
    wann: "Der häufigste Weg bei Leitfadeninterviews und in Abschlussarbeiten.",
    risiko: "Im Methodenteil klar trennen: Welche Kategorien waren vorab da, welche sind am Material entstanden? Das jellyqda-Protokoll hilft dabei.",
    tools: "Codes + Subcodes, Kodierleitfaden, In vivo, Summary Grid, Fallvergleich" },
  ab: { em: "🌀", name: "Abduktiv / rekonstruktiv", cls: "ab", short: "Sequenzielle Interpretation: vom überraschenden Befund zur erklärenden Hypothese – und zurück ans Material.",
    wann: "Bei narrativen Interviews und Gruppendiskussionen, wenn implizite Sinnstrukturen rekonstruiert werden sollen.",
    risiko: "Kodieren ist hier nur Hilfsmittel. Die Interpretation braucht Zeit, Sequenzanalyse und möglichst eine Interpretationsgruppe.",
    tools: "Codes als Lesezeichen für Sequenzen, Textstellen-Memos, Bericht mit Randspalte für die Interpretationsgruppe" }
};

/* ---------- Auswertungsverfahren ---------- */
// x: 0 deduktiv … 1 induktiv; y: 0 beschreibend/inhaltsanalytisch … 1 rekonstruktiv; sup: jellyqda-Unterstützung 2/1/0
const PR = {
  mayring_z: { name: "Zusammenfassende Inhaltsanalyse", by: "Mayring", short: "Mayring Z", x: .84, y: .06, la: "l", sup: 2, lg: { de: 0, in: 2, mix: 2, ab: 0 },
    what: "Material wird schrittweise reduziert, bis ein überschaubares, induktiv gebildetes Kategoriensystem bleibt.",
    steps: ["Analyseeinheiten festlegen (Kodier-, Kontext-, Auswertungseinheit)", "Paraphrasieren: Inhalt knapp in eigenen Worten", "Generalisieren auf das gewählte Abstraktionsniveau", "Erste Reduktion: Bedeutungsgleiches streichen", "Zweite Reduktion: Bündeln zu Kategorien", "Kategoriensystem am Ausgangsmaterial rücküberprüfen"],
    jq: "Mayring-Tabelle (Analyse → Zusammenfassung) mit Paraphrase und Generalisierung je Coding; Reduktion = Codes bilden und zusammenführen.",
    lit: ["mayring"] },
  mayring_s: { name: "Strukturierende Inhaltsanalyse", by: "Mayring", short: "Mayring S", x: .12, y: .32, la: "r", sup: 2, lg: { de: 2, in: 0, mix: 1, ab: 0 },
    what: "Theoriegeleitete Kategorien werden mit einem Kodierleitfaden an das Material angelegt (inhaltlich, typisierend oder skalierend).",
    steps: ["Strukturierungsdimensionen theoriegeleitet festlegen", "Kategoriensystem und Ausprägungen bestimmen", "Kodierleitfaden: Definition, Ankerbeispiel, Kodierregel", "Probedurchlauf: Fundstellen bezeichnen", "Kategorien und Leitfaden überarbeiten", "Hauptdurchlauf und Ergebnisaufbereitung"],
    jq: "Kodierleitfaden direkt am Code (Buch-Symbol), Ankerbeispiele per Klick aus dem Text, Code-Matrix für die Aufbereitung.",
    lit: ["mayring"] },
  kuckartz_s: { name: "Inhaltlich strukturierende QIA", by: "Kuckartz & Rädiker", short: "Kuckartz IS", x: .4, y: .2, la: "r", sup: 2, lg: { de: 1, in: 1, mix: 2, ab: 0 },
    what: "Hauptkategorien deduktiv, Subkategorien induktiv, mehrere Kodierdurchläufe, dann fallbezogene und kategorienbasierte Auswertung.",
    steps: ["Initiierende Textarbeit: lesen, markieren, Memos, Fallzusammenfassungen", "Hauptkategorien entwickeln (meist aus Leitfaden/Theorie)", "Erster Kodierprozess mit den Hauptkategorien", "Subkategorien induktiv am Material bilden", "Zweiter Kodierprozess mit dem ausdifferenzierten System", "Einfache und komplexe Analysen (Tabellen, Fallvergleiche)", "Ergebnisse verschriftlichen und Vorgehen dokumentieren"],
    jq: "Memos, Codes + Subcodes, Summary Grid für thematische Fallzusammenfassungen, Code-Matrix und Fallvergleich.",
    lit: ["kuckartz"] },
  kuckartz_t: { name: "Typenbildende QIA", by: "Kuckartz & Rädiker", short: "Kuckartz T", x: .38, y: .62, la: "l", sup: 1, lg: { de: 1, in: 1, mix: 2, ab: 1 },
    what: "Fälle werden über Merkmalsräume gruppiert, sodass Typen entstehen, die sich intern ähneln und untereinander unterscheiden.",
    steps: ["Merkmalsraum bestimmen (relevante Kategorien/Variablen)", "Fälle kodieren und zusammenfassen", "Fälle gruppieren, Typen bilden", "Typen beschreiben, prototypische Fälle wählen", "Zusammenhänge zwischen Typen und Variablen prüfen"],
    jq: "Kodieren, Dokument-Variablen und Fallvergleich ja; die eigentliche Typenbildung machst du in einer Tabelle (Export nach Excel).",
    lit: ["kuckartz"] },
  kuckartz_e: { name: "Evaluative QIA", by: "Kuckartz & Rädiker", short: "Kuckartz E", x: .22, y: .46, la: "r", sup: 2, lg: { de: 2, in: 0, mix: 2, ab: 0 },
    what: "Textstellen werden eingeschätzt und auf Ausprägungen (z. B. hoch/mittel/niedrig) kodiert.",
    steps: ["Evaluative Kategorien und Ausprägungen festlegen", "Textstellen zur Kategorie kodieren", "Ausprägungen je Fall vergeben, Regeln für Grenzfälle", "Fälle und Gruppen vergleichen"],
    jq: "Ausprägungen als Subcodes (z. B. „Belastung › hoch“), Kodierregel im Kodierleitfaden, Fallvergleich nach Variablen.",
    lit: ["kuckartz"] },
  glaeser: { name: "Qualitative Inhaltsanalyse durch Extraktion", by: "Gläser & Laudel", short: "Gläser/Laudel", x: .08, y: .08, la: "r", sup: 2, lg: { de: 2, in: 0, mix: 2, ab: 0 },
    what: "Informationen werden aus dem Text entnommen und theoretisch abgeleiteten Kategorien zugeordnet – das Kategoriensystem bleibt offen.",
    steps: ["Kategorien aus Theorie und Fragestellung ableiten", "Text lesen, relevante Informationen extrahieren", "Informationen den Kategorien zuordnen (neue Ausprägungen zulassen)", "Extrahierte Informationen aufbereiten und auswerten"],
    jq: "Codes vorab anlegen, Paraphrase-Feld als „Extraktion“ nutzen, Export der Codings als Tabelle.",
    lit: ["glaeser"] },
  meuser: { name: "Auswertung nach Meuser & Nagel", by: "Meuser & Nagel", short: "Meuser/Nagel", x: .76, y: .54, la: "l", sup: 2, lg: { de: 0, in: 2, mix: 1, ab: 1 },
    what: "Für Experteninterviews entwickelt: textnah paraphrasieren und kodieren, thematisch vergleichen, dann soziologisch konzeptualisieren.",
    steps: ["Transkription (thematisch relevante Passagen)", "Paraphrase der Passagen", "Kodieren mit textnahen Überschriften (Terminologie der Interviewten)", "Thematischer Vergleich über alle Interviews", "Soziologische Konzeptualisierung", "Theoretische Generalisierung"],
    jq: "Paraphrase-Feld, In-vivo-Codes für textnahe Überschriften, Codes zusammenführen beim thematischen Vergleich, Code-Matrix.",
    lit: ["meuser", "bogner"] },
  gt: { name: "Grounded Theory", by: "Glaser & Strauss; Strauss & Corbin; Charmaz", short: "Grounded Theory", x: .9, y: .64, la: "l", sup: 1, lg: { de: 0, in: 2, mix: 0, ab: 2 },
    what: "Theorie entsteht im ständigen Vergleich aus den Daten; Erhebung und Auswertung wechseln sich ab (theoretisches Sampling).",
    steps: ["Offenes Kodieren: Konzepte aufbrechen", "Axiales Kodieren: Beziehungen um Schlüsselkategorien", "Selektives Kodieren: Kernkategorie", "Memos von Anfang an", "Ständiges Vergleichen", "Theoretisches Sampling bis zur Sättigung"],
    jq: "Kodieren, In vivo, Code- und Projekt-Memos, Codes umhängen und zusammenführen. Theoretisches Sampling planst du außerhalb – neue Interviews kannst du jederzeit importieren.",
    lit: ["strauss"] },
  thema: { name: "Reflexive Thematische Analyse", by: "Braun & Clarke", short: "Them. Analyse", x: .64, y: .27, la: "r", sup: 2, lg: { de: 1, in: 2, mix: 2, ab: 1 },
    what: "Themen werden aktiv von der forschenden Person entwickelt – induktiv oder theoriegeleitet, in sechs Phasen.",
    steps: ["Mit den Daten vertraut werden", "Codes generieren", "Erste Themen entwickeln", "Themen prüfen und überarbeiten", "Themen definieren und benennen", "Bericht schreiben"],
    jq: "Codes, Code-Memos als Themendefinitionen, Codes zusammenführen, Bericht.",
    lit: ["braun"] },
  flick: { name: "Thematisches Kodieren", by: "Flick", short: "Flick", x: .58, y: .4, la: "r", sup: 2, lg: { de: 1, in: 1, mix: 2, ab: 0 },
    what: "Für vergleichende Studien: erst Einzelfallanalyse mit Kurzbeschreibung, dann eine gemeinsame thematische Struktur für den Fallvergleich.",
    steps: ["Kurzbeschreibung jedes Falls", "Fallbezogene Kodierung", "Thematische Struktur aus den ersten Fällen", "Weitere Fälle damit analysieren und Struktur anpassen", "Fallvergleich"],
    jq: "Dokument-Memo als Fallbeschreibung, Summary Grid, Fallvergleich nach Variablen.",
    lit: ["flick"] },
  narration: { name: "Narrationsanalyse", by: "Schütze", short: "Narrationsanalyse", x: .82, y: .84, la: "l", sup: 0, lg: { de: 0, in: 1, mix: 0, ab: 2 },
    what: "Rekonstruiert Prozessstrukturen des Lebensablaufs aus der formalen und inhaltlichen Struktur der Erzählung.",
    steps: ["Formale Textanalyse: erzählende von anderen Passagen trennen", "Strukturelle inhaltliche Beschreibung", "Analytische Abstraktion", "Wissensanalyse (Eigentheorien)", "Kontrastiver Vergleich", "Theoretisches Modell"],
    jq: "Nur unterstützend: Sequenzen als Codes markieren, Interpretationen als Textstellen-Memos, Bericht mit Randspalte für Interpretationsgruppen.",
    lit: ["schuetze"] },
  doku: { name: "Dokumentarische Methode", by: "Bohnsack", short: "Dok. Methode", x: .6, y: .94, la: "l", sup: 0, lg: { de: 0, in: 1, mix: 0, ab: 2 },
    what: "Unterscheidet, was gesagt wird (immanenter Sinn) von dem, wie es gesagt wird (dokumentarischer Sinn), um Orientierungsrahmen zu rekonstruieren.",
    steps: ["Thematischer Verlauf", "Formulierende Interpretation", "Reflektierende Interpretation (Diskursorganisation)", "Fallbeschreibung", "Komparative Analyse und Typenbildung"],
    jq: "Nur unterstützend: Passagen markieren, Interpretationen in Memos, Segmente nach Sprecherwechsel für die Diskursorganisation.",
    lit: ["bohnsack"] }
};

/* ---------- Forschungsziele (Schritt 1) ---------- */
const ZI = {
  pruefen: { em: "🔬", name: "Theorie anwenden oder prüfen", short: "Es gibt ein Modell oder Konzept, das du am Material prüfen oder ausdifferenzieren willst.", iv: ["leitfaden", "exp_sys", "fokussiert", "pzi"], lg: "de" },
  verstehen: { em: "💬", name: "Erfahrungen und Sichtweisen verstehen", short: "Wie erleben Menschen ein Problem, wie begründen sie ihr Handeln?", iv: ["pzi", "leitfaden", "episodisch"], lg: "mix" },
  experten: { em: "🧠", name: "Wissen von Expert:innen nutzen", short: "Du sprichst mit Menschen wegen ihrer Funktion oder Erfahrung in einem Feld.", iv: ["exp_theo", "exp_sys", "exp_expl"], lg: "mix" },
  theorie: { em: "🌱", name: "Neue Theorie / Konzepte entwickeln", short: "Du willst erklären, wie etwas funktioniert – und hast noch kein fertiges Modell.", iv: ["exp_theo", "narrativ", "pzi"], lg: "in" },
  erkunden: { em: "🧭", name: "Ein neues Feld erkunden", short: "Du weißt noch wenig und willst dich orientieren (z. B. Vorstudie).", iv: ["exp_expl", "leitfaden"], lg: "in" },
  biografie: { em: "📖", name: "Biografien oder Prozesse rekonstruieren", short: "Wie hat sich etwas im Leben von Menschen entwickelt?", iv: ["narrativ", "episodisch"], lg: "ab" },
  gruppe: { em: "👥", name: "Kollektive Orientierungen / Meinungsbild", short: "Was teilt eine Gruppe? Welche Meinungen gibt es?", iv: ["gruppe"], lg: "mix" }
};

/* ---------- 2. Grundlagen-Module ---------- */
const MOD = [
  { id: "qda", icon: "🔎", color: "#38bdf8", title: "Was ist qualitative Datenanalyse?", blurb: "Verstehen statt messen: Prinzipien, Ziele und was sie von Statistik unterscheidet.",
    body: () => `
<div class="md"><p>Qualitative Datenanalyse (QDA) erschließt <b>Bedeutungen</b>: Wie deuten Menschen ihre Welt, wie begründen sie ihr Handeln, welche Muster zeigen sich über mehrere Fälle? Grundlage sind meist Texte – Interviewtranskripte, Feldnotizen, Dokumente.</p></div>
${vis("quali")}
<div class="md"><p><b>Vier Prinzipien</b>, die in fast jedem Lehrbuch auftauchen:</p><ul>
<li><b>Offenheit</b> – für Unerwartetes, für die Relevanzen der Befragten.</li>
<li><b>Kommunikation</b> – Daten entstehen im Gespräch; du bist Teil der Situation.</li>
<li><b>Prozesshaftigkeit</b> – Fragestellung, Kategorien und Sampling dürfen sich entwickeln.</li>
<li><b>Reflexivität</b> – deine Rolle, dein Vorwissen und deine Entscheidungen werden offengelegt.</li></ul></div>
${box("tip", "💡", "Erst die Frage, dann das Verfahren", "Die Methode folgt aus der Forschungsfrage, nicht umgekehrt. Der Kompass hilft dir, Frage, Interviewform und Auswertung stimmig zu verbinden.")}
${box("warn", "⚠️", "Häufigkeiten mit Vorsicht", "jellyqda zeigt Zahlen (Codings je Code, Prozent im Bericht). In der qualitativen Forschung beschreiben sie die Verteilung im Material – sie sind kein Beleg für Verbreitung in einer Population.")}`,
    quiz: [
      { q: "Was ist das Hauptziel qualitativer Datenanalyse?", o: ["Häufigkeiten statistisch absichern", "Bedeutungen und Muster verstehen", "Hypothesen per Signifikanztest prüfen", "Möglichst große Stichproben auswerten"], a: 1, ex: "Es geht um Sinn, Deutungen und Muster – nicht um statistische Verallgemeinerung." },
      { q: "In jellyqda kommt „Motivation“ in 7 von 10 Interviews vor. Was darfst du daraus schließen?", o: ["70 % aller Beschäftigten sind motiviert", "Das Thema war in deinem Material breit präsent", "Motivation ist der wichtigste Faktor", "Nichts, Zahlen sind in QDA verboten"], a: 1, ex: "Zahlen beschreiben dein Material. Sie sind erlaubt, aber nicht repräsentativ." }
    ] },
  { id: "logik", icon: "🔁", color: "#a78bfa", title: "Induktiv, deduktiv, abduktiv", blurb: "Woher kommen die Kategorien? Die wichtigste Weichenstellung – mit interaktivem Schaubild.",
    body: () => `
<div class="md"><p>Die zentrale Frage jeder Auswertung: <b>Woher kommen deine Kategorien?</b></p></div>
${vis("logik")}
<div class="tblwrap"><table class="tbl"><tr><th>Logik</th><th>Kategorien kommen aus …</th><th>typische Verfahren</th></tr>
<tr><td><span class="tag de">deduktiv</span></td><td>Theorie, Forschungsstand, Leitfaden</td><td>Mayring strukturierend, Gläser & Laudel, Kuckartz evaluativ</td></tr>
<tr><td><span class="tag in">induktiv</span></td><td>dem Material selbst</td><td>Mayring zusammenfassend, Meuser & Nagel, Grounded Theory</td></tr>
<tr><td><span class="tag mix">deduktiv-induktiv</span></td><td>beidem: Hauptkategorien vorab, Subkategorien am Material</td><td>Kuckartz inhaltlich strukturierend, Flick, thematische Analyse</td></tr>
<tr><td><span class="tag ab">abduktiv</span></td><td>überraschenden Befunden, die eine neue Erklärung brauchen</td><td>Grounded Theory, Narrationsanalyse, dokumentarische Methode</td></tr></table></div>
${box("tip", "💡", "Rein induktiv gibt es nicht", "Niemand liest ein Transkript ohne Vorwissen. Wichtig ist, es offenzulegen – z. B. in einem Projekt-Memo „Mein Vorwissen“ in jellyqda, bevor du mit dem Kodieren beginnst.")}
${box("jq", "🪼", "In jellyqda", "Deduktiv: Codes vorab anlegen + Kodierleitfaden. Induktiv: Text markieren → <b>In vivo</b>, später ordnen mit Umhängen und Zusammenführen. Beides ist jederzeit rückgängig zu machen (Strg+Z) und steht im Protokoll.")}`,
    quiz: [
      { q: "Du legst Codes aus den Themenblöcken deines Leitfadens an und ergänzt Subcodes beim Lesen. Das ist …", o: ["rein deduktiv", "rein induktiv", "deduktiv-induktiv", "abduktiv"], a: 2, ex: "Hauptkategorien vorab, Subkategorien am Material: die klassische Mischform." },
      { q: "Welche jellyqda-Funktion ist typisch induktiv?", o: ["Kodierleitfaden vorab ausfüllen", "In-vivo-Code", "Alle Suchtreffer codieren", "Fallvergleich"], a: 1, ex: "In vivo macht die Worte der Befragten selbst zum Code." }
    ] },
  { id: "prozess", icon: "🗺️", color: "#34d399", title: "Der Forschungsprozess", blurb: "Von der Frage bis zum Methodenteil – und wo jellyqda dir hilft.",
    body: () => `
<div class="md"><p>Qualitative Forschung verläuft selten streng linear. Trotzdem hilft ein Ablaufplan – vor allem, um rechtzeitig mit der Auswertung zu beginnen.</p></div>
${vis("prozess")}
${box("tip", "💡", "Früh mit der Analyse anfangen", "Kodiere das erste Interview, bevor du alle geführt hast. Du merkst so, ob der Leitfaden funktioniert, und dein Postskript ist noch frisch.")}
${box("warn", "⚠️", "Zeitplanung", "Faustregel aus der Praxis: Transkription kostet ein Vielfaches der Interviewdauer, und die Auswertung dauert fast immer länger als geplant. Plane Puffer ein.")}`,
    quiz: [
      { q: "Wann ist ein guter Zeitpunkt, mit dem Kodieren zu beginnen?", o: ["Erst wenn alle Interviews transkribiert sind", "Schon nach den ersten Interviews", "Nach dem Schreiben der Ergebnisse", "Vor der Entwicklung des Leitfadens"], a: 1, ex: "Frühes Kodieren verbessert Leitfaden und Sampling – bei Grounded Theory ist es sogar Pflicht." }
    ] },
  { id: "interviews", icon: "🎙️", color: "#f472b6", title: "Interviewformen & Offenheit", blurb: "Von narrativ bis strukturiert: welche Form für welche Frage – und was „leitfadengestützt“ eigentlich heißt.",
    body: () => `
<div class="md"><p>Interviewformen unterscheiden sich vor allem darin, <b>wie stark du das Gespräch strukturierst</b> und <b>welches Wissen</b> du erheben willst. Tippe auf eine Zeile für Details.</p></div>
${vis("spektrum")}
${box("tip", "💡", "„Leitfadengestützt“ ist kein eigener Offenheitsgrad", "Der Begriff beschreibt das Instrument, nicht die Offenheit: Es gibt halboffene Leitfäden (Reihenfolge flexibel, viel Raum für Erzählung) und strukturierte (feste Fragen). Die meisten Lehrbücher meinen mit Leitfadeninterview das halboffene.")}
${box("warn", "⚠️", "Die Offenheit prägt die Auswertung", "Je offener die Erhebung, desto weniger passt ein starres, vorab festgelegtes Kategoriensystem. Ein narratives Interview rein deduktiv auszuwerten verschenkt genau das, wofür du es geführt hast.")}
<div class="btnrow"><a class="btn primary" href="#/compass">${ICON.compass} Im Kompass deine Form wählen</a></div>`,
    quiz: [
      { q: "Welches Interview lebt von einer ununterbrochenen Stegreiferzählung?", o: ["Problemzentriertes Interview", "Narratives Interview", "Systematisierendes Experteninterview", "Fokussiertes Interview"], a: 1, ex: "Schützes narratives Interview: erst erzählen lassen, Nachfragen erst danach." },
      { q: "Du willst das Deutungswissen von Führungskräften rekonstruieren. Was passt am besten?", o: ["Systematisierendes Experteninterview", "Theoriegenerierendes Experteninterview", "Standardisierter Fragebogen", "Fokussiertes Interview"], a: 1, ex: "Deutungswissen (Sichtweisen, Handlungslogiken) ist der Kern des theoriegenerierenden Experteninterviews." }
    ] },
  { id: "verfahren", icon: "🧭", color: "#fbbf24", title: "Verfahren-Landkarte", blurb: "Mayring, Kuckartz, Meuser & Nagel, Grounded Theory … wo steht was?",
    body: () => `
<div class="md"><p>Die Karte ordnet Verfahren nach zwei Achsen: <b>woher die Kategorien kommen</b> (deduktiv ↔ induktiv) und <b>wie tief interpretiert wird</b> (inhaltsanalytisch-beschreibend ↔ rekonstruktiv). Die Farbe zeigt, wie gut jellyqda das Verfahren unterstützt. Tippe auf einen Punkt.</p></div>
${vis("karte")}
${box("tip", "💡", "Eine Vereinfachung", "Die Positionen sind grob – viele Verfahren lassen sich deduktiver oder induktiver anwenden. Entscheidend ist, dass du dein Vorgehen begründest und die Schritte des gewählten Verfahrens nachvollziehbar dokumentierst.")}`,
    quiz: [
      { q: "Welches Verfahren wurde speziell für Experteninterviews entwickelt?", o: ["Narrationsanalyse", "Auswertung nach Meuser & Nagel", "Dokumentarische Methode", "Thematische Analyse"], a: 1, ex: "Meuser & Nagel: Paraphrase → Überschriften → thematischer Vergleich → Konzeptualisierung → Generalisierung." },
      { q: "Paraphrase → Generalisierung → Reduktion gehört zu …", o: ["Mayrings zusammenfassender Inhaltsanalyse", "Grounded Theory", "Gläser & Laudel", "Kuckartz’ evaluativer QIA"], a: 0, ex: "Das sind die Z-Regeln der zusammenfassenden Inhaltsanalyse – in jellyqda als Mayring-Tabelle." }
    ] },
  { id: "kategorien", icon: "🌳", color: "#fb923c", title: "Codes, Kategorien & Kodierleitfaden", blurb: "Wie ein gutes Kategoriensystem aussieht – und warum Ankerbeispiele Gold wert sind.",
    body: () => `
<div class="md"><p>Ein <b>Code</b> ist ein Etikett für eine Textstelle. Mehrere Codes zusammen bilden ein <b>Kategoriensystem</b> – in jellyqda als Codebaum mit Codes und Subcodes, jede Familie in einer Farbe, verbunden durch einen „Faden“.</p></div>
${vis("baum")}
<div class="md"><p><b>Kodierleitfaden</b> – die drei Spalten, die jede Kategorie nachvollziehbar machen:</p></div>
<div class="tblwrap"><table class="tbl"><tr><th>Kategorie</th><th>Definition</th><th>Ankerbeispiel</th><th>Kodierregel</th></tr>
<tr><td><b>Teamklima › Unterstützung</b></td><td>Aussagen über konkrete Hilfe durch Kolleg:innen</td><td>„Bei uns im Team, da hilft jeder jedem.“ (B3, Abs. 12)</td><td>Nur erlebte Hilfe, nicht Wünsche. Wünsche → „Unterstützungsbedarf“</td></tr></table></div>
<div class="md mt"><p><b>Gute Kategorien sind …</b></p><ul>
<li><b>trennscharf</b> – eine Textstelle passt klar in die eine oder andere Kategorie (sonst: Kodierregel schärfen),</li>
<li><b>auf einer Ebene</b> – Subcodes einer Familie sind gleichartig (nicht „Konflikte“ neben „Interview 3“),</li>
<li><b>überschaubar</b> – lieber wenige gut definierte Hauptkategorien als 200 lose Codes,</li>
<li><b>dokumentiert</b> – Definition und Änderungen stehen in Code-Memos.</li></ul></div>
${box("tip", "💡", "Analyseeinheiten festlegen", "Was ist die kleinste kodierbare Einheit (Wort, Satz, Sinnabschnitt)? Wie viel Kontext darfst du heranziehen? Kurz entscheiden und im Methodenteil nennen. In jellyqda helfen Segmente: „ganzes Segment“ kodiert einen Redebeitrag am Stück.")}
${box("jq", "🪼", "In jellyqda", "Buch-Symbol am Code öffnet den Kodierleitfaden. Eine kodierte Stelle anklicken → „Als Ankerbeispiel für …“. Definition und Regel erscheinen beim Kodieren als Hinweis über dem Code.")}`,
    quiz: [
      { q: "Zwei Kodierende ordnen dieselbe Stelle verschiedenen Kategorien zu. Was hilft am ehesten?", o: ["Mehr Codes anlegen", "Kodierregel und Ankerbeispiele schärfen", "Die Stelle ignorieren", "Nur noch Häufigkeiten zählen"], a: 1, ex: "Kodierregeln klären Grenzfälle, Ankerbeispiele zeigen den Prototyp." }
    ] },
  { id: "mayring", icon: "🪜", color: "#c084fc", title: "Zusammenfassen nach Mayring", blurb: "Paraphrase → Generalisierung → Reduktion – zum Durchklicken an einem Beispiel.",
    body: () => `
<div class="md"><p>Die zusammenfassende Inhaltsanalyse verdichtet Material schrittweise. Klick dich durch die vier Stufen – so sieht das später in der <b>Mayring-Tabelle</b> von jellyqda aus.</p></div>
${vis("mayring")}
${box("tip", "💡", "Abstraktionsniveau vorher festlegen", "Wie allgemein soll die Generalisierung sein? „Fehlende Mentorin“ oder „Unterstützungsbedarf“? Leg das Niveau fest, bevor du generalisierst, und halte es durch.")}
${box("warn", "⚠️", "Rücküberprüfung nicht vergessen", "Am Ende prüfst du, ob das reduzierte Kategoriensystem das Ausgangsmaterial noch repräsentiert. Ein Klick auf eine Zeile der Mayring-Tabelle springt zur Stelle im Dokument.")}`,
    quiz: [
      { q: "„Würde ohne Kolleginnen kündigen“ ist …", o: ["eine Paraphrase", "eine Generalisierung", "eine Kategorie", "ein Ankerbeispiel"], a: 0, ex: "Inhalt knapp in eigenen Worten, noch nah am Einzelfall – eine Paraphrase." }
    ] },
  { id: "kuckartz", icon: "⭕", color: "#22d3ee", title: "Kuckartz: 7 Phasen", blurb: "Die inhaltlich strukturierende QIA – rund um die Forschungsfrage.",
    body: () => `
<div class="md"><p>Die inhaltlich strukturierende QIA nach Kuckartz & Rädiker ist in vielen Abschlussarbeiten der Standard. Die Phasen kreisen um die Forschungsfrage – du gehst nicht stur im Kreis, sondern kehrst immer wieder zu ihr zurück. Tippe auf eine Phase.</p></div>
${vis("kreis")}
${box("jq", "🪼", "Fallbezogene Zusammenfassungen", "Kuckartz empfiehlt thematische Fallzusammenfassungen je Kategorie und Fall. Genau dafür gibt es in jellyqda das <b>Summary Grid</b> (Code × Dokument).")}`,
    quiz: [
      { q: "Wo entstehen bei Kuckartz typischerweise die Subkategorien?", o: ["Vorab aus der Theorie", "Induktiv am Material nach dem ersten Kodierprozess", "Aus Worthäufigkeiten", "Erst beim Schreiben"], a: 1, ex: "Phase 4: Subkategorien werden induktiv am bereits grob kodierten Material gebildet." }
    ] },
  { id: "guete", icon: "✅", color: "#4ade80", title: "Gütekriterien & Reflexivität", blurb: "Wie qualitative Forschung überzeugt – ohne Reliabilitätskoeffizienten-Fetisch.",
    body: () => `
<div class="md"><p>Für qualitative Forschung gelten eigene Gütekriterien. Häufig zitiert sind die Kernkriterien nach <b>Steinke</b>:</p><ul>
<li><b>Intersubjektive Nachvollziehbarkeit</b> – Vorgehen dokumentieren, Regeln offenlegen, in Gruppen interpretieren.</li>
<li><b>Indikation</b> – passen Frage, Methode und Auswertung zusammen? (genau das prüft der Kompass)</li>
<li><b>Empirische Verankerung</b> – Aussagen mit Textstellen belegen.</li>
<li><b>Limitation</b> – Grenzen der Verallgemeinerbarkeit benennen.</li>
<li><b>Kohärenz</b> – Widersprüche nicht glätten, sondern bearbeiten.</li>
<li><b>Relevanz</b> – was trägt die Studie bei?</li>
<li><b>Reflektierte Subjektivität</b> – deine Rolle im Forschungsprozess.</li></ul></div>
${box("tip", "💡", "Konsensuelles Kodieren", "Zu zweit dieselben Interviews kodieren, Unterschiede besprechen und Kodierregeln schärfen. Das Gespräch über Abweichungen ist oft wertvoller als ein Übereinstimmungswert.")}
${box("warn", "⚠️", "Intercoder-Übereinstimmung", "jellyqda berechnet derzeit keine Übereinstimmungskoeffizienten. Wenn deine Betreuung einen Wert verlangt: Codings als Tabelle exportieren und extern vergleichen – oder mit Betreuung klären, ob konsensuelles Kodieren genügt.")}
${box("jq", "🪼", "Verfahrensdokumentation geschenkt", "Jede Aktion steht mit Zeitstempel im Protokoll: <code>qda_export(\"audit\")</code>. Codebuch, Kodierleitfaden und Memos landen im Bericht – ideal für Anhang und Methodenteil.")}`,
    quiz: [
      { q: "Welches Kriterium prüft, ob Forschungsfrage, Methode und Auswertung zusammenpassen?", o: ["Relevanz", "Indikation", "Limitation", "Kohärenz"], a: 1, ex: "Indikation des Forschungsprozesses: Ist das Vorgehen dem Gegenstand angemessen?" }
    ] },
  { id: "ethik", icon: "🔒", color: "#f87171", title: "Transkription, Datenschutz & Ethik", blurb: "Einwilligung, Pseudonymisierung und ein Transkriptformat, das jellyqda versteht.",
    body: () => `
<div class="md"><p>Interviewdaten sind personenbezogen und oft sensibel. Bevor die Analyse beginnt, sollten drei Dinge geklärt sein:</p><ol>
<li><b>Informierte Einwilligung</b> – Zweck, Aufbewahrung, Löschung, Rücktrittsrecht; schriftlich dokumentiert.</li>
<li><b>Pseudonymisierung</b> – Namen, Orte, Firmen, seltene Funktionen ersetzen. Bei Expert:innen besonders gründlich: kleine Felder machen Personen wiedererkennbar.</li>
<li><b>Sichere Speicherung</b> – Rohdaten getrennt von der Zuordnungsliste, kein Upload in Cloud-Dienste ohne Vereinbarung.</li></ol></div>
<div class="md"><p><b>Transkriptformat</b>, mit dem jellyqda Segmente nach Sprecherwechsel erkennt:</p></div>
${vis("transkript")}
${box("tip", "💡", "Transkriptionsregeln festlegen", "Einfaches oder erweitertes Transkript? Dialekt glätten? Pausen notieren? Leg die Regeln vorab fest (z. B. nach Dresing & Pehl) und nenne sie im Methodenteil. Für rekonstruktive Verfahren brauchst du mehr Details als für eine Inhaltsanalyse.")}
${box("jq", "🪼", "Warum jellyqda hier hilft", "Komplett offline: keine Cloud, keine Uploads, die App läuft nur auf deinem Rechner. Ein Projekt ist eine Datei; Backups landen außerhalb des Projektordners. Interviewdaten gehören nicht in Git – die mitgelieferte <code>.gitignore</code> schließt sie aus.")}`,
    quiz: [
      { q: "Was gehört bei Experteninterviews besonders gründlich pseudonymisiert?", o: ["Nur der Name", "Name, Organisation, Funktion und erkennbare Anekdoten", "Nichts, Expert:innen sprechen öffentlich", "Nur die Zeitmarken"], a: 1, ex: "In kleinen Feldern reicht oft die Funktion, um eine Person zu erkennen." }
    ] }
];

/* ---------- 3. jellyqda Schritt für Schritt ---------- */
const TOUR = [
  { t: "Installieren", tag: "start", img: [], txt: "Voraussetzung: R ab 4.0, am besten mit RStudio (beides kostenlos). Dann eine einzige Zeile in die R-Konsole – das Skript installiert alles, prüft die Installation und sagt dir, wie es weitergeht.",
    r: 'source("https://raw.githubusercontent.com/thedivingshellyfish/jellyqda/main/install_jellyqda.R")',
    tips: ["Unter Linux braucht der PDF-/Word-Import einmalig Systembibliotheken – das Skript nennt den passenden Befehl."] },
  { t: "Projekt anlegen & App starten", tag: "start", img: [["01-uebersicht.png", "Die Oberfläche: Dokumente, Codesystem, Dokument-Browser, Memos"]], txt: "Ein Projekt ist eine einzige Datei (<code>*.jellyqda</code>). Gespeichert wird sofort bei jeder Aktion.",
    r: 'library(jellyqda)\nqda_open("meine-arbeit.jellyqda")  # anlegen oder wieder öffnen\nqda_app(lang = "de")               # App im Browser starten',
    tips: ["Zum Ausprobieren ohne eigene Daten: das Beispiel-Interview aus dem Paket oder die fiktiven Transkripte im Ordner <code>demo/</code>."] },
  { t: "Transkripte importieren & Variablen", tag: "beide", img: [["03-dokumente-import.png", "Import per Klick oder Drag & Drop"]], txt: "Links bei <b>Dokumente</b> importieren (.txt, .md, .docx, .pdf). Der Text wird beim Import „eingefroren“ – Markierungen verrutschen nie. Variablen wie Rolle, Branche oder Altersgruppe brauchst du später für den Fallvergleich.",
    r: 'qda_import(c("interview_01.docx", "interview_02.docx"), segments = "speaker")\nqda_source_set_var(1, "Rolle", "Projektleitung")',
    tips: ["Variablen gleich beim Import anlegen – nachträglich für 20 Interviews ist mühsam.", "Pseudonymisieren <b>vor</b> dem Import: Der Text ist danach bewusst unveränderlich."] },
  { t: "Segmente prüfen", tag: "beide", img: [["09-segmentleiste.png", "Segmente teilen und zusammenführen"]], txt: "Segmente sind die Grundeinheiten deines Textes: nach Absätzen oder nach Sprecherwechseln (<code>[00:01:12] B: …</code>). Teilen und zusammenführen geht mit einem Klick in den Text.",
    r: 'qda_segments_set(1, "speaker")   # Regel für Dokument 1 ändern', tips: ["Offene Interviews: eher Absätze. Leitfadeninterviews: Sprecherwechsel."] },
  { t: "Codesystem aufbauen", tag: "de", img: [["05-codesystem.png", "Codebaum mit Codes, Subcodes und Faden"]], txt: "Im <b>Code System</b> mit „+ Code“ Hauptkategorien anlegen, darunter „+ Subcode“. Doppelklick benennt um, der Farbpunkt färbt die ganze Familie. Bei deduktivem Vorgehen entsteht hier dein Kategoriensystem aus Theorie oder Leitfaden.",
    r: 'qda_code_add("Teamklima")\nqda_code_add("Unterstützung", parent = "Teamklima")\nqda_code_set_color("Teamklima", "#009E73")', tips: ["Bei induktivem Vorgehen startest du fast leer – die Codes entstehen beim Lesen."] },
  { t: "Kodieren", tag: "beide", img: [["06-markieren-aktionsleiste.png", "Text markieren → Kodier-Leiste"], ["08-coding-leiste.png", "Coding anklicken: umkodieren, kommentieren, Mayring-Felder"]], txt: "Text markieren, Code anklicken, fertig. Per Tastatur: <b>Strg+1…9</b> wählt den Code, danach <b>1…9</b> den Subcode. Ein Klick auf ein bestehendes Coding öffnet die Coding-Leiste: umkodieren, Kommentar, Paraphrase, Ankerbeispiel.",
    r: 'qda_code(source = 1, segment = 3, code = "Unterstützung")       # ganzes Segment\nqda_code(source = 1, start = 120, end = 340, code = "Teamklima") # Zeichenbereich', tips: ["Überlappende Codings sind grau mit Zahl – Maus drüber zeigt alle."] },
  { t: "Memos schreiben", tag: "beide", img: [["10-memos.png", "Memos in vier Arten, mit Filter und Suche"]], txt: "Vier Arten: Textstelle (<b>Strg+M</b>), Dokument (z. B. dein Postskript), Code (Definition, Kodierregel) und Projekt (z. B. „Mein Vorwissen“, Methodenentscheidungen).",
    r: 'qda_memo_add("Postskript: entspannte Atmosphäre, B3 wirkte unter Zeitdruck", source = 1, title = "Postskript")\nqda_memo_add("Nur explizite Aussagen codieren", code = "Unterstützung", title = "Kodierregel")', tips: ["Memos sind dein Forschungstagebuch – später Gold für den Methodenteil."] },
  { t: "Kodierleitfaden", tag: "de", img: [["26-kodierleitfaden.png", "Definition, Ankerbeispiele, Kodierregel"]], txt: "Maus über einen Code → <b>Buch-Symbol</b>. Definition, Ankerbeispiele (eins pro Zeile) und Kodierregel. Ankerbeispiele übernimmst du direkt aus dem Text: Coding anklicken → „Als Ankerbeispiel für …“.",
    r: 'qda_code_guide("Unterstützung",\n  definition = "Konkrete, erlebte Hilfe durch Kolleg:innen",\n  rule = "Nur erlebte Hilfe; Wünsche -> Unterstützungsbedarf")', tips: ["Nach dem Probedurchlauf (10–50 % des Materials) Leitfaden überarbeiten – das Protokoll dokumentiert die Änderung."] },
  { t: "Induktiv verdichten", tag: "in", img: [["27-codes-zusammenfuehren.png", "Codes zusammenführen"]], txt: "<b>In vivo</b> in der Kodier-Leiste macht den markierten Text selbst zum Code. Später: umbenennen, als Subcode unter einen anderen Code hängen, ähnliche Codes zusammenführen (Pfeil-Symbol). Alles mit Strg+Z umkehrbar.",
    r: 'qda_code_move("Mentorin fehlt", parent = "Unterstützungsbedarf")\nqda_code_merge("keiner zum Fragen", into = "Mentorin fehlt")', tips: ["Regelmäßig verdichten – nach jedem zweiten oder dritten Interview aufräumen."] },
  { t: "Suchtreffer codieren", tag: "de", img: [["28-auto-codieren.png", "Alle Treffer auf einmal codieren"]], txt: "Unten in der Mitte suchen, dann „Alle N Treffer codieren mit …“ – nur das Wort oder das ganze Segment. Ein Strg+Z nimmt alle zurück.",
    r: 'qda_autocode("Kolleg", code = "Teamklima", scope = "segment")', tips: ["Nicht blind vertrauen: Treffer danach über den Code durchsehen und Unpassendes löschen. Automatisches Kodieren ersetzt kein Lesen."] },
  { t: "Mayring-Tabelle", tag: "in", img: [["32-mayring.png", "Paraphrase und Generalisierung für alle Codings"]], txt: "<b>Analyse → Zusammenfassung (Mayring)</b>: alle Codings mit Textstelle und je einem Feld für Paraphrase und Generalisierung. Gespeichert wird beim Verlassen eines Feldes; als CSV für Excel exportierbar.",
    r: 'qda_coding_set_summary(12, paraphrase = "Würde ohne Kolleginnen kündigen",\n                       generalization = "Team als Bindungsfaktor")', tips: ["Paraphrasen erscheinen im Bericht auch in der Randspalte neben dem Interview."] },
  { t: "Fälle vergleichen & zusammenfassen", tag: "beide", img: [["29-fallvergleich.png", "Fallvergleich in der Code-Matrix"], ["16-summary-grid.png", "Summary Grid: Zusammenfassung je Code und Dokument"]], txt: "<b>Code-Matrix</b> (Codes × Dokumente), bei „Spalten“ ein Fallvergleich nach Variable, z. B. Rolle. Das <b>Summary Grid</b> hält thematische Zusammenfassungen je Code und Fall – ideal für Kuckartz und Flick.",
    r: 'qda_matrix()\nqda_case_matrix("Rolle")\nqda_summary_set("Teamklima", 1, "B1 erlebt das Team als zentrale Ressource …")', tips: ["Matrixzahlen zeigen, wo du genauer lesen solltest – nicht, was „gilt“."] },
  { t: "Worthäufigkeiten & Stichwort im Kontext", tag: "in", img: [["30-worthaeufigkeiten.png", "Häufigste Wörter, ohne Füllwörter"], ["31-stichwort-im-kontext.png", "Stichwort im Kontext (KWIC)"]], txt: "<b>Analyse → Worthäufigkeiten</b> (auch nur innerhalb eines Codes) und <b>Stichwort im Kontext</b>: jedes Vorkommen eines Begriffs mit Text links und rechts. Ein Klick springt zur Stelle.",
    r: 'qda_words(n = 30, code = "Motivation")\nqda_kwic("Familie")', tips: ["Gut zum Entdecken von Feldbegriffen und zum Gegenprüfen – nicht als Ersatz für das Kodieren."] },
  { t: "Bericht & Export", tag: "beide", img: [["33-bericht-randspalte-a4.png", "Bericht mit Randspalte, druckfertig auf A4"]], txt: "<b>Bericht</b> öffnet einen neuen Tab, druckfertig auf A4: Codesystem mit Häufigkeiten, Codebuch, Memos, codierte Stellen und alle Interviews mit Randspalte. Das <b>Export</b>-Menü liefert CSV, Excel und Word.",
    r: 'qda_export("all")       # CSV/Excel/Word/HTML nach exports/\nqda_export("codebook")  # Codebuch für den Anhang', tips: ["Codebuch und Kodierleitfaden in den Anhang – das erfüllt gleich mehrere Gütekriterien."] },
  { t: "Rückgängig, Backup & Protokoll", tag: "start", img: [["17-rueckgaengig.png", "Rückgängig und Wiederholen für alles"]], txt: "<b>Strg+Z / Strg+Y</b> für alles. Backups automatisch alle 25 Aktionen und per Klick, als ZIP außerhalb des Projektordners. Das Protokoll hält jede Aktion mit Zeitstempel fest.",
    r: 'qda_backup()\nqda_export("audit")   # Protokoll für den Methodenteil', tips: ["Vor großen Umbauten (Zusammenführen, Autocode) kurz Strg+S – das legt einen Sicherungspunkt an."] }
];

/* ---------- 4. Checklisten, Glossar, Literatur ---------- */
const CHECK = [
  { id: "vor", t: "Vor der Erhebung", em: "📝", items: ["Forschungsfrage(n) schriftlich und präzise formuliert", "Interviewform begründet gewählt (Kompass!)", "Sampling: Wer, wie viele, warum? Zugang geklärt", "Leitfaden entwickelt (SPSS-Prinzip) und im Pretest erprobt", "Einwilligungserklärung und Informationsblatt vorbereitet", "Aufnahmegerät getestet, Ersatz-Akku dabei", "Postskript-Vorlage bereit", "Vorwissen notiert (wird ein Projekt-Memo)"] },
  { id: "trans", t: "Transkription", em: "⌨️", items: ["Transkriptionsregeln festgelegt und notiert", "Einheitliche Sprecherkürzel (I, B1, B2 …)", "Zeitmarken im Format [hh:mm:ss] am Beitragsanfang", "Namen, Orte, Organisationen pseudonymisiert", "Zuordnungsliste getrennt und sicher gespeichert", "Transkript gegen Audio korrekturgehört"] },
  { id: "ana", t: "Analyse in jellyqda", em: "🪼", items: ["Projekt angelegt, Transkripte importiert", "Dokument-Variablen (Rolle, Gruppe …) gesetzt", "Postskripte als Dokument-Memos übernommen", "Analyseeinheiten festgelegt", "Kategoriensystem mit Kodierleitfaden dokumentiert", "Probekodierung gemacht und Leitfaden überarbeitet", "Methodische Entscheidungen in Projekt-Memos festgehalten", "Material vollständig kodiert (Fortschritt: qda_stats())", "Backup an einem zweiten Ort"] },
  { id: "bericht", t: "Bericht & Methodenteil", em: "📄", items: ["Vorgehen Schritt für Schritt beschrieben (Verfahren + Quelle)", "Herkunft der Kategorien offengelegt (deduktiv/induktiv)", "Codebuch und Kodierleitfaden im Anhang", "Befunde mit Zitaten belegt (Interview, Absatz/Zeitmarke)", "Häufigkeiten vorsichtig interpretiert", "Grenzen der Studie benannt", "Eigene Rolle reflektiert"] }
];
const GLOSS = [
  ["Abduktion", "Schluss von einem überraschenden Befund auf eine neue erklärende Hypothese, die dann am Material geprüft wird."],
  ["Analyseeinheit", "Nach Mayring: Kodiereinheit (kleinster Textteil), Kontexteinheit (größter Textteil) und Auswertungseinheit (Reihenfolge der Bearbeitung)."],
  ["Ankerbeispiel", "Typische Textstelle, die eine Kategorie prototypisch zeigt – Teil des Kodierleitfadens."],
  ["Axiales Kodieren", "Grounded Theory: Beziehungen zwischen Kategorien rund um eine Achsenkategorie herausarbeiten."],
  ["Code", "Etikett für eine Textstelle. In jellyqda: Codes und Subcodes im Codebaum."],
  ["Coding", "Eine konkrete Zuordnung von Code und Textstelle."],
  ["Deduktiv", "Kategorien werden vorab aus Theorie, Forschungsstand oder Leitfaden abgeleitet und am Material angewendet."],
  ["Deutungswissen", "Subjektive Relevanzen, Sichtweisen und Interpretationen von Expert:innen – Gegenstand des theoriegenerierenden Experteninterviews."],
  ["Erzählaufforderung", "Offene Frage, die eine Erzählung anregen soll („Erzählen Sie doch mal …“)."],
  ["Fallvergleich", "Vergleich von Codehäufigkeiten oder Inhalten zwischen Gruppen von Fällen, z. B. nach Rolle. In jellyqda in der Code-Matrix."],
  ["Generalisierung", "Mayring: Paraphrase auf ein festgelegtes Abstraktionsniveau heben."],
  ["Grounded Theory", "Forschungsstil, in dem Theorie im ständigen Vergleich aus den Daten entwickelt wird (Glaser & Strauss)."],
  ["In-vivo-Code", "Code, dessen Name ein Begriff der Befragten selbst ist."],
  ["Induktiv", "Kategorien entstehen schrittweise aus dem Material."],
  ["Intercoder-Übereinstimmung", "Maß, wie ähnlich zwei Personen kodieren. Alternative: konsensuelles Kodieren mit Diskussion der Abweichungen."],
  ["Kategorie", "Begriff, der mehrere Textstellen unter einem gemeinsamen Gesichtspunkt bündelt. Oft synonym zu Code verwendet."],
  ["Kodierleitfaden", "Tabelle mit Definition, Ankerbeispiel und Kodierregel je Kategorie."],
  ["Kodierregel", "Regel zur Abgrenzung bei Grenzfällen zwischen Kategorien."],
  ["KWIC", "Keyword in Context – Stichwort im Kontext: jedes Vorkommen eines Wortes mit Umgebungstext."],
  ["Memo", "Notiz zu Textstelle, Dokument, Code oder Projekt; hält Ideen und Entscheidungen fest."],
  ["Paraphrase", "Inhalt einer Textstelle knapp in eigenen Worten."],
  ["Postskript", "Notizen direkt nach dem Interview zu Atmosphäre, Auffälligkeiten und nonverbalen Aspekten."],
  ["Pretest", "Probeinterview, um Leitfaden und Erzählaufforderungen zu testen."],
  ["Pseudonymisierung", "Ersetzen identifizierender Angaben durch Platzhalter; die Zuordnung wird getrennt aufbewahrt."],
  ["Reduktion", "Mayring: Streichen bedeutungsgleicher und Bündeln ähnlicher Generalisierungen zu Kategorien."],
  ["Rekonstruktiv", "Verfahren, die implizite Sinnstrukturen sequenziell herausarbeiten (z. B. Narrationsanalyse, dokumentarische Methode)."],
  ["Sättigung", "Punkt, an dem neue Fälle keine neuen Erkenntnisse für die Kategorien mehr bringen."],
  ["Segment", "In jellyqda: Grundeinheit eines Dokuments, nach Absätzen oder Sprecherwechseln."],
  ["Sensibilisierendes Konzept", "Vorwissen, das die Aufmerksamkeit lenkt, ohne den Blick festzulegen (Blumer)."],
  ["Sondierung", "PZI: allgemeine (Erzählungen vertiefen) und spezifische Sondierungen (Zurückspiegeln, Verständnisfragen, Konfrontation)."],
  ["SPSS-Prinzip", "Leitfadenentwicklung nach Helfferich: Sammeln, Prüfen, Sortieren, Subsumieren."],
  ["Summary Grid", "Tabelle Code × Dokument mit thematischen Zusammenfassungen."],
  ["Theoretisches Sampling", "Grounded Theory: Auswahl weiterer Fälle nach dem Stand der entstehenden Theorie."],
  ["Triangulation", "Verbindung mehrerer Datenquellen, Methoden oder Perspektiven."]
];
const LIT = {
  mayring: "Mayring, P. (2022). <i>Qualitative Inhaltsanalyse. Grundlagen und Techniken</i> (13. Aufl.). Beltz.",
  kuckartz: "Kuckartz, U. & Rädiker, S. (2022). <i>Qualitative Inhaltsanalyse. Methoden, Praxis, Computerunterstützung</i> (5. Aufl.). Beltz Juventa.",
  witzel: "Witzel, A. (2000). Das problemzentrierte Interview. <i>Forum Qualitative Sozialforschung, 1</i>(1), Art. 22.",
  bogner: "Bogner, A., Littig, B. & Menz, W. (2014). <i>Interviews mit Experten. Eine praxisorientierte Einführung</i>. Springer VS.",
  meuser: "Meuser, M. & Nagel, U. (1991). ExpertInneninterviews – vielfach erprobt, wenig bedacht. In D. Garz & K. Kraimer (Hrsg.), <i>Qualitativ-empirische Sozialforschung</i> (S. 441–471). Westdeutscher Verlag.",
  glaeser: "Gläser, J. & Laudel, G. (2010). <i>Experteninterviews und qualitative Inhaltsanalyse</i> (4. Aufl.). VS Verlag.",
  helfferich: "Helfferich, C. (2011). <i>Die Qualität qualitativer Daten. Manual für die Durchführung qualitativer Interviews</i> (4. Aufl.). VS Verlag.",
  schuetze: "Schütze, F. (1983). Biographieforschung und narratives Interview. <i>Neue Praxis, 13</i>(3), 283–293.",
  flick: "Flick, U. (2011). <i>Das Episodische Interview</i>. In G. Oelerich & H.-U. Otto (Hrsg.), Empirische Forschung und Soziale Arbeit. VS Verlag.",
  merton: "Merton, R. K. & Kendall, P. L. (1946). The focused interview. <i>American Journal of Sociology, 51</i>(6), 541–557.",
  strauss: "Strauss, A. & Corbin, J. (1996). <i>Grounded Theory: Grundlagen Qualitativer Sozialforschung</i>. Beltz.",
  braun: "Braun, V. & Clarke, V. (2006). Using thematic analysis in psychology. <i>Qualitative Research in Psychology, 3</i>(2), 77–101.",
  bohnsack: "Bohnsack, R. (2014). <i>Rekonstruktive Sozialforschung. Einführung in qualitative Methoden</i> (9. Aufl.). Budrich.",
  steinke: "Steinke, I. (1999). <i>Kriterien qualitativer Forschung</i>. Juventa.",
  dresing: "Dresing, T. & Pehl, T. (2018). <i>Praxisbuch Interview, Transkription & Analyse</i> (8. Aufl.). Eigenverlag, Marburg.",
  kruse: "Kruse, J. (2015). <i>Qualitative Interviewforschung. Ein integrativer Ansatz</i> (2. Aufl.). Beltz Juventa."
};
const IVLIT = { pzi: ["witzel"], exp_theo: ["bogner", "meuser"], exp_sys: ["bogner", "glaeser"], exp_expl: ["bogner"], narrativ: ["schuetze"], episodisch: ["flick"], fokussiert: ["merton"], leitfaden: ["helfferich", "kruse"], gruppe: ["bohnsack"] };

/* ---------- 5. Oberfläche: Texte, Schaubild-Beschriftungen, Fahrplan ---------- */
const IMG = "../../img/de/";
const UI = {
  lang: "de", other: { href: "../../assistant/", label: "EN", title: "English version" },
  title: "jellyqda Assistenz", tagline: "Qualitativ forschen – Schritt für Schritt",
  tabs: ["Start", "Kompass", "Grundlagen", "jellyqda", "Mehr"],
  fit: ["eher nicht", "möglich", "passt gut"], rec: "empfohlen", toGoal: "zu deinem Ziel",
  sup: ["nur unterstützend", "teilweise", "gut unterstützt"], supPre: "jellyqda: ",
  back: "Zurück", next: "Weiter", copy: "Kopieren", copied: "Kopiert ✓", themeToggle: "Hell/Dunkel umschalten", textLabel: "Text",
  shotMissing: "Screenshot erscheint auf der Projektseite",
  steps: ["Ziel", "Interview", "Offenheit", "Logik", "Verfahren", "Fahrplan"],
  komp: {
    title: "Forschungs-Kompass", sub: "In fünf Schritten zu einem stimmigen Vorgehen", showPlan: "Fahrplan zeigen",
    q: {
      zi: ["Was willst du herausfinden?", "Wähle, was deinem Erkenntnisinteresse am nächsten kommt. Das ist nur ein Startpunkt – alles lässt sich später ändern."],
      iv: ["Welche Art von Interview führst du?", "Tippe eine Form an, um mehr zu erfahren.", 'Mit <span class="fit r">empfohlen</span> markiert: was zu deinem Ziel passt.'],
      st: ["Wie offen ist dein Interview?", "Bewertet für: "],
      lg: ["Woher kommen deine Kategorien?", "Die Auswertungslogik. Bewertet nach Interviewform und Offenheit."],
      pr: ["Mit welchem Verfahren wertest du aus?", "Sortiert nach Passung zu deiner Auswahl."]
    }
  },
  det: { ivFor: "Naheliegende Interviewformen", lgFor: "Naheliegende Logik", after: "nach", wissen: "Welches Wissen?", ablauf: "Ablauf", achten: "Worauf achten",
    ausw: "Was das für die Auswertung bedeutet", next: "Nächster Schritt", nextSt: "Wähle den Strukturierungsgrad. Für diese Form:", beispiel: "Beispielfrage",
    seg: "Segmente in jellyqda", wann: "Wann sinnvoll", risiko: "Worauf achten", tools: "Passende jellyqda-Werkzeuge", steps: "Schritte", injq: "In jellyqda" },
  plan: {
    notAll: "Bitte erst alle Schritte auswählen.", title: "Dein Fahrplan", stimmig: "stimmig",
    verdict: ["Hier knirscht es: Schau dir die roten Stellen am Faden an und überlege, ob eine andere Kombination besser passt.", "Grundsätzlich stimmig – an den gelben Stellen solltest du deine Wahl im Methodenteil begründen.", "Interviewform, Offenheit, Logik und Verfahren greifen gut ineinander."],
    pdf: "Als PDF speichern (A4)", restart: "Neu starten", pdfHint: "Im Druckdialog „Als PDF speichern“ wählen. Das Layout ist für A4 vorbereitet.",
    faden: "Der Faden deiner Entscheidungen", fadenLegend: 'Die Linie zwischen zwei Punkten zeigt, wie gut sie zusammenpassen: <span class="fit g">gut</span> <span class="fit o">begründen</span> <span class="fit b">überdenken</span>',
    nodes: ["Ziel", "Interviewform", "Offenheit", "Auswertungslogik", "Verfahren"], change: "ändern",
    goalOk: "Passt zu deinem Ziel.", goalNo: "Nicht die naheliegendste Form für dein Ziel – begründe die Wahl.",
    achten: "⚠️ Worauf du achten solltest", sup0: (n) => "jellyqda unterstützt " + n + " nur als Werkzeug zum Markieren und Notieren – die sequenzielle Interpretation passiert außerhalb, am besten in einer Interpretationsgruppe.",
    stepsT: "🪜 Schritte: ", jq: "🪼 Dein Weg in jellyqda", allSteps: "Alle Funktionen Schritt für Schritt mit Screenshots →",
    method: "✍️ Baustein für den Methodenteil", methodNote: "Ein Startpunkt, kein fertiger Text. Platzhalter in [eckigen Klammern] ersetzen und mit Quellen belegen.",
    lit: "📚 Zum Weiterlesen", litNote: "Auflagen bitte vor dem Zitieren prüfen.",
    printTitle: "Forschungs-Fahrplan", printMade: "Erstellt mit der jellyqda Assistenz am ", printUrl: "thedivingshellyfish.github.io/jellyqda/de/assistenz/"
  },
  home: {
    progress: "geschafft", heroDone: "Dein Fahrplan steht 🎉", heroNew: "Wo stehst du gerade?",
    heroText: "Der Kompass führt dich von deiner Forschungsfrage über die Interviewform bis zum passenden Auswertungsverfahren – und zeigt, was das in jellyqda bedeutet.",
    kpi: ["Grundlagen", "jellyqda-Schritte", "Checklisten"], start: " Kompass starten", cont: " Kompass fortsetzen", seePlan: " Fahrplan ansehen",
    startWith: "Womit möchtest du anfangen?",
    tiles: [["Forschungs-Kompass", "Interviewform, Offenheit, Logik, Verfahren – mit Passungs-Check und Fahrplan als A4-PDF."], ["Grundlagen", "Induktiv & deduktiv, Mayring, Kuckartz, Gütekriterien – mit Schaubildern und Mini-Quiz."], ["jellyqda Schritt für Schritt", "Von der Installation bis zum A4-Bericht – mit Screenshots und R-Code."], ["Checklisten", "Vor der Erhebung, Transkription, Analyse, Methodenteil."]],
    faq: "Beliebte Fragen",
    faqs: [["#/basics/logik", "🔁", "Induktiv oder deduktiv – was passt zu mir?", "mit interaktivem Schaubild"], ["#/basics/interviews", "🎙️", "Offen, halboffen, leitfadengestützt – was ist der Unterschied?", "Interviewformen im Überblick"], ["#/basics/verfahren", "🧭", "Mayring, Kuckartz oder Meuser & Nagel?", "Verfahren-Landkarte"], ["#/basics/mayring", "🪜", "Wie geht Paraphrase → Generalisierung → Reduktion?", "zum Durchklicken"], ["#/more/glossar", "🔤", "Was heißt eigentlich …?", " Begriffe im Glossar"]]
  },
  foot: 'jellyqda ist frei (MIT) und läuft komplett offline · <a href="../">Projektseite</a> · <a href="https://github.com/thedivingshellyfish/jellyqda">GitHub</a> · <a href="https://github.com/thedivingshellyfish/jellyqda/blob/main/docs/wiki/de/Home.md">Wiki</a> · <a href="#/more/set">Datenschutz</a>',
  basics: { title: "Grundlagen", read: (a, b) => a + " von " + b + " gelesen", quiz: "Quiz", quizT: "🎯 Kurz geprüft", right: "Richtig! ", wrong: "Nicht ganz. ", mark: " Als gelesen markieren", isRead: " Gelesen", good: "Gut gemacht ✓", crumb: "Grundlagen" },
  tour: { title: "jellyqda Schritt für Schritt", done: (a, b) => a + " von " + b + " erledigt", step: "Schritt", asR: "Dasselbe als R-Code:", tip: "Tipp", isDone: " Erledigt", doneNext: " Erledigt & weiter",
    more: 'Ausführlich mit allen Details: <a href="https://github.com/thedivingshellyfish/jellyqda/blob/main/docs/wiki/de/Home.md">Wiki</a> · <a href="../../dev/reference/">R-Referenz</a>',
    tags: { start: ["n", "Grundlagen"], beide: ["mix", "induktiv & deduktiv"], de: ["de", "eher deduktiv"], in: ["in", "eher induktiv"] } },
  more: { title: "Mehr", sub: "Checklisten, Glossar, Literatur, Datenschutz & Einstellungen", tabs: [["check", "Checklisten"], ["glossar", "Glossar"], ["lit", "Literatur"], ["set", "Daten & Einstellungen"]],
    search: "Begriff suchen …", noHit: "Kein Treffer.", litHint: "Eine Auswahl zum Einstieg. Auflagen bitte vor dem Zitieren prüfen.",
    theme: "Darstellung", themeSub: "Hell, dunkel oder wie dein System", themes: [["auto", "Auto"], ["light", "Hell"], ["dark", "Dunkel"]],
    wipe: "Gespeicherte Daten löschen", wipeSub: "Kompass-Auswahl, Quiz, Checklisten und erledigte Schritte aus diesem Browser entfernen", wipeBtn: " Löschen",
    wipeQ: "Wirklich alle gespeicherten Daten dieser Seite aus deinem Browser löschen?", wiped: "Gelöscht",
    privT: "🔒 Wo deine Daten liegen",
    priv: "<p>Diese Seite <b>setzt keine Cookies</b> und hat <b>kein Tracking</b>. Damit dein Fortschritt beim nächsten Besuch noch da ist, speichert sie ihn im <b>lokalen Speicher deines Browsers</b> (<code>localStorage</code>) – technisch ähnlich wie ein Cookie, aber er wird nie an einen Server geschickt.</p><p>Gespeichert werden nur: deine Auswahl im Kompass, Quiz-Antworten, abgehakte Checklisten und Schritte sowie die Darstellung (hell/dunkel). Keine Namen, keine Forschungsdaten.</p><p>Die Daten bleiben auf diesem Gerät und in diesem Browser. Im privaten Fenster werden sie beim Schließen verworfen. Löschen kannst du sie jederzeit hier unten oder über die Browser-Einstellungen („Websitedaten löschen“).</p>",
    noStore: "Dein Browser erlaubt gerade keinen lokalen Speicher (z. B. privates Fenster). Die Seite funktioniert trotzdem, vergisst den Fortschritt aber beim Schließen."
  },
  notice: { t: "Keine Cookies, kein Tracking.", d: "Dein Fortschritt wird nur lokal in deinem Browser gespeichert.", ok: "Verstanden", more: "Mehr dazu" },
  check: { tot: "Checklisten" }
};

const VISTX = {
  quali: { head: ["", "qualitativ", "quantitativ"], rows: [["Ziel", "verstehen, rekonstruieren", "messen, erklären, prüfen"], ["Daten", "Texte, Bilder, Beobachtungen", "Zahlen, standardisierte Antworten"], ["Stichprobe", "klein, gezielt ausgewählt", "groß, möglichst zufällig"], ["Vorgehen", "offen, zirkulär", "standardisiert, linear"], ["Verallgemeinerung", "auf Theorie / Typen", "auf eine Population"]] },
  logik: { layers: [["Theorie & Vorwissen", "Forschungsstand, Leitfaden"], ["Kategorien", "Codes & Subcodes"], ["Material", "Transkripte, Notizen"]],
    l: { ableiten: "ableiten", anwenden: "anwenden", buendeln: "bündeln", verall: "verallgemeinern", haupt: ["Haupt-", "kategorien"], sub: ["Sub-", "kategorien"], schaerfen: "schärfen", ab1: "Überraschung → Hypothese", ab2: "am Material prüfen" },
    aria: "Schaubild ",
    txt: { de: "<b>Deduktiv:</b> Die Theorie gibt Kategorien vor, du wendest sie mit einem Kodierleitfaden auf das Material an.", in: "<b>Induktiv:</b> Aus Textstellen werden Codes, aus Codes Kategorien, aus Kategorien Konzepte.", mix: "<b>Deduktiv-induktiv:</b> Hauptkategorien kommen aus Theorie oder Leitfaden (blau), Subkategorien entstehen am Material (violett).", ab: "<b>Abduktiv:</b> Ein überraschender Befund verlangt eine neue Erklärung, die du am Material prüfst – ein Kreislauf." } },
  spek: { axis: ["offen", "halboffen", "strukturiert"], cap: "Punkt = typischer Strukturierungsgrad, gestrichelt = üblicher Spielraum.", wissen: "Wissen:", take: " Im Kompass übernehmen" },
  karte: { aria: "Landkarte der Auswertungsverfahren", x: ["◀ deduktiv", "induktiv ▶"], y: ["beschreibend ▶", "◀ rekonstruktiv"], cap: "Tippe auf einen Punkt, um das Verfahren zu sehen." },
  prozess: { P: [["Fragestellung & Vorwissen", "Frage präzisieren, Vorwissen offenlegen", "Projekt-Memo"], ["Sampling & Feldzugang", "Wer, wie viele, warum?", ""], ["Leitfaden & Pretest", "SPSS-Prinzip, Probeinterview", ""], ["Erhebung", "Interview + Postskript", "Dokument-Memo"],
      ["Transkription", "Regeln, Pseudonymisierung, Zeitmarken", ""], ["Import & Segmente", "Text einfrieren, Variablen", "Import"], ["Kodieren & Kategorien", "deduktiv / induktiv", "Codebaum, Kodierleitfaden"], ["Interpretieren", "Memos, Zusammenfassungen", "Memos, Mayring, Summary Grid"],
      ["Fallübergreifend analysieren", "Vergleiche, Muster, Typen", "Matrix, Fallvergleich, KWIC"], ["Bericht & Methodenteil", "belegen, dokumentieren", "Bericht, Protokoll, Codebuch"]],
    loop: "↻ Bei Grounded Theory wechseln sich Erhebung und Auswertung ab (theoretisches Sampling)." },
  baum: { T: [["#E69F00", "Berufsweg", 12, [["KMU", 7], ["Konzern", 4]]], ["#009E73", "Teamklima", 18, [["Unterstützung", 11], ["Konflikte", 5]]], ["#CC79A7", "Motivation", 9, [["intrinsisch", 6], ["extrinsisch", 3]]]],
    cap: "So sieht der Codebaum in jellyqda aus: Hauptcode voll gefärbt, Subcodes mit Rahmen am farbigen Faden. Σ zählt die Codings inklusive Subcodes." },
  mayring: { D: [["„Also ich war fünf Jahre in so ’nem kleinen Betrieb, da musste man halt alles machen, von Buchhaltung bis Kundengespräch.“", "Fünf Jahre im Kleinbetrieb, musste alle Aufgaben übernehmen", "Breites Aufgabenspektrum im KMU", 0],
      ["„Was mir wirklich gefehlt hat, war jemand, den man mal fragen kann, so ’ne Mentorin oder so.“", "Hat eine Ansprechperson/Mentorin vermisst", "Fehlende Unterstützung durch Mentoring", 1],
      ["„Bei uns im Team, da hilft jeder jedem, das ist echt das, was mich hält.“", "Gegenseitige Hilfe im Team hält sie im Job", "Team als Bindungsfaktor", 2],
      ["„Ehrlich gesagt, ohne die Kolleginnen wär ich längst weg.“", "Würde ohne Kolleginnen kündigen", "Team als Bindungsfaktor", 2]],
    K: [["Aufgabenvielfalt im KMU", "#E69F00"], ["Unterstützungsbedarf", "#56B4E9"], ["Team als Bindungsfaktor", "#009E73"]],
    L: ["Original", "Paraphrase", "Generalisierung", "Reduktion"], th: ["Textstelle", "Paraphrase", "Generalisierung", "Kategorie"],
    cap: ["Vier Textstellen aus einem (fiktiven) Interview.", "Z1 Paraphrase: Inhalt knapp in eigenen Worten, ohne Ausschmückungen.", "Z2 Generalisierung: auf ein einheitliches Abstraktionsniveau heben. Die beiden letzten Stellen werden gleich!", "Z3/Z4 Reduktion: Bedeutungsgleiches streichen, Ähnliches bündeln – aus vier Stellen werden drei Kategorien. In jellyqda: das sind deine Codes."] },
  kreis: { P: [["Initiierende Textarbeit", "Lesen, wichtige Stellen markieren, Memos und erste Fallzusammenfassungen schreiben.", "Memos, Dokument-Memos"], ["Hauptkategorien entwickeln", "Meist aus Forschungsfrage, Theorie und Leitfaden.", "+ Code, Kodierleitfaden"], ["Erster Kodierprozess", "Das gesamte Material mit den Hauptkategorien kodieren.", "Kodier-Leiste, Strg+1…9"],
      ["Subkategorien induktiv bilden", "Alle Stellen einer Hauptkategorie zusammenstellen und Subkategorien am Material bilden.", "Codings eines Codes, + Subcode, In vivo"], ["Zweiter Kodierprozess", "Das Material mit dem ausdifferenzierten System erneut kodieren.", "Umkodieren in der Coding-Leiste"],
      ["Einfache & komplexe Analysen", "Kategorienbasiert, fallbezogen, Zusammenhänge, Fallvergleiche.", "Matrix, Fallvergleich, Summary Grid"], ["Verschriftlichen & dokumentieren", "Ergebnisse darstellen, Vorgehen nachvollziehbar machen.", "Bericht, Codebuch, Protokoll"]],
    center: ["Forschungs-", "frage(n)"], phase: "Phase ", aria: "Sieben Phasen nach Kuckartz" },
  transkript: '<div class="transcript">' +
    '<div><span class="ts">[00:01:12]</span> <span class="sp">I:</span> Erzählen Sie doch mal, wie Sie zu <span class="ps">[Firma A]</span> gekommen sind.</div>' +
    '<div><span class="ts">[00:01:20]</span> <span class="sp">B3:</span> Ja, also (.) das war eigentlich Zufall. <span class="pa">(lacht)</span> Ich hab in <span class="ps">[Stadt B]</span> studiert und …</div>' +
    '<div><span class="ts">[00:02:47]</span> <span class="sp">I:</span> Wie war das dann am Anfang im Team?</div></div>' +
    '<div class="cap"><span style="color:var(--accent2)">■</span> Zeitmarke &nbsp; <span style="color:var(--accent)">■</span> Sprecherkürzel – daraus bildet jellyqda mit <code>segments = "speaker"</code> je Redebeitrag ein Segment. &nbsp; <span style="color:var(--warn)">■</span> Pseudonym in eckigen Klammern.</div>'
};

function PRWHY(sel, p) {
  const out = [];
  if (sel.lg) {
    const v = PR[p].lg[sel.lg], n = LG[sel.lg].name;
    out.push(v === 2 ? "Arbeitet " + n.toLowerCase() + " – passt zu deiner Logik." : v === 1 ? "Lässt sich " + n.toLowerCase() + " anwenden, ist aber nicht der Kern des Verfahrens." : "Arbeitet anders als deine gewählte Logik (" + n + ").");
  }
  if (sel.iv) {
    const iv = IV[sel.iv];
    out.push(iv.good.includes(p) ? "Wird bei der Form „" + iv.name + "“ häufig genutzt." : iv.ok.includes(p) ? "Bei der Form „" + iv.name + "“ möglich – begründe die Wahl im Methodenteil." : "Bei der Form „" + iv.name + "“ eher unüblich.");
  }
  return out.join(" ");
}

function PLAN(sel) {
  const st = ST[sel.st], L = [];
  L.push({ t: "Projekt anlegen & Vorwissen festhalten", d: "Bevor du kodierst: ein Projekt-Memo „Mein Vorwissen & Annahmen“. Das ist die Basis für reflektierte Subjektivität.", r: 'library(jellyqda)\nqda_open("meine-arbeit.jellyqda")\nqda_memo_add("Vorwissen: …", title = "Mein Vorwissen")' });
  L.push({ t: "Transkripte importieren", d: "Segmente nach " + (st.segmode === "speaker" ? "Sprecherwechsel" : "Absätzen") + ". Variablen (z. B. Rolle) gleich mit anlegen; Postskripte als Dokument-Memos.", r: 'qda_import(c("interview_01.docx", "interview_02.docx"), segments = "' + st.segmode + '")\nqda_source_set_var(1, "Rolle", "…")' });
  if (sel.lg === "de") {
    L.push({ t: "Kategoriensystem aus der Theorie anlegen", d: "Hauptkategorien und ggf. Ausprägungen als Subcodes. Eine Restkategorie „Sonstiges“ für Unerwartetes.", r: 'qda_code_add("Kategorie A")\nqda_code_add("Ausprägung 1", parent = "Kategorie A")\nqda_code_add("Sonstiges")' });
    L.push({ t: "Kodierleitfaden schreiben", d: "Definition, Ankerbeispiel, Kodierregel für jede Kategorie (Buch-Symbol).", r: 'qda_code_guide("Kategorie A", definition = "…", rule = "…")' });
    L.push({ t: "Probedurchlauf & Überarbeitung", d: "10–50 % des Materials kodieren, Kategorien und Regeln schärfen. Änderungen in einem Code-Memo begründen." });
    L.push({ t: "Hauptdurchlauf", d: "Alles kodieren. Suchtreffer-Codieren nur mit anschließender Durchsicht." });
  } else if (sel.lg === "in") {
    L.push({ t: "Initiierende Textarbeit", d: "Erstes Interview langsam lesen, Auffälliges als Textstellen-Memo (Strg+M)." });
    L.push({ t: "Offen kodieren", d: "Textnah benennen, gern In vivo. Noch nicht zu früh ordnen." });
    if (["mayring_z", "meuser", "glaeser"].includes(sel.pr)) L.push({ t: "Paraphrasieren & generalisieren", d: "Analyse → Zusammenfassung (Mayring): Paraphrase und Generalisierung je Coding.", r: 'qda_coding_set_summary(1, paraphrase = "…", generalization = "…")' });
    L.push({ t: "Verdichten", d: "Nach jedem zweiten/dritten Interview: umbenennen, als Subcode umhängen, zusammenführen. Code-Memos mit Definitionen.", r: 'qda_code_move("Code", parent = "Oberkategorie")\nqda_code_merge("Code alt", into = "Code neu")' });
    L.push({ t: "Gegenprüfen mit Wortlisten", d: "Worthäufigkeiten und Stichwort im Kontext zeigen Feldbegriffe und Zusammenhänge.", r: 'qda_words(n = 30)\nqda_kwic("Begriff")' });
  } else if (sel.lg === "mix") {
    L.push({ t: "Hauptkategorien anlegen", d: "Aus Forschungsfrage und Leitfaden – deduktiv. Im Code-Memo vermerken: „vorab gebildet“.", r: 'qda_code_add("Thema aus Leitfaden-Block 1")\nqda_code_add("Thema aus Leitfaden-Block 2")' });
    L.push({ t: "Erster Kodierdurchlauf", d: "Ganzes Material grob mit den Hauptkategorien kodieren (Strg+1…9)." });
    L.push({ t: "Subkategorien am Material bilden", d: "Codings einer Hauptkategorie durchsehen, Subcodes bilden (In vivo, + Subcode). Im Code-Memo: „induktiv gebildet“." });
    L.push({ t: "Kodierleitfaden & zweiter Durchlauf", d: "Leitfaden für das finale System, dann umkodieren in der Coding-Leiste.", r: 'qda_code_guide("Subkategorie", definition = "…", rule = "…")\nqda_coding_recode(12, "Subkategorie")' });
  } else {
    L.push({ t: "Sequenzen markieren", d: "Codes als Lesezeichen nutzen (z. B. „Erzählung“, „Argumentation“, „Eingangspassage“) – nicht als Ergebnis." });
    L.push({ t: "Interpretieren in Memos", d: "Jede Interpretation als Textstellen-Memo direkt an der Sequenz." });
    L.push({ t: "Interpretationsgruppe vorbereiten", d: "Bericht mit Randspalte drucken (A4) – Nummern im Text, Memos am Rand." });
  }
  if (["kuckartz_s", "flick", "kuckartz_t"].includes(sel.pr)) L.push({ t: "Fallzusammenfassungen", d: "Summary Grid: je Kategorie und Fall eine thematische Zusammenfassung.", r: 'qda_summary_set("Hauptkategorie", 1, "…")' });
  L.push({ t: "Fallübergreifend auswerten", d: "Code-Matrix, Fallvergleich nach Variablen, Zitate sammeln.", r: 'qda_matrix()\nqda_case_matrix("Rolle")\nqda_segments("Kategorie A")' });
  L.push({ t: "Dokumentieren", d: "Bericht, Codebuch und Protokoll für Anhang und Methodenteil; Backup an zweitem Ort.", r: 'qda_export("all")\nqda_export("audit")\nqda_backup()' });
  return L;
}

function METHOD(sel) {
  const iv = IV[sel.iv], st = ST[sel.st], pr = PR[sel.pr];
  const lgTxt = { de: "deduktiv; die Kategorien wurden vorab aus [Theorie/Forschungsstand] abgeleitet und in einem Kodierleitfaden mit Definitionen, Ankerbeispielen und Kodierregeln festgehalten", in: "induktiv; die Kategorien wurden schrittweise am Material entwickelt und regelmäßig verdichtet", mix: "deduktiv-induktiv; Hauptkategorien wurden aus [Leitfaden/Theorie] abgeleitet, Subkategorien induktiv am Material gebildet", ab: "rekonstruktiv; die Interviews wurden sequenziell interpretiert, Codes dienten der Strukturierung des Materials" }[sel.lg];
  return "Die Daten wurden in [N] Interviews erhoben, geführt als " + iv.name + " (nach " + iv.by + "). " +
    "Die Interviews waren " + st.name.toLowerCase().replace(" (", ", ").replace(")", "") + " angelegt und dauerten zwischen [x] und [y] Minuten. " +
    "Sie wurden aufgezeichnet, nach [Transkriptionsregeln] transkribiert und pseudonymisiert. " +
    "Die Auswertung erfolgte " + lgTxt + ", orientiert an der " + pr.name + " nach " + pr.by + ". " +
    "Kodiert wurde computergestützt mit dem R-Paket jellyqda (Version 0.7.0). Kodierleitfaden, Memos und ein vollständiges Änderungsprotokoll der Analyse sind im Anhang dokumentiert.";
}
