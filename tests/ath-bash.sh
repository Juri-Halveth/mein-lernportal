#!/usr/bin/env bash
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_script=${1:-"$here/ath/ATH_BASH_EXPERIMENT.sh"}
test_dir=$(mktemp -d)
export ATH_ROOT="$test_dir/ledger"
bash -n "$source_script"
bash "$source_script" init
bash "$source_script" transfer 30000
bash "$source_script" verify
status=$(bash "$source_script" status)
[[ $status == *'ANNA: 7.0000 ATH'* && $status == *'BEN:  3.0000 ATH'* && $status == *'TOTAL: 10.0000 ATH'* ]]
bash "$source_script" transfer 30000
bash "$source_script" transfer 30000
if bash "$source_script" transfer 30000 > "$test_dir/rejected.txt" 2>&1; then echo 'FAIL: insufficient balance accepted'; exit 1; fi
bash "$source_script" verify
status=$(bash "$source_script" status)
[[ $status == *'ANNA: 1.0000 ATH'* && $status == *'BEN:  9.0000 ATH'* ]]
printf 'ATH BASH PASS: signed transfer, fresh-process replay, conserved supply, insufficient-balance rejection.\n'