/* amigaamule_trace(): a lab diagnostic. When ENV:aMule.trace is set, each
 * ("t": only from threads, not the main task)
 * call adds one line (EClock ms, task name, text) to SYS:T/amule.trace,
 * opened and closed every time so a crash right after loses nothing.
 * Copyright (c) 2026 AmiCradle Team */
#include <stdarg.h>
#include <stdio.h>
#include <exec/types.h>
#include <exec/tasks.h>
#include <exec/semaphores.h>
#include <dos/dos.h>
#include <proto/exec.h>
#include <proto/dos.h>

extern unsigned long long amigaamule_ticks_ms(void);

static int trace_on = -1;
static struct SignalSemaphore trace_lock;
static struct Task *trace_main;

__attribute__((constructor)) static void trace_init(void)
{
    InitSemaphore(&trace_lock);
    trace_main = FindTask(NULL);
}

void amigaamule_trace(const char *fmt, ...)
{
    char line[256];
    char v[8];
    va_list ap;
    int n;
    BPTR fh;
    struct Task *me;

    if (trace_on < 0)
        trace_on = GetVar((STRPTR)"aMule.trace", (STRPTR)v, sizeof v, 0) > 0 ? (v[0] == 't' ? 2 : 1) : 0;
    if (!trace_on)
        return;
    me = FindTask(NULL);
    if (trace_on == 2 && me == trace_main)
        return;   /* "t": the threads only */
    n = snprintf(line, sizeof line, "%lu %s: ", (unsigned long)amigaamule_ticks_ms(),
                 me->tc_Node.ln_Name ? me->tc_Node.ln_Name : "?");
    va_start(ap, fmt);
    n += vsnprintf(line + n, sizeof line - n - 1, fmt, ap);
    va_end(ap);
    if (n > (int)sizeof line - 2)
        n = sizeof line - 2;
    line[n++] = '\n';
    ObtainSemaphore(&trace_lock);
    fh = Open((STRPTR)"SYS:T/amule.trace", MODE_READWRITE);
    if (fh) {
        Seek(fh, 0, OFFSET_END);
        Write(fh, line, n);
        Close(fh);
    }
    ReleaseSemaphore(&trace_lock);
}
