#include "wifi_encoding.h"
#include "wifi_scan_policy.h"

#include <chrono>
#include <cstdlib>
#include <iostream>

void Require(bool condition, const char *message) {
  if (!condition) {
    std::cerr << message << '\n';
    std::exit(1);
  }
}
int main() {
  using namespace std::chrono_literals;
  wave_wifi::ScanCadence cadence;
  const auto start = wave_wifi::ScanCadence::Clock::time_point{};
  Require(!cadence.TryStart(start, true),
          "Cancellation before preparation must prevent start");
  Require(cadence.TryStart(start), "First request at clock epoch must start");
  Require(!cadence.TryStart(start), "Concurrent request must not start twice");
  Require(!cadence.TryStart(start + 34999ms),
          "Cancelled/failed native start must retain throttle");
  Require(cadence.TryStart(start + 35s), "Request at boundary must start");
  Require(!cadence.TryStart(start + 36s),
          "New start must advance throttle window");
  Require(cadence.TryStart(start + 70s), "Subsequent boundary must start");
  wave_wifi::AdapterChoice adapters;
  adapters.Consider(0, false, false, false);
  adapters.Consider(1, true, false, true);
  adapters.Consider(2, true, true, false);
  Require(adapters.index() == 2,
          "Healthy powered adapter must beat broken and disabled adapters");
  adapters.Consider(3, true, true, true);
  Require(adapters.index() == 3, "Healthy connected adapter must be preferred");
  adapters.Consider(4, false, true, true);
  Require(adapters.index() == 3,
          "Failed radio query must not hide healthy connected adapter");
  wave_wifi::AdapterChoice failed_adapters;
  failed_adapters.Consider(0, false, false, false);
  Require(!failed_adapters.index(),
          "All failed adapters must report query failure");
  Require(wave_wifi::SupportedFrequencyKHz(6115000),
          "6 GHz radio frequency must survive normalization");
  Require(wave_wifi::SupportedFrequencyKHz(2484000),
          "Channel 14 frequency must survive normalization");
  Require(!wave_wifi::SupportedFrequencyKHz(58320000),
          "60 GHz radios must not masquerade as 6 GHz");
  Require(!wave_wifi::SupportedFrequencyKHz(6115001),
          "Fractional MHz must not be silently truncated");
  Require(!wave_wifi::SupportedFrequencyKHz(0),
          "Missing frequency must be excluded");
  const uint8_t address[] = {0x12, 0xab, 0, 0x09, 0xf0, 0x45};
  const uint8_t hidden[] = {0, 0, 0, 0, 0, 0};
  const uint8_t broadcast[] = {255, 255, 255, 255, 255, 255};
  Require(wave_wifi::Bssid(address) == "12:ab:00:09:f0:45",
          "BSSID must preserve all octets");
  Require(wave_wifi::Bssid(hidden).empty() &&
              wave_wifi::Bssid(broadcast).empty(),
          "Redacted identifiers must be excluded");
  const uint8_t unicode[] = {'W', 0xe6, 0xb3, 0xa2};
  Require(wave_wifi::Ssid(unicode, sizeof(unicode)) == "W波",
          "Unicode SSID must survive codec");
  const uint8_t malformed[] = {'W', 0xc0, 0x80};
  Require(wave_wifi::Ssid(malformed, sizeof(malformed)) == "\\x57\\xc0\\x80",
          "Malformed SSID must remain identifiable and valid UTF-8");
  const uint8_t truncated[] = {0xf0, 0x9f};
  const uint8_t surrogate[] = {0xed, 0xa0, 0x80};
  const uint8_t too_large[] = {0xf4, 0x90, 0x80, 0x80};
  Require(!wave_wifi::IsUtf8(truncated, sizeof(truncated)),
          "Truncated UTF-8 must be rejected");
  Require(!wave_wifi::IsUtf8(surrogate, sizeof(surrogate)),
          "UTF-16 surrogates must not reach Flutter string decoder");
  Require(!wave_wifi::IsUtf8(too_large, sizeof(too_large)),
          "Out-of-range codepoints must be rejected");
  std::cout << "Windows native boundary regressions passed\n";
}
