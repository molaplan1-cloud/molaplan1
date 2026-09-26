/* v3 screenshots (guest mode) against the in-memory mock. Server: python3 -m http.server 8765 (in this folder).
   node shots-v3.js  -> shots/v3-*.png (390x844 @2x) */
const { chromium } = require('playwright-core');
const SHOTS = __dirname + '/shots/', BASE = process.env.URL || 'http://127.0.0.1:8765/index.html';
(async () => {
  const browser = await chromium.launch({ executablePath: '/usr/bin/google-chrome', args: ['--no-sandbox'] });
  const errors = [];
  const newPage = async (locale) => {
    const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale, timezoneId: 'Europe/Helsinki' });
    const p = await ctx.newPage();
    p.on('pageerror', e => errors.push(e.message));
    p.on('console', m => { if (m.type() === 'error' && !/tile\.openstreetmap|Failed to load resource/.test(m.text())) errors.push(m.text()); });
    return p;
  };
  const tiles = async (p) => { try { await p.waitForFunction(() => { const i = [...document.querySelectorAll('img.leaflet-tile')]; return i.length && i.every(x => x.complete && x.naturalWidth > 0); }, null, { timeout: 15000 }); } catch (e) { console.log('  (map tiles did not load)'); } };
  const shot = async (p, n) => { await p.evaluate(() => document.fonts.ready); await p.waitForTimeout(500); await p.screenshot({ path: SHOTS + n + '.png' }); console.log('saved', n); };
  const fresh = async (p, lang) => {
    await p.goto(BASE + '?mock=1');
    await p.evaluate(async (lang) => {
      window.__mockSupa.reset(); localStorage.clear(); sessionStorage.clear(); if (lang) localStorage.setItem('molaplan.lang', lang);
      const S = window.__mockSupa; S.createUser('hanna@example.com', 'Hanna', { city: 'Helsinki', district: 'Kallio' });
      S.createUser('mikko@example.com', 'Mikko', { city: 'Helsinki', district: 'Kallio' }); S.createUser('admin0@example.com', 'Admin', { admin: true });
      const h = S.as('hanna@example.com'), m = S.as('mikko@example.com'), d = (n, hh) => { const x = new Date(Date.now() + n * 864e5); x.setHours(hh, 0, 0, 0); return x.toISOString(); };
      const T = { fi: ['Padel töiden jälkeen', 'Aamulenkki rantaa pitkin', 'Lautapeli-ilta', 'Kahvia ja kieltenvaihtoa', 'Kauppakassit 4. kerrokseen', 'Tarvitsisin apua kauppakassien kantamisessa kerran viikossa.'],
        en: ['Padel after work', 'Morning run by the bay', 'Board game night', 'Coffee & language exchange', 'Groceries up to the 4th floor', 'I would need help carrying groceries home once a week.'],
        es: ['Pádel después del trabajo', 'Carrera matutina junto a la bahía', 'Noche de juegos de mesa', 'Café e intercambio de idiomas', 'Compra hasta el 4.º piso', 'Necesitaría ayuda para subir la compra una vez por semana.'],
        sv: ['Padel efter jobbet', 'Morgonlöpning vid viken', 'Brädspelskväll', 'Kaffe och språkutbyte', 'Matkassar upp till fjärde våningen', 'Jag skulle behöva hjälp att bära hem matkassar en gång i veckan.'] }[lang || 'fi'];
      const ev = [
        [h, 'padel', T[0], d(1, 18), 'Kallio', 'Kallion padelhalli', 60.1841, 24.9497, 4],
        [m, 'juoksu', T[1], d(2, 7), 'Kallio', 'Tokoinranta', 60.1796, 24.9447, 10],
        [h, 'lautapelit', T[2], d(3, 19), 'Kallio', 'Kallio library', 60.1838, 24.9531, 8],
        [m, 'kahvi', T[3], d(4, 16), 'Kallio', 'Karhupuisto', 60.1830, 24.9500, 6],
      ];
      for (const [c, a, t, s, dist, place, lat, lng, max] of ev) await c.from('events').insert({ activity_id: a, title: t, starts_at: s, city: 'Helsinki', district: dist, place, lat, lng, max_participants: max });
      const r = await m.rpc('submit_help_request', { req: { category: 'kauppa', title: T[4], description: T[5], city: 'Helsinki', district: 'Kallio', place: 'Helsinginkatu 1', lat: 60.1849, lng: 24.9481, starts_at: d(2, 12), duration: '1h', helpers_needed: 1, consent_voluntary: true, consent_terms: true, consent_review: true }, contact: { name: 'Mikko', phone: '+358401112233', email: 'mikko@example.com' } });
      await S.as('admin0@example.com').from('help_requests').update({ status: 'approved' }).eq('id', r.data);
    }, lang);
    await p.reload(); await p.waitForSelector('#landing');
  };
  const land = async (p, tab) => { if (!(await p.isVisible('#land-city'))) await p.click('#land-manual-btn'); await p.selectOption('#land-city', 'Helsinki'); await p.selectOption('#land-district', 'Kallio'); await p.click(tab === 'map' ? '#land-map' : '#land-go'); await p.waitForSelector(tab === 'map' ? '#s-map.active' : '#s-home.active .card'); };

  let p = await newPage('fi-FI'); await fresh(p, 'fi');
  await p.click('#land-manual-btn'); await p.selectOption('#land-city', 'Helsinki'); await p.selectOption('#land-district', 'Kallio');
  await shot(p, 'v3-guest-landing');
  await land(p, 'map'); await p.waitForFunction(() => document.querySelectorAll('#s-map .leaflet-marker-icon').length >= 2); await tiles(p);
  await shot(p, 'v3-guest-map');
  await p.click('#nav [data-t="home"]'); await p.waitForSelector('#s-home.active .card');
  await shot(p, 'v3-guest-home');
  await p.click('#s-home .card [data-a="join"]'); await p.waitForSelector('#auth-prompt'); await p.waitForTimeout(400);
  await shot(p, 'v3-login-sheet');
  await p.context().close();

  p = await newPage('en-GB'); await fresh(p, 'en');
  await p.click('#land-manual-btn'); await p.selectOption('#land-city', 'Helsinki'); await p.selectOption('#land-district', 'Kallio');
  await shot(p, 'v3-guest-landing-en');
  await p.context().close();

  for (const l of ['es', 'sv']) {
    p = await newPage(l === 'es' ? 'es-ES' : 'sv-SE'); await fresh(p, l); await land(p, 'home');
    await shot(p, 'v3-home-' + l);
    await p.context().close();
  }
  await browser.close();
  if (errors.length) { console.error('page errors:', errors); process.exit(1); }
  console.log('done');
})().catch(e => { console.error(e); process.exit(1); });
