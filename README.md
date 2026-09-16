# Mein Lernportal

**Öffnen. Suchen. Lernen.**

[Mein Lernportal](https://juri-halveth.github.io/mein-lernportal/) ist ein statisches, frei zugängliches Lernuniversum mit 702 Lektionen in 13 Themenwelten. Die Startseite öffnet direkt den Katalog. Es gibt keine Anmeldung, Paywall, Werbung oder eingebautes Tracking.

## Was enthalten ist

- 702 eindeutige Lektionen und Quizze in 133 Lernstufen
- Einstieg und Alltag, künstliche Intelligenz, Machine Learning, HTML, Python, JavaScript, digitale Sicherheit, Mathematik, Marketing, SEO, Projekte, Server sowie anschauliche Mathematik
- lokale Fortschrittsanzeige mit Export, Import und Löschung
- Suche über Themenwelten und Lektionstitel
- interaktive Übungen, Quizze, Codeaufgaben und Visualisierungen
- responsive Oberfläche, Hell-/Dunkelmodus und reduzierte Bewegung

Der Lernstand wird nur im Browser gespeichert. Python-Aufgaben laden Pyodide 0.26.2 erst beim Start einer solchen Aufgabe von jsDelivr; der normale Portalstart verwendet ausschließlich Dateien dieses Repositorys.

## Lokal öffnen

```powershell
npm install
npm run serve
```

Danach: <http://127.0.0.1:4175/>

## Prüfen

```powershell
npm test
```

Die Prüfung bindet den Inhaltssnapshot, zählt Tracks, Stufen und eindeutige Lektionen, prüft die produktiven HTML-Shells auf Zugangssperren und lädt die Oberfläche in einer Browser-DOM-Umgebung.

## Herkunft

Die Plattform wurde aus dem geprüften, kontofreien Lernstudio-Stand `8f171e7` aufgebaut und mit dem Curriculum-Snapshot `50775f64d82c0dd77ec2db4a9e0f6a3ab8714ff8cb55eba429fb7d9fa8c14f04` erweitert. Dadurch bleibt der neue öffentliche Stand vom weiterhin accountgebundenen Hosting unter `mein-lernstudio.com` getrennt.

## Lizenz

Originaler Plattformcode und veröffentlichte Originallektionen stehen unter der [ISC-Lizenz](LICENSE.txt). Separat lizenzierte Bestandteile sind in [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt) aufgeführt.
