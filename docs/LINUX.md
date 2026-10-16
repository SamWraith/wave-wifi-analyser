# Linux desktop

Wave uses the shared Flutter desktop interface and a native Linux WiFi bridge.
Overview, Spectrum, Networks, Channels, Settings, local room comparisons, private
export preview, themes, accessibility, onboarding and support link share the same
application code. Live scanning never silently falls back to demo data.

## Runtime requirements

- A graphical Linux desktop with GTK 3, a working Flutter-compatible graphics
  stack, a system D-Bus, running NetworkManager (1.12 or newer) and a managed WiFi
  interface. NetworkManager `LastScan` was introduced in 1.12.
- A kernel/driver supporting nl80211 and scan-cache signal values in mBm. Wave
  reads actual dBm from the kernel; it does not convert NetworkManager's strength
  percentage into fabricated RSSI. libnl 3 and libnl-genl 3 must be installed.
- An active desktop session and distribution Polkit policy permitting
  `org.freedesktop.NetworkManager.wifi.scan`. A desktop authentication agent may
  be needed when policy requires interaction. Automatic scans never request
  interactive authentication. When policy reports `auth`, choose **Authorize WiFi**
  and explicitly scan to allow authentication. Denial stays visible and retryable.
  Run Wave as your normal desktop user, never with sudo. Wave does not install
  permissive Polkit rules or request root/capability escalation.
- NetworkManager must manage the adapter. Systems using only standalone iwd,
  wpa_supplicant or systemd-networkd are not supported by this bridge.

The release build baseline is **Ubuntu 24.04 x64**, using glibc 2.39 and its
modern GCC 13 libstdc++ runtime. Required runtime packages include `libgtk-3-0t64`,
`libnl-3-200`, `libnl-genl-3-200`, `libstdc++6`, and `network-manager` plus your
normal desktop/graphics stack. The bundled Rive native runtime currently needs
glibc 2.38 or newer and modern libstdc++ symbols. Ubuntu 22.04 can compile the
standalone WiFi native tests, but cannot link the complete app with this prebuilt
Rive runtime. No Ubuntu 22.04 compatibility is claimed. Install through your distribution, preserving existing network
configuration. A tar bundle includes Flutter/plugin libraries and app assets,
not these system libraries or services. A web browser/URI handler must be configured
for **Buy me a coffee** and other external links.

## Scanning and limits

The bridge requests scans through NetworkManager and waits for its monotonic
`LastScan` completion value to advance. A successful request alone is not new
data. Actual starts are spaced at least 35 seconds apart, matching foreground
automatic requests; NetworkManager/driver may still reject, defer or throttle
requests. The completion wait has a 12-second timeout; individual D-Bus calls and scan-cache
reads have their own bounded deadlines, so total request time can be longer. Pause, background and disposal
cancel owned work and ignore late results; they cannot retract radio work already
accepted by the system. Concurrent requests are rejected, not queued indefinitely.

The bridge chooses a managed, usable adapter, preferring a connected one. Multiple
adapters are not merged. Connection identity comes from NetworkManager's active AP;
frequency and RSSI come from matching kernel scan entries. The default band follows a known
connected 2.4/5/6 GHz AP until manually changed in the shared interface.

Kernel scan caches can retain older APs. A new NetworkManager scan completion does
not establish a new radio observation for every returned AP. Width/center frequency
and per-AP freshness remain unknown when not supplied by this bridge. Wave labels
those limits; chart envelopes assume 20 MHz for unknown widths and channel planning
remains an overlap heuristic. A new completion may add one snapshot to history;
cache-only/duplicate completions do not. Recording timestamps represent accepted
completion observations, not an invented per-AP beacon time.

Service missing, no usable adapter, unmanaged adapter, radio off/rfkill, denied
scan/cache access, scan already running, timeout and native errors remain visible.
Use the desktop's network controls to enable WiFi and check policy. No GPS data,
monitor mode, packet capture, router changes or hidden privileged daemon is used.
6 GHz availability depends on adapter, firmware, driver and local regulation.

## Build and validate

Build on Linux. The macOS host cannot establish Linux compilation or hardware
behavior by running Dart tests. Keep `.fvmrc` at Flutter **3.47.5**.

Ubuntu 24.04 build dependencies:

