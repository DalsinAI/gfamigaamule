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

# Boost: headers only
if [ ! -f "$SYS/include/boost/version.hpp" ] || ! grep -q "\"$(echo "$BOOST_VERSION" | tr . _ | sed 's/_0$//')\"" "$SYS/include/boost/version.hpp"; then
    T="$WORK/deps/boost-$BOOST_VERSION.tar.xz"
    [ -f "$T" ] || curl -sSfL -o "$T" "$BOOST_URL"
    echo "$BOOST_SHA256  $T" | sha256sum -c - >/dev/null
    rm -rf "$WORK/deps/boost-$BOOST_VERSION" "$SYS/include/boost"
    tar xJf "$T" -C "$WORK/deps" "boost-$BOOST_VERSION/boost"
    mv "$WORK/deps/boost-$BOOST_VERSION/boost" "$SYS/include/boost"
    # Asio wakes its select() with a loopback socket pair on AmigaOS, as on
    # Windows: libnix's select() watches sockets only
    sed -i 's/|| defined(__SYMBIAN32__)$/|| defined(__SYMBIAN32__) || defined(__AMIGA__)/' \
        "$SYS/include/boost/asio/detail/select_interrupter.hpp"
    [ "$(grep -c '__AMIGA__' "$SYS/include/boost/asio/detail/select_interrupter.hpp")" = 2 ] || { echo "select_interrupter.hpp: edit not applied"; exit 1; }
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
