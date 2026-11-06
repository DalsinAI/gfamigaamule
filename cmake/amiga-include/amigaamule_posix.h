/* amigaamule_posix.h: POSIX names libnix's headers lack that Boost.Asio
 * and aMule use, included ahead of every C++ file (-include). The calls are
 * in deps/compat.
 * Copyright (c) 2026 AmiCradle Team */
#ifndef AMIGAAMULE_POSIX_H
#define AMIGAAMULE_POSIX_H
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/uio.h>

#ifndef INET_ADDRSTRLEN
#define INET_ADDRSTRLEN 16
#endif
#ifndef IF_NAMESIZE
#define IF_NAMESIZE 16
#endif

#ifdef __cplusplus
extern "C" {
#endif
const char *inet_ntop(int af, const void *src, char *dst, socklen_t size);
int inet_pton(int af, const char *src, void *dst);
unsigned int if_nametoindex(const char *name);
char *if_indextoname(unsigned int index, char *name);
int socketpair(int domain, int type, int protocol, int sv[2]);
ssize_t readv(int fd, const struct iovec *iov, int iovcnt);
ssize_t writev(int fd, const struct iovec *iov, int iovcnt);
#ifdef __cplusplus
}
#endif
#endif
