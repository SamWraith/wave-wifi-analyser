# wave - wifi analyser

A Flutter WiFi analyser with a modern responsive interface, system/light/dark themes, and a native Android WiFi scan bridge. Created in `~/Developer/personal/wifi_analyser`.

## Run

Flutter SDK used: `/Users/samirpandey/fvm/versions/3.47.5`.

```sh
cd ~/Developer/personal/wifi_analyser
/Users/samirpandey/fvm/versions/3.47.5/bin/flutter pub get
/Users/samirpandey/fvm/versions/3.47.5/bin/flutter run -d <android-device-id>
```

For desktop exploration: `flutter run -d macos` or `flutter run -d chrome`. These platforms default to clearly labelled simulated data. Android defaults to live data. Tap Scan and grant **precise location**, then ensure WiFi and Android Location services are enabled. No location coordinates are collected.

## Included in 1.0.0

- Overview with connected AP, signal quality, advertised security, and bandwidth.
- Channel overlap graph and per-AP signal history, with 2.4/5/6 GHz filters.
- Access-point search, signal sorting, hidden SSIDs, detail sheet, and MAC copying.
- Channel candidates ranked by bandwidth overlap weighted by received power.
- Approximate free-space distance, labelled as an estimate.
- Display signal threshold, scan pause/resume, and persistent theme selection.
- Android permission, Location-off, WiFi-off, throttled/cached, and empty states.
- Foreground-only scan requests every 35 seconds; fresh broadcasts update data.
- Explicit demo mode for exploring UI without Android hardware.

Device discovery, speed tests, aliases, AI/cloud diagnostics, widgets, and router administration remain future work. iOS/macOS/web native WiFi scanning is not implemented. Flutter builds for those targets use demo mode; they cannot scan nearby networks yet.

## Architecture: MVVM + Riverpod 3.4.3

- `lib/models/access_point.dart`: scan model, frequency/channel conversion, distance, overlap heuristic.
- `lib/models/analyser_state.dart`: immutable view state and typed native snapshots.
- `lib/viewmodels/analyser_view_model.dart`: Riverpod `NotifierProvider`, lifecycle, scanning, filtering and history.
- `lib/repositories/wifi_repository.dart`: typed Android MethodChannel/EventChannel boundary.
- `lib/repositories/settings_repository.dart`: persistence interface and local preferences implementation.
- `lib/widgets/signal_charts.dart`: canvas-based channel and history plots.
- `lib/main.dart` / `lib/app.dart`: bootstrap `ProviderScope` and reactive app theme.
- `lib/views/`: responsive navigation, screens, themes, and detail sheet.
- `android/app/src/main/kotlin/com/samirpandey/wifi_analyser/MainActivity.kt`: native `WifiManager` integration.

History accepts only fresh scan timestamps, never relabels cached data as new samples, and holds up to 60 samples per BSSID. Android may throttle manual requests. 35 seconds is a request interval, not a guaranteed hardware refresh rate.

Graphs use reported center frequency for wide channels when available. Envelopes are illustrative, not RF spectral measurements. Channel recommendations are an independent heuristic, not the original app's exact star algorithm. Candidates do not establish regulatory/router availability. 80+80 MHz channels are represented approximately as 160 MHz, without separate lobes.

## Verification

```sh
flutter analyze
flutter test
flutter build apk --debug
flutter build web
flutter test integration_test/native_wifi_test.dart -d <android-device-id>
```

Widget tests cover phone and desktop layouts in both themes, search/details/navigation, and chart width. Analysis tests cover frequency exceptions, connected-AP exclusion, bandwidth overlap, and signal weighting. ViewModel tests check fresh/cached/duplicate timestamps, immutable history, pause behavior, stale in-flight scan responses, and settings persistence. Native integration test checks the Android bridge on an emulator. Physical RF scanning still requires a real Android device; emulator success does not validate real RF measurements.

## Research

See `research/REVERSE_ENGINEERING.md` for APK identity, REA Evidence IDs, verified static findings, reconstruction choices, and remaining unknowns. APKs and raw decompilation outputs stay local and are excluded from Git. REA source clone: `~/Developer/personal/rea`; pinned JADX engine: `~/Developer/personal/rea-tools`.

Installable artifact: `dist/wave-wifi-debug.apk` (regular app entrypoint, preserved separately from integration-test builds).

Verified: `flutter analyze` clean, 10 unit/widget tests passed, Android bridge integration test passed on isolated `Wave_WiFi_Test` emulator, debug APK and web builds succeeded. Physical RF validation remains open.

APK output: `build/app/outputs/flutter-apk/app-debug.apk`. Debug-signed only; production signing is not configured.
