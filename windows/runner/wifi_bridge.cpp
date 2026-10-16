#include "wifi_bridge.h"

#include <shellapi.h>
#include <winrt/Windows.Security.Authorization.AppCapabilityAccess.h>

#include <algorithm>
#include <cstring>
#include <set>
#include <stdexcept>
#include <utility>
#include <vector>

#include "wifi_encoding.h"

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
using List = flutter::EncodableList;
using Access = winrt::Windows::Security::Authorization::AppCapabilityAccess::
    AppCapabilityAccessStatus;
struct WlanMemory {
  void *value = nullptr;
  ~WlanMemory() {
    if (value)
      WlanFreeMemory(value);
  }
};
struct WlanHandle {
  HANDLE value = nullptr;
  ~WlanHandle() {
    if (value) {
      // Unregister waits for callbacks. No callback can outlive its stack
      // context.
      WlanRegisterNotification(value, WLAN_NOTIFICATION_SOURCE_NONE, TRUE,
                               nullptr, nullptr, nullptr, nullptr);
      WlanCloseHandle(value, nullptr);
    }
  }
};
Access CheckAccess() {
  using winrt::Windows::Security::Authorization::AppCapabilityAccess::
      AppCapability;
  try {
    return AppCapability::Create(L"wiFiControl").CheckAccess();
  } catch (const winrt::hresult_error &error) {
    // AppCapability did not exist before Windows 10 1903. Those versions also
    // predate the protected WLAN APIs. Other failures remain explicit errors.
    if (error.code() == REGDB_E_CLASSNOTREG || error.code() == E_NOINTERFACE)
      return Access::Allowed;
    throw;
  }
}
bool Powered(HANDLE client, const GUID &id, DWORD *query_error) {
  WlanMemory memory;
  DWORD size = 0;
  const DWORD error =
      WlanQueryInterface(client, &id, wlan_intf_opcode_radio_state, nullptr,
                         &size, &memory.value, nullptr);
  *query_error = error;
  if (error != ERROR_SUCCESS)
    return false;
  const auto *radio = static_cast<WLAN_RADIO_STATE *>(memory.value);
  for (DWORD i = 0;
       i < radio->dwNumberOfPhys && i < std::size(radio->PhyRadioState); ++i) {
    const auto &phy = radio->PhyRadioState[i];
    if (phy.dot11SoftwareRadioState == dot11_radio_state_on &&
        phy.dot11HardwareRadioState == dot11_radio_state_on)
      return true;
  }
  return false;
}
std::string Security(const WLAN_CONNECTION_ATTRIBUTES &connection) {
  if (!connection.wlanSecurityAttributes.bSecurityEnabled)
    return "Open";
  switch (connection.wlanSecurityAttributes.dot11AuthAlgorithm) {
  case DOT11_AUTH_ALGO_WPA:
    return "WPA Enterprise";
  case DOT11_AUTH_ALGO_WPA_PSK:
    return "WPA";
  case DOT11_AUTH_ALGO_RSNA:
    return "WPA2 Enterprise";
  case DOT11_AUTH_ALGO_RSNA_PSK:
    return "WPA2";
  default:
    return "Protected (type unavailable)";
  }
}
Map Snapshot(bool permission, bool location, bool wifi, bool available,
             int64_t completion, bool completed, const std::string &status,
             List points = {}, int32_t redacted = 0, int32_t unavailable = 0) {
  return {{Value("source"), Value("windows")},
          {Value("permission"), Value(permission)},
          {Value("locationEnabled"), Value(location)},
          {Value("wifiEnabled"), Value(wifi)},
          {Value("interfaceAvailable"), Value(available)},
          {Value("fresh"), Value(false)},
          {Value("scanRequested"), Value(false)},
          {Value("scanCompleted"), Value(completed)},
          {Value("completionId"), Value(completion)},
          {Value("status"), Value(status)},
          {Value("redactedCount"), Value(redacted)},
          {Value("unavailableCount"), Value(unavailable)},
          {Value("accessPoints"), Value(std::move(points))}};
}
} // namespace

