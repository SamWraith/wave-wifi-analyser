#ifndef WAVE_LINUX_WIFI_TYPES_H_
#define WAVE_LINUX_WIFI_TYPES_H_

#include <chrono>
#include <cstdint>
#include <stdexcept>
#include <string>
#include <vector>

namespace wave_wifi {
struct NativeError : std::runtime_error {
  std::string code;
  NativeError(std::string code, std::string message)
      : std::runtime_error(message), code(std::move(code)) {}
};
struct AccessPoint {
  std::string ssid;
  std::string bssid;
  int rssi = 0;
  int frequency = 0;
  bool protected_network = false;
  bool security_known = false;
  bool connected = false;
};
struct RadioResults {
  std::vector<AccessPoint> points;
  int unavailable = 0;
  int redacted = 0;
};
struct Snapshot {
  bool permission = false;
  bool wifi_enabled = false;
  bool interface_available = false;
  bool completed = false;
  int64_t completion_id = 0;
  std::string status;
  RadioResults radio;
};
// Linux's mBm is signed hundredths of dBm. Never convert NM's relative
// Strength.
inline bool ValidSignal(int32_t mbm) { return mbm >= -12700 && mbm <= 0; }
inline bool SupportedFrequency(int mhz) {
  return (mhz >= 2412 && mhz <= 2472 && (mhz - 2412) % 5 == 0) || mhz == 2484 ||
         mhz == 5935 || (mhz >= 4900 && mhz < 5925 && mhz % 5 == 0) ||
         (mhz >= 5955 && mhz <= 7115 && (mhz - 5955) % 5 == 0);
}
class ScanCadence {
public:
  using Clock = std::chrono::steady_clock;
  bool TryStart(Clock::time_point now) {
    if (started_ && now - last_ < std::chrono::seconds(35))
      return false;
    started_ = true;
    last_ = now;
    return true;
  }

private:
  bool started_ = false;
  Clock::time_point last_;
};
// LastScan is CLOCK_BOOTTIME milliseconds, not a per-BSS timestamp. A later
// completion may include old BSS cache entries and may originate from another
// client. It proves only that NM observed a completed device scan after
// baseline.
inline bool CompletedAfter(int64_t baseline, int64_t current) {
  return current >= 0 && current > baseline;
}
} // namespace wave_wifi
#endif
