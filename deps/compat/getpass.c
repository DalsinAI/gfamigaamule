/* getpass() for aMule's command-line password prompt: libnix has none.
 * Reads a line from the console (the console echoes it).
 * Copyright (c) 2026 AmiCradle Team */
#include <stdio.h>
#include <string.h>

char *getpass(const char *prompt)
{
    static char buf[128];
    fputs(prompt, stderr);
    fflush(stderr);
    if (!fgets(buf, sizeof buf, stdin))
        buf[0] = 0;
    buf[strcspn(buf, "\r\n")] = 0;
    return buf;
}
