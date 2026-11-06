/* joinprobe: pthread create, priority, exit and join in a tight loop, with
 * the join landing before, during and after the thread's exit, as wxThread
 * does (attr stack size, sched param, a key, malloc on the way out).
 * Prints rounds done; a crash here is the pthread library's.
 * Copyright (c) 2026 AmiCradle Team */
#include <pthread.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>

static pthread_key_t key;
static volatile unsigned long sink;

static void spin(unsigned n)
{
    unsigned i;
    for (i = 0; i < n; i++)
        sink += i;
}

static void *work(void *arg)
{
    unsigned n = (unsigned)(unsigned long)arg;
    void *p = malloc(64 + n % 500);
    pthread_setspecific(key, p);
    spin(n);
    free(p);
    pthread_setspecific(key, NULL);
    return p;
}

int main(int argc, char **argv)
{
    int rounds = argc > 1 ? atoi(argv[1]) : 1000, i;
    pthread_key_create(&key, NULL);
    for (i = 0; i < rounds; i++) {
        pthread_t t;
        pthread_attr_t a;
        struct sched_param sp;
        int pol;
        pthread_attr_init(&a);
        pthread_attr_setstacksize(&a, 262144);
        if (pthread_create(&t, &a, work, (void *)(unsigned long)((i % 13) * 997))) {
            printf("joinprobe: create failed at %d\n", i);
            return 5;
        }
        pthread_attr_destroy(&a);
        if (pthread_getschedparam(t, &pol, &sp) == 0) {
            sp.sched_priority = (i & 1) ? -1 : 0;
            pthread_setschedparam(t, pol, &sp);
        }
        spin(((i * 7) % 11) * 1301);
        pthread_join(t, NULL);
        if (i % 100 == 0) {
            printf("joinprobe: %d\n", i);
            fflush(stdout);
        }
    }
    printf("joinprobe: %d rounds ok\n", rounds);
    return 0;
}
