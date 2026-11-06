#!/bin/sh
# Crypto++ (static, no assembly) and Boost's headers into the sysroot
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

# compat calls libnix lacks (deps/compat): poll() on select()
CS=$(cat "$HERE"/deps/compat/* "$HERE"/cmake/amiga-include/sys/poll.h "$HERE"/cmake/amiga-include/amigaamule_posix.h | sha256sum | cut -c1-16)
if [ "$(cat "$SYS/lib/.compat" 2>/dev/null)" != "$CS" ]; then
    rm -f "$SYS/lib/libamigacompat.a"
    for c in "$HERE"/deps/compat/*.c; do
        m68k-amigaos-gcc $FLAGS -Wall -c "$c" -o "$WORK/compat-$(basename "$c" .c).o"
        m68k-amigaos-ar rcs "$SYS/lib/libamigacompat.a" "$WORK/compat-$(basename "$c" .c).o"
    done
    echo "$CS" > "$SYS/lib/.compat"
fi

# Boost: headers only
if [ ! -f "$SYS/include/boost/version.hpp" ] || ! grep -q "\"$(echo "$BOOST_VERSION" | tr . _ | sed 's/_0$//')\"" "$SYS/include/boost/version.hpp" \
        || [ "$(cat "$SYS/include/.boost-edits" 2>/dev/null)" != 2 ]; then
    T="$WORK/deps/boost-$BOOST_VERSION.tar.xz"
    [ -f "$T" ] || curl -sSfL -o "$T" "$BOOST_URL"
    echo "$BOOST_SHA256  $T" | sha256sum -c - >/dev/null
    rm -rf "$WORK/deps/boost-$BOOST_VERSION" "$SYS/include/boost"
    tar xJf "$T" -C "$WORK/deps" "boost-$BOOST_VERSION/boost"
    mv "$WORK/deps/boost-$BOOST_VERSION/boost" "$SYS/include/boost"
    # Asio wakes its select() with a loopback socket pair on AmigaOS, as on
    # Windows: libnix's select() watches sockets only
    A="$SYS/include/boost/asio/detail"
    for f in select_interrupter.hpp socket_select_interrupter.hpp impl/socket_select_interrupter.ipp; do
        sed -i 's/|| defined(__SYMBIAN32__)$/|| defined(__SYMBIAN32__) || defined(__AMIGA__)/' "$A/$f"
        grep -q '__AMIGA__' "$A/$f" || { echo "$f: edit not applied"; exit 1; }
    done
    echo 2 > "$SYS/include/.boost-edits"
    # aMule's CMake looks Boost up as a CONFIG package: a header-only one
    D="$SYS/lib/cmake/Boost-$BOOST_VERSION"; mkdir -p "$D"
    cat > "$D/BoostConfig.cmake" <<CFG
set(Boost_VERSION $BOOST_VERSION)
set(Boost_INCLUDE_DIRS "$SYS/include")
set(Boost_LIBRARIES "")
if(NOT TARGET Boost::headers)
  add_library(Boost::headers INTERFACE IMPORTED)
  set_target_properties(Boost::headers PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "$SYS/include")
  add_library(Boost::boost ALIAS Boost::headers)
endif()
set(Boost_FOUND TRUE)
CFG
    cat > "$D/BoostConfigVersion.cmake" <<CFG
set(PACKAGE_VERSION $BOOST_VERSION)
if(PACKAGE_FIND_VERSION VERSION_GREATER PACKAGE_VERSION)
  set(PACKAGE_VERSION_COMPATIBLE FALSE)
else()
  set(PACKAGE_VERSION_COMPATIBLE TRUE)
endif()
CFG
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
