/* amigaamule_posix.h: included ahead of every C++ file (-include). The
 * POSIX network names libnix's headers lack come from GFOpenBoost's Amiga
 * config (their code is in its libboost_asio.a); getpass() is in
 * deps/compat.
 * Copyright (c) 2026 AmiCradle Team */
#ifndef AMIGAAMULE_POSIX_H
#define AMIGAAMULE_POSIX_H
#include <boost/config/platform/amigaos_net.hpp>

#ifdef __cplusplus
extern "C" {
#endif
char *getpass(const char *prompt);
#ifdef __cplusplus
}
#endif

/* exec/lists.h's macro would rewrite wxComboBox::IsListEmpty() */
#undef IsListEmpty
#endif
