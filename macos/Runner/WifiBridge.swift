import Cocoa
import CoreLocation
import CoreWLAN
import FlutterMacOS

/// Foreground-only CoreWLAN boundary. CoreWLAN supplies no per-network sample time,
/// and its blocking scan cannot be cancelled. Generation guards discard late work.
final class WifiBridge: NSObject, CLLocationManagerDelegate {
  private let location = CLLocationManager()
  private let client = CWWiFiClient.shared()
  private let worker = DispatchQueue(label: "wave.wifi.scan", qos: .userInitiated)
  private var channel: FlutterMethodChannel?
  private var permissionReply: FlutterResult?
  private var permissionGeneration: UInt64 = 0
  private var scanReply: FlutterResult?
  private var generation: UInt64 = 0
  private var completionId = 0
  private var workerBusy = false
  private var lastRequest: TimeInterval?
  private var cachedPoints: [[String: Any]] = []
  private var redactedCount = 0
  private var unavailableCount = 0

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    location.delegate = self
    channel = FlutterMethodChannel(
      name: "com.samirpandey.wifi_analyser/wifi", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "cancelled", message: "WiFi bridge closed", details: nil))
        return
      }
      self.handle(call, result: result)
    }
  }

  private var allowed: Bool {
    switch location.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse: return true
    default: return false
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "snapshot": result(snapshot())
    case "scan": scan(result)
    case "cancelScan": cancelScan(); result(nil)
    case "requestPermission": requestPermission(result)
    case "openSettings": openSettings(call, result: result)
    case "haptic":
      // AppKit chooses compatible hardware and honors system feedback settings.
      let arguments = call.arguments as? [String: Any]
      let pattern: NSHapticFeedbackManager.FeedbackPattern =
        arguments?["kind"] as? String == "selection" ? .alignment : .generic
      NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
      result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func wifiInterface() -> CWInterface? {
    let preferred = client.interface()
    let interfaces = (client.interfaces() ?? []).sorted {
      ($0.interfaceName ?? "") < ($1.interfaceName ?? "")
    }
    let selected = Self.selectInterface(preferred: preferred, available: interfaces) { $0.powerOn() }
    return selected
  }

  /// Client's default can be unavailable while another vended interface exists.
  /// Prefer powered hardware, preserving stable name order for fallback selection.
  static func selectInterface<T>(preferred: T?, available: [T], isPowered: (T) -> Bool) -> T? {
    if let preferred, isPowered(preferred) { return preferred }
    return available.first(where: isPowered) ?? preferred ?? available.first
  }

  private func snapshot(message: String? = nil, completed: Bool = false) -> [String: Any] {
    let interface = wifiInterface()
    let locationEnabled = CLLocationManager.locationServicesEnabled()
    let wifiEnabled = interface?.powerOn() == true
    let readable = allowed && locationEnabled && wifiEnabled
    let status: String
    if let message { status = message }
    else if !locationEnabled { status = "Enable Location Services in macOS settings to read WiFi identifiers." }
    else if !allowed { status = "Allow Location access to discover nearby WiFi networks on this Mac." }
    else if interface == nil { status = "No supported WiFi interface is available on this Mac." }
    else if !wifiEnabled { status = "Enable WiFi in macOS settings to scan." }
    else { status = "Ready • previous scan results. macOS does not expose individual observation times." }
    return [
      "source": "macos", "permission": allowed, "locationEnabled": locationEnabled,
      "wifiEnabled": wifiEnabled, "interfaceAvailable": interface != nil,
      "fresh": completed && readable, "scanCompleted": completed && readable,
      "completionId": completionId, "scanRequested": false, "status": status,
      "redactedCount": readable ? redactedCount : 0,
      "unavailableCount": readable ? unavailableCount : 0,
      "accessPoints": readable ? cachedPoints : [],
    ]
  }

  private func requestPermission(_ result: @escaping FlutterResult) {
    guard permissionReply == nil else {
      result(FlutterError(code: "busy", message: "Location permission request already open", details: nil))
      return
    }
    guard CLLocationManager.locationServicesEnabled() else { result(false); return }
    guard location.authorizationStatus == .notDetermined else { result(allowed); return }
    permissionGeneration &+= 1
    let requestGeneration = permissionGeneration
    permissionReply = result
    location.requestWhenInUseAuthorization()
    // A system prompt may remain unanswered. Bound Flutter's pending operation;
    // a later decision still updates authorization and is read on next refresh.
    DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
      guard let self, self.permissionGeneration == requestGeneration,
        let reply = self.permissionReply else { return }
      self.permissionReply = nil
      reply(self.allowed)
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard manager.authorizationStatus != .notDetermined else { return }
    let reply = permissionReply
    permissionReply = nil
    reply?(allowed)
    if !allowed { cachedPoints = []; cancelScan() }
  }

  private func scan(_ result: @escaping FlutterResult) {
    guard NSApplication.shared.isActive else {
      result(FlutterError(code: "cancelled", message: "Bring Wave to the foreground to scan", details: nil))
      return
    }
    guard allowed && CLLocationManager.locationServicesEnabled() else { result(snapshot()); return }
    guard let interface = wifiInterface() else {
      result(snapshot()); return
    }
    guard interface.powerOn() else { result(snapshot()); return }
    guard !workerBusy else {
      result(snapshot(message: "Previous macOS scan is still finishing. Try again shortly.")); return
    }
    let now = ProcessInfo.processInfo.systemUptime
    if let previous = lastRequest, now - previous < 35 {
      result(snapshot(message: "macOS scans are spaced 35 seconds apart. Previous results shown.")); return
    }
    lastRequest = now
    generation &+= 1
    let requestGeneration = generation
    scanReply = result
    workerBusy = true
    worker.async { [weak self] in
      let outcome: Result<EncodedScan, Error>
      do {
        let networks = try interface.scanForNetworks(withName: nil, includeHidden: true)
        outcome = .success(Self.encode(networks, connectedBssid: interface.bssid()))
      } catch { outcome = .failure(error) }
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.workerBusy = false
        guard self.generation == requestGeneration, let reply = self.scanReply else { return }
        self.scanReply = nil
        guard NSApplication.shared.isActive, self.allowed,
          CLLocationManager.locationServicesEnabled(), interface.powerOn() else {
          reply(self.snapshot()); return
        }
        switch outcome {
        case .success(let scan):
          self.cachedPoints = scan.points
          self.redactedCount = scan.redacted
          self.unavailableCount = scan.unavailable
          self.completionId += 1
          var message = "macOS scan completed. Individual observation times and cache freshness are unavailable."
          if scan.redacted > 0 { message += " \(scan.redacted) identifier-redacted results excluded; check Location access." }
          if scan.unavailable > 0 { message += " \(scan.unavailable) results with unsupported radio data excluded." }
          reply(self.snapshot(message: message, completed: true))
        case .failure(let error):
          let native = error as NSError
          reply(FlutterError(code: "scan_failed", message: "macOS WiFi scan failed. Retry or check WiFi and Location settings.",
            details: ["domain": native.domain, "code": native.code]))
        }
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
      guard let self, self.generation == requestGeneration, let reply = self.scanReply else { return }
      self.generation &+= 1
      self.scanReply = nil
      reply(FlutterError(code: "scan_timeout", message: "macOS scan took too long. Retry after the current scan finishes.", details: nil))
    }
  }

  private func cancelScan() {
    generation &+= 1
    let reply = scanReply
    scanReply = nil
    reply?(FlutterError(code: "cancelled", message: "WiFi scan cancelled", details: nil))
  }

  private func openSettings(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any]
    let locationTarget = ["location", "permission"].contains(arguments?["target"] as? String ?? "wifi")
    let address = locationTarget
      ? "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
      : "x-apple.systempreferences:com.apple.wifi-settings-extension"
    guard let url = URL(string: address), NSWorkspace.shared.open(url) else {
      result(FlutterError(code: "settings_unavailable", message: "Open System Settings and choose WiFi or Privacy & Security → Location Services.", details: nil))
      return
    }
    result(nil)
  }

  private struct EncodedScan {
    var points: [[String: Any]] = []
    var redacted = 0
    var unavailable = 0
  }

  private static func encode(_ networks: Set<CWNetwork>, connectedBssid: String?) -> EncodedScan {
    var scan = EncodedScan()
    for network in networks {
      guard let bssid = network.bssid, validBssid(bssid) else { scan.redacted += 1; continue }
      guard let channel = network.wlanChannel, let frequency = frequency(channelNumber: channel.channelNumber, band: channel.channelBand),
        let width = width(channel.channelWidth), (-127...0).contains(network.rssiValue) else {
        scan.unavailable += 1; continue
      }
      scan.points.append([
        "ssid": network.ssid ?? "", "bssid": bssid,
        "rssi": network.rssiValue, "frequency": frequency, "width": width,
        "security": security(network), "connected": bssid.caseInsensitiveCompare(connectedBssid ?? "") == .orderedSame,
        // No CoreWLAN timestamps or bonded center frequency are available.
        "timestamp": 0, "centerFrequency": NSNull(),
      ])
    }
    scan.points.sort { ($0["bssid"] as? String ?? "") < ($1["bssid"] as? String ?? "") }
    return scan
  }

  static func validBssid(_ value: String) -> Bool {
    let parts = value.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 6, parts.allSatisfy({ $0.count == 2 && UInt8($0, radix: 16) != nil }) else { return false }
    return value != "00:00:00:00:00:00" && value.lowercased() != "ff:ff:ff:ff:ff:ff"
  }

  static func frequency(channelNumber number: Int, band: CWChannelBand) -> Int? {
    switch band {
    case .band2GHz: return number == 14 ? 2484 : (1...13).contains(number) ? 2407 + number * 5 : nil
    case .band5GHz: return (1...196).contains(number) ? (number >= 182 ? 4000 : 5000) + number * 5 : nil
    case .band6GHz: return number == 2 ? 5935 : (1...233).contains(number) ? 5950 + number * 5 : nil
    default: return nil
    }
  }

  static func width(_ value: CWChannelWidth) -> Int? {
    switch value {
    case .width20MHz: return 20
    case .width40MHz: return 40
    case .width80MHz: return 80
    case .width160MHz: return 160
    default: return nil
    }
  }

  private static func security(_ network: CWNetwork) -> String {
    if network.supportsSecurity(.wpa3Personal) || network.supportsSecurity(.wpa3Transition) { return "WPA3" }
    if network.supportsSecurity(.wpa3Enterprise) || network.supportsSecurity(.wpa2Enterprise) || network.supportsSecurity(.wpaEnterprise) { return "Enterprise" }
    if network.supportsSecurity(.OWE) || network.supportsSecurity(.oweTransition) { return "Enhanced Open" }
    if network.supportsSecurity(.wpa2Personal) { return "WPA2" }
    if network.supportsSecurity(.wpaPersonal) || network.supportsSecurity(.wpaPersonalMixed) { return "WPA" }
    if network.supportsSecurity(.WEP) || network.supportsSecurity(.dynamicWEP) { return "WEP" }
    if network.supportsSecurity(.none) { return "Open" }
    return "Unknown"
  }
}
