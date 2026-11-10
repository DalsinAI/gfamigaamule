#!/bin/sh
# Crypto++ (static, no assembly) and the GFOpenBoost SDK into the sysroot
# aMule builds against, at the versions amule.lock gives.
#   TOOLCHAIN=.../prefix WORK=build scripts/build-deps.sh
# Copyright (c) 2026 AmiCradle Team
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$HERE/amule.lock"
WORK=${WORK:-$HERE/build}; JOBS=${JOBS:-12}
SYS="$WORK/sysroot"; mkdir -p "$SYS/include" "$SYS/lib" "$WORK/deps"
PATH="$TOOLCHAIN/bin:$PATH"; export PATH
SPECS="$HERE/scripts/m68k-soft-m68040.specs"
FLAGS="-noixemul -m68040 -O2"

# zlib's API on the system's z.library (deps/zlib): no zlib of our own
ZS=$(cat "$HERE"/deps/zlib/* | sha256sum | cut -c1-16)
if [ "$(cat "$SYS/lib/.zlib" 2>/dev/null)" != "$ZS" ]; then
    m68k-amigaos-gcc $FLAGS -Wall -c "$HERE/deps/zlib/zlib_zlibrary.c" -o "$WORK/zlib_zlibrary.o"
    rm -f "$SYS/lib/libz.a"; m68k-amigaos-ar rcs "$SYS/lib/libz.a" "$WORK/zlib_zlibrary.o"
    cp "$HERE/deps/zlib/zlib.h" "$SYS/include/zlib.h"
    echo "$ZS" > "$SYS/lib/.zlib"
fi

# POSIX ioctl()/fcntl() for sockets come from the stove's libsocket (GFOpenAmigaGCC
# patches/libnix/0010, in the os32-gcc16-open6 stove since 10 Nov 2026). An older
# libsocket takes ixemul's five-argument ioctl(), which breaks Boost.Asio's
# non-blocking sockets, so stop here rather than link against it.
m68k-amigaos-nm "$TOOLCHAIN/m68k-amigaos/libnix/lib/libsocket.a" 2>/dev/null | grep -q ' T _fcntl$' \
    || { echo "the stove's libsocket has no POSIX ioctl()/fcntl() (GFOpenAmigaGCC libnix patch 0010): refresh the stove"; exit 1; }

# compat calls libnix lacks (deps/compat): poll() on select(), and a few more
CS=$( (cat "$HERE"/deps/compat/* "$HERE"/cmake/amiga-include/sys/poll.h "$HERE"/cmake/amiga-include/amigaamule_posix.h; echo "$TOOLCHAIN") | sha256sum | cut -c1-16)
if [ "$(cat "$SYS/lib/.compat" 2>/dev/null)" != "$CS" ]; then
    rm -f "$SYS/lib/libamigacompat.a"
    for c in "$HERE"/deps/compat/*.c; do
        m68k-amigaos-gcc $FLAGS -Wall -c "$c" -o "$WORK/compat-$(basename "$c" .c).o"
        m68k-amigaos-ar rcs "$SYS/lib/libamigacompat.a" "$WORK/compat-$(basename "$c" .c).o"
    done
    echo "$CS" > "$SYS/lib/.compat"
fi

# Boost: the shared GFOpenBoost SDK, as it comes
if [ "$(cat "$SYS/include/.gfopenboost" 2>/dev/null)" != "$GFOPENBOOST_SHA256" ]; then
    T="$WORK/deps/gfopenboost-$GFOPENBOOST_VERSION-$(echo "$GFOPENBOOST_SHA256" | cut -c1-16)-sdk.tar.xz"
    [ -f "$T" ] || curl -sSfL -o "$T" "$GFOPENBOOST_URL"
    echo "$GFOPENBOOST_SHA256  $T" | sha256sum -c - >/dev/null
    G="$WORK/deps/gfopenboost-$GFOPENBOOST_VERSION"
    rm -rf "$G" "$SYS/include/boost" "$SYS/include/.boost-edits" "$SYS"/lib/cmake/Boost-* "$SYS"/lib/libboost_*.a
    tar xJf "$T" -C "$WORK/deps"
    cp -a "$G/include/boost" "$SYS/include/boost"
    cp "$G"/lib/libboost_*.a "$SYS/lib/"
    mkdir -p "$SYS/lib/cmake"; cp -a "$G/lib/cmake/Boost-$GFOPENBOOST_VERSION" "$SYS/lib/cmake/"
    echo "$GFOPENBOOST_SHA256" > "$SYS/include/.gfopenboost"
fi

# Crypto++: its own GNUmakefile, static, portable C++ only
C="$WORK/deps/cryptopp"
if [ "$(git -C "$C" rev-parse HEAD 2>/dev/null)" != "$CRYPTOPP_COMMIT" ]; then
    rm -rf "$C"; mkdir -p "$C"
    git -C "$C" init -q; git -C "$C" fetch -q --depth 1 "$CRYPTOPP_GIT" "$CRYPTOPP_COMMIT"; git -C "$C" checkout -q FETCH_HEAD
    rm -f "$SYS/lib/libcryptopp.a"
fi
# m68k-amigaos objects (a.out) align to 8 bytes at most: Crypto++'s 16-byte
# table alignment (only its SIMD code needs it) becomes 8
if ! grep -q '__AMIGA__' "$C/config_align.h"; then
    sed -i 's/^#if defined(CRYPTOPP_CXX11_ALIGNAS)/#if defined(__AMIGA__)\n\t#define CRYPTOPP_ALIGN_DATA(x) __attribute__((aligned((x) > 8 ? 8 : (x))))\n#elif defined(CRYPTOPP_CXX11_ALIGNAS)/' "$C/config_align.h"
    grep -q '__AMIGA__' "$C/config_align.h" || { echo "config_align.h: edit not applied"; exit 1; }
fi
# AmigaOS has no /dev/urandom: Crypto++'s generator takes arc4random_buf()
# from deps/compat/random.c, as on FreeBSD
if ! grep -q 'arc4random_buf' "$C/config_os.h" || [ ! -f "$C/.amiga-rng" ]; then
    grep -q 'arc4random_buf' "$C/config_os.h" && sed -i '/^#if defined(__AMIGA__) \&\& !defined(OS_RNG_AVAILABLE)/,$d' "$C/config_os.h"
    touch "$C/.amiga-rng"
    cat >> "$C/config_os.h" <<'RNG'

#if defined(__AMIGA__) && !defined(OS_RNG_AVAILABLE)
#	define NONBLOCKING_RNG_AVAILABLE
#	define OS_RNG_AVAILABLE
#	define USE_FREEBSD_ARC4RANDOM
#	include <errno.h>
#	include <stddef.h>
extern "C" void arc4random_buf(void *buf, size_t n);
#endif
RNG
    # its makefile has no header dependencies: build every object again
    rm -f "$SYS/lib/libcryptopp.a" "$C"/*.o
fi
if [ ! -f "$SYS/lib/libcryptopp.a" ]; then
    (cd "$C" && nice -n 19 make -j"$JOBS" -f GNUmakefile-cross static \
        CXX=m68k-amigaos-g++ AR=m68k-amigaos-ar RANLIB=m68k-amigaos-ranlib \
        CXXFLAGS="$FLAGS -std=gnu++17 -DNDEBUG -DCRYPTOPP_DISABLE_ASM -DCRYPTOPP_NO_CPU_FEATURE_PROBES" \
        > "$WORK/cryptopp.log" 2>&1) || { grep -E 'error' "$WORK/cryptopp.log" | head -30; exit 1; }
    mkdir -p "$SYS/include/cryptopp"
    cp "$C"/*.h "$SYS/include/cryptopp/"
    cp "$C/libcryptopp.a" "$SYS/lib/"
fi
ls -l "$SYS/lib"
