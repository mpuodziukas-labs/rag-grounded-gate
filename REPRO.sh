#!/usr/bin/env bash
# Reproduce every result in FIXTURE-TABLE.md. Offline, no network. Run from the repo root.
set -euo pipefail

GATE=./rag-grounded-gate

# 1. Self-contained selftest (builds its own fixtures in a tempdir). The count is asserted,
#    not just the exit code, so a silently shrunken selftest cannot pass.
selftest_out=$("$GATE" --selftest)
printf '%s\n' "$selftest_out"
case "$selftest_out" in
  *"32/32 PASS 0 FAIL"*) ;;
  *) echo "SELFTEST COUNT MISMATCH (expected 32/32 PASS 0 FAIL)" >&2; exit 1 ;;
esac

# 2. The nine demo fixtures - each engineered to force one recorded exit code.
fail=0
check() { # <fixture-name> <expected-rc> [extra gate args...]
  local name="$1" exp="$2"; shift 2
  set +e
  "$GATE" check "fixtures/$name/answer.json" "fixtures/$name/chunks" "$@" >/dev/null 2>&1
  local rc=$?
  set -e
  if [ "$rc" -ne "$exp" ]; then
    echo "FAIL $name: expected rc=$exp got rc=$rc" >&2
    fail=1
  else
    echo "ok   $name rc=$rc"
  fi
}

check 01-valid                     0
check 02-empty-retrieval-abstain   0
check 03-empty-retrieval-answered  1
check 04-span-mismatch             1
check 05-sha-unpinned              1
check 06-source-floor-one-source   1
check 07-stale-chunk-no-flag       1
check 08-attribution-ratio-low     1
check 09-schema-missing-field      2

if [ "$fail" -eq 0 ]; then
  echo "REPRO OK"
else
  echo "REPRO FAILED" >&2
  exit 1
fi
