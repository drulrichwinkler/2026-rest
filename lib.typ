// ============================================================================
// DHSN Lehrmaterial – Typst-Template (Duale Hochschule Sachsen)
//
// Setzt Flipped-Classroom-Material (Vorbereitungs-Handout oder Aufgabenblatt)
// direkt aus einer Markdown-Quelldatei. Der Inhalt bleibt Markdown und wird
// nicht abgeschrieben; das Template liest ihn ein, zieht die Metadaten aus dem
// YAML-Frontmatter und setzt alles mit schlichtem DHSN-Briefkopf.
//
// Verwendung (siehe handout.typ / aufgabe.typ, jeweils drei Zeilen):
//   #import "lib.typ": dhsn-material
//   #dhsn-material("handout.md", art: "Vorbereitung")
// ============================================================================

#import "@preview/cmarker:0.1.6"

// ---- Zurückhaltende Farben -------------------------------------------------
#let ink   = rgb("#1A1A1A")
#let muted = rgb("#555555")
#let rule  = luma(150)
#let akzent = rgb("#00539F")   // DHSN-Blau, dezent für Akzente

// ---- Institutionsdaten -----------------------------------------------------
#let institution = "Duale Hochschule Sachsen"
#let akademie    = "Staatliche Studienakademie Dresden"

// ---- Frontmatter aus einer Markdown-Quelle lösen ---------------------------
// Gibt (meta: dictionary, body: str) zurück. Ohne Frontmatter: meta = (:).
#let frontmatter-teilen(quelle) = {
  let treffer = quelle.match(regex("(?s)^---\r?\n(.*?)\r?\n---\r?\n"))
  if treffer == none {
    (meta: (:), body: quelle)
  } else {
    (meta: yaml(bytes(treffer.captures.at(0))), body: quelle.slice(treffer.end))
  }
}

// ---- Bausteine für die Markdown-Datei (per HTML-Kommentar aufrufbar) --------
// z. B.:  <!-- raw-typst #hinweis[Nutze ein multilinguales Embedding-Modell.] -->

// Farbig hinterlegter Merk-/Tipp-Kasten.
#let hinweis(inhalt, titel: "Hinweis") = {
  v(0.3em)
  block(width: 100%, inset: (x: 10pt, y: 8pt), radius: 3pt,
        fill: akzent.lighten(92%), stroke: (left: 2.5pt + akzent))[
    #text(weight: "bold", fill: akzent)[#titel] \
    #inhalt
  ]
  v(0.3em)
}

// Aufgaben-/Abgabe-Kasten mit Umrandung.
#let kasten(inhalt, titel: none) = {
  v(0.3em)
  block(width: 100%, inset: (x: 10pt, y: 8pt), radius: 3pt, stroke: 0.6pt + rule)[
    #if titel != none [#text(weight: "bold")[#titel] \ ]
    #inhalt
  ]
  v(0.3em)
}

