# Windows desktop

Wave's Windows target uses the shared Flutter desktop UI and a native Windows WLAN
bridge. Windows defaults to live data; explicitly selected demo mode remains
labelled. Live errors never replace measurements with simulated networks.

## Build and package

Use a Windows x64 development machine with Visual Studio's **Desktop development
with C++** workload, Windows SDK and CMake. Visual Studio Code alone does not supply
the compiler. Follow [Flutter's Windows setup](https://docs.flutter.dev/platform-integration/windows/setup)
and resolve `flutter doctor -v` toolchain errors. Development SDK stays pinned to
Flutter **3.47.5** by `.fvmrc`.

From PowerShell 7 at the repository root, with FVM installed:

```powershell
fvm install
fvm use
./tool/windows/validate.ps1 -Flutter (Resolve-Path .fvm/flutter_sdk/bin/flutter.bat).Path
fvm flutter run -d windows
```

Validation enforces the SDK pin and lockfile, checks formatting and analysis,
installs Rive's Windows runtime, runs Flutter and portable native CMake/CTest
tests, then builds Release. Ensure
Flutter's `bin` directory (containing Dart) remains on PATH for native plugin builds.
Dependencies and Rive prebuilt libraries require network access during setup.

For an interactive local Windows desktop, opt into the real native-channel smoke
check (no hardware RF assertion or automatic permission grant):

```powershell
./tool/windows/validate.ps1 -Flutter (Resolve-Path .fvm/flutter_sdk/bin/flutter.bat).Path -Integration
```

The default hosted CI run leaves `-Integration` off. Native boundary tests run by
both routes cover SSID encoding, redacted BSSIDs, scan start spacing and adapter
selection. They can also run independently:

```powershell
cmake -S windows/native_tests -B build/windows-native-tests
cmake --build build/windows-native-tests --config Release
ctest --test-dir build/windows-native-tests -C Release --output-on-failure
```

`dist/wave-wifi-analyser-windows-x64.zip` contains the **complete**
`build/windows/x64/runner/Release` directory. Extract everything together, then run
`wifi_analyser.exe`. Never distribute the EXE alone: DLLs and `data/flutter_assets`
are required. `tool/windows/package.ps1` can repackage an existing build without
rebuilding, including a future Shorebird baseline. Its SHA-256 identifies the
archive built locally; production publisher signing and installer/MSIX packaging
are separate distribution work. No certificate, store identity or public release
is configured by this workflow. A clean target may need Microsoft's supported
[Visual C++ v14 runtime](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist).
The public preview was built with toolset 14.51; use the latest x64 redistributable,
version 14.51 or newer, rather than an older 2015–2022-era installer. Microsoft
requires a runtime at least as new as the toolset used for the build.

## Windows build route and evidence

`.github/workflows/windows.yml` supplies a manual GitHub Actions route on
`windows-latest`: pinned Flutter checkout, Windows toolchain report, checks, tests,
release compilation and a downloadable workflow ZIP. It needs no Shorebird token
or billing setup and creates no GitHub Release. After the change is reviewed and
pushed to an authorized branch, run **Windows validation** from Actions. Workflow
availability/dispatch follows GitHub's default-branch workflow rules.

The implementation host is macOS. Local Flutter tests validate shared behavior and
mocked platform boundaries; they do not compile MSVC code or prove Windows RF,
permission prompts, share UI, Rive rendering or browser launch. A successful Windows
workflow proves compilation and deterministic tests, not access to WiFi hardware.
A real Windows computer with a WiFi adapter is still required for the checklist
below. Hosted runners need not expose WiFi radios.

## Release validation — 2026-10-17

[Windows validation run](https://github.com/SamWraith/wave-wifi-analyser/actions/runs/38956457236)
built the complete **1.0.1+2 Windows x64 release** on hosted Windows Server 2025,
Visual Studio 2026 / MSVC 19.51, using pinned Flutter 3.47.5. Formatting and analysis
passed, all **231 Flutter tests** passed and native CTest passed **1/1**. The complete
ZIP includes Flutter, Rive and plugin DLLs plus app assets. The runner now requests
C++20 so C++/WinRT uses standard coroutine headers on recent MSVC. Fresh SDK version
checks bootstrap Flutter before parsing machine-readable output.

This supersedes the initial compilation limitation below. **Windows remains untested
on real WiFi hardware.** Native-channel desktop integration, actual permission dialogs,
RF scans and everyday plugin/UI operation remain unverified. Public preview packages
are unsigned and have no installer/MSIX identity. See [GitHub releases](https://github.com/SamWraith/wave-wifi-analyser/releases)
and [delivery procedure](RELEASING.md).

## Local validation — 2026-10-16

On the macOS implementation host:

- `ai/scripts/check.sh`: formatting clean, analysis clean, all **217 Flutter tests** passed.
  Windows tests use mocked method-channel payloads/fake repositories; desktop widget
  tests cover Windows Ctrl navigation, resizing, large text and recovery states.
- Portable native C++17 tests compiled with AppleClang and passed CTest **1/1**:
  scan cadence/cancel-before-start, healthy/failing adapter selection, SSID encoding,
  redacted identifiers and supported-frequency filtering. These compile shared native
  policy/encoding helpers, not the Win32/WinRT bridge itself.
- Android debug APK, macOS debug app and web release builds succeeded. Android
  reports an upstream Rive Native Kotlin Gradle Plugin deprecation warning.
- Independent review identified adapter-failure isolation, cancellation before native
  scan start and first-run radio-off recovery; fixes and regressions are included.

**Not run:** Windows MSVC build, PowerShell script execution, Windows integration
smoke test, physical Windows WiFi or plugin runtime checks. Run the validation script
on a Windows x64 host with the Visual Studio C++ workload/SDK; use a real WiFi adapter
for RF/privacy qualification. No Windows artifact, release or patch was published.

## Privacy, scanning and limitations

Recent Windows versions gate WiFi identifiers and scans on Location consent.
Enable **Settings > Privacy & security > Location** and the relevant device, user
and desktop-app permissions; policies can still deny access. Wave offers settings
recovery and reports native access failures. It does not request location
coordinates. See [Microsoft's WiFi access changes](https://learn.microsoft.com/en-us/windows/win32/nativewifi/wi-fi-access-location-changes).

Microsoft's [WlanScan contract](https://learn.microsoft.com/en-us/windows/win32/api/wlanapi/nf-wlanapi-wlanscan)
is asynchronous: successful return only accepts a request. Completion notification
or timeout precedes reading results. The documented WLAN service's default
60-second background cadence is **not** an application scan throttle; Wave keeps
35-second foreground requests and serializes native work. Drivers control RF
behavior; scans can briefly increase network latency. Completion is not proof that
every listed AP was observed anew. ACM notifications identify the interface but
carry no application request ID: Wave accepts an interface completion while waiting,
without claiming exclusive correlation to its own request. Other software or the
WLAN service can contribute that completion.

Each successful scan completion receives a unique completion ID; each completion
is accepted once. `WLAN_BSS_ENTRY` has `ullHostTimestamp`, but Wave does not establish
a reliable radio observation age from it. Wave deliberately emits timestamp zero;
per-AP radio freshness and cache age remain unknown. A new
completion can include cached radio observations, so completion age is explicitly
qualified. Cache-only or duplicate completion IDs cannot complete a guided recheck
or add recording samples. Missing RF fields remain unknown: width is unreported
and center frequency absent. Charts/channel scoring disclose their 20 MHz fallback
assumption rather than presenting it as measured width. Native errors, missing
adapters, radio-off and denied permission stay visible; retained data keeps its old
completion time. No noise, throughput or distance-accuracy measurement is claimed.
Wave selects one usable adapter, preferring a connected powered adapter, then
another powered adapter; it does not merge measurements from multiple adapters.
An unusable secondary adapter does not block a usable one. Multiple-adapter
selection, driver behavior, roaming and 6 GHz still require hardware qualification.

## Shared plugins

Locked dependencies declare Windows support: `rive` 0.14.11 with `rive_native`
0.1.11, `share_plus` 13.3.1 and `url_launcher_windows` 3.1.6. Installed package
manifests and CMake were inspected. [Rive Native](https://pub.dev/packages/rive_native/versions/0.1.11)
provides Windows renderer libraries; the build downloads and bundles them.
[share_plus](https://pub.dev/packages/share_plus/versions/13.3.1) supports Windows
file sharing. [url_launcher_windows](https://pub.dev/packages/url_launcher_windows/versions/3.1.6)
is the endorsed Windows backend. Declared compatibility is not runtime proof;
exercise all three on Windows. Support still opens the default browser only after
user action, at `https://buymeacoffee.com/samirpandey`; all features remain free.

## Hardware acceptance checklist

Record Windows build, adapter/driver, band, artifact hash, consent state, actual
result and failures; do not include private SSIDs/BSSIDs in shared evidence.

- Start with no adapter, WLAN service unavailable, airplane mode and hardware/software
  radio off. Verify useful recovery, retained-data age and no demo substitution.
- Deny Location, disable it globally, re-enable it and retry. Check restricted
  desktop-app/policy configurations and settings navigation; no repeated prompts.
- Connect on 2.4/5/6 GHz where supported. Match BSSID/frequency/channel to trusted
  router/device evidence. Connected band selects data tabs until manual choice.
  Test disconnected, roaming and multiple-adapter cases without fabricated identity.
- Request rapid manual scans during automatic scans; pause/background/close during
  work. No overlapping starts, late history, crash, shutdown hang or restarted
  recording. Resume starts only relevant requests.
- Duplicate completions, cache-only results, timeouts, scan failure and an AP
  disappearing preserve honest freshness; only newer accepted scan completions add
  history/recording samples, with per-AP radio freshness explicitly unknown.
  Complete a same-BSSID guided recheck and save/compare two room sessions.
- Navigate Overview, Spectrum, Networks, Channels and Settings; check charts,
  favorites/aliases, connected-AP exclusion, filters and all saved comparisons.
  Restart and verify preferences/session persistence.
- Verify Wave icon/window branding, violet-to-indigo connection card, light/dark/system
  themes, keyboard focus, Escape/back, large text and reduced motion.
- Play and replay onboarding Rive scenes, background/resume and reduced motion.
  Verify visible animation and reliable exit, not merely a running ticker.
- Preview private summary/CSV with identifiers excluded; share both files through
  Windows UI, cancel and retry. Check real file contents and unknown outcome feedback.
- Use persistent warm amber Buy me a coffee CTA; verify default browser opens the
  exact HTTPS destination and failure remains recoverable. No feature is gated.
- Extract ZIP on a clean Windows x64 machine, test required VC runtime setup and
  launch offline. Production signing, SmartScreen reputation, installer and update
  download/restart behavior require separate release qualification.

Windows Shorebird setup and the current pinned-engine release constraint are in
[Shorebird updates](SHOREBIRD.md#windows).
