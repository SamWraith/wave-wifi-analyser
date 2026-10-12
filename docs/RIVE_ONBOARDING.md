# Rive onboarding

First launch shows three welcome steps before the analyser starts or requests
Android permissions. Skip and Start exploring save `onboardingComplete` through
the onboarding repository. A failed write keeps the welcome screen available
for retry. Settings → Replay welcome opens the same presentation without
resetting completion.

## Artwork

Original Wave artwork was authored with the Rive editor's local MCP server.
Editable source: https://editor.rive.app/file/untitled/2648120.
Bundled runtime asset: `assets/rive/wave_onboarding.riv`.

| Artboard | Interaction | Authored motion |
| --- | --- | --- |
| Wave Signal | Explore the signal | Expanding rings and signal satellites |
| Wave Channels | Compare channels | Channel heights and clear-channel indicator |
| Wave Access | See scan access | Privacy badge, checkmark and signal bars |

Each artboard is 480 × 400, has a transparent background, and contains an
`Explore` timeline lasting one second. Artboards are marked as components and
included in runtime exports; otherwise the editor exports only the main
artboard. Preserve these names when replacing the asset. Keep Rive's exported
branding intact.

The illustration owns its file, artboard and painter. It plays once on entry
and once per explicit replay button activation, then stops scheduling frames.
Backgrounding pauses advancement. Reduced motion shows the final authored
frame and disables replay. Loading failures retain the text and navigation
with a static icon; diagnostic details go to Flutter's error reporter.
Web uses Rive's default hosted WASM runtime and needs network access on initial
runtime load. Android ships native libraries in the APK.

## Verification

Use Flutter/Dart on PATH; Rive's Android build hook invokes `dart` directly.
For native asset tests on a fresh macOS checkout, initialize the host library:

```sh
flutter pub get
dart run rive_native:setup --platform macos
ai/scripts/check.sh
flutter test integration_test/onboarding_test.dart -d <android-device-id>
```

The asset test decodes every named artboard and applies its timeline. Welcome
tests cover storage loading, write retries, duplicate completion taps, scan
gating, phone/desktop layouts and both themes with enlarged text. Android
integration checks real Rive rendering, explicit replay, finite rest,
reduced-motion changes and disposal. These checks do not validate physical RF
measurements.
