# Flutter and Dart architecture rules

## Ownership and reuse

Use MVVM with Riverpod. Views render state and forward user intent. ViewModels coordinate application state; repositories own platform/storage boundaries. Keep domain calculations independent of widget lifecycle and simulated fixtures.

Extract cohesive pages and reusable `StatelessWidget`/`ConsumerWidget` classes instead of accumulating private widget-building functions in one State class. Shared panels, headings, rows and metrics should have explicit typed inputs and callbacks. Keep page-local state/controllers with the owning page and dispose them. Do not wrap every Row or SizedBox in an abstraction; reuse must reduce real duplication or establish a meaningful rebuild/test boundary.

Functions should have one clear responsibility. Split mixed orchestration, generation, decoding and drawing steps into named operations. Function/file length prompts inspection, not an automatic numeric failure: a cohesive declarative widget can be longer than a tiny mixed-responsibility method. Avoid part files or inheritance used only to conceal a monolith.

## Riverpod and rendering

Watch the smallest relevant immutable slice. Navigation/static shell and settings must not subscribe to whole scan state without a reason. Use derived providers for shared filtering/scoring; preserve unchanged collection identity or meaningful equality so select actually avoids unrelated recomputation.

Calculate ratings, normalization and filtered/sorted lists once per relevant input change, not once per row or repeated getter call. Separate expensive computation from widget construction. For large result lists, use lazy scrolling/slivers rather than eagerly materializing all rows or nested shrinkWrap lists.

Custom painters should share one axis definition, separate grid/data/label responsibilities, and implement shouldRepaint using all rendered inputs including theme colors. Equivalent newly allocated lists must not cause unconditional repaint; changed history/frequency/width must still repaint. Profile before adding repaint boundaries or claiming speed gains.

## Motion and interaction

Keep decorative motion finite and tied to user intent or fresh data. Respect reduced-motion and accessible-navigation preferences; preserve widget/state identity when those preferences change. Keep animation state in presentation widgets, retain keyboard/focus semantics, and dispose owned controllers. Animate exact measured values with a transition rather than fabricating intermediate scan samples. Test cancellation and accessibility changes for shared interaction components.

Theme reveals must preserve the live route/widget tree, dispose captured images and guard stale asynchronous cleanup. Reset controllers before subsequent reveals and recheck reduced motion after asynchronous work. Keep mobile haptics tied to explicit user intent. Display refresh preferences are requests; qualify 120 fps on physical hardware in profile mode before claiming it.

For Rive, await runtime initialization before accessing factories. The owning illustration disposes its painter, artboard and file, ignores late loads, and pauses background advancement. Verify bundled artboard/timeline names against the real asset and test actual runtime playback when changing integration; mocked illustrations only validate the surrounding flow. Verify visibly changed rendered pixels, not merely a running ticker or existing timeline. Reserve known variable-copy slots for stable onboarding controls while retaining responsive width and accessibility text scaling.

## State, async work and failures

Public immutable models must defensively freeze collections, including nested history. Preserve unchanged frozen collections on copyWith. Native payload errors become typed recoverable repository errors, not arbitrary cast failures leaking into UI callbacks.

Keep loading, saving and scanning error feedback distinct. Optimistic preference edits must not be overwritten by delayed hydration or stale save failures. Serialize/coalesce writes where order matters, check unsuccessful storage returns and handle errors before discarding Futures. Use immediate slider preview with persistence on commit rather than storage writes for every drag event.

Guard asynchronous replies with mounted/lifetime and request-generation checks. Cancellation includes timers, stream subscriptions, native receivers and observers. Paused/background/demo state must reject irrelevant live events and errors. Keep history/timestamp maps bounded together. Do not treat cached native results as fresh observations.

Keep repositories injectable through providers. Demo generation belongs in an explicit data source and must never silently substitute for a failed Android scan.

## Verification proportional to changes

- Format and run static analysis on final source.
- Preserve phone/desktop and light/dark navigation checks after UI extraction.
- Add behavioral regression tests for changed failures, races, input synchronization, normalization, repaint decisions and cancellation. Use deterministic completers/fake clocks; do not wait real time for deadlines.
- Test meaningful boundaries and observable outcomes; avoid tests that mirror private helpers, count lines or match documentation wording.
- Run native integration when changing the platform contract; distinguish emulator checks from physical RF validation.
- Review resulting diffs for remaining duplication, oversized mixed responsibilities and broad subscriptions. Existing passing tests alone do not close architecture findings.

Use [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations), [Flutter rendering practices](https://docs.flutter.dev/perf/best-practices) and [Riverpod select](https://riverpod.dev/docs/how_to/select) when a framework-specific choice needs verification. Prefer installed APIs and official primary documentation over recollection.

For cadence qualification, use the normal-binding `tool/motion_probe.dart` or normal app profile in addition to functional integration tests. Integration-test scheduling can differ from the production binding. Report UI/raster budgets and interval distribution alongside median cadence; never treat a 120 Hz display-mode report as proof of 120 fps.
