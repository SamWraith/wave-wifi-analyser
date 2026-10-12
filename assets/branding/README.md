# Wave app icon

The original mark pairs two WiFi arcs with a **W-shaped signal wave**: wireless
discovery, signal analysis and the Wave name in one silhouette. Violet matches
the app's palette. The mark stays legible in monochrome and at launcher sizes.

`wave-mark.svg` is the editable master. Named paths drive every export; colors
and platform margins live in `tool/icons/generate.cjs`. SVG is appropriate for
editing and scale-independent artwork. Native launchers consume platform asset
catalog PNGs and Android VectorDrawable XML, rather than the SVG itself.

From the repository root:

```sh
npm ci --prefix tool/icons
npm run generate --prefix tool/icons
npm run verify --prefix tool/icons
```

The generator adds no application runtime dependency. `icon-preview.png` shows
production artwork at large and small sizes, with illustrative system tint.
`wave-play-store.png` is an opaque, square 512px store export, without baked-in
corner masking or outer shadows.

## Android

- Android 8+: separate 108dp vector foreground and full-bleed background layers.
  The visible mark is approximately 58x49dp and contained in the central 66dp
  safe circle. The launcher applies its own mask and motion effects.
- Android 13+: a monochrome vector lets supporting launchers apply wallpaper
  colors. Users must enable themed icons; launcher support governs presentation.
- Light/dark foreground and background colors follow system `values-night`
  resources. Explicit night adaptive entries prevent legacy night bitmaps from
  outranking adaptive resources. Launcher caching may delay appearance updates.
- Older Android: five-density PNG fallbacks, including night versions.
- `AndroidManifest.xml` selects `@mipmap/ic_launcher` for native packaging.

## iOS

The supported asset-catalog workflow mirrors Folio: square 1024px opaque Any,
Dark and grayscale Tinted PNGs. Xcode generates device sizes and applies corner
masking. Home Screen appearance controls icon selection on supporting iOS
versions; older versions use Any. In-app theme changes do not switch launcher
icons independently of system appearance.

Current iOS also supports layered Icon Composer files for richer Liquid Glass
and clear appearances. This project supplies asset-catalog appearances; clear
presentation, where available, is system-derived. It does not claim bespoke
Icon Composer layers or App Store review approval. A future layered icon can
reuse the SVG paths without changing the app's identity.

## Platform references

- [Android adaptive icon requirements](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)
- [Apple asset-catalog icon configuration](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)
- [Apple app icon design guidance](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Apple Icon Composer workflow](https://developer.apple.com/documentation/Xcode/creating-your-app-icon-using-icon-composer)
