# Explainable channel planning

Delivered rank 5, 2026-10-13. Android live observations and explicitly labelled demo
observations; no export, new permission, cloud service or desktop scanning.

## Behavior

Channels → **Change assumptions** edits desired width and a manually entered
allowed-primary-channel shortlist. 2.4 GHz supports 20/40 MHz; 5/6 GHz supports
20/40/80/160 MHz. 320 MHz and discontiguous 80+80 planning are outside this MVP.
Example candidates are defaults, not a complete or regulatory availability list.
Blank restores examples; ASCII comma/space-separated numbers merge duplicates.
Malformed numbers, excessive input and channels without supported width geometry
reject the whole edit with recovery text. Unicode digit/emoji input cannot slip
through validation. Limits: 512 input code units and 64 entries. Clear edits draft;
Cancel/Escape retain applied inputs; Reset this band restores 20 MHz/examples.

Assumptions are immutable and session-local, separately retained per band through
navigation. Relaunch resets them. No new preference storage or hydration/write path.
Existing scan/session storage and recording paths are unchanged.

Primary channels map to bonded centers before scoring. 2.4 GHz 40 MHz can yield
both extension-above and extension-below candidates; channel 14 remains 2484 MHz
and supports only 20 MHz here. Exceptional 4.9 GHz channels use the 4000 MHz
base with conservative 20 MHz planning; 6 GHz channel 2 maps to 5935 MHz and is
20 MHz only. Incomplete wide blocks at band/group edges reject manual edits.
5 GHz geometry groups use standard primary sequences 36–64, 100–144 and 149–177;
6 GHz uses primary sequence 1–233. Geometry does not prove legality or hardware
support. Verify region, DFS, router support and every bonded subchannel before
changing router settings. The app does not configure routers.

The shared existing triangular heuristic uses distance between candidate and
reported source center, half-width sum, and received-power weighting. Desired
width replaces fixed candidate 20 MHz. Source observations are never rewritten;
missing source center falls back to primary, explicitly labelled. One reported
center cannot reconstruct separate 80+80 lobes. Relative scores/bars are heuristic
weights, not measured interference, noise, traffic or throughput; lower is not a
guarantee of improvement. Bars normalize against every candidate in current plan,
including candidates on other pages.

Every observed AP in selected band participates regardless of display query/RSSI
filters or hidden/solo chart curves. Optional connected exclusion removes only
connected BSSID. Expand any candidate to see strongest three contributors, local
alias plus original SSID, full BSSID, RSSI, source primary/width/center and score
share. Other contributors remain in total. Same-SSID APs remain distinct.

Eight-row pages keep rendering bounded while preserving access to every candidate.
Fresh-result age and cached/demo/paused/error status qualify current evidence.
No observations gives empty feedback, never a fabricated clear ranking. An observed
zero-overlap candidate explains unobserved noise/networks/traffic limits. Next action
is to check router support and, after any manual change, return for a fresh recheck.
Controls use existing Material press feedback, finite dialog/expansion/bar transitions
and discrete user-action haptics. Reduced motion/accessibility settings remove
transitions without changing input state.

## Verification

- `ai/scripts/check.sh`: format, clean analysis, all 141 unit/widget tests passed.
  Includes previous session/freshness/preferences/chart regressions.
- Domain tests: exceptional frequencies; bonded 40/80/160 MHz centers and edge
  rejection; reported width/center preservation; desired-width score changes;
  band/connected exclusion, same-SSID BSSID identity; 20 MHz compatibility with
  existing heuristic; width-compatible displayed defaults; bounded top-three
  evidence retaining all contributor weight; zero overlap; duplicate/empty/invalid/Unicode/bounded inputs;
  immutable per-band edits, reset and invalid-edit atomicity.
- Widget tests: apply/cancel/clear/reset and width-error recovery; aliases/source
  geometry; filters cannot change plans; independent band inputs; all 59 manual
  6 GHz candidates reachable with at most eight rendered tiles; both themes at
  320 px/3× text; desktop keyboard activation/Escape; cached/paused/demo/empty/error
  feedback. Existing motion tests verify immediate reduced-motion values and finite
  bar retargeting.
- Android emulator `emulator-5554`: `flutter test
  integration_test/channel_planning_test.dart -d emulator-5554` passed. Explicit
  simulated observations tested native app navigation, width/shortlist apply,
  contributor reasons, invalid-width recovery, cancellation and reset.
- Independent architecture review using repository `wave-architecture-review`
  skill found eager candidate rendering; replaced with bounded pagination and
  reachability regression. Independent re-review found no unresolved findings.

- Final normal Android release APK built with Flutter 3.47.5 (76.4 MB). Integration
  and normal release builds ran sequentially. Existing Rive future Kotlin
  compatibility warning is non-blocking.
- Final release installed on emulator only using `install -r`. Native touch smoke
  enabled explicit demo, opened Channels, changed 2.4 GHz to 40 MHz, applied plan,
  verified above/below extension alternatives, expanded contributor reasons and
  scrolled to limitations. Light page/dialog and dark expanded-reason screenshots
  inspected; source geometry, BSSID identity and simulated-data labels visible.
  Screenshots and local build/test logs stay outside Git.

Physical OnePlus testing intentionally pending until remaining features are built,
per user request. Emulator fixtures do not establish real RF correctness, actual
haptic feel, full screen-reader usability or measured frame rate. No 120 fps claim.
