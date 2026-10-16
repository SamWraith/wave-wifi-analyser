# Wave screenshot artwork

Five store-style presentation images frame actual shared Flutter UI renders:
three mobile portraits (1290 × 2796) and two desktop landscapes (2400 × 1840).
These are README/presentation assets, not evidence of store submission or formal
App Store/Google Play screenshot eligibility.

Every network comes from Wave's explicit deterministic demo source. Demo labels
remain visible in the untouched UI captures. No personal SSID/BSSID, device data,
AI-generated UI or simulated Windows/Linux hardware proof is used. Mobile layout
uses the iOS theme target; desktop uses the macOS layout. Live iOS scans are not
implemented. Android shares these responsive pages, with native platform controls.

`raw/` holds the original PNG screen renders. Final artwork adds only typography,
backgrounds and generic device/window frames around those PNGs. No UI element or
measurement is painted over, removed or invented.

## Reproduce

From the repository root with the pinned FVM SDK:

```sh
fvm flutter test tool/screenshots/capture_test.dart
cd tool/screenshots
npm ci
npx playwright install chromium
npm run render
```

The capture harness uses in-memory preferences and explicit demo mode, without
requesting RF permissions or modifying real app preferences. It loads Arial from
macOS when available, otherwise Flutter's Roboto fallback, and loads a local monospace face plus the SDK's
Material Icons font. Font binaries are not distributed in this repository.

The renderer uses local Chrome on macOS when available, otherwise Playwright's
Chromium. Set `CHROME_BIN` for another browser executable. All artwork is generated
locally from repository assets; no browser profile, account or remote font is used.
The renderer verifies that the complete device/window frame clears the footer.
Screen captures check for Flutter exceptions before writing files.

Artwork labels and README captions deliberately distinguish demo previews from
measured radio evidence and platform validation.
