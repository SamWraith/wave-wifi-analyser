# Wave roadmap

This file records user-requested work and its delivery status. Planned work has
no promised date. Existing feature inventory lives in README.md.
Ranks 1–6 from [PRODUCT_REVIEW.md](PRODUCT_REVIEW.md) are delivered.
Native macOS scanning implemented 2026-10-14; foreground live scans hardware-confirmed. Recording/export and recovery checks remain open. Windows/Linux/iOS live scanning remains
deferred.

## Saved room comparison sessions

Requested and implemented: 2026-10-13. Rank 4 only.

Overview opens **Compare rooms**. Record one explicitly selected BSSID with an
optional manual room/session label, stop/save or discard, select compatible saved
sessions and delete records. Favorites and aliases retain original SSID and BSSID
context. Only newly accepted observations add samples; demo stays simulated and
separate. Compare sample count, observation time range, median/range RSSI and gaps
for each reported band/channel/frequency/width/center-frequency context. Changed
contexts suppress combined deltas.

Pause, background and source changes end/save recording with a reason. Resume
requires a new start. Completed sessions survive relaunch; unfinished drafts and
pending writes may be lost on forced termination. Storage caps: 24 sessions, 120
samples/session, 1 MiB versioned envelope; no automatic deletion. Loading gates
recording and retains page-local edits, writes coalesce/serialize, errors offer
retry separately from scan status. Time ranges use monotonic elapsed time anchored
to start, preserving chronology across phone clock corrections.

Verification and limits: [saved comparison sessions](SAVED_COMPARISON_SESSIONS.md).
No export, GPS, heatmap, background service or new permission in this slice.

## Explainable channel planning

Requested and implemented: 2026-10-13. Rank 5 only.

Channels displays desired width and a manually entered primary-channel shortlist,
calculates bonded centers, ranks relative overlap and explains strongest contributors
by BSSID with alias/original SSID and unchanged reported source geometry. 2.4 GHz
40 MHz extension alternatives are explicit. Shortlist validation rejects unsupported
geometry; it cannot establish regulatory availability, DFS or router support.
Blank restores example channels; duplicates merge; Cancel preserves applied inputs;
Clear and per-band reset are explicit. Inputs stay in current app session, separately
for each band. No persistence or router configuration added.

Plans use every observed AP in selected band independently of search, RSSI filters
or hidden/solo chart curves. Connected exclusion remains BSSID-specific. Eight-row
pages retain access to every candidate and whole-plan normalization. Fresh-result
age and demo/cached/paused/error status qualify the evidence; empty observations
never produce recommendations. Relative overlap is not measured interference,
noise or throughput and cannot guarantee improvement.

Verification: [channel planning](CHANNEL_PLANNING.md). Physical OnePlus functional
checks passed 2026-10-14 using live observations and both themes.

## Private comparison export/share

Requested and implemented: 2026-10-13. Rank 6 only.

Select compatible saved sessions, review exact summary/CSV text, optionally reveal
SSID/BSSID or room labels separately, then explicitly open the system share chooser.
Defaults exclude identifiers, labels, aliases and internal record IDs. Generic file
names/metadata, escaped CSV text, exact samples/times, separate raw radio contexts,
empty records and honest gaps/limitations preserve evidence without inferred RF claims.
Bounded preview parts, fixed actions and explicit cancellation/failure recovery retain
context. Changed/deleted selections and disposed previews block late sharing during
preparation. Linux offers preview/copy recovery; unsupported web sharing has no
implicit download/email fallback. Two owned temporary files are overwritten on the
next share; system/receiving apps can keep copies. No anonymity or delivery guarantee.

Verification: [comparison export](COMPARISON_EXPORT.md). Physical OnePlus checks passed
2026-10-14, including actual local payloads, private defaults, opt-ins, cancellation
and empty-session evidence.

## Native macOS live scanning

Implemented: 2026-10-14. CoreWLAN/CoreLocation bridge, explicit Location recovery,
public sandbox-compatible client interfaces, bounded serialized foreground scans,
redacted/unavailable-data handling and source-aware history/recording/export.
Desktop sidebar/medium rail, scrolling, keyboard navigation, Escape return and
scaled layouts reuse existing pages. AppKit feedback is deliberate, best effort
and governed by hardware/system preferences.

macOS times describe scan completion, not individual radio measurements. Cache age
is unavailable; successful scans may include cached observations. Missing BSSID or
unsupported radio geometry is excluded, never fabricated. Android/demo/macOS
sessions stay separate; v1 records survive v2 source/time storage.

Verification evidence and remaining hardware checks: [macOS scanning](MACOS_SCANNING.md).
Windows/Linux/iOS live scanning remains deferred. No new roadmap slice authorized.

## Detailed chart exploration

