# CMake toolchain for the 68040 soft-float AmigaOS build.
#   -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-m68k-amigaos.cmake -DAMIGA_TOOLCHAIN=... -DAMIGA_SYSROOT=...
# Copyright (c) 2026 AmiCradle Team
set(CMAKE_SYSTEM_NAME AmigaOS)
set(CMAKE_SYSTEM_PROCESSOR m68k)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}")
set(CMAKE_C_COMPILER "${AMIGA_TOOLCHAIN}/bin/m68k-amigaos-gcc")
set(CMAKE_CXX_COMPILER "${AMIGA_TOOLCHAIN}/bin/m68k-amigaos-g++")
set(CMAKE_AR "${AMIGA_TOOLCHAIN}/bin/m68k-amigaos-ar" CACHE FILEPATH "")
set(CMAKE_RANLIB "${AMIGA_TOOLCHAIN}/bin/m68k-amigaos-ranlib" CACHE FILEPATH "")
set(CMAKE_STRIP "${AMIGA_TOOLCHAIN}/bin/m68k-amigaos-strip" CACHE FILEPATH "")
# Boost.Asio: one task (bsdsocket is per task), no serial ports (GFOpenBoost's
# Amiga config says so too); its code is in GFOpenBoost's libboost_asio.a
set(AMIGA_ASIO_DEFS "-DBOOST_ASIO_DISABLE_THREADS -DBOOST_ASIO_DISABLE_SERIAL_PORT -DBOOST_ASIO_SEPARATE_COMPILATION")
set(CMAKE_C_FLAGS_INIT "-noixemul -m68040 -I${CMAKE_CURRENT_LIST_DIR}/amiga-include -I${AMIGA_SYSROOT}/include")
set(CMAKE_CXX_FLAGS_INIT "-noixemul -m68040 -I${CMAKE_CURRENT_LIST_DIR}/amiga-include -I${AMIGA_SYSROOT}/include -include amigaamule_posix.h ${AMIGA_ASIO_DEFS}")
# libnix's fd table under one lock (deps/compat/fdlock.c)
set(AMIGA_FDLOCK "-Wl,--wrap=open,--wrap=close,--wrap=socket,--wrap=accept")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-noixemul -m68040 -specs=${AMIGA_SPECS} -L${AMIGA_SYSROOT}/lib ${AMIGA_FDLOCK}")
# after every library, whole archives included
set(CMAKE_C_STANDARD_LIBRARIES "-lboost_asio -lamigacompat -lsocket -lpthread -latomic -lm")
set(CMAKE_CXX_STANDARD_LIBRARIES "-lboost_asio -lamigacompat -lsocket -lpthread -latomic -lm")
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
set(CMAKE_FIND_ROOT_PATH "${AMIGA_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
# BOTH: the toolkit SDK wx-config names lives outside the sysroot
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
