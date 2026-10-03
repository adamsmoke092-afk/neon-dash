// Generates all Android launcher icon PNGs from the SVG sources.
// Runs in CI (never on the phone) — uses sharp for SVG rasterisation.
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const RES = 'android/app/src/main/res';

// Legacy icon sizes (dp → px per density)
const LEGACY = [
  { dir: 'mipmap-mdpi',    px: 48 },
  { dir: 'mipmap-hdpi',    px: 72 },
  { dir: 'mipmap-xhdpi',   px: 96 },
  { dir: 'mipmap-xxhdpi',  px: 144 },
  { dir: 'mipmap-xxxhdpi', px: 192 },
];

// Adaptive icon layers: 108dp canvas at each density
const ADAPTIVE = [
  { dir: 'mipmap-mdpi',    px: 108 },
  { dir: 'mipmap-hdpi',    px: 162 },
  { dir: 'mipmap-xhdpi',   px: 216 },
  { dir: 'mipmap-xxhdpi',  px: 324 },
  { dir: 'mipmap-xxxhdpi', px: 432 },
];

async function main() {
  const fgSvg = fs.readFileSync('android-src/icon-foreground.svg');
  const bgSvg = fs.readFileSync('android-src/icon-background.svg');

  // Legacy: composite fg over bg into a single square PNG
  for (const d of LEGACY) {
    const dir = path.join(RES, d.dir);
    fs.mkdirSync(dir, { recursive: true });

    const bgPng = await sharp(bgSvg).resize(d.px, d.px).png().toBuffer();
    const fgPng = await sharp(fgSvg).resize(d.px, d.px).png().toBuffer();

    const out = path.join(dir, 'ic_launcher.png');
    await sharp(bgPng).composite([{ input: fgPng }]).png().toFile(out);
    fs.copyFileSync(out, path.join(dir, 'ic_launcher_round.png'));
  }

  // Adaptive layers (API 26+): separate fg and bg PNGs
  for (const d of ADAPTIVE) {
    const dir = path.join(RES, d.dir);
    fs.mkdirSync(dir, { recursive: true });

    await sharp(fgSvg).resize(d.px, d.px).png()
      .toFile(path.join(dir, 'ic_launcher_foreground.png'));
    await sharp(bgSvg).resize(d.px, d.px).png()
      .toFile(path.join(dir, 'ic_launcher_background.png'));
  }

  // Adaptive icon XML pointing at the layers above
  const xmlDir = path.join(RES, 'mipmap-anydpi-v26');
  fs.mkdirSync(xmlDir, { recursive: true });

  const xml = [
    '<?xml version="1.0" encoding="utf-8"?>',
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">',
    '    <background android:drawable="@mipmap/ic_launcher_background"/>',
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>',
    '</adaptive-icon>',
    ''
  ].join('\n');

  fs.writeFileSync(path.join(xmlDir, 'ic_launcher.xml'), xml);
  fs.writeFileSync(path.join(xmlDir, 'ic_launcher_round.xml'), xml);

  // Splash screen: 1080x1920 PNG in drawable, replaces Capacitor's white default
  const splashSvg = fs.readFileSync('android-src/splash.svg');
  const drawableDir = path.join(RES, 'drawable');
  fs.mkdirSync(drawableDir, { recursive: true });
  await sharp(splashSvg).png().toFile(path.join(drawableDir, 'splash.png'));

  console.log('Icons generated: legacy (5 densities) + adaptive (5 densities + XML) + splash screen');
}

main().catch(err => { console.error(err); process.exit(1); });
