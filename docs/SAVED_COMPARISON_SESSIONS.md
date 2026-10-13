# Saved comparison sessions

Delivered slice: rank 4, 2026-10-13. Android foreground room comparisons; explicit
simulated demonstrations remain available on unsupported live platforms.

## Behavior and ownership

Overview's **Compare rooms** opens a recording/selection route and shows an ongoing
recording indicator when the user returns to Overview. Pick one AP across all
bands and display filters, with favorites first, local alias plus original SSID,
full BSSID and reported band/channel/width. Missing favorites remain identity-only.
Canonical BSSID identity keeps same-SSID APs distinct and deduplicates native rows.
Room/session label is optional and manually entered; no location coordinates.

Start accepts no old history or existing displayed value. The analyser forwards
exact newly accepted AP values at its freshness boundary. Cached snapshots,
duplicate/older timestamps (including case variants), hidden/solo chart curves and
AP disappearance cannot fabricate observations. Multiple rows for one BSSID use
the newest accepted timestamp/value. Demo and measured sessions are separate;
comparison rejects different BSSIDs or sources.

Recording shows count, start/last sample time, cached/missing update counters,
scan status and availability recovery. Counter changes represent received replies,
not proof of continuous presence or absence. Silence produces no sample. Stop
saves; discard confirms cancellation. Pause, leaving the foreground and source
changes end/save with a reason. Returning or resuming never starts a recording.
Saved sessions survive relaunch; unfinished recording and pending writes may be
lost on forced termination. No background recording/service.

For two or more compatible sessions, compare count, observation first/last time,
median RSSI and minimum/maximum RSSI separately for every band/channel/primary
frequency/width/center-frequency context. Combined median delta appears only for
one identical context across every selected session. Changed contexts are explicit.
Initial wait, longest observation gap, final silence and no-sample sessions remain
visible. A stronger median RSSI does not establish faster throughput or improvement
outside the sampled observations. No interpolated samples or distance claim.

Models freeze nested collections. Injectable repositories own validated versioned
local storage. ViewModel owns recording and serialized/coalesced checked writes;
views own input controllers, selected records, motion and user-action haptics.
Session time uses injectable monotonic elapsed time anchored to recording start,
so a wall-clock correction cannot make timestamps regress or block persistence.

## Bounds and recovery

- **24 saved sessions:** prevents indefinite preferences growth while retaining
  several rooms/rechecks. Full store rejects a new recording; delete explicitly,
  never silently evict saved evidence.
- **120 fresh samples/session:** stops and saves at cap; about 70 minutes at the
  existing 35-second foreground request policy if every request yields a sample.
  Actual Android availability is not guaranteed. History stays independently
  bounded at 60 samples/AP and 256 AP histories.
- **1 MiB UTF-8 envelope:** rejects oversized input before JSON decoding and
  validates identical write/read bounds. Maximum records/samples fit this budget.
- **64 UTF-16 code units/label:** same validation in editor, ViewModel and storage,
  including emoji; no grapheme-count/editor mismatch.

Version 1 is the first shipped session schema. No prior session migration is
needed. Unknown versions, corrupt records, duplicate IDs, unnormalized identity,
out-of-order/out-of-range timestamps and excess records/samples reject hydration
without replacing the store. Retry recovers when storage becomes readable.
Recording is gated until hydration succeeds; page-local label/AP edits remain.
There is no recursive pending-edit chain. Writes check unsuccessful storage
returns, coalesce latest state and ignore stale failures. Load/save feedback stays
separate from scan status; write failures retain changes in memory for retry.

## Verification

- `ai/scripts/check.sh`: formatting, clean static analysis and 126 unit/widget tests
  passed. Includes freshness/duplicate/order/case boundaries, pause/background/
  resume/source changes, caps/immutability, monotonic clock correction, hydration
  gating, Unicode roundtrip, schema rejection, coalesced writes, stale failures,
  retry, discard and context-separated median comparisons.
- Session UI tests cover loading failure/retry retaining label, checkbox semantic
  identity and checked/disabled states, unavailable scan feedback and return,
  empty/mismatched-source comparisons, honest gaps and radio changes, canonical
  chooser identity, 320-pixel width at 2× text, both themes and reduced motion.
- Independent architecture review found clock chronology, hydration affordance,
  hidden scan failures, missing gap feedback, checkbox identity, duplicate-native
  value selection and timestamp labelling issues. All fixed; final independent
  re-review reported no remaining concrete findings.

- Final Android emulator integration passed: native preferences persisted across
  provider/app reconstruction, two explicitly simulated sessions compared, Keep
  cancelled deletion and Delete persisted removal. Final release APK built with
  Flutter 3.47.5; existing Rive future Kotlin compatibility warning remains.
- OnePlus 15 (CPH2745, Android 16): final release updated with `install -r`; existing
  fine/coarse location grants retained. Native touch checks selected a live 5 GHz
  BSSID, started at zero samples despite existing fresh history, saved two measured
  sessions with two actual samples each and cached replies excluded, showed
  ongoing recording on Overview, auto-saved on Home/background with a reason,
  resumed without recording, and restored both sessions after force-stop/relaunch
  and release update. Comparison showed exact medians/ranges, radio context,
  observed time ranges and honest gaps. Keep retained both records; temporary
  checks were deleted afterward; deletion survived another force-stop/relaunch.
  Final update initially hit an Android install
  verification failure; ordinary retry succeeded without changing phone security
  settings.

Emulator fixtures are explicitly simulated; they test native storage/UI outcomes.
Physical check covers one live AP and ordinary touchscreen navigation, not broad
RF qualification, a full screen-reader audit or measured frame rate. No 120fps
claim. Screenshots and device identifiers stay outside Git.

No export/share, explainable planning, desktop scanning, GPS, heatmap, cloud service
or new permissions in this slice. Ranks 5–6 and then native macOS scanning remain
separate authorized follow-up work.
