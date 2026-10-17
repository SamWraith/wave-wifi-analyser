# Router finder

Open **Networks**, select an access point, then choose **Find this router**.
The first new accepted target observation establishes a baseline. Walk a few
steps, hold the device consistently and wait for another update. A change of at
least 3 dB shows warmer/stronger or colder/weaker signal; smaller changes show
similar signal. This deadband is a UI heuristic, not a confidence interval.

Finder follows the selected **BSSID**, including when mesh nodes share an SSID.
It shows the latest accepted RSSI, baseline, best signal and observation count.
**Start comparison here** clears the comparison and waits for another accepted
target sample. A frequency change establishes a new baseline. Closing the screen
disposes the finder comparison; finder does not save or export it. The analyser's
existing bounded in-memory signal history remains separate.

## Limits

- Warmer/colder describes received signal relative to the baseline. It cannot
  establish actual movement toward or away from a router: walls, reflections,
  antenna orientation and transmit power affect RSSI.
- The displayed metres reuse Wave's free-space path-loss estimate. They are not
  measured distance and can be very inaccurate indoors. There is no compass,
  map, triangulation, location recording or WiFi RTT implementation.
- Automatic live scan requests remain 35 seconds apart. Manual requests use the
  existing scan path; Android and drivers control actual availability.
- Android requires accepted new radio timestamps. Desktop comparisons use accepted
  scan completions and cannot establish individual AP radio freshness. Cached and
  duplicate results do not add finder observations.
- Missing targets or paused/cached results hold guidance and retain the last
  observation with its age. Changing data source clears the comparison and requires
  reopening finder; simulated and live data are never combined. Demo is labelled.
- A redacted/empty BSSID cannot start finder. Search and signal filters do not
  redirect the selected target to a different AP.

The feature uses the existing shared Flutter UI and analyser on Android, macOS,
Windows and Linux, without new permissions, dependencies or native contracts.
Existing Windows/Linux hardware-verification limitations still apply.

## Verification

`test/router_finder_test.dart` covers sample boundaries, signal deadband, identity,
frequency/source changes, reset and disposal. `test/router_finder_ui_test.dart`
covers entry/back navigation, scan requests, source/missing-target feedback,
phone/desktop layouts and large text. Its optional capture renders an explicit demo
preview to ignored `build/router-finder/preview.png` using Flutter SDK fonts:

```sh
fvm flutter test test/router_finder_ui_test.dart \
  --dart-define=WAVE_CAPTURE_FINDER=true \
  --plain-name 'render Android demo preview of finder with accepted observations'
```

Capture is skipped in normal CI so tests do not require an FVM SDK directory or
write preview files. A manual architecture/lifecycle review accompanied the change;
an independent feature architecture review was not run.

Automated checks do not prove physical router-location accuracy. The published
v1.0.1 preview predates this feature; source changes do not replace that release's
download packages.
