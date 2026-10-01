/* Shareable event URLs (/e/<id>), per-event SEO (functions/e/[id].js via lib/event-page.mjs), share sheet, "Mola el plan!"
   headline + name card, participant limit field and the Photon place autocomplete.
   Part 1: unit tests of lib/event-page.mjs (no browser). Part 2: mock UI (headless Chrome, ?mock=1, Photon/Nominatim mocked).
   Needs the local server:  node serve.js 8765   (serves index.html for /e/<id> like Cloudflare Pages). SHOTS=1 writes screenshots. */
const fs = require('fs'), path = require('path');
const { chromium } = require('playwright-core');
const ROOT = 'http://127.0.0.1:8765', BASE = ROOT + '/index.html';
const SHOTS = !!process.env.SHOTS;
let passed = 0; const ok = (c, m) => { if (!c) throw new Error('ASSERT: ' + m); passed++; console.log('✔', m); };

(async () => {
  const L = await import(path.join(__dirname, 'lib/event-page.mjs'));
  const INDEX = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
  // ================= Part 1: unit =================
  const ID = '0b9c8f2e-1111-4222-8333-444455556666';
  ok(L.parseEventId(ID) === ID && L.parseEventId(ID.toUpperCase() + '-padel-illalla') === ID && L.parseEventId(ID + '/') === ID, 'parseEventId: bare id, id-slug, upper case, trailing slash');
  ok([null, '', 'abc', '123', ID.slice(0, 30), ID + 'x', "1' or '1'='1", '../config.js', ID.replace(/-/g, '')].every(s => L.parseEventId(s) === null), 'parseEventId rejects junk, SQL-ish and path input');
  ok(L.slugify('Padel töiden jälkeen') === 'padel-toiden-jalkeen' && L.slugify('Kahvit & "pullat" <script>') === 'kahvit-pullat-script' && L.slugify('¡Fútbol en el Retiro!') === 'futbol-en-el-retiro' && L.slugify('🤪🎉') === '', 'slugify: ä/ö/accents, symbols, emoji-only');
  const long = L.slugify('Erittäin pitkä tapahtuman nimi joka jatkuu ja jatkuu vielä pitkään');
  ok(long.length <= 48 && !/-$/.test(long), 'slug max 48 chars, no trailing dash');
  // SPA evSlug() must produce the same slug as the function
  const spaSrc = /function evSlug\(t\)\{[^\n]+\}/.exec(INDEX)[0];
  const evSlug = new Function(spaSrc + '; return evSlug;')();
  ok(['Padel töiden jälkeen', 'Kahvit & "pullat" <script>', 'Åkersberga – Sjöstaden', 'Erittäin pitkä tapahtuman nimi joka jatkuu ja jatkuu vielä pitkään', ''].every(t => evSlug(t) === L.slugify(t)), 'SPA evSlug() == lib slugify()');
  ok(L.eventPath({ id: ID, title: 'Lautapeli-ilta' }) === '/e/' + ID + '-lautapeli-ilta' && L.eventPath({ id: ID, title: '🎲' }) === '/e/' + ID, 'eventPath with and without slug');
  // config
  const cfg = L.parseConfigJs(fs.readFileSync(path.join(__dirname, 'config.js'), 'utf8'));
  ok(/^https:\/\/[a-z0-9]+\.supabase\.co$/.test(cfg.url) && /^eyJ/.test(cfg.key) && JSON.parse(Buffer.from(cfg.key.split('.')[1], 'base64url')).role === 'anon', 'config.js parsed: Supabase URL + key with role=anon (never service_role)');
  // inject into the real index.html
  const EV = { id: ID, title: 'Lautapeli-ilta Kalliossa', description: 'Tuo oma peli   tai pelaa meidän.\nKahvia on.', starts_at: '2026-10-03T16:00:00+00:00', ends_at: null, city: 'Helsinki', district: 'Kallio', place: 'Kallion kirjasto', lat: 60.1838, lng: 24.9531, kind: 'community', organizer_name: '', business_name: '', price_info: '', official_url: '', is_adult: false };
  const m1 = L.buildEventMeta(EV, 'fi');
  const r1 = L.injectMeta(INDEX, m1);
  ok(L.INJECT_STEPS.every(s => r1.steps[s] >= 1) && r1.steps.hreflang === 5 && r1.steps.jsonLd === 1, 'every injection step applies to the real index.html (' + JSON.stringify(r1.steps) + ')');
  const h1 = r1.html, metaOf = (h, attr, name) => { const mm = new RegExp('<meta ' + attr + '="' + name + '" content="([^"]*)">').exec(h); return mm && mm[1]; };
  ok((h1.match(/<title>/g) || []).length === 1 && /<title>Lautapeli-ilta Kalliossa · la 3\.10\. klo 19\.00 \| Molaplan<\/title>/.test(h1), 'title = event + local time (Helsinki, fi) + brand: ' + /<title>([^<]*)/.exec(h1)[1]);
  ok(metaOf(h1, 'property', 'og:url') === 'https://molaplan.com/e/' + ID + '-lautapeli-ilta-kalliossa' && /<link rel="canonical" href="https:\/\/molaplan.com\/e\/0b9c8f2e-1111-4222-8333-444455556666-lautapeli-ilta-kalliossa">/.test(h1), 'og:url + canonical = /e/<id>-<slug> on molaplan.com');
  ok(metaOf(h1, 'property', 'og:image') === 'https://molaplan.com/og-image.png' && metaOf(h1, 'property', 'og:title').startsWith('Lautapeli-ilta Kalliossa – ') && metaOf(h1, 'name', 'twitter:title') === metaOf(h1, 'property', 'og:title'), 'og:image default, og:title/twitter:title');
  ok(metaOf(h1, 'name', 'description').includes('Kallion kirjasto, Helsinki') && metaOf(h1, 'name', 'description').includes('Tuo oma peli tai pelaa meidän. Kahvia on.') && metaOf(h1, 'name', 'description').length <= 160, 'meta description: when · place, city. description (whitespace collapsed, ≤160)');
  ok(!/<link rel="alternate" hreflang/.test(h1) && metaOf(h1, 'name', 'robots').startsWith('noindex'), 'community event: hreflang alternates removed, robots noindex (shareable, not indexed)');
  const ld = JSON.parse(/<script type="application\/ld\+json" id="ld-event">([^<]*)<\/script>/.exec(h1)[1]);
  ok(ld['@type'] === 'Event' && ld.name === EV.title && ld.startDate === EV.starts_at && ld.location.address.addressCountry === 'FI' && ld.location.geo.latitude === 60.1838 && ld.organizer.name === 'Molaplan' && ld.isAccessibleForFree === true, 'JSON-LD Event: name, startDate, place + FI + geo, organizer (no host name), free');
  ok(/<article class="onb-card land-about" id="seo-event"><h1>Lautapeli-ilta Kalliossa<\/h1>/.test(h1) && /id="seo-about">\s*<h2>Molaplan – seuraa/.test(h1) && (/<section id="gate"[^]*?<\/section>/.exec(h1)[0].match(/<h1>/g) || []).length === 1, 'static crawler content: event h1 first, about text demoted to h2 (one h1)');
  ok(!/6d53cc50|host_id|email/.test(JSON.stringify(m1)), 'no host id / e-mail in the meta');
  const PUB = Object.assign({}, EV, { kind: 'public', title: 'Helsinki City Run', organizer_name: 'Helsinki City Run ry', ends_at: '2026-10-03T13:00:00+00:00', city: 'Madrid', district: 'Retiro' });
  const m2 = L.buildEventMeta(PUB, 'en'), h2 = L.injectMeta(INDEX, m2).html, ld2 = JSON.parse(/id="ld-event">([^<]*)</.exec(h2)[1]);
  ok(metaOf(h2, 'name', 'robots').startsWith('index') && ld2.organizer.name === 'Helsinki City Run ry' && ld2.endDate && ld2.location.address.addressCountry === 'ES' && !('isAccessibleForFree' in ld2) && /18:00/.test(m2.title) && metaOf(h2, 'property', 'og:locale') === 'en_GB', 'public event (en, Madrid time): indexable, organiser, endDate, ES, og:locale en_GB');
  // escaping / injection attempts in user content
  const EVIL = Object.assign({}, EV, { title: '"><script>alert(1)</script>', description: 'x</script><script>alert(2)</script> & <!-- \u2028', place: '<img src=x onerror=alert(3)>' });
  const he = L.injectMeta(INDEX, L.buildEventMeta(EVIL, 'fi')).html;
  const ldRaw = /id="ld-event">([^]*?)<\/script>/.exec(he)[1];
  ok(!/<script>alert|<img src=x|<!-- \u2028/.test(he) && !/[<>]/.test(ldRaw) && !/\u2028/.test(ldRaw) && he.includes('&quot;&gt;&lt;script&gt;alert(1)&lt;/script&gt;'), 'user content is HTML-escaped in tags and \\u003c-escaped inside JSON-LD (no script injection)');
  ok(JSON.parse(/id="ld-event">([^<]*)</.exec(he)[1]).name === EVIL.title, 'escaped JSON-LD still parses back to the original title');
  // not found
  const nf = L.injectMeta(INDEX, L.buildNotFoundMeta('fi')).html;
  ok(metaOf(nf, 'name', 'robots') === 'noindex, follow' && /<title>Tapahtumaa ei löytynyt \| Molaplan<\/title>/.test(nf) && !/ld-event/.test(nf) && metaOf(nf, 'property', 'og:url') === 'https://molaplan.com/', 'unknown/forbidden id: generic page, noindex, no Event JSON-LD');
  // handler with stubs: RLS-safe source, statuses, headers
  const calls = [];
  const asset = p => Promise.resolve({ text: async () => p === '/' ? INDEX : fs.readFileSync(path.join(__dirname, 'config.js'), 'utf8') });
  const fake = rows => async (u, o) => { calls.push({ u, o }); return { ok: true, status: 200, json: async () => rows }; };
  const a = await L.handleEventRequest({ url: 'https://molaplan.com/e/' + ID + '-x', idSeg: ID + '-x', getAsset: asset, fetchImpl: fake([EV]) });
  ok(a.status === 200 && a.meta.found && calls.length === 1 && /\/rest\/v1\/guest_events\?select=/.test(calls[0].u) && /id=eq\.0b9c8f2e-1111-4222-8333-444455556666/.test(calls[0].u) && calls[0].o.headers.apikey === cfg.key && !/host_id/.test(calls[0].u), 'handler reads only guest_events with the anon key (200)');
  ok(a.headers['X-Robots-Tag'] === 'noindex' && /max-age=60/.test(a.headers['Cache-Control']), 'community page: X-Robots-Tag noindex, short cache');
  const b = await L.handleEventRequest({ url: 'https://molaplan.com/e/' + ID, idSeg: ID, getAsset: asset, fetchImpl: fake([]) });
  ok(b.status === 404 && !b.meta.found && b.headers['X-Robots-Tag'] === 'noindex' && /noindex/.test(b.html), 'not visible to guests (private / 18+ / past – empty from RLS): 404 generic noindex');
  const n0 = calls.length; const c = await L.handleEventRequest({ url: 'https://molaplan.com/e/hello', idSeg: 'hello', getAsset: asset, fetchImpl: fake([EV]) });
  ok(c.status === 404 && calls.length === n0, 'invalid id: no DB request at all, 404');
  const d = await L.handleEventRequest({ url: 'https://molaplan.com/e/' + ID, idSeg: ID, getAsset: asset, fetchImpl: fake([Object.assign({}, EV, { is_adult: true })]) });
  ok(d.status === 404, 'defence in depth: an 18+ row is never rendered');
  const e = await L.handleEventRequest({ url: 'https://molaplan.com/e/' + ID, idSeg: ID, getAsset: asset, fetchImpl: async () => { throw new Error('network down'); } });
  ok(e.status === 503 && e.headers['Cache-Control'] === 'no-store' && /noindex/.test(e.html), 'Supabase down: 503 generic page, not cached');
  const f = await L.handleEventRequest({ url: 'https://molaplan.com/e/' + ID + '?lang=sv', idSeg: ID, getAsset: asset, fetchImpl: fake([PUB]) });
  ok(f.status === 200 && !f.headers['X-Robots-Tag'] && /<meta property="og:locale" content="sv_SE">/.test(f.html), 'public event: indexable (no X-Robots-Tag), ?lang=sv respected');
  const sm = L.sitemapXml([{ id: ID, title: 'Helsinki City Run', kind: 'public', created_at: '2026-10-01T10:00:00Z' }, { id: ID.replace('0b', '1c'), title: 'Kahvit', kind: 'community' }]);
  ok(/<loc>https:\/\/molaplan.com\/e\/0b9c8f2e-1111-4222-8333-444455556666-helsinki-city-run<\/loc><lastmod>2026-10-01<\/lastmod>/.test(sm) && !/kahvit/.test(sm) && /^<\?xml/.test(sm), 'sitemap-events.xml: public/business only, loc + lastmod');
  ok(/Sitemap: https:\/\/molaplan.com\/sitemap-events.xml/.test(fs.readFileSync(path.join(__dirname, 'robots.txt'), 'utf8')), 'robots.txt references sitemap-events.xml');
  ok(/<script defer src="\/config.js"><\/script>/.test(INDEX) && /<script defer src="\/i18n.js"><\/script>/.test(INDEX) && /<script defer src="\/friend-requests.js"><\/script>/.test(INDEX) && /loadScript\('\/mock-supabase.js'\)/.test(INDEX), 'scripts use absolute /paths (work under /e/<id>)');

  // ================= Part 2: mock UI =================
  const browser = await chromium.launch({ executablePath: '/usr/bin/google-chrome', args: ['--no-sandbox'] });
  const errors = [];
  let DBJSON = null;   // the seeded mock DB, copied into every new browser context (localStorage is per context)
  const mkPage = async (opts = {}) => {
    const ctx = await browser.newContext(Object.assign({ viewport: { width: 390, height: 844 }, locale: 'fi-FI', timezoneId: 'Europe/Helsinki', deviceScaleFactor: 2 }, opts));
    if (DBJSON) await ctx.addInitScript(db => { if (!sessionStorage.getItem('mp.seeded')) { localStorage.setItem('molaplan.mock.db', db); localStorage.setItem('molaplan.lang', 'fi'); sessionStorage.setItem('mp.seeded', '1'); } }, DBJSON);
    const p = await ctx.newPage();
    p.on('pageerror', e => errors.push('pageerror: ' + e.message));
    p.on('console', mm => { if (mm.type() === 'error' && !/tile\.openstreetmap|Failed to load resource|photon|nominatim/.test(mm.text())) errors.push('console: ' + mm.text()); });
    return { ctx, p };
  };
  const shot = async (p, name, full) => { if (!SHOTS) return; await p.waitForTimeout(600); await p.screenshot({ path: path.join(__dirname, 'shots', name + '.png'), fullPage: !!full }); };
  const waitToast = (p, re) => p.waitForFunction(r => new RegExp(r).test((document.querySelector('#toast') || {}).textContent || ''), re.source, { timeout: 6000 });
  // seed: one community, one public, one 18+ event
  let { ctx, p } = await mkPage({ hasTouch: true, isMobile: true });
  await p.goto(BASE + '?mock=1');
  const seeded = await p.evaluate(async () => {
    const S = window.__mockSupa; S.reset(); localStorage.clear(); localStorage.setItem('molaplan.lang', 'fi');
    S.createUser('aino@example.com', 'Aino', { admin: true }); S.createUser('hanna@example.com', 'Hanna', {});
    const H = S.as('hanna@example.com'), A = S.as('aino@example.com');
    const d = (n, hh) => { const x = new Date(Date.now() + n * 864e5); x.setHours(hh, 0, 0, 0); return x.toISOString(); };
    const c = (await H.from('events').insert({ activity_id: 'lautapelit', title: 'Lautapeli-ilta Kalliossa', description: 'Tuo oma peli tai pelaa meidän.', starts_at: d(2, 19), city: 'Helsinki', district: 'Kallio', place: 'Kallion kirjasto', lat: 60.1838, lng: 24.9531, max_participants: 8 }).select().single()).data;
    const pub = (await A.from('events').insert({ kind: 'public', organizer_name: 'Helsingin kaupunki', activity_id: 'juoksutapahtuma', title: 'Kaupunkijuoksu', starts_at: d(4, 10), ends_at: d(4, 14), city: 'Helsinki', district: 'Kaisaniemi', place: 'Kaisaniemen puisto', lat: 60.1752, lng: 24.9446, max_participants: null }).select().single()).data;
    const adult = (await H.from('events').insert({ activity_id: 'kahvi', title: 'Aikuisten saunailta', starts_at: d(3, 20), city: 'Helsinki', district: 'Kallio', place: 'Kotiharjun sauna', lat: 60.1826, lng: 24.9617, max_participants: 6, is_adult: true }).select().single()).data;
    localStorage.removeItem('molaplan.mock.session'); localStorage.removeItem('molaplan.guest');
    return { c: c.id, pub: pub.id, adult: adult.id };
  });
  ok(seeded.c && seeded.pub && seeded.adult, 'mock seeded: community, public and 18+ events');
  DBJSON = await p.evaluate(() => localStorage.getItem('molaplan.mock.db'));
  // --- guest opens a shared link on mobile (no saved area, no account)
  const cPath = '/e/' + seeded.c + '-lautapeli-ilta-kalliossa';
  await p.goto(ROOT + cPath + '?mock=1');
  await p.waitForSelector('#s-detail.active h1', { timeout: 15000 });
  ok((await p.textContent('#s-detail h1')) === 'Lautapeli-ilta Kalliossa' && !(await p.$('#landing')), 'guest: /e/<id> opens the event directly (landing skipped)');
  ok(await p.evaluate(() => location.pathname + location.search) === cPath + '?mock=1', 'URL stays /e/<id>-<slug>');
  ok(await p.evaluate(() => window.__molaplan.state.guest === true && !localStorage.getItem('molaplan.guest')), 'still a guest, no area saved behind the user’s back');
  await shot(p, 'share-m-guest-event');
  await p.click('#s-detail [data-a="back"]'); await p.waitForSelector('#s-home.active');
  ok(await p.evaluate(() => location.pathname) === '/' && !(await p.$('.push.active')), 'back → feed, URL back to /');
  ok((await p.textContent('#s-home')).includes('Lautapeli-ilta Kalliossa'), 'feed of the event’s city is shown');
  // open from the feed → URL changes; browser back closes
  await p.click(`#s-home .card[data-id="${seeded.c}"] h3`); await p.waitForSelector('#s-detail.active');
  ok(await p.evaluate(() => location.pathname) === cPath, 'opening an event from the feed sets /e/<id>-<slug>');
  await p.goBack(); await p.waitForFunction(() => !document.querySelector('#s-detail.active'));
  ok(await p.evaluate(() => location.pathname) === '/' && await p.isVisible('#s-home.active'), 'browser/Android back closes the event and returns to the feed');
  await p.goForward(); await p.waitForSelector('#s-detail.active');
  ok((await p.textContent('#s-detail h1')) === 'Lautapeli-ilta Kalliossa', 'forward re-opens it');
  await p.click('#s-detail [data-a="back"]'); await p.waitForSelector('#s-home.active');
  // share sheet (mobile: touch → Messenger app link)
  await p.click(`#s-home .card[data-id="${seeded.pub}"] h3`); await p.waitForSelector('#s-detail.active #d-share');
  await p.click('#d-share'); await p.waitForSelector('#app.sheet-open #share-grid');
  const pubUrl = ROOT + '/e/' + seeded.pub + '-kaupunkijuoksu';
  const hrefs = await p.evaluate(() => Object.fromEntries([...document.querySelectorAll('#share-grid a')].map(a => [a.id, a.getAttribute('href')])));
  const enc = encodeURIComponent(pubUrl);
  ok(hrefs['sh-wa'].startsWith('https://wa.me/?text=') && hrefs['sh-wa'].includes(enc) && hrefs['sh-fb'] === 'https://www.facebook.com/sharer/sharer.php?u=' + enc && hrefs['sh-tg'].startsWith('https://t.me/share/url?url=' + enc) && hrefs['sh-ms'] === 'fb-messenger://share/?link=' + enc && hrefs['sh-em'].startsWith('mailto:?subject=') && decodeURIComponent(hrefs['sh-em']).includes(pubUrl), 'share fallbacks: WhatsApp, Facebook, Messenger (app link on touch), Telegram, e-mail – all with the /e/ URL');
  ok((await p.inputValue('#share-url')) === pubUrl && (await p.textContent('#sheet')).includes('Jaa tapahtuma'), 'link field shows the shareable URL');
  ok(decodeURIComponent(hrefs['sh-wa']).includes('Kaupunkijuoksu – ') && decodeURIComponent(hrefs['sh-wa']).includes('Lähdetkö mukaan?'), 'share text: title, time, place + warm invite');
  await shot(p, 'share-m-sheet');
  await p.click('#sheet [data-a="sheet-close"]'); await ctx.close();
  // desktop: Web Share API used when available, copy link, Messenger web fallback
  ({ ctx, p } = await mkPage({ viewport: { width: 1280, height: 860 }, deviceScaleFactor: 1 }));
  await ctx.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: ROOT });
  await ctx.addInitScript(() => { window.__shared = []; navigator.share = d => { window.__shared.push(d); return Promise.resolve(); }; });
  await p.goto(ROOT + '/e/' + seeded.pub + '?mock=1'); await p.waitForSelector('#s-detail.active #d-share', { timeout: 15000 });
  ok(await p.evaluate(() => location.pathname.endsWith('-kaupunkijuoksu') || location.pathname.endsWith(location.pathname)), 'desktop deep link without slug works');
  await p.click('#d-share'); await p.waitForSelector('#sh-native');
  await p.click('#sh-native'); await p.waitForFunction(() => window.__shared.length === 1);
  const sd = await p.evaluate(() => window.__shared[0]);
  ok(sd.url === pubUrl && sd.title === 'Kaupunkijuoksu' && /Kaupunkijuoksu/.test(sd.text), 'Web Share API gets title, text and the /e/ URL');
  await p.click('#d-share'); await p.waitForSelector('#sh-copy');
  ok(await p.$('#sh-ms[data-a="share-ms"]') && !(await p.$('a#sh-ms')), 'desktop Messenger = copy link + open messenger.com (no app link)');
  await p.click('#sh-copy'); await waitToast(p, /Linkki kopioitu/);
  ok(await p.evaluate(() => navigator.clipboard.readText()) === pubUrl, 'copy link puts the URL on the clipboard');
  await shot(p, 'share-d1280-sheet');
  await ctx.close();
  // not visible to guests: 18+ and unknown → toast + feed/landing, URL reset
  ({ ctx, p } = await mkPage());
  await p.goto(ROOT + '/e/' + seeded.adult + '?mock=1');
  await waitToast(p, /Tapahtumaa ei löytynyt/);
  ok(!(await p.$('#s-detail.active')) && await p.evaluate(() => location.pathname) === '/', '18+ event via /e/ as a guest: not shown, toast, URL reset');
  await p.goto(ROOT + '/e/00000000-0000-4000-8000-000000000000-nope?mock=1'); await waitToast(p, /Tapahtumaa ei löytynyt/);
  ok(!(await p.$('#s-detail.active')) && await p.isVisible('#landing'), 'unknown id: toast + normal landing');
  // signed-in user opens a shared 18+ link → visible (RLS for members), back → feed
  await p.evaluate(() => { localStorage.setItem('molaplan.mock.session', window.__mockSupa.userId('aino@example.com')); });
  await p.goto(ROOT + '/e/' + seeded.adult + '?mock=1'); await p.waitForSelector('#s-detail.active h1', { timeout: 15000 });
  ok((await p.textContent('#s-detail h1')) === 'Aikuisten saunailta', 'signed-in member opens the same link (members may see 18+)');
  await p.click('#s-detail [data-a="back"]'); await p.waitForSelector('#s-home.active');
  ok(await p.evaluate(() => location.pathname) === '/', 'member: back → feed');
  // headline + name card
  ok((await p.textContent('#home-h1')).trim() === 'Mola el plan!' && (await p.textContent('#home-sub')).trim() === 'Hyvä suunnitelma on parempi yhdessä. Katso, mitä lähelläsi tapahtuu.', 'home headline "Mola el plan!" + Finnish subtitle');
  ok((await p.textContent('#home-name')).includes('Mistä nimi Molaplan tulee?') && (await p.textContent('#home-name')).includes('”mola el plan”'), 'name card on home');
  await ctx.close();
  for (const [lang, sub, nameT] of [['en', "A good plan is better together. See what's happening near you.", 'Where does the name Molaplan come from?'], ['es', 'Un buen plan es mejor en compañía. Mira lo que pasa cerca de ti.', '¿De dónde viene el nombre Molaplan?'], ['sv', 'En bra plan blir bättre tillsammans. Se vad som händer nära dig.', 'Var kommer namnet Molaplan ifrån?']]) {
    ({ ctx, p } = await mkPage());
    await p.goto(BASE + '?mock=1'); await p.evaluate(l => { localStorage.setItem('molaplan.lang', l); localStorage.setItem('molaplan.guest', JSON.stringify({ city: 'Helsinki', district: 'Kallio' })); }, lang); await p.reload();
    await p.waitForSelector('#s-home.active #home-h1');
    ok((await p.textContent('#home-h1')).trim() === 'Mola el plan!' && (await p.textContent('#home-sub')).trim() === sub && (await p.textContent('#home-name')).includes(nameT), lang + ': "Mola el plan!" stays Spanish, subtitle + name card translated');
    if (lang === 'en') { await p.evaluate(() => localStorage.removeItem('molaplan.guest')); await p.reload(); await p.waitForSelector('#landing'); ok(await p.isVisible('#land-name'), 'en: name card on the landing too'); }
    await ctx.close();
  }
  ({ ctx, p } = await mkPage());
  await p.goto(BASE + '?mock=1'); await p.evaluate(() => { localStorage.setItem('molaplan.lang', 'fi'); localStorage.setItem('molaplan.guest', JSON.stringify({ city: 'Helsinki', district: 'Kallio' })); }); await p.reload();
  await p.waitForSelector('#s-home.active #home-h1'); await shot(p, 'home-mola-el-plan');
  await p.$eval('#home-name', e => e.scrollIntoView({ block: 'center' })); await shot(p, 'home-name-card');
  await ctx.close();

  // --- Photon autocomplete (mocked) + rate-limited reverse lookup
  const FIX = {
    'kallion kir': [{ geometry: { coordinates: [24.953627, 60.1836068] }, properties: { name: 'Kallion kirjasto', street: 'Viides linja', housenumber: '11', district: 'Kallio', city: 'Helsinki', countrycode: 'FI' } },
      { geometry: { coordinates: [24.9497, 60.1841] }, properties: { name: 'Kallion kirkko', street: 'Itäinen Papinkatu', housenumber: '2', district: 'Kallio', city: 'Helsinki' } },
      { geometry: { coordinates: [24.95, 60.183] }, properties: { street: 'Kallion puistotie', city: 'Helsinki' } }],
    'mannerheiminti': [{ geometry: { coordinates: [24.9384, 60.1699] }, properties: { street: 'Mannerheimintie', housenumber: '1', city: 'Helsinki' } }]
  };
  ({ ctx, p } = await mkPage({ hasTouch: true, isMobile: true }));
  const photon = [], reverse = [];
  let photonMode = 'ok';
  await ctx.route('https://photon.komoot.io/**', async route => {
    const u = new URL(route.request().url()); photon.push(u);
    if (photonMode === 'fail') return route.fulfill({ status: 502, body: 'bad gateway' });
    const q = (u.searchParams.get('q') || '').toLowerCase();
    const key = Object.keys(FIX).find(k => q.startsWith(k));
    return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ type: 'FeatureCollection', features: key ? FIX[key] : [] }) });
  });
  await ctx.route('https://nominatim.openstreetmap.org/**', route => { reverse.push(Date.now()); return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ address: { road: 'Testikatu', house_number: '5', city: 'Helsinki' } }) }); });
  await p.goto(BASE + '?mock=1'); await p.evaluate(() => { localStorage.setItem('molaplan.mock.session', window.__mockSupa.userId('hanna@example.com')); localStorage.setItem('molaplan.lang', 'fi'); }); await p.reload();
  await p.waitForSelector('#s-home.active'); await p.click('#nav [data-t="create"]'); await p.waitForSelector('#s-create.active #c-place');
  await p.waitForFunction(() => window.__molaplan.pickView);
  await p.waitForTimeout(1200);
  const rev0 = reverse.length;
  ok(rev0 <= 1, 'opening the form does at most one reverse lookup (' + rev0 + ')');
  ok(await p.getAttribute('#c-place', 'role') === 'combobox' && await p.getAttribute('#c-place', 'aria-expanded') === 'false' && await p.getAttribute('#c-place', 'autocomplete') === 'off', 'place field is an ARIA combobox (browser autofill off)');
  ok((await p.inputValue('#c-place')) === 'Testikatu 5', 'reverse lookup prefills the untouched place field ("Testikatu 5")');
  await p.fill('#c-place', ''); await p.waitForTimeout(350); photon.length = 0;
  await p.click('#c-place'); await p.keyboard.type('Ka', { delay: 40 }); await p.waitForTimeout(500);
  ok(photon.length === 0 && await p.isHidden('#c-place-list'), 'fewer than 3 characters: no request');
  await p.keyboard.type('llion kir', { delay: 40 }); await p.waitForSelector('#c-place-list .ac-opt');
  ok(photon.length === 1, 'typing quickly = one request after the 300 ms pause (' + photon.length + ')');
  const pq = photon[0];
  const view = await p.evaluate(() => window.__molaplan.pickView);
  ok(pq.searchParams.get('q') === 'Kallion kir' && Math.abs(+pq.searchParams.get('lat') - view.lat) < 0.01 && Math.abs(+pq.searchParams.get('lon') - view.lng) < 0.01 && !pq.searchParams.get('lang'), 'Photon request biased to the map centre; fi → local OSM names (no lang param)');
  const opts = await p.$$eval('#c-place-list .ac-opt', ls => ls.map(l => l.textContent));
  ok(opts.length === 3 && opts[0].includes('Kallion kirjasto') && opts[0].includes('Viides linja 11, Kallio, Helsinki') && opts[2].includes('Kallion puistotie'), 'suggestions show name + street + city (' + opts.join(' | ') + ')');
  ok((await p.textContent('#c-place-list .ac-attr')).includes('Photon') && (await p.textContent('#c-place-list .ac-attr')).includes('OpenStreetMap') && await p.getAttribute('#c-place', 'aria-expanded') === 'true', 'attribution "Photon · © OpenStreetMap", aria-expanded');
  await shot(p, 'create-place-autocomplete');
  await p.keyboard.press('ArrowDown'); await p.keyboard.press('ArrowDown'); await p.keyboard.press('ArrowUp');
  ok(await p.getAttribute('#c-place', 'aria-activedescendant') === 'c-place-opt-0' && await p.$('#c-place-opt-0.on'), 'arrow keys move the highlighted option');
  await p.keyboard.press('Enter'); await p.waitForTimeout(400);
  let st = await p.evaluate(() => ({ v: document.querySelector('#c-place').value, c: { lat: window.__molaplan.create.lat, lng: window.__molaplan.create.lng, place: window.__molaplan.create.place }, view: window.__molaplan.pickView }));
  ok(st.v === 'Kallion kirjasto, Viides linja 11' && st.c.place === st.v && Math.abs(st.c.lat - 60.18361) < 1e-4 && Math.abs(st.c.lng - 24.95363) < 1e-4, 'Enter picks: field filled, coordinates stored');
  ok(st.view.zoom === 17 && Math.abs(st.view.marker.lat - 60.18361) < 1e-4 && Math.abs(st.view.lat - 60.18361) < 1e-3, 'map pin moved there and zoomed in (17)');
  ok(await p.isHidden('#c-place-list'), 'list closes after picking');
  await p.waitForTimeout(1600);
  ok((await p.inputValue('#c-place')) === 'Kallion kirjasto, Viides linja 11', 'the reverse lookup after the pin move does not overwrite the picked place');
  // tap (mobile)
  await p.fill('#c-place', ''); await p.type('#c-place', 'Mannerheiminti', { delay: 20 }); await p.waitForSelector('#c-place-opt-0');
  await p.tap('#c-place-opt-0'); await p.waitForTimeout(300);
  ok((await p.inputValue('#c-place')) === 'Mannerheimintie 1' && Math.abs((await p.evaluate(() => window.__molaplan.create.lng)) - 24.9384) < 1e-4, 'tap on a suggestion works (mobile)');
  // Escape
  await p.fill('#c-place', ''); await p.type('#c-place', 'Kallion kirk', { delay: 20 }); await p.waitForSelector('#c-place-opt-0');
  await p.keyboard.press('Escape');
  ok(await p.isHidden('#c-place-list') && await p.isVisible('#s-create.active'), 'Esc closes the list (the create screen stays)');
  // no results
  await p.fill('#c-place', ''); await p.type('#c-place', 'Zzxqy paikka', { delay: 20 }); await p.waitForSelector('#c-place-msg');
  ok((await p.textContent('#c-place-msg')).includes('Ei osumia'), 'no results message');
  // service error
  photonMode = 'fail'; await p.fill('#c-place', ''); await p.type('#c-place', 'Kalasatama', { delay: 20 }); await p.waitForFunction(() => /ei juuri nyt toimi/.test((document.querySelector('#c-place-msg') || {}).textContent || ''));
  ok(true, 'Photon error → "Paikkahaku ei juuri nyt toimi – kirjoita paikka itse"');
  photonMode = 'ok';
  // offline
  await ctx.setOffline(true); const nOff = photon.length;
  await p.fill('#c-place', ''); await p.type('#c-place', 'Hakaniemi', { delay: 20 }); await p.waitForSelector('#c-place-msg'); await p.waitForTimeout(400);
  ok((await p.textContent('#c-place-msg')).includes('Ei verkkoyhteyttä') && photon.length === nOff, 'offline: friendly message, no request');
  await ctx.setOffline(false);
  // typed text is still accepted as the place
  ok((await p.inputValue('#c-place')) === 'Hakaniemi', 'free text stays in the field');
  // rate-limited reverse lookup: quick map taps → requests at least 1.5 s apart
  await p.tap('#c-place-msg'); await p.waitForTimeout(100);
  ok(await p.isHidden('#c-place-list'), 'tapping the status message closes it');
  const r0 = reverse.length;
  const box = await p.$eval('#pick-map', e => { const r = e.getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width, h: r.height }; });
  await p.$eval('#pick-map', e => e.scrollIntoView({ block: 'center' }));
  const box2 = await p.$eval('#pick-map', e => { const r = e.getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width, h: r.height }; });
  for (let i = 0; i < 6; i++) { await p.touchscreen.tap(box2.x + 40 + i * 25, box2.y + 60 + i * 10); await p.waitForTimeout(150); }
  await p.waitForTimeout(2500);
  const revT = reverse.slice(r0), nRev = revT.length, gaps = revT.slice(1).map((t, i) => t - revT[i]);
  ok(nRev >= 1 && nRev < 6 && gaps.every(g => g >= 1400), 'reverse lookup rate-limited: 6 quick pin moves → ' + nRev + ' request(s), gaps ' + gaps.join('/') + ' ms (≥1.5 s apart)');
  const afterTap = await p.evaluate(() => ({ lat: window.__molaplan.create.lat, lng: window.__molaplan.create.lng, v: window.__molaplan.pickView }));
  ok(Math.abs(afterTap.lng - 24.9384) > 1e-4 || Math.abs(afterTap.lat - 60.1699) > 1e-4, 'tapping the map still moves the pin ' + JSON.stringify(afterTap) + ' ' + JSON.stringify(box2));
  // en → lang=en
  await p.goto(BASE + '?mock=1&lang=en'); await p.waitForSelector('#s-home.active');
  await p.click('#nav [data-t="create"]'); await p.waitForSelector('#s-create.active #c-place');
  await p.type('#c-place', 'Kallion kir', { delay: 20 }); await p.waitForSelector('#c-place-opt-0');
  ok(photon[photon.length - 1].searchParams.get('lang') === 'en', 'en UI → Photon lang=en');
  // participant field screenshot
  await p.goto(BASE + '?mock=1&lang=fi'); await p.waitForSelector('#s-home.active');
  await p.click('#nav [data-t="create"]'); await p.waitForSelector('#s-create.active #c-max-field');
  await p.fill('#c-maxn', '12'); await p.$eval('#c-max-field', e => e.scrollIntoView({ block: 'center' })); await shot(p, 'create-max-field');
  await p.click('#c-nolimit-btn'); await shot(p, 'create-max-field-nolimit');
  await ctx.close();

  ok(!errors.length, 'no page/console errors' + (errors.length ? ': ' + errors.join(' | ') : ''));
  await browser.close();
  console.log(`\nALL PASSED: ${passed} checks`);
})().catch(e => { console.error('✘', e.message, `\n(${passed} checks passed before failure)`); process.exit(1); });
