// Rendert Icons, Thumbnails und Promo-Videos.
// Aufruf: node render.js <fontDir> <outDir> [stills|videos|all] [spielname...]
const { chromium } = require("playwright");
const { execFileSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const { scenes, SIZES } = require("./art");

const [fontDir, outDir, mode = "all", ...only] = process.argv.slice(2);
const games = only.length ? only : Object.keys(scenes);
const FPS = 30, DURATION = 10;

// Schrift als data-URL einbetten (file://-URLs lädt eine about:blank-Seite nicht)
const fontData = fs.readFileSync(path.resolve(fontDir, "LilitaOne-Regular.ttf")).toString("base64");
const fontCss = `
@font-face { font-family: 'Lilita One'; src: url(data:font/ttf;base64,${fontData}) format('truetype'); }
body { margin: 0; background: #000; }`;

// Feste Zeitpunkte für Standbilder (schönster Moment der Szene)
const STILL_T = { obby: 1.1, clicker: 1.3, tycoon: 1.7, disaster: 0.6, garden: 2.2 };

async function main() {
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch();
  for (const game of games) {
    const formats = mode === "videos" ? [] : ["icon", "thumb"];
    for (const fmt of formats) {
      const [w, h] = SIZES[fmt];
      const page = await browser.newPage({ viewport: { width: w, height: h } });
      const svg = scenes[game](fmt, STILL_T[game]);
      await page.setContent(`<style>${fontCss}</style><svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}">${svg}</svg>`);
      await page.evaluate(async () => { await document.fonts.load("100px 'Lilita One'"); await document.fonts.ready; });
      const file = path.join(outDir, `${game}-${fmt}.png`);
      await page.screenshot({ path: file });
      await page.close();
      console.log("wrote", file);
    }
    if (mode === "stills") continue;
    const [w, h] = SIZES.video;
    const frameDir = fs.mkdtempSync(path.join(outDir, `.frames-${game}-`));
    const page = await browser.newPage({ viewport: { width: w, height: h } });
    await page.setContent(`<style>${fontCss}</style><svg id="s" xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"></svg>`);
    await page.evaluate(() => document.fonts.load("100px 'Lilita One'"));
    for (let f = 0; f < FPS * DURATION; f++) {
      const svg = scenes[game]("video", f / FPS);
      await page.evaluate((markup) => { document.getElementById("s").innerHTML = markup; }, svg);
      await page.screenshot({ path: path.join(frameDir, `f${String(f).padStart(4, "0")}.png`) });
    }
    await page.close();
    const file = path.join(outDir, `${game}-promo.mp4`);
    execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-framerate", String(FPS), "-i", path.join(frameDir, "f%04d.png"),
      "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", "-movflags", "+faststart", file]);
    fs.rmSync(frameDir, { recursive: true, force: true });
    console.log("wrote", file);
  }
  await browser.close();
}

main().catch((e) => { console.error(e); process.exit(1); });
