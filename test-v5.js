/* Molaplan v5 UI tests (mock): rebalanced home, admin public events, business accounts, anti-advertising guard, reports + ban.
   Start a static server first:  python3 -m http.server 8765 --bind 127.0.0.1     Then:  node test-v5.js */
const { chromium } = require('playwright-core');
const BASE = process.env.URL || 'http://127.0.0.1:8765/index.html';
let passed = 0;
(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROME || '/usr/bin/google-chrome', args: ['--no-sandbox', '--lang=fi-FI'] });
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true, locale: 'fi-FI', timezoneId: 'Europe/Helsinki' });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  page.on('console', m => { if (m.type() === 'error' && !/tile\.openstreetmap|Failed to load resource/.test(m.text())) errors.push('console: ' + m.text()); });
  page.on('dialog', d => d.accept());
  const ok = (c, m) => { if (!c) throw new Error('ASSERT: ' + m); passed++; console.log('✔', m); };
  const M = (fn, ...a) => page.evaluate(fn, ...a);
  const DB = () => M(() => window.__mockSupa.db());
  const waitToast = async (re) => { await page.waitForFunction(r => new RegExp(r).test((document.querySelector('#toast') || {}).textContent || ''), re.source, { timeout: 6000 }); };
  const tab = t => page.click(`#nav [data-t="${t}"]`);
  const profile = async () => { await page.click('#s-home .hdr-actions [data-t="profile"]'); await page.waitForSelector('#s-profile.active'); };
  const ymd = n => { const d = new Date(Date.now() + n * 864e5); return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); };
  const loginAs = async (email) => { await M(e => { localStorage.setItem('molaplan.mock.session', window.__mockSupa.userId(e)); localStorage.setItem('molaplan.lang', 'fi'); }, email); await page.goto('about:blank'); await page.goto(BASE + '?mock=1'); try { await page.waitForSelector('#s-home.active .home-top #loc-pill', { timeout: 10000 }); } catch (e) { await page.screenshot({ path: '/tmp/login-fail.png' }); throw new Error('login as ' + email + ' failed: ' + await page.evaluate(() => [...document.querySelectorAll('.screen.active')].map(s => s.id).join())); } };
  const iso = (n, h) => { const d = new Date(Date.now() + n * 864e5); d.setHours(h, 0, 0, 0); return d.toISOString(); };

  // ---------- setup ----------
  await page.goto(BASE + '?mock=1');
  await M(() => { window.__mockSupa.reset(); localStorage.clear(); sessionStorage.clear(); localStorage.setItem('molaplan.lang', 'fi');
    const S = window.__mockSupa;
    S.createUser('aino@example.com', 'Aino', { admin: true, phone: '+358401111111' });
    S.createUser('liisa@example.com', 'Liisa', { phone: '+358402222222' });
    S.createUser('pekka@example.com', 'Pekka', { phone: '+358403333333' });
  });
  await page.reload();

  // ---------- 1. rebalanced landing ----------
  await page.waitForSelector('#landing');
  const hero = await page.textContent('.onb-hero');
  ok(/auttakaa toisianne/.test(hero) && !hero.includes('🤪') && !/hulluun/.test(hero), 'landing tagline = hobbies + helping each other; no 🤪 in the hero');
  ok(await page.isVisible('#land-pillars') && await page.isVisible('#land-help #land-offer') && await page.isVisible('#land-help #land-ask'), 'landing shows "Autetaan toisiamme" card with Tarjoa apua / Pyydä apua');
  await page.click('#land-biz summary');
  ok((await page.textContent('#land-biz')).includes('49 € / kk + ALV') && (await page.textContent('#land-biz')).includes('Laskutetaan kuukausittain'), 'landing "Yrityksille" shows the business offer (49 € / kk + ALV)');
  ok((await M(() => document.querySelector('meta[name=description]').content)).includes('auta naapuria'), 'meta description rebalanced');
  await page.click('#land-offer'); await page.waitForSelector('#s-good.active');
  ok(true, '"Tarjoa apua" on the landing opens Hyvät teot (guest)');

  // ---------- 2. home order (logged in) ----------
  await loginAs('liisa@example.com');
  const chips = await page.$$eval('#act-filter-popup-home .act-filter-item', x => x.map(e => e.dataset.v));
  const acts = await M(() => window.__molaplan.state.acts.map(a => ({ id: a.id, crazy: a.crazy })));
  const iCz = chips.indexOf('__hullut'), crazyIds = acts.filter(a => a.crazy).map(a => a.id), normIds = acts.filter(a => !a.crazy).map(a => a.id);
  ok(chips.slice(0, 3).join() === 'all,__hyvat,__yritykset' && normIds.every(id => chips.indexOf(id) > 2 && chips.indexOf(id) < iCz) && crazyIds.every(id => chips.indexOf(id) > iCz), 'activity menu: Kaikki, 💚 Hyvät teot, 🏢 Yritykset, normal activities, then 🤪 Hullut + crazy activities');
  ok(await M(() => { const h = document.querySelector('#help-card'), f = document.querySelector('#s-home .filters'); return !!h && !!(h.compareDocumentPosition(f) & Node.DOCUMENT_POSITION_FOLLOWING); }), 'warm "Autetaan toisiamme 💚" card sits above the filters');
  ok(await M(() => { const c = document.querySelector('#cz-banner'), cards = [...document.querySelectorAll('#s-home .cards')].pop(); return c.classList.contains('soft') && !!(cards.compareDocumentPosition(c) & Node.DOCUMENT_POSITION_FOLLOWING); }), 'crazy banner moved to the end and toned down');
  await page.click('#hc-ask'); await page.waitForSelector('#s-ask.active');
  ok(true, '"Pyydä apua" opens the help request form'); await page.click('#s-ask [data-a="back"]');

  // ---------- 3. anti-advertising guard (client + server) ----------
  await tab('create'); await page.waitForSelector('#s-create.active #c-title');
  ok((await page.textContent('#c-rule')).includes('yrityksille on oma Yritystili') && await page.isVisible('#ck-rule'), 'create form: rule text + required checkbox');
  await page.click('#s-create [data-a="c-act"][data-v="juoksu"]');
  await page.fill('#c-title', 'Lenkki Töölönlahdella'); await page.fill('#c-date', ymd(1)); await page.fill('#c-time', '18:30'); await page.fill('#c-place', 'Finlandia-talo');
  await page.fill('#c-desc', 'Liput www.juoksukauppa.fi, hinta 10 € – soita 040 123 4567');
  ok(await page.isVisible('#c-adwarn'), 'live check: link / price / phone in the description shows a warning instantly');
  await page.click('#ck-rule'); await page.click('#c-publish'); await waitToast(/Yritystili/);
  ok(!(await DB()).events.some(e => e.title === 'Lenkki Töölönlahdella'), 'publish blocked while the text looks like advertising');
  await page.fill('#c-desc', 'Rauhallinen 8 km, omakustanteinen – jaetaan kulut saunasta. Klo 18.30-20.');
  ok(!(await page.isVisible('#c-adwarn')), 'cost-sharing wording ("omakustanteinen", "jaetaan kulut") and times are allowed');
  await page.click('#c-publish'); await page.waitForSelector('#s-detail.active');
  const lenkki = (await DB()).events.find(e => e.title === 'Lenkki Töölönlahdella');
  ok(lenkki && lenkki.kind === 'community' && lenkki.host_id, 'community event published');
  const srv = await M(async () => { const L = window.__mockSupa.as('liisa@example.com'), s = new Date(Date.now() + 2 * 864e5).toISOString(); const base = { activity_id: 'juoksu', starts_at: s, city: 'Helsinki', place: 'Kallio', max_participants: 5 };
    const r = []; for (const x of [{ title: 'Varaa paikka nyt' }, { title: 'Lenkki', description: 'info@firma.fi' }, { title: 'Lenkki', description: '-20 % kaikesta' }, { title: 'Lenkki', price_info: '5 e' }]) { const q = await L.from('events').insert(Object.assign({}, base, x)); r.push(q.error ? q.error.message : 'OK'); } return r; });
  ok(srv[0] === 'commercial_content' && srv[1] === 'commercial_content' && srv[2] === 'commercial_content' && /events_kind_fields/.test(srv[3]), 'server guard rejects sales words, e-mails, discounts; private events cannot have a price (' + srv.join(' | ') + ')');

  // ---------- 4. admin-only public event ----------
  const nonAdmin = await M(async () => { const r = await window.__mockSupa.as('liisa@example.com').from('events').insert({ kind: 'public', organizer_name: 'Kaupunki', activity_id: 'festivaali', title: 'Feikki festari', starts_at: new Date(Date.now() + 864e5).toISOString(), city: 'Helsinki', place: 'Tori', max_participants: 100 }); return r.error && r.error.message; });
  ok(nonAdmin === 'public_event_admin_only', 'non-admin cannot create a public event');
  await loginAs('aino@example.com');
  await profile(); await page.click('#p-new-public'); await page.waitForSelector('#s-create.active #c-org');
  ok(await page.isVisible('#c-mode-public.on') && await page.isVisible('#c-edate') && await page.isVisible('#c-url') && await page.isVisible('#c-price') && !(await page.$('#ck-rule')), 'admin create mode "Julkinen tapahtuma": end time, organiser, link, price; no private-event checkbox');
  await page.click('#s-create [data-a="c-act"][data-v="juoksutapahtuma"]');
  await page.fill('#c-title', 'Helsinki City Run'); await page.fill('#c-date', ymd(2)); await page.fill('#c-time', '10:00'); await page.fill('#c-edate', ymd(2)); await page.fill('#c-etime', '15:00');
  await page.fill('#c-place', 'Olympiastadion'); await page.fill('#c-org', 'Helsinki City Run ry'); await page.fill('#c-url', 'https://helsinkicityrun.fi'); await page.fill('#c-price', 'Alk. 45 €'); await page.fill('#c-maxn', '5000');
  await page.fill('#c-desc', 'Puolimaraton ja 10 km. Ilmoittautuminen virallisella sivulla.');
  await page.click('#c-publish'); await page.waitForSelector('#s-detail.active #kind-strip');
  const pub = (await DB()).events.find(e => e.title === 'Helsinki City Run');
  ok(pub && pub.kind === 'public' && pub.host_id === null && pub.ends_at && pub.max_participants === 5000, 'public event stored: kind=public, host_id null, end time, 5000 places');
  ok((await page.textContent('#kind-strip')).includes('Julkinen tapahtuma') && (await page.getAttribute('#d-official', 'href')) === 'https://helsinkicityrun.fi' && (await page.textContent('#d-org')).includes('Helsinki City Run ry') && (await page.textContent('#d-price')).includes('45 €'), 'detail: "Julkinen tapahtuma" badge, organiser, price, "Virallinen sivu" link');
  ok(!(await page.textContent('#s-detail')).includes('Järjestää'), 'no private host shown for public events');
  ok(!(await DB()).event_participants.some(p => p.event_id === pub.id), 'admin is not added as a participant');
  await page.click('#d-edit'); await page.waitForSelector('#s-create.active #c-org');
  await page.fill('#c-title', 'Helsinki City Run 2026'); await page.click('#c-publish'); await page.waitForSelector('#s-detail.active');
  ok((await DB()).events.find(e => e.id === pub.id).title === 'Helsinki City Run 2026', 'admin can edit the public event');
  // guest sees it
  await M(() => { localStorage.removeItem('molaplan.mock.session'); localStorage.setItem('molaplan.guest', JSON.stringify({ city: 'Helsinki', district: 'Kallio' })); });
  await page.goto('about:blank'); await page.goto(BASE + '?mock=1'); await page.waitForSelector('#s-home.active .card');
  const gcard = await page.$eval(`#s-home .card[data-id="${pub.id}"]`, e => e.textContent);
  ok(await M(() => !window.__molaplan.state.user || window.__molaplan.state.guest) && gcard.includes('Julkinen tapahtuma') && gcard.includes('Kiinnostaa') && gcard.includes('Helsinki City Run ry'), 'guest sees the public event card with badge, organiser and "Kiinnostaa"');
  // Liisa joins -> "Etsi seuraa"
  await loginAs('liisa@example.com');
  await page.click(`#s-home .card[data-id="${pub.id}"] [data-a="join"]`); await page.waitForTimeout(400);
  await page.click(`#s-home .card[data-id="${pub.id}"]`); await page.waitForSelector('#s-detail.active');
  ok((await page.textContent('#chat-box')).includes('Etsi seuraa'), '"Kiinnostaa" joins; the chat is called "Etsi seuraa"');
  await page.click('#s-detail [data-a="back"]');

  // ---------- 5. business account ----------
  await loginAs('pekka@example.com');
  await profile(); await page.click('#open-biz'); await page.waitForSelector('#s-biz.active #biz-form');
  ok((await page.textContent('#biz-offer')).includes('49 € / kk + ALV') && (await page.textContent('#biz-offer')).includes('Rajattomasti tapahtumia'), 'business screen shows the price and terms');
  await page.fill('#bz-name', 'Pekan Pyörä Oy'); await page.fill('#bz-code', '1234567-2'); await page.fill('#bz-web', 'https://pekanpyora.fi');
  await page.fill('#bz-bill', 'Pyöräkatu 1, 00100 Helsinki'); await page.click('#ck-bizterms'); await page.click('#bz-submit'); await waitToast(/Y-tunnus/);
  ok(!(await DB()).businesses.length, 'invalid Y-tunnus rejected client-side');
  await page.fill('#bz-code', '737546-2'); await page.click('#bz-submit'); await waitToast(/Hakemus lähetetty/);
  let biz = (await DB()).businesses[0];
  ok(biz && biz.status === 'pending' && biz.business_code === '0737546-2' && (await DB()).business_private[0].billing_address.includes('Pyöräkatu'), 'application stored as pending (6-digit code padded to 0737546-2), billing kept in business_private');
  ok((await DB()).notifications.some(n => n.code === 'admin_new_business'), 'admin notified about the application');
  await page.click('#s-biz [data-a="back"]'); await page.waitForTimeout(300);
  ok((await page.textContent('#p-biz')).includes('Pekan Pyörä Oy') && (await page.textContent('#p-biz')).includes('Odottaa'), 'profile business card shows the pending application');
  await tab('create'); await page.waitForSelector('#s-create.active #c-title');
  ok(!(await page.$('#c-mode-business')), 'no business event mode before approval + active subscription');
  const early = await M(async id => { const r = await window.__mockSupa.as('pekka@example.com').from('events').insert({ kind: 'business', business_id: id, activity_id: 'pyoraily', title: 'Huoltoilta', starts_at: new Date(Date.now() + 864e5).toISOString(), city: 'Helsinki', place: 'Liike', max_participants: 20 }); return r.error && r.error.message; }, biz.id);
  ok(early === 'business_subscription_required', 'pending business cannot publish (server)');
  // admin approves + extends
  await loginAs('aino@example.com');
  await profile(); await page.click('#open-admin'); await page.waitForSelector('#s-admin.active'); await page.click('#adm-sec-biz'); await page.waitForSelector(`#adm-biz-${biz.id}`);
  const card = await page.textContent(`#adm-biz-${biz.id}`);
  ok(card.includes('0737546-2') && card.includes('Pyöräkatu 1') && card.includes('pekka@example.com'), 'admin queue shows Y-tunnus, billing and contact details');
  await page.click(`#adm-biz-${biz.id} [data-a="adm-biz-approve"]`); await waitToast(/Hyväksytty/);
  await page.click(`#biz-ext-${biz.id}`); await waitToast(/voimassa/);
  biz = (await DB()).businesses[0];
  const exp = await M(() => { const d = new Date(); const t = new Date(d.getFullYear(), d.getMonth() + 1, Math.min(d.getDate(), new Date(d.getFullYear(), d.getMonth() + 2, 0).getDate())); return t.getFullYear() + '-' + String(t.getMonth() + 1).padStart(2, '0') + '-' + String(t.getDate()).padStart(2, '0'); });
  ok(biz.status === 'approved' && biz.subscription_active_until === exp, 'approve + "Jatka 1 kk" → active until ' + exp);
  const codes = (await DB()).notifications.filter(n => n.user_id === biz.created_by).map(n => n.code);
  ok(codes.includes('business_approved') && codes.includes('business_extended'), 'owner notified: approved + extended');
  // business creates event
  await loginAs('pekka@example.com');
  await profile(); await page.click(`#new-biz-ev-${biz.id}`); await page.waitForSelector('#s-create.active #c-mode-business.on');
  await page.click('#s-create [data-a="c-act"][data-v="pyoraily"]');
  await page.fill('#c-title', 'Pyörähuollon ilta – alennus 20 %'); await page.fill('#c-date', ymd(3)); await page.fill('#c-time', '17:00'); await page.fill('#c-place', 'Pekan Pyörä, Kallio'); await page.fill('#c-price', '10 €');
  await page.click('#c-publish'); await page.waitForSelector('#s-detail.active #kind-strip');
  const bev = (await DB()).events.find(e => e.kind === 'business');
  ok(bev && bev.business_id === biz.id && bev.host_id === null && bev.price_info === '10 €', 'active business publishes a business event (sales wording + price allowed, no host)');
  ok((await page.textContent('#d-org')).includes('Pekan Pyörä Oy') && !(await page.textContent('#s-detail')).includes('Pekka'), 'business event shows the business name, never the person');
  await page.click('#s-detail [data-a="back"]'); await tab('home');
  ok(await page.isVisible('#biz-sec') && (await page.textContent('#biz-sec')).includes('Yritysten tapahtumat'), 'home: separate "Yritysten tapahtumat" section');
  await page.click('#act-filter-btn-home'); await page.click('#act-filter-popup-home [data-v="__yritykset"]'); await page.waitForTimeout(200);
  const bt = await page.$$eval('#s-home .card h3', x => x.map(e => e.textContent));
  ok(bt.length === 1 && bt[0].startsWith('Pyörähuollon ilta') && (await page.textContent('#s-home .card .kind-badge')).includes('Yritys'), '"🏢 Yritykset" chip shows only business events with the "Yritys" badge');
  // expiry
  await M(id => window.__mockSupa.setBusiness(id, { subscription_active_until: '2020-01-01' }), biz.id);
  const late = await M(async id => { const r = await window.__mockSupa.as('pekka@example.com').from('events').insert({ kind: 'business', business_id: id, activity_id: 'pyoraily', title: 'Uusi ilta', starts_at: new Date(Date.now() + 864e5).toISOString(), city: 'Helsinki', place: 'Liike', max_participants: 20 }); return r.error && r.error.message; }, biz.id);
  ok(late === 'business_subscription_required' && (await DB()).events.some(e => e.id === bev.id), 'expired subscription blocks new business events; existing ones stay visible');
  const anon = await M(async () => { const c = window.MolaplanMock.createClient(); localStorage.removeItem('molaplan.mock.session'); const a = await c.from('businesses').select('id,business_code'); const b = await c.from('business_private').select('*'); return [!!a.error, !!b.error]; });
  ok(anon[0] && anon[1], 'anon cannot read business_code or business_private');
  await M(id => window.__mockSupa.setBusiness(id, { subscription_active_until: new Date(Date.now() + 3 * 864e5).toISOString().slice(0, 10), expiring_notified_for: null }), biz.id);
  await loginAs('aino@example.com'); await profile(); await page.click('#open-admin'); await page.click('#adm-sec-biz'); await page.waitForSelector(`#soon-${biz.id}`);
  await page.waitForFunction(() => window.__mockSupa.db().notifications.some(n => n.code === 'business_expiring'));
  ok(true, 'admin queue highlights "Päättyy pian"; opening it runs the expiry sweep (business_expiring notice sent)');
  await page.click(`#biz-end-${biz.id}`); await waitToast(/päätetty/);
  ok((await DB()).businesses[0].subscription_active_until < new Date().toISOString().slice(0, 10) && (await DB()).notifications.some(n => n.code === 'business_ended'), '"Päätä" ends the subscription (business_ended notice)');

  // ---------- 6. report → admin ban ----------
  await loginAs('pekka@example.com');
  await page.click(`#s-home .card[data-id="${lenkki.id}"]`); await page.waitForSelector('#s-detail.active #d-report');
  await page.click('#d-report'); await page.waitForSelector('#rep-sheet');
  ok((await page.textContent('#rep-reasons')).includes('Mainostaa yritystä'), 'report sheet offers "Mainostaa yritystä"');
  await page.fill('#rep-note', 'Mainostaa saunaa'); await page.click('#rep-send'); await waitToast(/Kiitos/);
  await page.waitForSelector('#d-reported');
  const rp = (await DB()).reports;
  ok(rp.length === 1 && rp[0].reason === 'business_ad' && rp[0].target_id === lenkki.id && (await DB()).notifications.some(n => n.code === 'admin_new_report'), 'report stored (business_ad) and admins notified');
  const dup = await M(async id => (await window.__mockSupa.as('pekka@example.com').from('reports').insert({ target_type: 'event', target_id: id, reason: 'spam' })).error.message, lenkki.id);
  ok(/reports_once_key/.test(dup), 'one report per user per event');
  await loginAs('aino@example.com'); await profile(); await page.click('#open-admin'); await page.click('#adm-sec-reports'); await page.waitForSelector(`#adm-rep-${lenkki.id}`);
  ok((await page.textContent(`#adm-rep-${lenkki.id}`)).includes('Mainostaa saunaa'), 'admin reports queue shows the report + note');
  await page.click(`#adm-rep-${lenkki.id} [data-a="adm-rep-ban"]`); await waitToast(/estetty/);
  const d6 = await DB();
  ok(d6.profiles.find(p => p.id === lenkki.host_id).banned === true && d6.reports[0].status === 'resolved' && d6.notifications.some(n => n.code === 'moderation_banned' && n.user_id === lenkki.host_id), 'ban: profiles.banned set, report resolved, user notified');
  await loginAs('liisa@example.com'); await tab('create');
  ok(await page.isVisible('#c-banned'), 'banned user sees a notice instead of the create form');
  const blocked = await M(async id => { const L = window.__mockSupa.as('liisa@example.com'); const c = window.__mockSupa.db().conversations.find(x => x.event_id === id).id;
    const e = await L.from('events').insert({ activity_id: 'juoksu', title: 'Lenkki', starts_at: new Date(Date.now() + 864e5).toISOString(), city: 'Helsinki', place: 'Kallio', max_participants: 5 }); const m = await L.from('messages').insert({ conversation_id: c, body: 'hei' }); const u = await L.from('profiles').update({ banned: false }).eq('id', L.id); return [e.error && e.error.message, m.error && m.error.message, window.__mockSupa.db().profiles.find(p => p.id === L.id).banned]; }, lenkki.id);
  ok(blocked[0] === 'account_banned' && blocked[1] === 'account_banned' && blocked[2] === true, 'banned user cannot create events or send messages, and cannot unban themself');

  ok(errors.length === 0, 'no page/console errors' + (errors.length ? ': ' + errors.join(' | ') : ''));
  console.log(`\nALL PASSED: ${passed} checks`);
  await browser.close();
})().catch(async e => { console.error('✘', e.message, `\n(${passed} checks passed before failure)`); process.exit(1); });
