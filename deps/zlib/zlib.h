/*
 * zlib.h for aMule on AmigaOS: zlib's API on the system's z.library
 * (GFOpenZlib, or the Aminet one: the same calls). The types and the
 * stream are zlib's own layout, as z.library takes them; the calls are in
 * zlib_zlibrary.c, and the gz file calls aMule uses read through inflate.
 *
 * Copyright (c) 2026 AmiCradle Team
 */
#ifndef GFAMIGA_ZLIB_H
#define GFAMIGA_ZLIB_H

#ifdef __cplusplus
extern "C" {
#endif

#define ZLIB_VERSION "1.3.1"
#define ZLIB_VERNUM 0x1310
#define ZLIB_VER_MAJOR 1
#define ZLIB_VER_MINOR 3
#define ZLIB_VER_REVISION 1
#define ZLIB_VER_SUBREVISION 0

#define MAX_WBITS 15
#define MAX_MEM_LEVEL 9

/* as zlib's default: next_in is not const (aMule writes through it) */
#ifndef z_const
#define z_const
#endif

typedef unsigned char Byte;
typedef unsigned int uInt;
typedef unsigned long uLong;
typedef Byte Bytef;
typedef char charf;
typedef int intf;
typedef uInt uIntf;
typedef uLong uLongf;
typedef void *voidpf;
typedef void *voidp;
typedef const void *voidpc;
typedef long z_off_t;

typedef voidpf (*alloc_func)(voidpf opaque, uInt items, uInt size);
typedef void (*free_func)(voidpf opaque, voidpf address);

struct internal_state;

typedef struct z_stream_s {
    z_const Bytef *next_in;
    uInt avail_in;
    uLong total_in;
    Bytef *next_out;
    uInt avail_out;
    uLong total_out;
    const char *msg;
    struct internal_state *state;
    alloc_func zalloc;
    free_func zfree;
    voidpf opaque;
    int data_type;
    uLong adler;
    uLong reserved;
} z_stream;

typedef z_stream *z_streamp;

#define Z_NO_FLUSH      0
#define Z_PARTIAL_FLUSH 1
#define Z_SYNC_FLUSH    2
#define Z_FULL_FLUSH    3
#define Z_FINISH        4
#define Z_BLOCK         5
#define Z_TREES         6

#define Z_OK            0
#define Z_STREAM_END    1
#define Z_NEED_DICT     2
#define Z_ERRNO        (-1)
#define Z_STREAM_ERROR (-2)
#define Z_DATA_ERROR   (-3)
#define Z_MEM_ERROR    (-4)
#define Z_BUF_ERROR    (-5)
#define Z_VERSION_ERROR (-6)

#define Z_NO_COMPRESSION         0
#define Z_BEST_SPEED             1
#define Z_BEST_COMPRESSION       9
#define Z_DEFAULT_COMPRESSION  (-1)

#define Z_FILTERED            1
#define Z_HUFFMAN_ONLY        2
#define Z_RLE                 3
#define Z_FIXED               4
#define Z_DEFAULT_STRATEGY    0

#define Z_BINARY   0
#define Z_TEXT     1
#define Z_ASCII    Z_TEXT
#define Z_UNKNOWN  2

#define Z_DEFLATED   8
#define Z_NULL  0

const char *zlibVersion(void);
int deflateInit(z_streamp strm, int level);
int deflate(z_streamp strm, int flush);
int deflateEnd(z_streamp strm);
int inflateInit(z_streamp strm);
int inflate(z_streamp strm, int flush);
int inflateEnd(z_streamp strm);
int deflateInit2(z_streamp strm, int level, int method, int windowBits, int memLevel, int strategy);
int deflateReset(z_streamp strm);
int inflateInit2(z_streamp strm, int windowBits);
int inflateReset(z_streamp strm);
uLong deflateBound(z_streamp strm, uLong sourceLen);
int compress(Bytef *dest, uLongf *destLen, const Bytef *source, uLong sourceLen);
int compress2(Bytef *dest, uLongf *destLen, const Bytef *source, uLong sourceLen, int level);
uLong compressBound(uLong sourceLen);
int uncompress(Bytef *dest, uLongf *destLen, const Bytef *source, uLong sourceLen);
uLong adler32(uLong adler, const Bytef *buf, uInt len);
uLong crc32(uLong crc, const Bytef *buf, uInt len);

/* gz files: reading only (what aMule does) */
typedef struct gzFile_s *gzFile;
gzFile gzopen(const char *path, const char *mode);
int gzread(gzFile file, voidp buf, unsigned len);
int gzclose(gzFile file);
const char *gzerror(gzFile file, int *errnum);

#ifdef __cplusplus
}
#endif

#endif
