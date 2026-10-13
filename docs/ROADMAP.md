# Wave roadmap

This file records user-requested work and its delivery status. Planned work has
no promised date. Existing feature inventory lives in README.md.
The four remaining product-manager recommendations in
[PRODUCT_REVIEW.md](PRODUCT_REVIEW.md) remain proposals, not approved scope.

## Detailed chart exploration

Requested: 2026-10-13. Status: implemented 2026-10-13.

Delivered: Open Spectrum preserves band, graph and legend context; Focus chart
opens a larger route with freshness and controls while retaining Spectrum scroll
position; ordinary/focused charts support horizontal drag, tap, hover and keyboard
coordinate inspection with explicit measurement qualifiers and dismissal. Shared
geometry handles exceptional frequencies, stable hidden-curve bounds and history
positions. History paths retain gaps and mark actual observations with dots.

Verified: full unit/widget suite, static analysis, release APK build and Android
emulator exploration regression. Narrow/large-text light/dark/reduced-motion focus
and Back/Escape return are covered. Independent architecture review findings were
fixed and rechecked. OnePlus release updated using `install -r`, retaining data and
permissions; physical touch validation was interrupted when the phone was needed
away from USB and remains pending. No frame-rate qualification claimed.

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
