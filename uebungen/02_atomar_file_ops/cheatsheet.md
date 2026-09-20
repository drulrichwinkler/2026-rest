---
art: Cheat Sheet
titel: 'Cheat Sheet · Atomar schreiben in Python'
modul: '3IT-VSIT-50 · Verteilte Systeme und Internet der Dinge'
thema: 'Atomarität, fsync, Sperren, Lost Update, Dual Write'
dozent: 'Dr. Ulrich Winkler'
semester: '5. Semester · Informationstechnik'
---

# Cheat Sheet · Atomar schreiben in Python

## Einführung

Ihr Storage in dieser Übung ist ein Verzeichnis mit Dateien. Kein Datenbank­system
steht dazwischen. Damit haben Sie eine Aufgabe, die Ihnen ein DBMS sonst abnimmt:
**dafür zu sorgen, dass ein halb ausgeführter Schreibvorgang keinen kaputten
Zustand hinterlässt.**

Der Grund ist, dass „eine Datei schreiben" kein einzelner Vorgang ist. Zwischen
Ihrem `write()` und den Bytes auf der Platte liegen drei Stationen, und jede kann
Sie überraschen:

```mermaid
flowchart LR
    P["Ihr Programm"] -->|"write()"| K["Kernel-Puffer"]
    K -->|"fsync()"| C["Platten-Cache"]
    C -->|"F_FULLFSYNC<br/> (nur auf macOS nötig)"| S["Persistent Storage"]

    style S fill:#d4edda
```

**Ein zurückgekehrtes `write()` heißt nur, dass der Kernel die Daten hat.** Gegen einen
Prozessabsturz reicht das; gegen Stromausfall nicht.

Aber nicht nur das - ein einfaches öffnen einer Datei zum schreiben mit `open(pfad, "w")` kürzt die Zieldatei
auf null, bevor das erste Byte fließt. Stirbt der Prozess dazwischen, ist der
alte Zustand weg - und der neue nocht nicht da.

In einem distributed System gibt es oft kongurierende Schreiber, die zur gleichen Zeit
eine Resoruce (Datei) schreiben wollen. Ohne Koordination droht Datenverlust.

Daraus folgen die zwei Fragen, die dieses CheatSheet beantwortet:

1. **Wie mache ich einen Schreibvorgang atomar?** Damit nach einem Absturz
   entweder der alte oder der neue Zustand dasteht — nie eine Mischung.
2. **Wie koordiniere ich mehrere Schreiber?**

Grundsatz von atomaren Operationen auf Filesystem-Ebene: **Was zusammen gültig
werden muss, gehört in eine Datei.** Jede zusätzliche Datei, die mitgepflegt
werden muss, ist ein _Dual Write_ und damit ein potentielles Problem bei
Abstürzen.

---

## (a) Ein Prozess, ein Thread

Gefahr: der **unvollständige Schreibvorgang**. `open(pfad, "w")` kürzt die Zieldatei
auf null, bevor das erste Byte fließt. Stirbt der Prozess dazwischen, ist der
alte Zustand weg und der neue nicht da.

### Das Rezept

**❌ So nicht**

```python
with open(pfad, "w") as f:      # open(..., "w") = O_WRONLY|O_CREAT|O_TRUNC
    os._exit(1)                 # ✗ ABSTURZ — die Datei ist hier schon leer
    json.dump(obj, f)
```

Das `O_TRUNC` im `"w"` kürzt die Zieldatei auf null Bytes, **bevor** das erste
Byte des neuen Inhalts fließt. Ein Absturz in dieser Zeile lässt eine leere oder
halbe JSON-Datei zurück — der alte Zustand ist weg, der neue nie angekommen.

**✅ Musterlösung**

```python
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(pfad), prefix=".tmp-")
with os.fdopen(fd, "wb") as f:
    f.write(data)
    f.flush()
    os.fsync(f.fileno())     # Daten auf Platte, VOR dem Rename
os.replace(tmp, pfad)        # <- der Commit-Punkt, atomar
fsync_dir(os.path.dirname(pfad))   # den Rename selbst haltbar machen
```