WifiBridge::WifiBridge(flutter::BinaryMessenger *messenger, HWND window)
    : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<Value>>(
      messenger, "com.samirpandey.wifi_analyser/wifi",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto &call, auto result) {
    Handle(call, std::move(result));
  });
}
WifiBridge::~WifiBridge() {
  channel_->SetMethodCallHandler(nullptr);
  Cancel();
  if (worker_.joinable())
    worker_.join();
  // Engine remains alive while completing the outstanding method on teardown.
  if (pending_)
    pending_->Error("cancelled", "WiFi bridge closed");
}
void WifiBridge::Cancel() {
  cancelled_.store(true);
  signal_.changed.notify_all();
}
void WifiBridge::Handle(const flutter::MethodCall<Value> &call,
                        std::unique_ptr<Result> result) {
  const auto &method = call.method_name();
  if (method == "cancelScan") {
    Cancel();
    result->Success();
    return;
  }
  if (method == "haptic") {
    result->Success();
    return;
  }
  if (method == "openSettings") {
    std::string target = "wifi";
    if (const auto *args = call.arguments()) {
      if (const auto *map = std::get_if<Map>(args)) {
        const auto entry = map->find(Value("target"));
        if (entry != map->end())
          if (const auto *text = std::get_if<std::string>(&entry->second))
            target = *text;
      }
    }
    const wchar_t *uri = target == "wifi" ? L"ms-settings:network-wifi"
                                          : L"ms-settings:privacy-location";
    if (reinterpret_cast<INT_PTR>(ShellExecuteW(window_, L"open", uri, nullptr,
                                                nullptr, SW_SHOWNORMAL)) <= 32)
      result->Error("settings_unavailable",
                    "Open Windows Settings, then Network & internet > Wi-Fi or "
                    "Privacy & security > Location.");
    else
      result->Success();
    return;
  }
  if (method != "snapshot" && method != "scan" &&
      method != "requestPermission") {
    result->NotImplemented();
    return;
  }
  if (pending_) {
    result->Error("busy", "Previous Windows WiFi request is still finishing.");
    return;
  }
  if ((method == "scan" || method == "requestPermission") &&
      (GetForegroundWindow() != window_ || IsIconic(window_))) {
    result->Error("cancelled", "Bring Wave to the foreground to access WiFi.");
    return;
  }
  if (worker_.joinable())
    worker_.join();
  cancelled_.store(false);
  pending_ = std::move(result);
  try {
    worker_ = std::thread([this, method] { Run(method); });
  } catch (const std::exception &) {
    auto pending = std::move(pending_);
    pending->Error("native_error",
                   "Windows could not start WiFi worker. Retry.");
  }
}
void WifiBridge::Run(const std::string &operation) {
  auto reply = std::make_unique<Reply>();
  try {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    try {
      *reply = Read(operation);
    } catch (...) {
      winrt::uninit_apartment();
      throw;
    }
    winrt::uninit_apartment();
  } catch (const winrt::hresult_error &error) {
    reply->code = "native_error";
    reply->message = "Windows privacy capability check failed. Retry or check "
                     "Location settings.";
    reply->native_error = static_cast<DWORD>(error.code());
  } catch (const std::exception &error) {
    reply->code = "native_error";
    reply->message = error.what();
  } catch (...) {
    reply->code = "native_error";
    reply->message = "Unexpected Windows WiFi failure.";
  }
  if (cancelled_.load()) {
    reply->code = "cancelled";
    reply->message = "WiFi request cancelled.";
  }
  {
    std::lock_guard<std::mutex> lock(reply_mutex_);
    reply_ = std::move(reply);
  }
  PostMessage(window_, kReplyMessage, 0, 0);
}
void WifiBridge::DrainReply() {
  std::unique_ptr<Reply> reply;
  {
    std::lock_guard<std::mutex> lock(reply_mutex_);
    reply = std::move(reply_);
  }
  if (!reply || !pending_)
    return;
  if (worker_.joinable())
    worker_.join();
  auto pending = std::move(pending_);
  if (cancelled_.load())
    pending->Error("cancelled", "WiFi request cancelled.");
  else if (reply->code.empty())
    pending->Success(reply->value);
  else {
    Value details(Map{{Value("nativeCode"),
                       Value(static_cast<int64_t>(reply->native_error))}});
    pending->Error(reply->code, reply->message, details);
  }
}
void WINAPI WifiBridge::Notification(PWLAN_NOTIFICATION_DATA data,
                                     PVOID context) {
  auto *signal = static_cast<ScanSignal *>(context);
  if (data == nullptr ||
      data->NotificationSource != WLAN_NOTIFICATION_SOURCE_ACM)
    return;
  std::lock_guard<std::mutex> lock(signal->mutex);
  if (!signal->waiting ||
      !IsEqualGUID(data->InterfaceGuid, signal->interface_id))
    return;
  if (data->NotificationCode == wlan_notification_acm_scan_complete)
    signal->completed = true;
  else if (data->NotificationCode == wlan_notification_acm_scan_fail) {
    signal->failed = true;
    if (data->pData && data->dwDataSize >= sizeof(DWORD))
      std::memcpy(&signal->reason, data->pData, sizeof(DWORD));
  } else
    return;
  signal->changed.notify_all();
}

