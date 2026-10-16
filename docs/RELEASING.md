# GitHub release delivery

Public downloads cover Android, macOS, Windows and Linux. iOS/web remain demo UI
and source targets, not downloadable supported releases.

1. Increment `pubspec.yaml` version/build, add `docs/releases/v<version>.md`,
   commit and push. Keep Flutter pinned to `.fvmrc`.
2. Run **Prepare desktop release** in GitHub Actions on that exact commit.
   Windows/Linux compile, run checks and package full bundles; only after both
   pass does the workflow create/update a **draft prerelease**. It never publishes
   automatically and refuses to overwrite a published release.
3. On the signing owner's Mac, build Android and macOS release artifacts from the
   same commit. Verify version and signing, package the complete macOS app with
   `ditto -c -k --sequesterRsrc --keepParent`, then attach those packages to the draft.
4. Generate `SHA256SUMS` from the exact four uploaded binary packages. Verify
   checksums and download access, then publish the reviewed prerelease.

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
never commit, attach or print these files. Without `key.properties`, local release
builds retain the development debug signing fallback and **must not be uploaded**.
Verify public APKs with Android SDK `apksigner verify --verbose --print-certs`;
confirm the certificate is the Wave release identity and is not Android Debug.
A different signing certificate cannot upgrade older development installations.

## macOS signing

The current app is ad-hoc signed and has no Developer ID/notarization credential.
Disclose this in release notes; do not call it notarized or App Store approved.
Use `codesign --verify --deep --strict` and inspect architectures/Info.plist before
packaging. Do not disable Gatekeeper or other system protections in delivery scripts.

## Updaters and experimental platforms

These GitHub packages are ordinary Flutter builds; no Shorebird baseline/patch is
registered by this workflow. They do not receive Shorebird updates. The documented
Windows Shorebird engine hold remains in force and the SDK pin stays unchanged.
Windows/Linux physical WiFi behavior remains untested even after native CI passes.
Linux uses the documented Ubuntu 24.04 x64 baseline. Preserve those limits in notes.
