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
- Brief page/chart reveals, animated signal values and channel bars, fresh-scan pulses, hover/focus/press feedback, and smooth theme/detail-sheet transitions. Motion respects device accessibility preferences.
- Three-step Rive welcome with interactive replay, persistent completion, Skip/Back navigation, and Settings replay. Scanning starts after welcome completes.

Device discovery, speed tests, aliases, AI/cloud diagnostics, widgets, and router administration remain future work. iOS/macOS/web native WiFi scanning is not implemented. Flutter builds for those targets use demo mode; they cannot scan nearby networks yet.

## Architecture: MVVM + Riverpod 3.4.3

- `lib/models/access_point.dart`: scan model, frequency/channel conversion, distance, overlap heuristic.
- `lib/models/analyser_state.dart`: immutable view state and typed native snapshots.
- `lib/viewmodels/analyser_view_model.dart`: Riverpod `NotifierProvider`, lifecycle, scan orchestration, preferences and history.
- `lib/repositories/wifi_repository.dart`: typed Android MethodChannel/EventChannel boundary.
- `lib/repositories/settings_repository.dart`: persistence interface and local preferences implementation.
- `lib/widgets/signal_charts.dart`: canvas-based channel and history plots.
- `lib/main.dart` / `lib/app.dart`: bootstrap `ProviderScope` and reactive app theme.
- `lib/views/`: responsive shell, cohesive pages, selective consumers and derived presentation providers.
- `lib/widgets/`: reusable panels, headings, metrics, network tiles/detail sheet, connection card and focused chart painters.
- `lib/repositories/demo_wifi_source.dart`: deterministic simulated scans, separate from hardware and domain models.
- `android/app/src/main/kotlin/com/samirpandey/wifi_analyser/MainActivity.kt`: native `WifiManager` integration.

History accepts only fresh scan timestamps, never relabels cached data as new samples, and holds up to 60 samples per BSSID. Android may throttle manual requests. 35 seconds is a request interval, not a guaranteed hardware refresh rate.

Graphs use reported center frequency for wide channels when available. Envelopes are illustrative, not RF spectral measurements. Channel recommendations are an independent heuristic, not the original app's exact star algorithm. Candidates do not establish regulatory/router availability. 80+80 MHz channels are represented approximately as 160 MHz, without separate lobes.

## AI coding guidance

[AGENTS.md](AGENTS.md) routes agents to focused [architecture rules](ai/rules/flutter-architecture.md) and the project-local [review skill](ai/skills/wave-architecture-review/SKILL.md). The skill stays in `ai/`; no global skill installation is required. Run `ai/scripts/check.sh` for format, analysis and tests, or pass relevant test paths. Set `FLUTTER_BIN` if Flutter is not on PATH or in the documented local FVM location.

Preference edits survive delayed loading; serialized saves show recoverable errors separately from scan status. Signal sliders preview immediately and persist on release. Search text stays synchronized across navigation. Shared filtering/rating providers avoid recomputation for unrelated preferences, and equivalent chart content skips repaint.

See [original review](docs/ARCHITECTURE_REVIEW.md) and [completed fixes](docs/ARCHITECTURE_REVIEW_FOLLOWUP.md) for architecture evidence.

## Verification

```sh
flutter analyze
flutter test
flutter build apk --debug
flutter build web
flutter test integration_test/native_wifi_test.dart -d <android-device-id>
flutter test integration_test/onboarding_test.dart -d <android-device-id>
```

Widget tests cover phone and desktop layouts in both themes, search/details/navigation, and chart width. Analysis tests cover frequency exceptions, connected-AP exclusion, bandwidth overlap, and signal weighting. ViewModel tests check fresh/cached/duplicate timestamps, immutable history, pause behavior, stale in-flight scan responses, and settings persistence. Native integration test checks the Android bridge on an emulator. Physical RF scanning still requires a real Android device; emulator success does not validate real RF measurements.

## Research

See `research/REVERSE_ENGINEERING.md` for APK identity, REA Evidence IDs, verified static findings, reconstruction choices, and remaining unknowns. APKs and raw decompilation outputs stay local and are excluded from Git. REA source clone: `~/Developer/personal/rea`; pinned JADX engine: `~/Developer/personal/rea-tools`.

Installable artifact: `dist/wave-wifi-debug.apk` (regular app entrypoint, preserved separately from integration-test builds).

See [Rive onboarding](docs/RIVE_ONBOARDING.md) for editable artwork, runtime ownership, and native library setup. Keep Flutter/Dart on PATH for Rive's Android build hook. Independent architecture review found no actionable onboarding issues. Physical RF validation remains open.

APK output: `build/app/outputs/flutter-apk/app-debug.apk`. Debug-signed only; production signing is not configured.
