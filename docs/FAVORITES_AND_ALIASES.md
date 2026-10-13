# Favorites and local aliases

Delivered 2026-10-13, product review rank 3. Ranks 4–6 remain proposals.

Favorites and aliases use normalized BSSID identity, independently of SSID, scan
order, chart selection and display filters. Networks exposes Favorites and Saved
aliases across all bands. Detail sheets provide explicit add/remove favorite and
add/edit/remove alias controls with cancellation, finite sheet/dialog transitions,
press feedback and discrete haptics. Original SSIDs remain visible beside aliases;
legends add channel and short BSSID context. Missing saved APs show “Not seen” and
identity only, without constructing AccessPoint observations or adding timestamps
or history samples.

An injectable repository stores a version 1 JSON envelope locally, reads version
0 BSSID-keyed entries, and rejects malformed/unsupported data without replacing
it. Saved entries and pending hydration patches are capped at 256 identities;
aliases are capped at 64 UTF-16 code units with dialog validation. Encoded writes
are bounded by the same size accepted by loading. Early edits merge fieldwise
with loaded identities; writes serialize and coalesce revisions. Load failures
retain pending choices without overwriting unknown saved data; save failures keep
optimistic choices with explicit retry feedback separate from scan status.

Verification:

- `ai/scripts/check.sh`: formatting, static analysis and 108 unit/widget tests passed.
- Android emulator: preference editing, persistence through a recreated provider
  container, missing-favorite honesty, and chart exploration/selection/scroll
  regression passed (`integration_test/ap_preferences_test.dart` and
  `integration_test/chart_exploration_test.dart`). These checks use fixtures, not
  RF measurements.
- Widget coverage includes 360px width, 3× text, both themes, reduced motion,
  alias cancellation/removal, absent alias-only management, same-SSID legend
  identity, emoji limit feedback and save-error retry.
- Persistence coverage includes delayed hydration, fieldwise early edits,
  repeated mutation coalescing, bounded pending removals, full-store hydration,
  accepted-edit saving after overflow rejection, migration, malformed/unknown
  schema handling, relaunch and encoded-size protection.
- Independent architecture review found four concrete issues: missing alias-only
  removal access, recursive pending-edit accumulation, emoji limit mismatch and
  accepted edits not saved after hydration overflow. All fixed and re-reviewed;
  no remaining concrete findings in reviewed scope.
- OnePlus 15 (CPH2745, Android 16): release updated with `adb install -r`; existing fine/coarse location grants retained. ADB touch checks added a favorite and alias, force-stopped/reopened the app, confirmed both persisted, and observed the saved AP absent from current results with identity-only “Not seen” feedback. Removed both temporary choices afterward. This is one native workflow check, not broad RF qualification.
- Android release APK built. Existing Rive plugin emits a future Kotlin plugin
  compatibility warning; build succeeds with pinned Flutter 3.47.5.

No new permissions, services, background scan policy or measurement/scoring
changes. These checks do not establish physical RF coverage or a frame-rate claim.
