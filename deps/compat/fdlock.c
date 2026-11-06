/* fdlock: libnix's file descriptor table for programs with threads.
 * libnix hands out fds from one table (open.o's __allocfd), which it grows
 * with realloc() and fills without a lock. Two tasks opening at once can
 * get the same slot, and a task reading while another grows the table
 * reads freed memory: aMule's IP filter thread lost reads that way
 * (tests/fdprobe.c shows it with plain libnix). Linked with
 * -Wl,--wrap=open,--wrap=close,--wrap=socket,--wrap=accept: those calls
 * take one semaphore, and the first open() grows the table once, on the
 * main task before any thread starts, so it is never moved after that.
 * Copyright (c) 2026 AmiCradle Team */
#include <stdarg.h>
#include <fcntl.h>
#include <sys/types.h>
#include <exec/types.h>
#include <exec/semaphores.h>
#include <proto/exec.h>

#define FDLOCK_TABLE 256    /* slots made at the first open() */

int __real_open(const char *path, int flags, ...);
int __real_close(int fd);
int __real_socket(int domain, int type, int protocol);
struct sockaddr;
int __real_accept(int s, struct sockaddr *addr, void *len);

unsigned long amigaamule_fdlock_calls;
static struct SignalSemaphore fd_lock;
static volatile int fd_ready;

static void fd_obtain(void)
{
    if (!fd_ready) {
        Forbid();
        if (!fd_ready) {
            InitSemaphore(&fd_lock);
            fd_ready = 1;
        }
        Permit();
    }
    ObtainSemaphore(&fd_lock);
}

static void fd_grow(void)
{
    static int done;
    static int fds[FDLOCK_TABLE];
    int i, n = 0;
    if (done)
        return;
    done = 1;
    for (i = 0; i < FDLOCK_TABLE; i++) {
        fds[i] = __real_open("NIL:", O_RDONLY);
        if (fds[i] < 0)
            break;
        n++;
    }
    for (i = 0; i < n; i++)
        __real_close(fds[i]);
}

int __wrap_open(const char *path, int flags, ...)
{
    int r, mode = 0;
    va_list ap;
    va_start(ap, flags);
    if (flags & O_CREAT)
        mode = va_arg(ap, int);
    va_end(ap);
    fd_obtain();
    fd_grow();
    amigaamule_fdlock_calls++;
    r = __real_open(path, flags, mode);
    ReleaseSemaphore(&fd_lock);
    return r;
}

int __wrap_close(int fd)
{
    int r;
    fd_obtain();
    amigaamule_fdlock_calls++;
    r = __real_close(fd);
    ReleaseSemaphore(&fd_lock);
    return r;
}

int __wrap_socket(int domain, int type, int protocol)
{
    int r;
    fd_obtain();
    fd_grow();
    r = __real_socket(domain, type, protocol);
    ReleaseSemaphore(&fd_lock);
    return r;
}

int __wrap_accept(int s, struct sockaddr *addr, void *len)
{
    int r;
    fd_obtain();
    r = __real_accept(s, addr, len);
    ReleaseSemaphore(&fd_lock);
    return r;
}