// Zeitangabe / Aufwand als kleines Label (z. B. am Aufgabenkopf).
#let aufwand(text-inhalt) = box(inset: (x: 5pt, y: 2pt), radius: 2pt,
  fill: luma(238))[#text(size: 8pt, fill: muted)[⏱ #text-inhalt]]

// ---- Haupt-Template --------------------------------------------------------
// art: "Vorbereitung" (Pre-Class-Handout) oder "Aufgabe" (Übungsblatt).
// Werte aus dem Frontmatter lassen sich per benannten Argumenten übersteuern.
#let dhsn-material(
  quelle,                        // Pfad zur .md-Datei
  art: none,                     // "Vorbereitung" | "Aufgabe"
  titel: none,
  modul: none,
  thema: none,
  dozent: none,
  semester: none,
  bearbeitungszeit: none,
  logo: "assets/dhsn_logo.png",
) = {
  let geteilt = frontmatter-teilen(read(quelle))
  let m = geteilt.meta

  let f(argument, schluessel, vorgabe: "") = {
    if argument != none { argument }
    else if schluessel in m { str(m.at(schluessel)) }
    else { vorgabe }
  }

  let art              = f(art,              "art",              vorgabe: "Aufgabe")
  let titel            = f(titel,            "titel")
  let modul            = f(modul,            "modul")
  let thema            = f(thema,            "thema")
  let dozent           = f(dozent,           "dozent",           vorgabe: "Dr. Winkler")
  let semester         = f(semester,         "semester")
  let bearbeitungszeit = f(bearbeitungszeit, "bearbeitungszeit")

  set document(title: art + " – " + titel, author: dozent)
  set text(font: ("Libertinus Serif", "Times New Roman"), size: 11pt, fill: ink, lang: "de")
  set par(justify: true, leading: 0.68em, spacing: 1.0em)
  set list(spacing: 0.6em, indent: 0.6em, marker: ([–], [·]))
  set enum(spacing: 0.6em, indent: 0.6em)
  show raw.where(block: false): it => box(fill: luma(240), inset: (x: 3pt, y: 0pt),
    outset: (y: 3pt), radius: 2pt, text(size: 9.5pt, it))
  show raw.where(block: true): it => block(width: 100%, fill: luma(246), inset: 9pt,
    radius: 3pt, text(size: 9pt, it))
  show link: set text(fill: akzent)

  set page(
    paper: "a4",
    margin: (top: 2.4cm, bottom: 2.2cm, left: 2.6cm, right: 2.6cm),
    header: context {
      if counter(page).get().first() > 1 {
        set text(size: 9pt, fill: muted, style: "italic")
        grid(columns: (1fr, auto),
          align(left)[#art · #titel],
          align(right)[#modul],
        )
        v(2pt)
        line(length: 100%, stroke: 0.4pt + rule)
      }
    },
    footer: context {
      set text(size: 9pt, fill: muted)
      line(length: 100%, stroke: 0.4pt + rule)
      v(3pt)
      grid(columns: (1fr, auto),
        align(left)[#institution · #dozent],
        align(right)[Seite #counter(page).display() von #counter(page).final().first()],
      )
    },
  )

  // ---- Überschriften ----
  set heading(numbering: none)
  show heading.where(level: 1): it => { v(0.9em); block(text(size: 13pt, weight: "bold", fill: akzent, it.body)); v(0.2em) }
  show heading.where(level: 2): set text(size: 11.5pt, weight: "bold")

  // ---- Tabellen im Booktabs-Stil ----
  set table(
    stroke: (x, y) => (top: if y == 1 { 0.5pt + ink } else { 0pt }, rest: 0pt),
    inset: (x: 6pt, y: 5pt),
  )
  show table: it => block(width: 100%,
    stroke: (top: 0.8pt + ink, bottom: 0.8pt + ink, rest: 0pt),
    inset: (y: 2pt), below: 1.1em, text(size: 9.5pt, it))
  show table.cell.where(y: 0): set text(weight: "bold")

  // ---- Briefkopf ----
  grid(columns: (1fr, auto), align: (bottom + left, bottom + right),
    text(size: 9pt, fill: muted)[#institution \ #akademie],
    image(logo, height: 1.0cm),
  )
  v(4pt)
  line(length: 100%, stroke: 0.8pt + ink)
  v(1.2em)

  // ---- Titelblock ----
  text(size: 9pt, fill: akzent, weight: "bold", upper(art + (if art == "Vorbereitung" { " zur Vorlesung" } else { " zur Vorlesung" })))
  v(0.2em)
  text(size: 17pt, weight: "bold")[#titel]
  v(0.6em)

  let feld(k, v) = if v != none and v != "" { ([#text(fill: muted)[#k]], [#v]) } else { () }
  grid(columns: (auto, 1fr), row-gutter: 0.4em, column-gutter: 1.2em,
    ..feld("Modul", modul),
    ..feld("Thema", thema),
    ..feld("Dozent", dozent),
    ..feld("Semester", semester),
    ..feld("Bearbeitungszeit", bearbeitungszeit),
  )
  v(0.6em)
  line(length: 100%, stroke: 0.4pt + rule)
  v(1em)

  // ---- Inhalt aus der Markdown-Datei ----
  // cmarker erkennt den Baustein-Aufruf nur ohne Leerzeichen hinter „<!--".
  // Beide Schreibweisen zulassen, damit die .md-Datei lesbar bleibt.
  let body = geteilt.body.replace(regex("<!--\s+raw-typst"), "<!--raw-typst")
  cmarker.render(
    body,
    scope: (hinweis: hinweis, kasten: kasten, aufwand: aufwand),
    raw-typst: true,
  )
}
