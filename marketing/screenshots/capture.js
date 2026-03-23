/**
 * Batch-export store screenshots using Puppeteer.
 *
 * Usage:
 *   npm install puppeteer   (one-time)
 *   node capture.js
 *
 * Generates PNGs in ./output/
 */

const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

const OUTPUT_DIR = path.join(__dirname, 'output');

async function main() {
  if (!fs.existsSync(OUTPUT_DIR)) fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  const browser = await puppeteer.launch({ headless: 'new' });
  const page = await browser.newPage();

  // ── Phone screenshots (1284×2778) ────────────────────────────
  const phonePath = path.join(__dirname, 'phone_screenshots.html');
  await page.goto(`file:///${phonePath.replace(/\\/g, '/')}`, { waitUntil: 'networkidle0' });
  await page.waitForSelector('.slide');

  const slides = await page.$$('.slide');
  for (let i = 0; i < slides.length; i++) {
    const name = await slides[i].evaluate(el => el.dataset.name || `slide_${i + 1}`);

    // Set viewport wide enough for the slide to render, then screenshot the element at 3x
    const box = await slides[i].boundingBox();
    await slides[i].screenshot({
      path: path.join(OUTPUT_DIR, `${name}.png`),
      type: 'png',
      // Capture at the CSS size — multiply by deviceScaleFactor for final resolution
    });
    console.log(`✓  ${name}.png`);
  }

  // Now re-capture at 3x (1284×2778 final size)
  await page.setViewport({ width: 1400, height: 3000, deviceScaleFactor: 3 });
  await page.goto(`file:///${phonePath.replace(/\\/g, '/')}`, { waitUntil: 'networkidle0' });
  await page.waitForSelector('.slide');

  const slides3x = await page.$$('.slide');
  for (let i = 0; i < slides3x.length; i++) {
    const name = await slides3x[i].evaluate(el => el.dataset.name || `slide_${i + 1}`);
    await slides3x[i].screenshot({
      path: path.join(OUTPUT_DIR, `${name}_hires.png`),
      type: 'png',
    });
    console.log(`✓  ${name}_hires.png  (1284×2778)`);
  }

  // ── Feature graphic (1024×500) ──────────────────────────────
  const fgPath = path.join(__dirname, 'feature_graphic.html');
  await page.setViewport({ width: 1200, height: 700, deviceScaleFactor: 1 });
  await page.goto(`file:///${fgPath.replace(/\\/g, '/')}`, { waitUntil: 'networkidle0' });
  await page.waitForSelector('.graphic');

  const graphic = await page.$('.graphic');
  await graphic.screenshot({
    path: path.join(OUTPUT_DIR, 'feature_graphic_1024x500.png'),
    type: 'png',
  });
  console.log('✓  feature_graphic_1024x500.png');

  await browser.close();
  console.log(`\nDone — ${fs.readdirSync(OUTPUT_DIR).length} files in ${OUTPUT_DIR}`);
}

main().catch(err => { console.error(err); process.exit(1); });
