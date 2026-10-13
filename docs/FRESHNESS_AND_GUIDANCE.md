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
