/* Molaplan business/team account entry + team account REQUEST flow (mock): discoverable entry points
   (landing, home, profile), guest → sign up, request form validation, RLS, admin queue approve / reject,
   requester notifications. No payment is involved.
   Start a static server first:  python3 -m http.server 8765 --bind 127.0.0.1     Then:  node test-teams.js */
const { chromium } = require('playwright-core');
const BASE = process.env.URL || 'http://127.0.0.1:8765/index.html';
let passed = 0;
(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROME || '/usr/bin/google-chrome', args: ['--no-sandbox', '--lang=fi-FI'] });
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, locale: 'fi-FI', timezoneId: 'Europe/Helsinki' });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  page.on('console', m => { if (m.type() === 'error' && !/tile\.openstreetmap|nominatim|Failed to load resource/.test(m.text())) errors.push('console: ' + m.text()); });
  page.on('dialog', d => d.accept());
  const ok = (c, m) => { if (!c) throw new Error('ASSERT: ' + m); passed++; console.log('✔', m); };
  const M = (fn, ...a) => page.evaluate(fn, ...a);
  const DB = () => M(() => window.__mockSupa.db());
  const uid = e => M(e => window.__mockSupa.userId(e), e);
  const txt = s => page.textContent(s);
  const waitToast = async (re) => { await page.waitForFunction(r => new RegExp(r).test((document.querySelector('#toast') || {}).textContent || ''), re.source, { timeout: 6000 }); };
  const profile = async () => { await page.click('#s-home .hdr-actions [data-t="profile"]'); await page.waitForSelector('#s-profile.active'); };
  const loginAs = async (email) => { await M(e => { localStorage.setItem('molaplan.mock.session', window.__mockSupa.userId(e)); localStorage.setItem('molaplan.lang', 'fi'); }, email); await page.goto('about:blank'); await page.goto(BASE + '?mock=1'); await page.waitForSelector('#s-home.active .home-top .hdr-actions [data-t="profile"]', { timeout: 10000 }); await page.waitForFunction(() => window.MolaplanApp && window.MolaplanApp.me); };
  const fill = async (o) => { for (const [k, v] of Object.entries(o)) await page.fill('#' + k, v); };

  await page.goto(BASE + '?mock=1');
  await M(() => { window.__mockSupa.reset(); localStorage.clear(); sessionStorage.clear(); localStorage.setItem('molaplan.lang', 'fi');
    const S = window.__mockSupa;
    S.createUser('aino@example.com', 'Aino', { admin: true, phone: '+358401111111' });
    S.createUser('tero@example.com', 'Tero Valmentaja', { phone: '+358402222222' });
    S.createUser('olli@example.com', 'Olli', {});
    S.createUser('uuno@example.com', 'Uuno', { confirmed: false }); });
  await page.reload();

  // ---------- 1. guest: landing entry → options → team request needs an account ----------
  await page.waitForSelector('#land-orgs').catch(async e => { await page.screenshot({ path: '/tmp/tt-fail.png' }); console.log(await M(() => document.body.innerText.slice(0, 400))); throw e; });
  ok((await txt('#land-orgs')).includes('Avaa tili yritykselle tai joukkueelle'), 'landing shows "Avaa tili yritykselle tai joukkueelle"');
  await page.click('#land-orgs-btn'); await page.waitForSelector('#s-orgs.active #org-team');
  ok(await page.isVisible('#org-biz') && (await txt('#org-biz')).includes('49 € / kk + ALV') && (await txt('#org-team')).includes('Joukkuetili'), 'options screen: business account (with existing price) + team account');
  ok(!/10 €|€ \/ kk/.test(await txt('#org-team')), 'team option has no price text');
  await page.click('#org-team'); await page.waitForSelector('#s-teamreq.active #tr-guest-signup');
  ok(!(await page.$('#tr-form')), 'guest sees "Luo ensin oma tili" instead of the form');
  await page.click('#tr-guest-signup'); await page.waitForTimeout(300);
  ok(await M(() => (sessionStorage.getItem('molaplan.pending') || '').includes('team-req') && !!document.querySelector('#au-email')), 'guest sign-up remembers to come back to the team request');
  await M(() => sessionStorage.clear());

  // ---------- 2. logged in: home + profile entry, validation, submit ----------
  await loginAs('tero@example.com');
  ok(await page.isVisible('#home-orgs'), 'home feed has the business/team account entry card');
  await page.click('#home-orgs'); await page.waitForSelector('#s-orgs.active');
  await page.click('#s-orgs [data-a="back"]'); await page.waitForSelector('#s-home.active');
  await profile(); ok((await txt('#p-biz')).includes('Yritys- tai joukkuetili'), 'profile card "Yritys- tai joukkuetili"');
  await page.click('#open-orgs'); await page.waitForSelector('#s-orgs.active'); await page.click('#org-team'); await page.waitForSelector('#s-teamreq.active #tr-form');
  ok((await page.inputValue('#tr-email')) === 'tero@example.com' && (await page.inputValue('#tr-cname')) === 'Tero Valmentaja', 'contact name + email prefilled');
  ok(!(await page.$('#tr-verify')), 'verified user sees no verification notice');
  await page.click('#tr-submit'); await waitToast(/Kirjoita joukkueen nimi/);
  ok((await DB()).team_requests.length === 0 && await page.$eval('#tr-name', e => e.classList.contains('err')), 'empty form: friendly error, nothing stored');
  await fill({ 'tr-name': 'FC Kaislikko', 'tr-sport': 'Jalkapallo', 'tr-city': 'Tuusula', 'tr-desc': 'Harrastejoukkue, 18 pelaajaa, treenit Hyrylässä.', 'tr-phone': '+358 40 222 2222' });
  await page.click('#tr-submit'); await waitToast(/Kiitos! Pyyntö on lähetetty/);
  let db = await DB(); const TERO = await uid('tero@example.com'), AINO = await uid('aino@example.com');
  const r1 = db.team_requests[0];
  ok(db.team_requests.length === 1 && r1.status === 'pending' && r1.requester_id === TERO && r1.team_name === 'FC Kaislikko' && r1.city === 'Tuusula' && r1.contact_phone === '+358 40 222 2222', 'request stored as pending with the details');
  ok(db.notifications.some(n => n.user_id === AINO && n.code === 'admin_new_team_request' && n.link_kind === 'admin' && n.link_id === r1.id), 'admins notified (admin_new_team_request)');
  await page.waitForSelector('#tr-mine #my-tr-' + r1.id);
  ok((await txt('#my-tr-' + r1.id)).includes('Odottaa käsittelyä') && !(await page.$('#tr-form')) && await page.isVisible('#tr-form-open'), 'own request listed "Odottaa käsittelyä"; form collapses behind "Uusi pyyntö toiselle joukkueelle"');
  // a second request (rejected later)
  await page.click('#tr-form-open'); await page.waitForSelector('#tr-form');
  await fill({ 'tr-name': 'Kaislikon Ikimiehet', 'tr-sport': 'Salibandy', 'tr-city': 'Helsinki' });
  await page.click('#tr-submit'); await page.waitForFunction(() => window.__mockSupa.db().team_requests.length === 2, null, { timeout: 6000 });
  db = await DB(); const r2 = db.team_requests.find(r => r.team_name === 'Kaislikon Ikimiehet');
  ok(!!r2 && r2.status === 'pending', 'second request stored');

  // ---------- 3. RLS ----------
  const rls = await M(async () => { const S = window.__mockSupa, O = S.as('olli@example.com'), T = S.as('tero@example.com');
    const seen = (await O.from('team_requests').select('*')).data || [];
    const own = (await T.from('team_requests').select('*')).data || [];
    const ins = await O.from('team_requests').insert({ team_name: 'X', sport: 'Y', city: 'Z', contact_name: 'Olli', contact_email: 'o@example.com' });
    const rev = await O.rpc('admin_review_team_request', { p_id: own[0] && own[0].id, p_status: 'approved' });
    const unv = await S.as('uuno@example.com').rpc('request_team_account', { req: { team_name: 'Uunon tiimi', sport: 'Futis', city: 'Espoo', contact_name: 'Uuno', contact_email: 'uuno@example.com' } });
    return { seen: seen.length, own: own.length, ins: !!ins.error, rev: rev.error && rev.error.message, unv: unv.error && unv.error.message }; });
  ok(rls.seen === 0 && rls.own === 2, 'other users cannot read team requests; the requester sees their own');
  ok(rls.ins && /admin_only/.test(rls.rev || ''), 'direct inserts denied; non-admins cannot review');
  ok(/email_not_verified/.test(rls.unv || ''), 'unverified accounts cannot send a request');

  // ---------- 4. admin: queue, approve, reject with reason ----------
  await loginAs('aino@example.com'); await profile(); await page.click('#open-admin'); await page.waitForSelector('#s-admin.active #adm-sec-teams');
  ok((await txt('#adm-sec-teams')).includes('2'), 'admin "Joukkueet" tab shows the pending count');
  await page.click('#adm-sec-teams'); await page.waitForSelector('#adm-tr-' + r1.id);
  const card = await txt('#adm-tr-' + r1.id);
  ok(card.includes('FC Kaislikko') && card.includes('Jalkapallo') && card.includes('tero@example.com') && card.includes('Tero Valmentaja'), 'queue card shows team, sport, contact and requester');
  await page.click('#adm-tr-ok-' + r1.id); await waitToast(/Hyväksytty/);
  db = await DB();
  ok(db.team_requests.find(r => r.id === r1.id).status === 'approved' && db.notifications.some(n => n.user_id === TERO && n.code === 'team_request_approved' && n.link_kind === 'team'), 'approve: stored + requester notified');
  await page.click('#adm-tr-no-' + r2.id); await page.waitForSelector('#reason-txt');
  await page.click('#reason-ok'); await page.waitForTimeout(200);
  ok((await DB()).team_requests.find(r => r.id === r2.id).status === 'pending', 'reject needs a reason');
  await page.click('[data-a="reason-preset"]:has-text("Joukkueella on jo tili")'); await page.click('#reason-ok'); await page.waitForFunction(id => window.__mockSupa.db().team_requests.find(r => r.id === id).status === 'rejected', r2.id, { timeout: 6000 });
  db = await DB(); const x2 = db.team_requests.find(r => r.id === r2.id);
  ok(x2.status === 'rejected' && x2.admin_reason === 'Joukkueella on jo tili' && db.notifications.some(n => n.user_id === TERO && n.code === 'team_request_rejected'), 'reject: stored with reason + requester notified');
  await page.waitForSelector('#adm-tr-' + r2.id + ' .req-msg.bad');
  ok(!(await page.$('#adm-tr-ok-' + r1.id)), 'reviewed requests have no action buttons');

  // ---------- 5. requester sees the outcome ----------
  await loginAs('tero@example.com');
  ok(await M(() => window.__molaplan.state.notifs.some(n => /FC Kaislikko/.test(n.text) && /hyväksyttiin/.test(n.text))), 'notification text: "Joukkuetilipyyntö “FC Kaislikko” hyväksyttiin 🎉"');
  await page.click('#s-home [data-a="open-notifs"]'); await page.waitForSelector('#notif-list');
  const n1 = await M(() => window.__molaplan.state.notifs.find(n => /hyväksyttiin/.test(n.text)).id);
  await page.click(`#notif-list [data-id="${n1}"]`); await page.waitForSelector('#s-teamreq.active #tr-mine');
  const mine = await txt('#tr-mine');
  ok(mine.includes('Hyväksytty – otamme yhteyttä') && mine.includes('Ei hyväksytty') && mine.includes('Joukkueella on jo tili'), 'tapping the notification opens the request screen with both outcomes');

  // ---------- 6. unverified user gets a clear notice ----------
  await loginAs('uuno@example.com'); await profile(); await page.click('#open-orgs'); await page.click('#org-team'); await page.waitForSelector('#s-teamreq.active #tr-form');
  ok(await page.isVisible('#tr-verify'), 'unverified user sees the "verify first" notice');

  ok(errors.length === 0, 'no page/console errors' + (errors.length ? ': ' + errors.join(' | ') : ''));
  console.log(`\nALL PASSED: ${passed} checks`);
  await browser.close();
})().catch(async e => { console.error('✘', e.message, `\n(${passed} checks passed before failure)`); process.exit(1); });
