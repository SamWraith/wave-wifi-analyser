import CoreWLAN
import Security
import XCTest
@testable import wifi_analyser

final class RunnerTests: XCTestCase {
  func testHostRetainsRequiredWifiSandboxCapabilities() throws {
    var code: SecCode?
    XCTAssertEqual(SecCodeCopySelf([], &code), errSecSuccess)
    let host = try XCTUnwrap(code)
    var staticCode: SecStaticCode?
    XCTAssertEqual(SecCodeCopyStaticCode(host, [], &staticCode), errSecSuccess)
    let signedHost = try XCTUnwrap(staticCode)
    var information: CFDictionary?
    XCTAssertEqual(
      SecCodeCopySigningInformation(signedHost, SecCSFlags(rawValue: kSecCSSigningInformation), &information),
      errSecSuccess)
    let dictionary = try XCTUnwrap(information as? [String: Any])
    let entitlements = try XCTUnwrap(dictionary[kSecCodeInfoEntitlementsDict as String] as? [String: Any])
    for capability in [
      "com.apple.security.app-sandbox",
      "com.apple.security.personal-information.location",
      "com.apple.security.network.client",
    ] {
      XCTAssertEqual(entitlements[capability] as? Bool, true, "Missing signed capability: \(capability)")
    }
  }

  func testInterfaceFallbackUsesPoweredVendedInterface() {
    let powered = { (value: Int) in value == 2 }
    XCTAssertEqual(WifiBridge.selectInterface(preferred: nil, available: [1, 2], isPowered: powered), 2)
    XCTAssertEqual(WifiBridge.selectInterface(preferred: 1, available: [1, 2], isPowered: powered), 2)
    XCTAssertEqual(WifiBridge.selectInterface(preferred: 2, available: [1, 2], isPowered: powered), 2)
    XCTAssertEqual(WifiBridge.selectInterface(preferred: 1, available: [1], isPowered: powered), 1)
    XCTAssertNil(WifiBridge.selectInterface(preferred: nil, available: [Int](), isPowered: powered))
  }

  func testUnavailableIdentifiersNeverBecomeIdentity() {
    XCTAssertFalse(WifiBridge.validBssid(""))
    XCTAssertFalse(WifiBridge.validBssid("<redacted>"))
    XCTAssertFalse(WifiBridge.validBssid("00:00:00:00:00:00"))
    XCTAssertFalse(WifiBridge.validBssid("FF:FF:FF:FF:FF:FF"))
    XCTAssertFalse(WifiBridge.validBssid("12:34:56:78:90:xyz"))
    XCTAssertTrue(WifiBridge.validBssid("12:34:56:78:90:AB"))
  }

  func testReportedRadioGeometryAndUnknowns() {
    XCTAssertEqual(WifiBridge.frequency(channelNumber: 14, band: .band2GHz), 2484)
    XCTAssertEqual(WifiBridge.frequency(channelNumber: 36, band: .band5GHz), 5180)
    XCTAssertEqual(WifiBridge.frequency(channelNumber: 184, band: .band5GHz), 4920)
    XCTAssertEqual(WifiBridge.frequency(channelNumber: 2, band: .band6GHz), 5935)
    XCTAssertEqual(WifiBridge.frequency(channelNumber: 233, band: .band6GHz), 7115)
    XCTAssertNil(WifiBridge.frequency(channelNumber: 0, band: .band2GHz))
    XCTAssertNil(WifiBridge.frequency(channelNumber: 1, band: .bandUnknown))
    XCTAssertEqual(WifiBridge.width(.width160MHz), 160)
    XCTAssertNil(WifiBridge.width(.widthUnknown))
  }
}
