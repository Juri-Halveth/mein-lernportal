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
   [[ $kind == TRANSFER && $sender == ANNA && $receiver == BEN && $sig =~ ^[A-Za-z0-9+/=]+$ ]] || die 'Ungültige Beispielübertragung'
   ((amount>0 && amount<=anna)) || die 'Unzureichendes Guthaben'
   local signed="$n|$prev|$kind|$sender|$receiver|$amount"
   printf '%s' "$sig" | openssl base64 -d -A > "$root/signature.tmp"
   if ! printf '%s' "$signed" | openssl dgst -sha256 -verify "$root/keys/ANNA.public.pem" -signature "$root/signature.tmp" >/dev/null 2>&1; then die 'Signaturprüfung fehlgeschlagen'; fi
   anna=$((anna-amount)); ben=$((ben+amount))
  fi
  last=$digest; expected=$((expected+1))
 done < "$root/ledger.tsv"
 ((expected>=1 && anna+ben==100000)) || die 'Beispielmenge stimmt nicht'
}
transfer(){
 local amount=${1:-30000}; [[ $amount =~ ^[1-9][0-9]{0,8}$ ]] || die 'Betrag in positiven ganzzahligen Untereinheiten angeben'
 replay; ((amount<=anna)) || die 'Unzureichendes Guthaben'
 local signed="$expected|$last|TRANSFER|ANNA|BEN|$amount"
 local sig; sig=$(printf '%s' "$signed" | openssl dgst -sha256 -sign "$root/keys/ANNA.private.pem" | openssl base64 -A)
 local payload="$signed|$sig"
 printf '%s|%s\n' "$payload" "$(printf '%s' "$payload" | hash)" >> "$root/ledger.tsv"
 replay; printf 'TRANSFER: '; quantity "$amount"; printf ' ANNA -> BEN; Signatur und Menge geprüft.\n'
}
status(){ replay; printf 'ANNA: '; quantity "$anna"; printf '\nBEN:  '; quantity "$ben"; printf '\nTOTAL: '; quantity "$((anna+ben))"; printf '\nRECORDS: %d\nCHAIN HEAD: %s\n' "$expected" "$last"; }
case "$command" in
 init) init;;
 transfer) transfer "${2:-30000}";;
 verify) replay; printf 'PASS: Hashverkettung, Signaturen, Reihenfolge und Beispielmenge.\n';;
 status) status;;
 demo)
  if [[ -z ${ATH_ROOT:-} ]]; then root=$(mktemp -d "${TMPDIR:-/tmp}/ath-bash.XXXXXXXX")/ledger; fi
  init; transfer 30000; status
  printf 'DEMO PASS. Datenverzeichnis: %s\n' "$root"
  printf 'Scope: ein Prozess, zwei lokale Schlüssel, feste Beispielmenge; keine Gleichwertigkeit mit V0.5.\n';;
 help|--help|-h)
  printf 'ATH Bash Experiment\n  bash ATH_BASH_EXPERIMENT.sh demo\n  ATH_ROOT="./mein-neues-ledger" bash ATH_BASH_EXPERIMENT.sh init\n  ATH_ROOT="./mein-neues-ledger" bash ATH_BASH_EXPERIMENT.sh transfer 30000\n  ATH_ROOT="./mein-neues-ledger" bash ATH_BASH_EXPERIMENT.sh status\n  ATH_ROOT="./mein-neues-ledger" bash ATH_BASH_EXPERIMENT.sh verify\n\n30000 Untereinheiten = 3.0000 ATH. Ben kann in diesem ersten Experiment nur empfangen.\nKein Netzwerk, Mint-/Vesting-Modell, paralleler Writer oder Crash-Recovery.\n';;
 *) die 'Unbekannter Befehl. Nutze help.';;
esac