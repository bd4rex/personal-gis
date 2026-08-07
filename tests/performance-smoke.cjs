const fs = require("node:fs");
const { chromium } = require("playwright");

const chromeCandidates = [
  "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
  "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe"
];
const executablePath = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH
  || chromeCandidates.find((candidate) => fs.existsSync(candidate));
const baseUrl = process.env.GISS_UI_URL || "http://127.0.0.1:8080";

(async () => {
  const launchOptions = { headless: true, args: ["--no-proxy-server"] };
  if (executablePath) launchOptions.executablePath = executablePath;
  const browser = await chromium.launch(launchOptions);
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await context.newPage();
  const startedAt = Date.now();
  const failures = [];
  let mapPackRequests = 0;

  page.on("request", (request) => {
    if (new URL(request.url()).pathname === "/api/map-packs") mapPackRequests += 1;
  });
  page.on("requestfailed", (request) => {
    const failure = request.failure()?.errorText || "failed";
    const expectedAbort = failure.includes("ERR_ABORTED") || failure.includes("ERR_NETWORK_CHANGED");
    if (!expectedAbort) failures.push(`${request.url()} ${failure}`);
  });

  await page.goto(`${baseUrl}/?lon=118.89574&lat=32.05272&zoom=12&perf=${Date.now()}`, {
    waitUntil: "domcontentloaded",
    timeout: 90000
  });
  const domContentLoadedMs = Date.now() - startedAt;
  await page.locator("canvas.maplibregl-canvas").waitFor({ state: "visible", timeout: 30000 });
  const mapCanvasMs = Date.now() - startedAt;
  await page.waitForFunction(
    () => document.querySelector("#systemState")?.textContent === "本地在线",
    null,
    { timeout: 30000 }
  );
  const systemReadyMs = Date.now() - startedAt;
  await page.waitForTimeout(2500);

  const resources = await page.evaluate(() => performance.getEntriesByType("resource")
    .filter((entry) => /map-packs|map-pack-boundaries|world-region-catalog|osm-carto\/tile|\.pmtiles/.test(entry.name))
    .map((entry) => ({
      name: entry.name.replace(location.origin, ""),
      startMs: Math.round(entry.startTime),
      durationMs: Math.round(entry.duration),
      transferBytes: entry.transferSize,
      decodedBytes: entry.decodedBodySize
    }))
    .sort((left, right) => left.startMs - right.startMs));

  await browser.close();
  if (mapPackRequests !== 1) throw new Error(`Startup requested /api/map-packs ${mapPackRequests} times.`);
  if (mapCanvasMs > 15000) throw new Error(`Map canvas took ${mapCanvasMs} ms to appear.`);
  if (systemReadyMs > 15000) throw new Error(`Local services took ${systemReadyMs} ms to appear ready.`);
  if (failures.length) throw new Error(failures.join("\n"));

  console.log(JSON.stringify({
    domContentLoadedMs,
    mapCanvasMs,
    systemReadyMs,
    mapPackRequests,
    resources
  }, null, 2));
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
