/* The calls amigaamule_posix.h declares. IPv4 only: the stack has no IPv6.
 * Copyright (c) 2026 AmiCradle Team */
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include "../../cmake/amiga-include/amigaamule_posix.h"

const char *inet_ntop(int af, const void *src, char *dst, socklen_t size)
{
    const unsigned char *b = (const unsigned char *)src;
    char t[INET_ADDRSTRLEN];
    if (af != AF_INET) {
        errno = EAFNOSUPPORT;
        return NULL;
    }
    snprintf(t, sizeof t, "%u.%u.%u.%u", b[0], b[1], b[2], b[3]);
    if (strlen(t) + 1 > size) {
        errno = ENOSPC;
        return NULL;
    }
    strcpy(dst, t);
    return dst;
}

int inet_pton(int af, const char *src, void *dst)
{
    unsigned char b[4];
    int i;
    if (af != AF_INET) {
        errno = EAFNOSUPPORT;
        return -1;
    }
    for (i = 0; i < 4; i++) {
        unsigned v = 0;
        int digits = 0;
        while (*src >= '0' && *src <= '9') {
            v = v * 10 + (unsigned)(*src++ - '0');
            if (++digits > 3 || v > 255)
                return 0;
        }
        if (!digits)
            return 0;
        b[i] = (unsigned char)v;
        if (i < 3 && *src++ != '.')
            return 0;
    }
    if (*src)
        return 0;
    memcpy(dst, b, 4);
    return 1;
}

unsigned int if_nametoindex(const char *name)
{
    (void)name;
    return 0;
}

char *if_indextoname(unsigned int index, char *name)
{
    (void)index;
    (void)name;
    errno = ENXIO;
    return NULL;
}

int socketpair(int domain, int type, int protocol, int sv[2])
{
    (void)domain; (void)type; (void)protocol; (void)sv;
    errno = EOPNOTSUPP;
    return -1;
}

ssize_t readv(int fd, const struct iovec *iov, int iovcnt)
{
    ssize_t total = 0;
    int i;
    for (i = 0; i < iovcnt; i++) {
        ssize_t n = read(fd, iov[i].iov_base, iov[i].iov_len);
        if (n < 0)
            return total ? total : -1;
        total += n;
        if ((size_t)n < iov[i].iov_len)
            break;
    }
    return total;
}

ssize_t writev(int fd, const struct iovec *iov, int iovcnt)
{
    ssize_t total = 0;
    int i;
    for (i = 0; i < iovcnt; i++) {
        ssize_t n = write(fd, iov[i].iov_base, iov[i].iov_len);
        if (n < 0)
            return total ? total : -1;
        total += n;
        if ((size_t)n < iov[i].iov_len)
            break;
    }
    return total;
}
