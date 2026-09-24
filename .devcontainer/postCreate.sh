#!/usr/bin/env bash
# ============================================================================
# Einmalig nach dem Bau des Dev-Containers.
#
# Systemwerkzeuge für alle drei Übungen:
#
#   * curl, httpie, jq        HTTP-Requests von Hand stellen und auswerten
#   * uuidgen                 Idempotency-Keys erzeugen
#   * uv                      Paketmanager für das Projekt unter loesung/
#   * sqlite3                 Outbox aus Übung 03 inspizieren
# Danach installiert uv die Abhängigkeiten des bestehenden Python-Projekts
# unter loesung/ (FastAPI, Uvicorn, Multipart, HTTP-Client und pytest).
# Paket- und Tracking-Daten aus 01/02 bleiben dateibasiert.
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
  curl \
  sqlite3 >/dev/null

echo "==> uv installieren (Paketmanager)"
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null
fi
export PATH="$HOME/.local/bin:$PATH"

echo "==> Python-Projekt und Abhängigkeiten installieren"
uv sync --project loesung --locked
mkdir -p "$DATA_DIR" "$STAGING_DIR" "$FILE_DATA_DIR"

echo
echo "==> Versionen"
python3 --version
uv --version || echo "uv: neues Terminal öffnen, damit PATH greift"
uv run --project loesung python -c 'import fastapi, multipart, httpx, pytest; print("FastAPI, Multipart, httpx, pytest: OK")'

cat <<HINWEIS

------------------------------------------------------------------------
Bereit.

Datenablage      Pakete + SQLite: $DATA_DIR
                 Upload-Zwischenablage: $STAGING_DIR
                 Sortierte Bilder: $FILE_DATA_DIR
Python-Projekt   loesung/pyproject.toml; Abhängigkeiten sind installiert.
API-Ports        Parcel-Service: 8000, File-Service: 8001

Starten Sie Ihre Dienste aus loesung/ mit uv run uvicorn, sobald Sie
die Anwendungen geschrieben haben. Den Relay starten Sie separat.
Aufgaben: uebungen/01_parcel_service, 02_atomar_file_ops,
          03_transactional_outbox
------------------------------------------------------------------------
HINWEIS
