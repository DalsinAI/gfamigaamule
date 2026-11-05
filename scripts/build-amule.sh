#!/bin/sh
# Fetches aMule at its pinned commit, applies patches/, and configures and
# builds the monolithic aMule against the sysroot from build-deps.sh and the
# toolkit's SDK. The build tree is kept, so a build that runs out of time goes
# on from where it stopped next time (BUDGET seconds of make per run).
#   TOOLCHAIN=.../prefix WX_SDK=... WORK=build OUT=out scripts/build-amule.sh
# Copyright (c) 2026 AmiCradle Team
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$HERE/amule.lock"
WORK=${WORK:-$HERE/build}; OUT=${OUT:-$WORK/out}; JOBS=${JOBS:-12}; BUDGET=${BUDGET:-700}
SYS="$WORK/sysroot"; SRC="$WORK/amule"; B="$WORK/abuild"
mkdir -p "$OUT"

PSUM=$(cat "$HERE"/patches/*.patch 2>/dev/null | sha256sum | cut -c1-16)
if [ "$(cat "$SRC/.patched" 2>/dev/null)" != "$AMULE_COMMIT-$PSUM" ]; then
    rm -rf "$SRC"; mkdir -p "$SRC"
    git -C "$SRC" init -q
    git -C "$SRC" fetch -q --depth 1 "$AMULE_GIT" "$AMULE_COMMIT"
    git -C "$SRC" checkout -q FETCH_HEAD
    [ "$(git -C "$SRC" rev-parse HEAD)" = "$AMULE_COMMIT" ] || { echo "commit mismatch"; exit 1; }
    for p in "$HERE"/patches/*.patch; do
        [ -f "$p" ] || continue
        patch -s -d "$SRC" -p1 < "$p" || { echo "patch failed: $p"; exit 1; }
    done
    echo "$AMULE_COMMIT-$PSUM" > "$SRC/.patched"
    rm -rf "$B"
fi

OPTS="-DBUILD_MONOLITHIC=ON -DBUILD_DAEMON=OFF -DBUILD_REMOTEGUI=OFF -DBUILD_AMULECMD=OFF -DBUILD_WEBSERVER=OFF \
 -DBUILD_ED2K=OFF -DBUILD_ALC=OFF -DBUILD_ALCC=OFF -DBUILD_CAS=OFF -DBUILD_WXCAS=OFF -DBUILD_FILEVIEW=OFF \
 -DBUILD_TESTING=OFF -DENABLE_UPNP=OFF -DENABLE_IP2COUNTRY=OFF -DENABLE_NLS=OFF -DENABLE_MMAP=OFF"
CSUM=$( (cat "$0" "$HERE/cmake/toolchain-m68k-amigaos.cmake" "$HERE"/cmake/Platform/*.cmake; echo "$OPTS") | sha256sum | cut -c1-16)
if [ "$(cat "$B/.configured" 2>/dev/null)" != "$CSUM" ]; then
    rm -rf "$B"; mkdir -p "$B"
    # shellcheck disable=SC2086
    (cd "$B" && cmake "$SRC" -G "Unix Makefiles" \
        -DCMAKE_TOOLCHAIN_FILE="$HERE/cmake/toolchain-m68k-amigaos.cmake" \
        -DAMIGA_TOOLCHAIN="$TOOLCHAIN" -DAMIGA_SYSROOT="$SYS" -DAMIGA_SPECS="$HERE/scripts/m68k-soft-m68040.specs" \
        -DCMAKE_PREFIX_PATH="$SYS" -DCMAKE_BUILD_TYPE=Release \
        -DwxWidgets_CONFIG_EXECUTABLE="$WX_SDK/bin/wx-config" \
        -DCRYPTOPP_INCLUDE_PREFIX=cryptopp -DCRYPTOPP_LIBRARY="$SYS/lib/libcryptopp.a" \
        -DCMAKE_THREAD_LIBS_INIT=-lpthread -DCMAKE_HAVE_PTHREAD_CREATE=1 -DCMAKE_USE_PTHREADS_INIT=1 -DThreads_FOUND=TRUE \
        $OPTS > cmake.log 2>&1) || { grep -B2 -A12 'CMake Error' "$B/cmake.log" | head -80; tail -20 "$B/cmake.log"; exit 1; }
    echo "$CSUM" > "$B/.configured"
fi

set +e
(cd "$B" && timeout "$BUDGET" nice -n 19 make -k -j"$JOBS" > make.log 2>&1)
rc=$?
set -e
echo "make rc=$rc"
grep -E 'error:|Error [0-9]|undefined reference' "$B/make.log" | sort -u | head -60
tail -5 "$B/make.log"
A=$(find "$B" -type f -name amule -perm -u+x | head -1)
if [ -n "$A" ]; then
    "$TOOLCHAIN/bin/m68k-amigaos-strip" -o "$OUT/amule" "$A" || cp "$A" "$OUT/amule"
    ls -l "$OUT/amule"
fi