Requested: 2026-10-13. Status: implemented 2026-10-13.

Delivered: Open Spectrum preserves band, graph and legend context; Focus chart
opens a larger route with freshness and controls while retaining Spectrum scroll
position; ordinary/focused charts support horizontal drag, tap, hover and keyboard
inspection that follows visible envelope curves or recorded history samples,
with network identity, explicit measurement qualifiers and dismissal. Shared
geometry handles exceptional frequencies, stable hidden-curve bounds and history
positions. History paths retain gaps and mark actual observations with dots.

Verified: full unit/widget suite, static analysis, release APK build and Android
emulator exploration regression. Narrow/large-text light/dark/reduced-motion focus
and Back/Escape return are covered. Independent architecture review findings were
fixed and rechecked. OnePlus release updated using `install -r`, retaining data and
permissions. After reconnection, physical OnePlus 15 checks passed with the normal
release app and live scan data: Overview navigation retained 2.4 GHz; normal
landscape/history and focused history accepted horizontal drag inspection;
vertical chart gestures scrolled the page; cursor dismissal worked; Close and
Android Back returned to the same Spectrum scroll position and history mode;
legend hiding carried back from focus and Show all reset it. Freshness qualifiers
and actual history gaps remained visible. These were ADB-injected touchscreen
interactions inspected through screenshots and accessibility output, not a
frame-rate qualification or a full physical accessibility audit.

Follow-up requested 2026-10-13: constrain markers to plotted data rather than
free x/y coordinates, like financial charts. Landscape markers follow the same
Bézier definition used by the painter, clamping to visible envelope edges. History
selects real samples with AP identity and observation time, including across gaps;
it never invents interpolated readings. Hidden curves cannot be selected.
Follow-up verification: 93 unit/widget tests and Android emulator exploration
passed; independent geometry/architecture review found no actionable findings.
Updated release installed on OnePlus 15 with `install -r`; native touchscreen
checks confirmed landscape markers on envelope curves and normal/focused history
markers on recorded samples with AP identity and exact observation timestamps.
Vertical scrolling and focus return remain usable. Data and permissions preserved.

Original acceptance scope follows.

### Overview to Spectrum

Provide a clear Open Spectrum action on Overview's Channel landscape card so users
can continue into the dedicated Spectrum page. Preserve the selected band and chart
context. Existing graph-mode toggle, compact legend scroll/expand and legend actions
must stay independent; card navigation must not swallow those taps or chart drags.
If the card itself is tappable, make its affordance and keyboard/semantic action clear.

### Focused chart mode

Add a discoverable focus/expand action on Spectrum. Focused mode gives the chart more
space, readable axes and detailed inspection, while keeping band, graph mode, legend
selection and measurement freshness visible or easily accessible. Support channel
landscape and signal history. Back, Escape and an explicit close action return to
Spectrum with previous selection and scroll context intact. Respect safe areas,
rotation, large text, reduced motion and keyboard navigation; no forced orientation.

### Touch inspection in ordinary chart mode

Let users drag a finger across the chart to reveal a crosshair and x/y readout.
For channel landscape, show channel (and frequency when needed) plus signal strength
in dBm. For signal history, show time plus dBm. Map cursor positions through the same
axis definition used by the painter, including band/frequency exceptions and wide
channels. Keep ordinary vertical page scrolling and legend taps usable; make the
inspection gesture discoverable and offer pointer/keyboard alternatives.

Distinguish cursor axis coordinates/illustrative envelopes from actual AP readings.
If snapping to a measured AP/sample, identify the AP and observation time explicitly.
Never invent history samples, imply interpolated envelopes are RF measurements, or
relabel cached data as fresh. Keep cursor readout readable at chart edges; provide
an accessible textual equivalent and a clear way to dismiss inspection. Avoid repeated
haptics while dragging; use subtle feedback only for intentional discrete actions.

### Acceptance and verification

- Overview action opens Spectrum without changing the selected band; internal
  legend, graph-toggle and scrolling actions never navigate accidentally.
- Enter/exit focus preserves graph mode, band and hide/include/solo/reset state;
  compact Overview legend behavior remains unchanged.
- Cursor readouts match plotted axes at bounds and representative points, including
  2.4/5/6 GHz exceptions; hidden curves retain stable axes and history gaps stay gaps.
- Touch inspection works in normal mode alongside page scrolling; focused mode and
  pointer/keyboard inspection remain intuitive and accessible.
- Validate narrow phones, desktop, large text and both themes, plus reduced motion
  and native touch interactions on OnePlus. Qualify performance only with measurements.

Reuse existing chart axis/painters and small presentation widgets. Keep inspection
and focus UI state presentation-owned; scan/history state and channel scoring remain
independent. Review architecture after implementation before declaring this shipped.
