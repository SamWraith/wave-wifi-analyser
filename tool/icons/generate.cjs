// Development-only SVG exports. No Flutter/runtime dependency.
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');

const root = path.resolve(__dirname, '../..');
const branding = path.join(root, 'assets/branding');
const android = path.join(root, 'android/app/src/main/res');
const ios = path.join(root, 'ios/Runner/Assets.xcassets/AppIcon.appiconset');
const palettes = {
  light: { background: '#F5F3FF', ink: '#7054D7' },
  dark: { background: '#141321', ink: '#B7A5FF' },
  tinted: { background: '#000000', ink: '#FFFFFF' },
};
const densities = { mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 };

async function write(file, contents) {
  await fs.mkdir(path.dirname(file), { recursive: true });
  await fs.writeFile(file, contents);
}

function mark(paths, ink, adaptive) {
  // 256-unit artwork centered in a 108dp layer. Its stroked bounds occupy
  // 58x49dp and stay entirely inside the central 66dp safe circle.
  const transform = adaptive ? 'translate(10.48 13.2) scale(0.34)' : '';
  return `<g transform="${transform}" fill="none" stroke="${ink}" stroke-width="18" stroke-linecap="round" stroke-linejoin="round">${paths.map((d) => `<path d="${d}"/>`).join('')}</g>`;
}

function artwork(paths, colors, { adaptive = false, rounded = false, circle = false } = {}) {
  const size = adaptive ? 108 : 256;
  const viewport = adaptive ? '18 18 72 72' : '0 0 256 256';
  const background = circle
    ? `<circle cx="54" cy="54" r="36" fill="${colors.background}"/>`
    : `<rect width="${size}" height="${size}" rx="${rounded ? 56 : 0}" fill="${colors.background}"/>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="${viewport}">${background}${mark(paths, colors.ink, adaptive)}</svg>`;
}

async function png(svg, file, size, opaque = true) {
  await fs.mkdir(path.dirname(file), { recursive: true });
  let raster = sharp(Buffer.from(svg)).resize(size, size);
  if (opaque) raster = raster.removeAlpha();
  await raster.png().toFile(file);
}

function vector(paths, monochrome) {
  return `<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <group android:translateX="10.48" android:translateY="13.2" android:scaleX="0.34" android:scaleY="0.34">
${paths.map((d) => `        <path android:fillColor="#00000000" android:strokeColor="${monochrome ? '#FFFFFFFF' : '@color/wave_icon_ink'}" android:strokeWidth="18" android:strokeLineCap="round" android:strokeLineJoin="round" android:pathData="${d}" />`).join('\n')}
    </group>
</vector>
`;
}

async function generateIos(paths) {
  // Remove only obsolete template AppIcon PNGs; the catalog remains dedicated
  // to the app icon, and Xcode generates each device's sizes from 1024px.
  for (const name of await fs.readdir(ios)) {
    if (/^Icon-App-.*\.png$/.test(name)) await fs.unlink(path.join(ios, name));
  }
  const images = [];
  for (const [appearance, colors] of Object.entries(palettes)) {
    const svg = artwork(paths, colors);
    await write(path.join(branding, `wave-icon-${appearance}.svg`), svg + '\n');
    await png(svg, path.join(ios, `Wave-${appearance}.png`), 1024);
    images.push({ filename: `Wave-${appearance}.png`, idiom: 'universal', platform: 'ios', size: '1024x1024',
      ...(appearance === 'light' ? {} : { appearances: [{ appearance: 'luminosity', value: appearance }] }) });
  }
  await write(path.join(ios, 'Contents.json'), JSON.stringify({ images, info: { author: 'xcode', version: 1 } }, null, 2) + '\n');
}

async function generateAndroid(paths) {
  await write(path.join(android, 'drawable/wave_icon_foreground.xml'), vector(paths, false));
  await write(path.join(android, 'drawable/wave_icon_monochrome.xml'), vector(paths, true));
  for (const night of [false, true]) {
    const colors = palettes[night ? 'dark' : 'light'];
    await write(path.join(android, `${night ? 'values-night' : 'values'}/wave_icon_colors.xml`), `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="wave_icon_background">${colors.background}</color>
    <color name="wave_icon_ink">${colors.ink}</color>
</resources>
`);
    for (const [density, size] of Object.entries(densities)) {
      await png(artwork(paths, colors, { rounded: true }), path.join(android, `mipmap-${night ? 'night-' : ''}${density}/ic_launcher.png`), size, false);
    }
    // Explicit night adaptive variants outrank legacy night bitmaps.
    for (const api of [26, 33]) {
      await write(path.join(android, `mipmap-${night ? 'night-' : ''}anydpi-v${api}/ic_launcher.xml`), `<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/wave_icon_background" />
    <foreground android:drawable="@drawable/wave_icon_foreground" />${api === 33 ? '\n    <monochrome android:drawable="@drawable/wave_icon_monochrome" />' : ''}
</adaptive-icon>
`);
    }
  }
}

async function generatePreview(paths) {
  const variants = [
    ['iOS light', artwork(paths, palettes.light, { rounded: true })],
    ['iOS dark', artwork(paths, palettes.dark, { rounded: true })],
    ['iOS tinted source', artwork(paths, palettes.tinted, { rounded: true })],
    ['Android light', artwork(paths, palettes.light, { adaptive: true, circle: true })],
    ['Android dark', artwork(paths, palettes.dark, { adaptive: true, circle: true })],
    ['Android system tint', artwork(paths, { background: '#DEE7F9', ink: '#354166' }, { adaptive: true, circle: true })],
  ];
  const tiles = variants.map(([label, svg], index) => {
    const content = svg.replace(/^<svg[^>]*>|<\/svg>$/g, '');
    const viewport = svg.match(/viewBox="([^"]+)"/)[1];
    const x = 50 + (index % 3) * 330, y = 100 + Math.floor(index / 3) * 350;
    return `<g transform="translate(${x} ${y})"><svg width="220" height="220" viewBox="${viewport}">${content}</svg><text x="110" y="255" text-anchor="middle" font-family="sans-serif" font-size="18" fill="#2A2546">${label}</text><svg x="90" y="274" width="40" height="40" viewBox="${viewport}">${content}</svg></g>`;
  });
  const preview = `<svg xmlns="http://www.w3.org/2000/svg" width="1040" height="820"><rect width="1040" height="820" fill="#EEECF6"/><text x="50" y="56" font-family="sans-serif" font-size="30" font-weight="bold" fill="#2A2546">Wave · WiFi clarity, in one signal</text>${tiles.join('')}</svg>`;
  await write(path.join(branding, 'icon-preview.svg'), preview + '\n');
  await sharp(Buffer.from(preview)).removeAlpha().png().toFile(path.join(branding, 'icon-preview.png'));
  await png(artwork(paths, palettes.light), path.join(branding, 'wave-play-store.png'), 512);
}

async function generate() {
  const source = await fs.readFile(path.join(branding, 'wave-mark.svg'), 'utf8');
  const paths = [...source.matchAll(/<path id="[^"]+" d="([^"]+)"/g)].map((match) => match[1]);
  if (paths.length !== 3) throw new Error('Expected three named Wave mark paths.');
  await generateIos(paths);
  await generateAndroid(paths);
  await generatePreview(paths);
  console.log('Generated Wave SVG masters, iOS appearances, Android adaptive/themed/legacy icons and store artwork.');
}

generate().catch((error) => { console.error(error); process.exitCode = 1; });
