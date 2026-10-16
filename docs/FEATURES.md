# Wave feature reference

### Overview and WiFi scanning

- Connected access-point card with network name, band, channel, measured signal in dBm, signal quality, advertised security and channel width.
- Nearby-network count, strongest nearby access points, clearest channel candidate and local signal/channel/security insights.
- Live scan bridges for Android, macOS, Windows and Linux, with manual scan, automatic scanning and pause/resume. Windows/Linux remain experimental and lack real-device validation. Foreground requests run every 35 seconds; macOS also spaces actual starts by at least 35 seconds and serializes CoreWLAN work. Android controls availability. macOS replies time out after 20 seconds; blocking OS work cannot be physically cancelled, so late results are discarded.
- Permission, Location-off, WiFi-off, throttled/cached, empty and recoverable scan-error states. Contextual shortcuts request precise location or open platform Location/privacy or WiFi settings. macOS distinguishes unavailable interfaces, redacted identifiers and unsupported radio fields; unidentified results are excluded, never given synthetic BSSIDs.
- Visible Android last-fresh-result age, macOS completed-scan age, pending/cached/paused labels and separate simulated-update age. Older observations are marked after two minutes; presentation clocks never add history or promise a next scan.
- Clearly labelled demo mode on every target, with simulated updates every 3 seconds. Backgrounding or pausing stops automatic updates.

### Guided Improve my WiFi

- Overview opens an on-device guide for weak signal or crowded channel.
- Captures an accepted connected-AP baseline, shows RSSI/band/channel/width and relative overlap evidence, suggests one action, then requests a recheck.
- Compares only newer observations of the same BSSID. Cached/duplicate results cannot complete a recheck; changing access points requires a new check.
- Demo, paused, missing-connected-AP, empty and older-than-two-minute data explain why a live comparison cannot start. Scan recovery controls remain available inside the guide.
- Uses the connected band and full scan regardless of display filters. Guidance does not diagnose interference, ISP trouble or router failure, measure speed, or configure routers.
- Baselines exist only while the guide is open; these are single-observation checks, not saved sessions or proof of lasting improvement.

### Spectrum, signal history and interactive legends

- Channel landscape showing illustrative signal envelopes from reported frequency, channel width and received power.
- **Open Spectrum** on Overview carries band, graph mode and legend selection into Spectrum.
- **Focus chart** opens a larger chart with scan freshness, band controls and legends. Close, Back or Escape returns to the same Spectrum scroll position and selection; no forced orientation.
- Tap or drag horizontally to follow visible envelope curves or recorded history samples in normal or focused charts. Markers stay on plotted data, with network name/BSSID and frequency/channel or observation time plus dBm. Vertical gestures scroll the page; pointer hover and focused arrow keys provide alternatives. Dismiss clears inspection.
- Landscape readouts explicitly label illustrative envelope values; history snaps only to recorded samples and shows their actual timestamps. Hidden curves cannot be selected. Exceptional channels use their correct centers, with nearby coordinates qualified as **Near CH**. History only plots retained observations and breaks lines across missing observations or gaps longer than two foreground scan intervals.
- Per-access-point signal history with up to 60 accepted samples per BSSID and 256 AP histories. Android cached/duplicate radio timestamps add no samples. Desktop sources accept each completed scan once using a completion ID; completion time does not establish per-AP radio freshness, and cached observations may contribute. Windows/Linux widths remain unknown, with a disclosed 20 MHz illustration/scoring assumption.
- Switch between channel landscape and signal history; filter 2.4 GHz, 5 GHz or 6 GHz bands.
- Tap a WiFi legend name through this cycle: **hide → include again → show only this WiFi → restore all**.
- While one WiFi is isolated, tap another legend name to switch focus. **Show all** resets legend selections anytime.
- Hidden networks stay in the legend. Duplicate network names remain independent through BSSID identity; colors stay tied to BSSID as scan order changes.
- Chart axes and history time range retain all chart input data when curves are hidden, keeping remaining curves in place. Legend filtering does not alter measurements or channel scoring.
- **Overview:** one horizontally scrollable legend row, pinned reset and expand controls, full wrapped list on expansion, and collapse back to the compact row. Selection survives expansion/collapse.
- **Spectrum:** full wrapped legend list. Legend controls work in both chart modes, with keyboard selection and tooltips identifying the access point and next action.

