#ifndef RUNNER_WIFI_SCAN_POLICY_H_
#define RUNNER_WIFI_SCAN_POLICY_H_
#include <chrono>
#include <cstddef>
#include <optional>

namespace wave_wifi {
// Native starts, including failed/cancelled starts, consume cadence. Cached
// reads and denied requests do not. No OS request token exists to cancel a
// WlanScan.
class ScanCadence {
public:
  using Clock = std::chrono::steady_clock;
  bool TryStart(Clock::time_point now, bool cancelled = false) {
    if (cancelled)
      return false;
    if (last_start_ && now - *last_start_ < std::chrono::seconds(35))
      return false;
    last_start_ = now;
    return true;
  }

private:
  std::optional<Clock::time_point> last_start_;
};
// A broken adapter must not hide another healthy one. Connected state only
// breaks ties among adapters with the same powered state.
class AdapterChoice {
public:
  void Consider(size_t index, bool readable, bool powered, bool connected) {
    if (!readable)
      return;
    const int rank = (powered ? 2 : 0) + (connected ? 1 : 0);
    if (!index_ || rank > rank_) {
      index_ = index;
      rank_ = rank;
    }
  }
  std::optional<size_t> index() const { return index_; }

private:
  std::optional<size_t> index_;
  int rank_ = -1;
};
} // namespace wave_wifi
#endif
