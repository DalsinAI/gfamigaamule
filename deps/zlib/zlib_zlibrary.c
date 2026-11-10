/*
 * zlib's calls on the system's z.library: one LVO each, the stream in A0
 * and the other arguments as the library's table says. The init calls
 * take no version or stream size.
 *
 * Two tables. From 53.13 on, GFOpenZlib (amicradle-guest
 * libraries/openzlib) has the Aminet z.library's table (z.lvo), and so do
 * other z.libraries: InflateInit2 -102, InflateSetDictionary -108,
 * Adler32 -132, Crc32 -138, DeflateBound -156. GFOpenZlib before 53.13
 * (53.12 is on the instances) had a table of its own: DeflateBound -108,
 * InflateInit2 -132, Adler32 -228 and so on. This file used only that old
 * table, so on 53.13 inflateInit2 landed on Adler32 and deflateBound on
 * InflateSetDictionary, and every gz/zip read and write broke. Now
 * z_old() says which table the opened library has, as the GFOpenWX
 * Toolkit's wxzlib_zlibrary.c does.
 *
 * The library is opened on first use; without it every call fails cleanly
 * (Z_VERSION_ERROR), so aMule reports the error instead of crashing.
 * gzopen/gzread/gzclose/gzerror read a gzip file through inflate.
 *
 * Copyright (c) 2026 AmiCradle Team
 */
#include <exec/types.h>
#include <exec/libraries.h>
#include <proto/exec.h>
#include <inline/macros.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "zlib.h"

static struct Library *ZBase;
static int ZOld;    /* GFOpenZlib before 53.13: its own old table */

static int zopen(void)
{
    if (!ZBase) {
        ZBase = OpenLibrary((CONST_STRPTR)"z.library", 0);
        if (ZBase) {
            const char *id = (const char *)ZBase->lib_IdString;
            int gf = id && strstr(id, "GFOpenZlib") != NULL;
            ZOld = gf && (ZBase->lib_Version < 53 ||
                          (ZBase->lib_Version == 53 && ZBase->lib_Revision < 13));
        }
    }
    return ZBase != NULL;
}

/* the opened library has GFOpenZlib's table from before 53.13 */
static int z_old(void)
{
    return ZOld;
}

static void zclose(void) __attribute__((destructor));
static void zclose(void)
{
    if (ZBase) {
        CloseLibrary(ZBase);
        ZBase = NULL;
    }
}

#define ZB struct Library *

const char *zlibVersion(void)
{
    /* only the old table has ZlibVersion (-30) */
    if (!zopen() || !z_old())
        return ZLIB_VERSION;
    return LP0(0x1e, const char *, ZlibVersion, ZB, ZBase);
}

/* the calls at the same place in both tables */
int deflateInit(z_streamp s, int level)
{
    if (!zopen()) return Z_VERSION_ERROR;
    return LP2(0x24, LONG, DeflateInit, z_streamp, s, a0, LONG, level, d0, ZB, ZBase);
}

int deflate(z_streamp s, int flush)
{
    if (!zopen()) return Z_STREAM_ERROR;
    return LP2(0x2a, LONG, Deflate, z_streamp, s, a0, LONG, flush, d0, ZB, ZBase);
}

int deflateEnd(z_streamp s)
{
    if (!zopen()) return Z_STREAM_ERROR;
    return LP1(0x30, LONG, DeflateEnd, z_streamp, s, a0, ZB, ZBase);
}

int inflateInit(z_streamp s)
{
    if (!zopen()) return Z_VERSION_ERROR;
    return LP1(0x36, LONG, InflateInit, z_streamp, s, a0, ZB, ZBase);
}

int inflate(z_streamp s, int flush)
{
    if (!zopen()) return Z_STREAM_ERROR;
    return LP2(0x3c, LONG, Inflate, z_streamp, s, a0, LONG, flush, d0, ZB, ZBase);
}

