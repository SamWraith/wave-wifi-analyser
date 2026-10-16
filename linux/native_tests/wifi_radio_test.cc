#include "wifi_radio.h"
#include <iostream>
#include <linux/nl80211.h>
#include <memory>
#include <netlink/attr.h>
#include <netlink/genl/genl.h>

namespace {
void Check(bool value, const char *message) {
  if (!value)
    throw std::runtime_error(message);
}
wave_wifi::RadioResults Decode(int signal, int frequency = 5180,
                               bool dbm = true, bool valid_mac = true,
                               bool hidden = false, bool capability = true) {
  std::unique_ptr<nl_msg, decltype(&nlmsg_free)> message(nlmsg_alloc(),
                                                         nlmsg_free);
  genlmsg_put(message.get(), NL_AUTO_PORT, NL_AUTO_SEQ, 0, 0, 0,
              NL80211_CMD_NEW_SCAN_RESULTS, 0);
  nlattr *bss = nla_nest_start(message.get(), NL80211_ATTR_BSS);
  const unsigned char mac[] = {0x02, 0x13, 0x24, 0x35, 0x46, 0x57};
  nla_put(message.get(), NL80211_BSS_BSSID, valid_mac ? 6 : 5, mac);
  nla_put_u32(message.get(), NL80211_BSS_FREQUENCY, frequency);
  if (dbm)
    nla_put_u32(message.get(), NL80211_BSS_SIGNAL_MBM,
                static_cast<uint32_t>(signal));
  else
    nla_put_u8(message.get(), NL80211_BSS_SIGNAL_UNSPEC, 90);
  if (capability)
    nla_put_u16(message.get(), NL80211_BSS_CAPABILITY, 0x10);
  const unsigned char ssid[] = {0, 4, 'W', 'a', 'v', 'e'};
  const unsigned char empty[] = {0, 0};
  nla_put(message.get(), NL80211_BSS_INFORMATION_ELEMENTS, hidden ? 2 : 6,
          hidden ? empty : ssid);
  nla_nest_end(message.get(), bss);
  wave_wifi::RadioResults result;
  wave_wifi::DecodeBss(message.get(), &result);
  return result;
}
} // namespace
int main() {
  try {
    auto valid = Decode(-5250);
    Check(valid.points.size() == 1, "real mBm entry missing");
    const auto &ap = valid.points.front();
    Check(ap.rssi == -53 && ap.frequency == 5180 && ap.ssid == "Wave" &&
              ap.bssid == "02:13:24:35:46:57" && ap.protected_network &&
              ap.security_known,
          "BSS identity/radio decode wrong");
    Check(Decode(0, 5180, false).points.empty(),
          "relative NM/driver percentage accepted as dBm");
    Check(Decode(-12800).unavailable == 1, "invalid signal accepted");
    Check(Decode(-5000, 60480).unavailable == 1, "unsupported 60 GHz accepted");
    Check(Decode(-5000, 5955).points.size() == 1, "6 GHz rejected");
    Check(Decode(-5000, 5935).points.size() == 1, "6 GHz channel 2 rejected");
    Check(Decode(-5000, 2484).points.size() == 1,
          "2.4 GHz channel 14 rejected");
    Check(Decode(-5000, 5180, true, false).unavailable == 1,
          "malformed MAC accepted");
    Check(Decode(-5000, 5180, true, true, true).points.front().ssid.empty(),
          "hidden SSID invented");
    Check(!Decode(-5000, 5180, true, true, false, false)
               .points.front()
               .security_known,
          "missing capability falsely labels network open");
    Check(Decode(-5000, 4910).points.size() == 1, "4.9 GHz rejected");
    wave_wifi::ScanCadence cadence;
    const auto epoch = wave_wifi::ScanCadence::Clock::time_point{};
    Check(cadence.TryStart(epoch), "initial scan blocked");
    Check(!cadence.TryStart(epoch + std::chrono::seconds(34)),
          "cadence bypass");
    Check(cadence.TryStart(epoch + std::chrono::seconds(35)),
          "35 second boundary blocked");
    Check(!wave_wifi::CompletedAfter(100, 100) &&
              !wave_wifi::CompletedAfter(100, 99) &&
              wave_wifi::CompletedAfter(-1, 0) &&
              !wave_wifi::CompletedAfter(-1, -1),
          "false completion accepted");
    std::cout
        << "Linux signal, BSS, cadence and completion boundaries passed\n";
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