| Detail                                            | Warum                                                                                   |
| ------------------------------------------------- | --------------------------------------------------------------------------------------- |
| Temp-Datei im **selben Verzeichnis**              | `os.replace` ist nur _innerhalb eines Dateisystems_ atomar. `/tmp` ist oft ein anderes. |
| `os.replace`, nicht `os.rename`                   | Gleiche Semantik, aber plattformunabhängig überschreibend.                              |
| `fsync` auf die **Datei**, vor dem Replace        | Der Rename ist sofort sichtbar. Die Daten sind es nicht.                                |
| `fsync` auf das **Verzeichnis**, nach dem Replace | Sonst kann der Rename selbst den Stromausfall nicht überleben.                          |
| `.tmp-`-Reste beim Start wegräumen                | Ein Absturz vor dem Replace lässt sie liegen.                                           |

`os.replace` schützt gegen den **Prozess**absturz. Gegen Stromausfall schützt
erst `fsync`, und auf **macOS flusht `fsync` den Plattencache nicht** — dafür
braucht es `fcntl.fcntl(fd, fcntl.F_FULLFSYNC)`.

Dies wird oft in einer Hilfsfunktion `write_atomic` encapsulate:

```python
import os
import tempfile

def write_atomic(path, data):
    directory = os.path.dirname(path) or "."

    fd, tmp = tempfile.mkstemp(dir=directory)

    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())

        os.replace(tmp, path)

    except:
        try:
            os.unlink(tmp)
        except FileNotFoundError:
            pass
        raise
```

### Datei nur anlegen - falls noch nicht existent

Mit den Flags `O_CREATE` und `O_EXCL` kann man eine Datei anlagen - falls diese nicht schon existiert.

**❌ So nicht**

```python
fd = os.open(pfad, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
os._exit(1)             # ✗ ABSTURZ — Name schon belegt, Datei noch leer
os.write(fd, data)
os.close(fd)
```

`O_CREAT | O_EXCL` macht nur den _Anspruch auf den Namen_ atomar, nicht den Inhalt.
Stirbt der Prozess zwischen `open` und `write`, liegt dort eine **leere Datei** —
und jeder Retry liest sie als „schon erledigt, da vorhanden"

**✅ Musterlösung**

```python
fd, tmp = tempfile.mkstemp(dir=d, prefix=".tmp-")
...schreiben, flush, fsync...            # Inhalt fertig, noch namenlos
try:
    os.link(tmp, pfad)                   # <- Commit: scheitert, wenn vergeben
except FileExistsError:
    ...                                  # jemand anderes war schneller
os.unlink(tmp)
fsync_dir(d)                             # der neue Name muss haltbar werden
```

`os.link` hängt den Namen an einen Inhalt, der **bereits vollständig auf der
Platte liegt**. Entweder der Name existiert mit gültigem Inhalt oder gar nicht;
einen Zwischenzustand gibt es nicht.

#### 2. Append-Log — eine Zeile anhängen

**✅ Musterlösung**

```python
with open(pfad, "a") as f:
    f.write(json.dumps(event) + "\n")
    f.flush()
    os.fsync(f.fileno())
```

#### 3. Versionsfeld (die Spalte, die zum `ETag` wird)

**❌ So nicht**

```python
obj = json.loads(open(pfad).read())
# ⟵ ✗ HIER liest der zweite Prozess denselben Stand
obj["version"] = "abc"
write_atomic(pfad, json.dumps(obj).encode())   # jeder Write gelingt - auch vom zweiten Prozess
```

Jeder einzelne Schreibvorgang ist sauber, und das Ergebnis ist trotzdem falsch:
Zwei Prozesse lesen denselben Stand, beide schreiben, der zweite überschreibt den
ersten. **Lost Update**

Mit Hilfe einer Sperre auf einer Datei können sich Prozesse unterenander abstimemn. `fcntl.flock` ist
ein Wrapper um den Unix-Systemaufruf flock(2).

**✅ Musterlösung**

