// Validate shipped asset dimensions, alpha requirements and Android safe area.
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');
const root = path.resolve(__dirname, '../..');

async function verify() {
  const catalog = path.join(root, 'ios/Runner/Assets.xcassets/AppIcon.appiconset');
  const contents = JSON.parse(await fs.readFile(path.join(catalog, 'Contents.json'), 'utf8'));
  assert.equal(contents.images.length, 3);
  for (const image of contents.images) {
    const metadata = await sharp(path.join(catalog, image.filename)).metadata();
    assert.equal(metadata.width, 1024);
    assert.equal(metadata.height, 1024);
    assert.equal(metadata.hasAlpha, false, 'iOS icons must be opaque square exports');
  }
  const tinted = await sharp(path.join(catalog, 'Wave-tinted.png')).raw().toBuffer();
  for (let i = 0; i < tinted.length; i += 3) {
    assert.equal(tinted[i], tinted[i + 1], 'Tint source must be grayscale');
    assert.equal(tinted[i], tinted[i + 2]);
  }
  const macos = path.join(root, 'macos/Runner/Assets.xcassets/AppIcon.appiconset');
  const macContents = JSON.parse(await fs.readFile(path.join(macos, 'Contents.json'), 'utf8'));
  for (const image of macContents.images) {
    const size = Number(image.size.split('x')[0]) * Number(image.scale.replace('x', ''));
    const metadata = await sharp(path.join(macos, image.filename)).metadata();
    assert.equal(metadata.width, size);
    assert.equal(metadata.height, size);
    assert.equal(metadata.hasAlpha, true, 'macOS icon must preserve its transparent outer margin');
  }
  const macPixels = await sharp(path.join(macos, 'app_icon_1024.png')).ensureAlpha().raw().toBuffer();
  assert.equal(macPixels[3], 0, 'macOS icon corners must be transparent');
  let violetPixels = 0;
  for (let i = 0; i < macPixels.length; i += 4) {
    if (Math.abs(macPixels[i] - 112) < 3 && Math.abs(macPixels[i + 1] - 84) < 3 &&
        Math.abs(macPixels[i + 2] - 215) < 3 && macPixels[i + 3] === 255) violetPixels++;
  }
  assert(violetPixels > 10000, 'macOS icon must contain Wave violet artwork, not the Flutter placeholder');
  const android = path.join(root, 'android/app/src/main/res');
  for (const night of [false, true]) {
    for (const [density, size] of Object.entries({ mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 })) {
      const metadata = await sharp(path.join(android, `mipmap-${night ? 'night-' : ''}${density}/ic_launcher.png`)).metadata();
      assert.equal(metadata.width, size);
      assert.equal(metadata.height, size);
    }
    for (const api of [26, 33]) {
      const xml = await fs.readFile(path.join(android, `mipmap-${night ? 'night-' : ''}anydpi-v${api}/ic_launcher.xml`), 'utf8');
      assert(xml.includes('@drawable/wave_icon_foreground'));
      assert.equal(xml.includes('<monochrome'), api === 33);
    }
  }
  const monochrome = await fs.readFile(path.join(android, 'drawable/wave_icon_monochrome.xml'), 'utf8');
  const paths = [...monochrome.matchAll(/android:pathData="([^"]+)"/g)].map((match) => match[1]);
  const transform = monochrome.match(/android:translateX="([^"]+)" android:translateY="([^"]+)" android:scaleX="([^"]+)"/);
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1080" viewBox="0 0 108 108"><g transform="translate(${transform[1]} ${transform[2]}) scale(${transform[3]})" fill="none" stroke="white" stroke-width="18" stroke-linecap="round" stroke-linejoin="round">${paths.map((d) => `<path d="${d}"/>`).join('')}</g></svg>`;
  const pixels = await sharp(Buffer.from(svg)).ensureAlpha().raw().toBuffer();
  let minX = 1080, minY = 1080, maxX = 0, maxY = 0;
  for (let y = 0; y < 1080; y++) {
    for (let x = 0; x < 1080; x++) {
      if (pixels[(y * 1080 + x) * 4 + 3] < 16) continue;
      assert(Math.hypot(x + 0.5 - 540, y + 0.5 - 540) <= 331, 'Foreground exceeds Android 66dp safe circle');
      minX = Math.min(minX, x); maxX = Math.max(maxX, x);
      minY = Math.min(minY, y); maxY = Math.max(maxY, y);
    }
  }
  assert(maxX - minX >= 480 && maxY - minY >= 480, 'Mark must occupy at least 48x48dp');
  console.log('Verified macOS catalog sizes, transparency and Wave branding; iOS opaque 1024px appearances, grayscale tint, Android density/adaptive layers and 66dp safe-circle containment.');
}

verify().catch((error) => { console.error(error); process.exitCode = 1; });
