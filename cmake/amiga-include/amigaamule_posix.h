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
#include <netdb.h>

#ifndef INET_ADDRSTRLEN
#define INET_ADDRSTRLEN 16
#endif
#ifndef IF_NAMESIZE
#define IF_NAMESIZE 16
#endif

/* IPv6 names, for Asio's types and options: the stack has no IPv6, so a
 * v6 socket fails when it is made */
#ifndef AF_INET6
#define AF_INET6 28
#endif
#ifndef PF_INET6
#define PF_INET6 AF_INET6
#endif
#ifndef IPPROTO_IPV6
#define IPPROTO_IPV6 41
#endif
#ifndef IPPROTO_ICMPV6
#define IPPROTO_ICMPV6 58
#endif
#ifndef IPV6_UNICAST_HOPS
#define IPV6_UNICAST_HOPS 4
#endif
#ifndef IPV6_MULTICAST_IF
#define IPV6_MULTICAST_IF 9
#endif
#ifndef IPV6_MULTICAST_HOPS
#define IPV6_MULTICAST_HOPS 10
#endif
#ifndef IPV6_MULTICAST_LOOP
#define IPV6_MULTICAST_LOOP 11
#endif
#ifndef IPV6_JOIN_GROUP
#define IPV6_JOIN_GROUP 12
#endif
#ifndef IPV6_LEAVE_GROUP
#define IPV6_LEAVE_GROUP 13
#endif
#ifndef IPV6_V6ONLY
#define IPV6_V6ONLY 27
#endif
struct sockaddr_storage {
    unsigned char ss_len;
    unsigned char ss_family;
    char ss_pad[126];
} __attribute__((aligned(4)));
struct ipv6_mreq {
    struct in6_addr ipv6mr_multiaddr;
    unsigned int ipv6mr_interface;
};

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
/* libnix's socket library has these; its netdb.h does not declare them */
int getaddrinfo(const char *node, const char *service,
                const struct addrinfo *hints, struct addrinfo **res);
void freeaddrinfo(struct addrinfo *res);
int getnameinfo(const struct sockaddr *sa, socklen_t salen, char *host,
                size_t hostlen, char *serv, size_t servlen, int flags);
/* declared for Asio's gethostbyname wrappers, which go unused while
 * getaddrinfo() is there */
int gethostbyname_r(const char *name, struct hostent *ret, char *buf,
                    size_t buflen, struct hostent **result, int *h_errnop);
int gethostbyaddr_r(const void *addr, socklen_t len, int type,
                    struct hostent *ret, char *buf, size_t buflen,
                    struct hostent **result, int *h_errnop);
#ifdef __cplusplus
}
#endif
#endif