```python
def update(pfad, changes):
    lock_path = pfad + ".lock"

    with open(lock_path, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)

        # Ab hier ist dieser Prozess exklusiv (`LOCK_EX`)
        with open(pfad, "r") as f:
            obj = json.load(f)

        obj.update(changes)
        obj["version"] += 1

        write_atomic(
            pfad,
            json.dumps(obj).encode()
        )

        # beim Verlassen wird der Lock automatisch freigegeben
```

## Dateisystem-Operationen in Python — Nachschlagteil

Die Signaturen stammen aus der Python-3.14-Dokumentation.

### Schreiben und Committen

| Aufruf                 | Was es tut                                                                                | Fallstrick                                                                                                                                                |
| ---------------------- | ----------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `os.replace(src, dst)` | benennt um, überschreibt `dst` still. **Atomar, wenn es gelingt.**                        | Nur _innerhalb eines Dateisystems_. `/tmp` ist oft ein anderes — Temp-Datei ins **Zielverzeichnis**. Und: Last-Writer-Wins, überschreibt ohne Rückfrage.  |
| `os.rename(src, dst)`  | dasselbe, aber unter Windows schlägt es fehl, wenn `dst` existiert                        | Deshalb immer `os.replace` nehmen                                                                                                                         |
| `os.link(src, dst)`    | zweiter Name für dieselbe Datei. Schlägt mit `FileExistsError` fehl, wenn `dst` existiert | **First-Writer-Wins** — das Gegenteil von `os.replace`. Taugt als Commit-Punkt, wenn der Inhalt vorher fertig ist                                         |
| `os.write(fd, bytes)`  | schreibt in den Kernel-Puffer, gibt die Zahl der Bytes zurück                             | **Darf kurz zurückkommen.** Rückgabewert prüfen, sonst steht eine halbe Zeile da                                                                          |
| `os.fsync(fd)`         | zwingt den Kernel-Puffer auf die Platte                                                   | Macht den **Inhalt** haltbar, nicht den **Verzeichniseintrag**. Auf macOS erreicht es den Plattencache nicht — dafür `fcntl.fcntl(fd, fcntl.F_FULLFSYNC)` |
| `os.sync()`            | schreibt _alles_ raus                                                                     | Nur für Notfälle; blockiert das ganze System                                                                                                              |
| `f.flush()`            | leert den **Python**-Puffer in den Kernel                                                 | Ersetzt `fsync` **nicht**. Reihenfolge: `flush()` → `fsync(fileno())`                                                                                     |

### Öffnen: die Flags, auf die es ankommt

`os.open(path, flags, mode=0o777)` — Flags mit `|` kombinieren.

| Flag                             | Bedeutung                                                                         | Wofür hier                                                                    |
| -------------------------------- | --------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `O_CREAT \| O_EXCL`              | anlegen, aber **fehlschlagen**, wenn es schon existiert                           | der `UNIQUE`-Constraint des Dateisystems                                      |
| `O_APPEND`                       | jeder Write geht ans Dateiende, Positionieren und Schreiben ohne Lücke dazwischen | das Append-only-Log                                                           |
| `O_TRUNC`                        | kürzt auf null Bytes                                                              | **steckt im eingebauten `open(p, "w")`** — die Ursache des zerrissenen Writes |
| `O_WRONLY`, `O_RDONLY`, `O_RDWR` | Zugriffsart                                                                       | Pflichtangabe, genau eine davon                                               |
| `O_DIRECTORY`                    | nur Verzeichnisse öffnen                                                          | für den Verzeichnis-`fsync`                                                   |
| `O_SYNC`, `O_DSYNC`              | jeder Write wartet auf die Platte                                                 | korrekt, aber langsam — `fsync` an der richtigen Stelle ist meist besser      |

> `open(pfad, "w")` ist `O_WRONLY | O_CREAT | O_TRUNC`. Das `O_TRUNC` ist der
> Grund, warum diese Zeile Ihre alte Datei vernichtet, bevor die neue existiert.

### Sperren

