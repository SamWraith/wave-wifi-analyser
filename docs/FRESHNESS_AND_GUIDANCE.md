# Freshness and guided troubleshooting verification

Date: 2026-10-13. Flutter 3.47.5 through FVM.

## Feature 1: scan freshness and recovery

Last fresh observation age advances in presentation only, including while paused.
Cached/duplicate snapshots retain the observation time and never add history.
Demo age is explicitly simulated. Recent observations become older after two
minutes; this cutoff is a UI caution, not Android scan availability policy.
Presentation clocks stop in background and refresh elapsed age on resume.
Permission recovery offers the permission prompt and app settings (including
permanent denial); Location and WiFi have their own settings destinations.

Checks passed: format, static analysis, controller/freshness/recovery/repository,
layout-stability and phone/desktop light/dark widget tests. Emulator-5554 passed
native_wifi_test.dart against the Android bridge after native destination changes.
OnePlus 3C161500AUB00000 was not connected; physical RF coverage remains open.
Native settings Intent targets are covered by channel routing tests and native
compilation; automated bridge test does not prove OEM settings UI behavior.

Independent architecture engineer review caught a qualifier that remained fresh
as observations aged. Qualifier now lives with the presentation clock; deterministic
clock/background/resume/disposal and recovery tests cover the fix. Independent
re-review found no remaining actionable feature 1 findings.

## Feature 2: Improve my WiFi

Overview opens a scrollable, ephemeral guide with weak-signal and crowded-channel
choices. A baseline requires a connected AP recorded in the latest fresh history
batch, live mode and enabled scan prerequisites. Cached, empty, paused, demo and
observations older than two minutes explain the limitation rather than inventing
conclusions. The guide uses full scan data and the connected AP's band, independent
of chart visibility, search, band selection and signal display threshold.

Recheck requires a timestamp newer than both baseline and the current result at
request time. It waits through cached/duplicate replies and compares only the same
BSSID. Roaming resets comparison; switching to demo clears pending checks. Recheck
shows exact RSSI difference or relative overlap direction, with single-observation,
router-support and heuristic caveats. No storage, extra permissions, cloud or AI
service were introduced. Closing the guide disposes its Riverpod state.

Independent architecture engineer reviewed MVVM/Riverpod ownership, lifetime,
freshness/identity gates, overlap reuse and scrollable/shared widget composition.
No actionable findings. Unit and large-text phone light/dark widget tests verify
newer-only rechecks, cached/duplicate rejection, AP changes, demo resets, stale and
paused baselines, filter independence, both themes and closing. The Android native
bridge integration test opens both guide choices and checks cached-data gating on
emulator-5554. Native integration passed; physical RF testing remains open because
the OnePlus was disconnected. Full format/analysis and all 71 unit/widget tests
passed, including existing chart legends, onboarding, theme reveal and motion.

## Final delivery checks

Android release APK and web builds passed. Release build initially collided with
integration-plugin generated registration while Flutter commands ran concurrently;
sequential rebuild passed. Run Flutter builds/tests sequentially when they share
this checkout's generated plugin metadata. Existing Rive Kotlin-plugin migration
warning remains; no dependency upgrade was included in this feature slice.

Normal release APK installed and launched on emulator-5554. Original Rive welcome,
Overview recovery panel and guided sheet were visually inspected. App permissions
shortcut opened Android Settings app-details UI on the emulator. Location/WiFi
routes remain covered by typed channel tests/native compilation, without OEM UI
coverage. Refreshed installable artifact: `dist/wave-wifi-release.apk` (ignored by
Git, normal app entrypoint). Release still uses existing development signing.
No additional refresh-rate or physical RF qualification was claimed.
