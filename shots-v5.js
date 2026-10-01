/* v5 screenshots (rebalanced home, public + business events, business accounts, moderation) against the in-memory mock.
   Server: python3 -m http.server 8765 (in this folder).   node shots-v5.js  -> shots/v5-*.png (390x844 @2x) */
const { chromium } = require('playwright-core');
const SHOTS = __dirname + '/shots/', BASE = process.env.URL || 'http://127.0.0.1:8765/index.html';
(async () => {
  const browser = await chromium.launch({ executablePath: '/usr/bin/google-chrome', args: ['--no-sandbox'] });
  const errors = [];
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale: 'fi-FI', timezoneId: 'Europe/Helsinki' });
  const p = await ctx.newPage();
  p.on('pageerror', e => errors.push(e.message));
  p.on('console', m => { if (m.type() === 'error' && !/tile\.openstreetmap|Failed to load resource/.test(m.text())) errors.push(m.text()); });
  p.on('dialog', d => d.accept());
  const tiles = async () => { try { await p.waitForFunction(() => { const i = [...document.querySelectorAll('img.leaflet-tile')]; return i.length && i.every(x => x.complete && x.naturalWidth > 0); }, null, { timeout: 12000 }); } catch (e) { console.log('  (tiles not loaded)'); } };
  const shot = async (n) => { await p.evaluate(() => document.fonts.ready); await p.waitForTimeout(700); await p.screenshot({ path: SHOTS + n + '.png' }); console.log('saved', n); };
  const go = async (session, lang, guest) => { await p.goto('about:blank'); await p.goto(BASE + '?mock=1'); await p.evaluate(([s, l, g]) => { if (s) localStorage.setItem('molaplan.mock.session', window.__mockSupa.userId(s)); else localStorage.removeItem('molaplan.mock.session'); localStorage.setItem('molaplan.lang', l); if (g) localStorage.setItem('molaplan.guest', JSON.stringify({ city: 'Helsinki', district: 'Kallio' })); else localStorage.removeItem('molaplan.guest'); }, [session, lang, guest]); await p.goto('about:blank'); await p.goto(BASE + '?mock=1'); };
  await p.goto(BASE + '?mock=1');
  await p.evaluate(async () => {
    window.__mockSupa.reset(); localStorage.clear(); sessionStorage.clear();
    const S = window.__mockSupa;
    S.createUser('aino@example.com', 'Aino', { admin: true, phone: '+358401111111' });
    S.createUser('hanna@example.com', 'Hanna', { phone: '+358402222222', favs: ['juoksu', 'padel'] });
    S.createUser('mikko@example.com', 'Mikko', { phone: '+358403333333' });
    S.createUser('pekka@example.com', 'Pekka', { phone: '+358404444444' });
    const A = S.as('aino@example.com'), H = S.as('hanna@example.com'), K = S.as('mikko@example.com'), P = S.as('pekka@example.com');
    const d = (n, hh, mm = 0) => { const x = new Date(Date.now() + n * 864e5); x.setHours(hh, mm, 0, 0); return x.toISOString(); };
    const ev = (c, o) => c.from('events').insert(Object.assign({ city: 'Helsinki', max_participants: 8, skill_level: 'all' }, o)).select().single();
    await ev(H, { activity_id: 'juoksu', title: 'Iltalenkki Töölönlahdella', starts_at: d(1, 18, 30), district: 'Töölö', place: 'Finlandia-talo', lat: 60.1757, lng: 24.9339, description: 'Rauhallinen 8 km, omakustanteinen sauna perään.' });
    await ev(K, { activity_id: 'padel', title: 'Padel töiden jälkeen', starts_at: d(2, 17), district: 'Kallio', place: 'Kallion padelhalli', lat: 60.1841, lng: 24.9497, max_participants: 4 });
    await ev(H, { activity_id: 'lautapelit', title: 'Lautapeli-ilta', starts_at: d(3, 19), district: 'Kallio', place: 'Kallion kirjasto', lat: 60.1838, lng: 24.9531 });
    await ev(K, { activity_id: 'kahvi', title: 'Kahvia ja kieltenvaihtoa', starts_at: d(4, 16), district: 'Kallio', place: 'Karhupuisto', lat: 60.1830, lng: 24.95 });
    const pub = await ev(A, { kind: 'public', activity_id: 'juoksutapahtuma', title: 'Helsinki City Run', starts_at: d(5, 10), ends_at: d(5, 15), district: 'Taka-Töölö', place: 'Olympiastadion', lat: 60.1869, lng: 24.9272, max_participants: 5000, organizer_name: 'Helsinki City Run ry', official_url: 'https://helsinkicityrun.fi', price_info: 'Alk. 45 €', description: 'Puolimaraton ja 10 km kaikille. Ilmoittautuminen virallisella sivulla – etsi täältä seuraa ja lähdetään yhdessä!' });
    await ev(A, { kind: 'public', activity_id: 'festivaali', title: 'Flow Festival', starts_at: d(9, 14), ends_at: d(11, 23), district: 'Vallila', place: 'Suvilahti', lat: 60.1872, lng: 24.9716, max_participants: 30000, organizer_name: 'Flow Festival Oy', official_url: 'https://www.flowfestival.com', price_info: 'Liput 89–229 €' });
    for (const c of [H, K]) await c.from('event_participants').insert({ event_id: pub.data.id, user_id: c.id });
    // help requests
    const help = async (c, q, contact) => { const r = await c.rpc('submit_help_request', { req: Object.assign({ city: 'Helsinki', helpers_needed: 1, consent_voluntary: true, consent_terms: true, consent_review: true, duration: '1h' }, q), contact }); await A.from('help_requests').update({ status: 'approved', admin_reason: '' }).eq('id', r.data); };
    await help(K, { category: 'koira', title: 'Koiran ulkoilutus ma–ke', description: 'Vanha labradori kaipaa lenkkiseuraa, kun olen leikkauksen jälkeen toipumassa.', needs: 'Rauhallinen ulkoiluttaja', district: 'Kallio', place: 'Helsinginkatu', lat: 60.1845, lng: 24.9502, starts_at: d(1, 12) }, { name: 'Mikko', phone: '+358403333333' });
    await help(H, { category: 'siivous', title: 'Apua pihatalkoisiin', description: 'Haravoidaan taloyhtiön piha yhdessä, kahvit tarjolla.', needs: '2 haravoijaa', district: 'Kallio', place: 'Pengerkatu', lat: 60.1869, lng: 24.9551, starts_at: d(2, 10), helpers_needed: 2 }, { name: 'Hanna', phone: '+358402222222' });
    // business: approved + active, second pending
    const b1 = await P.rpc('apply_business', { biz: { name: 'Pekan Pyörä Oy', business_code: '0737546-2', country: 'FI', website: 'https://pekanpyora.fi', description: 'Pyöräkorjaamo Kalliossa', consent_terms: true }, contact: { contact_email: 'pekka@example.com', phone: '+358404444444', billing_address: 'Pyöräkatu 1, 00530 Helsinki' } });
    const t = new Date(Date.now() + 5 * 864e5).toISOString().slice(0, 10);
    await A.from('businesses').update({ status: 'approved' }).eq('id', b1.data); await A.from('businesses').update({ subscription_active_until: t }).eq('id', b1.data);
    await ev(P, { kind: 'business', business_id: b1.data, activity_id: 'pyoraily', title: 'Pyörähuollon ilta', starts_at: d(3, 17), district: 'Kallio', place: 'Pekan Pyörä, Vaasankatu 5', lat: 60.1861, lng: 24.9536, max_participants: 30, price_info: '10 € / pyörä', official_url: 'https://pekanpyora.fi', description: 'Opettelemme perushuollon yhdessä – ketjut, jarrut ja renkaat.' });
    await ev(P, { kind: 'business', business_id: b1.data, activity_id: 'pyoraily', title: 'Kevätretki Nuuksioon', starts_at: d(6, 10), district: 'Kallio', place: 'Pekan Pyörä', lat: 60.1861, lng: 24.9536, max_participants: 25, price_info: 'Ilmainen' });
    await K.rpc('apply_business', { biz: { name: 'Kallion Joogastudio', business_code: '2245689-3', country: 'FI', website: 'https://kallionjooga.fi', consent_terms: true }, contact: { contact_email: 'info@kallionjooga.fi', phone: '+358405555555', e_invoice: '003722456893 / OKOYFIHH' } });
    // a report
    const bad = await ev(K, { activity_id: 'jooga', title: 'Aamujooga puistossa', starts_at: d(2, 8), district: 'Kallio', place: 'Karhupuisto', lat: 60.183, lng: 24.95, description: 'Tule mukaan, rento meininki!' });
    await H.from('reports').insert({ target_type: 'event', target_id: bad.data.id, reason: 'business_ad', note: 'Kutsuu chatissa maksulliselle kurssille' });
  });
  // 1. landing fi / en
  await go(null, 'fi'); await p.waitForSelector('#landing'); await shot('v5-landing');
  await go(null, 'en'); await p.waitForSelector('#landing'); await shot('v5-landing-en');
  // 2. home (logged in) with the help card
  await go('hanna@example.com', 'fi'); await p.waitForSelector('#s-home.active #help-card'); await shot('v5-home-good-deeds');
  // 3. public event detail
  const pubId = await p.evaluate(() => window.__mockSupa.db().events.find(e => e.title === 'Helsinki City Run').id);
  await p.click(`#s-home .card[data-id="${pubId}"]`); await p.waitForSelector('#s-detail.active #kind-strip'); await tiles(); await shot('v5-public-event-detail');
  await p.click('#s-detail [data-a="back"]');
  // 4. business events (chip)
  await p.click('#chip-biz-home'); await p.waitForTimeout(300); await p.evaluate(() => { const c = document.querySelector('#s-home .filters'); document.querySelector('#s-home').scrollTop = c.offsetTop - 10; }); await shot('v5-business-events');
  await p.click('#chip-biz-home').catch(() => {}); await p.evaluate(() => { document.querySelector('#s-home [data-v="all"]').click(); });
  // 5. create form with rule + live warning
  await p.click('#nav [data-t="create"]'); await p.waitForSelector('#s-create.active #c-rule');
  await p.fill('#c-title', 'Juoksukoulu'); await p.fill('#c-desc', 'Kurssin hinta 20 €, varaa paikka: www.juoksukoulu.fi');
  await p.evaluate(() => { const r = document.querySelector('#c-desc'); document.querySelector('#s-create').scrollTop = r.getBoundingClientRect().top + document.querySelector('#s-create').scrollTop - 200; }); await shot('v5-create-rules');
  // 6. business apply form
  await go('mikko@example.com', 'fi'); await p.waitForSelector('#s-home.active');
  await p.evaluate(() => { document.querySelector('#s-home .hdr-actions [data-t="profile"]').click(); }); await p.waitForSelector('#open-orgs'); await p.click('#open-orgs'); await p.waitForSelector('#org-biz'); await p.click('#org-biz'); await p.waitForSelector('#s-biz.active');
  await p.click('#biz-form-open').catch(() => {}); await p.waitForSelector('#biz-form'); await p.fill('#bz-name', 'Kallion Kahvila'); await p.fill('#bz-code', '1572860-0'); await p.waitForTimeout(100); await shot('v5-business-apply');
  // 7. admin business queue + reports
  await go('aino@example.com', 'fi'); await p.waitForSelector('#s-home.active');
  await p.evaluate(() => { document.querySelector('#s-home .hdr-actions [data-t="profile"]').click(); }); await p.waitForSelector('#open-admin'); await p.click('#open-admin'); await p.click('#adm-sec-biz'); await p.waitForSelector('#adm-biz-list');
  await shot('v5-admin-business-queue');
  await p.evaluate(() => { const s = document.querySelector('#s-admin'), c = document.querySelectorAll('#adm-biz-list .card')[1]; if (c) s.scrollTop = c.offsetTop - 60; }); await shot('v5-admin-business-queue-2');
  await p.click('#adm-sec-reports'); await p.waitForSelector('#adm-rep-list .card'); await shot('v5-admin-reports');
  console.log(errors.length ? 'ERRORS: ' + errors.join(' | ') : 'no page errors');
  await browser.close();
})();
