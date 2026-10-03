#!/usr/bin/env bash
# SPDX-License-Identifier: ISC
set -euo pipefail
out=${1:-ath-site}
[[ ! -e "$out" ]] || { printf "Ziel existiert bereits: %s\n" "$out" >&2; exit 1; }
mkdir -p "$out"
cat > "$out/app.js" <<'ATH_TEMPLATE_0'
/* SPDX-License-Identifier: ISC */
'use strict';
let anna=100000,ben=0;
const a=document.getElementById('anna'),b=document.getElementById('ben'),message=document.getElementById('result');
function units(n){return new Intl.NumberFormat('de-DE',{maximumFractionDigits:4}).format(n/10000)+' ATH';}
function render(){a.textContent=units(anna);b.textContent=units(ben);}
document.getElementById('transfer').addEventListener('click',()=>{if(anna<30000){message.textContent='Anna hat weniger als 3 ATH. Setze das Beispiel zurück.';return;}anna-=30000;ben+=30000;render();message.textContent='Beispielbuchung: 3 ATH übertragen. Insgesamt bleiben es '+units(anna+ben)+'.';});
document.getElementById('reset').addEventListener('click',()=>{anna=100000;ben=0;render();message.textContent='Zurückgesetzt: Anna hat 10 ATH, Ben hat 0 ATH.';});
ATH_TEMPLATE_0
cat > "$out/ATH_BASH_EXPERIMENT.sh" <<'ATH_TEMPLATE_1'
#!/usr/bin/env bash
# SPDX-License-Identifier: ISC
# LEVIATH / ATH: independent local Bash learning experiment.
# Not a port of V0.5, network consensus, or production wallet.
set -euo pipefail
export LC_ALL=C
umask 077
command=${1:-help}
root=${ATH_ROOT:-"$PWD/.ath-bash-experiment"}
zeros=$(printf '%064d' 0)
die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
hash(){ sha256sum | cut -d' ' -f1; }
quantity(){ printf '%d.%04d ATH' "$(( $1/10000 ))" "$(( $1%10000 ))"; }
requirements(){ command -v openssl >/dev/null || die 'OpenSSL fehlt'; command -v sha256sum >/dev/null || die 'sha256sum fehlt'; }
init(){
 requirements
 [[ ! -e "$root" ]] || die 'Ziel existiert bereits. Nutze einen neuen ATH_ROOT.'
 mkdir -p "$root/keys"; printf '/keys/\n/ledger.tsv\n' > "$root/.gitignore"
 for person in ANNA BEN; do
  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$root/keys/$person.private.pem" 2>/dev/null
  openssl pkey -in "$root/keys/$person.private.pem" -pubout -out "$root/keys/$person.public.pem" 2>/dev/null
 done
 local payload="0|$zeros|GENESIS|GENESIS|ANNA|100000|UNSIGNED"
 printf '%s|%s\n' "$payload" "$(printf '%s' "$payload" | hash)" > "$root/ledger.tsv"
 printf 'INIT: 10.0000 ATH bei ANNA; 0.0000 ATH bei BEN. Lokale Beispielmenge.\n'
}
replay(){
 requirements
 [[ -f "$root/ledger.tsv" ]] || die 'Kein Ledger. Zuerst init oder demo.'
 anna=0; ben=0; expected=0; last=$zeros
 local n prev kind sender receiver amount sig digest extra payload calculated
 while IFS='|' read -r n prev kind sender receiver amount sig digest extra; do
  [[ -z ${extra:-} && $n == "$expected" && $prev == "$last" ]] || die 'Ungültige Reihenfolge oder Hashverkettung'
  [[ $amount =~ ^[0-9]{1,9}$ && $digest =~ ^[a-f0-9]{64}$ ]] || die 'Ungültiges Format'
  payload="$n|$prev|$kind|$sender|$receiver|$amount|$sig"
  calculated=$(printf '%s' "$payload" | hash)
  [[ $calculated == "$digest" ]] || die 'Block-Hash stimmt nicht'
  if ((expected==0)); then
   [[ $kind == GENESIS && $sender == GENESIS && $receiver == ANNA && $amount == 100000 && $sig == UNSIGNED ]] || die 'Ungültiger Beispiel-Genesis'
   anna=100000
  else
   [[ $kind == TRANSFER && (( $sender == ANNA && $receiver == BEN ) || ( $sender == BEN && $receiver == ANNA )) && $sig =~ ^[A-Za-z0-9+/=]+$ ]] || die 'Ungültige Beispielübertragung'
   local balance=$anna; [[ $sender == BEN ]] && balance=$ben
   ((amount>0 && amount<=balance)) || die 'Unzureichendes Guthaben'
   local signed="$n|$prev|$kind|$sender|$receiver|$amount"
   printf '%s' "$sig" | openssl base64 -d -A > "$root/signature.tmp"
   if ! printf '%s' "$signed" | openssl dgst -sha256 -verify "$root/keys/$sender.public.pem" -signature "$root/signature.tmp" >/dev/null 2>&1; then die 'Signaturprüfung fehlgeschlagen'; fi
   if [[ $sender == ANNA ]]; then anna=$((anna-amount)); ben=$((ben+amount)); else ben=$((ben-amount)); anna=$((anna+amount)); fi
  fi
  last=$digest; expected=$((expected+1))
 done < "$root/ledger.tsv"
 ((expected>=1 && anna+ben==100000)) || die 'Beispielmenge stimmt nicht'
}
parse_ath(){
 local value=${1:-}
 [[ $value =~ ^(0|[1-9][0-9]{0,4})([.,]([0-9]{1,4}))?$ ]] || die 'ATH-Betrag erwartet, z.B. 1, 2 oder 0.0001; maximal vier Nachkommastellen'
 local whole=${BASH_REMATCH[1]} fraction=${BASH_REMATCH[3]:-}
 fraction="${fraction}0000"; fraction=${fraction:0:4}
 local amount=$((10#$whole*10000+10#$fraction))
 ((amount>0)) || die 'Betrag muss größer als null sein'
 printf '%d' "$amount"
}
transfer(){
 local sender=ANNA receiver=BEN value
 if (($#==1)); then value=$1
 elif (($#==3)); then sender=$1; receiver=$2; value=$3
 else die 'Aufruf: transfer ANNA BEN 2 oder transfer BEN ANNA 1'; fi
 [[ ( $sender == ANNA && $receiver == BEN ) || ( $sender == BEN && $receiver == ANNA ) ]] || die 'Zwei verschiedene Teilnehmer ANNA und BEN angeben'
 local amount; amount=$(parse_ath "$value")
 replay
 local balance=$anna; [[ $sender == BEN ]] && balance=$ben
 ((amount<=balance)) || die 'Unzureichendes Guthaben'
 local signed="$expected|$last|TRANSFER|$sender|$receiver|$amount"
 local sig; sig=$(printf '%s' "$signed" | openssl dgst -sha256 -sign "$root/keys/$sender.private.pem" | openssl base64 -A)
 local payload="$signed|$sig"
 printf '%s|%s\n' "$payload" "$(printf '%s' "$payload" | hash)" >> "$root/ledger.tsv"
 replay; printf 'TRANSFER: '; quantity "$amount"; printf ' %s -> %s; Signatur und Menge geprüft.\n' "$sender" "$receiver"
}
status(){ replay; printf 'ANNA: '; quantity "$anna"; printf '\nBEN:  '; quantity "$ben"; printf '\nTOTAL: '; quantity "$((anna+ben))"; printf '\nRECORDS: %d\nCHAIN HEAD: %s\n' "$expected" "$last"; }
case "$command" in
 init) init;;
 transfer) transfer "${@:2}";;
 verify) replay; printf 'PASS: Hashverkettung, Signaturen, Reihenfolge und Beispielmenge.\n';;
 status) status;;
 demo)
  if [[ -z ${ATH_ROOT:-} ]]; then root=$(mktemp -d "${TMPDIR:-/tmp}/ath-bash.XXXXXXXX")/ledger; fi
  init; transfer 3; status
  printf 'DEMO PASS. Datenverzeichnis: %s\n' "$root"
  printf 'Scope: ein Prozess, zwei lokale Schlüssel, feste Beispielmenge; keine Gleichwertigkeit mit V0.5.\n';;
 help|--help|-h)
  printf 'ATH Bash Experiment\n  bash ATH_BASH_EXPERIMENT.sh demo\n  ATH_ROOT="./mein-neues-ledger" bash ATH_BASH_EXPERIMENT.sh init\n  ATH_ROOT="./mein-neues-ledger" bash ATH_BASH_EXPERIMENT.sh transfer 3\n  ATH_ROOT="./mein-neues-ledger" bash ATH_BASH_EXPERIMENT.sh status\n  ATH_ROOT="./mein-neues-ledger" bash ATH_BASH_EXPERIMENT.sh verify\n\nEingabe in ATH: 1 = 1 ATH, 2 = 2 ATH, 0.0001 = eine Untereinheit. Punkt oder Komma; maximal vier Nachkommastellen. Beide Richtungen: transfer ANNA BEN 2 oder transfer BEN ANNA 1. Kurzform transfer 2 bleibt ANNA -> BEN.\nKein Netzwerk, Mint-/Vesting-Modell, paralleler Writer oder Crash-Recovery.\n';;
 *) die 'Unbekannter Befehl. Nutze help.';;
