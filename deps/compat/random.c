/* arc4random_buf() for Crypto++'s operating-system generator on AmigaOS,
 * which has no /dev/urandom. A ChaCha20 stream whose key comes from the
 * EClock, the date, the task, the stack and free memory, and takes in a
 * fresh EClock reading at every call.
 * amigaamule_ticks_ms(), aMule's tick count, reads the same EClock.
 * Copyright (c) 2026 AmiCradle Team */
/* our own timer.device base: not a TimerBase another library may define */
#define TimerBase amigaamule_TimerBase
#include <string.h>
#include <exec/types.h>
#include <exec/memory.h>
#include <exec/io.h>
#include <devices/timer.h>
#include <dos/dos.h>
#include <proto/exec.h>
#include <proto/dos.h>
#include <proto/timer.h>

struct Device *TimerBase;
static struct timerequest treq;
static int timer_open;

static unsigned long st[16];    /* ChaCha20 state: constants, key, counter, nonce */
static int seeded;

#define ROTL(a, b) (((a) << (b)) | ((a) >> (32 - (b))))
#define QR(a, b, c, d) \
    a += b; d ^= a; d = ROTL(d, 16); \
    c += d; b ^= c; b = ROTL(b, 12); \
    a += b; d ^= a; d = ROTL(d, 8);  \
    c += d; b ^= c; b = ROTL(b, 7)

static void chacha_block(unsigned long out[16])
{
    unsigned long x[16];
    int i;
    memcpy(x, st, sizeof x);
    for (i = 0; i < 10; i++) {
        QR(x[0], x[4], x[8], x[12]);
        QR(x[1], x[5], x[9], x[13]);
        QR(x[2], x[6], x[10], x[14]);
        QR(x[3], x[7], x[11], x[15]);
        QR(x[0], x[5], x[10], x[15]);
        QR(x[1], x[6], x[11], x[12]);
        QR(x[2], x[7], x[8], x[13]);
        QR(x[3], x[4], x[9], x[14]);
    }
    for (i = 0; i < 16; i++)
        out[i] = (x[i] + st[i]) & 0xffffffffUL;
    if (++st[12] == 0)
        st[13]++;
}

static void eclock(unsigned long v[2])
{
    struct EClockVal e;
    if (!timer_open) {
        timer_open = 1;
        if (OpenDevice((CONST_STRPTR)TIMERNAME, UNIT_ECLOCK, (struct IORequest *)&treq, 0) == 0)
            TimerBase = treq.tr_node.io_Device;
    }
    if (TimerBase) {
        v[0] ^= ReadEClock(&e);
        v[0] ^= e.ev_lo;
        v[1] ^= e.ev_hi;
    }
}

/* milliseconds since an arbitrary start, from the EClock: monotonic */
unsigned long long amigaamule_ticks_ms(void)
{
    struct EClockVal e;
    unsigned long v[2] = { 0, 0 };
    unsigned long freq;
    unsigned long long t;
    eclock(v);  /* opens timer.device on the first call */
    if (!TimerBase)
        return 0;
    freq = ReadEClock(&e);
    t = ((unsigned long long)e.ev_hi << 32) | e.ev_lo;
    return freq ? (t / freq) * 1000ULL + (t % freq) * 1000ULL / freq : 0;
}

static void stir(void)
{
    unsigned long v[2] = { 0, 0 }, out[16];
    int i;
    eclock(v);
    st[4] ^= v[0];
    st[5] ^= v[1];
    /* the stream's own output becomes the new key: no going backwards */
    chacha_block(out);
    for (i = 0; i < 8; i++)
        st[4 + i] = out[i];
}

static void seed(void)
{
    struct DateStamp ds;
    unsigned long v[2] = { 0, 0 };
    int i;
    st[0] = 0x61707865UL; st[1] = 0x3320646eUL;
    st[2] = 0x79622d32UL; st[3] = 0x6b206574UL;
    eclock(v);
    st[4] = v[0];
    st[5] = v[1];
    DateStamp(&ds);
    st[6] = (unsigned long)ds.ds_Days;
    st[7] = (unsigned long)ds.ds_Minute * 3000UL + (unsigned long)ds.ds_Tick;
    st[8] = (unsigned long)FindTask(NULL);
    st[9] = (unsigned long)&ds;
    st[10] = (unsigned long)AvailMem(MEMF_ANY);
    st[11] = (unsigned long)AvailMem(MEMF_LARGEST);
    for (i = 0; i < 8; i++)
        stir();
    seeded = 1;
}

void arc4random_buf(void *buf, size_t n)
{
    unsigned char *p = (unsigned char *)buf;
    unsigned long out[16];
    if (!seeded)
        seed();
    stir();
    while (n) {
        size_t k = n < sizeof out ? n : sizeof out, i;
        chacha_block(out);
        for (i = 0; i < k; i++)
            p[i] = (unsigned char)(out[i / 4] >> (8 * (i % 4)));
        p += k;
        n -= k;
    }
    stir();
}

static void __attribute__((destructor)) random_close(void)
{
    if (TimerBase) {
        CloseDevice((struct IORequest *)&treq);
        TimerBase = NULL;
    }
}
