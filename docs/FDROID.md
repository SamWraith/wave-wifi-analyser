# F-Droid submission preparation

Wave is **not yet listed on F-Droid**. Listing requires F-Droid's inclusion review
and a successful build using its infrastructure. A GitHub release APK alone is
not an official F-Droid package.

Packaging request submitted on 17 October 2026:
[F-Droid RFP #4587 — Wave WiFi Analyser](https://gitlab.com/fdroid/rfp/-/work_items/4587).
The request discloses the remaining native dependency and unsigned build review;
submission is not approval or a published download.

## Project identity

- App: Wave WiFi Analyser
- Android application ID: `com.samirpandey.wifi_analyser`
- Source: https://github.com/SamWraith/wave-wifi-analyser
- App license: `GPL-3.0-or-later`, with copyright/origin in root `NOTICE`
- Current app version: `1.0.2+3`
- Listing: `fastlane/metadata/android/en-US/`
- Inclusion request draft: `docs/fdroid-inclusion-request.md`

The GPL license is on the current branch. The existing `v1.0.1` tag predates the
license and listing additions; do not assume that tag contains these files.
Select a reviewed commit containing the license for an initial build recipe.

## Build review still required

Use ordinary Flutter **3.47.5**, as pinned in `.fvmrc`, rather than a Shorebird
engine. The ordinary GitHub APK has no Shorebird updater. The repository retains
Shorebird configuration for separate distribution experiments; its presence is
not evidence that a standard Flutter build downloads executable updates.

`rive_native` **0.1.11** is MIT-licensed. Its normal setup downloads native
libraries. F-Droid must review their provenance or use its upstream source-build
route. Do not label this dependency proprietary, and do not claim its source-build
route is already verified on F-Droid.

Upstream documents a source-build command:

```sh
dart run rive_native:setup --build --clean --verbose --platform android
```

Its bundled native runtime configuration requires Android NDK r27c
(`27.2.12479018`); the app's pinned Flutter SDK defaults to NDK
`28.2.13676358`. These serve different build steps. Use an isolated `PUB_CACHE`
when investigating native builds, since `--clean` changes the cached package's
native libraries. Inspect and pin native build dependencies and network fetches
before proposing a production recipe. No Rive source build or F-Droid scanner
pass has been completed for this app.

Android production release builds fail without complete local signing properties.
An F-Droid recipe must explicitly select the unsigned mode, which does not read
local signing properties:

```sh
ORG_GRADLE_PROJECT_waveSigningMode=unsigned fvm flutter build apk --release
```

Verify the resulting APK has no signing certificate before F-Droid signs it.
Never send the GitHub distribution key to F-Droid or commit it to this repository.

Unless reproducible upstream-signature verification is separately arranged,
F-Droid signs its builds with a different certificate. Users cannot update an
existing GitHub-signed installation in place with a differently signed package.

## References

- [Inclusion policy](https://f-droid.org/docs/Inclusion_Policy/)
- [Submission guide](https://f-droid.org/docs/Submitting_to_F-Droid_Quick_Start_Guide/)
- [Request for packaging](https://gitlab.com/fdroid/rfp/-/issues)
- [Rive native package](https://pub.dev/packages/rive_native)