esac
ATH_TEMPLATE_1
cat > "$out/ATH_BASH_START.md" <<'ATH_TEMPLATE_2'
# ATH in Git Bash starten

1. Windows-StartmenÃƒÂ¼ ÃƒÂ¶ffnen, Ã¢â‚¬Å¾Git BashÃ¢â‚¬Å“ suchen und ÃƒÂ¶ffnen.
2. Einen Codeblock mit Strg+C kopieren.
3. Im Git-Bash-Fenster Rechtsklick Ã¢â€ â€™ Paste/EinfÃƒÂ¼gen. Alternativ Umschalt+EinfÃƒÂ¼gen.
4. Enter drÃƒÂ¼cken. Das Dollarzeichen des Terminal-Prompts wird nicht mitkopiert.

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

Die Demonstration legt getrennte lokale TestschlÃƒÂ¼ssel und ein Ledger in einem neuen temporÃƒÂ¤ren Verzeichnis an. Die genaue Adresse zeigt der Lauf. Die SchlÃƒÂ¼ssel werden nicht hochgeladen. Das sind Beispieleinheiten eines eigenen Bash-Experiments.

## Ein Skript selbst in der Konsole schreiben

Den ganzen Block einschlieÃƒÅ¸lich der beiden ATH_CODE-Zeilen einfÃƒÂ¼gen:

