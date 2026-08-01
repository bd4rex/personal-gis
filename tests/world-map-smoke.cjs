const fs = require("node:fs");
const path = require("node:path");
const { chromium } = require("playwright");

const chromeCandidates = [
  "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
  "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe"
];
const executablePath = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH
  || chromeCandidates.find((candidate) => fs.existsSync(candidate));

const outputDir = path.resolve(__dirname, "..", "runtime", "ui-smoke");
const baseUrl = process.env.GISS_UI_URL || "http://127.0.0.1:8080";
fs.mkdirSync(outputDir, { recursive: true });

(async () => {
  const launchOptions = { headless: true, args: ["--no-proxy-server"] };
  if (executablePath) launchOptions.executablePath = executablePath;
  const browser = await chromium.launch(launchOptions);
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  const errors = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("console", (message) => {
    if (message.type() === "error" && !message.text().includes("/api/")) errors.push(message.text());
  });

  await page.goto(`${baseUrl}/`, { waitUntil: "load" });
  await page.waitForFunction(() => document.querySelector("#systemState")?.textContent === "本地在线", null, { timeout: 90000 });
  await page.getByRole("button", { name: "系统", exact: true }).click();
  await page.getByRole("button", { name: "管理资源", exact: true }).click();
  await page.waitForURL("**/resources.html");
  await page.waitForFunction(() => document.querySelectorAll("#versionRows tr[data-pack-row]").length >= 5, null, { timeout: 90000 });
  await page.getByRole("button", { name: /添加区域/ }).click();
  await page.locator('[data-catalog-scope="global"]').click();
  await page.locator("#catalogSearch").fill("日本");
  const locate = page.getByRole("button", { name: /在地图中定位 日本/ });
  await locate.waitFor({ state: "visible" });
  await locate.click();

  await page.waitForURL("**/?coverage=gf-japan");
  await page.waitForFunction(() => document.querySelector("#coveragePromptTitle")?.textContent.includes("日本") && !document.querySelector("#coveragePrompt")?.hidden, null, { timeout: 30000 });
  const overview = await page.evaluate(async () => {
    const image = new Image();
    image.src = "/assets/overview/gray-earth.jpg?v=mercator-4096-20260801";
    await image.decode();
    return { width: image.naturalWidth, height: image.naturalHeight };
  });
  if (overview.width !== 4096 || overview.height !== 4096) {
    throw new Error(`Offline world overview is not a WebGL-safe Web Mercator square: ${overview.width}x${overview.height}.`);
  }
  await page.screenshot({ path: path.join(outputDir, "world-region-prompt.png") });

  await page.locator("#onlineMapShortcut").click();
  await page.locator("#mapSourcePopover").waitFor({ state: "visible" });
  const japanCoverage = await page.locator("#mapCoverageStatus").textContent();
  if (!japanCoverage.includes("日本") || !japanCoverage.includes("未安装")) {
    throw new Error(`Map source control did not reflect Japan offline coverage: ${japanCoverage}`);
  }
  await page.screenshot({ path: path.join(outputDir, "map-source-menu-japan.png") });
  await page.locator('#mapSourcePopover [data-online-provider="osm"]').click();
  if (await page.locator("#onlineMapShortcut").getAttribute("aria-pressed") !== "true") {
    throw new Error("Online OSM view did not become active.");
  }
  await page.waitForFunction(() => document.querySelector("#onlineMapShortcut")?.title.includes("已连接"), null, { timeout: 15000 });
  const toastBox = await page.locator("#toast").boundingBox();
  const shortcutBox = await page.locator("#onlineMapShortcut").boundingBox();
  if (toastBox && shortcutBox) {
    const overlaps = toastBox.x < shortcutBox.x + shortcutBox.width
      && toastBox.x + toastBox.width > shortcutBox.x
      && toastBox.y < shortcutBox.y + shortcutBox.height
      && toastBox.y + toastBox.height > shortcutBox.y;
    if (overlaps) throw new Error("Map source toast overlaps the source shortcut.");
  }
  await page.screenshot({ path: path.join(outputDir, "world-region-online.png") });

  await page.locator('[data-tab="layers"]').click();
  await page.locator('[data-tab-panel="layers"] [data-online-provider="openfreemap"]').click();
  await page.waitForFunction(() => document.querySelector("#onlineMapShortcut")?.title.includes("OpenFreeMap") && document.querySelector('[data-online-provider="openfreemap"]')?.classList.contains("active"), null, { timeout: 25000 });
  await page.screenshot({ path: path.join(outputDir, "world-region-openfreemap.png") });
  await page.locator('[data-tab-panel="layers"] [data-online-provider="osm"]').click();
  await page.waitForFunction(() => document.querySelector("#onlineMapShortcut")?.title.includes("OSM 标准地图已连接"), null, { timeout: 15000 });

  await page.locator("#coverageDownloadButton").click();
  await page.waitForURL("**/resources.html?pack=gf-japan");
  await page.waitForFunction(() => document.querySelector('[data-catalog-pack="gf-japan"]'), null, { timeout: 90000 });
  if (await page.getByRole("button", { name: "构建", exact: true }).count() !== 1) {
    throw new Error("World-map download prompt did not hand off to the selected offline package.");
  }

  await page.goto(`${baseUrl}/?coverage=jiangsu`, { waitUntil: "load" });
  await page.waitForFunction(() => document.querySelector("#systemState")?.textContent === "本地在线", null, { timeout: 30000 });
  await page.waitForFunction(() => document.querySelector("#mapCoverageStatus")?.textContent.includes("江苏省已安装并启用"), null, { timeout: 15000 });
  await page.locator("#onlineMapShortcut").click();
  await page.locator('#mapSourcePopover [data-online-provider="offline"]').click();
  if (await page.locator("#onlineMapShortcut").getAttribute("aria-pressed") !== "false") {
    throw new Error("Online OSM view did not turn off.");
  }

  const fallbackPage = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await fallbackPage.route("https://tile.openstreetmap.org/**", (route) => route.abort("internetdisconnected"));
  await fallbackPage.addInitScript(() => {
    localStorage.setItem("giss-online-map", "true");
    localStorage.setItem("giss-online-provider", "osm");
  });
  await fallbackPage.goto(`${baseUrl}/?coverage=gf-japan`, { waitUntil: "load" });
  await fallbackPage.locator("#coveragePrompt").waitFor({ state: "visible", timeout: 15000 });
  await fallbackPage.waitForFunction(() => {
    const shortcut = document.querySelector("#onlineMapShortcut");
    return shortcut?.title.includes("OpenFreeMap") && shortcut.classList.contains("fallback");
  }, null, { timeout: 25000 });
  if (!(await fallbackPage.locator("#onlineMapShortcut").evaluate((button) => button.classList.contains("fallback")))) {
    throw new Error("OSM failure did not switch to the OpenFreeMap vector fallback.");
  }
  await fallbackPage.screenshot({ path: path.join(outputDir, "world-region-online-vector-fallback.png") });
  await fallbackPage.close();

  const degradedPage = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await degradedPage.route("https://tile.openstreetmap.org/**", (route) => route.abort("internetdisconnected"));
  await degradedPage.route("https://tiles.openfreemap.org/**", (route) => route.abort("internetdisconnected"));
  await degradedPage.addInitScript(() => {
    localStorage.setItem("giss-online-map", "true");
    localStorage.setItem("giss-online-provider", "osm");
  });
  await degradedPage.goto(`${baseUrl}/?coverage=gf-japan`, { waitUntil: "load" });
  await degradedPage.waitForFunction(() => {
    const shortcut = document.querySelector("#onlineMapShortcut");
    return shortcut?.title.includes("在线不可用") && shortcut.classList.contains("degraded");
  }, null, { timeout: 25000 });
  if (!(await degradedPage.locator("#onlineMapShortcut").evaluate((button) => button.classList.contains("degraded")))) {
    throw new Error("Failure of both online providers did not expose the offline overview fallback state.");
  }
  await degradedPage.screenshot({ path: path.join(outputDir, "world-region-online-fallback.png") });
  await degradedPage.close();

  const boundaryPayload = await page.evaluate(async () => {
    const response = await fetch("/api/map-pack-boundaries", { cache: "no-store" });
    return response.json();
  });
  const pointInRing = (longitude, latitude, ring) => {
    let inside = false;
    for (let current = 0, previous = ring.length - 1; current < ring.length; previous = current++) {
      const [currentLongitude, currentLatitude] = ring[current];
      const [previousLongitude, previousLatitude] = ring[previous];
      if ((currentLatitude > latitude) !== (previousLatitude > latitude)
          && longitude < ((previousLongitude - currentLongitude) * (latitude - currentLatitude)) / (previousLatitude - currentLatitude) + currentLongitude) {
        inside = !inside;
      }
    }
    return inside;
  };
  const boundaryContains = (name, longitude, latitude) => {
    const boundary = boundaryPayload.boundaries[name];
    return boundary.include.some((ring) => pointInRing(longitude, latitude, ring))
      && !boundary.exclude.some((ring) => pointInRing(longitude, latitude, ring));
  };
  if (!boundaryContains("taiwan", 121.56, 25.04) || boundaryContains("fujian", 121.56, 25.04)) {
    throw new Error("Taipei is not distinguished from Fujian by the offline package boundaries.");
  }

  const taiwanPage = await browser.newPage({ viewport: { width: 760, height: 900 } });
  await taiwanPage.goto(`${baseUrl}/?coverage=gf-taiwan`, { waitUntil: "load" });
  await taiwanPage.locator("#coveragePrompt").waitFor({ state: "visible", timeout: 30000 });
  const taiwanPrompt = await taiwanPage.locator("#coveragePromptTitle").textContent();
  if (!taiwanPrompt.includes("台湾") || /Taiwan/i.test(taiwanPrompt)) {
    throw new Error(`Taiwan offline prompt was not localized: ${taiwanPrompt}`);
  }
  await taiwanPage.locator("#onlineMapShortcut").click();
  const taiwanCoverage = await taiwanPage.locator("#mapCoverageStatus").textContent();
  if (!taiwanCoverage.includes("台湾") || !taiwanCoverage.includes("未安装")) {
    throw new Error(`Map source coverage did not refresh for Taiwan: ${taiwanCoverage}`);
  }
  await taiwanPage.screenshot({ path: path.join(outputDir, "map-source-menu-taiwan.png") });
  await taiwanPage.close();

  await browser.close();
  if (errors.length) throw new Error(errors.join("\n"));
  console.log("World map smoke test passed: source menu, live offline coverage, localized prompts, automatic fallback, and package handoff.");
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