```sh
sudo apt-get update
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-13-dev libnl-3-dev libnl-genl-3-dev python3
fvm install
FLUTTER_BIN="$PWD/.fvm/flutter_sdk/bin/flutter" ./tool/linux/validate.sh
```

The script enforces the pin and lockfile, checks formatting/analysis, prepares Rive's
Linux native runtime, runs native C++ tests, builds a release, then runs Flutter
tests with the resulting bundle libraries on `LD_LIBRARY_PATH` and packages the
complete bundle. The complete build supplies the real Rive Linux plugin needed
by asset tests; the download/setup step alone does not supply that plugin. It does not start a hardware scan or publish a release.
Rive setup downloads the upstream native runtime and needs network access. For a
native-only check:

```sh
cmake -S linux/native_tests -B build/linux-native-tests -DCMAKE_BUILD_TYPE=Release
cmake --build build/linux-native-tests --parallel
ctest --test-dir build/linux-native-tests --output-on-failure
```

`.github/workflows/linux.yml` is a manual Ubuntu 24.04 x64 validation workflow.
It uploads a workflow artifact retained for 14 days, subject to repository access
rules; it does not create a GitHub release.
Hosted CI has no physical WiFi hardware; successful compilation/tests do not prove
RF behavior. ARM64 packaging is supported by the script when built on an ARM64
Linux host, but that architecture requires separate validation.

## Public preview validation — 2026-10-17