```bash
cat > mein-erstes-ath.sh <<'ATH_CODE'
#!/usr/bin/env bash
printf 'ATH: Mein erstes Bash-Skript lÃƒÂ¤uft!\n'
ATH_CODE
bash mein-erstes-ath.sh
```

Die erste Zeile ÃƒÂ¶ffnet die Datei zum Schreiben. Die alleinstehende letzte ATH_CODE-Zeile beendet den Text. AnschlieÃƒÅ¸end fÃƒÂ¼hrt bash die Datei aus. Ein chmod ist fÃƒÂ¼r Ã¢â‚¬Å¾bash datei.shÃ¢â‚¬Å“ nicht nÃƒÂ¶tig.

## Was Bash hier ÃƒÂ¼bernimmt

Buchungslogik, ganzzahlige Untereinheiten, Hashverkettung, Ledger-Replay, CLI und PrÃƒÂ¼fungen sind in Bash. OpenSSL erzeugt und prÃƒÂ¼ft RSA-Signaturen; sha256sum berechnet Hashes. Das ist keine ausschlieÃƒÅ¸lich aus Bash-Builtins bestehende Kryptografie. Der Webseiten-Generator ist ebenfalls Bash; der Browser benÃƒÂ¶tigt weiter HTML/CSS und JavaScript fÃƒÂ¼r Interaktion.

## Bewusster Umfang dieses ersten Experiments

Ein Prozess; ANNA kann an BEN ÃƒÂ¼bertragen; feste Beispielmenge 10 ATH. Beitragsausgabe, GrÃƒÂ¼nder-Vesting, Revenue, unabhÃƒÂ¤ngige Nodes, gleichzeitige Writer und Crash-Recovery sind noch eigene Baustufen. Die PowerShell-Pakete bleiben die getrennte Vergleichsbasis; dieses Experiment ersetzt sie nicht.

Quellen fÃƒÂ¼r EinfÃƒÂ¼gen: https://mintty.github.io/mintty.1.html
Webseite und Bash-Code: ISC, siehe LICENSE.txt.

## BetrÃ¤ge jetzt direkt in ATH

`transfer 1` bedeutet 1 ATH. `transfer 2` bedeutet 2 ATH. `transfer 0.0001` bedeutet eine Untereinheit. Punkt oder Komma sind zulÃ¤ssig; hÃ¶chstens vier Nachkommastellen. Die gespeicherten LedgerbetrÃ¤ge bleiben unverÃ¤ndert in Untereinheiten.

## Beide Richtungen

