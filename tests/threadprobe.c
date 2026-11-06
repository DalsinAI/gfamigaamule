/* threadprobe: are libnix's malloc and stdio safe with two pthreads?
 * Two threads and the main task each allocate, free and read a file for a
 * few seconds; prints what went wrong, and each one's stack size. A lab check for the aMule port.
 * Copyright (c) 2026 AmiCradle Team */
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <exec/tasks.h>
#include <clib/exec_protos.h>

static unsigned long stack_of_me(void)
{
    struct Task *t = FindTask(NULL);
    return (unsigned long)t->tc_SPUpper - (unsigned long)t->tc_SPLower;
}
static volatile unsigned long stacks[3];

static const char *path;
static volatile int bad_alloc, bad_read, rounds[3];

static void *work(void *arg)
{
    const int me = (int)(long)arg;
    const time_t end = time(NULL) + 5;
    char buf[256];
    stacks[me] = stack_of_me();
    while (time(NULL) < end) {
        int i;
        void *p[64];
        for (i = 0; i < 64; i++) {
            size_t n = 16 + (size_t)((i * 37 + me * 11) % 900);
            p[i] = malloc(n);
            if (!p[i]) { bad_alloc++; continue; }
            memset(p[i], me + 1, n);
        }
        for (i = 0; i < 64; i++) {
            if (p[i] && ((unsigned char *)p[i])[0] != (unsigned char)(me + 1))
                bad_alloc++;
            free(p[i]);
        }
        {
            FILE *f = fopen(path, "r");
            if (!f) { bad_read++; continue; }
            if (fread(buf, 1, sizeof buf, f) == 0 && ferror(f)) bad_read++;
            fclose(f);
        }
        rounds[me]++;
    }
    return NULL;
}

int main(int argc, char **argv)
{
    pthread_t t[2];
    path = argc > 1 ? argv[1] : "S:Startup-Sequence";
    if (pthread_create(&t[0], NULL, work, (void *)1L) || pthread_create(&t[1], NULL, work, (void *)2L)) {
        printf("threadprobe: pthread_create failed\n");
        return 1;
    }
    work((void *)0L);
    pthread_join(t[0], NULL);
    pthread_join(t[1], NULL);
    printf("threadprobe: stacks %lu (main) %lu %lu bytes\n", stacks[0], stacks[1], stacks[2]);
    printf("threadprobe: rounds %d %d %d, bad allocations %d, failed reads %d\n",
           rounds[0], rounds[1], rounds[2], bad_alloc, bad_read);
    return (bad_alloc || bad_read) ? 5 : 0;
}
