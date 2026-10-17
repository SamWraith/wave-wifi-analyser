# Wave architecture and Flutter/Dart quality review

Reviewed: 2026-10-12. Commit: `cc7cf719381219850bceb97814c0b927ae298496`.

**Verdict: NEEDS CHANGES.** MVVM and Riverpod foundations are present, but the presentation layer does not yet meet the requested widget decomposition and reuse standard. Several preference and navigation edge cases also need fixes. Static analysis passing is not architecture approval.

This was an independent architectural agent review. Application source was read only; this report is the sole review artifact added. Scope: all application Dart files, unit/widget tests, Android bridge, native integration test, and analyzer configuration. No applicable on-disk AGENTS.md was found in the project or checked ancestors. Sibling Folio's validation records (`docs/validation/chm.md:85`, `docs/cbr-validation.md:44`) establish independent review plus regression checks after fixes; they do not supply a reusable architectural agent configuration. No Folio code was copied.

## Prioritized findings

### 1. P2 — Extract cohesive widgets and narrow provider subscriptions

Location: `lib/views/analyser_home.dart:25`, particularly whole-provider watch at line 32, sidebar at 105, overview at 367, connection card at 456, chart panel at 593, network row at 781, detail sheet at 851, and settings at 1009.

One 1,119-line State class owns five pages, all cards, navigation, graph mode, and the bottom sheet. Private helper methods offer some source reuse but do not establish independently reusable widgets or element-level rebuild boundaries. Every scan, query, minimum-RSSI edit, and preference change rebuilds the complete active page and sidebar; unrelated settings controls also rebuild with scan updates. This is an observable dependency structure, not a measured performance regression.

Minimal fix: keep responsive shell/navigation in AnalyserHome; extract OverviewPage, SpectrumPage, NetworksPage, ChannelsPage, SettingsPage and AccessPointDetailsSheet. Extract actual shared pieces such as WavePanel, SectionHeading, NetworkTile, MetricCard, EmptyState and chart panel where callers already reuse them. Give presentational widgets explicit data/callback inputs; use focused ConsumerWidgets/selectors only where needed. Keep graph-mode state inside chart panel and query-controller state inside NetworksPage. Do not create generic abstractions for every Row or SizedBox. There is no universal good function/file line limit; the problem here is mixed ownership and subscriptions.

Verification: retain existing mobile/desktop/light/dark checks; add targeted widget tests for shared NetworkTile/detail sheet and confirm unrelated settings/sidebar sections do not rebuild for signal-only updates. Profile before claiming numerical gains.

### 2. P2 — Handle preference save failures at the ViewModel boundary

Location: `lib/viewmodels/analyser_view_model.dart:234` and `:239`; callers `lib/views/analyser_home.dart:260`, `:1028`, `:1083`; persistence `lib/repositories/settings_repository.dart:34` and `:39`.

Both setters optimistically update state then await persistence without error handling. Void UI callbacks discard the returned Futures, so storage exceptions become unhandled asynchronous errors and users receive no indication that changes will be lost on restart. Repository also ignores the boolean success result from SharedPreferences.setInt. Load failures are handled; save failures are not.

Minimal fix: make repository report failed writes, catch expected persistence errors inside ViewModel, and expose a recoverable save error (or roll back only if the failed request still represents the latest user choice). Serialize/coalesce rapid minimum-RSSI writes or persist on slider onChangeEnd, retaining immediate display updates. Explicitly handle fire-and-forget Futures; spelling unawaited alone does not handle errors.

Verification: fake settings repository that throws and one that reports failed writes; assert no uncaught error, useful feedback, and a newer user selection is not rolled back by an older failed write.

### 3. P2 — Protect early user preferences from initialization overwrite

Location: `lib/viewmodels/analyser_view_model.dart:42`, `:48`, `:50`, `:234`, `:239`.

Initialization runs after first state publication, and settings controls are immediately usable. If load() is pending, setTheme/setMinimum changes state, then a delayed older preference result overwrites those fields. UI can show one choice while storage contains the newer one. Existing tests await vm.ready before edits and cannot catch this sequence.