`bash "$ATH_SCRIPT" transfer ANNA BEN 2` überträgt 2 ATH von Anna an Ben. `bash "$ATH_SCRIPT" transfer BEN ANNA 1` überträgt 1 ATH zurück. Die Kurzform `transfer 2` bleibt Anna → Ben. Jede Übertragung nutzt den Schlüssel ihres Senders.
ATH_TEMPLATE_2
cat > "$out/index.html" <<'ATH_TEMPLATE_5'
<!doctype html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="description" content="ATH ist die digitale Einheit im LEVIATH-Prototyp: BeitrÃƒÂ¤ge, Guthaben und ÃƒÂ¼berprÃƒÂ¼fbare Buchungen. Technischer Stand, Beispiel und Quellen."><meta name="theme-color" content="#122e32"><title>ATH Ã‚Â· LEVIATH</title><link rel="stylesheet" href="style.css"></head>
<body><header class="wrap"><a class="brand" href="#">LEVIATH <span>/ ATH</span></a><nav aria-label="Seitennavigation"><a href="#prinzip">Prinzip</a><a href="#stand">Stand</a><a href="#bash">Bash starten</a><a href="#quellen">Quellen</a><a href="../big-bang/">Lernportal Ã¢â€ â€”</a></nav></header>
<main><section class="hero wrap"><p class="eyebrow">LEVIATH Ã‚Â· Entwicklung vor dem ÃƒÂ¶ffentlichen Launch</p><h1>Ein Beitrag.<br>Eine Buchung.<br><em>ATH.</em></h1><div class="intro"><p>ATH ist die digitale Einheit in LEVIATH. Das Programm registriert BeitrÃƒÂ¤ge, fÃƒÂ¼hrt Guthaben und prÃƒÂ¼ft signierte ÃƒÅ“bertragungen.</p><a class="button" href="#beispiel">Einfach ausprobieren Ã¢â€ â€œ</a><p class="small">Der lokale Kern lÃƒÂ¤uft. Ein ÃƒÂ¶ffentliches Netzwerk und reale Auszahlungen sind die nÃƒÂ¤chsten eigenen Entwicklungsschritte.</p></div><div class="hero-note">Quellenstand 03.10.2026 <span>Lokale Funktionstests ausgefÃƒÂ¼hrt</span></div></section>
<section id="prinzip" class="light"><div class="wrap"><p class="eyebrow">Das Prinzip</p><h2>LEVIATH fÃƒÂ¼hrt das Buch.<br>ATH zÃƒÂ¤hlt die Einheiten.</h2><div class="steps"><article><span>01</span><h3>Arbeit registrieren</h3><p>Eine Anleitung, ein Programm oder ein anderes digitales Artefakt erhÃƒÂ¤lt einen Inhalts-Hash. Er bindet genau diese Dateifassung.</p></article><article><span>02</span><h3>Beitrag vergÃƒÂ¼ten</h3><p>Eine freigegebene Ausgabe verweist auf das registrierte Artefakt. In V0.5 darf sein Hash einmal fÃƒÂ¼r eine Ausgabe verwendet werden.</p></article><article><span>03</span><h3>Guthaben ÃƒÂ¼bertragen</h3><p>Der Sender signiert die Buchung. LEVIATH prÃƒÂ¼ft Signatur und Guthaben. V0.5 erhebt dabei keine ProtokollgebÃƒÂ¼hr.</p></article></div><p class="footnote">Ein Hash bindet Bytes. Die Bewertung und Berechtigung eines Beitrags benÃƒÂ¶tigen eigene Regeln.</p></div></section>
<section id="beispiel" class="wrap demo"><div><p class="eyebrow">Ein Beispiel zum Verstehen</p><h2>Anna gibt Ben<br>3 ATH.</h2><p>Die Gesamtmenge bleibt gleich. Hier kannst du den Ablauf mit Beispielzahlen ansehen.</p><p class="small">Diese Ansicht rechnet im Browser. Sie erstellt keine Wallet und verbindet sich mit keinem Ledger.</p></div><div class="book"><p class="book-heading">Beispielbuch Ã‚Â· 10 ATH insgesamt</p><table><caption class="sr-only">Guthaben im ÃƒÅ“bertragungsbeispiel</caption><thead><tr><th>Person</th><th>Guthaben</th></tr></thead><tbody><tr><td>Anna</td><td id="anna">10 ATH</td></tr><tr><td>Ben</td><td id="ben">0 ATH</td></tr></tbody></table><div class="actions"><button id="transfer" type="button">3 ATH ÃƒÂ¼bertragen</button><button id="reset" class="secondary" type="button">ZurÃƒÂ¼cksetzen</button></div><p id="result" role="status" aria-live="polite">Bereit: Anna hat 10 ATH, Ben hat 0 ATH.</p></div></section>
<section id="stand" class="light"><div class="wrap"><p class="eyebrow">Heute technisch vorhanden</p><h2>Der Kern arbeitet.<br>Die Verbindung wÃƒÂ¤chst noch.</h2><div class="status-grid"><article><h3>V0.5 Ã‚Â· Guthaben & BeitrÃƒÂ¤ge</h3><p>Wallets angelegt, ATH signiert ÃƒÂ¼bertragen, Zustand neu geladen und State-Root reproduziert. Bootstrap, GrÃƒÂ¼nder-Handoff und spÃƒÂ¤tere Beitragsausgabe ausgefÃƒÂ¼hrt. Einnahmenanteile einschlieÃƒÅ¸lich RestbetrÃƒÂ¤gen exakt gebucht.</p><p class="metric">14 Selbsttests + 9 IntegrationsprÃƒÂ¼fungen</p></article><article><h3>V0.3 Ã‚Â· Lokales Quorum</h3><p>Drei Prozesse mit verschiedenen SchlÃƒÂ¼sseln. Ein Block mit drei gÃƒÂ¼ltigen Signaturen; nach Stop eines Knotens ein zweiter mit zwei. Die BlÃƒÂ¶cke sind hashverkettet.</p><p class="metric">2 von 3 Signaturen reichen</p></article></div><p class="footnote">Die Pakete wurden separat geprÃƒÂ¼ft. V0.3 koordiniert BlÃƒÂ¶cke ÃƒÂ¼ber einen Controller; die Knoten signieren Vorschlags-Hashes. Alle drei laufen bisher auf einem Rechner.</p></div></section>
<section class="wrap economics"><p class="eyebrow">GrÃƒÂ¼nderanteil im Bootstrap</p><h2 class="ratio">9 ATH <span>+</span> 1 ATH</h2><p class="large">Neun fÃƒÂ¼r das Netzwerk, eine fÃƒÂ¼r den GrÃƒÂ¼nder.</p><p>Beispiel mit 10 % GrÃƒÂ¼nderanteil: Der Sonderanteil wird gekoppelt an tatsÃƒÂ¤chliche Netzwerkfreigaben ausgegeben. Mit Ende des Bootstrap-Pools endet dieser Sonderpfad. SpÃƒÂ¤tere Beitragsausgaben kÃƒÂ¶nnen bestehende prozentuale Anteile verwÃƒÂ¤ssern.</p></section>
<section class="light"><div class="wrap"><p class="eyebrow">NÃƒÂ¤chster Entwicklungsstand</p><h2>Ein gemeinsamer Betrieb.</h2><ol class="roadmap"><li><strong>Pakete zusammenfÃƒÂ¼hren</strong><span>Guthabenverwaltung und Quorum brauchen ein gemeinsames Regelwerk. V0.3-TestgebÃƒÂ¼hren und V0.5-GebÃƒÂ¼hrenfreiheit sind unterschiedliche Modelle.</span></li><li><strong>UnabhÃƒÂ¤ngige Rechner</strong><span>RegelprÃƒÂ¼fung, Zustandsabgleich und Wiederherstellung mÃƒÂ¼ssen im Mehrrechnerbetrieb nachgewiesen werden.</span></li><li><strong>Reale Verwendung definieren</strong><span>AusgabeautoritÃƒÂ¤t, Bewertung, Rechte und tatsÃƒÂ¤chliche Zahlungen erhalten jeweils eigene Vereinbarungen und Integrationen.</span></li></ol><p class="footnote">ATH hat im geprÃƒÂ¼ften Stand keinen belegten Marktpreis oder zugesagte EinlÃƒÂ¶sbarkeit. Einnahmenbuchungen bewegen kein externes Geld.</p></div></section>
<section id="bash" class="wrap bash-guide"><p class="eyebrow">Neu Ã‚Â· das Bash-Experiment</p><h2>Code kopieren.<br>In Git Bash einfÃƒÂ¼gen.<br>Enter.</h2><p>Ãƒâ€“ffne unter Windows das StartmenÃƒÂ¼ und suche <strong>Git Bash</strong>. Kopiere den Befehl. Im Terminal: Rechtsklick Ã¢â€ â€™ Paste/EinfÃƒÂ¼gen, dann Enter. Alternativ: Umschalt+EinfÃƒÂ¼gen.</p><pre><code>printf 'Hallo ATH!\n'</code></pre><p><a href="ATH_BASH_EXPERIMENT.sh" download="ATH_BASH_EXPERIMENT.sh">Bash-Experiment herunterladen Ã¢â€ â€œ</a></p><p>Speichere die Datei in Downloads. FÃƒÂ¼hre dann diese beiden Zeilen in Git Bash aus:</p><pre><code>cd ~/Downloads
bash ATH_BASH_EXPERIMENT.sh demo</code></pre><p>Der Lauf erzeugt zwei lokale TestschlÃƒÂ¼ssel, ÃƒÂ¼bertrÃƒÂ¤gt 3 ATH und prÃƒÂ¼ft die Signatur sowie die Hashverkettung. Erwartet: Anna 7 ATH, Ben 3 ATH, Gesamtmenge 10 ATH.</p><p class="small">Dies ist ein eigenes Bash-Lernexperiment mit festem Beispielbestand. Bash fÃƒÂ¼hrt Buchungen und Replay aus; OpenSSL ÃƒÂ¼bernimmt Kryptografie. Beitragsausgabe, GrÃƒÂ¼nder-Vesting und Netzbetrieb folgen als eigene Baustufen.</p><div class="source-links"><a href="ATH_BASH_START.md">Anleitung: eigenes Skript in der Konsole schreiben Ã¢â€ â€”</a><a href="BUILD_ATH_WEBSITE.sh" download="BUILD_ATH_WEBSITE.sh">Webseiten-Generator in Bash herunterladen Ã¢â€ â€œ</a></div></section><section id="quellen" class="wrap sources"><p class="eyebrow">Quellen Ã‚Â· Lizenz Ã‚Â· Zuordnung</p><h2>Nachvollziehbar gebaut.</h2><p>Projektkontext: <a href="https://github.com/Juri-Halveth">Juri-Halveth</a> / LEVIATH. Grundlage sind die vier bereitgestellten EntwicklungsstÃƒÂ¤nde und die eigenen lokalen Funktionstests vom 03.10.2026. ATH ist die vom Projektverantwortlichen festgelegte Einheitenbezeichnung.</p><div class="source-links"><a href="ATH_EINFACH_ERKLAERT.pptx">PowerPoint: ATH einfach erklÃƒÂ¤rt Ã¢â€ â€”</a><a href="technical-receipt.json">Technisches PrÃƒÂ¼freceipt Ã¢â€ â€”</a><a href="SOURCES.md">Quellen und Abgrenzung Ã¢â€ â€”</a><a href="LICENSE.txt">Lizenz der Webseite: ISC Ã¢â€ â€”</a><a href="LEVIATH_LICENSE_MIT.txt">V0.5-Quelllizenz: MIT Ã¢â€ â€”</a><a href="https://github.com/Juri-Halveth/mein-lernportal/tree/main/ath">Webseiten-Quellcode Ã¢â€ â€”</a></div><p class="small">Die Webseite erweitert das Lernportal. Die LEVIATH-Quellpakete behalten ihre eigenen Lizenzangaben. Die Projektbezeichnung und die Copyright-Zuordnung der Quellen bleiben erhalten.</p></section></main><footer class="wrap"><span>LEVIATH / ATH Ã‚Â· Stand 03.10.2026</span><a href="../privacy.html">Datenschutz</a><span>Ohne Tracking Ã‚Â· ohne Wallet-Verbindung</span></footer><script src="app.js"></script></body></html>
ATH_TEMPLATE_5
cat > "$out/LEVIATH_LICENSE_MIT.txt" <<'ATH_TEMPLATE_6'
MIT License

