// Live E2E of the order flow on https://shop.molaplan.com/tilaa/ (not in CI).
//   node test/e2e-live.cjs [base] [shotDir]
// Uses a reserved example.com customer address; the test order is deleted afterwards by the runner.
const { chromium } = require(process.env.PW || '/workspace/molaplan-tools/pw/node_modules/playwright-core');
const BASE = process.argv[2] || 'https://shop.molaplan.com/tilaa/';
const OUT = process.argv[3] || '/workspace/molaplan-shots/shop';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
(async () => {
  const browser = await chromium.launch({ executablePath: '/usr/bin/google-chrome', headless: !process.env.HEADED, args: ['--disable-blink-features=AutomationControlled'] });
  const errors = [];
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'fi-FI' });
  const page = await ctx.newPage();
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  await page.goto(BASE, { waitUntil: 'networkidle' });
  await page.waitForSelector('.card');
  const n = await page.locator('.card').count();
  console.log('cards', n);
  await page.screenshot({ path: `${OUT}/mobile-1-catalog.png`, fullPage: true });
  // PC app: straight to cart
  await page.locator('.card', { hasText: 'PC-sovellus' }).locator('[data-add]').click();
  // ESP IR: opens details dialog
  await page.locator('.card', { hasText: 'ESP IR' }).locator('[data-add]').click();
  await page.waitForSelector('#pdlg[open]');
  await page.fill('#dn', 'Testi: ilmalämpöpumppu, merkki ja malli');
  await page.locator('#dq').fill('2');
  await page.screenshot({ path: `${OUT}/mobile-2-details.png` });
  await page.click('#dAdd');
  await page.click('#cartBtn');
  await sleep(300);
  await page.screenshot({ path: `${OUT}/mobile-3-cart.png` });
  console.log('cart count', await page.textContent('#cartCount'));
  await page.click('#toCheckout');
  await page.waitForSelector('#viewCheckout:not([hidden])');
  // validation: submit empty
  await page.click('#sendBtn');
  console.log('validation:', await page.textContent('#formErr'));
  const email = `molaplan-shoptest-${Date.now()}@example.com`;
  await page.fill('#f_name', 'Testi Asiakas (automaattitesti)');
  await page.fill('#f_email', email);
  await page.fill('#f_phone', '+358 40 000 0000');
  await page.fill('#f_address', 'Testikatu 1, 00100 Helsinki');
  await page.fill('#f_message', 'Automaattinen testitilaus – voi poistaa.');
  await page.check('#f_consent');
  // Turnstile
  let token = '';
  for (let i = 0; i < 10 && !token; i++) { await sleep(500); token = await page.evaluate(() => window.turnstile?.getResponse?.() || ''); }
  if (!token) {
    // Managed mode may ask a headless browser to tick the box.
    const fr = page.frames().find((f) => f.url().includes('challenges.cloudflare.com'));
    if (fr) { const box = await page.locator('#tsBox iframe').boundingBox(); if (box) await page.mouse.click(box.x + 30, box.y + box.height / 2); }
  }
  for (let i = 0; i < 40 && !token; i++) { await sleep(500); token = await page.evaluate(() => window.turnstile?.getResponse?.() || ''); }
  console.log('turnstile token', token ? 'yes' : 'NO');
  await page.screenshot({ path: `${OUT}/mobile-4-checkout.png`, fullPage: true });
  if (process.env.NO_SUBMIT) { await browser.close(); return; }
  await page.click('#sendBtn');
  await page.waitForSelector('#viewThanks:not([hidden])', { timeout: 20000 }).catch(() => {});
  console.log('thanks visible', await page.isVisible('#viewThanks'), (await page.textContent('#thanksP').catch(() => '')).trim());
  console.log('form error', await page.isVisible('#formErr') ? await page.textContent('#formErr') : '-');
  await page.screenshot({ path: `${OUT}/mobile-5-thanks.png` });
  console.log('EMAIL', email);
  // desktop + languages
  const d = await browser.newPage({ viewport: { width: 1360, height: 900 } });
  for (const l of ['fi', 'en', 'sv', 'es']) {
    await d.goto(`${BASE}?lang=${l}`, { waitUntil: 'networkidle' });
    await d.waitForSelector('.card');
    await d.screenshot({ path: `${OUT}/desktop-${l}.png` });
  }
  await d.goto(`${BASE}tietosuoja/`, { waitUntil: 'networkidle' }); await sleep(500);
  await d.screenshot({ path: `${OUT}/desktop-privacy.png`, fullPage: true });
  await d.goto(`${BASE}hallinta/`, { waitUntil: 'networkidle' }); await sleep(800);
  await d.screenshot({ path: `${OUT}/desktop-admin-login.png` });
  console.log('errors', errors);
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
