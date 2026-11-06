/* poll() on select(): Boost.Asio's socket calls wait with poll(). The
 * select() the program links is the toolkit's (bsdsocket WaitSelect), which
 * answers by libnix descriptor.
 * Copyright (c) 2026 AmiCradle Team */
#include <errno.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/select.h>
#include "../../cmake/amiga-include/sys/poll.h"

int amigaamule_poll(struct pollfd *fds, nfds_t nfds, int timeout)
{
    fd_set r, w, e;
    struct timeval tv, *t = 0;
    int top = 0, n, got = 0;
    nfds_t i;

    FD_ZERO(&r);
    FD_ZERO(&w);
    FD_ZERO(&e);
    for (i = 0; i < nfds; i++) {
        fds[i].revents = 0;
        if (fds[i].fd < 0)
            continue;
        if (fds[i].fd >= FD_SETSIZE) {
            fds[i].revents = POLLNVAL;
            got++;
            continue;
        }
        if (fds[i].events & (POLLIN | POLLRDNORM | POLLRDBAND | POLLPRI))
            FD_SET(fds[i].fd, &r);
        if (fds[i].events & (POLLOUT | POLLWRBAND))
            FD_SET(fds[i].fd, &w);
        FD_SET(fds[i].fd, &e);
        if (fds[i].fd + 1 > top)
            top = fds[i].fd + 1;
    }
    if (got)
        return got;
    if (timeout >= 0) {
        tv.tv_sec = timeout / 1000;
        tv.tv_usec = (timeout % 1000) * 1000;
        t = &tv;
    }
    n = select(top, &r, &w, &e, t);
    if (n <= 0)
        return n;
    for (i = 0; i < nfds; i++) {
        const int fd = fds[i].fd;
        if (fd < 0)
            continue;
        if (FD_ISSET(fd, &r))
            fds[i].revents |= fds[i].events & (POLLIN | POLLRDNORM | POLLRDBAND | POLLPRI);
        if (FD_ISSET(fd, &w))
            fds[i].revents |= fds[i].events & (POLLOUT | POLLWRBAND);
        if (FD_ISSET(fd, &e))
            fds[i].revents |= POLLERR;
        if (fds[i].revents)
            got++;
    }
    return got;
}