Copyright (c) 2026 LEVIATH contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
ATH_TEMPLATE_6
cat > "$out/LICENSE.txt" <<'ATH_TEMPLATE_7'
ISC License

Copyright (c) 2026 Lernstudio contributors

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

Scope: original Lernstudio platform code and original published lesson content.
Files bearing their own SPDX/license notice retain that license. Third-party
materials retain their notices. This license does not grant trademark,
personality, voice, likeness, or endorsement rights.
ATH_TEMPLATE_7
cat > "$out/SOURCES.md" <<'ATH_TEMPLATE_8'
# ATH / LEVIATH: Quellen und Lizenzen

Stand: 03.10.2026. Projektkontext: Juri-Halveth / LEVIATH.

## Webseite

Diese neue statische Webseite ist eine Erweiterung des Lernportals mein-lernportal. Ihr HTML-, CSS- und JavaScript-Code sowie die neue erklärende Darstellung stehen unter der vorhandenen ISC-Lizenz. Die bestehende Copyright-Zuordnung „2026 Lernstudio contributors“ bleibt in LICENSE.txt erhalten. Die Namensnennung ist Projektzuordnung, keine Behauptung einer unabhängigen Prüfung oder einer Zustimmung Dritter.

## LEVIATH-Quellen

- LEVIATH_IAT_DEVNET_V0_1: frühes Git-Ledger.
- LEVIATH_REWARD_BIND_PATCH_V0_2: Reward-/Adressmetadaten.
- LEVIATH_COLD_RED_BIG_BANG_V0_3: Controller, drei lokale Nodes und Quorum.
- LEVIATH_SIMPLE_PRESTIGE_II_V0_5: Wallets, Guthaben, Artefaktausgaben, Gründer-Handoff und Einnahmenbuchhaltung.