int inflateEnd(z_streamp s)
{
    if (!zopen()) return Z_STREAM_ERROR;
    return LP1(0x42, LONG, InflateEnd, z_streamp, s, a0, ZB, ZBase);
}

int deflateInit2(z_streamp s, int level, int method, int windowBits, int memLevel, int strategy)
{
    if (!zopen()) return Z_VERSION_ERROR;
    return LP6(0x48, LONG, DeflateInit2, z_streamp, s, a0, LONG, level, d0, LONG, method, d1,
               LONG, windowBits, d2, LONG, memLevel, d3, LONG, strategy, d4, ZB, ZBase);
}

int deflateReset(z_streamp s)
{
    if (!zopen()) return Z_STREAM_ERROR;
    return LP1(0x5a, LONG, DeflateReset, z_streamp, s, a0, ZB, ZBase);
}

/* the calls that moved: new table (z.lvo) first, then the old one */
uLong deflateBound(z_streamp s, uLong sourceLen)
{
    if (!zopen()) return sourceLen + (sourceLen >> 12) + (sourceLen >> 14) + (sourceLen >> 25) + 13;
    if (z_old())
        return LP2(0x6c, ULONG, DeflateBound, z_streamp, s, a0, ULONG, sourceLen, d0, ZB, ZBase);
    return LP2(0x9c, ULONG, DeflateBound, z_streamp, s, a0, ULONG, sourceLen, d0, ZB, ZBase);
}

int inflateInit2(z_streamp s, int windowBits)
{
    if (!zopen()) return Z_VERSION_ERROR;
    if (z_old())
        return LP2(0x84, LONG, InflateInit2, z_streamp, s, a0, LONG, windowBits, d0, ZB, ZBase);
    return LP2(0x66, LONG, InflateInit2, z_streamp, s, a0, LONG, windowBits, d0, ZB, ZBase);
}

int inflateReset(z_streamp s)
{
    if (!zopen()) return Z_STREAM_ERROR;
    if (z_old())
        return LP1(0xa2, LONG, InflateReset, z_streamp, s, a0, ZB, ZBase);
    return LP1(0x72, LONG, InflateReset, z_streamp, s, a0, ZB, ZBase);
}

int compress(Bytef *dest, uLongf *destLen, const Bytef *source, uLong sourceLen)
{
    if (!zopen()) return Z_VERSION_ERROR;
    if (z_old())
        return LP4(0xc6, LONG, Compress, Bytef *, dest, a0, uLongf *, destLen, a1,
                   const Bytef *, source, a2, ULONG, sourceLen, d0, ZB, ZBase);
    return LP4(0x78, LONG, Compress, Bytef *, dest, a0, uLongf *, destLen, a1,
               const Bytef *, source, a2, ULONG, sourceLen, d0, ZB, ZBase);
}

int compress2(Bytef *dest, uLongf *destLen, const Bytef *source, uLong sourceLen, int level)
{
    if (!zopen()) return Z_VERSION_ERROR;
    if (z_old())
        return LP5(0xcc, LONG, Compress2, Bytef *, dest, a0, uLongf *, destLen, a1,
                   const Bytef *, source, a2, ULONG, sourceLen, d0, LONG, level, d1, ZB, ZBase);
    return LP5(0xde, LONG, Compress2, Bytef *, dest, a0, uLongf *, destLen, a1,
               const Bytef *, source, a2, ULONG, sourceLen, d0, LONG, level, d1, ZB, ZBase);
}

uLong compressBound(uLong sourceLen)
{
    if (!zopen()) return sourceLen + (sourceLen >> 12) + (sourceLen >> 14) + (sourceLen >> 25) + 13;
    if (z_old())
        return LP1(0xd2, ULONG, CompressBound, ULONG, sourceLen, d0, ZB, ZBase);
    return LP1(0xe4, ULONG, CompressBound, ULONG, sourceLen, d0, ZB, ZBase);
}

