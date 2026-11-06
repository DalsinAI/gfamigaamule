#!/bin/sh
# Lab diagnostic: which libnix objects define and use the fd calls, to
# see where a lock around them has to go. Prints to the job log.
# Copyright (c) 2026 AmiCradle Team
TC=$1
L=$("$TC/bin/m68k-amigaos-gcc" -noixemul -m68040 -print-file-name=libnix.a 2>/dev/null)
[ -f "$L" ] || L=$("$TC/bin/m68k-amigaos-gcc" -noixemul -print-file-name=libc.a)
echo "libnix: $L"
for s in open close read write lseek fopen fclose __srefill __stdfiledes __stdfilesize __allocfd __nextfd _lx_addflags; do
    "$TC/bin/m68k-amigaos-nm" -A "$L" 2>/dev/null | grep -E " [TDBC] _?$s\$" | head -2
done
for o in open.o close.o read.o fopen.o fclose.o; do
    echo "$o uses: $("$TC/bin/m68k-amigaos-nm" -A "$L" 2>/dev/null | grep ":$o:" | grep " U " | awk '{print $NF}' | tr '\n' ' ')"
done
"$TC/bin/m68k-amigaos-nm" -A "$L" 2>/dev/null | grep -iE "fd|filedes" | grep -E " [TDBC] " | head -20