Minimal fix: track field-specific preference revisions and apply loaded values only to untouched fields, or disable just those controls until preference hydration completes. Preserve mounted checks. A request epoch for scanning does not solve this settings race.

Verification: hold load() with a Completer; select a new theme/threshold; complete load with old values; assert both displayed and stored final values retain the newer choice.

### 4. P2 — Keep network search input synchronized with retained filter

Location: `lib/views/analyser_home.dart:59` and `:768`; retained filter `lib/models/analyser_state.dart:54`.

Networks page creates TextField without a controller/initial query binding. Switching to Settings or another page removes the field, but analyser state retains query. Returning creates an empty-looking search box while results remain filtered by the previous text. Users cannot see the active filter.

Minimal fix: owned TextEditingController in extracted NetworksPage, initialized from retained query and disposed correctly, with synchronization if external query edits are supported; alternatively clear query deliberately when leaving the page. Choose one consistent behavior.

Verification: search "Studio", leave Networks, return, and assert field text and results agree; clear query and assert full results return.

### 5. P2 — Calculate channel ratings once per data/filter change

Location: `lib/views/analyser_home.dart:948` and `:949`; getter `lib/models/analyser_state.dart:63`; scorer `lib/models/access_point.dart:79`.

Each channel row invokes s.ratings again to find the maximum. That getter reruns all candidate/AP overlap calculations and sorts the result, even though the outer iteration already calculated ratings. With C candidates and A access points, scoring work increases from approximately O(C*A) to O(C*C*A) for this page, before repeated getters elsewhere. Provider updates unrelated to scoring trigger the same work.

Minimal fix: obtain one ratings list, compute max once outside row construction, and pass ChannelRating plus normalized amount into reusable ChannelRatingTile. Consider a derived provider keyed by accessPoints, band, excludeConnected when reuse warrants it. Likewise compute visiblePoints once per relevant build instead of repeatedly sorting/filtering it.

Verification: keep existing scoring tests; add a Channels page behavior test covering zero interference and normalized row values. A benchmark is optional unless claiming measured improvement.

### 6. P3 — Split painter responsibilities and implement change-based repaint

Location: `lib/widgets/signal_charts.dart:85`, duplicated band bounds at `:147`/`:202`, and unconditional shouldRepaint at `:223`.

paint() mixes grid layout, time-series extraction, spectrum envelopes, tick mapping and labels across 136 lines. Band bounds appear twice. shouldRepaint always returns true, so a parent rebuild for an unrelated preference/status can repaint an unchanged chart. The single existing SignalChart widget is a good starting point, but painter responsibilities are insufficiently separated.

Minimal fix: extract grid, history paths, spectrum paths and axes into focused private drawing methods, use one band-axis definition, and compare all relevant inputs including theme colors in shouldRepaint. A stable derived immutable chart input makes comparison reliable; identity checks against newly-created lists alone will not reduce repaints. Add RepaintBoundary only if profiling shows independent repaint isolation helps.

Verification: assert shouldRepaint false for equivalent inputs and true for changed band/data/history/theme. Retain nonzero-width chart test. Axis regression coverage should include accepted 4.9 GHz access points: native scan accepts them (`MainActivity.kt:99`) but current 5 GHz painter bounds start at 5150 MHz and clip their envelopes.

### 7. P3 — Separate demo generation from scan orchestration; extend failure coverage

Location: `lib/viewmodels/analyser_view_model.dart:154`; missing failure-path coverage visible in `test/controller_test.dart:83` onward.

scan() spans 79 lines and owns demo generation/history updates, permission requests, platform invocation, timeout scheduling and exception-to-status mapping. ViewModel is correctly located but has accumulated distinct responsibilities. Demo fixture data also lives alongside production domain models in access_point.dart:116. Existing three ViewModel tests cover important cases but leave disposal, lifecycle changes, permission denial, scan timeout and repository failures untested. Integration test checks native snapshot shape/basic state, not successful physical RF scanning.

