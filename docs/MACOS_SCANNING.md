# Native macOS scanning

Implemented 2026-10-14. Public CoreWLAN/CoreLocation APIs; local observations only.
Windows/Linux/iOS live scanning remains deferred. No discovery, throughput tests,
router configuration, accounts or telemetry added.

## Contract and limits

`WifiBridge` uses a retained `CWWiFiClient` and its vended interfaces, preferring
powered default hardware or a stable powered fallback. Explicit **Allow location**
requests CoreLocation authorization; privacy/Location and WiFi recovery open System
Settings with a readable fallback if the deep link fails. Both build entitlements
retain App Sandbox and grant Location access plus the standard network-client
capability required to reach the local CoreWLAN service on the tested Mac. No location coordinates are requested
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

## Verification (2026-10-14–15)

- Normal release `.app` built and launched through Finder into foreground. Live
  CoreWLAN observations appeared in the macOS workspace: 17, then 14 APs on the
  selected 5 GHz view; the AP selector also contained 2.4 GHz observations.
  Connected AP identification, channel 48, reported 80 MHz width and changing RSSI
  (-47 to -53 dBm across observations) were visible. These are OS-reported values,
  not calibrated RF accuracy measurements. Network identifiers and raw captures
  remain outside Git.
- Completion-age/cache qualifiers and unavailable individual radio age were visible.
  Pointer chart inspection showed the illustrative envelope qualifier. Room
  comparisons opened and the connected 5 GHz BSSID could be selected by keyboard.
  Subsequent recording/export checks are detailed below.
- Earlier computer-use launches left the app in background, where foreground-only
  scans rejected requests. Opening the built app through Finder resolved that
  context and established successful live scanning. Already-granted Location access
  was used; first grant, denial and permission recovery were not qualified.
  A prior network-client entitlement trial was reverted; no sandbox exception or
  privacy bypass is retained.
- October 15 foreground access was restored after blank desktop captures. On
  macOS 26.3.1 (25D771280a), two stationary sessions for the same connected 5 GHz
  BSSID started with zero samples. Session A accepted one -48 dBm observation;
  pause ended/saved it with the scanning-paused reason. Resume started no recording.
  Session B accepted two -50 dBm observations from separate scan completions,
  including repeated RSSI, and explicit Stop and save retained both. Each session
  counted one cache-only update without adding a sample. Native cooldown feedback
  disclosed the 35-second spacing; this does not guarantee fresh radio readings.
- Same-source/BSSID comparison rendered one radio context with unknown center,
  medians -48/-50 dBm, -2 dB delta, sample windows and unfilled silence/gap durations.
  The Mac stayed stationary; these observations do not establish a room improvement.
- Private summary and CSV previews defaulted both identifier and label switches off.
  Native chooser opened with two local files and was cancelled; cancellation feedback
  explicitly confirmed no delivery. Local file inspection verified excluded network
  identifiers/test labels, macOS freshness qualifiers, exact UTC microsecond times,
  -48 dBm, 5240 MHz primary, 80 MHz reported width and empty unknown center field.
  No receiving service was selected and no external sharing was performed.
- Quitting and relaunching the normal release restored both sessions, sample counts
  and stop reasons. Two clearly labelled hardware-check sessions remain local.
  Pointer selection, scrolling, keyboard AP selection and Escape route return worked.
  Resize/zoom and Cmd/Ctrl page shortcuts could not be reliably established through
  this automation, so no hardware pass is claimed for them. Permission revoke/regrant,
  background recording termination, 6 GHz and perceived haptics remain unqualified.
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
Final source-specific recording copy passed 15 focused checks plus clean analysis.
Live scanning, recording, pause/resume, same-source comparison, private export/chooser
cancellation and saved-session restoration are hardware-confirmed. Remaining physical
checks are listed above. No calibrated RF accuracy or frame-rate claim.

## Network-client capability correction (2026-10-15)

A later release retry failed before scanning: the OS detected powered `en0`, but
Wave's sandbox returned no client-vended interfaces. Kernel/launchd logs confirmed
`deny(1) mach-lookup com.apple.airportd`. Foreground activation and a fresh process
did not resolve the failure.

Two isolated signed sandbox probes reproduced the difference: sandbox + Location
alone returned no interfaces; adding standard `com.apple.security.network.client`
returned powered `en0`. Both Debug/Profile and Release now retain that capability,
App Sandbox and Location access. No temporary sandbox exceptions, private WiFi
entitlements or new outgoing network calls were added. Earlier reverted capability
experiments above are historical evidence, not the current signing configuration.

The corrected release built successfully; its signed entitlements were inspected.
A read-only debugger check inside that release confirmed the shared CoreWLAN client
now vends `en0`. Four native tests passed, including a check of the host's actual
signed sandbox/Location/network-client capabilities. Formatting/static analysis and
31 macOS scan/session/export Dart regressions passed.

After user-approved Location access, the normal corrected release completed live
scans: 24 APs on the selected 2.4 GHz view and 12–19 APs across observed 5 GHz
completions. Connected-AP details reported channel 48, primary 5240 MHz, 80 MHz and
WPA3; RSSI varied from -52 to -60 dBm during this stationary check. History pointer
inspection selected an accepted -57 dBm sample and retained the unknown per-AP/cache
age qualifier. Network details and channel-planning candidates used these live
observations; Demo mode remained off.

Two new labelled test sessions began at zero samples for the same connected 5 GHz
BSSID. Session C accepted one -58 dBm observation; Pause saved it with `Scanning
paused`. Results remained retained while paused for over two minutes, and Resume
started no recording. Session D then accepted one -60 dBm observation and explicit
Stop and save retained it. Each session counted one update without accepted samples,
without increasing its sample count. Comparison showed one matching radio context,
medians -58/-60 dBm and -2 dB delta. The Mac stayed stationary; this is no claim of
room improvement, calibrated RF accuracy or internet speed.

Private summary/CSV previews defaulted identifier and label opt-ins off. CSV showed
one sample, exact accepted UTC time, -58 dBm, 5240 MHz, 80 MHz and empty unknown
center field, with macOS freshness limits. Native chooser opened with two local files
and was cancelled without selecting any recipient. Feedback confirmed cancellation;
no external delivery was performed.

A clean quit was confirmed before relaunching the same normal release. Both new
sessions restored with one sample each and their distinct pause/manual-stop reasons;
the earlier two local hardware-check sessions also remained intact. New captures
and network identifiers stay outside Git. Core corrected-build live scanning,
history inspection, pause/resume, recording, same-source comparison, private export
review/chooser cancellation and persistence are now hardware-confirmed. 6 GHz,
roaming, permission revocation/recovery, background recording termination, calibrated
RF accuracy and perceived haptics remain outside this qualification.

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
