#!/bin/sh
# Builds aMule 3.0.0 for AmigaOS 3 (68040, FPU used when there is one) with a
# stove: the GFOpenWX Toolkit SDK first, then Crypto++ and Boost's headers
# (scripts/build-deps.sh), then aMule (scripts/build-amule.sh) for what is
# left of BUDGET_TOTAL seconds; the build tree is kept, so the next run goes on.
#   STOVE=.../stoves/os32-gcc16-open6 OUT=out ./build-amiga.sh
#   (WXT_SRC=... to use a toolkit tree already on disk)
# aMule and the libraries are fetched at the versions amule.lock gives;
# nothing third-party is kept here. OUT gets amule when it links.
# Copyright (c) 2026 AmiCradle Team
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$HERE/amule.lock"
STOVE=${STOVE:-"$HOME/AmiCradle/stoves/os32-gcc16-open6"}
# the build tree lives outside the checkout: Cradle cleans the checkout
# (git clean) before each job, and a build longer than one job goes on
WORK="${WORK:-$HOME/.cache/gfamigaamule/build}"; OUT="${OUT:-$WORK/out}"; JOBS=${JOBS:-12}
TC="$STOVE/prefix"
command -v cmake >/dev/null || { echo "no cmake on this stove"; exit 1; }
mkdir -p "$WORK/deps" "$OUT"
t0=$(date +%s)

fetch() {
    d="$WORK/deps/$1"
    if [ "$(git -C "$d" rev-parse HEAD 2>/dev/null)" != "$3" ]; then
        rm -rf "${d:?}"; mkdir -p "$d"
        git -C "$d" init -q
        git -C "$d" fetch -q --depth 1 "$2" "$3"
        git -C "$d" checkout -q FETCH_HEAD
    fi
}
# a ready SDK from the lock, when it is on this host and its checksum holds
WX_SDK=""
if [ -z "${WXT_SRC:-}" ] && [ -n "${WXT_SDK_TAR:-}" ] && [ -f "$WXT_SDK_TAR" ]; then
    D="$WORK/wxsdk-$(echo "$WXT_SDK_SHA256" | cut -c1-16)"
    if [ ! -x "$D/.ok" ]; then
        echo "$WXT_SDK_SHA256  $WXT_SDK_TAR" | sha256sum -c - >/dev/null || { echo "SDK checksum differs"; exit 1; }
        rm -rf "$D"; mkdir -p "$D"; tar xzf "$WXT_SDK_TAR" -C "$D"
        touch "$D/.ok"; chmod +x "$D/.ok"
    fi
    WX_SDK=$(dirname "$(dirname "$(find "$D" -path '*/bin/wx-config' | head -1)")")
    echo "toolkit: SDK $WX_SDK"
fi
if [ -z "$WX_SDK" ] && [ -z "${WXT_SRC:-}" ]; then
    [ -n "$WXT_COMMIT" ] || { echo "WXT_SRC: a GFOpenWX Toolkit tree with wxNet (no commit pinned yet)"; exit 1; }
    fetch gfopenwxtoolkit "$WXT_REPO" "$WXT_COMMIT"; WXT_SRC="$WORK/deps/gfopenwxtoolkit"
fi

# the toolkit again only when its tree changed since its SDK was made
WXB="$WORK/gfopenwx"
if [ -z "$WX_SDK" ]; then
WXREV=$( (git -C "$WXT_SRC" rev-parse HEAD 2>/dev/null; git -C "$WXT_SRC" diff HEAD 2>/dev/null) | sha256sum | cut -c1-16)
if [ ! -x "$WXB/out/sdk/bin/wx-config" ] || [ "$(cat "$WXB/out/.rev" 2>/dev/null)" != "$WXREV" ]; then
    STOVE="$STOVE" WORK="$WXB" OUT="$WXB/out" JOBS=$JOBS sh "$WXT_SRC/build-amiga.sh" > "$WORK.wx.log" 2>&1 || { tail -30 "$WORK.wx.log"; exit 1; }
    echo "$WXREV" > "$WXB/out/.rev"
    echo "toolkit: $(( $(date +%s) - t0 )) s"
fi
[ -x "$WXB/out/sdk/bin/wx-config" ] || { tail -30 "$WORK.wx.log"; echo "no toolkit SDK"; exit 1; }
WX_SDK="$WXB/out/sdk"
fi

TOOLCHAIN="$TC" WORK="$WORK" JOBS=$JOBS sh "$HERE/scripts/build-deps.sh" > "$WORK.deps.log" 2>&1 || { tail -40 "$WORK.deps.log"; exit 1; }
echo "libraries: $(( $(date +%s) - t0 )) s"
# lab check: libnix malloc and stdio with threads (tests/threadprobe.c)
mkdir -p "$OUT"
"$TC/bin/m68k-amigaos-gcc" -noixemul -m68040 -O2 -specs="$HERE/scripts/m68k-soft-m68040.specs" \
    -o "$OUT/threadprobe" "$HERE/tests/threadprobe.c" -lpthread || echo "threadprobe: not built"
"$TC/bin/m68k-amigaos-gcc" -noixemul -m68040 -O2 -specs="$HERE/scripts/m68k-soft-m68040.specs" \
    -o "$OUT/joinprobe" "$HERE/tests/joinprobe.c" -lpthread || echo "joinprobe: not built"
"$TC/bin/m68k-amigaos-gcc" -noixemul -m68040 -O2 -specs="$HERE/scripts/m68k-soft-m68040.specs" \
    -o "$OUT/selfprobe" "$HERE/tests/selfprobe.c" -lpthread || echo "selfprobe: not built"
"$TC/bin/m68k-amigaos-gcc" -noixemul -m68040 -O2 -specs="$HERE/scripts/m68k-soft-m68040.specs" \
    -Wl,--wrap=open,--wrap=close,--wrap=socket,--wrap=accept -L"$WORK/sysroot/lib" \
    -o "$OUT/fdprobe" "$HERE/tests/fdprobe.c" -lamigacompat -lsocket -lpthread || echo "fdprobe-locked: not built"
# fpuauto (FPU when there is one, in the stove's own specs): does this link get it?
printf 'double f(double a,double b){return a*b+1.0;}\nint main(int c,char**v){return (int)f(c,2.5);}\n' > "$WORK/fpucheck.c"
if "$TC/bin/m68k-amigaos-gcc" -noixemul -m68040 -O2 -specs="$HERE/scripts/m68k-soft-m68040.specs" \
        -Wl,-Map="$WORK/fpucheck.map" -o "$WORK/fpucheck" "$WORK/fpucheck.c" 2>/dev/null; then
    echo "fpuauto: $(grep -c -i fpuauto "$WORK/fpucheck.map") map lines"
fi
left=$(( ${BUDGET_TOTAL:-840} - ($(date +%s) - t0) ))
[ "$left" -gt 60 ] || { echo "no time left for aMule this run"; exit 0; }
TOOLCHAIN="$TC" WORK="$WORK" OUT="$OUT" JOBS=$JOBS WX_SDK="$WX_SDK" BUDGET=$left \
    sh "$HERE/scripts/build-amule.sh"
echo "total: $(( $(date +%s) - t0 )) s"
