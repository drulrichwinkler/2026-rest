#!/usr/bin/env bash
# ============================================================================
# Einmalig nach dem Bau des Dev-Containers.
#
# Installiert wird nur, was auf SYSTEM-Ebene nötig ist, damit Sie eine
# Python-REST-API bauen können:
#
#   * curl, httpie, jq        HTTP-Requests von Hand stellen und auswerten
#   * uuidgen                 Idempotency-Keys erzeugen
#   * uv                      der Paketmanager – das PROJEKT legen Sie selbst an
#
# Es gibt bewusst KEINE Datenbank. Ihre Daten liegen in Dateien unter
# $DATA_DIR. Sperren, atomares Schreiben und Versionierung bauen Sie selbst –
# genau das ist der Lerninhalt und nicht an ein DBMS delegierbar.
#
# Bewusst NICHT installiert: FastAPI, Flask & Co. Diese Abhängigkeiten wählen
# und installieren Sie selbst mit `uv add`.
# ============================================================================
set -euo pipefail

echo "==> Systempakete installieren"
# Das Basis-Image bringt eine Yarn-Paketquelle mit abgelaufenem Schlüssel mit.
# Wir brauchen kein Yarn; die Quelle fliegt raus, sonst scheitert `apt-get update`.
sudo rm -f /etc/apt/sources.list.d/yarn.list
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
  httpie \
  jq \
  uuid-runtime \
  curl >/dev/null

echo "==> uv installieren (Paketmanager; ein Projekt legt er noch nicht an)"
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null
fi
export PATH="$HOME/.local/bin:$PATH"

echo
echo "==> Versionen"
python3 --version
uv --version || echo "uv: neues Terminal öffnen, damit PATH greift"

cat <<HINWEIS

------------------------------------------------------------------------
Bereit.

Datenablage      Dateien unter \$DATA_DIR
                 ($DATA_DIR)
                 Das Verzeichnis existiert noch nicht – Ihr Code legt es an.
                 Keine Datenbank: Sperren und atomares Schreiben sind Ihre
                 Aufgabe, nicht die eines DBMS.
Ihre API         auf Port 8000 starten, dann Reiter "Ports" -> 8000

Projekt anlegen (macht der Container absichtlich nicht für Sie):

    mkdir -p loesung && cd loesung
    uv init
    uv add fastapi "uvicorn[standard]"

    uv run uvicorn main:app --reload --host 0.0.0.0 --port 8000   # Entwicklung
    uv run uvicorn main:app --workers 4 --host 0.0.0.0 --port 8000 # Teil D + Abnahme

Aufgabenstellung:  uebungen/01_parcel_service/aufgaben.md
------------------------------------------------------------------------
HINWEIS
