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
    if [ "$(git -C "$SRC" rev-parse HEAD 2>/dev/null)" = "$AMULE_COMMIT" ]; then
        # same commit, other patches: back to the commit and patch again;
        # the build tree stays, so make rebuilds only the patched files
        rm -f "$SRC/.patched"
        git -C "$SRC" checkout -q -f "$AMULE_COMMIT"
        git -C "$SRC" clean -q -fdx
    else
        rm -rf "$SRC" "$B"; mkdir -p "$SRC"
        git -C "$SRC" init -q
        git -C "$SRC" fetch -q --depth 1 "$AMULE_GIT" "$AMULE_COMMIT"
        git -C "$SRC" checkout -q FETCH_HEAD
    fi
    [ "$(git -C "$SRC" rev-parse HEAD)" = "$AMULE_COMMIT" ] || { echo "commit mismatch"; exit 1; }
    for p in "$HERE"/patches/*.patch; do
        [ -f "$p" ] || continue
        patch -s -d "$SRC" -p1 < "$p" || { echo "patch failed: $p"; exit 1; }
    done
    echo "$AMULE_COMMIT-$PSUM" > "$SRC/.patched"
fi

# Boost.Asio through libnix's headers: every error at once, before CMake's
# probe (which shows only the first)
printf '#include <boost/asio.hpp>\nint main(){boost::asio::io_context c; boost::asio::ip::tcp::socket s(c); c.poll(); return 0;}\n' > "$WORK/asioprobe.cpp"
if ! "$TOOLCHAIN/bin/m68k-amigaos-g++" -noixemul -m68040 -std=gnu++17 -I"$HERE/cmake/amiga-include" -include amigaamule_posix.h \
        -DBOOST_ASIO_DISABLE_THREADS -DBOOST_ASIO_DISABLE_SERIAL_PORT -DBOOST_ASIO_SEPARATE_COMPILATION -I"$SYS/include" \
        -fsyntax-only -fmax-errors=60 "$WORK/asioprobe.cpp" > "$WORK/asioprobe.log" 2>&1; then
    echo "asio probe failed:"; grep -E 'error' "$WORK/asioprobe.log" | sort -u | head -60
    # what libnix's headers and socket library have
    I=$(echo | "$TOOLCHAIN/bin/m68k-amigaos-g++" -noixemul -xc++ -E -v - 2>&1 | sed -n '/^ \//p' | tr -d ' ' | tr '\n' ' ')
    for w in sockaddr_storage sockaddr_in6 in6_addr ipv6_mreq addrinfo getaddrinfo iovec recvmsg msghdr inet_ntop fcntl FIONBIO EAI_NONAME; do
        echo "$w: $(grep -rlw "$w" $I 2>/dev/null | grep -v c++ | head -3 | tr '\n' ' ')"
    done
    N=$(find "$TOOLCHAIN" -path '*ndk-include/netdb.h' | head -1)
    [ -n "$N" ] && grep -n -B4 -A2 'getaddrinfo\|^#if\|^#endif' "$N" | head -60
    for l in $(find "$TOOLCHAIN" -name libsocket.a | head -1); do
        echo "libsocket: $("$TOOLCHAIN/bin/m68k-amigaos-nm" "$l" 2>/dev/null | grep ' T ' | awk '{print $3}' | tr '\n' ' ' | cut -c1-4000)"
    done
    exit 1
fi
echo "asio probe: ok"

# CMake's function checks only compile (no link) here, so every one
# passes: the calls libnix lacks are named absent on the command line
OPTS="-DBUILD_MONOLITHIC=ON -DBUILD_DAEMON=OFF -DBUILD_REMOTEGUI=OFF -DBUILD_AMULECMD=OFF -DBUILD_WEBSERVER=OFF \
 -DBUILD_ED2K=OFF -DBUILD_ALC=OFF -DBUILD_ALCC=OFF -DBUILD_CAS=OFF -DBUILD_WXCAS=OFF -DBUILD_FILEVIEW=OFF \
 -DBUILD_TESTING=OFF -DENABLE_UPNP=OFF -DENABLE_IP2COUNTRY=OFF -DENABLE_NLS=OFF -DENABLE_MMAP=OFF"
CSUM=$( (cat "$0" "$HERE/cmake/toolchain-m68k-amigaos.cmake" "$HERE"/cmake/Platform/*.cmake; echo "$OPTS $WX_SDK $TOOLCHAIN") | sha256sum | cut -c1-16)
if [ "$(cat "$B/.configured" 2>/dev/null)" != "$CSUM" ]; then
    # configured again in place: make rebuilds what the new flags change
    rm -f "$B/CMakeCache.txt"; mkdir -p "$B"
    # shellcheck disable=SC2086
    (cd "$B" && cmake "$SRC" -G "Unix Makefiles" \
        -DCMAKE_TOOLCHAIN_FILE="$HERE/cmake/toolchain-m68k-amigaos.cmake" \
        -DAMIGA_TOOLCHAIN="$TOOLCHAIN" -DAMIGA_SYSROOT="$SYS" -DAMIGA_SPECS="$HERE/scripts/m68k-soft-m68040.specs" \
        -DCMAKE_PREFIX_PATH="$SYS" -DCMAKE_BUILD_TYPE=Release \
        -DwxWidgets_CONFIG_EXECUTABLE="$WX_SDK/bin/wx-config" \
        -DLIBATOMIC_LIBRARY=atomic -DHAVE_FALLOCATE=0 -DHAVE_POSIX_FALLOCATE=0 -DHAVE_GETRLIMIT=0 -DHAVE_SETRLIMIT=0 -DCRYPTOPP_INCLUDE_PREFIX=cryptopp -DCRYPTOPP_VERSION=8.9.0 -DCRYPTOPP_INCLUDE_DIR="$SYS/include" -DCRYPTOPP_LIBRARY="$SYS/lib/libcryptopp.a" \
        -DCMAKE_THREAD_LIBS_INIT=-lpthread -DCMAKE_HAVE_PTHREAD_CREATE=1 -DCMAKE_USE_PTHREADS_INIT=1 -DThreads_FOUND=TRUE \
        $OPTS > cmake.log 2>&1) || { grep -B2 -A12 'CMake Error' "$B/cmake.log" | head -40;
        # why a compile probe failed: the compiler's own errors
        cat "$B"/CMakeFiles/CMakeConfigureLog.yaml "$B"/CMakeFiles/CMakeError.log 2>/dev/null | grep -E 'error:|#error' | sort -u | head -40; exit 1; }
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
