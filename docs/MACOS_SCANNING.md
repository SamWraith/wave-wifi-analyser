# Native macOS scanning

Implemented 2026-10-14. Public CoreWLAN/CoreLocation APIs; local observations only.
Windows/Linux/iOS live scanning remains deferred. No discovery, throughput tests,
router configuration, accounts or telemetry added.

## Contract and limits

`WifiBridge` uses a retained `CWWiFiClient` and its vended interfaces, preferring
powered default hardware or a stable powered fallback. Explicit **Allow location**
requests CoreLocation authorization; privacy/Location and WiFi recovery open System
Settings with a readable fallback if the deep link fails. Both build entitlements
retain App Sandbox and grant Location access. No location coordinates are requested
or read. AppKit haptic feedback is best effort, discrete and subject to hardware,
accessibility and system preferences; perceived tactile output was not qualified.

Foreground automatic requests run every 35 seconds. Native actual starts are also
at least 35 seconds apart and serialized. Scan replies time out after 20 seconds;
CoreWLAN's blocking operation cannot physically be cancelled. Pause, background,
source change and disposal invalidate results; native generations prevent late work
from replacing its cache or opening another simultaneous scan. Permission replies
are bounded and guarded against obsolete timeout callbacks.

macOS snapshots carry explicit source, completion ID, completion flag, interface
availability and excluded-result counts. Cached snapshots and repeated IDs never
add history or recording samples. Successful new completions add one identifiable
AP reading per BSSID even if RSSI repeats. **These are completed-scan observations,
not a claim of fresh radio measurements.** CoreWLAN has no per-network measurement
timestamp or reliable cache age; scan cache may contribute. Age labels, history,
guidance, recording and export disclose this. Empty/redacted completed scans still
advance completion age without inventing AP samples.

Missing/invalid BSSID and unknown channel/band/width are excluded with counts;
no fabricated identities or default reported width. SSID can be hidden or unavailable.
Reported primary frequency and width are retained. Bonded center is unavailable
(`null`); illustrative chart/overlap geometry falls back to primary frequency with
existing contributor qualifiers. No inferred centers, noise or throughput.
Android continues to require newly accepted radio timestamps for history. History
remains bounded to 60 samples/AP and 256 APs.

## Evidence and compatibility

Demo, Android and macOS are explicit sources. Same-BSSID recordings, comparisons
and export also require same source. Storage v2 reads shipped v1 Android/demo records,
keeps exact accepted microsecond times and distinguishes null/zero/reported centers.
Limits remain 24 sessions, 120 samples/session and 1 MiB. Existing hydration/edit,
checked serialized writes and recoverable storage-error behavior remain.

Private export defaults, independent identifier/label opt-ins, neutral names,
selectable bounded preview and explicit native chooser remain. macOS export describes
accepted completion times and unknown per-AP/cache age; it never says measured Android
for Mac observations. No automatic sharing or delivery claim.

## Desktop interaction

Existing pages reuse sidebar at wide widths, compact rail at medium desktop widths
and bottom navigation in narrow windows. Scrollable sidebar/content and scaled panel
breakpoints keep short/large-text layouts reachable. Safe areas protect titlebar
insets; native minimum window size is 420×560. Cmd/Ctrl+1–5 changes page; Cmd/Ctrl+R
requests scanning. Focus/Material controls, pointer charts and scrolling remain;
Escape returns from focused charts, room comparisons and export. Finite Wave motion,
theme reveal and deliberate feedback retain reduced-motion behavior.

## Verification (2026-10-14)

- Normal release `.app` built and launched through computer-use, not a CLI scan probe.
  Overview clearly identified macOS, zero observations and Location recovery. Explicit
  request/pending, unavailable-interface and foreground-rejection paths were visible.
- Automated GUI context did **not** establish successful Location authorization or a
  live scan. It launched/operated the window in background; native foreground scans
  rejected that context, and snapshots reported unavailable CoreWLAN interfaces.
  Host read-only CoreWLAN/system inventory showed powered WiFi, which does not prove
  GUI app authorization. Public interface fallback did not produce verified scan data.
  A standard network-client entitlement trial produced no verified improvement and
  was reverted. No sandbox exception or privacy bypass retained. User deferred foreground
  hardware verification for now; no RF/haptic/frame-rate claim.
- Three native XCTest cases passed: client-vended interface fallback, identity
  exclusions and frequency/width unknowns. Real Apple/Flutter SDK compilation passed.
- Dart regressions cover completion de-duplication without fake timestamps, cache-only
  and empty/redacted batches, source/malformed-payload boundaries, backward clock
  guidance recovery, v1 migration/source separation, exact times/raw contexts and
  private export. Desktop tests cover keyboard navigation, resizing, titlebar inset,
  short wide/large text/reduced motion and both themes. Existing chart, recording,
  preferences and export suites remain required by `ai/scripts/check.sh`.

Final `ai/scripts/check.sh` passed: formatting/static analysis clean, 177 unit/widget
tests. Android emulator native bridge/guidance integration passed (virtual hardware,
not RF accuracy). Independent native/domain/persistence/desktop review findings
were fixed and re-reviewed; no remaining concrete findings. Normal Android release APK and macOS release `.app` builds passed sequentially.
Final source-specific recording copy passed 15 focused checks plus clean analysis; actual GUI resizing, live AP
recording/export and tactile behavior remain deferred for foreground hardware confirmation.

## Primary API references

- [CoreWLAN sandbox/client contract](https://developer.apple.com/documentation/corewlan)
- [CWInterface scan API](https://developer.apple.com/documentation/corewlan/cwinterface/scanfornetworks%28withname%3Aincludehidden%3A%29)
- [CoreLocation authorization](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services)
- [Location sandbox entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.personal-information.location)
- [AppKit feedback performer](https://developer.apple.com/documentation/appkit/nshapticfeedbackmanager/defaultperformer)
- [Flutter macOS entitlements](https://docs.flutter.dev/platform-integration/macos/building)

Installed SDK headers verified optional identifiers, channel geometry, blocking scan
semantics and absent per-network timestamps/centers. Public settings deep links are
best effort; typed recovery provides manual pane directions.