Minimal fix: extract a small demo data source and focused permission/native-request/deadline helpers; retain one orchestration entry point and current epoch/mounted safeguards. Normalize platform payload decode failures in repository rather than letting arbitrary cast errors bypass the ViewModel's PlatformException catches. Add focused behavior tests for relevant error/lifecycle cases, not tests that merely mirror every helper.

Verification: permission denial preserves sane busy state; pause/background/disposal rejects late replies; timeout displays cached state; malformed payload produces recoverable failure; native stream errors during demo do not overwrite simulated-data status. Use fake clocks/timers for deadline checks. No new service framework or layer of use-case classes is needed.

## Existing strengths

- Actual MVVM separation: views call ViewModel; platform channels live in WifiRepository; SharedPreferences lives in SettingsRepository. Riverpod providers support overrides and focused fake-based tests.
- Root WaveApp uses theme-only select (`lib/app.dart:12`) instead of rebuilding MaterialApp for every scan.
- AnalyserState defensively copies and freezes AP lists and nested history (`lib/models/analyser_state.dart:30`). ViewModel bounds history to 60 samples and 256 AP histories; timestamps avoid treating cached broadcasts as new samples.
- Epoch/mounted checks guard stale asynchronous scan replies. Timers, subscriptions and WidgetsBinding observer are cleaned up on provider disposal. Native receiver registration has matching unregister paths.
- Shared SignalChart, theme factory and helper reuse already prevent some duplication. Responsive layout and explicit demo labeling are covered across two window sizes and both themes.
- Channel scoring is a documented independent heuristic, with meaningful tests for bandwidth, band, power, and connected-AP exclusion. Platform/reverse-engineering limitations are stated rather than presented as verified equivalence.

## Follow-up observations

- WifiSnapshot declares @immutable but its public const constructor accepts a mutable accessPoints list (`lib/models/analyser_state.dart:103`); only fromMap wraps it. AnalyserState freezes it before UI use, so this is lower priority. Enforce immutable constructor inputs if snapshots become shared/cached more broadly.
- _lastTimestamp map (`lib/viewmodels/analyser_view_model.dart:27`, `:127`) has no matching eviction when history caps at 256. Long-running roaming sessions can retain every observed BSSID. Keep its lifetime/bounds aligned with history or explicitly document intended retention.
- Native bridge is currently small enough for MainActivity, but mapping/security classification and channel wiring are separate concerns. Extract an owned native bridge/plugin class when this integration grows, preserving lifecycle registration and permission reply handling. No immediate plugin-package scaffold is warranted.
- Network rows are eagerly built in a Column inside SingleChildScrollView (`lib/views/analyser_home.dart:777`). Consider lazy slivers for demonstrably large result sets; do not add a nested shrinkWrap ListView as a reflexive fix.

## Validation and limitations

Main agent independently ran `flutter analyze` (no issues), `flutter test` (10 passed), and `dart format --output=none --set-exit-if-changed lib test integration_test` (14 files, zero changes) during this review. These confirm static/test/format baseline only. Review findings above come from source inspection; proposed regression tests were not added or run. Physical-device RF behavior, performance profiles, accessibility audit and fresh native integration run were outside this architectural review. No application fixes are claimed.

## Standards used

- [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations): explicit responsibilities, repositories, ViewModels and testable ownership.
- [Flutter performance best practices](https://docs.flutter.dev/perf/best-practices): prefer reusable StatelessWidget classes over helper functions, split widgets by encapsulation/change, and use lazy construction for large collections.
- [Riverpod select](https://riverpod.dev/docs/how_to/select): subscribe to relevant slices of immutable state and use selection when reduced rebuild work warrants complexity.

Recommended sequence: preference error/race and search correctness fixes; extract page/shared widgets with focused state subscriptions; cache derived scoring and split painter/scan methods; add regression coverage and rerun review. Keep behavior-preserving extraction separate from changed failure handling for straightforward diffs.
