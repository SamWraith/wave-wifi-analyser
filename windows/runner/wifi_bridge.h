#ifndef RUNNER_WIFI_BRIDGE_H_
#define RUNNER_WIFI_BRIDGE_H_

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <wlanapi.h>

#include "wifi_scan_policy.h"
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <memory>
#include <mutex>
#include <thread>

// One owned worker, one native handle per operation. All Flutter replies return
// on the platform thread via the runner's window procedure.
class WifiBridge {
public:
  static constexpr UINT kReplyMessage = WM_APP + 71;
  WifiBridge(flutter::BinaryMessenger *messenger, HWND window);
  ~WifiBridge();
  void DrainReply();
  void Cancel();

private:
  using Value = flutter::EncodableValue;
  using Result = flutter::MethodResult<Value>;
  struct Reply {
    Value value;
    std::string code;
    std::string message;
    DWORD native_error = ERROR_SUCCESS;
  };
  struct ScanSignal {
    std::mutex mutex;
    std::condition_variable changed;
    GUID interface_id{};
    bool waiting = false;
    bool completed = false;
    bool failed = false;
    DWORD reason = 0;
  };
  void Handle(const flutter::MethodCall<Value> &call,
              std::unique_ptr<Result> result);
  void Run(const std::string &operation);
  Reply Read(const std::string &operation);
  static void WINAPI Notification(PWLAN_NOTIFICATION_DATA data, PVOID context);

  HWND window_;
  std::unique_ptr<flutter::MethodChannel<Value>> channel_;
  std::unique_ptr<Result> pending_; // Platform thread only.
  std::thread worker_;
  std::atomic<bool> cancelled_{false};
  ScanSignal signal_;
  std::mutex reply_mutex_;
  std::unique_ptr<Reply> reply_;
  wave_wifi::ScanCadence cadence_; // Worker only.
  int64_t completion_id_ = 0;
};
#endif
