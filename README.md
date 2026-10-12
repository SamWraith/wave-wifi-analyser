# wave - wifi analyser

A Flutter WiFi analyser with a modern responsive interface, system/light/dark themes, and a native Android WiFi scan bridge. Created in `~/Developer/personal/wave-wifi-analyser`.

## Run

Flutter SDK pinned through FVM: `3.47.5` in `.fvmrc`.

```sh
cd ~/Developer/personal/wave-wifi-analyser
fvm use
fvm flutter pub get
fvm flutter run -d <android-device-id>
```

For desktop exploration: `fvm flutter run -d macos` or `fvm flutter run -d chrome`. These platforms default to clearly labelled simulated data. Android defaults to live data. Tap Scan and grant **precise location**, then ensure WiFi and Android Location services are enabled. No location coordinates are collected.

## Implemented features — 1.0.0

### Overview and WiFi scanning

- Connected access-point card with network name, band, channel, measured signal in dBm, signal quality, advertised security and channel width.
- Nearby-network count, strongest nearby access points, clearest channel candidate and local signal/channel/security insights.
- Android live scans, manual Scan action, automatic scanning and pause/resume. Automatic requests run every 35 seconds while foregrounded; Android determines actual scan availability.
- Permission, Location-off, WiFi-off, throttled/cached, empty and recoverable scan-error states, plus a shortcut to Android WiFi settings.
- Clearly labelled demo mode on every target, with simulated updates every 3 seconds. Backgrounding or pausing stops automatic updates.

### Spectrum, signal history and interactive legends

- Channel landscape showing illustrative signal envelopes from reported frequency, channel width and received power.
- Per-access-point signal history with up to 60 fresh samples per BSSID. Cached or duplicate scan timestamps never become fresh history samples.
- Switch between channel landscape and signal history; filter 2.4 GHz, 5 GHz or 6 GHz bands.
- Tap a WiFi legend name through this cycle: **hide → include again → show only this WiFi → restore all**.
- While one WiFi is isolated, tap another legend name to switch focus. **Show all** resets legend selections anytime.
- Hidden networks stay in the legend. Duplicate network names remain independent through BSSID identity; colors stay tied to BSSID as scan order changes.
- Chart axes and history time range retain all chart input data when curves are hidden, keeping remaining curves in place. Legend filtering does not alter measurements or channel scoring.
- **Overview:** one horizontally scrollable legend row, pinned reset and expand controls, full wrapped list on expansion, and collapse back to the compact row. Selection survives expansion/collapse.
- **Spectrum:** full wrapped legend list. Legend controls work in both chart modes, with keyboard selection and tooltips identifying the access point and next action.

### Networks and access-point details

- Search by network name, strongest-signal-first ordering and a display-only minimum-signal filter.
- Hidden-SSID entries, connected/nearby identification and access-point detail sheets.
- Details include BSSID, signal/quality, frequency, channel/band, width, advertised security and approximate distance.
- Selectable detail values and Copy MAC address with confirmation feedback.
- Search text stays synchronized when navigating between screens.

### Channel planning

- Channel candidates ranked by bandwidth overlap weighted by received power, with relative overlap bars and Clear/Low/Moderate/High labels.
- Option to exclude the connected access point when planning its channel.
- Display filters and legend visibility do not remove scanned access points from scoring. Recommendations are a local heuristic, not measured noise, throughput or regulatory availability.

### Welcome and onboarding

- Three-step welcome with original Rive signal, channel and scan-access scenes.
- Finite animation on scene entry, interactive replay actions, Back/Continue, Skip and Start exploring controls.
- Persisted completion and welcome replay from Settings. Scanning starts after initial welcome completes.
- Background-aware playback, reduced-motion support and stable copy/control slots across steps.

### Appearance, motion and feedback

- Modern responsive phone/desktop layouts with Overview, Spectrum, Networks, Channels and Settings destinations.
- System, light and dark themes with saved theme preference.
- Circular theme reveal growing from the tapped header toggle or Settings theme control, retaining navigation, search and focus state.
- Finite page/chart reveals, animated exact signal values, channel bars, fresh-scan pulses and detail-sheet transitions.
- Mobile selection/impact haptics for supported actions, plus hover/focus/press feedback and accessible standard controls.
- Reduced-motion/accessibility preferences honored by custom motion; stable ordinary scan-status space and onboarding copy reduce unintended layout shifts.
- Android requests the highest advertised refresh mode at the current resolution; iOS ProMotion opt-in is enabled. Sampled theme/Rive motion reached approximately 120 Hz active cadence with touch activity on the tested phone. Constant 120 fps is not qualified; see [measured performance and limits](docs/MOTION_VERIFICATION.md).