Die vier privaten Ausgangspakete werden hier nicht hochgeladen. Die V0.5-Lizenz liegt zur Zuordnung separat als LEVIATH_LICENSE_MIT.txt bei; sie enthält den unveränderten ursprünglichen Copyright-Hinweis „2026 LEVIATH contributors“. Diese Webseite verändert die Lizenz der Quellpakete nicht.

ATH ist die ausdrücklich festgelegte Einheitenbezeichnung. Die vorbereiteten ATH-Korrekturen sind neue Fassungen; historische Originalpakete und frühere Prüfungen bleiben eigene Quellenstände.

## Beleggrundlage

Die technischen Aussagen beruhen auf Quelltextinspektion und eigenen lokalen Funktionstests. Das minimierte technical-receipt.json enthält Testumfang, Zeitpunkt und V0.5-Quell-Digest. Der Digest bindet Quellbytes, nicht Außenwahrheit oder Produktionssicherheit. V0.3 und V0.5 wurden getrennt geprüft. Die Tests belegen lokalen Betrieb; Mehrrechner-Konsens, vollständige Regelvalidierung und reale Zahlungsausführung bleiben offen.

## PowerPoint

ATH_EINFACH_ERKLAERT.pptx ist die für dieses Projekt erstellte Erklärung mit editierbarem Text und Tabelle. Als neue Erklärung gilt die ISC-Lizenz dieses Webbereichs. Die enthaltenen Quellenangaben bleiben erhalten.

