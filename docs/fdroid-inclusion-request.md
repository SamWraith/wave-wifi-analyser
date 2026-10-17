# Wave WiFi Analyser

Submitted request (17 October 2026):
https://gitlab.com/fdroid/rfp/-/work_items/4587

The text below is the preparation draft; the linked request uses F-Droid's form
headings and records the remaining review requirements explicitly.

Request inclusion of Wave, a free WiFi analyser with live Android scans, channel
overlap charts, signal history, local favourites/aliases and saved room comparisons.
All features are free; an optional donation link opens an external website.

- Source and website: https://github.com/SamWraith/wave-wifi-analyser
- License: GPL-3.0-or-later (root LICENSE and NOTICE on main)
- Android package: com.samirpandey.wifi_analyser
- Current version: 1.0.2, version code 3
- Releases: https://github.com/SamWraith/wave-wifi-analyser/releases
- Issue tracker: https://github.com/SamWraith/wave-wifi-analyser/issues
- Metadata and screenshots: fastlane/metadata/android/en-US
- Build review notes: docs/FDROID.md

WiFi observations and saved comparisons stay on device until the user explicitly
shares an export. Live scanning needs precise Location permission and enabled
Location services; Wave does not collect geographic coordinates. Screenshots use
clearly labelled demo networks rather than private observations.

The app uses Flutter 3.47.5 (FVM pin), Riverpod and Rive. Please review the native
Rive dependency's build provenance: rive_native 0.1.11 is MIT-licensed but normally
downloads native libraries. Upstream offers a source-build path; it has not yet
been validated for this app on F-Droid. An unsigned Android build recipe also
needs to bypass the repository's local release/debug signing configuration.

Please build with ordinary Flutter, without a Shorebird engine/updater. The
repository includes Shorebird configuration for other distribution experiments;
the ordinary Flutter GitHub APK has no Shorebird updater.

The existing v1.0.1 release tag predates the new root GPL license. Use a reviewed
commit containing LICENSE and NOTICE rather than assuming that tag is suitable.
No F-Droid build/scanner success is claimed. Packaging assistance and inclusion
review are requested.
