# Motion and branding verification

Date: 2026-10-13. Scope: native motion, onboarding/layout fixes, refresh requests,
platform branding and FVM setup. Architecture remains MVVM with Riverpod.

## Changes and regressions

- `.fvmrc` pins Flutter 3.47.5; editor and validation script use the local FVM SDK.
  Checkout directory now matches `wave-wifi-analyser`.
- Theme reveals grow from the selected control without replacing Navigator,
  search state or focus. Regression checks cover repeated captures, asynchronous
  cancellation, reduced motion, resize and disposal.
- User interactions receive mobile haptics. Background scans and slider previews
  do not trigger feedback; unavailable haptics cannot block actions.
- Rive assets contained valid animation keys. Seeking animation time followed by
  `apply()` did not synchronize native timeline state. `advanceAndApply(0)` now
  applies the selected frame. Rendered-pixel regressions verify all three scenes
  change between timeline positions. Playback remains finite on entry/replay,
  pauses in background, and honors reduced motion.
- Measured text slots stabilize onboarding titles, body, eyebrow and actions at
  actual width/text scale. Back retains its slot. Home status reserves ordinary
  status-copy height. Exceptional longer errors can expand accessibly.
- Android requests the highest advertised refresh rate at the current resolution
  through window mode, surface and supported view APIs. Lifecycle owns and
  removes surface callbacks. iOS ProMotion opt-in remains enabled.
- Original SVG generates Android adaptive/monochrome/night assets and iOS
  Any/Dark/Tinted opaque asset-catalog appearances.

## Checks completed

- `ai/scripts/check.sh`: formatting clean, analyzer clean, 55 unit/widget tests
  passed, including rendered Rive-frame and layout-stability regressions.
- `integration_test/native_motion_test.dart`: both tests passed on Android
  emulator and iOS iPhone 17 Pro simulator. Covers native Rive load/replay/rest,
  reduced motion, theme reveal, retained search and navigation destinations.
- Android normal release APK built successfully and installed on connected
  OnePlus CPH2745, Android API 36. Release uses development signing.
- Icon generator verification passed dimensions, opacity, grayscale tint,
  Android resource density and adaptive safe-circle checks. Native Android
  packaging and Xcode asset-catalog compilation passed.
- Independent architectural review found no remaining actionable findings in
  the changed motion, lifecycle, Rive and stable-copy paths.

## Physical performance qualification

The first physical profile requested 165 Hz, reported a current display mode of
120 Hz, but measured active frame cadence near 16.626 ms (about 60 fps). The
three Rive scenes had UI p95 below 1 ms and raster p95 below 1.9 ms, with no
frames over the 8.33 ms budget in those samples. Theme and navigation samples
included over-budget frames. This does not establish sustained 120 fps.

`flutter drive` initially removed its test APK after completion, explaining the
missing installation when the user checked app-specific refresh settings. A
normal release installation restored Wave to that settings list; the user then
selected 120 Hz or the highest offered rate. Subsequent profile runs use
`--keep-app-running`, and the normal release app replaces the test entry point
following verification.

Frame timings describe the tested workload, not compositor presentation or
all-device guarantees. Physical RF scanning and prolonged thermal/battery tests
are outside this motion qualification.

After the user selected the per-app rate, the repeated physical integration
profile still measured median active cadence near 16.626 ms. Rive UI/raster p95
remained below 1 ms in that run. All workload assertions passed; 120 fps did
not qualify. The diagnostic JSON stays in ignored `dist/motion-profile.json`.

A separate profile-only probe using ordinary `WidgetsFlutterBinding` sampled
eight theme toggles: 673 frames, median active vsync interval 8.314 ms (near
120 Hz), with intervals up to 33.253 ms in its filtered active range. This
shows normal runtime can reach 120 Hz active cadence. Later controlled
comparisons below identify touch activity as a material variable; the binding
alone did not explain the difference. This does not establish constant 120 fps. `tool/motion_probe.dart` makes subsequent
normal-binding theme/Rive sampling reproducible. Independent review caught
and resolved distinct-root ProviderScope ownership in this diagnostic tool.

## Controlled touch comparison

The same installed normal-binding probe was restarted without rebuilding or
changing system settings. Continuous synthetic touches in non-actionable header
space accompanied all samples. Comparing against the earlier no-touch run
indicates touch activity/device refresh policy affects cadence; changing the
binding alone does not explain the variation.

| Scenario | Frames | Active median ms | UI p95 ms | Raster p95 ms | Frames exceeding 8.33 ms UI/raster budget |
| --- | ---: | ---: | ---: | ---: | ---: |
| normal-binding-theme-reveals | 471 | 8.314 | 5.404 | 1.431 | 6 |
| normal-binding-rive-Wave Signal | 366 | 8.315 | 0.76 | 0.919 | 3 |
| normal-binding-rive-Wave Channels | 366 | 8.315 | 0.812 | 0.902 | 1 |
| normal-binding-rive-Wave Access | 366 | 8.314 | 0.772 | 0.924 | 1 |

All four samples reached active cadence near 120 Hz with UI/raster p95 below
8.33 ms. Theme work peaked at 12.471 ms UI; Rive raster work peaked at 10.636 ms.
Theme active intervals included 17 gaps above 9 ms; Rive included zero, zero
and one respectively. These results establish sampled 120 Hz active cadence,
not zero missed frames or sustained 120 fps under every condition. Cadence
statistics exclude intervals at least 40 ms, which can include idle gaps and
stalls. Display mode continued to report 120 Hz despite a 165 Hz request.

Structured results remain in ignored `dist/normal-motion-profile.json`.
Per-scenario `WAVE_NORMAL_SAMPLE` logging avoids Android truncating the larger
aggregate JSON. Ordinary no-touch programmatic runs can fall near 60 Hz; natural
interaction/idle policy must be documented alongside any performance claim.
