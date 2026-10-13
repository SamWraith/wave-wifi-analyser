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
- Permission, Location-off, WiFi-off, throttled/cached, empty and recoverable scan-error states. Contextual shortcuts request precise location or open Android app permissions, Location or WiFi settings.
- Visible last-fresh-result age, pending/cached/paused labels and separate simulated-update age. Older observations are marked after two minutes; presentation clocks never add history or promise a next scan.
- Clearly labelled demo mode on every target, with simulated updates every 3 seconds. Backgrounding or pausing stops automatic updates.

### Guided Improve my WiFi

- Overview opens an on-device guide for weak signal or crowded channel.
- Captures a fresh connected-AP baseline, shows RSSI/band/channel/width and relative overlap evidence, suggests one action, then requests a recheck.
- Compares only newer observations of the same BSSID. Cached/duplicate results cannot complete a recheck; changing access points requires a new check.
- Demo, paused, missing-connected-AP, empty and older-than-two-minute data explain why a live comparison cannot start. Scan recovery controls remain available inside the guide.
- Uses the connected band and full scan regardless of display filters. Guidance does not diagnose interference, ISP trouble or router failure, measure speed, or configure routers.
- Baselines exist only while the guide is open; these are single-observation checks, not saved sessions or proof of lasting improvement.

### Spectrum, signal history and interactive legends

- Channel landscape showing illustrative signal envelopes from reported frequency, channel width and received power.
- **Open Spectrum** on Overview carries band, graph mode and legend selection into Spectrum.
- **Focus chart** opens a larger chart with scan freshness, band controls and legends. Close, Back or Escape returns to the same Spectrum scroll position and selection; no forced orientation.
- Tap or drag horizontally to follow visible envelope curves or recorded history samples in normal or focused charts. Markers stay on plotted data, with network name/BSSID and frequency/channel or observation time plus dBm. Vertical gestures scroll the page; pointer hover and focused arrow keys provide alternatives. Dismiss clears inspection.
- Landscape readouts explicitly label illustrative envelope values; history snaps only to recorded samples and shows their actual timestamps. Hidden curves cannot be selected. Exceptional channels use their correct centers, with nearby coordinates qualified as **Near CH**. History only plots retained observations and breaks lines across missing observations or gaps longer than two foreground scan intervals.
- Per-access-point signal history with up to 60 fresh samples per BSSID. Cached or duplicate scan timestamps never become fresh history samples.
- Switch between channel landscape and signal history; filter 2.4 GHz, 5 GHz or 6 GHz bands.
- Tap a WiFi legend name through this cycle: **hide → include again → show only this WiFi → restore all**.
- While one WiFi is isolated, tap another legend name to switch focus. **Show all** resets legend selections anytime.
- Hidden networks stay in the legend. Duplicate network names remain independent through BSSID identity; colors stay tied to BSSID as scan order changes.
- Chart axes and history time range retain all chart input data when curves are hidden, keeping remaining curves in place. Legend filtering does not alter measurements or channel scoring.
- **Overview:** one horizontally scrollable legend row, pinned reset and expand controls, full wrapped list on expansion, and collapse back to the compact row. Selection survives expansion/collapse.
- **Spectrum:** full wrapped legend list. Legend controls work in both chart modes, with keyboard selection and tooltips identifying the access point and next action.

### Networks and access-point details

- Search by original SSID, local alias or BSSID, strongest-signal-first ordering and a display-only minimum-signal filter.
- Add/remove favorites and add/edit/remove local aliases from access-point details. Aliases appear alongside original SSIDs in Networks and chart legends; channel and BSSID context distinguishes same-SSID APs.
- Favorites remain pinned in a dedicated Networks section across all bands, search and signal filters. A separate Saved aliases section keeps alias-only APs manageable even when absent. Missing saved APs show **Not seen** with saved identity only; no invented signal, channel, history or timestamp.
- Preferences persist by BSSID across scans, reorder and relaunch, capped at 256 saved AP identities and 64 characters per alias. Versioned local storage preserves early edits during loading, serializes writes and exposes separate retry feedback for load/save failures. No extra permissions or services.
- Hidden-SSID entries, connected/nearby identification and access-point detail sheets.
- Details include BSSID, signal/quality, frequency, channel/band, width, advertised security and approximate distance.
- Selectable detail values adapt to narrow screens and large text; Copy MAC address gives confirmation feedback.
- Search text stays synchronized when navigating between screens.

### Saved room comparisons

