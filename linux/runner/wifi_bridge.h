#ifndef WAVE_LINUX_WIFI_BRIDGE_H_
#define WAVE_LINUX_WIFI_BRIDGE_H_
#include <flutter_linux/flutter_linux.h>
// Bridge lifetime follows FlView. All GTK/Flutter calls remain on main thread;
// owned GTask work uses only GIO/netlink and carries shared cancellation state.
void wave_wifi_bridge_attach(FlView *view);
#endif
