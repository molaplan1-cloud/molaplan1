/* Molaplan friends + unlimited participants UI tests (mock): friend requests (send / accept / decline / cancel),
   friends list in the profile, inviting a friend to an event, public event without a participant limit.
   Start a static server first:  python3 -m http.server 8765 --bind 127.0.0.1     Then:  node test-friends.js */
const { chromium } = require('playwright-core');
const BASE = process.env.URL || 'http://127.0.0.1:8765/index.html';
const SHOTS = process.env.SHOTS || null; // e.g. SHOTS=shots -> m-friends.png, m-event-unlimited.png (390x844 @2x)
let passed = 0;
(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROME || '/usr/bin/google-chrome', args: ['--no-sandbox', '--lang=fi-FI'] });
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: SHOTS ? 2 : 1, isMobile: true, hasTouch: true, locale: 'fi-FI', timezoneId: 'Europe/Helsinki' });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  page.on('console', m => { if (m.type() === 'error' && !/tile\.openstreetmap|nominatim|Failed to load resource/.test(m.text())) errors.push('console: ' + m.text()); });
  page.on('dialog', d => d.accept());
  const ok = (c, m) => { if (!c) throw new Error('ASSERT: ' + m); passed++; console.log('✔', m); };
  const M = (fn, ...a) => page.evaluate(fn, ...a);
  const DB = () => M(() => window.__mockSupa.db());
  const uid = e => M(e => window.__mockSupa.userId(e), e);
  const waitToast = async (re) => { await page.waitForFunction(r => new RegExp(r).test((document.querySelector('#toast') || {}).textContent || ''), re.source, { timeout: 6000 }); };
  const profile = async () => { await page.click('#s-home .hdr-actions [data-t="profile"]'); await page.waitForSelector('#s-profile.active #fr-card'); };
  const ymd = n => { const d = new Date(Date.now() + n * 864e5); return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); };
  const loginAs = async (email) => { await M(e => { localStorage.setItem('molaplan.mock.session', window.__mockSupa.userId(e)); localStorage.setItem('molaplan.lang', 'fi'); }, email); await page.goto('about:blank'); await page.goto(BASE + '?mock=1'); await page.waitForSelector('#s-home.active .home-top #loc-pill', { timeout: 10000 }); await page.waitForFunction(() => window.MolaplanFriends && window.MolaplanApp && window.MolaplanApp.me); };
  const openEvent = async id => { await page.click(`#s-home .card[data-id="${id}"]`); await page.waitForSelector('#s-detail.active'); await page.waitForTimeout(250); };
  const shot = async (name, sel, block = 'start') => { if (!SHOTS) return; await page.waitForTimeout(2800); /* let toasts fade */ if (sel) await page.$eval(sel, (e, b) => e.scrollIntoView({ block: b }), block); await page.waitForTimeout(400); await page.screenshot({ path: `${SHOTS}/${name}.png` }); console.log('  📸', `${SHOTS}/${name}.png`); };

  // ---------- setup: 4 users, Liisa hosts a board game night, Pekka joins ----------
  await page.goto(BASE + '?mock=1');
  const evId = await M(async () => { window.__mockSupa.reset(); localStorage.clear(); sessionStorage.clear(); localStorage.setItem('molaplan.lang', 'fi');
    const S = window.__mockSupa;
    S.createUser('aino@example.com', 'Aino', { admin: true });
    S.createUser('liisa@example.com', 'Liisa');
    S.createUser('pekka@example.com', 'Pekka');
    S.createUser('matti@example.com', 'Matti');
    const L = S.as('liisa@example.com');
    const r = await L.from('events').insert({ activity_id: 'lautapelit', title: 'Lautapeli-ilta', starts_at: new Date(Date.now() + 2 * 864e5).toISOString(), city: 'Helsinki', district: 'Kallio', place: 'Kallion kirjasto', lat: 60.184, lng: 24.95, max_participants: 6 }).select().single();
    if (r.error) throw new Error(r.error.message);
    const P = S.as('pekka@example.com'); await P.from('event_participants').insert({ event_id: r.data.id, user_id: P.id });
    const Mt = S.as('matti@example.com'); await Mt.from('event_participants').insert({ event_id: r.data.id, user_id: Mt.id });
    return r.data.id; });
  const [LIISA, PEKKA, MATTI] = [await uid('liisa@example.com'), await uid('pekka@example.com'), await uid('matti@example.com')];
  ok(!!evId, 'setup: Liisa hosts "Lautapeli-ilta", Pekka and Matti joined');

  // ---------- 1. send a friend request from the participant list ----------
  await loginAs('pekka@example.com');
  await openEvent(evId);
  ok(await page.isVisible(`#s-detail .prow[data-uid="${LIISA}"] [data-fr="add"]`) && !(await page.$(`#s-detail .prow[data-uid="${PEKKA}"] .fr-btn`)), 'participant rows show "＋ Lisää kaveriksi" for others (not for yourself)');
  await page.click(`#s-detail .prow[data-uid="${LIISA}"] [data-fr="add"]`); await waitToast(/Kaveripyyntö lähetetty/);
  await page.waitForSelector(`#s-detail .prow[data-uid="${LIISA}"] .fr-btn.is-pending`);
  let db = await DB();
  let fr = db.friend_requests.find(r => r.requester_id === PEKKA && r.target_id === LIISA);
  ok(fr && fr.status === 'pending' && fr.event_id === evId, 'request stored as pending (with the event where they met)');
  ok(db.notifications.some(n => n.user_id === LIISA && n.code === 'friend_request' && n.link_kind === 'friend'), 'Liisa gets a "friend_request" notification');
  ok((await page.textContent(`#s-detail .prow[data-uid="${LIISA}"] .fr-btn`)).includes('Pyyntö lähetetty'), 'button turns into "Pyyntö lähetetty"');
  // Matti asks too (server API)
  const mr = await M(async t => (await window.__mockSupa.as('matti@example.com').rpc('send_friend_request', { p_target: t })).data, LIISA);
  ok(mr === 'pending', 'Matti sends a request via RPC');

  // ---------- 2. accept + decline in the profile ----------
  await loginAs('liisa@example.com');
  ok(await M(() => window.__molaplan.state.notifs.some(n => /kaveripyynnön/.test(n.text))), 'notification text rendered for the friend request');
  await profile();
  ok((await page.$$('#fr-incoming .fr-row')).length === 2 && (await page.textContent('#fr-incoming')).includes('Pekka') && (await page.textContent('#fr-incoming')).includes('Matti'), 'profile "Kaverit" card lists 2 incoming requests');
  await page.click(`#fr-incoming .fr-row[data-uid="${PEKKA}"] [data-fr="accept"]`); await waitToast(/kavereita/);
  await page.waitForSelector(`#fr-list .fr-row[data-uid="${PEKKA}"]`);
  ok((await page.textContent('#fr-count')).trim() === '1', 'accepted: Pekka in the friend list (count 1)');
  db = await DB();
  ok(db.friend_requests.find(r => r.requester_id === PEKKA).status === 'accepted' && db.notifications.some(n => n.user_id === PEKKA && n.code === 'friend_accepted'), 'stored as accepted; Pekka notified (friend_accepted)');
  await shot('m-friends', '#fr-card');
  await page.click(`#fr-incoming .fr-row[data-uid="${MATTI}"] [data-fr="decline"]`); await waitToast(/hylätty/);
  await page.waitForFunction(() => !document.querySelector('#fr-incoming'));
  db = await DB();
  ok(db.friend_requests.find(r => r.requester_id === MATTI).status === 'declined' && !db.notifications.some(n => n.user_id === MATTI && n.code === 'friend_accepted'), 'declined: request hidden, Matti not notified');
  const again = await M(async t => (await window.__mockSupa.as('matti@example.com').rpc('send_friend_request', { p_target: t })).error.message, LIISA);
  ok(again === 'friend_request_declined', 'Matti cannot re-send after a decline');

  // ---------- 3. friends list on both sides + detail shows "Kaveri" ----------
  await page.click('#nav [data-t="home"]'); await page.waitForSelector('#s-home.active');
  await openEvent(evId);
  ok((await page.textContent(`#s-detail .prow[data-uid="${PEKKA}"] .fr-btn`)).includes('Kaveri') && await page.isVisible(`#s-detail .prow[data-uid="${MATTI}"] [data-fr="add"]`), 'detail: Pekka marked "Kaveri ✓"; Matti still addable (decline not revealed as friendship)');

  // ---------- 4. invite a friend to an event ----------
  const ev2 = await M(async () => { const r = await window.__mockSupa.as('liisa@example.com').from('events').insert({ activity_id: 'kahvi', title: 'Kahvit Kalliossa', starts_at: new Date(Date.now() + 3 * 864e5).toISOString(), city: 'Helsinki', district: 'Kallio', place: 'Kahvila Sävy', lat: 60.183, lng: 24.951, max_participants: 4 }).select().single(); return r.data.id; });
  await page.click('#s-detail [data-a="back"]');
  await M(() => window.__molaplan.refresh()); await page.waitForSelector(`#s-home .card[data-id="${ev2}"]`);
  await openEvent(ev2);
  await page.click('#fr-invite-open'); await page.waitForSelector('#fr-invite-list');
  ok(await page.isVisible(`#fr-invite-list .fr-row[data-uid="${PEKKA}"] [data-fr="invite"]`) && !(await page.$(`#fr-invite-list .fr-row[data-uid="${MATTI}"]`)), 'invite sheet lists friends only (Pekka), with "Kutsu"');
  await page.click(`#fr-invite-list .fr-row[data-uid="${PEKKA}"] [data-fr="invite"]`); await waitToast(/Kutsu lähetetty/);
  await page.waitForSelector(`#fr-invite-list .fr-row[data-uid="${PEKKA}"] .fr-btn.is-pending`);
  db = await DB();
  ok(db.event_invites.some(i => i.event_id === ev2 && i.inviter_id === LIISA && i.invitee_id === PEKKA) && db.notifications.filter(n => n.user_id === PEKKA && n.code === 'event_invite' && n.link_id === ev2).length === 1, 'invite stored; Pekka notified once (event_invite → event)');
  const notFriend = await M(async ([e, m]) => (await window.__mockSupa.as('liisa@example.com').rpc('invite_friend_to_event', { p_event: e, p_friend: m })).error.message, [ev2, MATTI]);
  ok(notFriend === 'not_friends', 'inviting a non-friend is rejected (server)');
  await page.keyboard.press('Escape').catch(() => {});

  // ---------- 5. Pekka: invite notification, friend list, remove friend ----------
  await loginAs('pekka@example.com');
  ok(await M(t => window.__molaplan.state.notifs.some(n => n.text.includes('kutsui sinut') && n.text.includes(t)), 'Kahvit Kalliossa'), 'Pekka sees "Liisa kutsui sinut tapahtumaan …"');
  await profile();
  ok((await page.textContent('#fr-list')).includes('Liisa'), "Pekka's friend list shows Liisa");
  await page.click(`#fr-list .fr-row[data-uid="${LIISA}"] [data-fr="remove"]`); await waitToast(/Poistettu/);
  await page.waitForSelector('#fr-empty');
  ok(!(await DB()).friend_requests.some(r => r.status === 'accepted'), 'remove friend deletes the friendship');

  // ---------- 6. unlimited participants (public event by admin) ----------
  await loginAs('aino@example.com');
  await page.click('#s-home .hdr-actions [data-t="profile"]'); await page.waitForSelector('#s-profile.active');
  await page.click('#p-new-public'); await page.waitForSelector('#s-create.active #c-org');
  ok(await page.isVisible('#c-nolimit-btn'), 'public event form has "Ei rajaa (∞)"');
  await page.click('#s-create [data-a="c-act"][data-v="juoksutapahtuma"]');
  await page.fill('#c-title', 'Kaupunkijuoksu'); await page.fill('#c-date', ymd(4)); await page.fill('#c-time', '10:00'); await page.fill('#c-edate', ymd(4)); await page.fill('#c-etime', '14:00');
  await page.fill('#c-place', 'Kaisaniemen puisto'); await page.fill('#c-org', 'Helsingin kaupunki'); await page.fill('#c-desc', 'Ilmainen juoksutapahtuma kaikille.');
  await page.click('#c-nolimit-btn');
  ok(await page.isDisabled('#c-maxn') && (await page.getAttribute('#c-nolimit-btn', 'aria-pressed')) === 'true', 'toggle on: number field disabled');
  await page.click('#c-publish'); await page.waitForSelector('#s-detail.active #kind-strip');
  db = await DB();
  const big = db.events.find(e => e.title === 'Kaupunkijuoksu');
  ok(big && big.kind === 'public' && big.max_participants === null, 'stored with max_participants = null');
  ok((await page.textContent('#d-cap')).includes('Ei rajaa'), 'detail shows "Osallistujia enintään: Ei rajaa"');
  await shot('m-event-unlimited', '#d-cap', 'center');
  // 25 people join – never "full"
  const joins = await M(async id => { const S = window.__mockSupa; const errs = []; for (let i = 0; i < 25; i++) { const e = `j${i}@example.com`; S.createUser(e, 'Juoksija ' + i); const r = await S.as(e).from('event_participants').insert({ event_id: id, user_id: S.userId(e) }); if (r.error) errs.push(r.error.message); } return errs; }, big.id);
  ok(!joins.length, '25 participants can join an unlimited event');
  await loginAs('liisa@example.com');
  await shot('m-home', '#s-home .sec-head');
  const card = await page.$eval(`#s-home .card[data-id="${big.id}"]`, e => e.textContent);
  ok(card.includes('Ei rajaa') && !(await page.$(`#s-home .card[data-id="${big.id}"] .btn.full`)) && await page.isVisible(`#s-home .card[data-id="${big.id}"] [data-a="join"]`), 'card shows "∞ Ei rajaa" and stays joinable');
  await page.click(`#s-home .card[data-id="${big.id}"] [data-a="join"]`); await page.waitForTimeout(500);
  ok((await DB()).event_participants.filter(p => p.event_id === big.id).length === 26, 'Liisa joins as the 26th');
  // community events keep the 2–50 limit
  const cm = await M(async () => (await window.__mockSupa.as('liisa@example.com').from('events').insert({ activity_id: 'kahvi', title: 'Rajaton kahvi', starts_at: new Date(Date.now() + 864e5).toISOString(), city: 'Helsinki', place: 'Kallio', max_participants: null })).error);
  ok(cm && /max_participants/.test(cm.message), 'community event with no limit is rejected (2–50 stays)');
  await page.click('#nav [data-t="create"]'); await page.waitForSelector('#s-create.active #c-title');
  ok(!(await page.$('#c-nolimit-btn')), 'normal create form has no "Ei rajaa" toggle');

  ok(!errors.length, 'no console errors' + (errors.length ? ': ' + errors.join(' | ') : ''));
  console.log(`\n${passed} checks passed`);
  await browser.close();
})().catch(async e => { console.error('✘', e.message); console.error(`(${passed} checks passed before failure)`); process.exit(1); });
