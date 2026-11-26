// Live E2E of the admin + download flow (not in CI). Needs a throw-away account that the runner
// temporarily adds to private.shop_admins:  node test/e2e-admin-live.cjs <email> <password> [shotDir]
const { chromium } = require(process.env.PW || '/workspace/molaplan-tools/pw/node_modules/playwright-core');
const [EMAIL, PW, OUT = '/workspace/molaplan-shots/shop'] = process.argv.slice(2);
const BASE = 'https://shop.molaplan.com/tilaa/';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const fs = require('fs');
(async () => {
  const browser = await chromium.launch({ executablePath: '/usr/bin/google-chrome', headless: !process.env.HEADED });
  const errors = [];
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'fi-FI' });
  const page = await ctx.newPage();
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('dialog', (d) => d.accept());
  await page.goto(`${BASE}hallinta/`, { waitUntil: 'networkidle' });
  await page.fill('#le', EMAIL);
  await page.click('#lpw');
  await page.fill('#lp', PW);
  await page.click('#lverify');
  await page.waitForSelector('.orow', { timeout: 15000 });
  console.log('badge', await page.textContent('#newCount'), 'rows', await page.locator('.orow').count());
  await page.screenshot({ path: `${OUT}/admin-1-orders.png` });
  await page.locator('.orow').first().click();
  await page.waitForSelector('#seg');
  await sleep(500);
  await page.screenshot({ path: `${OUT}/admin-2-order.png`, fullPage: true });
  // offer price + template + send (expected to fail on the free plan -> logged as failed)
  await page.fill('#offer', '249,90');
  await page.click('#saveOffer');
  await sleep(800);
  await page.locator('[data-tpl]', { hasText: 'Tarjous' }).click();
  const body = await page.inputValue('#rbody');
  console.log('template filled:', /249,90/.test(body), /#100\d/.test(await page.inputValue('#rsub')));
  await page.click('#rsend');
  await sleep(4000);
  const toastTxt = await page.locator('.toast').allTextContents();
  console.log('send toast', toastTxt);
  await page.waitForSelector('#seg');
  // one-tap status
  await page.locator('#seg [data-s="laskutettu"]').click();
  await sleep(2500);
  console.log('status now', await page.locator('#seg button.on').textContent());
  await page.screenshot({ path: `${OUT}/admin-3-after-reply.png`, fullPage: true });
  // products: create with fixed price + image, hide, move up, then delete
  await page.click('a[data-tab="tuotteet"]');
  await page.waitForSelector('#newP');
  await page.click('#newP');
  await page.fill('#pn', 'E2E-testituote');
  await page.check('input[name=pm][value=fixed]');
  await page.fill('#pp', '19,90');
  await page.fill('#pnote', '/ kpl');
  await page.setInputFiles('#pimg', '/workspace/molaplan-brochure/icon.png');
  await sleep(800);
  await page.screenshot({ path: `${OUT}/admin-4-product-editor.png` });
  await page.click('#psave');
  await page.waitForSelector('.prow:has-text("E2E-testituote")', { timeout: 15000 });
  const prow = page.locator('.prow', { hasText: 'E2E-testituote' });
  console.log('product row', (await prow.textContent()).replace(/\s+/g, ' ').trim());
  await prow.locator('[data-up]').click(); await sleep(1500);
  await page.screenshot({ path: `${OUT}/admin-5-products.png`, fullPage: true });
  // public page shows the fixed price + image
  const pub = await ctx.newPage();
  await pub.goto(BASE, { waitUntil: 'networkidle' }); await pub.waitForSelector('.card');
  const card = pub.locator('.card', { hasText: 'E2E-testituote' });
  console.log('public card', (await card.locator('.price').textContent()).trim(), 'img', await card.locator('img').count());
  await pub.close();
  await page.locator('.prow', { hasText: 'E2E-testituote' }).locator('[data-hide]').click(); await sleep(1500);
  console.log('hidden', await page.locator('.prow.hid', { hasText: 'E2E-testituote' }).count());
  await page.locator('.prow', { hasText: 'E2E-testituote' }).locator('[data-edit]').click();
  await page.click('#pdel'); await sleep(2000);
  console.log('deleted', (await page.locator('.prow', { hasText: 'E2E-testituote' }).count()) === 0);
  // settings render
  await page.click('a[data-tab="asetukset"]'); await page.waitForSelector('#ssave');
  await page.screenshot({ path: `${OUT}/admin-6-settings.png`, fullPage: true });
  // tokens for API checks done by the runner
  const tok = await page.evaluate(() => JSON.parse(localStorage.getItem('molaplan-shop-auth')).access_token);
  fs.writeFileSync('/tmp/shop-e2e-token', tok, { mode: 0o600 });
  // desktop admin layout
  const d = await browser.newPage({ viewport: { width: 1360, height: 900 } });
  await d.goto(`${BASE}hallinta/`, { waitUntil: 'networkidle' });
  console.log('errors', errors);
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
