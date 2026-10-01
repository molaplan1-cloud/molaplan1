/* Molaplan v2 UI tests – run against the in-memory Supabase mock (index.html?mock=1 on localhost).
   Start a static server first:  python3 -m http.server 8765 --bind 127.0.0.1
   Then:  node test.js      (screenshots -> shots/v2-*.png) */
const { chromium } = require('playwright-core');
const SHOTS = __dirname + '/shots/';
const BASE = process.env.URL || 'http://127.0.0.1:8765/index.html';
let passed = 0;
(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROME || '/usr/bin/google-chrome', args: ['--no-sandbox', '--lang=fi-FI'] });
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale: 'fi-FI', timezoneId: 'Europe/Helsinki' });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  page.on('console', m => { if (m.type() === 'error' && !/tile\.openstreetmap|Failed to load resource/.test(m.text())) errors.push('console: ' + m.text()); });
  page.on('dialog', d => d.accept());
  const ok = (c, m) => { if (!c) throw new Error('ASSERT: ' + m); passed++; console.log('✔', m); };
  const shot = async (name) => { await page.waitForTimeout(350); await page.screenshot({ path: SHOTS + 'v2-' + name + '.png' }); };
  const M = (fn, ...a) => page.evaluate(fn, ...a);
  const S = () => M(() => window.__molaplan.state);
  const toast = async () => (await page.textContent('#toast').catch(() => '')) || '';
  const waitToast = async (re) => { await page.waitForFunction(r => new RegExp(r).test((document.querySelector('#toast') || {}).textContent || ''), re.source, { timeout: 5000 }); };
  const tab = t => page.click(`#nav [data-t="${t}"]`);
  const refresh = () => M(() => window.__molaplan.refresh());
  const noDemo = async (where) => { const t = await page.evaluate(() => document.body.innerText); ok(!/demo|prototyyp|esimerkki|localStorage|simuloi/i.test(t), 'no demo/prototype wording on ' + where); };
  const tomorrow = () => { const d = new Date(Date.now() + 864e5); return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); };
  const tryTiles = async sel => { try { await page.waitForFunction(s => { const i = [...document.querySelectorAll(s + ' img.leaflet-tile')]; return i.length && i.every(x => x.complete && x.naturalWidth > 0); }, sel, { timeout: 15000 }); await page.waitForTimeout(500); } catch (e) { console.log('  (map tiles did not load – continuing)'); } };

  // ---------- 1. not configured -> coming soon (config.js served with placeholders) ----------
  await page.route('**/config.js', r => r.fulfill({ contentType: 'application/javascript', body: "window.SUPABASE_URL='https://YOUR-PROJECT-REF.supabase.co';window.SUPABASE_ANON_KEY='YOUR-ANON-KEY';" }));
  await page.goto(BASE);
  await page.waitForSelector('#coming-soon');
  ok((await page.textContent('#coming-soon')).includes('Palvelu otetaan käyttöön pian'), 'unconfigured config.js shows "Palvelu otetaan käyttöön pian"');
  ok(await M(() => document.querySelector('#app').classList.contains('onb') && document.querySelector('#nav').getBoundingClientRect().top >= innerHeight - 2), 'navigation hidden on coming-soon screen');
  await page.evaluate(() => document.fonts.ready);
  await shot('00-tulossa');
  await page.unroute('**/config.js');

  // ---------- 1b. guest browsing: landing -> feed/map without an account, login sheet only when acting ----------
  await page.goto(BASE + '?mock=1');
  await M(() => { if (window.__mockSupa) window.__mockSupa.reset(); localStorage.clear(); sessionStorage.clear(); }); await page.reload();
  await page.waitForSelector('#landing');
  await page.evaluate(() => document.fonts.ready);
  ok(await M(() => { const r = document.querySelector('#lang-gate').getBoundingClientRect(); return r.top < 80 && r.right > innerWidth - 60; }), 'first screen: language switcher (EN/FI/ES/SV) in the top corner');
  ok((await page.textContent('#lang-gate')).replace(/\s/g, '') === 'ENFIESSV', 'language switcher offers en, fi, es, sv');
  ok(!(await page.$('#auth-card')), 'first screen is the landing, not a sign-up form');
  await noDemo('landing');
  // other people's data (created through the mock "as" another user)
  const seeded = await M(async () => {
    const S = window.__mockSupa; S.createUser('hanna@example.com', 'Hanna', { city: 'Tuusula', district: 'Hyrylä', phone: '+358401112233' });
    S.createUser('admin0@example.com', 'Admin', { admin: true });
    const h = S.as('hanna@example.com'), d = n => new Date(Date.now() + n * 864e5).toISOString();
    await h.from('events').insert({ activity_id: 'padel', title: 'Padel Hyrylässä', starts_at: d(2), city: 'Tuusula', district: 'Hyrylä', place: 'Hyrylän padelhalli', lat: 60.404, lng: 25.023, max_participants: 4 });
    await h.from('events').insert({ activity_id: 'nakuuinti', title: 'Kuutamouinti', starts_at: d(3), city: 'Tuusula', district: 'Rusutjärvi', place: 'Rusutjärven ranta', lat: 60.43, lng: 25.05, max_participants: 8 });
    const base = { city: 'Tuusula', district: 'Jokela', place: 'Kotikatu 5 B 12', lat: 60.5512, lng: 24.9687, starts_at: d(4), duration: '1h', helpers_needed: 1, consent_voluntary: true, consent_terms: true, consent_review: true };
    const r1 = await h.rpc('submit_help_request', { req: Object.assign({ category: 'kauppa', title: 'Kauppakassit kotiin', description: 'Tarvitsisin apua kauppakassien kantamisessa.' }, base), contact: { name: 'Hanna', phone: '+358401112233', email: 'hanna@example.com' } });
    const r2 = await h.rpc('submit_help_request', { req: Object.assign({ category: 'koira', title: 'Koiran ulkoilutus', description: 'Koira tarvitsee lenkkiseuraa viikonloppuna.' }, base), contact: { name: 'Hanna', phone: '+358401112233', email: 'hanna@example.com' } });
    await S.as('admin0@example.com').from('help_requests').update({ status: 'approved' }).eq('id', r1.data);
    return { approved: r1.data, pending: r2.data };
  });
  ok(await page.isVisible('#land-locate') && (await page.textContent('#land-locate')).includes('Näytä lähelläni'), 'landing: primary action "Näytä lähelläni" (use my location)');
  ok(!(await page.isVisible('#land-city')) && (await page.textContent('#land-manual-btn')).includes('Valitse kaupunki itse'), 'landing: manual city picker is the secondary option "Valitse kaupunki itse"');
  ok(await M(() => !document.querySelector('#landing .tile, #landing [data-a="pick-act"], #landing .act-grid')), 'landing never asks for an activity/sport type');
  await page.click('#land-manual-btn'); await page.waitForSelector('#land-city');
  await page.selectOption('#land-city', 'Tuusula');
  ok(await M(() => [...document.querySelectorAll('#land-district option')].map(o => o.value).join()).then(v => ['Hyrylä', 'Jokela', 'Kellokoski'].every(x => v.includes(x))), 'landing: Tuusula districts selectable (Hyrylä, Jokela, Kellokoski…)');
  await page.selectOption('#land-district', 'Hyrylä');
  await shot('19-vieras-aloitus');
  await page.click('#land-go'); await page.waitForSelector('#s-home.active .card');
  ok(await M(() => window.__molaplan.state.guest === true && !window.__mockSupa.db().calls.some(c => c.fn === 'signUp')), 'guest sees the feed without an account');
  const gHome = await page.textContent('#s-home');
  ok(gHome.includes('Padel Hyrylässä') && gHome.includes('Tuusula'), 'guest feed shows public events in the chosen city');
  ok(!gHome.includes('Kuutamouinti'), '18+ events are not shown to guests');
  ok(await page.isVisible('#guest-login') && await page.isVisible('#guest-lang'), 'guest header has "Kirjaudu" and a language button');
  ok(await page.isVisible('#vt-list') && await page.isVisible('#vt-map') && (await page.textContent('#vt-list')).includes('Lista') && (await page.textContent('#vt-map')).includes('Kartta'), 'home feed has a visible Lista/Kartta toggle');
  ok((await page.textContent('#guest-city')).includes('Vaihda aluetta'), 'home header offers "Vaihda aluetta" (change area)');
  ok(await M(() => document.querySelector('#s-home .act-filter-item.on').dataset.v === 'all'), 'default activity filter = all activities');
  const gState = await M(() => JSON.stringify(window.__molaplan.state));
  ok(!gState.includes('Hanna') && !gState.includes('+358401112233') && !gState.includes('hanna@example.com') && !gState.includes('Kotikatu'), 'guest data has no names, phone numbers, emails or street addresses');
  ok(await M(() => { try { return JSON.stringify(window.__mockSupa.db()) && true; } catch (e) { return false; } }), 'mock DB reachable');
  const anon = await M(async () => { const c = window.MolaplanMock.createClient(); const out = {}; for (const t of ['messages', 'help_request_contacts', 'profiles', 'profile_private', 'notifications', 'conversations', 'events', 'help_requests']) { const r = await c.from(t).select('*'); out[t] = !!r.error; } const a = await c.from('activities').select('*'); out.activitiesStar = !!a.error; const g = await c.from('guest_help_requests').select('*'); out.helps = g.data.map(x => x.title); out.helpKeys = Object.keys(g.data[0] || {}); return out; });
  ok(['messages', 'help_request_contacts', 'profiles', 'profile_private', 'notifications', 'conversations', 'events', 'help_requests'].every(t => anon[t]) && anon.activitiesStar, 'anon cannot read messages, contacts, profiles, notifications or raw tables');
  ok(anon.helps.includes('Kauppakassit kotiin') && !anon.helps.includes('Koiran ulkoilutus') && !anon.helpKeys.some(k => /requester|phone|email_addr|contact|place|history|admin/.test(k)), 'anon sees approved help requests only, without contact/requester fields');
  await shot('20-vieras-koti');
  await page.click('#s-home .card [data-a="join"]'); await page.waitForSelector('#auth-prompt'); await page.waitForTimeout(350);
  ok((await page.textContent('#auth-prompt')).includes('Luo ilmainen tili'), 'joining as a guest opens the "create an account or log in" sheet');
  await shot('21-kirjaudu-kehote');
  await page.click('#ap-later'); await page.waitForTimeout(300);
  for (const t of ['create', 'chats', 'mine']) { await tab(t); await page.waitForSelector('#auth-prompt'); ok(await M(() => document.querySelector('#app').classList.contains('sheet-open')), `guest tapping "${t}" gets the login sheet`); await page.click('#ap-later'); await page.waitForTimeout(250); }
  await page.click('#good-banner'); await page.waitForSelector('#s-good.active');
  ok((await page.textContent('#s-good')).includes('Kauppakassit kotiin') && !(await page.textContent('#s-good')).includes('Koiran ulkoilutus'), 'guest sees approved help requests only (pending hidden)');
  await page.click('#s-good [data-a="offer"]'); await page.waitForSelector('#auth-prompt'); ok(true, 'offering help as a guest opens the login sheet');
  await page.click('#ap-later'); await page.waitForTimeout(250); await page.click('#s-good [data-a="back"]');
  await tab('map'); await page.waitForSelector('#s-map.active');
  await page.waitForFunction(() => document.querySelectorAll('#s-map .leaflet-marker-icon').length >= 2);
  ok(true, 'guest map shows public events and help requests');
  // log in from the prompt -> sign up -> onboarding (name, activities) -> back to the join
  await tab('home'); await page.click('#s-home .card [data-a="join"]'); await page.waitForSelector('#auth-prompt');
  await page.click('#ap-signup'); await page.waitForSelector('#auth-card #tab-signup.on');
  ok(await page.isVisible('#auth-cancel'), 'auth screen offers "keep browsing without an account"');
  await page.fill('#au-email', 'vieras+test@example.com'); await page.fill('#au-pw', 'salasana123'); await page.click('#auth-submit');
  await page.waitForSelector('#onb.active #onb-name');
  ok(await page.inputValue('#onb-city') === 'Tuusula' && await page.inputValue('#onb-district') === 'Hyrylä', 'onboarding pre-filled with the city/district chosen as a guest');
  await page.fill('#onb-name', 'Vieras'); await page.click('[data-a="onb-next"]'); await page.waitForSelector('#s-lajit.active');
  await page.click('#s-lajit [data-v="padel"]'); await page.click('[data-a="lajit-done"]');
  await page.waitForSelector('#s-detail.active'); await page.waitForFunction(() => { const d = window.__mockSupa.db(); const u = d.users.find(x => x.email === 'vieras+test@example.com'); return u && d.event_participants.some(p => p.user_id === u.id); }, null, { timeout: 5000 });
  ok(true, 'after sign-up the user returns to the event and the pending join completes');
  await page.click('#s-detail [data-a="back"]').catch(() => {});
  await page.click('#s-home [data-t="profile"]'); await page.waitForSelector('#logout-btn');
  await page.click('#logout-btn'); await page.waitForSelector('#s-home.active #guest-login');
  ok(true, 'logout returns to guest browsing');

  // ---------- 2. auth with email confirmation ON ----------
  await page.goto(BASE + '?mock=1&confirm=1');
  await M(() => { if (window.__mockSupa) window.__mockSupa.reset(); localStorage.clear(); sessionStorage.clear(); }); await page.reload();
  await page.waitForSelector('#landing'); await page.click('#land-signup');
  await page.waitForSelector('#auth-card #tab-signup.on');
  await noDemo('auth screen');
  await shot('01-luo-tili');
  await page.fill('#au-email', 'ei-sahkoposti'); await page.fill('#au-pw', 'salasana123'); await page.click('#auth-submit');
  await waitToast(/Tarkista sähköpostiosoite/); ok(true, 'invalid email rejected client-side');
  await page.fill('#au-email', 'enn+test@example.com'); await page.fill('#au-pw', 'lyhyt'); await page.click('#auth-submit');
  await waitToast(/vähintään 8/); ok(true, 'short password rejected client-side');
  await page.fill('#au-pw', 'salasana123'); await page.click('#auth-submit');
  await page.waitForSelector('#mail-sent');
  ok((await page.textContent('#mail-sent')).includes('enn+test@example.com'), 'confirmation-sent screen shows the address');
  await shot('02-vahvista-sahkoposti');
  await page.click('[data-a="auth-resend"]'); await waitToast(/lähetetty uudelleen/);
  ok((await M(() => window.__mockSupa.calls())).some(c => c.fn === 'resend'), 'resend confirmation calls auth.resend');
  await page.click('#mail-sent [data-a="auth-mode"][data-v="login"]');
  await page.fill('#au-pw', 'salasana123'); await page.click('#auth-submit');
  await waitToast(/Vahvista ensin sähköpostisi/); ok(true, 'login before confirming email shows Finnish error');
  await page.fill('#au-pw', 'vaarasalasana'); await page.click('#auth-submit');
  await waitToast(/Väärä sähköposti tai salasana/); ok(true, 'wrong password shows Finnish error');
  // forgot password
  await page.click('#forgot-link'); await page.waitForSelector('#auth-card h2');
  await shot('03-unohtunut-salasana');
  await page.click('#auth-submit'); await page.waitForSelector('#mail-sent');
  const rp = (await M(() => window.__mockSupa.calls())).find(c => c.fn === 'resetPasswordForEmail');
  ok(rp && rp.email === 'enn+test@example.com' && /index\.html$/.test(rp.redirectTo), 'password reset email requested with redirect back to the app');
  await page.click('#mail-sent [data-a="auth-mode"]');
  // confirm email (as if the link was clicked) and log in
  await M(() => window.__mockSupa.confirmEmail('enn+test@example.com'));
  await page.fill('#au-pw', 'salasana123'); await page.click('#auth-submit');

  // ---------- 3. onboarding ----------
  await page.waitForSelector('#onb.active #onb-name');
  ok((await page.textContent('#onb')).includes('enn+test@example.com'), 'onboarding shows signed-in email');
  await noDemo('onboarding');
  await page.fill('#onb-name', 'Enn'); await page.selectOption('#onb-city', 'Helsinki'); await page.selectOption('#onb-district', 'Kallio');
  await shot('04-onboarding');
  await page.click('[data-a="onb-next"]'); await page.waitForSelector('#s-lajit.active');
  for (const id of ['padel', 'lautapelit', 'kahvi']) await page.click(`#s-lajit [data-v="${id}"]`);
  await page.click('#s-lajit [data-a="add-own"]'); await page.waitForTimeout(400);
  await page.fill('#cs-name', 'Melonta'); await page.click('.emoji-grid [data-v="🛶"]');
  await page.click('[data-a="cs-add"]');
  await page.waitForSelector('#s-lajit .tile.on:has-text("Melonta")');
  ok((await M(() => window.__mockSupa.db().activities.filter(a => a.name === 'Melonta' && a.is_custom).length)) === 1, 'custom activity saved to activities table');
  await page.click('[data-a="lajit-done"]'); await page.waitForSelector('#s-home.active');
  const prof = await M(() => { const d = window.__mockSupa.db(); return d.profiles.find(p => p.id === window.__mockSupa.userId('enn+test@example.com')); });
  ok(prof.onboarded && prof.display_name === 'Enn' && prof.district === 'Kallio' && prof.favs.length === 4, 'profile row saved (name, district, 4 favs, onboarded)');
  await page.waitForSelector('#home-empty');
  ok((await page.textContent('#home-empty')).includes('Ei vielä tapahtumia'), 'friendly Finnish empty state on home');
  ok(await page.locator('#s-home .card').count() === 0, 'no seeded meetups');
  await noDemo('home');
  await page.evaluate(() => document.querySelector('#s-home').scrollTop = 0);
  await shot('05-koti-tyhja');

  // other users (simulated)
  const bobId = await M(() => window.__mockSupa.createUser('bob+test@example.com', 'Bob', { phone: '+358401111111' }));
  await M(() => window.__mockSupa.createUser('carol+test@example.com', 'Carol', { phone: '+358402222222' }));
  await M(() => window.__mockSupa.createUser('dave+test@example.com', 'Dave'));
  const bobEvent = await M(async () => { const s = new Date(Date.now() + 2 * 864e5); s.setHours(18, 0, 0, 0); const r = await window.__mockSupa.as('bob+test@example.com').from('events').insert({ activity_id: 'padel', title: 'Padel-ilta Kalliossa', description: 'Rento peli, mailoja lainaan.', starts_at: s.toISOString(), city: 'Helsinki', district: 'Kallio', place: 'Kallion urheilukenttä', lat: 60.1841, lng: 24.9500, max_participants: 4, skill_level: 'all' }).select().single(); return r.data.id; });
  await M(async () => { const s = new Date(Date.now() + 3 * 864e5); s.setHours(12, 0, 0, 0); await window.__mockSupa.as('carol+test@example.com').from('events').insert({ activity_id: 'nakuuinti', title: 'Nakuuinti Hietsussa', starts_at: s.toISOString(), city: 'Helsinki', district: 'Etu-Töölö', place: 'Hietaniemen ranta', lat: 60.172, lng: 24.9, max_participants: 8, skill_level: 'all' }); });
  await refresh(); await page.waitForTimeout(300);
  ok(await page.locator('#s-home .card').count() === 2, 'events created by others appear after refresh');
  const czc = await M(() => window.__molaplan.crazyUpcoming.length);
  ok(czc === 1, 'crazy event (from crazy activity) detected');
  await page.evaluate(() => document.querySelector('#s-home').scrollTop = 0);
  await shot('06-koti-tapahtumat');

  // ---------- 4. join Bob's event, realtime chat ----------
  await page.click(`#s-home .card[data-id="${bobEvent}"]`);
  await page.waitForSelector('#s-detail.active');
  ok((await page.textContent('#s-detail')).includes('Bob'), 'host name resolved from profiles');
  await page.click('#s-detail [data-a="join"]');
  await page.waitForFunction(id => window.__molaplan.state.meetups.find(m => m.id === id).people.length === 2, bobEvent);
  const bobNotifs = await M(id => window.__mockSupa.db().notifications.filter(n => n.user_id === id).map(n => n.body), bobId);
  ok(bobNotifs.some(b => /Enn liittyi/.test(b)), 'host gets a notification when someone joins (DB trigger)');
  await page.waitForSelector('#chat-box');
  await page.click('#s-detail .d-chat, #s-detail [data-a="open-chat"]');
  await page.waitForSelector('#s-chat.active #cv-in');
  await page.fill('#cv-in', 'Moi! Tuon pallot 🎾'); await page.press('#cv-in', 'Enter');
  await page.waitForFunction(() => [...document.querySelectorAll('#cv-msgs .msg')].some(m => m.textContent.includes('Tuon pallot')));
  await page.waitForFunction(() => window.__mockSupa.db().messages.some(m => m.body === 'Moi! Tuon pallot 🎾'), null, { timeout: 4000 }).catch(() => {});
  const dbMsg = await M(() => { const m = window.__mockSupa.db().messages.find(m => m.body === 'Moi! Tuon pallot 🎾'); return m && m.kind === 'user' && m.sender_id === window.__mockSupa.userId('enn+test@example.com'); });
  ok(dbMsg, 'message stored in messages table with sender = me');
  // Bob replies -> realtime
  await M(async id => { const c = window.__mockSupa.db().conversations.find(c => c.event_id === id); await window.__mockSupa.as('bob+test@example.com').from('messages').insert({ conversation_id: c.id, body: 'Mahtavaa, nähdään kentällä!' }); }, bobEvent);
  await page.waitForFunction(() => [...document.querySelectorAll('#cv-msgs .msg')].some(m => m.textContent.includes('nähdään kentällä')), null, { timeout: 4000 });
  ok(true, 'realtime: message from another user appears in open chat');
  ok((await page.textContent('#cv-msgs')).includes('Enn liittyi mukaan'), 'system message from join trigger shown');
  await shot('07-chat');
  // Dave (not a member) cannot read or post
  const daveRead = await M(async () => (await window.__mockSupa.as('dave+test@example.com').from('messages').select('*')).data.length);
  ok(daveRead === 0, 'RLS (mock): non-member sees no chat messages');
  await page.click('#s-chat [data-a="back"]');
  // leave
  await page.waitForSelector('#s-detail.active');
  await page.click('#s-detail [data-a="leave"]');
  await page.waitForFunction(id => window.__molaplan.state.meetups.find(m => m.id === id).people.length === 1, bobEvent);
  ok(true, 'leave event removes participant row');
  await page.click('#s-detail [data-a="back"]');

  // ---------- 5. create own event ----------
  await tab('create'); await page.waitForSelector('#s-create.active #c-title');
  await page.click('#s-create [data-a="c-act"][data-v="padel"]');
  await page.fill('#c-title', 'Lauantain lautapeli-ilta');
  await page.click('#s-create [data-a="c-act"][data-v="lautapelit"]');
  await page.fill('#c-date', tomorrow()); await page.fill('#c-time', '18:30');
  await page.fill('#c-place', 'Kallion kirjasto'); await page.fill('#c-desc', 'Tuo oma lempipeli!');
  await page.evaluate(() => document.querySelector('#s-create').scrollTop = 0);
  await shot('08-luo-tapahtuma');
  ok(await page.isVisible('#c-rule') && (await page.textContent('#c-rule')).includes('Yritysten ja maksullisten palveluiden mainostaminen on kielletty') && await page.isVisible('#c-rule-biz'), 'create form shows the no-advertising rule + link to the business account');
  await page.click('#s-create [data-a="publish"]'); await waitToast(/yksityinen/);
  ok(!(await M(() => window.__mockSupa.db().events.some(e => e.title === 'Lauantain lautapeli-ilta'))), 'publish blocked until "Tapahtuma on yksityinen…" is ticked');
  await page.click('#ck-rule');
  await page.click('#s-create [data-a="publish"]');
  await page.waitForSelector('#s-detail.active');
  const myEv = await M(() => window.__mockSupa.db().events.find(e => e.title === 'Lauantain lautapeli-ilta'));
  ok(myEv && myEv.activity_id === 'lautapelit' && myEv.max_participants >= 2, 'event row inserted');
  ok(await M(id => window.__mockSupa.db().conversations.some(c => c.event_id === id), myEv.id), 'conversation auto-created for event (trigger)');
  await tryTiles('#mini-map');
  await shot('09-tapahtuma');
  // 18+ auto flag from title
  await page.click('#s-detail [data-a="back"]');
  await tab('create'); await page.waitForSelector('#s-create.active #c-title');
  await page.fill('#c-title', 'Viinimaistelu puistossa');
  await page.waitForTimeout(200);
  ok(await page.locator('#s-create [data-a="c-adult-t"].on, #s-create #c-adult-t.on, #s-create .tgl.on:has-text("18+")').count() >= 1, '18+ toggle turns on automatically from title');
  await page.fill('#c-title', '');
  await tab('home'); await page.waitForSelector('#s-home.active');

  // ---------- 6. map ----------
  await tab('map'); await page.waitForSelector('#s-map.active');
  await tryTiles('#big-map, #s-map');
  ok(await page.locator('#s-map .leaflet-marker-icon').count() >= 2, 'map shows markers for events');
  await shot('10-kartta');

  // ---------- 7. Hullut ----------
  await tab('home'); await page.click('#cz-banner'); await page.waitForSelector('#s-hullut.active');
  ok(await page.locator('#s-hullut .card.crazy').count() === 1, 'Hullut view lists crazy events from DB');
  await page.click('#s-hullut [data-a="back"]');

  // ---------- 8. Tehdään yhdessä hyvää: ask for help ----------
  await page.click('#good-banner'); await page.waitForSelector('#s-good.active');
  await noDemo('Hyvät teot');
  await page.click('#s-good [data-a="ask-help"]'); await page.waitForSelector('#s-ask.active #a-title');
  await page.fill('#a-title', 'Apua muuttolaatikoiden kantamiseen');
  await page.fill('#a-desc', 'Muutan kolmanteen kerrokseen ilman hissiä, tarvitsen kaksi kantajaa.');
  await page.fill('#a-needs', 'Pari tuntia, hyvät kengät');
  await page.fill('#a-date', tomorrow()); await page.fill('#a-time', '12:00');
  await page.click('#s-ask [data-a="a-next"]'); await page.waitForSelector('#vblock');
  ok(await page.locator('#vr-email.ok').count() === 1, 'verified email shown as ✓ in verification step');
  ok(await page.locator('#v-phone').count() === 1, 'phone input shown (no SMS code)');
  ok((await page.textContent('#s-ask')).includes('tarkistaa jokaisen pyynnön käsin'), 'manual admin review wording replaces bank-ID');
  ok(!/pankkitunnus|BankID|koodi/i.test(await page.textContent('#vblock')), 'no bank-ID / SMS-code UI');
  await page.fill('#v-phone', '12'); await page.click('[data-a="v-phone-save"]'); await waitToast(/Tarkista puhelinnumero/);
  ok(true, 'invalid phone rejected');
  await page.fill('#v-phone', '+358 40 123 4567'); await page.click('[data-a="v-phone-save"]');
  await page.waitForSelector('#vr-phone.ok');
  ok(await M(() => window.__mockSupa.db().profile_private.find(p => p.id === window.__mockSupa.userId('enn+test@example.com')).phone) === '+358 40 123 4567', 'phone saved to profile_private');
  await page.evaluate(() => document.querySelector('#s-ask').scrollTop = 0);
  await shot('11-apupyynto-vahvistus');
  await page.click('#s-ask [data-a="a-next"]'); await page.waitForSelector('#ck-vol');
  await page.click('#s-ask [data-a="a-submit"]'); await waitToast(/suostumukset/);
  ok(true, 'submit blocked until all three consents are checked');
  for (const k of ['vol', 'terms', 'review']) await page.click('#ck-' + k, { position: { x: 16, y: 16 } });
  await page.evaluate(() => document.querySelector('#s-ask').scrollTop = 0);
  await shot('12-apupyynto-suostumukset');
  await page.click('#s-ask [data-a="a-submit"]');
  await page.waitForSelector('#s-mine.active .card.req');
  const req = await M(() => window.__mockSupa.db().help_requests.find(h => h.title.startsWith('Apua muutto')));
  ok(req && req.status === 'pending' && req.consent_voluntary && req.consent_terms && req.consent_review, 'help request stored as pending with all consents');
  ok(await M(id => !!window.__mockSupa.db().help_request_contacts.find(c => c.request_id === id && c.phone === '+358 40 123 4567'), req.id), 'contact row stored separately (help_request_contacts)');
  await shot('13-omat-pyynnot');
  { const seen = await M(async () => (await window.__mockSupa.as('bob+test@example.com').from('help_requests').select('*')).data.map(h => h.title + '|' + h.status)); ok(seen.length === 0, 'RLS (mock): pending request invisible to other users' + (seen.length ? ' saw: ' + seen.join(', ') : '')); }

  // ---------- 9. admin ----------
  await M(() => window.__mockSupa.makeAdmin('enn+test@example.com'));
  await page.reload(); await page.waitForSelector('#s-home.active');
  await page.click('#s-home [data-t="profile"]'); await page.waitForSelector('#s-profile.active #p-admin');
  ok(await page.locator('#p-verified').count() === 1, 'profile shows Vahvistettu badge (email+phone)');
  await shot('14-profiili');
  await page.click('#open-admin'); await page.waitForSelector('#s-admin.active');
  ok(await page.locator('#s-admin .card.adm').count() === 1, 'admin queue lists pending request');
  ok((await page.textContent('#s-admin')).includes('+358 40 123 4567'), 'admin sees contact phone');
  await shot('15-yllapito');
  await page.click(`#s-admin [data-a="adm-approve"]`);
  await page.waitForFunction(() => document.querySelectorAll('#s-admin .card.adm').length === 0);
  ok(await M(id => window.__mockSupa.db().help_requests.find(h => h.id === id).status, req.id) === 'approved', 'admin approval updates status');
  await page.waitForFunction(() => window.__molaplan.state.notifs.some(n => /hyväksytty/.test(n.text)), null, { timeout: 4000 });
  ok(true, 'requester receives realtime notification on approval');
  await page.click('#s-admin [data-a="back"]');
  // helpers
  const daveOffer = await M(async id => (await window.__mockSupa.as('dave+test@example.com').from('help_offers').insert({ request_id: id })).error, req.id);
  ok(daveOffer && /verification_required/.test(daveOffer.message), 'unverified user (no phone) cannot offer help');
  await M(async id => { await window.__mockSupa.as('carol+test@example.com').from('help_offers').insert({ request_id: id }); }, req.id);
  await page.waitForFunction(() => window.__molaplan.state.notifs.some(n => /Carol tarjoutui/.test(n.text)), null, { timeout: 4000 });
  ok(true, 'requester notified when a verified helper offers');
  const carolSees = await M(async id => (await window.__mockSupa.as('carol+test@example.com').from('help_request_contacts').select('*').eq('request_id', id)).data.length, req.id);
  ok(carolSees === 1, 'accepted helper can see requester contact');
  ok(await M(async id => (await window.__mockSupa.as('bob+test@example.com').from('help_request_contacts').select('*').eq('request_id', id)).data.length, req.id) === 0, 'non-helper cannot see contact');
  // Enn helps Bob
  const bobReq = await M(async () => { const s = new Date(Date.now() + 2 * 864e5); s.setHours(10, 0, 0, 0); const r = await window.__mockSupa.as('bob+test@example.com').rpc('submit_help_request', { req: { category: 'kauppa', title: 'Kauppakassit kotiin', description: 'Tarvitsen apua kauppakassien kantamiseen.', needs: '', city: 'Helsinki', district: 'Kallio', place: 'K-Market', lat: 60.184, lng: 24.95, starts_at: s.toISOString(), duration: '1h', helpers_needed: 1, consent_voluntary: true, consent_terms: true, consent_review: true }, contact: { name: 'Bob', phone: '+358401111111', email: 'x' } }); return r.data; });
  await page.waitForFunction(() => window.__molaplan.state.notifs.some(n => /Uusi avunpyyntö/.test(n.text)), null, { timeout: 4000 });
  ok(true, 'admins notified about new help request');
  await tab('home'); await page.waitForSelector('#s-home.active'); await page.click('#s-home .bell'); await page.waitForSelector('#notif-list');
  await shot('16-ilmoitukset');
  await page.click('[data-a="sheet-close"]').catch(() => {}); await page.keyboard.press('Escape');
  await M(async id => { await window.__mockSupa.as('enn+test@example.com').from('help_requests').update({ status: 'approved' }).eq('id', id); }, bobReq);
  await refresh();
  await tab('home'); await page.click('#good-banner'); await page.waitForSelector('#s-good.active');
  await page.click(`#s-good [data-a="open-help"][data-id="${bobReq}"], #s-good .card[data-id="${bobReq}"] h3`);
  await page.waitForSelector('#s-hdetail.active #d-offer');
  await page.click('#d-offer');
  await page.waitForSelector('#s-chat.active');
  ok(await M(id => window.__mockSupa.db().help_offers.some(o => o.request_id === id && o.helper_id === window.__mockSupa.userId('enn+test@example.com')), bobReq), 'verified user offered help (help_offers row)');
  await page.click('#s-chat [data-a="back"]'); await page.waitForSelector('#s-hdetail.active #help-contact');
  ok((await page.textContent('#help-contact')).includes('+358401111111'), 'helper sees requester contact after offering');
  await shot('17-autan');
  await page.click('#s-hdetail [data-a="back"]');

  // ---------- 10. recovery + logout/login + persistence ----------
  await M(() => window.__mockSupa.triggerRecovery());
  await page.waitForSelector('#recovery-card');
  await shot('18-uusi-salasana');
  await page.fill('#rc-pw', 'uusisalasana1'); await page.fill('#rc-pw2', 'eri'); await page.click('#recovery-submit'); await waitToast(/eivät täsmää/);
  await page.fill('#rc-pw2', 'uusisalasana1'); await page.click('#recovery-submit');
  await page.waitForSelector('#s-home.active');
  ok(await M(() => window.__mockSupa.db().users.find(u => u.email === 'enn+test@example.com').password) === 'uusisalasana1', 'password updated via recovery flow');
  await page.click('#s-home [data-t="profile"]'); await page.waitForSelector('#logout-btn');
  await page.click('#logout-btn'); await page.waitForSelector('#s-home.active #guest-login');
  ok(true, 'logout returns to guest browsing');
  await page.click('#guest-login'); await page.waitForSelector('#auth-card #tab-login.on');
  await page.fill('#au-email', 'enn+test@example.com'); await page.fill('#au-pw', 'uusisalasana1'); await page.click('#auth-submit');
  await page.waitForSelector('#s-home.active .card');
  ok(await page.locator('#s-home .card').count() >= 3, 'data persists across logout/login (loaded from DB)');

  // ---------- 11. delete account ----------
  await page.click('#s-home [data-t="profile"]'); await page.waitForSelector('#p-account');
  await page.click('[data-a="delete-account"]'); await page.waitForSelector('#s-home.active #guest-login');
  const gone = await M(() => { const d = window.__mockSupa.db(); return !d.users.some(u => u.email === 'enn+test@example.com') && !d.events.some(e => e.title === 'Lauantain lautapeli-ilta'); });
  ok(gone, 'delete account removes user and their events');

  // ---------- 12. signup without confirmation goes straight to onboarding ----------
  await page.goto(BASE + '?mock=1'); await M(() => { if (window.__mockSupa) window.__mockSupa.reset(); localStorage.clear(); sessionStorage.clear(); }); await page.reload();
  await page.waitForSelector('#landing'); await page.click('#land-signup'); await page.waitForSelector('#auth-card');
  await page.fill('#au-email', 'uusi+test@example.com'); await page.fill('#au-pw', 'salasana123'); await page.click('#auth-submit');
  await page.waitForSelector('#onb.active');
  ok(true, 'with confirmation OFF, sign-up goes directly to onboarding');
  await page.fill('#onb-name', 'Uusi'); await page.click('[data-a="onb-next"]'); await page.waitForSelector('#s-lajit.active');
  ok(await page.isVisible('#lajit-skip') && (await page.textContent('#lajit-opt')).includes('Vapaaehtoinen'), 'favourite activities step is optional ("Ohita toistaiseksi")');
  await page.click('#lajit-skip'); await page.waitForSelector('#s-home.active');
  const p12 = await M(() => window.__mockSupa.db().profiles.find(p => p.id === window.__mockSupa.userId('uusi+test@example.com')));
  ok(p12.onboarded && p12.favs.length === 0, 'onboarding completes without choosing any sport (no forced activity selection)');
  ok(await M(() => document.querySelector('#s-home .act-filter-item.on').dataset.v === 'all' && window.__molaplan.state.user.favs.length === 0), 'logged-in default filter = all activities');
  await page.click('#s-home [data-t="profile"]'); await page.waitForSelector('#logout-btn');
  await page.click('#logout-btn'); await page.waitForSelector('#s-home.active #guest-login');
  await page.click('#guest-login'); await page.waitForSelector('#auth-card #tab-login.on');
  await page.click('#tab-signup'); await page.fill('#au-email', 'uusi+test@example.com'); await page.fill('#au-pw', 'salasana123'); await page.click('#auth-submit');
  await waitToast(/jo tili/); ok(true, 'duplicate sign-up shows "Tällä sähköpostilla on jo tili"');

  // ---------- 13. location first: "Näytä lähelläni" (mocked geolocation) ----------
  const geoPage = async (geo, perm) => {
    const c = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true, locale: 'fi-FI', timezoneId: 'Europe/Helsinki' });
    await c.addInitScript(([geo, perm]) => {
      window.__geoCalls = 0;
      Object.defineProperty(navigator, 'geolocation', { configurable: true, value: { getCurrentPosition: (res, rej) => { window.__geoCalls++; setTimeout(() => geo ? res({ coords: { latitude: geo[0], longitude: geo[1], accuracy: 25 }, timestamp: Date.now() }) : rej({ code: 1, message: 'User denied Geolocation' }), 60); }, watchPosition: () => 0, clearWatch: () => {} } });
      Object.defineProperty(navigator, 'permissions', { configurable: true, value: { query: d => Promise.resolve({ name: d && d.name, state: d && d.name === 'geolocation' ? perm : 'prompt', onchange: null }) } });
    }, [geo, perm]);
    const p = await c.newPage();
    p.on('pageerror', e => errors.push('pageerror: ' + e.message));
    p.on('console', m => { if (m.type() === 'error' && !/tile\.openstreetmap|Failed to load resource/.test(m.text())) errors.push('console: ' + m.text()); });
    await p.goto(BASE + '?mock=1');
    await p.evaluate(async () => {
      window.__mockSupa.reset(); localStorage.clear(); sessionStorage.clear();
      const S = window.__mockSupa; S.createUser('liisa@example.com', 'Liisa', { city: 'Helsinki', district: 'Kallio' });
      const h = S.as('liisa@example.com'), d = n => new Date(Date.now() + n * 864e5).toISOString();
      await h.from('events').insert({ activity_id: 'padel', title: 'Kaukana Vuosaaressa', starts_at: d(1), city: 'Helsinki', district: 'Vuosaari', place: 'Vuosaaren halli', lat: 60.2085, lng: 25.1476, max_participants: 4 });
      await h.from('events').insert({ activity_id: 'juoksu', title: 'Keskustan lenkki', starts_at: d(2), city: 'Helsinki', district: 'Kamppi', place: 'Kamppi', lat: 60.1685, lng: 24.931, max_participants: 10 });
      await h.from('events').insert({ activity_id: 'kahvi', title: 'Kahvit Kalliossa', starts_at: d(3), city: 'Helsinki', district: 'Kallio', place: 'Karhupuisto', lat: 60.1834, lng: 24.9500, max_participants: 6 });
      await h.from('events').insert({ activity_id: 'lautapelit', title: 'Brädspel på Söder', starts_at: d(2), city: 'Stockholm', district: 'Södermalm', place: 'Medborgarplatsen', lat: 59.3143, lng: 18.0735, max_participants: 6 });
    });
    await p.reload();
    return { c, p };
  };
  const KALLIO = [60.1836, 24.9565];
  {
    const { c, p } = await geoPage(KALLIO, 'prompt');
    await p.waitForSelector('#landing #land-locate'); await p.waitForTimeout(300);
    ok(await p.evaluate(() => window.__geoCalls) === 0, 'location is not requested before the user taps (permission not yet granted)');
    await p.click('#land-locate'); await p.waitForSelector('#s-home.active .card');
    const st = await p.evaluate(() => ({ city: window.__molaplan.state.user.city, district: window.__molaplan.state.user.district, pref: JSON.parse(localStorage.getItem('molaplan.guest')), here: JSON.parse(localStorage.getItem('molaplan.here')) }));
    ok(st.city === 'Helsinki' && ['Kallio', 'Linjat', 'Torkkelinmäki', 'Siltasaari', 'Harju'].includes(st.district) && st.pref.city === 'Helsinki' && st.pref.near === true && Math.abs(st.here.lat - KALLIO[0]) < 1e-6, `location success -> nearest supported city + district chosen and remembered (${st.city} / ${st.district})`);
    const titles = await p.$$eval('#s-home .card h3', x => x.map(e => e.textContent));
    // GitHub 2026-09-26 removed the city scoping ("Remove city restrictions"): other cities' events come last, sorted by distance
    ok(titles.join('|') === 'Kahvit Kalliossa|Keskustan lenkki|Kaukana Vuosaaressa|Brädspel på Söder', 'near-me feed shows ALL upcoming events sorted by distance (not by activity or date): ' + titles.join(', '));
    const km = await p.$$eval('#s-home .card .dist-pill', x => x.map(e => e.textContent.replace(/\s/g, ' ')));
    ok(km.length === 3 && /^0,\d km$/.test(km[0]) && /^\d+(,\d)? km$/.test(km[2]) && parseFloat(km[0].replace(',', '.')) < parseFloat(km[1].replace(',', '.')), 'distance shown on event cards ("' + km.join('", "') + '")');
    ok(await p.isVisible('#near-note') && await p.evaluate(() => document.querySelector('#s-home .act-filter-item.on').dataset.v === 'all'), 'feed says "Lähimmät ensin"; activity filter stays "Kaikki"');
    await p.click('#vt-map'); await p.waitForSelector('#s-map.active'); await p.waitForTimeout(700);
    const mc = await p.evaluate(() => ({ c: window.__molaplan.mapCenter(), me: !!document.querySelector('#s-map .me-dot') }));
    ok(mc.me && Math.abs(mc.c.lat - KALLIO[0]) < 0.005 && Math.abs(mc.c.lng - KALLIO[1]) < 0.01, `map shows "you are here" and is centred on the user (${mc.c.lat.toFixed(4)}, ${mc.c.lng.toFixed(4)})`);
    await p.click('#vt-list-m'); await p.waitForSelector('#s-home.active .card');
    ok(true, 'List/Map toggle switches back to the list');
    await p.reload(); await p.waitForSelector('#s-home.active .card');
    ok(!(await p.$('#landing')) && await p.evaluate(() => window.__geoCalls) === 0 && (await p.textContent('#s-home .card h3')) === 'Kahvit Kalliossa', 'choice remembered: next visit opens the near-me feed directly, without prompting again');
    await p.click('#guest-city'); await p.waitForSelector('#landing #land-city');
    ok(await p.isVisible('#land-locate') && await p.isVisible('#land-city'), '"Vaihda aluetta" opens the area picker (with "Näytä lähelläni" still available)');
    await c.close();
  }
  {
    const { c, p } = await geoPage(null, 'prompt');
    await p.waitForSelector('#landing #land-locate'); await p.click('#land-locate');
    await p.waitForSelector('#land-msg:not([hidden])');
    ok((await p.textContent('#land-msg')).includes('Sijaintia ei saatu') && await p.isVisible('#land-city') && await p.isVisible('#land-go') && !(await p.evaluate(() => localStorage.getItem('molaplan.guest'))), 'location denied -> friendly note + manual city/area picker');
    await p.selectOption('#land-city', 'Stockholm'); await p.selectOption('#land-district', 'Södermalm'); await p.click('#land-go'); await p.waitForSelector('#s-home.active .card');
    ok((await p.textContent('#s-home')).includes('Brädspel på Söder') && !(await p.$('#s-home .dist-pill')), 'manual choice after denial works (Stockholm / Södermalm), no distances without location');
    await c.close();
  }
  {
    const { c, p } = await geoPage([35.6812, 139.7671], 'prompt');
    await p.waitForSelector('#landing #land-locate'); await p.click('#land-locate');
    await p.waitForSelector('#land-msg:not([hidden])');
    ok((await p.textContent('#land-msg')).includes('ei ole vielä alueellasi') && await p.isVisible('#land-city'), 'location far from every supported city (> 50 km) -> city picker with a friendly note');
    await c.close();
  }
  {
    const { c, p } = await geoPage([59.3155, 18.072], 'granted');
    await p.waitForSelector('#s-home.active .card', { timeout: 8000 });
    const st = await p.evaluate(() => [window.__molaplan.state.user.city, window.__molaplan.state.user.district]);
    ok(st[0] === 'Stockholm' && (await p.textContent('#s-home .card h3')) === 'Brädspel på Söder', `permission already granted -> location used automatically (${st.join(' / ')})`);
    await c.close();
  }

  ok(errors.length === 0, 'no page/console errors' + (errors.length ? ': ' + errors.join(' | ') : ''));
  console.log(`\nALL PASSED: ${passed} checks`);
  await browser.close();
})().catch(async e => { console.error('✘', e.message, `\n(${passed} checks passed before failure)`); process.exit(1); });
