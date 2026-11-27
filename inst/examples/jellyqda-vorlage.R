# ============================================================================
# jellyqda-Vorlage: eine Codier-Session für die Masterarbeit
# ============================================================================
# So arbeitest du damit in RStudio:
#   1. Dieses Skript öffnen (oder in dein eigenes Skript kopieren).
#   2. Oben bei "projekt_datei" und "meine_dateien" deine echten Namen
#      eintragen.
#   3. Zeilenweise ausführen: Cursor in eine Zeile -> Strg+Enter (alles
#      markieren + Strg+Enter geht auch).
#
# Wichtige Idee von jellyqda:
#   - Eine Projekt-Datei (*.jellyqda) enthält ALLES: Texte, Codes, Codings,
#     Memos und den Audit-Trail. Zum Sichern reicht qda_backup().
#   - Beim Import wird der Text einmalig "eingefroren" (in die Datenbank
#     kopiert). Danach wird nie neu extrahiert -> Zeichen-Offsets bleiben
#     für immer stabil.
#   - 100 % offline: Es wird nie eine Internetverbindung aufgebaut.
# ============================================================================

library(jellyqda)

# --- 0. Projekt öffnen (legt die Datei beim ersten Mal neu an) ------------
projekt_datei <- "meinarbeit.jellyqda"   # <- DEIN Projektordner/Dateiname
qda_open(projekt_datei)
qda_project()   # Überblick: Datei, Größe, Anzahl Quellen/Codes/Codings/Events

# --- 1. Transkripte importieren --------------------------------------------
# txt, md, docx und pdf sind gleichrangig. Der Text wird nach UTF-8
# normalisiert und eingefroren; das Original landet unverändert in originals/.
# (PDF ohne Text-Layer -> Warnung; Original bleibt Quelle, ggf. manuell OCRen.)
meine_dateien <- c(
  "interview_01.docx",
  "interview_02.txt"
  # "interview_03.md",
  # "feldnotizen.pdf"
)
qda_import(meine_dateien)
qda_sources()   # alle Quellen: id, name, format, Zeichen, Segmente, importiert am

# Zum Ausprobieren mit den Beispieldaten des Pakets stattdessen:
# qda_import(system.file("extdata",
#   c("interview_01.txt", "interview_02.md", "interview_03.docx", "fieldnotes.pdf"),
#   package = "jellyqda"))

# --- 2. Codebuch anlegen (deduktiv: aus Leitfaden/Theorie) ------------------
qda_code_add("Beruflicher Werdegang")
qda_code_add("KMU",     parent = "Beruflicher Werdegang",
             description = "kleines Softwareunternehmen")
qda_code_add("Konzern", parent = "Beruflicher Werdegang")
qda_code_add("Motivation")
qda_codes()     # Codebaum mit Pfad (z. B. "Beruflicher Werdegang / KMU") und Farbe

# --- 3. Codieren ------------------------------------------------------------
# Im Viewer siehst du das Transkript mit Segment-Nummern (Segment 1, 2, 3 ...).
qda_view(1)                    # Quelle mit id 1 im Viewer-Pane öffnen
qda_view("interview_01.docx")  # geht auch über den Namen

# Ein Segment bekommt einen Code (+ Memo):
qda_code(source = 1, segment = 3, code = "KMU", memo = "seit 5 Jahren im KMU")

# Oder direkt über Zeichen-Positionen (1-basiert, start und end inklusive):
qda_code(source = 1, start = 120, end = 340, code = "Motivation")

# Induktive Codes entstehen frei während des Codierens (ohne parent):
qda_code_add("Teamklima")
qda_code(source = 2, segment = 5, code = "Teamklima", memo = "Vertrauen ist zentral")

# Alle Fundstellen eines Codes als Tabelle (mit Text-Ausschnitt und Memo):
qda_segments("KMU")

# Alle Codings ansehen (filterbar nach Quelle und Code):
qda_codings()
qda_codings(source = 1, code = "Motivation")

# Einzelnes Coding löschen (wird im Audit-Trail protokolliert):
# qda_coding_delete(7)   # z. B. die Coding-Zeile mit id 7

# Code umbenennen / löschen (ebenfalls protokolliert; löscht Unter-Codes mit):
qda_code_rename("KMU", "KMU-Erfahrung")
# qda_code_delete("Konzern")

# --- 4. Freie Memos (z. B. Notizen zum Leitfaden) ---------------------------
qda_memo_add("Leitfaden-Frage 3 war unklar -- im naechsten Interview nachfragen")
qda_memos()

# --- 5. Fortschritt, Export, Backup -----------------------------------------
qda_stats()     # overall: wie viel % des Materials ist bereits codiert?
qda_matrix()    # Kreuztabelle Code x Dokument (Anzahl Codings)

qda_export("all")    # segments_*.csv/xlsx, codings_*.csv, codebook_*.csv/docx,
                     # audit_*.csv -- alles landet in exports/ neben dem Projekt
qda_export("audit")  # nur der Audit-Trail -> Beleg fürs Methodenkapitel

qda_backup()         # timestamped zip in jellyqda-backups/ (AUSSERHALB des
                     # Projektordners); alte Backups rotieren automatisch
# qda_backup(path = "D:/usb-stick/backups", keep = 20)   # eigener Backup-Pfad

qda_events()         # kompletter Audit-Trail als Tabelle (jede Aktion + Zeitstempel)

# --- 5b. Optional: interaktive App (V2) --------------------------------------
# Ein Befehl startet eine lokale Web-Oberflaeche (nur 127.0.0.1, offline) im
# RStudio-Viewer: Dokumentbaum links, Code-System mit Farben, Dokument-Browser
# Mitte. Text markieren -> farbigen Code-Button klicken -> Coding wird an den
# exakten Zeichen-Positionen gespeichert. Esc beendet die App.
# qda_app()

# --- 5c. Optional: Intercoder-Übereinstimmung (eine zweite Person kodiert) --
# 1. Blind-Kopie für die zweite Person: gleiche Dokumente, Segmente und Codes,
#    aber keine Ihrer Codings. Weitergeben (USB-Stick, verschlüsselte Mail ...).
# qda_intercoder_copy("kodierer_b.jellyqda")
# 2. Die zweite Person öffnet sie mit qda_open("kodierer_b.jellyqda") und kodiert.
# 3. Vergleichen (die andere Datei wird nur gelesen): Kappa, Alpha je Code
# qda_intercoder("kodierer_b.jellyqda")
# qda_intercoder_diff("kodierer_b.jellyqda")   # Abweichungen -> Konsens
# In der App: Analyse -> Reiter "Intercoder".

# --- 6. Sitzung beenden ------------------------------------------------------
qda_close()

# Merke: Nie die .jellyqda-Datei, originals/, exports/ oder Backups in git
# legen -- nur den R-Paket-Code. Die Interview-Daten bleiben lokal.
