#include "wifi_backend.h"

#include <algorithm>
#include <cctype>
#include <memory>

namespace wave_wifi {
namespace {
constexpr const char *kService = "org.freedesktop.NetworkManager";
constexpr const char *kRoot = "/org/freedesktop/NetworkManager";
constexpr const char *kDevice = "org.freedesktop.NetworkManager.Device";
constexpr const char *kWireless =
    "org.freedesktop.NetworkManager.Device.Wireless";

void CheckCancelled(GCancellable *cancel) {
  if (g_cancellable_is_cancelled(cancel))
    throw NativeError("scan_cancelled", "WiFi request cancelled.");
}
GVariant *Call(GDBusConnection *bus, const std::string &path,
               const char *interface_name, const char *method,
               GVariant *arguments, const GVariantType *result_type,
               GCancellable *cancel, bool authorize = false) {
  CheckCancelled(cancel);
  g_autoptr(GError) error = nullptr;
  GVariant *reply = g_dbus_connection_call_sync(
      bus, kService, path.c_str(), interface_name, method, arguments,
      result_type,
      authorize ? G_DBUS_CALL_FLAGS_ALLOW_INTERACTIVE_AUTHORIZATION
                : G_DBUS_CALL_FLAGS_NONE,
      authorize ? 10000 : 3000, cancel, &error);
  if (reply)
    return reply;
  CheckCancelled(cancel);
  g_autofree char *remote = g_dbus_error_get_remote_error(error);
  const std::string name = remote ? remote : "";
  std::string code = "native_error";
  std::string message = "NetworkManager request failed: ";
  if (name.find("ServiceUnknown") != std::string::npos ||
      name.find("NameHasNoOwner") != std::string::npos) {
    code = "service_unavailable";
    message =
        "NetworkManager service unavailable. Start NetworkManager and retry. ";
  } else if (name.find("NotAuthorized") != std::string::npos ||
             name.find("PermissionDenied") != std::string::npos ||
             name.find("AccessDenied") != std::string::npos) {
    code = "permission_denied";
    message = "NetworkManager denied WiFi access. Allow WiFi scanning in your "
              "desktop's Polkit policy and retry. ";
  }
  throw NativeError(code,
                    message + (error ? error->message : "Unknown D-Bus error"));
}
GVariant *Properties(GDBusConnection *bus, const std::string &path,
                     const char *interface_name, GCancellable *cancel) {
  g_autoptr(GVariant) reply = Call(
      bus, path, "org.freedesktop.DBus.Properties", "GetAll",
      g_variant_new("(s)", interface_name), G_VARIANT_TYPE("(a{sv})"), cancel);
  GVariant *properties = nullptr;
  g_variant_get(reply, "(@a{sv})", &properties);
  return properties;
}
bool Bool(GVariant *properties, const char *key) {
  gboolean result;
  if (!g_variant_lookup(properties, key, "b", &result))
    throw NativeError("unsupported_service",
                      std::string("NetworkManager property unavailable: ") +
                          key);
  return result;
}
guint32 Uint(GVariant *properties, const char *key) {
  guint32 result;
  if (!g_variant_lookup(properties, key, "u", &result))
    throw NativeError("unsupported_service",
                      std::string("NetworkManager property unavailable: ") +
                          key);
  return result;
}
int64_t LastScan(GVariant *properties) {
  gint64 result;
  if (!g_variant_lookup(properties, "LastScan", "x", &result))
    throw NativeError(
        "unsupported_service",
        "NetworkManager 1.12 or newer with LastScan is required.");
  return result;
}
std::string String(GVariant *properties, const char *key,
                   const char *format = "&s") {
  const char *result = nullptr;
  if (!g_variant_lookup(properties, key, format, &result))
    throw NativeError("unsupported_service",
                      std::string("NetworkManager property unavailable: ") +
                          key);
  return result;
}
struct Adapter {
  std::string path;
  std::string name;
  bool ready = false;
  bool connected = false;
};
Adapter SelectAdapter(GDBusConnection *bus, GCancellable *cancel) {
  g_autoptr(GVariant) reply = Call(bus, kRoot, kService, "GetDevices", nullptr,
                                   G_VARIANT_TYPE("(ao)"), cancel);
  g_autoptr(GVariant) paths = g_variant_get_child_value(reply, 0);
  GVariantIter iter;
  g_variant_iter_init(&iter, paths);
  const char *path;
  Adapter selected;
  int rank = -1;
  std::unique_ptr<NativeError> unreadable;
  while (g_variant_iter_next(&iter, "&o", &path)) {
    CheckCancelled(cancel);
    try {
      g_autoptr(GVariant) properties = Properties(bus, path, kDevice, cancel);
      if (Uint(properties, "DeviceType") != 2)
        continue; // NM_DEVICE_TYPE_WIFI
      Adapter candidate;
      candidate.path = path;
      candidate.name = String(properties, "Interface");
      const guint32 state = Uint(properties, "State");
      candidate.ready = Bool(properties, "Managed") &&
                        !Bool(properties, "FirmwareMissing") && state >= 30 &&
                        state < 120; // DISCONNECTED .. DEACTIVATING
      candidate.connected = state == 100;
      const int candidate_rank =
          (candidate.ready ? 2 : 0) + (candidate.connected ? 1 : 0);
      if (candidate_rank > rank) {
        selected = std::move(candidate);
        rank = candidate_rank;
      }
    } catch (const NativeError &error) {
      // A disappearing/broken adapter must not hide another healthy adapter.
      // Cancellation and bus/service failure cannot be treated as no adapter.
      if (error.code == "scan_cancelled" ||
          error.code == "service_unavailable" ||
          error.code == "permission_denied")
        throw;
      unreadable.reset(new NativeError(error));
    }
  }
  if (selected.path.empty() && unreadable)
    throw *unreadable;
  return selected;
}
} // namespace

namespace {
std::string ScanPermission(GDBusConnection *bus, GCancellable *cancel) {
  g_autoptr(GVariant) reply = Call(bus, kRoot, kService, "GetPermissions",
                                   nullptr, G_VARIANT_TYPE("(a{ss})"), cancel);
  g_autoptr(GVariant) permissions = g_variant_get_child_value(reply, 0);
  const char *value = nullptr;
  if (!g_variant_lookup(permissions, "org.freedesktop.NetworkManager.wifi.scan",
                        "&s", &value))
    return "no";
  return value;
}
} // namespace
bool WifiBackend::Permission(GDBusConnection *bus, GCancellable *cancel) {
  const auto permission = ScanPermission(bus, cancel);
  // "auth" allows a Polkit agent to ask during an explicit RequestScan; it is
  // not a grant. Automatic scanning must never start that authorization path.
  return permission == "yes" || permission == "auth";
}

Snapshot WifiBackend::Read(GDBusConnection *bus, bool scan,
                           GCancellable *cancel, bool interactive) {
  Snapshot snapshot;
  snapshot.completion_id = completion_id_;
  const auto permission = ScanPermission(bus, cancel);
  snapshot.permission =
      permission == "yes" || (interactive && permission == "auth");
  g_autoptr(GVariant) root = Properties(bus, kRoot, kService, cancel);
  snapshot.wifi_enabled =
      Bool(root, "WirelessEnabled") && Bool(root, "WirelessHardwareEnabled");
  const Adapter adapter = SelectAdapter(bus, cancel);
  snapshot.interface_available = !adapter.path.empty();
  if (!snapshot.interface_available) {
    snapshot.status =
        "No WiFi adapter found. Connect a supported adapter and retry.";
    return snapshot;
  }
  if (!snapshot.wifi_enabled) {
    snapshot.status =
        "WiFi radio is off or hardware-blocked. Enable WiFi and retry.";
    return snapshot;
  }
  if (!snapshot.permission) {
    snapshot.status =
        permission == "auth"
            ? "WiFi scanning needs authorization. Select Authorize WiFi to "
              "allow NetworkManager/Polkit scanning."
            : "WiFi scanning denied by NetworkManager policy. Allow WiFi "
              "scanning and retry.";
    return snapshot;
  }
  if (!adapter.ready)
    throw NativeError("adapter_unavailable",
                      "WiFi adapter unavailable or unmanaged. Enable it in "
                      "NetworkManager and retry.");

  g_autoptr(GVariant) wireless =
      Properties(bus, adapter.path, kWireless, cancel);
  const int64_t baseline = LastScan(wireless);
  snapshot.status =
      "Linux scan cache; per-network age and channel width unavailable.";
  if (scan && cadence_.TryStart(ScanCadence::Clock::now())) {
    GVariantBuilder options;
    g_variant_builder_init(&options, G_VARIANT_TYPE("a{sv}"));
    g_autoptr(GVariant) accepted =
        Call(bus, adapter.path, kWireless, "RequestScan",
             g_variant_new("(a{sv})", &options), G_VARIANT_TYPE("()"), cancel,
             interactive);
    (void)accepted;
    const auto deadline = std::chrono::steady_clock::now() +
                          std::chrono::milliseconds(scan_timeout_ms_);
    for (;;) {
      CheckCancelled(cancel);
      g_autoptr(GVariant) updated =
          Properties(bus, adapter.path, kWireless, cancel);
      if (CompletedAfter(baseline, LastScan(updated))) {
        snapshot.completed = true;
        snapshot.status = "NetworkManager scan completed; per-network cache "
                          "age and channel width unavailable.";
        break;
      }
      if (std::chrono::steady_clock::now() >= deadline)
        throw NativeError(
            "scan_timeout",
            "NetworkManager did not report a completed WiFi scan. Cached "
            "results were not added to history. Retry scan.");
      // GDBus honors cancellation; bounded sleep avoids busy-polling LastScan.
      g_usleep(100000);
    }
  } else if (scan) {
    snapshot.status = "Linux scan requested too soon. Showing cache; native "
                      "requests are at least 35 seconds apart.";
  }
  snapshot.radio = radio_reader_(adapter.name, cancel);
  CheckCancelled(cancel);
  // Fetch connected metadata after scan/cache read; a roaming connection may
  // have changed while the request was pending. Never infer from signal alone.
  g_autoptr(GVariant) current =
      Properties(bus, adapter.path, kWireless, cancel);
  const std::string active = String(current, "ActiveAccessPoint", "&o");
  if (active != "/") {
    g_autoptr(GVariant) ap = Properties(
        bus, active, "org.freedesktop.NetworkManager.AccessPoint", cancel);
    std::string bssid = String(ap, "HwAddress");
    std::transform(
        bssid.begin(), bssid.end(), bssid.begin(),
        [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    for (auto &point : snapshot.radio.points)
      point.connected = point.bssid == bssid;
  }
  CheckCancelled(cancel);
  if (snapshot.completed)
    snapshot.completion_id = ++completion_id_;
  if (snapshot.radio.unavailable || snapshot.radio.redacted)
    snapshot.status += " Entries without supported frequency, real dBm or "
                       "valid identifiers excluded.";
  return snapshot;
}
} // namespace wave_wifi
