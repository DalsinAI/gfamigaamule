#!/bin/sh
# Unit test: build-amiga.sh stops the toolkit's SDK build at BUDGET_TOTAL and
# says "run again", instead of running into the kitchen's 2700 s cap with
# nothing in its log. A stand-in toolkit tree that only sleeps; no stove.
#   sh tests/test_toolkit_budget.sh
# Copyright (c) 2026 AmiCradle Team
set -u
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "ok: $1"; }
no() { fail=$((fail + 1)); echo "FAIL: $1"; }
mkdir -p "$T/bin" "$T/wxt" "$T/stove/prefix"
printf '#!/bin/sh\nexit 0\n' > "$T/bin/cmake"; chmod +x "$T/bin/cmake"
printf '#!/bin/sh\necho toolkit started\nsleep 30\n' > "$T/wxt/build-amiga.sh"
git -C "$T/wxt" init -q
s=$(date +%s)
PATH="$T/bin:$PATH" AMIGACHROME_GIT_MIRROR=file:///nonexistent/ STOVE="$T/stove" \
    WORK="$T/work" OUT="$T/out" WXT_SRC="$T/wxt" BUDGET_TOTAL=2 \
    sh "$HERE/build-amiga.sh" > "$T/log" 2>&1
rc=$?; took=$(( $(date +%s) - s ))
[ "$rc" = 0 ] && ok "exits 0 when out of time" || no "exits 0 when out of time (rc $rc)"
[ "$took" -lt 20 ] && ok "stopped at the budget ($took s)" || no "stopped at the budget ($took s)"
grep -q 'toolkit: out of time after .* run again to go on' "$T/log" && ok "says run again" || no "says run again"
grep -q 'toolkit started' "$T/log" && ok "shows the toolkit log tail" || no "shows the toolkit log tail"
[ ! -f "$T/work/gfopenwx/out/.rev" ] && ok "no .rev written for an unfinished SDK" || no "no .rev written for an unfinished SDK"
# a toolkit build that fails still fails the run
printf '#!/bin/sh\necho broken\nexit 3\n' > "$T/wxt/build-amiga.sh"
PATH="$T/bin:$PATH" AMIGACHROME_GIT_MIRROR=file:///nonexistent/ STOVE="$T/stove" \
    WORK="$T/work" OUT="$T/out" WXT_SRC="$T/wxt" BUDGET_TOTAL=20 \
    sh "$HERE/build-amiga.sh" > "$T/log" 2>&1
rc=$?
[ "$rc" = 1 ] && grep -q broken "$T/log" && ok "a failing toolkit fails the run" || no "a failing toolkit fails the run (rc $rc)"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
