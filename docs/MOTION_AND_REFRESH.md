# Motion, feedback and display refresh

Wave uses Flutter's display-driven tickers, including Rive playback. There is no application timer limiting animation to 60 fps. The Android activity requests the highest advertised mode at the current resolution each time it resumes. Its Flutter SurfaceView also requests that rate when created/recreated; Android 16 uses the UI-specific `FRAME_RATE_COMPATIBILITY_AT_LEAST` vote. Owned surface callbacks are removed on destruction. iOS already includes `CADisableMinimumFrameDurationOnPhone=true` for ProMotion.

These are requests, not guarantees. Display hardware, system settings, power saving, thermal limits and rendering workload determine actual presentation. A 60 Hz emulator cannot validate 120 fps. Android refresh diagnostics are available through `com.samirpandey.wifi_analyser/display`, method `refreshRate`; this reports supported/current/requested display rates, not achieved animation fps.

## Interaction coverage

- Overview, Spectrum, Networks, Channels and Settings: finite page reveal.
- Charts, channel bars, signal values and fresh scan feedback: existing finite transitions, preserving exact measured data.
- Navigation, band selection, theme selection, scan pause/resume, settings switches, committed signal threshold and onboarding navigation/replay: mobile selection haptics.
- Manual scan and access-point detail opening: light impact.
- Actionable network rows and desktop navigation: hover/focus/press feedback. Standard Material buttons, chips, switches and navigation retain their native interaction states.
- Rive welcome: three original scenes with finite interactive playback, background pause and accessibility support.

Home scan status reserves measured space for ordinary status messages, preventing subsequent content from jumping as messages change. Onboarding reserves the largest known title/body/eyebrow/action copy at actual width and text scale, and retains the Back control slot across steps. Longer exceptional messages can still expand without clipping.

Haptics run only for user actions on Android/iOS. Unsupported hardware/plugin failures do not block actions. No haptics fire for background scans or slider preview ticks.

## Circular theme reveal

Both header toggle and Settings theme chips reveal the new theme from the tapped control's center. One old frame is captured at up to 2x logical resolution, then a 460 ms expanding circular mask reveals the live new theme. Painting listens directly to the animation rather than rebuilding the application each tick. Routes, search, scroll and focus retain their state; the application is never duplicated.

Repeated theme taps during capture/reveal are coalesced into one selection. Capture failure falls back to changing the theme. Reduced motion skips capture and reveal; enabling it mid-transition ends the reveal. Background/disposal and stale asynchronous capture replies release resources safely. System-driven theme changes have no button origin and apply immediately.

## Native verification and 120 fps qualification

Use the repository SDK pin:

```sh
fvm use
ai/scripts/check.sh
fvm flutter test integration_test/theme_refresh_test.dart -d <android-or-ios-target>
fvm flutter test integration_test/onboarding_test.dart -d <android-or-ios-target>
fvm flutter drive --profile --target integration_test/motion_profile_test.dart \
  --driver test_driver/motion_profile_test.dart --keep-app-running -d <physical-120hz-device>
fvm flutter run --profile --no-resident -t tool/motion_probe.dart -d <physical-120hz-device>
fvm flutter run --profile -d <physical-120hz-device>
```

`flutter drive` normally uninstalls its test app after completion; `--keep-app-running` preserves installation for device settings and inspection. Install the normal release APK after testing to replace the test entry point.

The automated profile run writes `dist/motion-profile.json` with display diagnostics and per-scenario frame counts, UI/raster p95 and maxima, over-budget counts, and active vsync cadence. It measures first/repeated theme reveals, navigation/search/details and all three real Rive scenes. It does not equate frame timings with compositor presentation or claim all-device sustained fps.

Use `tool/motion_probe.dart` for performance cadence: it runs the production `WidgetsFlutterBinding` with demo data and real elapsed time, samples eight theme reveals and three replays of each Rive scene, then logs `WAVE_NORMAL_MOTION_PROFILE` JSON through Android logcat or Flutter output. It marks onboarding complete and changes the persisted theme; it is a diagnostic entry point, not the normal app. Install the normal release afterward. Programmatic no-touch samples measured near 60 Hz, including with the normal binding. The same installed normal-binding probe reached near 120 Hz with touch activity. Cadence varies with input/device policy; integration cadence alone must not diagnose a production cap. Per-scenario `WAVE_NORMAL_SAMPLE` JSON avoids aggregate log truncation. See the verification report for budget misses and measurement limits.

In Flutter DevTools Performance, record first and repeated theme changes, Rive scene replay, navigation, chart updates, network search/scroll and detail opening in light/dark modes. Record model, OS, display settings, power/thermal state and supported/current refresh rate. At 120 Hz, UI and raster work each have an approximately 8.33 ms frame budget; inspect dropped frames, latency and readback cost, not just average fps. Repeat at the device's highest supported mode if higher than 120 Hz. Profile real hardware; debug emulator/simulator timings cannot qualify release performance.

Primary references: [Flutter profiling](https://docs.flutter.dev/perf/ui-performance), [Android window refresh preference](https://developer.android.com/reference/android/view/WindowManager.LayoutParams#preferredRefreshRate), [Android surface frame-rate vote](https://developer.android.com/reference/android/view/Surface#setFrameRate(float,int)), [Apple ProMotion opt-in](https://developer.apple.com/documentation/bundleresources/information-property-list/cadisableminimumframedurationonphone).