### Settings and platform branding

- Saved theme and minimum-signal preferences, immediate slider preview with persistence on release, and separate recoverable preference-error feedback.
- Demo mode, automatic scanning controls, Android WiFi settings shortcut and Replay welcome.
- Original Wave logo with editable SVG master and reproducible platform exports.
- Android adaptive, monochrome/themed, light/night and legacy-density launcher icons; iOS Any/light, Dark and Tinted asset-catalog appearances. Launcher/system appearance controls icon presentation independently of in-app theme. See [branding assets](assets/branding/README.md).

## Platform support and current limits

| Target | Nearby WiFi scanning | Interface/demo support |
| --- | --- | --- |
| Android | Live scan bridge implemented; required permission and WiFi/Location services must be enabled | Yes |
| iOS | Not implemented | Yes, demo data |
| macOS | Not implemented | Yes, demo data |
| Web | Not implemented | Yes, demo data |

No location coordinates are collected. Distance is a free-space estimate and can be inaccurate indoors; chart envelopes are illustrative rather than RF spectrum measurements. Local channel recommendations do not configure routers.

Saved measurement sessions, device discovery, speed tests, network aliases, AI/cloud diagnostics, home-screen widgets and router administration are not included. Potential additions are recommendations, not committed scope; see the [product manager review](docs/PRODUCT_REVIEW.md).

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

[AGENTS.md](AGENTS.md) routes agents to focused [architecture rules](ai/rules/flutter-architecture.md) and the project-local [review skill](ai/skills/wave-architecture-review/SKILL.md). The skill stays in `ai/`; no global skill installation is required. Run `ai/scripts/check.sh` for format, analysis and tests, or pass relevant test paths. The check script prefers `.fvm/flutter_sdk`; set `FLUTTER_BIN` to override it.

Preference edits survive delayed loading; serialized saves show recoverable errors separately from scan status. Signal sliders preview immediately and persist on release. Search text stays synchronized across navigation. Shared filtering/rating providers avoid recomputation for unrelated preferences, and equivalent chart content skips repaint.

See [original review](docs/ARCHITECTURE_REVIEW.md) and [completed fixes](docs/ARCHITECTURE_REVIEW_FOLLOWUP.md) for architecture evidence.

See [motion and display refresh](docs/MOTION_AND_REFRESH.md) for native verification and physical-device 120 fps qualification, and [verification evidence](docs/MOTION_VERIFICATION.md) for completed checks and measured limits. Android requests maximum refresh at the current resolution; iOS enables ProMotion.

## Verification

```sh
ai/scripts/check.sh
fvm flutter build apk --release
fvm flutter build web
fvm flutter test integration_test/native_wifi_test.dart -d <android-device-id>
fvm flutter test integration_test/native_motion_test.dart -d <android-or-ios-device-id>
```

Widget tests cover phone and desktop layouts in both themes, search/details/navigation, chart width, legend hide/include/isolate/reset cycles, duplicate-SSID identity, scan reordering, compact scrolling/expansion at normal and large text scales, and rendered curve visibility. Analysis tests cover frequency exceptions, connected-AP exclusion, bandwidth overlap, and signal weighting. ViewModel tests check fresh/cached/duplicate timestamps, immutable history, pause behavior, stale in-flight scan responses, and settings persistence. Native integration test checks the Android bridge on an emulator. Physical RF scanning still requires a real Android device; emulator success does not validate real RF measurements.

## Research

See `research/REVERSE_ENGINEERING.md` for APK identity, REA Evidence IDs, verified static findings, reconstruction choices, and remaining unknowns. APKs and raw decompilation outputs stay local and are excluded from Git. REA source clone: `~/Developer/personal/rea`; pinned JADX engine: `~/Developer/personal/rea-tools`.

Installable artifact: `dist/wave-wifi-release.apk` (normal app entry point, preserved separately from integration-test builds).

[Original platform branding](assets/branding/README.md) includes editable SVG, Android adaptive/themed/night icons, and iOS Any/Dark/Tinted appearances.

See [Rive onboarding](docs/RIVE_ONBOARDING.md) for editable artwork, runtime ownership, and native library setup. Keep Flutter/Dart on PATH for Rive's Android build hook. Independent architecture review found no actionable onboarding issues. Physical RF validation remains open.

APK output: `build/app/outputs/flutter-apk/app-release.apk`. Release mode currently uses development signing; production signing is not configured.