WifiBridge::Reply WifiBridge::Read(const std::string &operation) {
  Reply reply;
  WlanHandle client;
  DWORD negotiated = 0;
  DWORD error = WlanOpenHandle(2, nullptr, &negotiated, &client.value);
  auto failure = [&reply](const char *api, DWORD code) {
    reply.code =
        code == ERROR_ACCESS_DENIED ? "permission_denied" : "native_error";
    reply.message =
        std::string(api) + " failed (Windows error " + std::to_string(code) +
        "). " +
        (code == ERROR_ACCESS_DENIED
             ? "Allow Location access in Windows Settings."
             : "Check WiFi adapter and WLAN AutoConfig service, then retry.");
    reply.native_error = code;
    return reply;
  };
  if (error != ERROR_SUCCESS)
    return failure("WlanOpenHandle", error);
  WlanMemory interfaces_memory;
  error = WlanEnumInterfaces(
      client.value, nullptr,
      reinterpret_cast<PWLAN_INTERFACE_INFO_LIST *>(&interfaces_memory.value));
  if (error != ERROR_SUCCESS)
    return failure("WlanEnumInterfaces", error);
  const auto *interfaces =
      static_cast<WLAN_INTERFACE_INFO_LIST *>(interfaces_memory.value);
  const auto access = CheckAccess();
  bool allowed = access == Access::Allowed;
  // Windows exposes a combined capability decision, not a separate reliable
  // global Location toggle. DeniedBySystem includes policy/system restrictions.
  const bool location = access != Access::DeniedBySystem;
  wave_wifi::AdapterChoice choice;
  std::vector<bool> radio_states;
  DWORD radio_error = ERROR_SUCCESS;
  for (DWORD i = 0; i < interfaces->dwNumberOfItems; ++i) {
    const auto &item = interfaces->InterfaceInfo[i];
    DWORD query_error = ERROR_SUCCESS;
    const bool item_powered =
        Powered(client.value, item.InterfaceGuid, &query_error);
    radio_states.push_back(item_powered);
    if (query_error != ERROR_SUCCESS)
      radio_error = query_error;
    choice.Consider(i, query_error == ERROR_SUCCESS, item_powered,
                    item.isState == wlan_interface_state_connected);
  }
  if (!choice.index() && interfaces->dwNumberOfItems != 0)
    return failure("WlanQueryInterface(radio_state)", radio_error);
  const WLAN_INTERFACE_INFO *selected =
      choice.index() ? &interfaces->InterfaceInfo[*choice.index()] : nullptr;
  const bool powered = choice.index() && radio_states[*choice.index()];
  const bool available = selected != nullptr;
  auto snapshot = [&](const std::string &status, bool completed = false,
                      List points = {}, int32_t redacted = 0,
                      int32_t unavailable = 0) {
    reply.value = Value(Snapshot(allowed, location, powered, available,
                                 completion_id_, completed, status,
                                 std::move(points), redacted, unavailable));
    return reply;
  };
  if (!available) {
    if (operation == "requestPermission") {
      reply.value = Value(false);
      return reply;
    }
    return snapshot("No WiFi adapter available. Connect a supported adapter "
                    "and enable WLAN AutoConfig.");
  }
  if (!powered) {
    if (operation == "requestPermission") {
      reply.value = Value(false);
      return reply;
    }
    return snapshot("WiFi radio is off. Enable WiFi and disable airplane mode "
                    "in Windows Settings.");
  }
  // Startup/cache reads never call an API which could display the one-time
  // Location prompt. Only explicit requestPermission may probe protected
  // access.
  if (!allowed && operation != "requestPermission")
    return snapshot("Allow WiFi/Location access to discover networks. Windows "
                    "may combine user, system and policy restrictions; check "
                    "Privacy & security > Location.");
  bool completed = false;
  std::string status = "Previous Windows WiFi results; per-network observation "
                       "time and freshness are not shown.";
  if (operation == "scan") {
    const auto now = std::chrono::steady_clock::now();
    if (!cadence_.TryStart(now, cancelled_.load())) {
      status = "Windows scans are spaced 35 seconds apart. Previous results "
               "shown; per-network freshness unknown.";
    } else {
      if (cancelled_.load()) {
        reply.code = "cancelled";
        reply.message = "WiFi scan cancelled before start.";
        return reply;
      }
      error = WlanRegisterNotification(
          client.value, WLAN_NOTIFICATION_SOURCE_ACM, TRUE, Notification,
          &signal_, nullptr, nullptr);
      if (error != ERROR_SUCCESS)
        return failure("WlanRegisterNotification", error);
      {
        std::lock_guard<std::mutex> lock(signal_.mutex);
        signal_.interface_id = selected->InterfaceGuid;
        signal_.waiting = true;
        signal_.completed = false;
        signal_.failed = false;
        signal_.reason = 0;
      }
      if (cancelled_.load()) {
        std::lock_guard<std::mutex> lock(signal_.mutex);
        signal_.waiting = false;
        reply.code = "cancelled";
        reply.message = "WiFi scan cancelled before start.";
        return reply;
      }
      error = WlanScan(client.value, &selected->InterfaceGuid, nullptr, nullptr,
                       nullptr);
      if (error != ERROR_SUCCESS) {
        {
          std::lock_guard<std::mutex> lock(signal_.mutex);
          signal_.waiting = false;
        }
        return failure("WlanScan", error);
      }
      {
        std::unique_lock<std::mutex> lock(signal_.mutex);
        signal_.changed.wait_for(lock, std::chrono::seconds(4), [this] {
          return signal_.completed || signal_.failed || cancelled_.load();
        });
        signal_.waiting = false;
        if (cancelled_.load()) {
          reply.code = "cancelled";
          reply.message = "WiFi scan cancelled.";
          return reply;
        }
        if (signal_.failed) {
          reply.code = "scan_failed";
          reply.message = "Windows WiFi scan failed. Check radio and Location "
                          "settings, then retry.";
          reply.native_error = signal_.reason;
          return reply;
        }
        if (!signal_.completed) {
          reply.code = "scan_timeout";
          reply.message =
              "Windows did not report scan completion within 4 seconds. "
              "Previous results retained; retry after current scan finishes.";
          return reply;
        }
      }
      // ACM completion means the interface completed a scan. Notifications
      // carry no application request ID and do not certify each cached BSS as
      // fresh.
      completed = true;
      status = "Windows scan completed. Per-network observation time and cache "
               "freshness are unknown; channel width unavailable.";
    }
  }
  if (cancelled_.load()) {
    reply.code = "cancelled";
    reply.message = "WiFi request cancelled.";
    return reply;
  }
  WlanMemory bss_memory;
  error = WlanGetNetworkBssList(
      client.value, &selected->InterfaceGuid, nullptr, dot11_BSS_type_any,
      FALSE, nullptr, reinterpret_cast<PWLAN_BSS_LIST *>(&bss_memory.value));
  if (operation == "requestPermission") {
    if (error == ERROR_ACCESS_DENIED) {
      reply.value = Value(false);
      return reply;
    }
    if (error != ERROR_SUCCESS)
      return failure("WlanGetNetworkBssList", error);
    reply.value = Value(true);
    return reply;
  }
  if (error != ERROR_SUCCESS)
    return failure("WlanGetNetworkBssList", error);
  WlanMemory connection_memory;
  DWORD size = 0;
  error = WlanQueryInterface(client.value, &selected->InterfaceGuid,
                             wlan_intf_opcode_current_connection, nullptr,
                             &size, &connection_memory.value, nullptr);
  // No connected interface is a normal outcome. Access denial must not leak old
  // identifiers; other connection-query failures remain visible without
  // guessing.
  if (error == ERROR_ACCESS_DENIED)
    return failure("WlanQueryInterface", error);
  const WLAN_CONNECTION_ATTRIBUTES *connection = nullptr;
  if (error == ERROR_SUCCESS && size >= sizeof(WLAN_CONNECTION_ATTRIBUTES))
    connection =
        static_cast<WLAN_CONNECTION_ATTRIBUTES *>(connection_memory.value);
  else if (error != ERROR_INVALID_STATE && error != ERROR_SUCCESS)
    return failure("WlanQueryInterface", error);
  std::string connected_bssid;
  if (connection && connection->isState == wlan_interface_state_connected)
    connected_bssid =
        wave_wifi::Bssid(connection->wlanAssociationAttributes.dot11Bssid);
  List points;
  int32_t redacted = 0, unavailable = 0;
  const auto *list = static_cast<WLAN_BSS_LIST *>(bss_memory.value);
  std::set<std::string> seen;
  for (DWORD i = 0; i < list->dwNumberOfItems; ++i) {
    const auto &bss = list->wlanBssEntries[i];
    const auto bssid = wave_wifi::Bssid(bss.dot11Bssid);
    if (bssid.empty()) {
      ++redacted;
      continue;
    }
    const auto frequency = bss.ulChCenterFrequency / 1000;
    if (bss.dot11Ssid.uSSIDLength > DOT11_SSID_MAX_LENGTH || bss.lRssi > 0 ||
        bss.lRssi < -127 || bss.dot11BssPhyType == dot11_phy_type_fhss ||
        !wave_wifi::SupportedFrequencyKHz(bss.ulChCenterFrequency)) {
      ++unavailable;
      continue;
    }
    if (!seen.insert(bssid).second)
      continue;
    const bool connected = !connected_bssid.empty() && bssid == connected_bssid;
    const std::string security = connected && connection ? Security(*connection)
                                 : (bss.usCapabilityInformation & 0x10) != 0
                                     ? "Protected (type unavailable)"
                                     : "Open";
    points.emplace_back(
        Map{{Value("ssid"), Value(wave_wifi::Ssid(bss.dot11Ssid.ucSSID,
                                                  bss.dot11Ssid.uSSIDLength))},
            {Value("bssid"), Value(bssid)},
            {Value("rssi"), Value(static_cast<int32_t>(bss.lRssi))},
            {Value("frequency"), Value(static_cast<int32_t>(frequency))},
            {Value("width"), Value(int32_t{0})},
            {Value("centerFrequency"), Value()},
            {Value("timestamp"), Value(int64_t{0})},
            {Value("connected"), Value(connected)},
            {Value("security"), Value(security)}});
  }
  if (completed)
    ++completion_id_;
  if (redacted != 0 || unavailable != 0)
    status += " Some redacted or unsupported radio entries excluded.";
  return snapshot(status, completed, std::move(points), redacted, unavailable);
}