int uncompress(Bytef *dest, uLongf *destLen, const Bytef *source, uLong sourceLen)
{
    if (!zopen()) return Z_VERSION_ERROR;
    if (z_old())
        return LP4(0xd8, LONG, Uncompress, Bytef *, dest, a0, uLongf *, destLen, a1,
                   const Bytef *, source, a2, ULONG, sourceLen, d0, ZB, ZBase);
    return LP4(0x7e, LONG, Uncompress, Bytef *, dest, a0, uLongf *, destLen, a1,
               const Bytef *, source, a2, ULONG, sourceLen, d0, ZB, ZBase);
}

uLong adler32(uLong adler, const Bytef *buf, uInt len)
{
    if (!zopen()) return 1;
    if (z_old())
        return LP3(0xe4, ULONG, Adler32, ULONG, adler, d0, const Bytef *, buf, a0, ULONG, len, d1, ZB, ZBase);
    return LP3(0x84, ULONG, Adler32, ULONG, adler, d0, const Bytef *, buf, a0, ULONG, len, d1, ZB, ZBase);
}

uLong crc32(uLong crc, const Bytef *buf, uInt len)
{
    if (!zopen()) return 0;
    if (z_old())
        return LP3(0xea, ULONG, Crc32, ULONG, crc, d0, const Bytef *, buf, a0, ULONG, len, d1, ZB, ZBase);
    return LP3(0x8a, ULONG, Crc32, ULONG, crc, d0, const Bytef *, buf, a0, ULONG, len, d1, ZB, ZBase);
}

/* ---- reading a gzip file ---- */

struct gzFile_s {
    FILE *f;
    z_stream s;
    int err;
    int done;
    Bytef in[16384];
};

gzFile gzopen(const char *path, const char *mode)
{
    gzFile g;
    if (!mode || mode[0] != 'r')
        return NULL;
    g = (gzFile)calloc(1, sizeof *g);
    if (!g)
        return NULL;
    g->f = fopen(path, "rb");
    /* 15 + 32: a gzip or a zlib header, whichever the file has */
    if (!g->f || inflateInit2(&g->s, MAX_WBITS + 32) != Z_OK) {
        if (g->f)
            fclose(g->f);
        free(g);
        return NULL;
    }
    return g;
}

int gzread(gzFile g, voidp buf, unsigned len)
{
    int rc;
    if (!g || g->err)
        return -1;
    if (g->done || !len)
        return 0;
    g->s.next_out = (Bytef *)buf;
    g->s.avail_out = len;
    while (g->s.avail_out) {
        if (!g->s.avail_in) {
            size_t n = fread(g->in, 1, sizeof g->in, g->f);
            if (n == 0) {
                if (ferror(g->f))
                    g->err = Z_ERRNO;
                else
                    g->err = Z_BUF_ERROR;  /* the file ends inside the stream */
                break;
            }
            g->s.next_in = g->in;
            g->s.avail_in = (uInt)n;
        }
        rc = inflate(&g->s, Z_NO_FLUSH);
        if (rc == Z_STREAM_END) {
            g->done = 1;
            break;
        }
        if (rc != Z_OK) {
            g->err = rc == Z_NEED_DICT ? Z_DATA_ERROR : rc;
            break;
        }
    }
    if (g->err && g->s.avail_out == len)
        return -1;
    return (int)(len - g->s.avail_out);
}

int gzclose(gzFile g)
{
    int rc;
    if (!g)
        return Z_STREAM_ERROR;
    inflateEnd(&g->s);
    rc = fclose(g->f) ? Z_ERRNO : Z_OK;
    free(g);
    return rc;
}

const char *gzerror(gzFile g, int *errnum)
{
    int e = g ? g->err : Z_STREAM_ERROR;
    if (errnum)
        *errnum = e;
    switch (e) {
    case Z_OK: return "";
    case Z_ERRNO: return "read error";
    case Z_BUF_ERROR: return "unexpected end of file";
    case Z_DATA_ERROR: return "data error";
    case Z_MEM_ERROR: return "out of memory";
    default: return "error";
    }
}
