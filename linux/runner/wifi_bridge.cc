#include "wifi_bridge.h"
#include "wifi_backend.h"
#include "wifi_radio.h"

#include <cstring>
#include <memory>
#include <string>

namespace {
using wave_wifi::Snapshot;
void Put(FlValue *map, const char *key, FlValue *value) {
  fl_value_set_string_take(map, key, value);
}
FlValue *Encode(const Snapshot &state) {
  FlValue *map = fl_value_new_map();
  Put(map, "source", fl_value_new_string("linux"));
  Put(map, "permission", fl_value_new_bool(state.permission));
  Put(map, "locationEnabled",
      fl_value_new_bool(true)); // Linux has no location toggle requirement.
  Put(map, "wifiEnabled", fl_value_new_bool(state.wifi_enabled));
  Put(map, "interfaceAvailable", fl_value_new_bool(state.interface_available));
  Put(map, "fresh", fl_value_new_bool(false));
  Put(map, "scanRequested", fl_value_new_bool(false));
  Put(map, "scanCompleted", fl_value_new_bool(state.completed));
  Put(map, "completionId", fl_value_new_int(state.completion_id));
  Put(map, "status", fl_value_new_string(state.status.c_str()));
  Put(map, "redactedCount", fl_value_new_int(state.radio.redacted));
  Put(map, "unavailableCount", fl_value_new_int(state.radio.unavailable));
  FlValue *points = fl_value_new_list();
  for (const auto &point : state.radio.points) {
    FlValue *ap = fl_value_new_map();
    Put(ap, "ssid", fl_value_new_string(point.ssid.c_str()));
    Put(ap, "bssid", fl_value_new_string(point.bssid.c_str()));
    Put(ap, "rssi", fl_value_new_int(point.rssi));
    Put(ap, "frequency", fl_value_new_int(point.frequency));
    Put(ap, "width", fl_value_new_int(0));
    Put(ap, "centerFrequency", fl_value_new_null());
    Put(ap, "timestamp", fl_value_new_int(0));
    Put(ap, "connected", fl_value_new_bool(point.connected));
    Put(ap, "security",
        fl_value_new_string(!point.security_known ? "Unknown"
                            : point.protected_network
                                ? "Protected (type unavailable)"
                                : "Open"));
    fl_value_append_take(points, ap);
  }
  Put(map, "accessPoints", points);
  return map;
}
void Error(FlMethodCall *call, const char *code, const char *message) {
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_error(call, code, message, nullptr, &error))
    g_warning("WiFi bridge reply failed: %s", error->message);
}
void Success(FlMethodCall *call, FlValue *result) {
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_success(call, result, &error))
    g_warning("WiFi bridge reply failed: %s", error->message);
}
struct State {
  wave_wifi::WifiBackend backend{wave_wifi::ReadRadio}; // worker-only
  GCancellable *cancel = nullptr; // main-thread ownership, job owns another ref
  FlMethodCall *pending = nullptr; // main thread only
  bool busy = false;
  bool disposed = false;
  ~State() {
    g_clear_object(&cancel);
    g_clear_object(&pending);
  }
};
struct Job {
  std::shared_ptr<State> state;
  std::string method;
  GCancellable *cancel;
  bool interactive;
  Job(std::shared_ptr<State> state, std::string method, bool interactive)
      : state(std::move(state)), method(std::move(method)),
        cancel(G_CANCELLABLE(g_object_ref(this->state->cancel))),
        interactive(interactive) {}
  ~Job() { g_object_unref(cancel); }
};
struct Reply {
  Snapshot snapshot;
  bool permission = false;
  std::string code;
  std::string message;
};
void Work(GTask *task, gpointer, gpointer task_data, GCancellable *) {
  auto *job = static_cast<Job *>(task_data);
  auto *reply = new Reply;
  try {
    g_autoptr(GError) error = nullptr;
    g_autoptr(GDBusConnection) bus =
        g_bus_get_sync(G_BUS_TYPE_SYSTEM, job->cancel, &error);
    if (!bus)
      throw wave_wifi::NativeError(g_cancellable_is_cancelled(job->cancel)
                                       ? "scan_cancelled"
                                       : "service_unavailable",
                                   "Cannot connect to system D-Bus. Start "
                                   "D-Bus and NetworkManager, then retry.");
    if (job->method == "requestPermission")
      reply->permission = job->state->backend.Permission(bus, job->cancel);
    else
      reply->snapshot = job->state->backend.Read(bus, job->method == "scan",
                                                 job->cancel, job->interactive);
  } catch (const wave_wifi::NativeError &error) {
    reply->code = error.code;
    reply->message = error.what();
  } catch (const std::exception &error) {
    reply->code = "native_error";
    reply->message = error.what();
  }
  g_task_return_pointer(
      task, reply, [](gpointer value) { delete static_cast<Reply *>(value); });
}
void Done(GObject *, GAsyncResult *result, gpointer) {
  auto *task = G_TASK(result);
  auto *job = static_cast<Job *>(g_task_get_task_data(task));
  auto state = job->state;
  std::unique_ptr<Reply> reply(
      static_cast<Reply *>(g_task_propagate_pointer(task, nullptr)));
  state->busy = false;
  g_clear_object(&state->cancel);
  if (state->disposed || !state->pending)
    return;
  if (!reply->code.empty()) {
    Error(state->pending, reply->code.c_str(), reply->message.c_str());
  } else if (job->method == "requestPermission") {
    g_autoptr(FlValue) value = fl_value_new_bool(reply->permission);
    Success(state->pending, value);
  } else {
    g_autoptr(FlValue) value = Encode(reply->snapshot);
    Success(state->pending, value);
  }
  g_clear_object(&state->pending);
}
void Cancel(const std::shared_ptr<State> &state) {
  if (state->cancel)
    g_cancellable_cancel(state->cancel);
  if (state->pending) {
    Error(state->pending, "scan_cancelled", "WiFi request cancelled.");
    g_clear_object(&state->pending);
  }
  // busy remains set until worker exits, preserving backend serialization.
  // Never abort NetworkManager's global scan: other apps may share it.
}
void OpenSettings(FlMethodCall *call) {
  const char *desktop = g_getenv("XDG_CURRENT_DESKTOP");
  const bool kde = desktop && (std::strstr(desktop, "KDE") ||
                               std::strstr(desktop, "Plasma"));
  const char *tools[] = {kde ? "systemsettings" : "gnome-control-center",
                         kde ? "gnome-control-center" : "systemsettings",
                         "nm-connection-editor"};
  for (const char *tool : tools) {
    g_autofree char *executable = g_find_program_in_path(tool);
    if (!executable)
      continue;
    const char *page = g_str_equal(tool, "gnome-control-center") ? "wifi"
                       : g_str_equal(tool, "systemsettings")
                           ? "kcm_networkmanagement"
                           : nullptr;
    gchar *arguments[] = {executable, const_cast<gchar *>(page), nullptr};
    g_autoptr(GError) error = nullptr;
    if (g_spawn_async(nullptr, arguments, nullptr, G_SPAWN_DEFAULT, nullptr,
                      nullptr, nullptr, &error)) {
      Success(call, nullptr);
      return;
    }
  }
  Error(call, "settings_unavailable",
        "Open your desktop's Network settings to enable WiFi. Scanning "
        "authorization is controlled by NetworkManager/Polkit; contact your "
        "system administrator if denied.");
}
struct Bridge {
  FlMethodChannel *channel;
  std::shared_ptr<State> state = std::make_shared<State>();
  explicit Bridge(FlView *view) {
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    channel = fl_method_channel_new(
        fl_engine_get_binary_messenger(fl_view_get_engine(view)),
        "com.samirpandey.wifi_analyser/wifi", FL_METHOD_CODEC(codec));
    fl_method_channel_set_method_call_handler(channel, Handle, this, nullptr);
  }
  ~Bridge() {
    state->disposed = true;
    fl_method_channel_set_method_call_handler(channel, nullptr, nullptr,
                                              nullptr);
    Cancel(state);
    g_object_unref(channel);
  }
  static void Handle(FlMethodChannel *, FlMethodCall *call, gpointer data) {
    auto state = static_cast<Bridge *>(data)->state;
    const std::string method = fl_method_call_get_name(call);
    if (method == "cancelScan") {
      Cancel(state);
      Success(call, nullptr);
    } else if (method == "openSettings") {
      OpenSettings(call);
    } else if (method == "snapshot" || method == "scan" ||
               method == "requestPermission") {
      if (state->busy) {
        Error(call, "scan_in_progress",
              "A Linux WiFi request is already running. Retry after it "
              "finishes.");
        return;
      }
      state->busy = true;
      state->pending = FL_METHOD_CALL(g_object_ref(call));
      state->cancel = g_cancellable_new();
      FlValue *arguments = fl_method_call_get_args(call);
      FlValue *interactive =
          arguments && fl_value_get_type(arguments) == FL_VALUE_TYPE_MAP
              ? fl_value_lookup_string(arguments, "interactive")
              : nullptr;
      const bool allow_auth =
          interactive && fl_value_get_type(interactive) == FL_VALUE_TYPE_BOOL &&
          fl_value_get_bool(interactive);
      auto *job = new Job(state, method, allow_auth);
      g_autoptr(GTask) task = g_task_new(nullptr, state->cancel, Done, nullptr);
      // Completion callback always receives our Reply, including cancellation.
      // Early return-on-cancel would otherwise free state while work still
      // runs.
      g_task_set_check_cancellable(task, false);
      g_task_set_task_data(
          task, job, [](gpointer value) { delete static_cast<Job *>(value); });
      g_task_run_in_thread(task, Work);
    } else {
      g_autoptr(GError) error = nullptr;
      fl_method_call_respond_not_implemented(call, &error);
    }
  }
};
} // namespace
void wave_wifi_bridge_attach(FlView *view) {
  auto *bridge = new Bridge(view);
  g_signal_connect(view, "destroy", G_CALLBACK(+[](GtkWidget *, gpointer data) {
                     delete static_cast<Bridge *>(data);
                   }),
                   bridge);
}
