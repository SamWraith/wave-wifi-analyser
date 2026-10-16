#ifndef RUNNER_WIFI_ENCODING_H_
#define RUNNER_WIFI_ENCODING_H_

#include <cstddef>
#include <cstdint>
#include <string>

namespace wave_wifi {
inline bool SupportedFrequencyKHz(uint32_t frequency) {
  if (frequency % 1000 != 0)
    return false;
  const auto mhz = frequency / 1000;
  return (mhz >= 2400 && mhz <= 2500) || (mhz >= 4900 && mhz <= 7125);
}

// SSIDs are arbitrary octets, not guaranteed UTF-8. Escape invalid input
// instead of passing invalid strings to Flutter's UTF-8 StandardMessageCodec.
inline bool IsUtf8(const uint8_t *bytes, size_t size) {
  for (size_t i = 0; i < size;) {
    const auto lead = bytes[i++];
    if (lead < 0x80)
      continue;
    size_t tail;
    uint32_t value;
    uint32_t minimum;
    if (lead >= 0xc2 && lead <= 0xdf) {
      tail = 1;
      value = lead & 0x1f;
      minimum = 0x80;
    } else if (lead >= 0xe0 && lead <= 0xef) {
      tail = 2;
      value = lead & 0x0f;
      minimum = 0x800;
    } else if (lead >= 0xf0 && lead <= 0xf4) {
      tail = 3;
      value = lead & 7;
      minimum = 0x10000;
    } else
      return false;
    if (tail > size - i)
      return false;
    while (tail-- > 0) {
      const auto next = bytes[i++];
      if ((next & 0xc0) != 0x80)
        return false;
      value = (value << 6) | (next & 0x3f);
    }
    if (value < minimum || value > 0x10ffff ||
        (value >= 0xd800 && value <= 0xdfff))
      return false;
  }
  return true;
}
inline std::string Ssid(const uint8_t *bytes, size_t size) {
  if (IsUtf8(bytes, size))
    return std::string(reinterpret_cast<const char *>(bytes), size);
  constexpr char hex[] = "0123456789abcdef";
  std::string escaped;
  for (size_t i = 0; i < size; ++i) {
    escaped += "\\x";
    escaped += hex[bytes[i] >> 4];
    escaped += hex[bytes[i] & 15];
  }
  return escaped;
}
inline std::string Bssid(const uint8_t *bytes) {
  bool zero = true, broadcast = true;
  for (size_t i = 0; i < 6; ++i) {
    zero &= bytes[i] == 0;
    broadcast &= bytes[i] == 255;
  }
  if (zero || broadcast)
    return {};
  constexpr char hex[] = "0123456789abcdef";
  std::string value;
  for (size_t i = 0; i < 6; ++i) {
    if (i != 0)
      value += ':';
    value += hex[bytes[i] >> 4];
    value += hex[bytes[i] & 15];
  }
  return value;
}
} // namespace wave_wifi
#endif
