// Browser test of the add-on's Home Assistant Ingress panel.
//
// Usage: node e2e.mjs <base-url> <ingress-token>
//   <base-url>       origin of the emulated Supervisor (see supervisor.conf)
//   <ingress-token>  the token in /api/hassio_ingress/<token>/
//
// What it guards: the T3 Code client assumes it lives at "/". The add-on's nginx
// and /_ingress/shim.js make it work under the ingress prefix. A T3 Code upgrade
// can break that, and this test is how we notice. The Supervisor's root answers
// 404 "HA-ROOT-LEAK" for anything outside the prefix, so a request that escapes
// the prefix shows up in `leaks` here (and in the proxy log checked by the
// wrapper script, which also sees WebSockets).
import { chromium } from "playwright";

const [base, token] = process.argv.slice(2);
if (!base || !token) {
  console.error("usage: node e2e.mjs <base-url> <ingress-token>");
  process.exit(2);
}
const origin = new URL(base).origin;
const prefix = `/api/hassio_ingress/${token}`;
const entry = `${origin}${prefix}/`;
const TIMEOUT = 45_000;
const PROJECT_TITLE = "Home Assistant config"; // registered by the add-on's init-t3 service
const SETTINGS_LINK = 'a[href*="settings"], button[aria-label*="ettings"]';
const shotDir = process.env.E2E_SCREENSHOT_DIR;

let failures = 0;
let currentPage;

// check(name, fn): runs one assertion, reports it and keeps going on failure.
async function check(name, fn) {
  try {
    await fn();
    console.log(`PASS: ${name}`);
  } catch (e) {
    failures++;
    console.error(`FAIL: ${name}: ${String(e.message ?? e).split("\n")[0]}`);
    if (shotDir && currentPage) {
      const file = `${shotDir}/${name.replace(/[^A-Za-z0-9]+/g, "-")}.png`;
      await currentPage.screenshot({ path: file }).catch(() => {});
    }
  }
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const inPrefix = (pathname) => pathname === prefix || pathname.startsWith(`${prefix}/`);

// newContext(browser): a fresh browser profile (so auto sign-in runs every time)
// that records same-origin requests escaping the ingress prefix. Cross-origin
// requests (for example clerk.t3.codes) never reach the Supervisor and are ignored.
async function newContext(browser) {
  const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const leaks = [];
  context.on("request", (request) => {
    const url = new URL(request.url());
    // blob: URLs (workers built from object URLs) carry the page origin but never hit the network.
    if (url.protocol === "blob:") return;
    if (url.origin === origin && !inPrefix(url.pathname) && url.pathname !== "/ha-panel") {
      leaks.push(`${request.method()} ${url.pathname}`);
    }
  });
  return { context, leaks };
}

const browser = await chromium.launch();
try {
  // --- Top-level page: load, WebSocket, navigation, reload ---------------------
  {
    const { context, leaks } = await newContext(browser);
    const page = await context.newPage();
    currentPage = page;
    page.on("pageerror", (e) => console.log(`info: pageerror: ${String(e).slice(0, 200)}`));
    const socketErrors = [];
    const wsOpened = page.waitForEvent("websocket", {
      predicate: (ws) => {
        ws.on("socketerror", (e) => socketErrors.push(String(e)));
        return inPrefix(new URL(ws.url()).pathname);
      },
      timeout: TIMEOUT,
    });
    wsOpened.catch(() => {}); // reported by the check below

    await check("app loads and shows the auto-registered project", async () => {
      await page.goto(entry, { waitUntil: "load" });
      await page.getByText(PROJECT_TITLE).first().waitFor({ timeout: TIMEOUT });
    });

    await check("a WebSocket is opened under the ingress prefix", async () => {
      const ws = await wsOpened;
      assert(socketErrors.length === 0, `WebSocket errors: ${socketErrors.join("; ")}`);
      assert(/^wss?:/.test(ws.url()), `unexpected WebSocket URL ${ws.url()}`);
    });

    await check("clicking Settings keeps the ingress prefix", async () => {
      await page.locator(SETTINGS_LINK).first().click();
      await page.waitForURL((url) => /\/settings/.test(url.pathname), { timeout: TIMEOUT });
      const { pathname } = new URL(page.url());
      assert(inPrefix(pathname), `left the prefix: ${pathname}`);
    });

    await check("reloading a settings deep link still renders settings", async () => {
      await page.reload({ waitUntil: "load" });
      await page.getByText(/settings/i).first().waitFor({ timeout: TIMEOUT });
      const { pathname } = new URL(page.url());
      assert(inPrefix(pathname) && /\/settings/.test(pathname), `unexpected URL after reload: ${pathname}`);
    });

    await check("no top-level request escaped the ingress prefix", async () => {
      assert(leaks.length === 0, `escaped requests: ${leaks.join(", ")}`);
    });
    await context.close();
  }

  // --- Inside an iframe, as Home Assistant embeds the panel --------------------
  {
    const { context, leaks } = await newContext(browser);
    const page = await context.newPage();
    currentPage = page;
    await context.route(`${origin}/ha-panel`, (route) =>
      route.fulfill({
        contentType: "text/html",
        body: `<html><body style="margin:0"><iframe id="f" src="${prefix}/" style="width:100vw;height:100vh;border:0"></iframe></body></html>`,
      }),
    );
    const frame = page.frameLocator("#f");

    await check("app loads inside an iframe", async () => {
      await page.goto(`${origin}/ha-panel`);
      await frame.getByText(PROJECT_TITLE).first().waitFor({ timeout: TIMEOUT });
    });

    await check("Settings works and keeps the prefix inside the iframe", async () => {
      await frame.locator(SETTINGS_LINK).first().click();
      const inner = page.frames().find((f) => f !== page.mainFrame());
      assert(inner, "iframe not found");
      await inner.waitForURL((url) => /\/settings/.test(url.pathname), { timeout: TIMEOUT });
      assert(inPrefix(new URL(inner.url()).pathname), `left the prefix: ${inner.url()}`);
    });

    await check("no iframe request escaped the ingress prefix", async () => {
      assert(leaks.length === 0, `escaped requests: ${leaks.join(", ")}`);
    });
    await context.close();
  }
} finally {
  await browser.close();
}

if (failures > 0) {
  console.error(`${failures} check(s) failed`);
  process.exit(1);
}
console.log("all ingress e2e checks passed");
