#ifndef WAVE_LINUX_WIFI_BACKEND_H_
#define WAVE_LINUX_WIFI_BACKEND_H_
#include "wifi_types.h"
#include <functional>
#include <gio/gio.h>

namespace wave_wifi {
// Worker-only state. The bridge serializes all calls. D-Bus connection and
// radio reader injection allow real protocol tests without touching host WiFi.
class WifiBackend {
public:
  using RadioReader =
      std::function<RadioResults(const std::string &, GCancellable *)>;
  explicit WifiBackend(RadioReader reader, int scan_timeout_ms = 12000)
      : radio_reader_(std::move(reader)), scan_timeout_ms_(scan_timeout_ms) {}
  Snapshot Read(GDBusConnection *bus, bool scan, GCancellable *cancel,
                bool interactive = false);
  bool Permission(GDBusConnection *bus, GCancellable *cancel);

private:
  RadioReader radio_reader_;
  int scan_timeout_ms_;
  ScanCadence cadence_;
  int64_t completion_id_ = 0;
};
} // namespace wave_wifi
#endif
