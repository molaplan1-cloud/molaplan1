/* v4 screenshots (new cities + location-first flow) against the in-memory mock. Server: python3 -m http.server 8765 (in this folder).
   node shots-v4.js  -> shots/v4-*.png (390x844 @2x). Geolocation is stubbed (Kallio, Helsinki). */
const { chromium } = require('playwright-core');
const SHOTS = __dirname + '/shots/', BASE = process.env.URL || 'http://127.0.0.1:8765/index.html';
const KALLIO = [60.1834, 24.9612];
(async () => {
  const browser = await chromium.launch({ executablePath: '/usr/bin/google-chrome', args: ['--no-sandbox'] });
  const errors = [];
  const newPage = async (locale, geo) => {
    const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale, timezoneId: 'Europe/Helsinki' });
    if (geo) await ctx.addInitScript(geo => {
      Object.defineProperty(navigator, 'geolocation', { configurable: true, value: { getCurrentPosition: (res) => setTimeout(() => res({ coords: { latitude: geo[0], longitude: geo[1], accuracy: 20 }, timestamp: Date.now() }), 80), watchPosition: () => 0, clearWatch: () => {} } });
      Object.defineProperty(navigator, 'permissions', { configurable: true, value: { query: () => Promise.resolve({ state: 'prompt', onchange: null }) } });
    }, geo);
    const p = await ctx.newPage();
    p.on('pageerror', e => errors.push(e.message));
    p.on('console', m => { if (m.type() === 'error' && !/tile\.openstreetmap|Failed to load resource/.test(m.text())) errors.push(m.text()); });
    return p;
  };
  const tiles = async (p) => { try { await p.waitForFunction(() => { const i = [...document.querySelectorAll('img.leaflet-tile')]; return i.length && i.every(x => x.complete && x.naturalWidth > 0); }, null, { timeout: 15000 }); } catch (e) { console.log('  (map tiles did not load)'); } };
  const shot = async (p, n) => { await p.evaluate(() => document.fonts.ready); await p.waitForTimeout(600); await p.screenshot({ path: SHOTS + n + '.png' }); console.log('saved', n); };
  const fresh = async (p, lang) => {
    await p.goto(BASE + '?mock=1');
    await p.evaluate(async (lang) => {
      window.__mockSupa.reset(); localStorage.clear(); sessionStorage.clear(); if (lang) localStorage.setItem('molaplan.lang', lang);
      const S = window.__mockSupa; S.createUser('hanna@example.com', 'Hanna', { city: 'Helsinki', district: 'Kallio' }); S.createUser('mikko@example.com', 'Mikko', { city: 'Helsinki', district: 'Kallio' });
      const h = S.as('hanna@example.com'), m = S.as('mikko@example.com'), d = (n, hh) => { const x = new Date(Date.now() + n * 864e5); x.setHours(hh, 0, 0, 0); return x.toISOString(); };
      const ev = [
        [h, 'padel', 'Padel töiden jälkeen', d(1, 18), 'Helsinki', 'Kallio', 'Kallion padelhalli', 60.1841, 24.9497, 4],
        [m, 'juoksu', 'Aamulenkki rantaa pitkin', d(2, 7), 'Helsinki', 'Siltasaari', 'Tokoinranta', 60.1796, 24.9447, 10],
        [h, 'lautapelit', 'Lautapeli-ilta', d(3, 19), 'Helsinki', 'Kallio', 'Kallion kirjasto', 60.1838, 24.9531, 8],
        [m, 'kahvi', 'Kahvia ja kieltenvaihtoa', d(4, 16), 'Helsinki', 'Kallio', 'Karhupuisto', 60.1830, 24.9500, 6],
        [h, 'jooga', 'Joogaa Kaivopuistossa', d(1, 9), 'Helsinki', 'Kaivopuisto', 'Kaivopuiston ranta', 60.1569, 24.9569, 12],
        [m, 'pyoraily', 'Pyörälenkki Vuosaareen', d(2, 17), 'Helsinki', 'Vuosaari', 'Vuosaaren satama', 60.2085, 25.1476, 8],
        [h, 'lautapelit', 'Juegos de mesa en Malasaña', d(1, 19), 'Madrid', 'Universidad', 'Plaza del Dos de Mayo', 40.4268, -3.7041, 8],
        [m, 'juoksu', 'Carrera por El Retiro', d(2, 8), 'Madrid', 'Jerónimos', 'Parque de El Retiro', 40.4153, -3.6845, 15],
        [h, 'kahvi', 'Café e intercambio en Lavapiés', d(2, 18), 'Madrid', 'Embajadores', 'Plaza de Lavapiés', 40.4088, -3.7011, 6],
        [m, 'padel', 'Pádel en Chamberí', d(3, 20), 'Madrid', 'Trafalgar', 'Club Chamberí', 40.4335, -3.7005, 4],
        [h, 'vaellus', 'Paseo por Madrid Río', d(4, 11), 'Madrid', 'Imperial', 'Madrid Río', 40.4050, -3.7190, 20],
        [m, 'valokuvaus', 'Fotografía en el Templo de Debod', d(5, 19), 'Madrid', 'Argüelles', 'Templo de Debod', 40.4240, -3.7177, 10],
      ];
      for (const [c, a, t, s, city, dist, place, lat, lng, max] of ev) await c.from('events').insert({ activity_id: a, title: t, starts_at: s, city, district: dist, place, lat, lng, max_participants: max });
    }, lang);
    await p.reload(); await p.waitForSelector('#landing');
  };
  const pick = async (p, city, district) => {
    await p.click('#land-manual-btn'); await p.waitForSelector('#land-city');
    await p.selectOption('#land-city', city); await p.selectOption('#land-district', district);
    await p.evaluate(() => document.querySelector('#land-city').blur());
    await p.evaluate(() => { const g = document.querySelector('#gate'), c = document.querySelector('#landing'); g.scrollTop = Math.max(0, c.offsetTop - 12); });
  };

  // location-first landing + near me (Finnish, geolocation at Kallio)
  let p = await newPage('fi-FI', KALLIO); await fresh(p, 'fi');
  await shot(p, 'v4-location-landing');
  await p.click('#land-locate'); await p.waitForSelector('#s-home.active .card');
  await p.waitForTimeout(3500);   // let the "events near you" toast fade
  await p.evaluate(() => document.querySelector('#s-home').scrollTop = 0);
  await shot(p, 'v4-near-me-top');                       // header: area + "Vaihda aluetta", Lista/Kartta toggle
  await p.setViewportSize({ width: 390, height: 1900 });  // tall: header, toggle and the distance-sorted list in one image
  await p.waitForTimeout(300);
  await shot(p, 'v4-near-me-list');
  await p.setViewportSize({ width: 390, height: 844 }); await p.waitForTimeout(300);
  await p.click('#vt-map'); await p.waitForSelector('#s-map.active'); await p.waitForFunction(() => document.querySelectorAll('#s-map .leaflet-marker-icon').length >= 3); await tiles(p);
  await shot(p, 'v4-near-me-map');
  await p.context().close();

  // landing with a new city selected
  for (const [lang, locale, city, district, name] of [['sv', 'sv-SE', 'Stockholm', 'Södermalm', 'v4-landing-stockholm-sv'], ['en', 'en-GB', 'London', 'Shoreditch', 'v4-landing-london-en'], ['es', 'es-ES', 'Madrid', 'Sol', 'v4-landing-madrid-es']]) {
    p = await newPage(locale); await fresh(p, lang); await pick(p, city, district);
    await shot(p, name);
    if (city === 'Madrid') {
      await p.click('#land-map'); await p.waitForSelector('#s-map.active'); await p.waitForFunction(() => document.querySelectorAll('#s-map .leaflet-marker-icon').length >= 5); await tiles(p);
      await shot(p, 'v4-map-madrid-es');
      await p.click('#nav [data-t="home"]'); await p.waitForSelector('#s-home.active .card');
      await shot(p, 'v4-home-madrid-es');
    }
    await p.context().close();
  }
  await browser.close();
  if (errors.length) { console.error('page errors:', errors); process.exit(1); }
  console.log('done');
})().catch(e => { console.error(e); process.exit(1); });