### Networks and access-point details

- Search by original SSID, local alias or BSSID, strongest-signal-first ordering and a display-only minimum-signal filter.
- Add/remove favorites and add/edit/remove local aliases from access-point details. Aliases appear alongside original SSIDs in Networks and chart legends; channel and BSSID context distinguishes same-SSID APs.
- Favorites remain pinned in a dedicated Networks section across all bands, search and signal filters. A separate Saved aliases section keeps alias-only APs manageable even when absent. Missing saved APs show **Not seen** with saved identity only; no invented signal, channel, history or timestamp.
- Preferences persist by BSSID across scans, reorder and relaunch, capped at 256 saved AP identities and 64 characters per alias. Versioned local storage preserves early edits during loading, serializes writes and exposes separate retry feedback for load/save failures. No extra permissions or services.
- Hidden-SSID entries, connected/nearby identification and access-point detail sheets.
- Details include BSSID, signal/quality, frequency, channel/band, width, advertised security and approximate distance.
- Selectable detail values adapt to narrow screens and large text; Copy MAC address gives confirmation feedback.
- Search text stays synchronized when navigating between screens.

### Saved room comparisons

- **Compare rooms** on Overview opens a foreground recording for one BSSID, with an optional manual room/session label. Favorites and aliases help identify APs; original SSID, full BSSID and radio context remain visible.
- Start waits for new observations; cached/duplicate native timestamps, chart visibility and existing history never add samples. Recordings report missing-AP updates and updates without fresh data. Demo sessions stay explicitly simulated and cannot compare with measured sessions.
- Stop saves locally; discard cancels. Pause, leaving the foreground or changing data source ends and saves with a reason. Resume never restarts recording. Relaunch restores completed sessions; forced termination may lose an unfinished recording or pending save.
- Select two or more sessions for the same BSSID/source. Each band/channel/primary frequency/width/center-frequency context shows sample count, observation time range, median RSSI and RSSI range separately. Median delta appears only when every selected session has one identical context; stronger signal is not proof of faster WiFi.
- Gaps remain visible: initial wait, longest interval between observations and silence before stop. No interpolated signal samples. Observation times use monotonic elapsed time anchored to recording start, so wall-clock corrections cannot break a saved session.
- Retain up to 24 sessions with 120 accepted samples each; recording stops at the sample cap. Delete records to free space. Labels use a consistent 64 UTF-16-code-unit limit; storage is a validated version 2 envelope (version 1 Android/demo records remain readable) capped at 1 MiB. Loading gates recording while preserving entered labels; checked, serialized/coalesced writes expose recoverable storage errors separately from scanning.
- No GPS coordinates, background service, extra permissions, cloud sync, heatmap or distance-accuracy claim. See [session verification](SAVED_COMPARISON_SESSIONS.md).

### Private comparison export

- Select one or more saved sessions for the same BSSID/source in **Compare rooms**, then **Preview private export**. Review a readable summary and CSV before opening the system share chooser. Both files use neutral filenames; summary and CSV previews are selectable, with bounded text parts and always-reachable actions.
- SSID/BSSID and room labels are excluded by default. Each has a separate explicit opt-in; aliases, internal record IDs and arbitrary stored stop reasons are never exported. Labels may themselves contain sensitive identifiers. Timing/radio data can reveal context; this is not an anonymity guarantee.
- CSV preserves accepted UTC timestamps, RSSI, reported frequency/width/center, source, counts and empty-session metadata. Summary separates raw radio contexts, including unknown centers, and reports medians/ranges and exact session gaps. No fabricated samples, combined-context delta, noise/throughput estimate or improvement guarantee. Text cells guard spreadsheet formulas; numeric measurements remain unchanged.
- Sharing occurs only after a button press. No account, server upload, automatic telemetry, router changes or new runtime permission. Two owned temporary files are overwritten on the next share; system/receiving apps may retain their own copies. Cancellation, retryable failure and unknown delivery outcomes remain explicit. Linux uses **Save reviewed files** with a native directory chooser and a new local export subfolder; preview text remains copyable. Web file sharing requires browser support; automatic download/email fallbacks are disabled.
- A changed/deleted snapshot cannot be shared; leaving preview during file preparation prevents a late chooser. Recording and versioned local storage remain unchanged. See [export verification](COMPARISON_EXPORT.md).