## Darstellung und Betrieb

Die Seite enthält eine Browserrechnung mit Beispielguthaben. Sie hat keine Wallet-Verbindung, keine Zahlungsfunktion, keinen Preisfeed, kein Tracking und keinen Zugriff auf private Schlüssel. Die Erläuterung ist keine zugesagte Einlösbarkeit, kein Eigentumsanteil und kein individueller Zahlungsanspruch. Keine Drittbilder, externen Fonts oder Illustrationen werden eingebunden.

## Bash-Experiment
ATH_BASH_EXPERIMENT.sh ist ein eigenständiges neues Bash-Lernexperiment unter ISC. Ein Prozess, zwei Testschlüssel, feste Beispielmenge. Buchungen, Replay und Hashverkettung werden von Bash orchestriert; OpenSSL übernimmt RSA und sha256sum die Hashfunktion. Dieses Skript ist kein vollständiger V0.5-Port. BUILD_ATH_WEBSITE.sh erzeugt die Textdateien der Website aus Bash-Heredocs. Browser-HTML/CSS/JavaScript bleiben eigene Ausgabetypen.
ATH_TEMPLATE_8
cat > "$out/style.css" <<'ATH_TEMPLATE_9'
:root{--ink:#122e32;--cream:#f4f0e7;--mint:#a5dac8;--line:#385154;--muted:#bad0cb}*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:24px}body{margin:0;background:var(--ink);color:var(--cream);font-family:Arial,Helvetica,sans-serif;font-size:18px;line-height:1.65}.wrap{max-width:1240px;margin:auto;padding:0 48px}header{display:flex;align-items:center;justify-content:space-between;min-height:110px;gap:24px}.brand{font-weight:800;letter-spacing:.04em;text-decoration:none}.brand span{color:var(--mint)}nav{display:flex;gap:26px;font-size:14px}a{color:inherit;text-underline-offset:5px}nav a{text-decoration:none}a:hover{color:var(--mint)}a:focus-visible,button:focus-visible{outline:3px solid #dd9b64;outline-offset:6px}.hero{position:relative;padding-top:60px;padding-bottom:75px;display:grid;grid-template-columns:1.2fr 1fr;column-gap:80px}.eyebrow{text-transform:uppercase;font-size:12px;letter-spacing:.17em;font-weight:bold;margin:0 0 26px;color:var(--mint)}.hero>.eyebrow{grid-column:1/-1}h1{font-size:clamp(64px,7.4vw,105px);line-height:1.03;letter-spacing:-.055em;margin:8px 0 30px}h1 em{font-style:normal;color:var(--mint)}.intro{padding-top:18px;font-size:22px}.intro p:first-child{margin-top:0}.button,button{display:inline-block;background:var(--mint);color:var(--ink);padding:15px 22px;border:0;border-radius:0;font:inherit;font-weight:bold;text-decoration:none;cursor:pointer}.button:hover,button:hover{background:#c3eedf;color:var(--ink)}.small{font-size:14px;color:var(--muted)}.hero-note{grid-column:1/-1;border-top:1px solid var(--line);padding-top:24px;margin-top:38px;display:flex;justify-content:space-between;font-size:13px;color:var(--muted)}.light{background:var(--cream);color:var(--ink);padding:80px 0}.light .eyebrow{color:#176a59}h2{font-size:clamp(37px,4.4vw,59px);line-height:1.12;letter-spacing:-.035em;margin:0 0 38px}h3{font-size:24px;line-height:1.3;letter-spacing:-.02em;margin:16px 0}p{max-width:780px}.steps{display:grid;grid-template-columns:repeat(3,1fr);gap:40px;margin-top:60px}.steps article{border-top:1px solid #a9b5aa;padding-top:22px}.steps article>span{font-size:14px;color:#176a59}.steps p,.status-grid p{font-size:17px}.footnote{font-size:14px;max-width:1040px;margin-top:38px;color:#49615c}.demo{padding-top:90px;padding-bottom:90px;display:grid;grid-template-columns:1fr 1fr;gap:70px}.book{border-top:1px solid var(--mint);padding-top:12px}.book-heading{font-size:14px;color:var(--mint)}table{border-collapse:collapse;width:100%;font-size:27px}th,td{text-align:left;padding:16px 0;border-bottom:1px solid var(--line)}th{font-size:13px;font-weight:normal;color:var(--muted)}th:last-child,td:last-child{text-align:right}.actions{display:flex;gap:12px;margin-top:26px;flex-wrap:wrap}button{font-size:15px}.secondary{background:transparent;color:var(--cream);border:1px solid var(--line)}#result{font-size:14px;min-height:48px;color:var(--muted)}.status-grid{display:grid;grid-template-columns:1fr 1fr;gap:65px}.metric{font-weight:bold;color:#176a59}.economics{padding-top:80px;padding-bottom:85px}.ratio{font-size:clamp(52px,7vw,95px);color:var(--mint)}.ratio span{color:#64807a}.large{font-size:27px}.roadmap{list-style:none;padding:0;counter-reset:road}.roadmap li{counter-increment:road;display:grid;grid-template-columns:40px 280px 1fr;gap:20px;padding:24px 0;border-top:1px solid #b5c1b4}.roadmap li:before{content:'0' counter(road);color:#176a59;font-size:14px}.roadmap span{font-size:17px}.sources{padding-top:80px;padding-bottom:75px}.source-links{display:flex;flex-direction:column;align-items:flex-start;gap:14px;margin:35px 0}.source-links a{font-size:17px}.sources>p{max-width:900px}footer{padding-top:26px!important;padding-bottom:30px!important;border-top:1px solid var(--line);display:flex;justify-content:space-between;gap:20px;font-size:12px;color:var(--muted)}.sr-only{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0,0,0,0)}@media(max-width:760px){.wrap{padding-left:24px;padding-right:24px}header{align-items:flex-start;flex-direction:column;justify-content:center;gap:12px;padding-top:24px;padding-bottom:22px}nav{flex-wrap:wrap;gap:13px 20px}.hero{grid-template-columns:1fr;padding-top:35px;gap:10px}.hero>.eyebrow{font-size:10px}h1{font-size:72px}.intro{font-size:20px}.hero-note{flex-direction:column;gap:8px}.light{padding:58px 0}.steps,.demo,.status-grid{grid-template-columns:1fr;gap:28px}.steps{margin-top:35px}.demo{padding-top:60px;padding-bottom:60px}.roadmap li{grid-template-columns:30px 1fr;gap:10px}.roadmap span{grid-column:2}.economics,.sources{padding-top:58px;padding-bottom:58px}footer{flex-direction:column;gap:8px}.ratio{font-size:55px}}@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}}

.bash-guide{padding-top:80px;padding-bottom:80px}.bash-guide pre{max-width:850px;overflow-x:auto;background:#091f22;border-left:3px solid var(--mint);padding:24px;font-size:17px;line-height:1.8}.bash-guide code{font-family:Consolas,monospace}.bash-guide>p{max-width:850px}
ATH_TEMPLATE_9
cat > "$out/technical-receipt.json" <<'ATH_TEMPLATE_10'
{
  "unit": "ATH",
  "recordedAt": "2026-10-02T23:38:37.9536152Z",
  "v05": {
    "sourceSHA256": "D33C7B0BEA4BA6C78977C56D67AB1080EA2E538440996AA7A532E08DB3EB031A",
    "passed": [
      "Three distinct wallets persisted",
      "Bootstrap supply and founder vesting",
      "Founder handoff complete",
      "Transfer exact balances and conserved supply",
      "Stored signature verifies",
      "Persisted state root reproducible",
      "Revenue persisted with exact remainder conservation",
      "Post-handoff contribution with no founder increment",
      "State loads in a fresh PowerShell process"
    ],
    "selftestPassed": 14,
    "observedAt": "2026-10-02T23:38:04.3856545Z"
  },
  "v03": {
    "threeNodes": true,
    "distinctKeys": true,
    "threeSignatures": true,
    "twoSignatures": true,
    "hashLinked": true,
    "observedAt": "2026-10-02T23:38:21.8182984Z"
  },
  "scope": "Local functional integration; separate corrected packages",
  "testNodesStopped": true
}
ATH_TEMPLATE_10
cp -- "${BASH_SOURCE[0]}" "$out/BUILD_ATH_WEBSITE.sh"
printf "ATH-Webseitentexte gebaut: %s\nPowerPoint bei Bedarf separat daneben speichern.\n" "$out"
