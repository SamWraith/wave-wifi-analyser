# Shorebird updates

Wave uses Shorebird's standard automatic update flow in Shorebird-built releases.
Development builds made with FVM remain ordinary Flutter builds. No update widget,
polling timer, application state provider, or Dart updater dependency is needed.

## Verified baseline — 2026-10-16

- Android and macOS `1.0.0+1` baselines built with Shorebird Flutter 3.47.5 and
  registered in the owner's private Shorebird app. No patch was published.
- Both artifacts bundle Wave's real app ID and `auto_update: true`. Android APK
  engine inspection confirms Shorebird is present. The macOS signed host retains
  sandbox, network-client, Location and required patch-execution entitlements.
- Shorebird doctor reports no issues; static analysis and all 207 Flutter tests pass.
- Account recheck after registration confirms Free plan and zero overage limit.
- These baseline artifacts retain the project's development signing. Production
  Android signing and macOS Developer ID/notarization remain distribution work.
  No end-to-end patch download/relaunch test on a device has been performed.

Baseline artifact paths (excluded from source control):

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/macos/Build/Products/Release/wave - wifi analyser.app`

## Account and initialization

Registered application: **Wave WiFi Analyser**. Its stable public app ID lives in
`shorebird.yaml`, which is bundled by `pubspec.yaml`. CLI account verification on
2026-10-16 reported plan `free` with `overage_limit: 0`.

Use the Free plan. Do not enable paid overages or add billing details. The published
Free allowance is 5,000 successful patch installs per month, shared across apps on
the account; it is not 5,000 published patches. Review usage in the Shorebird console.
Free-plan availability is controlled by Shorebird, not by application code.

Install the official Shorebird CLI, then run these commands from the repository root:

```sh
export PATH="$HOME/.shorebird/bin:$PATH"
shorebird login
shorebird doctor
shorebird account whoami --json
```

The account response should report `plan_level: "free"` and `overage_limit: 0`.

Android bundle validation also needs Google's Android SDK Command-line Tools
(`cmdline-tools/latest/bin/apkanalyzer`) in the SDK reported by `flutter doctor -v`.
A missing `apkanalyzer` can surface as "failed to strip debug symbols" even when
the AAB contains engine symbols. Install the official tools; do not suppress symbol
checks or change native-library stripping to work around a missing tool.

Wave is already initialized. Only for a separate new app, initialize it once with
`shorebird init --display-name "Wave WiFi Analyser"`.

Initialization requires the owner's account. Keep the generated real `app_id` in
`shorebird.yaml` and its asset entry in `pubspec.yaml` under version control.
Never substitute an invented ID, copy another app's ID, or use `init --force` for
routine builds: existing installs need a stable app ID. Credentials and CI tokens
must stay outside the repository.

## Release baseline

Keep the Flutter version aligned with `.fvmrc` (currently 3.47.5). Shorebird builds
with its own matching Flutter fork; it does not replace the FVM development SDK.
Run the normal project checks before building.

```sh
ai/scripts/check.sh
shorebird release android --artifact apk --flutter-version 3.47.5 --dry-run
# Explicit engine profile; ordinary Flutter releases must not select it.
XCODE_XCCONFIG_FILE="$PWD/tool/macos/Shorebird.xcconfig" \
  shorebird release macos --flutter-version 3.47.5 --dry-run
