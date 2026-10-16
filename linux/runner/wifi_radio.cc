#include "wifi_radio.h"

#include <linux/nl80211.h>
#include <net/if.h>
#include <netlink/attr.h>
#include <netlink/genl/ctrl.h>
#include <netlink/genl/genl.h>
#include <netlink/socket.h>
#include <poll.h>
#include <sys/socket.h>

#include <array>
#include <cerrno>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <memory>
#include <set>

namespace wave_wifi {
namespace {
std::string Ssid(nlattr *ies) {
  if (!ies)
    return "";
  const auto *bytes = static_cast<const unsigned char *>(nla_data(ies));
  size_t size = static_cast<size_t>(nla_len(ies));
  for (size_t offset = 0; offset + 2 <= size;) {
    const size_t length = bytes[offset + 1];
    if (offset + 2 + length > size)
      break;
    if (bytes[offset] == 0 && length <= 32) {
      const char *start = reinterpret_cast<const char *>(bytes + offset + 2);
      if (length == 0 || std::memchr(start, '\0', length))
        return "";
      g_autofree char *valid = g_utf8_make_valid(start, length);
      return valid;
    }
    offset += 2 + length;
  }
  return "";
}
struct Dump {
  RadioResults results;
  bool done = false;
  int error = 0;
};
int Valid(nl_msg *message, void *data) {
  DecodeBss(message, &static_cast<Dump *>(data)->results);
  return NL_OK;
}
int Finished(nl_msg *message, void *data) {
  auto *dump = static_cast<Dump *>(data);
  dump->done = true;
  const auto *header = nlmsg_hdr(message);
  if (header->nlmsg_flags & NLM_F_DUMP_INTR)
    dump->error = -EAGAIN;
  if (nlmsg_datalen(header) >= static_cast<int>(sizeof(int))) {
    int status = 0;
    std::memcpy(&status, nlmsg_data(header), sizeof(status));
    if (status != 0)
      dump->error = status;
  }
  return NL_STOP;
}
int Failed(sockaddr_nl *, nlmsgerr *error, void *data) {
  auto *dump = static_cast<Dump *>(data);
  dump->error = error->error;
  dump->done = true;
  return NL_STOP;
}
} // namespace

bool DecodeBss(nl_msg *message, RadioResults *results) {
  std::array<nlattr *, NL80211_ATTR_MAX + 1> attrs{};
  auto *header = nlmsg_hdr(message);
  if (genlmsg_parse(header, 0, attrs.data(), NL80211_ATTR_MAX, nullptr) < 0 ||
      !attrs[NL80211_ATTR_BSS]) {
    ++results->unavailable;
    return false;
  }
  std::array<nlattr *, NL80211_BSS_MAX + 1> bss{};
  if (nla_parse_nested(bss.data(), NL80211_BSS_MAX, attrs[NL80211_ATTR_BSS],
                       nullptr) < 0 ||
      !bss[NL80211_BSS_BSSID] || nla_len(bss[NL80211_BSS_BSSID]) != 6 ||
      !bss[NL80211_BSS_FREQUENCY] || nla_len(bss[NL80211_BSS_FREQUENCY]) != 4 ||
      !bss[NL80211_BSS_SIGNAL_MBM] ||
      nla_len(bss[NL80211_BSS_SIGNAL_MBM]) != 4) {
    ++results->unavailable;
    return false;
  }
  const int frequency =
      static_cast<int>(nla_get_u32(bss[NL80211_BSS_FREQUENCY]));
  int32_t mbm;
  const uint32_t raw = nla_get_u32(bss[NL80211_BSS_SIGNAL_MBM]);
  std::memcpy(&mbm, &raw, sizeof(mbm));
  if (!ValidSignal(mbm) || !SupportedFrequency(frequency)) {
    ++results->unavailable;
    return false;
  }
  const auto *mac =
      static_cast<const unsigned char *>(nla_data(bss[NL80211_BSS_BSSID]));
  // Exclude multicast, broadcast and all-zero identifiers.
  if ((mac[0] & 1) ||
      (mac[0] | mac[1] | mac[2] | mac[3] | mac[4] | mac[5]) == 0) {
    ++results->redacted;
    return false;
  }
  char address[18];
  std::snprintf(address, sizeof(address), "%02x:%02x:%02x:%02x:%02x:%02x",
                mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  AccessPoint point;
  point.bssid = address;
  point.frequency = frequency;
  // Round to nearest integer dBm, retaining sign (wire format is hundredths).
  point.rssi = static_cast<int>(std::lround(static_cast<double>(mbm) / 100.0));
  point.ssid = Ssid(bss[NL80211_BSS_INFORMATION_ELEMENTS]);
  if (point.ssid.empty())
    point.ssid = Ssid(bss[NL80211_BSS_BEACON_IES]);
  if (bss[NL80211_BSS_CAPABILITY] &&
      nla_len(bss[NL80211_BSS_CAPABILITY]) == 2) {
    point.security_known = true;
    point.protected_network =
        (nla_get_u16(bss[NL80211_BSS_CAPABILITY]) & 0x10) != 0;
  }
  results->points.push_back(std::move(point));
  return true;
}

RadioResults ReadRadio(const std::string &name, GCancellable *cancel) {
  const unsigned index = if_nametoindex(name.c_str());
  if (index == 0)
    throw NativeError("adapter_unavailable",
                      "Selected WiFi adapter disappeared.");
  std::unique_ptr<nl_sock, decltype(&nl_socket_free)> socket(nl_socket_alloc(),
                                                             nl_socket_free);
  if (!socket || genl_connect(socket.get()) < 0)
    throw NativeError("native_error", "Cannot open Linux nl80211 connection.");
  // Family lookup uses libnl synchronous control exchange before the dump.
  // Bound both socket directions so cancellation/disposal cannot leave a worker
  // waiting forever even if the local kernel/control exchange fails.
  const timeval timeout{3, 0};
  const int fd = nl_socket_get_fd(socket.get());
  if (setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) != 0 ||
      setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout)) != 0)
    throw NativeError("native_error",
                      "Cannot bound Linux scan-cache connection timeout.");
  if (g_cancellable_is_cancelled(cancel))
    throw NativeError("scan_cancelled", "WiFi request cancelled.");
  const int family = genl_ctrl_resolve(socket.get(), "nl80211");
  if (family < 0)
    throw NativeError("unsupported_driver",
                      "Linux kernel does not expose nl80211 WiFi data.");
  std::unique_ptr<nl_msg, decltype(&nlmsg_free)> message(nlmsg_alloc(),
                                                         nlmsg_free);
  if (!message ||
      !genlmsg_put(message.get(), NL_AUTO_PORT, NL_AUTO_SEQ, family, 0,
                   NLM_F_DUMP, NL80211_CMD_GET_SCAN, 0) ||
      nla_put_u32(message.get(), NL80211_ATTR_IFINDEX, index) < 0)
    throw NativeError("native_error", "Cannot allocate Linux scan request.");
  Dump dump;
  nl_socket_modify_cb(socket.get(), NL_CB_VALID, NL_CB_CUSTOM, Valid, &dump);
  nl_socket_modify_cb(socket.get(), NL_CB_FINISH, NL_CB_CUSTOM, Finished,
                      &dump);
  nl_socket_modify_err_cb(socket.get(), NL_CB_CUSTOM, Failed, &dump);
  if (nl_send_auto(socket.get(), message.get()) < 0 ||
      nl_socket_set_nonblocking(socket.get()) < 0)
    throw NativeError("native_error", "Cannot request Linux scan cache.");
  const auto deadline =
      std::chrono::steady_clock::now() + std::chrono::seconds(3);
  while (!dump.done) {
    if (g_cancellable_is_cancelled(cancel))
      throw NativeError("scan_cancelled", "WiFi request cancelled.");
    if (std::chrono::steady_clock::now() >= deadline)
      throw NativeError("native_timeout",
                        "Linux scan-cache read timed out. Retry scan.");
    pollfd descriptor{nl_socket_get_fd(socket.get()), POLLIN, 0};
    const int ready = poll(&descriptor, 1, 100);
    if (ready < 0 && errno == EINTR)
      continue;
    if (ready < 0 || (descriptor.revents & (POLLERR | POLLHUP | POLLNVAL)))
      throw NativeError("native_error", "Linux scan-cache connection failed.");
    if (ready > 0) {
      const int received = nl_recvmsgs_default(socket.get());
      if (received < 0 && received != -NLE_AGAIN && !dump.done)
        throw NativeError("native_error",
                          std::string("Cannot read Linux scan cache: ") +
                              nl_geterror(received));
    }
  }
  if (dump.error != 0)
    throw NativeError(dump.error == -EPERM || dump.error == -EACCES
                          ? "permission_denied"
                          : "native_error",
                      std::string("Linux driver rejected scan-cache read: ") +
                          std::strerror(-dump.error));
  std::set<std::string> seen;
  RadioResults unique;
  unique.redacted = dump.results.redacted;
  unique.unavailable = dump.results.unavailable;
  for (auto &point : dump.results.points)
    if (seen.insert(point.bssid).second)
      unique.points.push_back(std::move(point));
  return unique;
}
} // namespace wave_wifi
