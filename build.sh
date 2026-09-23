#!/usr/bin/env bash
# ============================================================================
# Setzt alle Übungs-Markdown-Dateien (uebungen/**/aufgaben.md) sowie die
# README.md mit dem DHSN-Typst-Template (lib.typ) zu PDF.
#
# Nur die erzeugten *.pdf gehören ins Repo; dieses Skript, lib.typ und assets/
# sind per .gitignore ausgenommen (siehe HANDOFF.md §5).
#
#   ./build.sh            alle aufgaben.md + README.md setzen
#   ./build.sh --open     zusätzlich die PDFs öffnen (macOS)
#
# Trick: cmarker/Typst lösen relative Pfade (Logo!) zum kompilierten .typ auf.
# Deshalb legen wir den Wrapper jeweils im Repo-Root ab (wo lib.typ + assets/
# liegen) und geben der Markdown-Quelle den Pfad relativ zum Root mit.
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"

command -v typst >/dev/null || { echo "FEHLER: typst nicht installiert (brew install typst)." >&2; exit 1; }

OPEN=false
[ "${1:-}" = "--open" ] && OPEN=true

# Liste der zu setzenden Markdown-Dateien (relativ zum Root).
QUELLEN=()
for md in uebungen/*/aufgaben.md; do [ -f "$md" ] && QUELLEN+=("$md"); done
for md in uebungen/*/handout.md; do [ -f "$md" ] && QUELLEN+=("$md"); done
for md in uebungen/*/cheatsheet.md; do [ -f "$md" ] && QUELLEN+=("$md"); done

[ -f README.md ] && QUELLEN+=("README.md")

for md in "${QUELLEN[@]}"; do
  pdf="${md%.md}.pdf"
  # "Vorbereitung" für Entdecken-/Lese-Blätter, sonst "Aufgabe"; README neutral.
  art="Aufgabe"
  case "$md" in
    *handout.md)        art="Vorbereitung" ;;
    *08_selbststudium*) art="Vorbereitung" ;;
    README.md)          art="Information" ;;
  esac
  wrapper=".wrap_$$_$RANDOM.typ"
  cat > "$wrapper" <<TYP
#import "lib.typ": dhsn-material
#dhsn-material("$md", art: "$art")
TYP
  typst compile "$wrapper" "$pdf"
  rm -f "$wrapper"
  echo "PDF gesetzt: $pdf"
  $OPEN && [ "$(uname)" = "Darwin" ] && open "$pdf"
done

echo "Fertig – $(( ${#QUELLEN[@]} )) PDF(s)."
