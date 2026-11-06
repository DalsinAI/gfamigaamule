/* fdprobe: libnix's file descriptors with two pthreads. One thread opens,
 * reads and closes one file through stdio, the main task does the same
 * with another through open()/read()/close(), as wxFile does. Each checks
 * it read its own file; prints errors, and the fd numbers seen.
 * Copyright (c) 2026 AmiCradle Team */
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>

extern unsigned long amigaamule_fdlock_calls __attribute__((weak));
static const char *a_path, *b_path;
static char a_head[64], b_head[64];
static volatile int a_bad, b_bad, a_rounds, b_rounds, a_err, b_err;

static void *stdio_side(void *arg)
{
    const time_t end = time(NULL) + 8;
    char buf[64];
    (void)arg;
    while (time(NULL) < end) {
        FILE *f = fopen(a_path, "r");
        size_t n;
        if (!f) { a_err = errno; a_bad++; continue; }
        n = fread(buf, 1, sizeof buf, f);
        if (n == 0 && ferror(f)) { a_err = errno; a_bad++; }
        else if (memcmp(buf, a_head, n)) a_bad++;
        fclose(f);
        a_rounds++;
    }
    return NULL;
}

static void posix_side(void)
{
    const time_t end = time(NULL) + 8;
    char buf[64];
    while (time(NULL) < end) {
        int fd = open(b_path, O_RDONLY), n;
        if (fd < 0) { b_err = errno; b_bad++; continue; }
        n = read(fd, buf, sizeof buf);
        if (n < 0) { b_err = errno; b_bad++; }
        else if (memcmp(buf, b_head, n)) b_bad++;
        close(fd);
        b_rounds++;
    }
}

static void head(const char *p, char *h)
{
    FILE *f = fopen(p, "r");
    if (f) { fread(h, 1, 64, f); fclose(f); }
}

int main(int argc, char **argv)
{
    pthread_t t;
    a_path = argc > 1 ? argv[1] : "S:Startup-Sequence";
    b_path = argc > 2 ? argv[2] : "S:User-Startup";
    head(a_path, a_head);
    head(b_path, b_head);
    if (pthread_create(&t, NULL, stdio_side, NULL)) { printf("fdprobe: no thread\n"); return 1; }
    posix_side();
    pthread_join(t, NULL);
    printf("fdprobe: stdio thread %d rounds, %d bad (errno %d); open() main %d rounds, %d bad (errno %d)\n",
           a_rounds, a_bad, a_err, b_rounds, b_bad, b_err);
    if (&amigaamule_fdlock_calls)
        printf("fdprobe: fdlock on, %lu calls through it\n", amigaamule_fdlock_calls);
    return (a_bad || b_bad) ? 5 : 0;
}
