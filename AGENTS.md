# Wave agent guide

This file applies throughout this repository. User instructions take precedence.

## Start here

- Product: **wave - wifi analyser**, a Flutter app using MVVM and Riverpod.
- Read [Flutter architecture rules](ai/rules/flutter-architecture.md) before changing application code. They are the maintained project standard.
- For architecture/code-quality reviews or substantial refactors, read [wave-architecture-review](ai/skills/wave-architecture-review/SKILL.md). For a small isolated change, use the relevant rule sections without loading the review skill.
- [ai/README.md](ai/README.md) indexes guidance; load only material relevant to the task. Historical reports in `docs/` are evidence, not current instructions.

## Locate work efficiently

- `lib/views/`: responsive shell, pages, presentation providers and theme.
- `lib/widgets/`: shared UI and chart rendering; widgets receive explicit inputs where possible.
- `lib/viewmodels/`: Riverpod state transitions, scan orchestration and lifecycle.
- `lib/models/`: immutable state and WiFi/channel domain logic.
- `lib/repositories/`: Android platform boundary, settings storage and explicit demo source.
- `android/app/src/main/kotlin/com/samirpandey/wifi_analyser/MainActivity.kt`: native WiFi bridge.
- `test/`: unit/widget regressions; `integration_test/`: native bridge checks.
- Motion/high-refresh work: read `docs/MOTION_AND_REFRESH.md`; use FVM pin, keep haptics presentation-owned and validate performance on physical hardware before claiming 120 fps.
- Onboarding/Rive work: read `docs/RIVE_ONBOARDING.md` for asset names, editable source and native test setup.

Start with `git status --short`, then use `rg` and focused file reads. Preserve unrelated work. Do not ingest raw `research/` JSON/decompiled sources, build output, dependencies or entire sibling repositories to answer an ordinary coding question.

## Delivery and review

- Preserve modern light/dark/system themes and responsive phone/desktop behavior.
- Treat minor interaction details as product requirements: intuitive affordances, complete feedback and restrained motion. Apply the interaction-quality section in `ai/rules/flutter-architecture.md` to every UI change.
- For multi-page changes, provider lifetime changes, persistence changes or native contract changes, review architecture before finalizing. Use an independent review agent when delegation is available and authorized; otherwise make a separate review pass and state that limitation.
- Delegate only independent owned file groups; share interface changes before editing overlapping files. Integration and final validation remain the primary agent's responsibility. Do not create unrelated user chats.
- Fix concrete findings within authorized scope. Avoid feature expansion, speculative frameworks and repeated broad validation after a clean final run.
- Run `ai/scripts/check.sh` for a broad refactor, or pass relevant `test/..._test.dart` files for isolated work. Build Android/web when startup, platform integration or packaging changes warrant it. Native integration requires an available Android target.
- Report changes, checks actually run and remaining limitations. Passing tests are not proof of physical RF behavior or a performance claim. Do not mark an unresolved architecture finding closed merely because analysis passes.
- Commit/push only within user-authorized scope. APKs, signing files, raw decompilation and local logs stay excluded from Git.

## Operational invariants

- Android performs live scans; unsupported targets use clearly labelled demo data.
- Foreground requests are 35 seconds apart; Android controls actual scan availability. Demo updates every 3 seconds. Pause/background/disposal must stop timers and ignore late replies.
- Cached/duplicate native timestamps must never create fresh history. Keep history and timestamp retention bounded together: 60 samples per AP, 256 AP histories.
- Channel ratings are an independent overlap heuristic. Preserve frequency exceptions, reported width/center frequency and honest distance/graph limitations.
- Persisted preferences must survive early edits during loading and recoverable write failures. Keep storage errors separate from scan status.
