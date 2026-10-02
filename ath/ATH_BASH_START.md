# ATH in Git Bash starten

1. Windows-Startmenü öffnen, „Git Bash“ suchen und öffnen.
2. Einen Codeblock mit Strg+C kopieren.
3. Im Git-Bash-Fenster Rechtsklick → Paste/Einfügen. Alternativ Umschalt+Einfügen.
4. Enter drücken. Das Dollarzeichen des Terminal-Prompts wird nicht mitkopiert.

## Erster Befehl

```bash
printf 'Hallo ATH!\n'
```

## Das vorbereitete Experiment

ATH_BASH_EXPERIMENT.sh von der ATH-Webseite herunterladen. In Git Bash:

```bash
cd ~/Downloads
bash ATH_BASH_EXPERIMENT.sh demo
```

Erwartet: ANNA 7.0000 ATH, BEN 3.0000 ATH, TOTAL 10.0000 ATH und DEMO PASS.

Die Demonstration legt getrennte lokale Testschlüssel und ein Ledger in einem neuen temporären Verzeichnis an. Die genaue Adresse zeigt der Lauf. Die Schlüssel werden nicht hochgeladen. Das sind Beispieleinheiten eines eigenen Bash-Experiments.

## Ein Skript selbst in der Konsole schreiben

Den ganzen Block einschließlich der beiden ATH_CODE-Zeilen einfügen:

```bash
cat > mein-erstes-ath.sh <<'ATH_CODE'
#!/usr/bin/env bash
printf 'ATH: Mein erstes Bash-Skript läuft!\n'
ATH_CODE
bash mein-erstes-ath.sh
```

Die erste Zeile öffnet die Datei zum Schreiben. Die alleinstehende letzte ATH_CODE-Zeile beendet den Text. Anschließend führt bash die Datei aus. Ein chmod ist für „bash datei.sh“ nicht nötig.

## Was Bash hier übernimmt

Buchungslogik, ganzzahlige Untereinheiten, Hashverkettung, Ledger-Replay, CLI und Prüfungen sind in Bash. OpenSSL erzeugt und prüft RSA-Signaturen; sha256sum berechnet Hashes. Das ist keine ausschließlich aus Bash-Builtins bestehende Kryptografie. Der Webseiten-Generator ist ebenfalls Bash; der Browser benötigt weiter HTML/CSS und JavaScript für Interaktion.

## Bewusster Umfang dieses ersten Experiments

Ein Prozess; ANNA kann an BEN übertragen; feste Beispielmenge 10 ATH. Beitragsausgabe, Gründer-Vesting, Revenue, unabhängige Nodes, gleichzeitige Writer und Crash-Recovery sind noch eigene Baustufen. Die PowerShell-Pakete bleiben die getrennte Vergleichsbasis; dieses Experiment ersetzt sie nicht.

Quellen für Einfügen: https://mintty.github.io/mintty.1.html
Webseite und Bash-Code: ISC, siehe LICENSE.txt.
