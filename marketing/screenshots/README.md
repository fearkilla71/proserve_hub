# ProServe Hub – Store Screenshot Generator

## How to use

1. Open `phone_screenshots.html` in Chrome / Edge
2. Each "slide" is sized to **1284 × 2778 px** (iPhone 6.7″ / Android equivalent)
3. Use **DevTools → Device toolbar → Responsive** at that size, or simply
   right-click each slide → *Inspect* → screenshot the node.
4. Fastest method: open the file, then run the **built-in export** button at the
   top — it uses `html2canvas` to save each slide as a PNG automatically.

### Quick CLI capture (requires Chrome)

```bash
# From this folder – generates 8 PNGs
node capture.js
```

## Files

| File | Purpose |
|------|---------|
| `phone_screenshots.html` | 8 marketing slides (phone mockup + headline) |
| `feature_graphic.html` | Google Play feature graphic 1024×500 |
| `capture.js` | Optional Node script using Puppeteer for batch export |

## Dimensions Reference

| Store | Asset | Size |
|-------|-------|------|
| Google Play | Phone screenshot | 1080×1920 or 1284×2778 |
| Google Play | Feature graphic | 1024×500 |
| App Store | 6.7″ display | 1290×2796 |
| App Store | 6.5″ display | 1284×2778 |
| App Store | 5.5″ display | 1242×2208 |
