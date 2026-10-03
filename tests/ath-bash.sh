#!/usr/bin/env bash
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_script=${1:-"$here/ath/ATH_BASH_EXPERIMENT.sh"}
test_dir=$(mktemp -d)
export ATH_ROOT="$test_dir/ledger"
bash -n "$source_script"
bash "$source_script" init
bash "$source_script" transfer 3
bash "$source_script" verify
status=$(bash "$source_script" status)
[[ $status == *'ANNA: 7.0000 ATH'* && $status == *'BEN:  3.0000 ATH'* && $status == *'TOTAL: 10.0000 ATH'* ]]
bash "$source_script" transfer 3
bash "$source_script" transfer 3
if bash "$source_script" transfer 3 > "$test_dir/rejected.txt" 2>&1; then echo 'FAIL: insufficient balance accepted'; exit 1; fi
bash "$source_script" verify
status=$(bash "$source_script" status)
[[ $status == *'ANNA: 1.0000 ATH'* && $status == *'BEN:  9.0000 ATH'* ]]
printf 'ATH BASH PASS: signed transfer, fresh-process replay, conserved supply, insufficient-balance rejection.\n'
export ATH_ROOT="$test_dir/decimal-ledger"
bash "$source_script" init
bash "$source_script" transfer 1
bash "$source_script" transfer 2
bash "$source_script" transfer 0.0001
bash "$source_script" transfer 0,25
status=$(bash "$source_script" status)
[[ $status == *'ANNA: 6.7499 ATH'* && $status == *'BEN:  3.2501 ATH'* ]]
before=$(sha256sum "$ATH_ROOT/ledger.tsv")
for invalid in 0 -1 1.00001 01 1e2 abc ''; do
 if bash "$source_script" transfer "$invalid" >/dev/null 2>&1; then echo "FAIL invalid amount: $invalid"; exit 1; fi
done
[[ $(sha256sum "$ATH_ROOT/ledger.tsv") == "$before" ]]
printf 'DECIMAL ATH PASS: 1, 2, smallest subunit, comma, invalid inputs rejected without ledger changes.\n'

bash "$source_script" transfer BEN ANNA 1
status=$(bash "$source_script" status)
[[ $status == *'ANNA: 7.7499 ATH'* && $status == *'BEN:  2.2501 ATH'* ]]
bash "$source_script" transfer ANNA BEN 0.5
bash "$source_script" verify
status=$(bash "$source_script" status)
[[ $status == *'ANNA: 7.2499 ATH'* && $status == *'BEN:  2.7501 ATH'* ]]
before=$(sha256sum "$ATH_ROOT/ledger.tsv")
for args in 'BEN BEN 1' 'OTHER ANNA 1' 'BEN ANNA 9' 'BEN ANNA' 'ANNA BEN 1 extra'; do
 if bash "$source_script" transfer $args >/dev/null 2>&1; then echo "FAIL invalid participants or balance: $args"; exit 1; fi
done
[[ $(sha256sum "$ATH_ROOT/ledger.tsv") == "$before" ]]
printf 'BIDIRECTIONAL ATH PASS: both senders sign, balances conserved, invalid requests unchanged.\n'