- **Compare rooms** on Overview opens a foreground recording for one BSSID, with an optional manual room/session label. Favorites and aliases help identify APs; original SSID, full BSSID and radio context remain visible.
- Start waits for new observations; cached/duplicate native timestamps, chart visibility and existing history never add samples. Recordings report missing-AP updates and updates without fresh data. Demo sessions stay explicitly simulated and cannot compare with measured sessions.
- Stop saves locally; discard cancels. Pause, leaving the foreground or changing data source ends and saves with a reason. Resume never restarts recording. Relaunch restores completed sessions; forced termination may lose an unfinished recording or pending save.
- Select two or more sessions for the same BSSID/source. Each band/channel/primary frequency/width/center-frequency context shows sample count, observation time range, median RSSI and RSSI range separately. Median delta appears only when every selected session has one identical context; stronger signal is not proof of faster WiFi.
- Gaps remain visible: initial wait, longest interval between observations and silence before stop. No interpolated signal samples. Observation times use monotonic elapsed time anchored to recording start, so wall-clock corrections cannot break a saved session.
- Retain up to 24 sessions with 120 fresh samples each; recording stops at the sample cap. Delete records to free space. Labels use a consistent 64 UTF-16-code-unit limit; storage is a validated version 1 envelope capped at 1 MiB. Loading gates recording while preserving entered labels; checked, serialized/coalesced writes expose recoverable storage errors separately from scanning.
- No GPS coordinates, background service, extra permissions, cloud sync, heatmap, export or distance-accuracy claim. See [session verification](docs/SAVED_COMPARISON_SESSIONS.md).

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
- Mobile selection/impact haptics for supported actions, including chart-mode changes, plus hover/focus/press feedback and accessible standard controls. Shared detail/troubleshooting sheet motion honors reduced-motion and accessible-navigation preferences.
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

Device discovery, speed tests, AI/cloud diagnostics, home-screen widgets and router administration are not included. Next authorized Android slices are explainable channel planning and private comparison export/share; afterward, native macOS scanning. Windows/Linux/iOS live scanning remains deferred. See delivered work and next scope in the [roadmap](docs/ROADMAP.md); original feature recommendations remain in the [product review](docs/PRODUCT_REVIEW.md).

## Architecture: MVVM + Riverpod 3.4.3

- `lib/models/access_point.dart`: scan model, frequency/channel conversion, distance, overlap heuristic.
- `lib/models/analyser_state.dart`: immutable view state and typed native snapshots.
- `lib/models/comparison_session.dart`, `lib/repositories/comparison_sessions_repository.dart`, `lib/viewmodels/comparison_sessions_view_model.dart`: immutable bounded session evidence, versioned local storage and foreground recording/persistence orchestration.
- `lib/views/sessions_page.dart`: AP selection, recording feedback, saved-session comparison and deletion.
- `lib/models/scan_freshness.dart` / `wifi_guidance.dart`: elapsed-age rules and offline evidence/guidance.
- `lib/viewmodels/wifi_guidance_view_model.dart`: ephemeral same-AP baseline/recheck workflow.
- `lib/views/wifi_guidance_sheet.dart`: scrollable guide using shared scan recovery controls.
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

See [premium interaction review](docs/PREMIUM_REVIEW.md) for reviewed polish, fixes and verification.

See [motion and display refresh](docs/MOTION_AND_REFRESH.md) for native verification and physical-device 120 fps qualification, and [verification evidence](docs/MOTION_VERIFICATION.md) for completed checks and measured limits. Android requests maximum refresh at the current resolution; iOS enables ProMotion.

## Verification

```sh
ai/scripts/check.sh
fvm flutter build apk --release
fvm flutter build web
fvm flutter test integration_test/native_wifi_test.dart -d <android-device-id>
fvm flutter test integration_test/native_motion_test.dart -d <android-or-ios-device-id>
```

Widget tests cover phone and desktop layouts in both themes, search/details/navigation, chart width, legend hide/include/isolate/reset cycles, duplicate-SSID identity, scan reordering, compact scrolling/expansion at normal and large text scales, and rendered curve visibility. Analysis tests cover frequency exceptions, connected-AP exclusion, bandwidth overlap, and signal weighting. ViewModel tests check fresh/cached/duplicate timestamps, immutable history, pause behavior, stale in-flight scan responses, and settings persistence. Native integration checks the Android bridge on an emulator and OnePlus 15 (CPH2745, Android 16). Opt-in `physical_wifi_test.dart` verified live 2.4/5 GHz observations, paused age/history behavior and a newer same-BSSID guided recheck on that phone. Permission-revocation, disabled-service, throttling, roaming and 6 GHz coverage remain open; see [device evidence](docs/FRESHNESS_AND_GUIDANCE.md).

## Research

See `research/REVERSE_ENGINEERING.md` for APK identity, REA Evidence IDs, verified static findings, reconstruction choices, and remaining unknowns. APKs and raw decompilation outputs stay local and are excluded from Git. REA source clone: `~/Developer/personal/rea`; pinned JADX engine: `~/Developer/personal/rea-tools`.

Installable artifact: `dist/wave-wifi-release.apk` (normal app entry point, preserved separately from integration-test builds).

[Original platform branding](assets/branding/README.md) includes editable SVG, Android adaptive/themed/night icons, and iOS Any/Dark/Tinted appearances.

See [Rive onboarding](docs/RIVE_ONBOARDING.md) for editable artwork, runtime ownership, and native library setup. Keep Flutter/Dart on PATH for Rive's Android build hook. Independent architecture review found no actionable onboarding issues. Remaining physical RF edge cases are listed in [freshness/guidance verification](docs/FRESHNESS_AND_GUIDANCE.md).

APK output: `build/app/outputs/flutter-apk/app-release.apk`. Release mode currently uses development signing; production signing is not configured.
