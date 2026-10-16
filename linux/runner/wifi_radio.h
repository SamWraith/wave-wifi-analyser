#ifndef WAVE_LINUX_WIFI_RADIO_H_
#define WAVE_LINUX_WIFI_RADIO_H_
#include "wifi_types.h"
#include <gio/gio.h>
#include <netlink/msg.h>
namespace wave_wifi {
// Public decoder boundary supports malformed kernel-record regression tests.
bool DecodeBss(nl_msg *message, RadioResults *results);
RadioResults ReadRadio(const std::string &interface_name, GCancellable *cancel);
} // namespace wave_wifi
#endif
