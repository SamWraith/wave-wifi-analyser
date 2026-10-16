# Android listing metadata

`metadata/android/en-US/` contains the English Android listing, launcher icon,
version-code changelog and three screenshots for F-Droid's Fastlane convention.
This directory does not mean Wave is approved or published on F-Droid or Play.

Screenshots are real renders of Wave's Android-themed Flutter UI with explicitly
labelled simulated networks. They contain no private WiFi observations. They are
1290 × 2796 PNGs, without device frames or promotional overlays. Review them after
regenerating; widget captures do not verify physical Android scanning.

From the repository root, regenerate with the pinned Flutter SDK:

```sh
fvm flutter test tool/screenshots/capture_test.dart \
  --dart-define=WAVE_SCREENSHOT_ANDROID=true \
  --dart-define=WAVE_SCREENSHOT_OUTPUT=fastlane/metadata/android/en-US/images/phoneScreenshots
```

The harness uses local Arial/Courier New where available and Flutter SDK fallback
fonts elsewhere, so typography can differ across hosts. The icon is copied from
`assets/branding/wave-play-store.png`; its editable source is in the same directory.

Original metadata and artwork are covered by the root `LICENSE` and `NOTICE`.
See `docs/FDROID.md` for submission status and remaining build review.
