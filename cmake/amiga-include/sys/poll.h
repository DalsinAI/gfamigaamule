/* sys/poll.h for m68k-amigaos: libnix has no poll header. poll() here is
 * deps/compat/poll.c, built on select() (the toolkit's, on WaitSelect).
 * Copyright (c) 2026 AmiCradle Team */
#ifndef AMIGAAMULE_SYS_POLL_H
#define AMIGAAMULE_SYS_POLL_H
#ifdef __cplusplus
extern "C" {
#endif
struct pollfd {
    int fd;
    short events;
    short revents;
};
typedef unsigned int nfds_t;
#define POLLIN     0x0001
#define POLLPRI    0x0002
#define POLLOUT    0x0004
#define POLLERR    0x0008
#define POLLHUP    0x0010
#define POLLNVAL   0x0020
#define POLLRDNORM 0x0040
#define POLLRDBAND 0x0080
#define POLLWRNORM POLLOUT
#define POLLWRBAND 0x0100
/* our own, not libnix's */
#define poll amigaamule_poll
int amigaamule_poll(struct pollfd *fds, nfds_t nfds, int timeout);
#ifdef __cplusplus
}
#endif
#endif
