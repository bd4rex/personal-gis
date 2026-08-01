const fs = require("node:fs");
const path = require("node:path");
const { chromium } = require("playwright");

const chromeCandidates = [
  "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
  "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe"
];
const executablePath = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH
  || chromeCandidates.find((candidate) => fs.existsSync(candidate));

const outputDir = path.resolve(__dirname, "..", "runtime", "resource-console-smoke");
const baseUrl = process.env.GISS_UI_URL || "http://127.0.0.1:8080";
fs.mkdirSync(outputDir, { recursive: true });

(async () => {
  const launchOptions = { headless: true, args: ["--no-proxy-server"] };
  if (executablePath) launchOptions.executablePath = executablePath;
  const browser = await chromium.launch(launchOptions);
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 });
  const errors = [];
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(`console: ${message.text()}`);
  });
  page.on("pageerror", (error) => errors.push(`page: ${error.message}`));
  page.on("requestfailed", (request) => errors.push(`request: ${request.url()} ${request.failure()?.errorText || "failed"}`));

  await page.goto(`${baseUrl}/resources.html`, { waitUntil: "load", timeout: 60000 });
  await page.waitForFunction(() => document.querySelectorAll("#versionRows tr[data-pack-row]").length >= 5, null, { timeout: 30000 });

  const rows = await page.locator("#versionRows tr[data-pack-row]").count();
  if (rows < 5) throw new Error(`Expected all installed map packs, found ${rows}.`);
  if (!/维护服务(在线|离线)/.test(await page.locator("#workerState").innerText())) {
    throw new Error("Maintenance worker state was not rendered.");
  }
  if (await page.locator(".version-table").evaluate((element) => element.scrollWidth > element.clientWidth + 2)) {
    throw new Error("Version table overflows its container.");
  }
  await page.locator('[data-pack-menu="jiangsu"]').click();
  await page.locator('[data-pack-action="info"][data-pack-id="jiangsu"]').click();
  await page.locator("#detailDialog").waitFor({ state: "visible" });
  if (!(await page.locator("#detailBody").innerText()).includes("7222152")) {
    throw new Error("Version detail does not expose the current source sequence.");
  }
  await page.locator("[data-close-dialog]").click();

  await page.screenshot({ path: path.join(outputDir, "versions-desktop.png"), fullPage: true });
  await page.getByRole("button", { name: /添加区域/ }).click();
  if (await page.locator('[data-catalog-pack]').count() !== 30) {
    throw new Error("Recommended catalog does not show every uninstalled province-level region.");
  }
  await page.locator('[data-catalog-scope="global"]').click();
  await page.locator("#catalogSearch").fill("日本");
  if (await page.locator('[data-catalog-pack="gf-japan"]').count() !== 1) {
    throw new Error("Global catalog search did not find Japan.");
  }
  await page.screenshot({ path: path.join(outputDir, "catalog-desktop.png"), fullPage: true });
  await page.getByRole("button", { name: /本地资源/ }).click();
  await page.waitForFunction(() => document.querySelectorAll(".resource-row").length >= 8);
  const localText = await page.locator("#localGroups").innerText();
  for (const expected of [
    "完整恢复包",
    "2 个已验证",
    "可再生",
    "系统能力",
    "地址检索索引"
  ]) {
    if (!localText.includes(expected)) {
      throw new Error(`Local resource classification is missing: ${expected}`);
    }
  }
  if (!localText.includes("外部卷") && !localText.includes("需检查")) {
    throw new Error("Search-index validity state was not rendered.");
  }
  await page.screenshot({ path: path.join(outputDir, "local-resources-desktop.png"), fullPage: true });
  await page.getByRole("button", { name: /任务与更新/ }).click();
  await page.waitForFunction(() => document.querySelector("#activeTasks"));
  await page.screenshot({ path: path.join(outputDir, "tasks-desktop.png"), fullPage: true });

  if (errors.length) throw new Error(errors.join("\n"));
  console.log(JSON.stringify({ ok: true, rows, screenshots: outputDir }, null, 2));
  await browser.close();
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
