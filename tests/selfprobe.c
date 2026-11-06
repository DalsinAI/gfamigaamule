/* selfprobe: what pthread_self() gives on the main task and on a thread.
 * wxThread::IsMain() compares the two; a main task id of 0 makes every
 * thread look like the main one to wx.
 * Copyright (c) 2026 AmiCradle Team */
#include <pthread.h>
#include <stdio.h>
#include <exec/tasks.h>
#include <clib/exec_protos.h>

static void *work(void *arg)
{
    (void)arg;
    printf("selfprobe: thread pthread_self %lu task %p\n", (unsigned long)pthread_self(), (void *)FindTask(NULL));
    return NULL;
}

int main(void)
{
    pthread_t t;
    printf("selfprobe: main pthread_self %lu task %p\n", (unsigned long)pthread_self(), (void *)FindTask(NULL));
    if (pthread_create(&t, NULL, work, NULL) == 0) {
        printf("selfprobe: created id %lu\n", (unsigned long)t);
        pthread_join(t, NULL);
    }
    printf("selfprobe: main again %lu\n", (unsigned long)pthread_self());
    return 0;
}
