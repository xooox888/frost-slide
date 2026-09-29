/**
 * Regenerates the iOS app icon and launch image from the painted art in the Swift app's asset
 * catalog: `node scripts/ios-assets.mjs` (needs Playwright's Chromium). Writes opaque RGB PNGs,
 * because App Store icons must not have an alpha channel, which canvas PNGs always carry.
 */
import { chromium } from '@playwright/test';
import { readFileSync, writeFileSync } from 'node:fs';
import { deflateSync } from 'node:zlib';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const swiftAssets = `${root}/FrostSlide/FrostSlide/Assets.xcassets`;
const iosAssets = `${root}/web/ios/App/App/Assets.xcassets`;

/** Minimal PNG encoder: 8-bit RGB, no alpha. */
function encodeRGB(width, height, rgba) {
  const raw = Buffer.alloc((width * 3 + 1) * height);
  for (let y = 0; y < height; y += 1) {
    raw[y * (width * 3 + 1)] = 0; // filter: none
    for (let x = 0; x < width; x += 1) {
      const src = (y * width + x) * 4;
      const dst = y * (width * 3 + 1) + 1 + x * 3;
      raw[dst] = rgba[src];
      raw[dst + 1] = rgba[src + 1];
      raw[dst + 2] = rgba[src + 2];
    }
  }
  const crcTable = Array.from({ length: 256 }, (_, n) => {
    let c = n;
    for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    return c >>> 0;
  });
  const crc = (buf) => {
    let c = 0xffffffff;
    for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
  };
  const chunk = (type, data) => {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
    const sum = Buffer.alloc(4);
    sum.writeUInt32BE(crc(body));
    return Buffer.concat([len, body, sum]);
  };
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8; // bit depth
  header[9] = 2; // colour type: RGB
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', header),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

const dataURL = (path) => `data:image/jpeg;base64,${readFileSync(path).toString('base64')}`;

const browser = await chromium.launch();
const page = await browser.newPage();
async function draw(width, height, script, images) {
  const pixels = await page.evaluate(
    async ({ width, height, script, images }) => {
      const loaded = await Promise.all(
        images.map(async (src) => {
          const img = new Image();
          img.src = src;
          await img.decode();
          return img;
        }),
      );
      const canvas = new OffscreenCanvas(width, height);
      const ctx = canvas.getContext('2d');
      new Function('ctx', 'images', 'width', 'height', script)(ctx, loaded, width, height);
      // Base64 moves megabytes out of the page far faster than a JSON array would.
      const bytes = ctx.getImageData(0, 0, width, height).data;
      let binary = '';
      for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
      return btoa(binary);
    },
    { width, height, script, images },
  );
  return encodeRGB(width, height, Buffer.from(pixels, 'base64'));
}

// App icon: the painted icon, flattened.
const icon = await draw(1024, 1024, 'ctx.drawImage(images[0], 0, 0, width, height);', [
  dataURL(`${swiftAssets}/AppIcon.appiconset/AppIcon.png`),
]);
writeFileSync(`${iosAssets}/AppIcon.appiconset/AppIcon-512@2x.png`, icon);

// Launch image: the brand badge centred on the Swift launch colour (0.07, 0.10, 0.22). The
// storyboard aspect-fills this square, so the badge sits in the middle third. (Capacitor's
// template names the files 2732 px; 1366 px is plenty for a phone and keeps the app small.)
const splash = await draw(
  1366,
  1366,
  `ctx.fillStyle = 'rgb(18, 26, 56)';
   ctx.fillRect(0, 0, width, height);
   const size = 380;
   ctx.save();
   ctx.beginPath();
   ctx.roundRect((width - size) / 2, (height - size) / 2, size, size, 85);
   ctx.clip();
   ctx.drawImage(images[0], (width - size) / 2, (height - size) / 2, size, size);
   ctx.restore();`,
  [dataURL(`${swiftAssets}/BrandBadge.imageset/BrandBadge.png`)],
);
for (const name of ['splash-2732x2732.png', 'splash-2732x2732-1.png', 'splash-2732x2732-2.png']) {
  writeFileSync(`${iosAssets}/Splash.imageset/${name}`, splash);
}
await browser.close();
console.log('Wrote the app icon and launch images.');
