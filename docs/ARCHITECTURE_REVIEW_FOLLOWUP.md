# Architecture review follow-up

Date: 2026-10-12. Follows the [original review](ARCHITECTURE_REVIEW.md) of commit `cc7cf71`. The original report remains historical evidence.

## Resolved findings

| Finding | Completed change | Regression evidence |
| --- | --- | --- |
| Page/widget ownership and broad subscriptions | Home reduced from 1,119 to 93 lines. Five cohesive pages share panels, headings, tiles, details, metrics and connection card. Shell owns navigation; scoped consumers own data changes. | Phone/desktop light/dark flows; signal-only changes preserve sidebar/settings build boundaries. |
| Preference save failures | Serialized/coalesced writes catch storage failures, including unsuccessful storage returns. Optimistic choices remain usable with dedicated error feedback and retry. Slider previews write only on release. | Failure/retry tests and stale failed-write test; slider preview/persistence check. |
| Preference hydration race | Field revisions prevent delayed loading from overwriting early user edits. | Delayed Completer load retains newer theme and signal threshold. |
| Hidden retained search | Networks page owns/disposes controller, restores retained query and synchronizes external edits. | Search, navigate away/return, clear; repeated across sizes/themes. |
| Repeated scoring | Derived providers cache filtered/sorted data and channel ratings. Normalization is computed once outside row construction. Frozen collections retain identity on unrelated state copies. | Query edits preserve scoring identity; normalized rows remain within zero to one. |
| Painter responsibilities/repaint | Separate grid, history, spectrum and axes methods share SpectrumAxis. Repaint compares rendered content and colors. Axis includes accepted 4.9 GHz envelopes. | Equivalent inputs skip repaint; changed data/history/band/theme repaint; 4.9 GHz range test. |
| Scan/demo orchestration | Demo source separate from domain models. Scan entry delegates permission, demo generation and deadline handling. Repository turns malformed native data into recoverable platform errors. | Denial, malformed data, deadlines, pause/background/disposal, stale replies and demo stream-error checks. |

Additional fixes: public WifiSnapshot freezes incoming lists; AP histories and timestamp entries share a 256-entry bound. An eviction timestamp floor prevents replayed data from creating new samples after eviction, while a batch captures its initial floor so its first observations remain eligible. Unknown/evicted APs older than the floor are conservatively skipped until a newer scan timestamp arrives. Retained APs continue using their own last timestamps. Demo/live switching resets native dedupe state.

## Maintained AI guidance

- [AGENTS.md](../AGENTS.md): concise routing, code map, delivery rules and operational invariants.
- [Architecture rules](../ai/rules/flutter-architecture.md): single maintained source for Flutter/Dart standards.
- [Review skill](../ai/skills/wave-architecture-review/SKILL.md): focused project-local review/refactor workflow with scoped evidence and proportionate checks.
- [Validation script](../ai/scripts/check.sh): repeatable format, analysis and tests; accepts targeted test paths and FLUTTER_BIN override.

No global skills, unrelated agent framework or empty role scaffolding was installed. Independent reviewer inspected application changes and AI guidance; final validation evidence follows below.

## Validation

- `ai/scripts/check.sh`: 30 Dart files formatted, zero changes; analysis clean; 28 unit/widget tests passed.
- `flutter test integration_test/native_wifi_test.dart -d emulator-5554`: one native bridge integration test passed on isolated Wave_WiFi_Test emulator before the final Dart-only eviction-floor fix. Native contract was unchanged; final unit suite covers the eviction fix.
- Skill creator `quick_validate.py`: project-local review skill valid. `bash -n ai/scripts/check.sh`: valid.

- `flutter build apk --debug` and `flutter build web`: succeeded on final source. Regular app APK refreshed in `dist/wave-wifi-debug.apk`.
- Independent architecture reviewers found no remaining actionable findings; a final narrow reviewer also approved the eviction-floor change and AI guidance. Emulator tests do not establish physical RF behavior; numerical performance and large-result lazy scrolling remain outside this review's evidence.