| Aufruf                                | Art                              | Reichweite                                                                             |
| ------------------------------------- | -------------------------------- | -------------------------------------------------------------------------------------- |
| `fcntl.flock(fd, LOCK_EX)`            | **advisory**, hängt am Inode     | Prozesse auf **einem** Host. Über NFS emuliert — und `local_lock` schaltet es still ab |
| `fcntl.flock(fd, LOCK_EX \| LOCK_NB)` | dasselbe, nicht blockierend      | wirft `BlockingIOError` statt zu warten                                                |
| `fcntl.flock(fd, LOCK_UN)`            | freigeben                        | passiert auch beim `close()` — verlassen Sie sich nicht darauf                         |
| `fcntl.lockf(fd, LOCK_EX)`            | POSIX-Record-Lock, bereichsweise | andere Semantik: wird beim Schließen **jedes** Deskriptors auf die Datei freigegeben   |
| `threading.Lock()`                    | prozessintern                    | **nutzlos bei `--workers 4`** — jeder Worker hat sein eigenes                          |

**Advisory** heißt: Die Sperre wirkt nur zwischen denen, die sie nehmen. Wer
direkt schreibt, wird nicht gehindert.

### Temporäre Dateien

| Aufruf                                      | Anmerkung                                                                             |
| ------------------------------------------- | ------------------------------------------------------------------------------------- |
| `tempfile.mkstemp(dir=..., prefix=".tmp-")` | legt sicher an, gibt `(fd, pfad)` zurück. **Sie** müssen aufräumen                    |
| `tempfile.mktemp()`                         | **deprecated** — liefert nur einen Namen, zwischen Name und Anlegen klafft eine Lücke |
| `tempfile.NamedTemporaryFile(delete=False)` | Alternative, wenn Sie ein Dateiobjekt statt eines Deskriptors wollen                  |

`dir=` auf das **Zielverzeichnis** setzen — sonst scheitert `os.replace` an der
Dateisystemgrenze.

### Lesen und Prüfen

| Aufruf                     | Wofür                                                                     |
| -------------------------- | ------------------------------------------------------------------------- |
| `os.stat(pfad).st_size`    | Log-Größe als billiger Cache-Validator, O(1)                              |
| `os.stat(pfad).st_nlink`   | „Habe _ich_ diesen `link()` gesetzt?" — 2 heißt: Temp-Name existiert noch |
| `os.scandir(d)`            | Verzeichnis lesen, schneller als `listdir` + `stat`                       |
| `pathlib.Path.read_text()` | bequem, aber **puffernd** — für die heiklen Stellen `os.read` nehmen      |

---

## Offizielle Dokumentation

| Thema                                | Fundstelle                                                             |
| ------------------------------------ | ---------------------------------------------------------------------- |
| `os` — Betriebssystem-Schnittstellen | <https://docs.python.org/3/library/os.html>                            |
| Dateideskriptor-Operationen          | <https://docs.python.org/3/library/os.html#file-descriptor-operations> |
| `os.open`-Flags, vollständige Liste  | <https://docs.python.org/3/library/os.html#open-constants>             |
| `fcntl` — Sperren (nur Unix)         | <https://docs.python.org/3/library/fcntl.html>                         |
| `tempfile`                           | <https://docs.python.org/3/library/tempfile.html>                      |
| `pathlib`                            | <https://docs.python.org/3/library/pathlib.html>                       |
| `shutil` — Kopieren, Baumoperationen | <https://docs.python.org/3/library/shutil.html>                        |

**Unterhalb von Python** — die Manpages sagen, was wirklich garantiert ist:
`man 2 rename`, `man 2 fsync`, `man 2 open`, `man 2 flock`, `man 2 link`.
Im Container: `apt-get install manpages-dev`.

**Zum Weiterlesen, wenn Sie es genau wissen wollen:**

- Pillai et al., _All File Systems Are Not Created Equal_ (OSDI 2014) — misst
  nach, welche Annahmen über atomares Umbenennen auf welchem Dateisystem
  tatsächlich halten. Ernüchternd.
- Die SQLite-Seite _Atomic Commit In SQLite_
  (<https://www.sqlite.org/atomiccommit.html>) — dasselbe Problem, von Leuten
  gelöst, die es sehr ernst genommen haben.
- `man 2 fsync` unter **macOS**, Abschnitt zu `F_FULLFSYNC`
