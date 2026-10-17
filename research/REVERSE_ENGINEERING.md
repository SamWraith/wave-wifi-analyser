# WiFi Analyzer 9.4: initial reconstruction findings

Investigation date: 2026-10-12. Tooling: [morluto/rea](https://github.com/morluto/rea), REA CLI 6.4.0 and pinned JADX headless 0.7.1. Followed [REA skill](https://github.com/morluto/rea/blob/main/.agents/skills/reverse-engineer-anything/SKILL.md). No original APK code/assets were copied into Flutter implementation. This is a new implementation of core analysis behavior with a new visual design.

## Target identity

Primary artifact supplied as the user's phone APK:

- Path: `<input-directory>/WiFi_Analyzer_(9.4).apk`
- SHA-256: `719c187524fd83f3db8ea97b09bc5be4b492d64bb50fb5f657e2f049b36ba507`
- Package: `abdelrahman.wifianalyzerpro`
- Version: 9.4, version code 149, min SDK 23, target SDK 36.
- REA evidence: `ev_c5411f3539b77e075126ee9b1383a96442c8aa7d5c26a430933825b234b38b90`, saved in `phone-package.json`.

APKMirror artifact has a different SHA-256 (`2fb8bf81762de09b35773418d34c389887e790ce1388c04b03ce11ad7219fd1d`). Its archive inspection is preserved in `apk-inventory.json`; the phone artifact is the authority for method traces. Different hashes alone do not establish why builds differ.

JADX engine SHA-256: `6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75`, checked against REA's pinned release metadata. Local CLI ran with Node 24 because the default Node 22.12 is below REA's supported version range.

## Verified static findings

| Question | Evidence and observation | Flutter reconstruction |
|---|---|---|
| Which permissions/components exist? | Manifest declares WiFi state/change, precise location, internet, multicast, billing, notification, and widget/service components. `phone-package.json` | Only core scan permissions; no original ad/billing/cloud stack. |
| How does scanning start? | `w2.K()` calls `WifiManager.startScan()`, checks false return, clears in-flight flag, reads connection info. `scanner-trigger.json`, `ev_5c868cf1393a80ab5a8a3d39a9650add93b98c1bc8ca50bef5fc7b8f47f9c757` | MethodChannel request plus scan-result broadcast listener; false return stays explicitly cached. |
| Does cached data get injected? | `w2.D()` reads `getScanResults()` and passes nonempty results to worker. `scanner-start.json`, `ev_4320936f27bb634c3485e0d5b5dcab19fb1e919452fd3aeaa870cc2def036d13` | Startup snapshot may show cached results. Cached data never creates history samples. |
| How is history buffered? | `w2.x(List)` clones AP models, adds snapshot to deque, drops oldest while size >5. `scanner-ingest.json`, `ev_00c05c6d0d814077fc991995aa67f465595b2e602c456eb17a5afab7600bf0dd` | New design retains up to 60 fresh samples per BSSID. This is a deliberate difference, not exact parity. |
| How does distance work? | `s2.h(boolean)` calculates `10^((27.55 - 20*log10(frequencyMHz) + abs(RSSI))/20)`; rounds metres or feet. `distance-model.json`, `ev_5ee02d368a02a2b47947187749ce66f247842ccd69e26dec465bcdac43b36294` | Same standard free-space formula, one-decimal metre display, explicit uncertainty. |
| Which AP fields affect plots? | `s2` constructor stores names/capabilities, RSSI, frequency and width/center inputs; uses separate band mappings. `ap-constructor.json`, `ev_702e7dd388c6d8f81dd9ac06706b044d5501429e5857acbcd58e2158b2a31e98` | Flutter AP model keeps BSSID, SSID, RSSI, primary and center frequency, bandwidth, security. |
| How does graph redraw? | `GraphView.a(ArrayList, WifiInfo)` updates AP list/connection and invalidates. `graph-update.json`, `ev_f51e047e8767fdaf62ede98cce4d4e8126ba8e92d1a63d48a70b270cb7c35d5f` | Controller notifications drive `CustomPainter`. |
| How are APs distinguished? | `GraphView.onDraw()` compares BSSID with connected `WifiInfo`, draws channel envelopes and labels including distance. `graph-draw.json`, `ev_c072621edadfe6fa967218190d1b7be92301a1a6ef10e15335486431152051ca` | Stable color by BSSID, connected label/icon, smooth illustrative envelopes. |
| How are limited permissions represented? | `MainActivity.I3()` switches permission/Location banners and limits tools. `scan-init.json`, `ev_606d3137819aaae2703cbd68a19a88c203a79d1605982daf8faa205774d7b20c` | Actionable permission/Location/WiFi states. No simulated data substituted into live mode. |
| Which extended tools exist? | Manifest/class inventory includes `WiFiDiagnosticsTool`, `WhoisActivity`, `SpeedTestActivity`, `SpeedHistoryActivity`, `SignalTracker`, `RouterSettingsActivity`, `AdvancedSettings`, `AiAnalysisActivity`, and widget receivers. `phone-package.json`, `app-classes.json` | Recorded as future work. Declarations alone do not prove internal behavior. |

Original graph decompilation contains duplicate-block warnings. These traces establish static operations and data flow, not pixel-perfect behavior or numerical equivalence. Model band boundaries are not copied blindly: Flutter handles special channels such as 2484 MHz/channel 14 and 5935 MHz/channel 2 explicitly.

`w2.d.f(ScanResult)` directly maps `SSID`, `BSSID`, `capabilities`, `level`, `frequency`, `channelWidth`, and `centerFreq0` into `s2`, then records WiFi standard on Android 11+. Evidence: `scan-result-map.json`, `ev_1604eba74ae79ce8ca8529331f76517f80bbb24792cde9492698300d14f4e55f`. This verifies the scan-model field mapping rather than inferring it solely from constructor names.

## Behavior corroboration

Publisher's [user guide](https://abdelrahmanmsid.com/WiFiAnalyzerUserGuide.pdf) documents channel/time graphs, New AP vs Connected AP channel ratings, hidden networks, MAC copying, filters, scan interval, aliases, and metre/feet units. [Play listing](https://play.google.com/store/apps/details?id=abdelrahman.wifianalyzerpro) documents additional tools and 2.4/5/6 GHz support. Publisher statements corroborate visible intended behavior; they are not evidence of exact internal algorithms.

[Android scanning documentation](https://developer.android.com/develop/connectivity/wifi/wifi-scan) establishes required permissions/Location services, broadcasts, potentially stale cached results, and scan throttling. Flutter respects these platform constraints.

## Scope and unknowns

This is an initial static investigation and working core app, not a complete reconstruction of all premium tools. The original APK was never executed. Initial REA device probe found no connected Android target (`rea-devices.json`). A local emulator was subsequently started to validate the new app only.

- Original exact channel-star scoring, diagnostic percentages, device discovery, speed endpoints, cloud AI, widget refresh and alert behavior remain untraced.
- Current channel ranking uses independent received-power-weighted overlap. No claims of parity with proprietary scoring.
- Theme/layout are new design choices. Original strings, icons, ads and assets are not shipped in Flutter app.
- APK signatures and equivalence between two supplied artifacts were not verified.
- Native scan bridge is built/tested on Android emulator; physical 2.4/5/6 GHz radio validation remains open.
- iOS/macOS/web live scanning remains unimplemented; those platforms provide explicit demo mode.

## Reproduce focused analysis

```sh
REA_JADX_MCP_JAR="$HOME/Developer/personal/rea-tools/jadx-headless-mcp-0.7.1-all.jar" \
  npx --yes --package=node@24 --package=rea-agents@6.4.0 rea \
  inspect-android-package "$HOME/Downloads/WiFi_Analyzer_(9.4).apk" --format json
```

Use `inspect-android-class` before `inspect-android-method` to choose overloads. `s2.<init>` requires `--overload-index 1` for the seven-argument AP constructor. Full Evidence JSON preserves APK/engine identity and provider limitations. Decompiled text excerpts remain local research outputs, outside application source.

## New-app verification outcome

- `flutter analyze`: no issues.
- Ten unit/widget tests passed, including both themes at 390×844 and 1440×1000, chart width, navigation/search/details, and Riverpod ViewModel state/lifecycle behavior.
- Debug APK and Flutter web build succeeded.
- Native Android bridge integration test passed on a fresh isolated `Wave_WiFi_Test` emulator. Existing `Medium_Phone_API_36.1` initially failed package installation with `INSTALL_FAILED_INSUFFICIENT_STORAGE`; its data was preserved, and an isolated AVD was created instead.
- Emulator test verifies the new app's native channel/state handling, not physical radio discovery. No original APK was executed.
- Modern theme screenshots saved under `previews/`. Local browser preview uses clearly labelled simulated data.
- Final state management: MVVM with Riverpod 3.4.3 `NotifierProvider`, immutable `AnalyserState`, injectable WiFi/settings repository interfaces, and Consumer views.
