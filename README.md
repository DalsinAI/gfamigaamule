# GF Amiga aMule

aMule, the eD2k and Kad file-sharing client, for AmigaOS 3 (68040; the FPU is used when there is one), on the GFOpenWX Toolkit (wxWidgets on GFOpenLayout).

aMule and the libraries it uses are fetched at build time; nothing third-party is kept in this repository.

## Building

```
STOVE=~/AmiCradle/stoves/os32-gcc16-open6 OUT=out ./build-amiga.sh
```

The first run fetches the GFOpenWX Toolkit at the commit `amule.lock` pins and builds its SDK, then Crypto++ and Boost's headers, then aMule for what is left of 840 s; run it again and it goes on from where it stopped. `out/amule` appears when it links.

| Where | What |
|---|---|
| `amule.lock` | aMule 3.0.0, Crypto++ 8.9.0, Boost 1.92.0 (headers only) and the toolkit, pinned |
| `patches/` | aMule's changes for the Amiga |
| `scripts/` | build-deps.sh (Crypto++, Boost), build-amule.sh |
| `cmake/` | the m68k-amigaos toolchain and platform files |
| `deps/zlib/` | zlib's API on the system's z.library (GFOpenZlib), and gz file reading through inflate |

The first build is the monolithic `amule` (window app). The daemon, remote GUI, web server, UPnP, GeoIP and translations are off for now.

## Licence

aMule is GPL v2 or later; the patches and build files here are under the same licence.

Designed, tested and delivered by The AmiCradle Team.
Copyright (c) 2026 AmiCradle Team

## Package

The build also makes `aMule-<version>.lha`: the `aMule` drawer (aMule, its ReadMe and `Libs/event.library` from GFOpenEvent 1.1 RC2) with its icon, and `Install-aMule`. Unpack it anywhere and double-click `Install-aMule`: it checks for a 68040 or later, asks where to put the drawer (Work: by default), copies it, and puts event.library in LIBS: unless a newer one is there. `package/` holds the Installer and icon specs; the files in `package/installer` and `package/icons` are made from them by amicradle's `scripts/port_installer.py` and `scripts/port_icons.py`.