```

Dry runs validate local builds without uploading a release. To register the actual
baseline, run the same commands without `--dry-run`. Distribute exactly the artifacts
from those successful Shorebird releases through the download page/Homebrew cask.
An APK/app rebuilt afterward with `flutter build` is not that baseline and cannot
receive its patches. Existing ordinary Flutter installations need a full upgrade to
the Shorebird baseline first.

Before public distribution, use a stable production Android signing key and complete
macOS Developer ID signing/notarization. Shorebird does not replace platform signing.
Increment app version/build number for each new full release.

For macOS, `tool/macos/Shorebird.xcconfig` selects the separate
`ShorebirdRelease.entitlements` profile and enforces hardened runtime without
base debugging-entitlement injection. Verify the built **and final packaged** app
with `tool/macos/verify_distribution.py --shorebird`; use the packaging script's
`--shorebird` flag. Keep ordinary Flutter builds on the default Release profile.
A local build is not evidence of valid patch delivery. Before public Shorebird
distribution, require owner-controlled patch signatures and verify missing/invalid
signature rejection and rollback. Existing private experimental baselines do not
establish those controls.

## Patches

Use the exact version shown by the registered baseline (the example below assumes
the current pubspec version). Patch builds reuse the baseline's Flutter revision.

```sh
shorebird patch android --release-version 1.0.0+1 --track staging
shorebird patch macos --release-version 1.0.0+1 --track staging
```

Preview the staging patch on a matching installed baseline before promoting it to
the stable track in the console. Check startup, navigation, scanning, permission
recovery, saved sessions, export, support link and offline use. A patch downloaded
in the background applies on a later app restart; do not force quit or restart the
app during a recording. Keep a known-good full release available for recovery.

Native Kotlin/Swift changes, entitlements, permissions, native plugins and asset
changes require a new full release unless Shorebird explicitly supports the change.
Never bypass native/asset compatibility checks just to force a patch through.
Use console rollback for a faulty patch, then verify behavior on a fresh launch.

## Network and privacy

Android's main manifest includes `INTERNET` for update delivery. macOS already grants
`com.apple.security.network.client` for CoreWLAN. Shorebird additionally requires
`com.apple.security.cs.allow-unsigned-executable-memory` in Release entitlements to
execute downloaded Dart patches. This expands executable-memory capability; the
app sandbox and Location access remain enabled. No WiFi permissions or scan timing
rules change.

Shorebird-enabled releases contact Shorebird to request patches and send update
metadata, including an installation identifier used for usage accounting. WiFi
identifiers, signal samples, aliases and saved sessions are not supplied to the
updater. Scanning and saved data still work without internet. Shorebird stores
compiled release/patch artifacts, not the project's source repository. Publishing
updates is an external upload, separate from a local dry-run build.

## References

- [Initialization](https://docs.shorebird.dev/code-push/initialize/)
- [Releases](https://docs.shorebird.dev/code-push/release/)
- [Patches](https://docs.shorebird.dev/code-push/patch/)
- [Pricing](https://shorebird.dev/pricing)
- [Billing](https://docs.shorebird.dev/account/billing/)
- [Privacy, source code and update limitations](https://docs.shorebird.dev/code-push/faq/)

## Windows

Shorebird supports Windows release/patch builds. Keep app ID
`9b0845e1-531e-4bf9-ab48-a1e96e08b9b5`, `auto_update: true`, Free plan and zero
overage limit. No Windows baseline or patch was registered by this implementation.
Ordinary Windows Flutter builds and the manual CI workflow do not receive patches.

**Pinned-engine constraint:** Shorebird's current [changelog](https://docs.shorebird.dev/changelog/)
reports a Windows production hang fixed in its Flutter 3.47.6 engine; the fix requires
a new full release. This repository must retain Flutter 3.47.5. Hold Windows
Shorebird production distribution until an SDK upgrade is separately approved and
validated. A Dart patch cannot repair this engine issue.

A Windows host can validate a local build without registering a release:

```powershell
shorebird doctor
shorebird release windows --flutter-version 3.47.5 --dry-run
```

This dry run retains the known engine limitation. After resolving the SDK constraint,
use the approved pin for a reviewed full baseline and test a staging patch on an
actual Windows installation. Account login/upload, patch delivery and restart proof
remain separate steps; no paid upgrade or public release is needed for local work.
Native WLAN/C++ changes require a full baseline.

Package the complete resulting Release directory using
`./tool/windows/package.ps1`. Never rebuild with ordinary Flutter after creating a
Shorebird baseline. Future MSIX packaging must use `build_windows: false`; see
[official Windows packaging](https://docs.shorebird.dev/flutter-concepts/releasing-flutter-apps/windows/)
and [release commands](https://docs.shorebird.dev/code-push/release/).

## Linux

Shorebird's current [platform FAQ](https://docs.shorebird.dev/code-push/faq/#what-platforms-does-shorebird-support)
and [release documentation](https://docs.shorebird.dev/code-push/release/) explicitly
support Linux. This is target-platform support, separate from running its CLI on
a Linux build host. The ordinary Flutter bundle and manual Linux CI build have no
Shorebird updater. No Linux baseline or patch is registered by these scripts.

Keep existing app ID `9b0845e1-531e-4bf9-ab48-a1e96e08b9b5`, `auto_update: true`,
Flutter 3.47.5, Free plan and zero overage limit. On an appropriately configured
Linux host, a local no-upload validation can use:

```sh
shorebird doctor
shorebird release linux --flutter-version 3.47.5 --dry-run
```

A successful Linux dry run, private baseline registration and actual staging patch
application after restart are separate evidence. Do not claim update delivery from
an ordinary Flutter build or change SDK pin to make the command pass. Native bridge,
plugin, system-library or asset changes require a reviewed full baseline. Packaging
must retain the exact resulting complete bundle; `tool/linux/package.sh` accepts a
`LINUX_BUNDLE` override and does not rebuild it. No workflow in this repository
uploads Shorebird artifacts, enables billing or publishes public releases.
