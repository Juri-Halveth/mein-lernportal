# ATH in Git Bash starten

1. Windows-StartmenÃ¼ Ã¶ffnen, â€žGit Bashâ€œ suchen und Ã¶ffnen.
2. Einen Codeblock mit Strg+C kopieren.
3. Im Git-Bash-Fenster Rechtsklick â†’ Paste/EinfÃ¼gen. Alternativ Umschalt+EinfÃ¼gen.
4. Enter drÃ¼cken. Das Dollarzeichen des Terminal-Prompts wird nicht mitkopiert.

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

Die Demonstration legt getrennte lokale TestschlÃ¼ssel und ein Ledger in einem neuen temporÃ¤ren Verzeichnis an. Die genaue Adresse zeigt der Lauf. Die SchlÃ¼ssel werden nicht hochgeladen. Das sind Beispieleinheiten eines eigenen Bash-Experiments.

## Ein Skript selbst in der Konsole schreiben

Den ganzen Block einschlieÃŸlich der beiden ATH_CODE-Zeilen einfÃ¼gen:

```bash
cat > mein-erstes-ath.sh <<'ATH_CODE'
#!/usr/bin/env bash
printf 'ATH: Mein erstes Bash-Skript lÃ¤uft!\n'
ATH_CODE
bash mein-erstes-ath.sh
```

Die erste Zeile Ã¶ffnet die Datei zum Schreiben. Die alleinstehende letzte ATH_CODE-Zeile beendet den Text. AnschlieÃŸend fÃ¼hrt bash die Datei aus. Ein chmod ist fÃ¼r â€žbash datei.shâ€œ nicht nÃ¶tig.

## Was Bash hier Ã¼bernimmt

Buchungslogik, ganzzahlige Untereinheiten, Hashverkettung, Ledger-Replay, CLI und PrÃ¼fungen sind in Bash. OpenSSL erzeugt und prÃ¼ft RSA-Signaturen; sha256sum berechnet Hashes. Das ist keine ausschlieÃŸlich aus Bash-Builtins bestehende Kryptografie. Der Webseiten-Generator ist ebenfalls Bash; der Browser benÃ¶tigt weiter HTML/CSS und JavaScript fÃ¼r Interaktion.

## Bewusster Umfang dieses ersten Experiments

Ein Prozess; ANNA kann an BEN Ã¼bertragen; feste Beispielmenge 10 ATH. Beitragsausgabe, GrÃ¼nder-Vesting, Revenue, unabhÃ¤ngige Nodes, gleichzeitige Writer und Crash-Recovery sind noch eigene Baustufen. Die PowerShell-Pakete bleiben die getrennte Vergleichsbasis; dieses Experiment ersetzt sie nicht.

Quellen fÃ¼r EinfÃ¼gen: https://mintty.github.io/mintty.1.html
Webseite und Bash-Code: ISC, siehe LICENSE.txt.

## Beträge jetzt direkt in ATH

`transfer 1` bedeutet 1 ATH. `transfer 2` bedeutet 2 ATH. `transfer 0.0001` bedeutet eine Untereinheit. Punkt oder Komma sind zulässig; höchstens vier Nachkommastellen. Die gespeicherten Ledgerbeträge bleiben unverändert in Untereinheiten.
