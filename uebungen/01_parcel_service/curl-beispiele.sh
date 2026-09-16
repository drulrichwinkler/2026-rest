#!/usr/bin/env bash
# ===========================================================================
# curl in acht Beispielen – zum Lesen und zum Laufenlassen.
#
# Die wichtigsten Schalter:
#
#   -i              Statuszeile und Antwort-Header mit ausgeben
#   -X METHODE      HTTP-Methode (ohne -X ist es GET, mit -d ein POST)
#   -H 'Name: Wert' einen Header mitschicken
#   -d '...'        Body mitschicken
#   -s              still: keine Fortschrittsanzeige (fast immer sinnvoll –
#                   sonst legt curl eine Tabelle ueber die Ausgabe)
#   -o DATEI        Body in eine Datei schreiben (/dev/null = wegwerfen)
#   -D DATEI        Antwort-Header in eine Datei schreiben
#   -w 'FORMAT'     nach der Antwort etwas ausgeben, z. B. %{http_code}
#
# Die Pfade nehmen eine der Varianten aus Aufgabe A3 an – passen Sie sie an
# Ihren Entwurf an.
# ===========================================================================
BASIS=http://localhost:8000


echo
echo "== 1. GET mit Headern =========================================="
# Bei REST ist der Statuscode Teil der Antwort. Schauen Sie ihn sich an.
curl -s -i $BASIS/parcels


echo
echo "== 2. Nur der Statuscode ======================================="
# Body wegwerfen, Code ausgeben. Praktisch in Schleifen.
curl -s -o /dev/null -w '%{http_code}\n' $BASIS/parcels


echo
echo "== 3. POST mit JSON ============================================"
# -d macht daraus automatisch ein POST. Den Content-Type muss man selbst
# setzen – ohne ihn hält der Server den Body für ein HTML-Formular.
curl -s -i -X POST $BASIS/parcels \
     -H 'Content-Type: application/json' \
     -d '{"recipient":"Erika Mustermann","city":"01067 Dresden","weight_kg":2.5}'


echo
echo "== 4. Einen Antwort-Header weiterverwenden ======================"
# -D legt die Header ab, danach holt grep den ETag heraus.
# tr -d '\r' entfernt das CR der HTTP-Zeilenendung – sonst schleppen Sie ein
# unsichtbares Zeichen in den nächsten Request.
curl -s -o /dev/null -D /tmp/kopf.txt $BASIS/parcels/4711
ETAG=$(grep -i '^etag:' /tmp/kopf.txt | cut -d' ' -f2 | tr -d '\r')
echo "ETag ist $ETAG"


echo
echo "== 5. Einen Header mitschicken: If-Match ======================="
# Mit veralteter Vorbedingung muss der Server ablehnen -> 412.
curl -s -i -X PUT $BASIS/parcels/4711 \
     -H 'Content-Type: application/json' \
     -H 'If-Match: "gewiss-veraltet"' \
     -d '{"assigned_driver":"A"}'


echo
echo "== 6. Bedingt lesen: If-None-Match ============================="
# Passt der ETag, antwortet der Server mit 304 und ohne Body.
curl -s -i $BASIS/parcels/4711 -H "If-None-Match: $ETAG"


echo
echo "== 7. Denselben Request zweimal schicken ======================="
# Gleicher Idempotency-Key, zwei Versuche: gleiche Antwort, eine Zahlung.
KEY=$(uuidgen)
for i in 1 2; do
  echo "Versuch $i:"
  curl -s -w ' -> %{http_code}\n' -X POST $BASIS/parcels/4711/payments \
       -H 'Content-Type: application/json' \
       -H "Idempotency-Key: $KEY" \
       -d '{"amount":"12.90","currency":"EUR"}'
done


echo
echo "== 8. Zwei Requests gleichzeitig ==============================="
# & schickt in den Hintergrund, wait sammelt ein – so laufen beide Requests
# wirklich gleichzeitig. Erwartung: 200 und 412. Zweimal 200 heisst, dass eine
# der beiden Zuweisungen verlorengegangen ist (Lost Update, Teil D).
# Dafuer muss Ihre API mit --workers 4 laufen.
for N in A B; do
  curl -s -o /dev/null -w "$N: %{http_code}\n" -X PUT $BASIS/parcels/4711 \
       -H 'Content-Type: application/json' \
       -H "If-Match: $ETAG" \
       -d "{\"assigned_driver\":\"$N\"}" &
done
wait



