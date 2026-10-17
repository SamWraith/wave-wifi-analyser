# Security remediation — 17 October 2026

Maintained repository: `wave-wifi-analyser`. Audit baseline: `244bf83`.
Implementation starts from `ed82445`, which already includes the router finder.
Router-finder source/tests and `network_tile.dart` were preserved. No commit,
push, release publication, credential change or history rewrite was performed.

## Finding disposition

| Finding | Implemented control | Remaining limit |
| --- | --- | --- |
| WAVE-01 | `allowBackup=false`; explicit exclusions for all app storage domains in legacy rules and both Android 12+ cloud/transfer sections. Updated README, app and Android listing privacy language. | Compiled APK policy verified; real OS backup/restore and OEM device transfer not exercised. Earlier backups are not erased. Desktop account/filesystem backups can include records. |
| WAVE-02 | Release disables Xcode base-entitlement injection and enables hardened runtime. Ordinary Flutter and Shorebird use separate entitlement profiles. Staged inside-out signing and final ZIP extraction enforce every Mach-O slice's runtime/entitlements and nested signatures. | Developer ID identity unavailable (zero valid signing identities). Local structural-validation artifact is ad-hoc/unnotarized and fails native startup: dyld rejects the host/framework signing Team IDs under library validation. WAVE-02 remains open for production delivery; Developer ID signing is required. Public v1.0.1 is unchanged. A signed, notarized replacement still requires owner credentials and publication. |
| WAVE-03 | Production release signing fails without complete properties/keystore. Explicit `development` and `unsigned` modes do not read private signing properties. APK gate checks trusted certificate fingerprint, package/version, non-debuggable/test-only flags and actual manifest-linked compiled backup policies. | APK identity checked against the audited public release certificate. F-Droid native dependency/source-build review remains separate. |
| WAVE-04 | Selection checked before preparation and handoff; per-operation owned folders; partial writes/stale preparation/dismissed chooser cleanup; 24-hour eligibility for retained handoffs; maximum 16 recent operation folders. Startup/share cleanup and explicit Settings clearing include Wave's known Android share-plugin copies. | Cleanup runs on next startup/share or explicit request; no wall-clock deletion while app is closed. Unknown/throwing native handoffs retain files because delivery is uncertain. OS/receivers may retain independent copies. Android plugin may replace its copy on a later share. Deleting a saved session does not revoke already handed-off copies. |
| WAVE-05 | Current documentation uses repository-relative/input-placeholder paths; trace helper takes APK/JADX arguments. Tracked/unignored-source gate rejects private home paths. | Historical README/docs retain old paths. History unchanged; no credential rotation warranted solely by path exposure. |
| WAVE-06 | Actions pinned to full verified upstream SHAs; checkout credential persistence disabled; Dependabot updates configured. Flutter 3.47.5 checked against recorded immutable revision. Draft updates require tag SHA and draft target equal workflow source. | Workflow YAML/source checks run locally; hosted Windows/Linux jobs and GitHub draft mutation not executed. No new attestations or reviewed Gradle transitive dependency-verification metadata claimed. |

## Verification

- `ai/scripts/check.sh`: formatting, source privacy/workflow policy, clean static
  analysis and full Flutter suite: **245 passed, one platform-specific skip**.
- Cancellation before preparation, selection change during preparation, dismissed
  chooser deletion, unknown handoff retention, unique export files, expiration,
  count bounds, legacy-file cleanup, plugin-copy lifetime and explicit Settings
  confirmation/busy/success/failure covered by regressions.
- Android production build succeeds. APK signer matches the independently retained
  audited v1.0.1 APK certificate. Manifest and linked compiled XML exclusions pass.
  Explicit unsigned build has no certificate; explicit development build uses
  Android Debug; both are rejected by the production artifact gate. A missing
  production properties file is rejected by `preReleaseBuild`. Wrong expected
  certificate is rejected.
- Universal macOS release builds. Final ZIP extracted with `ditto` passes strict
  deep verification plus runtime/entitlement checks on **eight Mach-O slices**,
  including arm64/x86_64 host and nested code. Structural verification is not a launch check. Native startup smoke test aborts with SIGABRT: dyld rejects embedded FlutterMacOS under library validation because the ad-hoc host/framework do not establish a valid matching Team ID. No library-validation exception was added. Ordinary profile contains no
  debugging/JIT/unsigned-memory exceptions. Negative checks on temporary staged
  real bundles reject ad-hoc production identity, injected `get-task-allow` and
  missing hardened runtime.
- Shorebird override resolved with `xcodebuild -showBuildSettings`: dedicated
  entitlement profile, base injection disabled, hardened runtime enabled. No
  Shorebird release/patch was registered or published; signed patch rejection and
  rollback remain prerequisites for future public Shorebird distribution.
- Web release compiles. Workflow/Dependabot YAML parses; Python scripts compile;
  trace helper accepts CLI arguments. Synthetic isolated Git repositories prove
  source gate rejects private paths and mutable action tags. Recorded Flutter
  revision matches the upstream 3.47.5 tag.
- Separate architecture/diff review completed by the implementing agent;
  independent agent review was not authorized. Cleanup state is ViewModel-owned,
  filesystem work repository-owned, and widget forwards confirmed intent.

## Local artifacts and delivery

Final local packages (ignored by Git, never uploaded):

- `dist/wave-security-remediated-android.apk`
- `dist/wave-security-remediated-macos-validation.zip` (structural checks only; startup blocked)

These validation artifacts retain the current version/build. Follow
[release instructions](RELEASING.md), increment the next public version/build,
rebuild from the reviewed commit, verify final artifacts and use owner-controlled
signing/notarization before release. The ad-hoc macOS validation package is not runnable distribution and is not proof of publisher
identity or notarization. Production delivery remains blocked on owner signing credentials. Do not disable Gatekeeper or other system protections.

Policy references: [Android Auto Backup](https://developer.android.com/identity/data/autobackup),
[Apple entitlement injection and notarization](https://developer.apple.com/documentation/security/resolving-common-notarization-issues),
[Flutter macOS entitlements](https://docs.flutter.dev/platform-integration/macos/building).
