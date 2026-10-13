# Private comparison export — 2026-10-13

Rank 6 from PRODUCT_REVIEW.md only. Native macOS scanning remains next;
Windows/Linux/iOS live scanning remains deferred.

## Delivered flow

Overview → Compare rooms → select one or more saved sessions for the same
BSSID/source → Preview private export. Both summary and CSV have exact selectable
previews, split into bounded contiguous text parts. All parts remain in the actual
files. Fixed share/return actions and scroll-bounded feedback stay reachable while
reviewing large evidence. Returning preserves saved-session selection.

SSID/BSSID and room labels start excluded, with independent explicit switches.
Aliases, internal session IDs and arbitrary stored stop reasons never enter files.
Generic filenames (`wave-comparison.txt`, `wave-comparison.csv`) and share metadata
contain no network identifiers. User-entered labels can include sensitive data;
reviewing an opt-in is essential. Timing and radio context may identify a place:
this feature makes no anonymity guarantee.

CSV preserves exact accepted timestamps as UTC ISO-8601, numeric RSSI,
primary frequency, reported width and raw reported center. Null centers remain
blank in raw columns and unknown in descriptions; zero and explicit centers remain
distinct. Summary groups raw radio tuples without pooling contexts, reporting
counts, median/range RSSI, wait to first sample, longest session gap and silence to
stop in millisecond units retaining accepted microsecond precision. Missing/cached update counts remain metadata. Empty sessions
export metadata and an explicit no-samples summary without synthetic observations.
Source is explicitly MEASURED or SIMULATED DEMO. Foreground/heuristic limitations
travel with both outputs; no noise, interference, throughput, combined-context delta
or guaranteed improvement is inferred. CSV textual cells are quoted, quotes escaped,
and formula-leading text prefixed with an apostrophe; numeric values stay numeric.

Sharing creates files only on button press and opens the system chooser. No account,
server upload, automatic telemetry, cloud integration, new runtime permission or
router configuration. Native preparation owns exactly two temporary source files,
overwritten on the next share; Android's plugin also keeps its bounded chooser
copies. System/receiving apps can retain copies. Preview navigation cancellation
during preparation prevents a late chooser; changed/deleted snapshots also block it.
A shared repository lock prevents overlapping preparation/choosers across routes.

Cancel is explicit; failures allow retry; selecting a receiving action is described
as handoff, never confirmed delivery. Platforms with unknown outcomes say so. Linux
file sharing is unsupported and offers copyable preview/return recovery without a
retry loop. Web requires browser file-share support; download/email fallbacks are
disabled. macOS/iOS/Windows plugin support is not device-qualified in this slice.

## Verification

- `ai/scripts/check.sh`: clean format/static analysis; all **165** unit/widget tests
  passed (141 existing + 24 new).
- New regressions cover private defaults, independent opt-ins, Unicode/quotes/newlines,
  malicious CSV cells, exact timestamps/values/gaps, raw null/zero/explicit-center
  boundaries, no-sample/source/identity guards and all 24 × 120 accepted rows.
- Platform-boundary tests verify exact preview bytes, filenames/MIME payloads,
  origin rectangle, result mapping and disabled web fallbacks. Owned-cache tests
  verify two files with stable paths and replacement of earlier opt-in content.
  Completers verify cancellation, duplicate share rejection and stale preparation.
- Widget tests cover discovery/selection return, opt-ins, cancellation/retry,
  failure/unknown/handoff feedback, deleted selection, route disposal/reopen,
  deletion during preparation and unsupported-platform recovery. Maximum records
  fit 320px width, 2× text, both themes and reduced-motion preferences; 320×640
  combined failure/deletion retains return. Desktop keyboard traversal/Enter
  activates the Material share action.
- Independent review used `ai/skills/wave-architecture-review/SKILL.md`. Initial
  findings (raw center grouping, large-preview actions, unsupported retry and
  unbounded plugin source-cache files) were fixed. Final independent re-review
  found no actionable findings. Recording/persistence were not changed.
- Android emulator integration exercised the real two-file chooser with simulated
  evidence, inspected private native cache bytes, dismissed with Android Back and
  verified cancellation/retry feedback. Native screenshot/logs stay outside Git.
- Final normal Android release build passed (77.5 MB); web build passed, including
  Wasm dry-run compilation. Normal release emulator smoke covered two saved demo
  sessions, both themes, summary/CSV selection, privacy opt-ins, real chooser,
  cancellation and return. A final `install -r` retained saved sessions and verified
  private defaults, sub-millisecond gap precision and chooser cancellation.

Physical OnePlus verification remains deferred by user; phone deliberately unplugged
and untouched. Emulator/test evidence does not qualify RF behavior, share delivery,
physical haptics, frame cadence or 120 fps. Existing Rive future Kotlin compatibility
warning remains non-blocking.
