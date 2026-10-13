# Wave product review

Date: 2026-10-13. Role: independent product manager review.

This report recommends possible next work. It does not authorize implementation
or commit Wave to a roadmap. Priorities are product judgments inferred from the
repository, not findings from user interviews, analytics or competitor research.

## Product direction and observed baseline

Wave should help a person answer three questions: “Is my WiFi signal weak here?”,
“Which nearby access points affect my channel?”, and “Did moving or changing my
router improve the result?” The first two jobs have a useful foundation; the
third lacks a durable comparison workflow.

Observed in README and focused source review: Android live scans, explicit demo
mode elsewhere, connected-AP overview, channel/history charts, band filters,
search/details, overlap rankings, permission/status handling and local settings.
Legend filtering already supports hide/include/solo/reset, with a scrolling and
expandable Overview legend. Onboarding, themes, haptics and platform icons are
implemented. These are existing features, not recommendations below.

History currently retains up to 60 fresh samples per BSSID in running state.
`lastUpdated` drives the fresh-scan pulse; the reviewed status bar does not show
a numeric measurement age. Insights offer basic signal/channel advice; channel
ranking uses a fixed candidate list and an overlap heuristic. Sources reviewed:
`lib/models/analyser_state.dart`, `lib/models/access_point.dart`,
`lib/views/overview_page.dart`, `lib/views/channels_page.dart`,
`lib/views/settings_page.dart`, `lib/widgets/scan_activity.dart`, and legend UI.

## Implementation follow-up

The user subsequently approved ranks 1 and 2. Both are implemented in the
2026-10-13 follow-up; see [freshness and guidance verification](FRESHNESS_AND_GUIDANCE.md).
The original ranking and hypotheses below remain historical recommendations.
Rank 3 was subsequently authorized and delivered: BSSID favorites, local aliases, missing-favorite identity and bounded versioned storage. See [favorites and aliases verification](FAVORITES_AND_ALIASES.md) and README for delivered behavior. Rank 4 was subsequently authorized and delivered: bounded foreground room sessions and same-BSSID comparisons with separate radio contexts. See [session verification](SAVED_COMPARISON_SESSIONS.md). Ranks 5–6 are now authorized as later Android slices; this session slice does not implement them. Native macOS scanning follows those slices; other native platforms remain deferred.

## Ranked feature recommendations

Effort is relative engineering scope: small (focused presentation/state), medium
(new persisted workflow), large (new native/data contract). It is not a delivery
estimate. Suggested sequence follows rank; validate with a few real users before
expanding later items.

| Rank | Recommendation | Value hypothesis | Effort | MVP acceptance criteria and dependencies |
| --- | --- | --- | --- | --- |
| 1 | Visible freshness and scan recovery | Prevent users reading cached signal as a new measurement. | Small–medium | Show “Last fresh result … ago”, distinguish pending request/cached/paused/demo states, and give contextual recovery actions for permission, Location and WiFi. Age advances without creating history samples; pause/background preserve truthful timestamps. Build on current state/native status. Do not promise a countdown to a guaranteed next scan. |
| 2 | Guided “Improve my WiFi” flow | Convert technical charts into a clear next action. | Medium | Let users choose weak signal or crowded channel; show measured evidence, one suggested action, then a recheck. Never identify interference, ISP trouble or router failure from RSSI alone. In stale/empty/demo states, explain what can be concluded. Reuse existing local rules; no AI service or extra permissions. |
| 3 | Favorite APs and local aliases | Make repeated comparisons easier, especially when several APs share an SSID. | Small–medium | Pin APs by BSSID, rename locally, show alias plus original SSID, and retain identity through scans/reordering/relaunch. Keep same-SSID APs distinct; show channel or short BSSID in legend context. Missing favorite stays “not seen”, never receives fabricated samples. Depends on bounded preference storage and migration tests. |
| 4 | Saved comparison sessions with room labels | Answer whether a router move or configuration change helped. | Medium | User starts/stops a foreground session, optionally labels rooms manually, and compares at least two sessions using sample count, time range, median RSSI and range for the same BSSID. Fresh samples only; gaps and disappearance remain visible. Cap storage, support deletion, and preserve band/channel/width context. No GPS, background service, floor-plan heatmap or claimed distance accuracy. |
| 5 | Explainable channel planning | Help users understand why a candidate ranks well and whether it is relevant to their router. | Medium–large | Explain strongest overlap contributors for each candidate. Allow desired channel width and a user-entered allowed-channel shortlist; recalculate using that width. Display selected assumptions and fresh-data age. Verify wide-channel frequency handling with domain tests. A shortlist is user input, not proof of local regulatory availability or router support. |
| 6 | Private export/share of a comparison | Help users send useful evidence to household members or support. | Small–medium after rank 4 | Export a selected session as CSV and a concise readable summary. Preview before sharing; hide SSID/BSSID by default, make inclusion explicit, and distinguish demo/measured data. Include timestamps, sample counts and heuristic limitations. Share only on user action; no account, server upload or automatic telemetry. |

Original proposed next slice: rank 1, then rank 2. Ask participants to diagnose a known
weak-signal location and explain the next action in their own words. Record
task completion and misunderstandings; this is a proposed validation exercise,
not research already performed.

## Release readiness before adding scope

These are quality gates for existing functionality, separate from new features:

- Validate real RF behavior on physical Android devices: permission denial and
  revocation, WiFi/Location disabled, cached/throttled scans, duplicate timestamps,
  same-SSID multiple APs, AP disappearance, and supported 2.4/5/6 GHz hardware.
  Record actual OS/device coverage. Emulator bridge checks do not establish RF
  measurement correctness.
- Check narrow-phone layouts, large text, screen readers, keyboard focus and
  legend actions in both themes. Verify chart interpretation does not depend on
  color alone; inspect hidden/solo next-action announcements on native devices.
- Finish prolonged battery/thermal and normal-interaction performance checks.
  Existing evidence establishes sampled near-120 Hz active cadence, with slow
  frames and no-touch runs near 60 Hz. Do not market constant 120 fps.
  See [motion verification](MOTION_VERIFICATION.md).
- Configure production signing and prepare accurate privacy/platform disclosures
  before public distribution. Keep unsupported platforms clearly marked demo;
  avoid implying advertised security is a comprehensive security audit.

## Platform constraints and scope limits

Android can return previous scan results and can reject or throttle scan
requests. Its documented foreground limit is four scans per two minutes on
Android 9 and later; permissions and enabled Location services also affect these
APIs. This supports freshness/recovery work and rules out promising continuous
live measurements. Wave's 35-second interval remains a request policy, not a
hardware guarantee. [Android Wi-Fi scanning overview](https://developer.android.com/develop/connectivity/wifi/wifi-scan).

iOS has no general-purpose WiFi scanning API. Do not treat Android nearby-AP
parity as an ordinary iOS feature task; retain honest demo behavior and assess any
future iOS product independently. [Apple TN3111: iOS Wi-Fi API overview](https://developer.apple.com/documentation/technotes/tn3111-ios-wifi-api-overview).

Defer device discovery, throughput tests, router administration, widgets,
automatic alerts and cloud/AI diagnostics until the core comparison workflow is
validated. They solve adjacent jobs and introduce more infrastructure, platform
constraints or ongoing maintenance. README/About mentions of future tools are
ideas, not delivery promises. Offline guidance, aliases and bounded sessions can
add value without new sensitive permissions or accounts.