[Hosted Ubuntu 24.04 x64 job](https://github.com/SamWraith/wave-wifi-analyser/actions/runs/38955632851/job/117157670778)
built version **1.0.1+2**, passed formatting/analysis, native CTest **2/2** and all
**231 Flutter tests**, then packaged the complete release bundle. The Windows job in
that combined run failed separately; Linux completed successfully. Linux source was
unchanged by the subsequent Windows-only C++20 build fix. Physical Linux WiFi scans,
Polkit and normal desktop distribution remain untested. See [GitHub releases](https://github.com/SamWraith/wave-wifi-analyser/releases).

## Validation evidence — 2026-10-16

- Full **Linux x64 release** built with pinned Flutter 3.47.5 on Ubuntu 24.04
  (glibc 2.39, Clang 18), inside an isolated Docker container on a macOS ARM64 host
  using x64 emulation. Complete tar bundle produced. Executable dependency check
  reported no missing shared libraries in that environment.
- `tool/linux/validate.sh` passed: formatting, static analysis, native CMake/CTest
  **2/2**, complete release compilation, and all **231 Flutter tests**, including
  actual Rive asset rendering. Native tests use a private fake NetworkManager
  D-Bus service and constructed nl80211 messages; they do not use physical RF.
- `integration_test/linux_wifi_test.dart` passed under Xvfb with a session D-Bus.
  It exercises the compiled GTK runner/method channel, explicit native service-error
  handling, live Linux source identity, app startup and Ctrl+5 Settings navigation.
  The container has no system NetworkManager/WiFi adapter, so this is error-path
  and desktop runtime proof, not a successful hardware scan or Polkit grant.
- macOS also passed all 231 Flutter tests. Android debug APK, macOS debug app and
  web release builds succeeded after shared repository/export changes. Independent
  review's unknown-security and automatic authorization findings have fixes and
  behavioral coverage.
- Ubuntu 22.04 compiled and passed native WiFi tests, but its full app link failed
  on Rive's newer glibc/libstdc++ symbols. Ubuntu 24.04 is the current app baseline;
  no symbol shims or ignored linker errors are used.

For an interactive Linux desktop bridge smoke check:

```sh
fvm flutter test integration_test/linux_wifi_test.dart -d linux
```

For a headless display, install `xvfb` and `dbus-x11`, then use
`dbus-run-session -- xvfb-run -a fvm flutter test integration_test/linux_wifi_test.dart -d linux`.
The normal production entry point remains the release bundle; an integration-test
build must not replace it in distribution.

**Still unverified:** real NetworkManager/driver RF scans, real Polkit grant/deny,
roaming, multi-adapter hardware, 6 GHz, native folder chooser interaction, browser
launch, normal-user desktop distribution and Shorebird delivery. Complete the
hardware checklist before claiming production parity. No Linux release/patch was
published and no billing setting changed.

## Package and install

`tool/linux/package.sh` packages `build/linux/x64/release/bundle` (or `arm64`) into
`dist/wave-wifi-analyser-linux-x64.tar.gz`. Keep executable, `lib/` and `data/`
together; copying only `wifi_analyser` breaks startup. Set `LINUX_BUNDLE` only to
package another complete build output, such as an approved Shorebird baseline.

Extract into a permanent user-owned location, then run:

```sh
./wave-wifi-analyser-linux-x64/wifi_analyser
./wave-wifi-analyser-linux-x64/install-launcher.sh
```

The optional script installs the shared Wave SVG and a desktop entry under
`${XDG_DATA_HOME:-$HOME/.local/share}`. It never moves the bundle or installs
system-wide. Moving the bundle requires running the script again. Remove the
`applications/com.samirpandey.wifi_analyser.desktop` and
`icons/hicolor/scalable/apps/com.samirpandey.wifi_analyser.svg` files to remove
this launcher. Local app preferences/sessions remain until separately removed.
Tar packaging supplies no sandbox integration, signing, auto-upgrade manager,
AppImage, Flatpak or Snap permissions. Distribution packages need their own review.

## Plugin behavior

[Rive 0.14.11](https://pub.dev/packages/rive) advertises Linux support for both
renderers; onboarding still needs actual Linux rendering/playback checks.
[url_launcher_linux](https://pub.dev/packages/url_launcher_linux) is endorsed and
opens through the desktop's configured URI handlers.
[share_plus 13.3.1](https://pub.dev/packages/share_plus) supports text, but not file
sharing on Linux. Wave therefore uses an explicit **Save reviewed files** action for reviewed
private comparison exports instead of claiming a system file-share chooser.
The native directory chooser uses [file_selector 1.1.0](https://pub.dev/packages/file_selector).
Files go into a newly created `wave-comparison-` subfolder in the chosen directory;
existing files are not overwritten. No upload or email handoff occurs.
Preview/copy/privacy choices remain shared. Browser launch, save cancellation,
write failures and successful local export need desktop verification.

## Hardware acceptance matrix

Record distro/version, desktop/Wayland or X11, CPU architecture, NetworkManager
version, adapter/driver and exact test outcome. Do not log private SSIDs/BSSIDs in
public build artifacts.

| Check | Expected behavior |
| --- | --- |
| Connected 2.4/5/6 GHz (where supported) | Real RSSI/frequency/BSSID; correct connected card/default band; no fabricated width |
| Disconnected but powered adapter | Nearby results; honest disconnected card |
| Missing/unmanaged adapter or NetworkManager stopped | Actionable live error; no silent demo |
| Software/hardware radio block | Radio error, then recovery after user enables WiFi |
| Policy denied/authentication canceled | Permission error; no root recommendation; retry after policy/session recovery |
| Repeated manual requests/automatic 35 s cadence | Coalescing/rejection and honest cache status; no duplicate history |
| Missing kernel mBm/netlink access | Missing-mBm entries excluded with status/count; denied cache access errors; no percent-to-dBm estimate |
| Pause/background/close while scanning | No late state/history/recording mutation or crash |
| Recording and room comparison | Only accepted observations; unknown RF/freshness stays disclosed |
| Export save/cancel/retry, privacy toggles | Correct reviewed files; no email/share fallback or silent identifiers |
| Rive, light/dark/system, large text, keyboard | Real rendering, reachable controls and accessible navigation |
| Support link and relaunch | Browser opens only after action; preferences/sessions persist |
| Extracted release on clean target distro | Complete bundle launches; runtime dependencies clear |

At implementation time no physical Linux WiFi verification is claimed. Record
actual build and runtime evidence separately from this acceptance checklist.

## Official references

- [NetworkManager Wireless: RequestScan, LastScan, ActiveAccessPoint](https://networkmanager.dev/docs/api/latest/gdbus-org.freedesktop.NetworkManager.Device.Wireless.html)
- [NetworkManager AccessPoint metadata](https://networkmanager.dev/docs/api/latest/gdbus-org.freedesktop.NetworkManager.AccessPoint.html)
- [Kernel nl80211 interface](https://www.kernel.org/doc/html/latest/networking/netlink_spec/nl80211.html)
- [Flutter Linux build/distribution](https://docs.flutter.dev/platform-integration/linux/building)
- [Shorebird platform support](https://docs.shorebird.dev/code-push/faq/#what-platforms-does-shorebird-support) and [project update setup](SHOREBIRD.md)