### Channel planning

- Explainable channel plans rank primary channels by bandwidth overlap weighted by received power. Expand each candidate for its strongest three BSSID-specific contributors, aliases plus original SSIDs, reported source widths/centers and share of that candidate’s score. Same-SSID APs stay distinct.
- Change desired width (20/40 MHz in 2.4 GHz; 20/40/80/160 MHz in 5/6 GHz) and enter a manual allowed-primary-channel shortlist. Scores use calculated bonded centers; 2.4 GHz 40 MHz shows extension above/below. Blank restores example candidates; duplicates merge; invalid edits stay open. Cancel, clear and per-band reset are explicit. Assumptions last for this app session only.
- Fresh-result age, cached/demo/paused/error status and selected assumptions stay visible. Candidate pages hold eight rows; all candidates remain reachable and bars normalize against the whole plan. No observations means no ranking.
- Option to exclude the connected access point when planning its channel.
- Display filters and legend visibility do not remove scanned access points from scoring. Recommendations are a local heuristic, not measured noise, throughput or regulatory availability.

### Welcome and onboarding

- Three-step welcome with original Rive signal, channel and scan-access scenes.
- Finite animation on scene entry, interactive replay actions, Back/Continue, Skip and Start exploring controls.
- Persisted completion and welcome replay from Settings. Scanning starts after initial welcome completes.
- Background-aware playback, reduced-motion support and stable copy/control slots across steps.

### Appearance, motion and feedback

- Modern responsive phone/desktop layouts with Overview, Spectrum, Networks, Channels and Settings destinations. Data tabs default to the connected AP’s 2.4/5/6 GHz band when connection identity is available; an explicit band choice stays selected for the app session.
- System, light and dark themes with saved theme preference. Violet primary actions, restrained teal/blue informational accents, a violet-to-indigo connection gradient and neutral surfaces keep color focused.
- Large-text status controls reflow without worst-case empty space. Narrow network rows stack readable metadata; bottom navigation uses accessible icon destinations when enlarged labels cannot fit. Chart axes scale with text and share geometry with cursor inspection.
- Circular theme reveal growing from the tapped header toggle or Settings theme control, retaining navigation, search and focus state.
- Finite page/chart reveals, animated exact signal values, channel bars, fresh-scan pulses and detail-sheet transitions.
- Mobile selection/impact haptics for supported actions, including chart-mode changes, plus hover/focus/press feedback and accessible standard controls. Shared detail/troubleshooting sheet motion honors reduced-motion and accessible-navigation preferences.
- Reduced-motion/accessibility preferences honored by custom motion; stable ordinary scan-status space and onboarding copy reduce unintended layout shifts.
- Android requests the highest advertised refresh mode at the current resolution; iOS ProMotion opt-in is enabled. Sampled theme/Rive motion reached approximately 120 Hz active cadence with touch activity on the tested phone. Constant 120 fps is not qualified; see [measured performance and limits](MOTION_VERIFICATION.md).

### Settings and platform branding

- Saved theme and minimum-signal preferences, immediate slider preview with persistence on release, and separate recoverable preference-error feedback.
- Explicit demo mode, automatic scanning controls, platform WiFi/Location recovery and Replay welcome. Desktop sidebar/medium-window rail, visible scrollbar and Cmd/Ctrl+1–5 navigation or Cmd/Ctrl+R scan reuse existing pages; narrow windows retain bottom navigation. Comparisons/export and focused charts support Escape return.
- Original Wave logo with editable SVG master and reproducible platform exports.
- Android adaptive, monochrome/themed, light/night and legacy-density launcher icons; iOS Any/light, Dark and Tinted asset-catalog appearances. Launcher/system appearance controls icon presentation independently of in-app theme. See [branding assets](../assets/branding/README.md).


See [platform support and testing cautions](../README.md#supported-platforms), [Windows setup](WINDOWS.md) and [Linux setup](LINUX.md) for platform-specific limits.
