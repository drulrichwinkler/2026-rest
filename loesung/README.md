# loesung/

Hier entsteht das Python-Projekt (`uv init`, siehe die `README.md` im Repo-Root).

## Dokumente

| Datei | Inhalt |
| --- | --- |
| `DATENMODELL.md` | Warum der Storage aus B1 ein Dual-Write-Problem enthält, welche Lösungsansätze es gibt, und der konkrete Entwurf |
| `API.md` | Ressourcentabelle und Repräsentationen (Teil A) |

## Mermaid

- **VS Code** rendert Mermaid seit Version 1.121 in der Markdown-Vorschau, in
  Notebook-Zellen und im Chat — Matt Bierners `markdown-mermaid` wurde als
  Built-in „Mermaid Markdown Features" übernommen. Nichts zu installieren, auch
  nicht in der `devcontainer.json`: Built-ins laufen im UI-Teil, unabhängig vom
  Container.
- **GitHub** rendert ```mermaid-Blöcke in `.md` ohnehin.
- **`build.sh`/Typst rendert kein Mermaid.** Deshalb liegen diese Dokumente unter
  `loesung/` und nicht unter `uebungen/` — die Globs in `build.sh` greifen nur auf
  `uebungen/*/aufgaben.md`, `uebungen/*/handout.md` und `README.md`. Soll ein
  Diagramm ins PDF, vorher mit `mmdc` nach SVG rendern (Setup in
  `iot/mermaid/package.json`).
