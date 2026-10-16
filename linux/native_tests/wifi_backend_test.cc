#include "wifi_backend.h"

#include <atomic>
#include <condition_variable>
#include <future>
#include <iostream>
#include <mutex>
#include <thread>

namespace {
constexpr const char *kRoot = "/org/freedesktop/NetworkManager";
constexpr const char *kDevice = "/org/freedesktop/NetworkManager/Devices/1";
constexpr const char *kBroken = "/org/freedesktop/NetworkManager/Devices/0";
constexpr const char *kAp = "/org/freedesktop/NetworkManager/AccessPoint/1";
void Check(bool value, const char *message) {
  if (!value)
    throw std::runtime_error(message);
}
const char *kXml = R"XML(<node>
<interface name='org.freedesktop.DBus.Properties'><method name='GetAll'><arg type='s' direction='in'/><arg type='a{sv}' direction='out'/></method></interface>
<interface name='org.freedesktop.NetworkManager'><method name='GetDevices'><arg type='ao' direction='out'/></method><method name='GetPermissions'><arg type='a{ss}' direction='out'/></method></interface>
<interface name='org.freedesktop.NetworkManager.Device.Wireless'><method name='RequestScan'><arg type='a{sv}' direction='in'/></method></interface>
</node>)XML";
class FakeNetworkManager {
public:
  std::atomic<bool> wifi{true};
  std::atomic<bool> hardware{true};
  std::atomic<bool> adapters{true};
  std::atomic<bool> complete{true};
  std::atomic<bool> deny{false};
  std::atomic<bool> missing_last_scan{false};
  std::atomic<int> permission{1}; // no / yes / auth
  std::atomic<int> requests{0};
  std::atomic<bool> interactive{false};
  std::atomic<int64_t> last_scan{100};
  GDBusConnection *client = nullptr;
  FakeNetworkManager() {
    bus_ = g_test_dbus_new(G_TEST_DBUS_NONE);
    g_test_dbus_up(bus_);
    std::promise<void> ready;
    auto future = ready.get_future();
    server_ = std::thread([this, &ready] {
      context_ = g_main_context_new();
      g_main_context_push_thread_default(context_);
      loop_ = g_main_loop_new(context_, false);
      GDBusConnection *connection = Connect();
      g_autoptr(GVariant) name = g_dbus_connection_call_sync(
          connection, "org.freedesktop.DBus", "/org/freedesktop/DBus",
          "org.freedesktop.DBus", "RequestName",
          g_variant_new("(su)", "org.freedesktop.NetworkManager", 0u),
          G_VARIANT_TYPE("(u)"), G_DBUS_CALL_FLAGS_NONE, 1000, nullptr,
          nullptr);
      g_autoptr(GDBusNodeInfo) info =
          g_dbus_node_info_new_for_xml(kXml, nullptr);
      static const GDBusInterfaceVTable table = {
          Invoke, nullptr, nullptr, {nullptr}};
      for (const char *path : {kRoot, kDevice, kBroken, kAp}) {
        g_dbus_connection_register_object(connection, path, info->interfaces[0],
                                          &table, this, nullptr, nullptr);
      }
      g_dbus_connection_register_object(connection, kRoot, info->interfaces[1],
                                        &table, this, nullptr, nullptr);
      g_dbus_connection_register_object(connection, kDevice,
                                        info->interfaces[2], &table, this,
                                        nullptr, nullptr);
      ready.set_value();
      g_main_loop_run(loop_);
      g_dbus_connection_close_sync(connection, nullptr, nullptr);
      g_object_unref(connection);
      g_main_loop_unref(loop_);
      g_main_context_pop_thread_default(context_);
      g_main_context_unref(context_);
    });
    future.get();
    client = Connect();
  }
  ~FakeNetworkManager() {
    g_dbus_connection_close_sync(client, nullptr, nullptr);
    g_object_unref(client);
    g_main_context_invoke(
        context_,
        +[](gpointer data) -> gboolean {
          g_main_loop_quit(static_cast<FakeNetworkManager *>(data)->loop_);
          return G_SOURCE_REMOVE;
        },
        this);
    server_.join();
    g_test_dbus_down(bus_);
    g_object_unref(bus_);
  }
  bool WaitForRequest(int count) {
    std::unique_lock<std::mutex> lock(mutex_);
    return condition_.wait_for(lock, std::chrono::seconds(2),
                               [&] { return requests >= count; });
  }

private:
  GTestDBus *bus_;
  GMainContext *context_ = nullptr;
  GMainLoop *loop_ = nullptr;
  std::thread server_;
  std::mutex mutex_;
  std::condition_variable condition_;
  GDBusConnection *Connect() {
    g_autoptr(GError) error = nullptr;
    auto *connection = g_dbus_connection_new_for_address_sync(
        g_test_dbus_get_bus_address(bus_),
        static_cast<GDBusConnectionFlags>(
            G_DBUS_CONNECTION_FLAGS_AUTHENTICATION_CLIENT |
            G_DBUS_CONNECTION_FLAGS_MESSAGE_BUS_CONNECTION),
        nullptr, nullptr, &error);
    if (!connection)
      throw std::runtime_error(error->message);
    return connection;
  }
  static void Add(GVariantBuilder *map, const char *key, GVariant *value) {
    g_variant_builder_add(map, "{sv}", key, value);
  }
  static void Invoke(GDBusConnection *, const gchar *, const gchar *path,
                     const gchar *, const gchar *method, GVariant *arguments,
                     GDBusMethodInvocation *invocation, gpointer data) {
    auto *self = static_cast<FakeNetworkManager *>(data);
    if (g_str_equal(method, "GetDevices")) {
      GVariantBuilder paths;
      g_variant_builder_init(&paths, G_VARIANT_TYPE("ao"));
      if (self->adapters) {
        g_variant_builder_add(&paths, "o", kBroken);
        g_variant_builder_add(&paths, "o", kDevice);
      }
      g_dbus_method_invocation_return_value(invocation,
                                            g_variant_new("(ao)", &paths));
      return;
    }
    if (g_str_equal(method, "GetPermissions")) {
      GVariantBuilder map;
      g_variant_builder_init(&map, G_VARIANT_TYPE("a{ss}"));
      const int permission = self->permission;
      g_variant_builder_add(&map, "{ss}",
                            "org.freedesktop.NetworkManager.wifi.scan",
                            permission == 1   ? "yes"
                            : permission == 2 ? "auth"
                                              : "no");
      g_dbus_method_invocation_return_value(invocation,
                                            g_variant_new("(a{ss})", &map));
      return;
    }
    if (g_str_equal(method, "RequestScan")) {
      const auto flags = g_dbus_message_get_flags(
          g_dbus_method_invocation_get_message(invocation));
      self->interactive =
          (flags & G_DBUS_MESSAGE_FLAGS_ALLOW_INTERACTIVE_AUTHORIZATION) != 0;
      {
        std::lock_guard<std::mutex> lock(self->mutex_);
        ++self->requests;
      }
      self->condition_.notify_all();
      if (self->deny) {
        g_dbus_method_invocation_return_dbus_error(
            invocation, "org.freedesktop.NetworkManager.Device.NotAuthorized",
            "Wi-Fi scan not authorized");
        return;
      }
      if (self->complete)
        ++self->last_scan;
      g_dbus_method_invocation_return_value(invocation, g_variant_new("()"));
      return;
    }
    const char *interface_name;
    g_variant_get(arguments, "(&s)", &interface_name);
    if (g_str_equal(path, kBroken)) {
      g_dbus_method_invocation_return_dbus_error(
          invocation, "org.freedesktop.DBus.Error.UnknownObject",
          "Adapter disappeared");
      return;
    }
    GVariantBuilder map;
    g_variant_builder_init(&map, G_VARIANT_TYPE("a{sv}"));
    if (g_str_equal(path, kRoot)) {
      Add(&map, "WirelessEnabled", g_variant_new_boolean(self->wifi));
      Add(&map, "WirelessHardwareEnabled",
          g_variant_new_boolean(self->hardware));
    } else if (g_str_equal(path, kAp)) {
      Add(&map, "HwAddress", g_variant_new_string("02:13:24:35:46:AB"));
    } else if (g_str_equal(interface_name,
                           "org.freedesktop.NetworkManager.Device")) {
      Add(&map, "DeviceType", g_variant_new_uint32(2));
      Add(&map, "State", g_variant_new_uint32(100));
      Add(&map, "Managed", g_variant_new_boolean(true));
      Add(&map, "FirmwareMissing", g_variant_new_boolean(false));
      Add(&map, "Interface", g_variant_new_string("test-wlan"));
    } else {
      if (!self->missing_last_scan)
        Add(&map, "LastScan", g_variant_new_int64(self->last_scan));
      Add(&map, "ActiveAccessPoint", g_variant_new_object_path(kAp));
    }
    g_dbus_method_invocation_return_value(invocation,
                                          g_variant_new("(a{sv})", &map));
  }
};
template <typename Action> void Expect(const char *code, Action action) {
  try {
    action();
  } catch (const wave_wifi::NativeError &error) {
    Check(error.code == code, error.what());
    return;
  }
  throw std::runtime_error(std::string("Expected error: ") + code);
}
} // namespace
int main(int argc, char **argv) {
  g_test_init(&argc, &argv, nullptr);
  try {
    FakeNetworkManager server;
    g_autoptr(GCancellable) cancel = g_cancellable_new();
    int reads = 0;
    auto radio = [&](const std::string &name, GCancellable *) {
      Check(name == "test-wlan", "unhealthy adapter chosen");
      ++reads;
      wave_wifi::RadioResults results;
      results.points.push_back(
          {"Wave", "02:13:24:35:46:ab", -51, 5180, true, true, false});
      return results;
    };
    wave_wifi::WifiBackend backend(radio, 0);
    auto cached = backend.Read(server.client, false, cancel);
    Check(cached.interface_available && cached.permission &&
              cached.wifi_enabled && !cached.completed &&
              cached.completion_id == 0 && cached.radio.points[0].connected,
          "cache read incorrectly counted or connection metadata wrong");
    auto scanned = backend.Read(server.client, true, cancel);
    Check(scanned.completed && scanned.completion_id == 1 &&
              server.requests == 1,
          "completed scan not accepted");
    Check(!server.interactive,
          "automatic scan attempted interactive Polkit auth");
    auto limited = backend.Read(server.client, true, cancel);
    Check(!limited.completed && limited.completion_id == 1 &&
              server.requests == 1,
          "native cadence bypass/history duplicate");
    server.wifi = false;
    Check(!backend.Read(server.client, true, cancel).wifi_enabled &&
              server.requests == 1,
          "radio off triggered scan");
    server.wifi = true;
    server.hardware = false;
    Check(!backend.Read(server.client, true, cancel).wifi_enabled,
          "hardware radio block ignored");
    server.hardware = true;
    server.adapters = false;
    Check(!backend.Read(server.client, true, cancel).interface_available,
          "missing adapter invented");
    server.adapters = true;
    server.permission = 0;
    auto denied = backend.Read(server.client, true, cancel);
    Check(!denied.permission && denied.radio.points.empty(),
          "denial leaked cached networks");
    server.permission = 2;
    Check(backend.Permission(server.client, cancel),
          "Polkit auth option not exposed");
    wave_wifi::WifiBackend auth_backend(radio, 0);
    const int auth_before = server.requests;
    auto auth_needed = auth_backend.Read(server.client, true, cancel);
    Check(!auth_needed.permission && auth_needed.radio.points.empty() &&
              server.requests == auth_before,
          "automatic scan entered Polkit authorization path");
    auto auth_allowed = auth_backend.Read(server.client, true, cancel, true);
    Check(auth_allowed.permission && auth_allowed.completed &&
              server.requests == auth_before + 1 && server.interactive,
          "explicit scan did not enter interactive authorization path");
    server.deny = true;
    wave_wifi::WifiBackend denied_backend(radio, 0);
    Expect("permission_denied",
           [&] { denied_backend.Read(server.client, true, cancel, true); });
    Check(server.interactive,
          "manual authorized scan did not permit Polkit prompt");
    server.deny = false;
    server.permission = 1;
    server.complete = false;
    wave_wifi::WifiBackend timeout(radio, 0);
    const int before = reads;
    Expect("scan_timeout", [&] { timeout.Read(server.client, true, cancel); });
    Check(reads == before, "timeout added cached observation");
    server.missing_last_scan = true;
    Expect("unsupported_service",
           [&] { timeout.Read(server.client, false, cancel); });
    server.missing_last_scan = false;
    wave_wifi::WifiBackend waiting(radio, 12000);
    const int next = server.requests + 1;
    auto operation = std::async(std::launch::async, [&] {
      Expect("scan_cancelled",
             [&] { waiting.Read(server.client, true, cancel); });
    });
    Check(server.WaitForRequest(next), "scan never reached NetworkManager");
    g_cancellable_cancel(cancel);
    Check(operation.wait_for(std::chrono::seconds(2)) ==
              std::future_status::ready,
          "cancel did not stop pending request");
    operation.get();
    std::cout << "NetworkManager D-Bus scan, cache, policy, adapter, timeout "
                 "and cancellation tests passed\n";
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
