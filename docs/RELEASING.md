# GitHub release delivery

Version 1.0.2 downloads cover Android, Windows and Linux. macOS source remains
supported; its binary is withheld pending Developer ID signing, notarization and
a successful hardened-runtime launch check. iOS/web remain demo UI
and source targets, not downloadable supported releases.

1. Increment `pubspec.yaml` version/build, add `docs/releases/v<version>.md`,
   commit and push, then create the reviewed version tag on that exact commit.
   Keep Flutter pinned to `.fvmrc` and its immutable revision in `tool/flutter-revision`.
2. Run **Prepare desktop release** in GitHub Actions on that exact commit.
   Windows/Linux compile, run checks and package full bundles; only after both
   pass does the workflow create/update a **draft prerelease**. It never publishes
   automatically and refuses to overwrite a published release.
3. On the signing owner's Mac, build Android and macOS release artifacts from the
   same commit. Verify version and signing. When macOS distribution credentials
   are available, package the complete app with
   `ditto -c -k --sequesterRsrc --keepParent`, then attach those packages to the draft.
4. Generate `SHA256SUMS` from the exact uploaded binary packages. Verify
   checksums and download access, then publish the reviewed prerelease. For 1.0.2,
   checksum only the three runnable Android/Windows/Linux packages; do not upload
   the ad-hoc macOS structural-validation package.

## Android signing

`android/app/build.gradle.kts` reads ignored `android/key.properties` when present:

```properties
storeFile=/absolute/path/to/persistent-release.jks
keyAlias=wave-release
storePassword=<local-secret>
keyPassword=<local-secret>
```

The first public key and recovery properties are stored outside this repository at
`~/.config/wave-wifi-analyser/signing/`, with owner-only permissions. Back up both
files securely before changing machines. Keep the same key for all app upgrades;
never commit, attach or print these files. Production is the default and release
builds fail without complete signing properties and an existing keystore. No debug
fallback exists. `waveSigningPropertiesFile` can point Gradle at a private properties
file outside the checkout; its default is `android/key.properties`.

Explicit alternatives (never upload these as GitHub production APKs):

```sh
# Local release-mode development with a debug certificate:
ORG_GRADLE_PROJECT_waveSigningMode=development fvm flutter build apk --release
# F-Droid signs this itself; no local signing properties are read:
ORG_GRADLE_PROJECT_waveSigningMode=unsigned fvm flutter build apk --release
```

Before production packaging, use `fvm flutter pub get --enforce-lockfile`, then build
normally with `fvm flutter build apk --release`. Before upload, verify the exact APK:

```sh
python3 tool/android/verify_apk.py build/app/outputs/flutter-apk/app-release.apk \
  --certificate-sha256 "$WAVE_RELEASE_CERT_SHA256" --version-name 1.0.2 --version-code 3 \
  --apksigner "$ANDROID_HOME/build-tools/36.1.0/apksigner" \
  --apkanalyzer "$ANDROID_HOME/cmdline-tools/latest/bin/apkanalyzer" \
  --aapt2 "$ANDROID_HOME/build-tools/36.1.0/aapt2"
```

Supply the expected **public certificate fingerprint** from independently retained
release metadata, never from the candidate APK itself. This checks signer, package,
version, non-debuggable/test-only flags and compiled backup/transfer exclusions.
APK checks do not exercise real-device backup/restore or manufacturer transfer behavior.
A different signing certificate cannot upgrade older development installations.

## macOS signing

The current app is ad-hoc signed and has no Developer ID/notarization credential.
Disclose this in release notes; do not call it notarized or App Store approved.
Release disables Xcode base-entitlement injection (`CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`)
and enables hardened runtime. The default ordinary Flutter profile contains no
JIT/unsigned-memory exception. Xcode's default base injection caused the old
`get-task-allow` entitlement despite its absence in the source plist. See
[Apple notarization guidance](https://developer.apple.com/documentation/security/resolving-common-notarization-issues).

Build ordinary Flutter with `fvm flutter build macos --release`. Package using a
staged copy so the original build stays intact:

```sh
python3 tool/macos/package.py "build/macos/Build/Products/Release/wave - wifi analyser.app" \
  dist/wave-wifi-analyser-macos-validation.zip --identity - --allow-adhoc-validation
```

This creates an **ad-hoc structural-validation package, not a runnable distribution**. It signs nested code
inside-out with runtime enabled, checks every Mach-O architecture and nested
signature, then extracts the final ZIP with `ditto` and repeats checks. Both host
architectures are required. Ordinary Flutter forbids unsigned executable memory;
Shorebird permits it only on the host with `--shorebird`.

For production, supply `--identity "Developer ID Application: …"`, omit
`--allow-adhoc-validation`, submit with the owner's notarization credentials, staple,
and re-run `tool/macos/verify_distribution.py` on the final extracted app plus
`spctl --assess --type execute --verbose` and `xcrun stapler validate`. Developer ID
and notarization are unavailable here; ad-hoc checks do not establish publisher
identity, launch compatibility or notarization. On this Mac, the hardened ad-hoc
bundle aborts at startup because dyld library validation requires a valid matching
Team ID for the host and embedded frameworks. Keep library validation enabled;
complete Developer ID signing with one Team ID across all code, then launch-test
and notarize the final app. No release is automatically published by these scripts.
Never disable Gatekeeper or other system protections.

## Updaters and experimental platforms

These GitHub packages are ordinary Flutter builds; no Shorebird baseline/patch is
registered by this workflow. They do not receive Shorebird updates. The documented
Windows Shorebird engine hold remains in force and the SDK pin stays unchanged.
Windows/Linux physical WiFi behavior remains untested even after native CI passes.
Linux uses the documented Ubuntu 24.04 x64 baseline. Preserve those limits in notes.
