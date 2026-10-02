/* Molaplan media + groups + sports UI tests (mock, schema.sql section 8):
   - sports: typeahead from the DB list (all languages' names), favourites (stars) first in create form + filter, free-text sport
     -> admin queue "Lajit" -> approved for everyone (with translations), creator notified
   - images: client compression (long edge <= 1600 px, <= 200 kB, webp/jpeg, EXIF/GPS stripped), cover in the create form,
     card, detail and for guests; chat photos (private bucket, signed URLs, members only); report photo / cover -> admin removes
   - chat groups: open (search, nearby, join) and closed (invite, join request via link, approve), moderators, removal,
     realtime chat with photos, anti-ad guard, notifications, guests see nothing
   Start the local server first:  node serve.js 8765     Then:  node test-media.js   (SHOTS=shots -> screenshots, mobile + desktop) */
const { chromium } = require('playwright-core');
const BASE = process.env.URL || 'http://127.0.0.1:8765/index.html';
const ORIGIN = new URL(BASE).origin;
const SHOTS = process.env.SHOTS || null;
let passed = 0;
(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROME || '/usr/bin/google-chrome', args: ['--no-sandbox', '--lang=fi-FI'] });
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: SHOTS ? 2 : 1, isMobile: true, hasTouch: true, locale: 'fi-FI', timezoneId: 'Europe/Helsinki' });
  const page = await ctx.newPage(); global.__pg = page;
  const errors = [];
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  page.on('console', m => { if (m.type() === 'error' && !/tile\.openstreetmap|nominatim|photon|Failed to load resource/.test(m.text())) errors.push('console: ' + m.text()); });
  page.on('dialog', d => d.accept());
  const ok = (c, m) => { if (!c) throw new Error('ASSERT: ' + m); passed++; console.log('✔', m); };
  const M = (fn, ...a) => page.evaluate(fn, ...a);
  const DB = () => M(() => window.__mockSupa.db());
  const uid = e => M(e => window.__mockSupa.userId(e), e);
  const txt = s => page.textContent(s);
  const waitToast = async (re) => { await page.waitForFunction(r => new RegExp(r).test((document.querySelector('#toast') || {}).textContent || ''), re.source, { timeout: 8000 }); };
  const ymd = n => { const d = new Date(Date.now() + n * 864e5); return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); };
  const loginAs = async (email, path) => { await M(e => { localStorage.setItem('molaplan.mock.session', window.__mockSupa.userId(e)); localStorage.setItem('molaplan.lang', 'fi'); }, email); await page.goto('about:blank'); await page.goto((path ? ORIGIN + path : BASE) + '?mock=1'); await page.waitForSelector('#s-home.active .home-top .hdr-actions [data-t="profile"], #s-group.active', { timeout: 10000 }); await page.waitForFunction(() => window.MolaplanApp && window.MolaplanApp.me); await page.waitForTimeout(200); };
  const tab = async t => { await page.click(`#nav [data-t="${t}"]`); await page.waitForSelector(`#s-${t}.active`); };
  const profile = async () => { await page.click('#s-home .hdr-actions [data-t="profile"]'); await page.waitForSelector('#s-profile.active'); };
  const shot = async (name, sel) => { if (!SHOTS) return; await page.waitForTimeout(2600); if (sel) await page.$eval(sel, e => e.scrollIntoView({ block: 'start' })); await page.waitForTimeout(400); await page.screenshot({ path: `${SHOTS}/${name}.png` }); };
  /* a 4032×3024 "camera photo" JPEG with an EXIF APP1 segment carrying GPS tags (made in the page, bytes back to node) */
  const makePhoto = (w, h, hue) => M(async ([w, h, hue]) => {
    const c = document.createElement('canvas'); c.width = w; c.height = h; const g = c.getContext('2d');
    const gr = g.createLinearGradient(0, 0, w, h); gr.addColorStop(0, `hsl(${hue} 70% 55%)`); gr.addColorStop(1, `hsl(${hue + 60} 80% 35%)`); g.fillStyle = gr; g.fillRect(0, 0, w, h);
    for (let i = 0; i < 300; i++) { g.fillStyle = `hsla(${(hue + i * 7) % 360} 80% ${30 + (i % 50)}% / .5)`; g.beginPath(); g.arc((i * 997) % w, (i * 641) % h, 20 + (i % 9) * 30, 0, 7); g.fill(); }
    const id = g.getImageData(0, 0, w, h); for (let i = 0; i < id.data.length; i += 4) { const n = (Math.random() - .5) * 26; id.data[i] += n; id.data[i + 1] += n; id.data[i + 2] += n; } g.putImageData(id, 0, 0);
    const b = await new Promise(r => c.toBlob(r, 'image/jpeg', 0.95)); const u8 = new Uint8Array(await b.arrayBuffer());
    const exif = new TextEncoder().encode('Exif\0\0MM\0*GPSLatitude 60.1699 GPSLongitude 24.9384 Make Molaphone');
    const seg = new Uint8Array(4 + exif.length); seg[0] = 0xFF; seg[1] = 0xE1; seg[2] = (exif.length + 2) >> 8; seg[3] = (exif.length + 2) & 255; seg.set(exif, 4);
    const out = new Uint8Array(u8.length + seg.length); out.set(u8.slice(0, 2)); out.set(seg, 2); out.set(u8.slice(2), 2 + seg.length);
    let s = ''; for (let i = 0; i < out.length; i += 0x8000) s += String.fromCharCode.apply(null, out.subarray(i, i + 0x8000)); return btoa(s);
  }, [w, h, hue]).then(b64 => Buffer.from(b64, 'base64'));
  /* stored object (data URL in the mock) -> type, bytes, dimensions, metadata markers */
  const inspect = (bucket, path) => M(async ([bucket, path]) => {
    const o = window.__mockSupa.db().storage_objects.find(x => x.bucket_id === bucket && x.name === path); if (!o) return null;
    const bin = atob(o.data.split(',')[1]); const img = new Image(); await new Promise((r, j) => { img.onload = r; img.onerror = j; img.src = o.data; });
    return { mime: o.mime, size: bin.length, w: img.naturalWidth, h: img.naturalHeight, exif: /Exif|GPSLatitude|Molaphone/.test(bin), webp: bin.slice(8, 12) === 'WEBP', jpeg: bin.charCodeAt(0) === 0xFF && bin.charCodeAt(1) === 0xD8 };
  }, [bucket, path]);

  await page.goto(BASE + '?mock=1');
  const evId = await M(async () => { window.__mockSupa.reset(); localStorage.clear(); sessionStorage.clear(); localStorage.setItem('molaplan.lang', 'fi');
    const S = window.__mockSupa;
    S.createUser('aino@example.com', 'Aino', { admin: true });
    S.createUser('tero@example.com', 'Tero');
    S.createUser('olli@example.com', 'Olli');
    S.createUser('uma@example.com', 'Uma');
    const T = S.as('tero@example.com');
    const r = await T.from('events').insert({ activity_id: 'padel', title: 'Padel-ilta Kalasatamassa', starts_at: new Date(Date.now() + 2 * 864e5).toISOString(), city: 'Helsinki', district: 'Kallio', place: 'Padel Areena', lat: 60.187, lng: 24.977, max_participants: 8 }).select().single();
    if (r.error) throw new Error(r.error.message);
    const O = S.as('olli@example.com'); await O.from('event_participants').insert({ event_id: r.data.id, user_id: O.id });
    return r.data.id; });
  const [TERO, OLLI, UMA, AINO] = [await uid('tero@example.com'), await uid('olli@example.com'), await uid('uma@example.com'), await uid('aino@example.com')];

  // ---------- 1. sports: typeahead, favourites, free-text sport ----------
  await loginAs('tero@example.com');
  await tab('create'); await page.waitForSelector('#c-act-q');
  await page.fill('#c-act-q', 'badm'); await page.waitForSelector('#c-act-list:not([hidden]) [data-v="sulkapallo"]');
  ok((await txt('#c-act-list')).includes('Sulkapallo'), 'typeahead: "badm" finds Sulkapallo (matches the English name Badminton too)');
  await page.fill('#c-act-q', 'koripa'); await page.waitForSelector('#c-act-list [data-v="koripallo"]');
  ok(true, 'typeahead: new DB sport "Koripallo" (seeded list) is searchable');
  await page.fill('#c-act-q', 'ajedrez'); await page.waitForSelector('#c-act-list [data-v="shakki"]');
  ok(true, 'typeahead: Spanish name "ajedrez" finds Shakki');
  await page.fill('#c-act-q', 'tenn'); await page.waitForSelector('#c-act-list [data-v="tennis"] .ao-star');
  await page.click('#c-act-list [data-v="tennis"] .ao-star'); await waitToast(/suosikkeihin/);
  await page.waitForFunction(u => (window.__mockSupa.db().profiles.find(p => p.id === u).favs || []).includes('tennis'), TERO, { timeout: 3000 }).catch(() => {});
  ok((await DB()).profiles.find(p => p.id === TERO).favs.includes('tennis'), 'star in the typeahead saves the favourite to profiles.favs');
  await page.keyboard.press('ArrowDown'); await page.keyboard.press('Enter'); await page.waitForTimeout(150);
  ok(await M(() => window.__molaplan.create.act) === 'tennis' && (await txt('#c-act-sel')).includes('Tennis'), 'keyboard ↓ + Enter picks the sport, "Valittu: Tennis" shown');
  ok(await page.$eval('#c-acts .chip[data-v]', e => e.dataset.v) === 'tennis' && (await page.$$('#c-acts .chip[data-v="tennis"] .fav-mark')).length === 1, 'create form: the starred sport is the first chip, marked ★');
  await page.fill('#c-act-q', 'Kyykkä'); await page.waitForSelector('#c-act-list .act-new');
  ok((await txt('#c-act-list .act-new')).includes('Lisää uusi laji: “Kyykkä”'), 'unknown text -> "Lisää uusi laji: “Kyykkä”" option');
  await page.click('#c-act-list .act-new'); await page.waitForSelector('#cs-name');
  ok((await page.inputValue('#cs-name')) === 'Kyykkä', 'new-sport sheet opens with the typed name');
  await page.click('.emoji-grid button >> nth=3'); await page.click('[data-a="cs-add"]'); await waitToast(/ylläpito hyväksyy/);
  let db = await DB(); const kyy = db.activities.find(a => a.name === 'Kyykkä');
  ok(kyy && kyy.status === 'pending' && kyy.created_by === TERO && await M(() => window.__molaplan.create.act) === kyy.id, 'free-text sport stored as pending and selected in the form right away');
  ok((await page.inputValue('#c-act-q')) === '' && (await page.$$('#c-acts .chip[data-v]:not([hidden])')).length > 40, 'after adding, the search is cleared and all sport chips are back');
  ok(db.notifications.some(n => n.user_id === AINO && n.code === 'admin_new_activity'), 'admin notified about the new sport');
  ok((await txt('#c-act-sel')).includes('odottaa hyväksyntää'), 'form shows the sport is waiting for approval');
  // home filter: search + favourites first
  await tab('home'); await page.click('#act-filter-btn-home'); await page.waitForSelector('#act-filter-popup-home:not(.hidden)');
  ok(await page.$eval('#act-filter-popup-home .act-filter-section .afi-row', e => e.dataset.v) === 'tennis', 'filter list: starred sport first');
  await page.fill('#afi-q-home', 'lento'); await page.waitForTimeout(100);
  ok(await page.isVisible('#act-filter-popup-home .afi-row[data-v="lentopallo"]') && !(await page.isVisible('#act-filter-popup-home .afi-row[data-v="padel"]')), 'filter search narrows the sport list');
  await page.click('#act-filter-popup-home .afi-row[data-v="lentopallo"] .afi-star'); await waitToast(/suosikkeihin/);
  await page.waitForFunction(u => (window.__mockSupa.db().profiles.find(p => p.id === u).favs || []).includes('lentopallo'), TERO, { timeout: 3000 }).catch(() => {});
  ok((await DB()).profiles.find(p => p.id === TERO).favs.includes('lentopallo'), 'star in the filter list saves a favourite');
  await page.click('#act-filter-btn-home'); await page.waitForSelector('#act-filter-popup-home.hidden', { state: 'attached' });

  // ---------- 2. cover image: create form -> card, detail, guest, og ----------
  await tab('create'); await page.waitForSelector('#c-cover-pick');
  const photo = await makePhoto(4032, 3024, 20);
  ok(photo.length > 1e6 && photo.includes(Buffer.from('GPSLatitude')), `test photo: ${(photo.length / 1048576).toFixed(1)} MB JPEG with EXIF GPS`);
  await page.setInputFiles('#c-cover-file', { name: 'IMG_2041.jpg', mimeType: 'image/jpeg', buffer: photo });
  await page.waitForSelector('#c-cover-img');
  ok(await M(() => { const c = window.__molaplan.create.coverBlob; return c && c.w === 1600 && c.h === 1200 && c.blob.size <= 200 * 1024 && c.type === 'image/jpeg'; }), 'cover compressed in the browser: 1600×1200, ≤ 200 kB, JPEG (best for link previews)');
  await page.click('#c-acts .chip[data-v="padel"]');
  await page.fill('#c-title', 'Padel-turnaus kavereille'); await page.fill('#c-date', ymd(3)); await page.fill('#c-time', '18:00'); await page.fill('#c-place', 'Padel Areena');
  await page.click('#ck-rule'); await page.click('#c-publish'); await page.waitForSelector('#s-detail.active .d-hero.has-cover #d-cover');
  db = await DB(); const cev = db.events.find(e => e.title === 'Padel-turnaus kavereille');
  ok(cev && /^[0-9a-f-]{36}\/[0-9a-f]{24}\.jpg$/.test(cev.cover_path) && cev.cover_path.startsWith(cev.id + '/'), 'event saved with cover_path <event id>/<random>.jpg');
  let info = await inspect('event-covers', cev.cover_path);
  ok(info && info.jpeg && info.w === 1600 && info.h === 1200 && info.size <= 200 * 1024 && !info.exif, `stored cover: JPEG 1600×1200, ${Math.round(info.size / 1024)} kB, no EXIF/GPS`);
  await shot('mg-m-event-cover');
  await page.click('#s-detail [data-a="back"]'); await tab('home');
  await page.waitForSelector(`#s-home .card[data-id="${cev.id}"] .card-cover img`);
  ok(true, 'home card shows the cover');
  await shot('mg-m-home-cover-card', `#s-home .card[data-id="${cev.id}"]`);
  // detail: change + remove by the host
  await page.click(`#s-home .card[data-id="${cev.id}"]`); await page.waitForSelector('#s-detail.active #d-cover-pick');
  const oldCover = cev.cover_path;
  await page.setInputFiles('#d-cover-file', { name: 'kentta.png', mimeType: 'image/png', buffer: await makePhoto(1200, 2000, 200) }); await waitToast(/Kansikuva tallennettu/);
  db = await DB(); const nc = db.events.find(e => e.id === cev.id).cover_path;
  ok(nc && nc !== oldCover && !db.storage_objects.some(o => o.name === oldCover) && db.storage_objects.some(o => o.name === nc), 'host changes the cover on the event page; the old file is deleted');
  info = await inspect('event-covers', nc); ok(info.h === 1600 && info.w === 960, 'portrait cover scaled to long edge 1600 (960×1600)');
  // another user cannot upload a cover for this event (bucket RLS)
  const foreign = await M(async id => { const U = window.__mockSupa.as('uma@example.com'); const r = await U.storage.from('event-covers').upload(id + '/abcdef123456.jpg', new Blob([new Uint8Array(500)], { type: 'image/jpeg' }), { contentType: 'image/jpeg' }); return r.error && r.error.message; }, cev.id);
  ok(/row-level security/.test(foreign || ''), 'other users cannot upload a cover for someone else’s event');
  const lim = await M(async id => { const T = window.__mockSupa.as('tero@example.com'); const big = await T.storage.from('event-covers').upload(id + '/bigbig123456.jpg', new Blob([new Uint8Array(300 * 1024)], { type: 'image/jpeg' }), { contentType: 'image/jpeg' }); const png = await T.storage.from('event-covers').upload(id + '/pngpng123456.jpg', new Blob([new Uint8Array(500)], { type: 'image/png' }), { contentType: 'image/png' }); return [big.error && big.error.message, png.error && png.error.message]; }, cev.id);
  ok(/maximum allowed size/.test(lim[0]) && /not supported/.test(lim[1]), 'bucket limits: > 256 kB and non-webp/jpeg types rejected');

  // ---------- 3. chat photo (event chat, private bucket) ----------
  await loginAs('olli@example.com');
  await page.click(`#s-home .card[data-id="${evId}"]`); await page.waitForSelector('#s-detail.active');
  await page.click('#s-detail [data-a="open-chat"]'); await page.waitForSelector('#s-chat.active #cv-img');
  await page.fill('#cv-in', 'Kenttä 3 on varattu meille 🎾');
  await page.setInputFiles('#cv-file', { name: 'IMG_2042.jpg', mimeType: 'image/jpeg', buffer: photo });
  await page.waitForFunction(() => window.__mockSupa.db().messages.some(m => m.image_path), null, { timeout: 15000 });
  db = await DB(); const im = db.messages.find(m => m.image_path);
  ok(im.sender_id === OLLI && im.body === 'Kenttä 3 on varattu meille 🎾' && im.image_w === 1600 && im.image_h === 1200 && im.image_path.startsWith(db.conversations.find(c => c.event_id === evId).id + '/'), 'participant sends a photo with caption; path = <conversation id>/…');
  info = await inspect('chat-images', im.image_path);
  ok(info.webp && info.mime === 'image/webp' && info.size <= 200 * 1024 && Math.max(info.w, info.h) === 1600 && !info.exif, `chat photo: WebP ${info.w}×${info.h}, ${Math.round(info.size / 1024)} kB, EXIF/GPS stripped`);
  await page.waitForSelector('#cv-msgs .bub.has-img .ph img[src]'); ok((await page.inputValue('#cv-in')) === '', 'photo bubble shown, caption input cleared');
  ok(await M(() => { const b = document.querySelector('#cv-msgs .bub.has-img').getBoundingClientRect(), p = document.querySelector('#cv-msgs .bub.has-img .ph').getBoundingClientRect(); return b.right <= innerWidth && b.left >= 0 && p.right <= b.right + 0.5 && p.left >= b.left - 0.5; }), 'photo bubble fits the phone screen (image inside the bubble)');
  await shot('mg-m-chat-photo');
  ok(await M(async p => { const U = window.__mockSupa.as('uma@example.com'); const r = await U.storage.from('chat-images').createSignedUrls([p], 60); return !r.data[0].signedUrl; }, im.image_path), 'outsider cannot get a signed URL for the chat photo');
  ok(await M(async cid => { const U = window.__mockSupa.as('uma@example.com'); const r = await U.storage.from('chat-images').upload(cid + '/abcdef123456.webp', new Blob([new Uint8Array(100)], { type: 'image/webp' }), { contentType: 'image/webp' }); return /row-level security/.test(r.error && r.error.message); }, im.image_path.split('/')[0]), 'outsider cannot upload into the event chat');
  // host sees it via a signed URL, reports nothing; Uma (outsider) gets no chat
  await loginAs('tero@example.com');
  await page.click(`#s-home .card[data-id="${evId}"]`); await page.click('#s-detail [data-a="open-chat"]'); await page.waitForSelector('#s-chat.active #cv-msgs .ph img[src^="data:image/webp"]');
  ok((await DB()).calls.some(c => c.fn === 'sign' && c.bucket === 'chat-images'), 'host loads the photo through a signed URL');
  await page.click('#cv-msgs .ph'); await page.waitForSelector('#img-sheet #img-report');
  ok(!(await page.$('#img-del')), 'photo viewer: others can report but not delete');
  await page.click('#img-report'); await page.waitForSelector('#rep-sheet'); await page.click('#rep-r-inappropriate'); await page.fill('#rep-note', 'Ei kuulu tänne'); await page.click('#rep-send'); await waitToast(/Kiitos/);
  db = await DB(); ok(db.reports.some(r => r.target_type === 'message' && r.target_id === im.id && r.reporter_id === TERO), 'photo reported (target_type message)');
  // Olli reports the cover of Tero's tournament
  await loginAs('olli@example.com');
  await page.click(`#s-home .card[data-id="${cev.id}"]`); await page.waitForSelector('#s-detail.active #d-cover-report');
  await page.click('#d-cover-report'); await page.waitForSelector('#rep-sheet'); await page.click('#rep-send'); await waitToast(/Kiitos/);
  ok((await DB()).reports.some(r => r.target_type === 'event_cover' && r.target_id === cev.id), 'cover reported (target_type event_cover)');
  // ---------- 4. admin: remove reported photo + cover, approve sport ----------
  await loginAs('aino@example.com'); await profile(); await page.click('#open-admin'); await page.waitForSelector('#s-admin.active');
  await page.click('#adm-sec-reports'); await page.waitForSelector(`#adm-rep-${im.id} .rep-img img[src]`);
  ok((await txt(`#adm-rep-${im.id}`)).includes('Ei kuulu tänne') && (await txt(`#adm-rep-${im.id}`)).includes('Olli'), 'admin sees the reported photo (signed URL while the report is open), note and sender');
  await shot('mg-m-admin-photo-report');
  await page.click(`#adm-rep-rm-${im.id}`); await waitToast(/Sisältö poistettu/);
  db = await DB(); ok(!db.messages.some(m => m.id === im.id) && !db.storage_objects.some(o => o.name === im.image_path) && db.reports.find(r => r.target_id === im.id).status === 'resolved', 'admin removes it: message + file deleted, report resolved');
  await page.waitForSelector(`#adm-rep-cover-${cev.id}`); await page.click(`#adm-rep-cover-${cev.id} [data-v="rm"]`); await page.waitForFunction(id => window.__mockSupa.db().events.find(e => e.id === id).cover_path === null, cev.id, { timeout: 6000 }).catch(() => {});
  db = await DB(); ok(db.events.find(e => e.id === cev.id).cover_path === null && !db.storage_objects.some(o => o.bucket_id === 'event-covers' && o.name === nc), 'admin removes the reported cover (column + file)');
  await page.click('#adm-sec-acts'); await page.waitForSelector(`#adm-act-${kyy.id}`);
  ok((await txt('#adm-sec-acts')).includes('1') && (await txt(`#adm-act-${kyy.id}`)).includes('Tero'), 'admin "Lajit" tab: pending sport with count + suggester');
  await shot('mg-m-admin-sports');
  await page.fill(`#an-${kyy.id}-en`, 'Kyykkä (Finnish skittles)'); await page.fill(`#an-${kyy.id}-es`, 'Kyykkä (bolos finlandeses)');
  await page.click(`#adm-act-ok-${kyy.id}`); await waitToast(/lisättiin kaikkien lajilistaan/);
  db = await DB(); const kyy2 = db.activities.find(a => a.id === kyy.id);
  ok(kyy2.status === 'approved' && kyy2.name_i18n.en === 'Kyykkä (Finnish skittles)' && db.notifications.some(n => n.user_id === TERO && n.code === 'activity_approved'), 'approved with translations; suggester notified');
  await loginAs('uma@example.com'); await tab('create'); await page.fill('#c-act-q', 'kyyk'); await page.waitForSelector(`#c-act-list [data-v="${kyy.id}"]`);
  ok(true, 'approved sport is now in everyone’s typeahead');
  await page.goto(BASE + '?mock=1&lang=en'); await page.waitForSelector('#s-home.active'); await tab('create'); await page.fill('#c-act-q', 'skittles'); await page.waitForSelector(`#c-act-list [data-v="${kyy.id}"]`);
  ok((await txt(`#c-act-list [data-v="${kyy.id}"]`)).includes('Finnish skittles'), 'English UI shows the admin’s English name');
  await page.goto(BASE + '?mock=1&lang=fi'); await page.waitForSelector('#s-home.active'); await page.waitForTimeout(400);

  // ---------- 5. groups: open group ----------
  await loginAs('olli@example.com'); await tab('chats'); await page.click('#chat-seg-groups'); await page.waitForSelector('#grp-new');
  ok(await page.isVisible('#grp-empty'), 'no groups nearby yet -> friendly empty state');
  await page.click('#grp-new'); await page.waitForSelector('#gr-name');
  await page.fill('#gr-name', 'Kallion padelporukka'); await page.fill('#gr-desc', 'Pelataan padelia viikoittain, kaikki tasot tervetulleita!'); await page.selectOption('#gr-act', 'padel');
  await page.fill('#gr-desc', 'Mailat -20 % kaupastamme'); await page.waitForSelector('#gr-adwarn:not([hidden])');
  ok(true, 'group form: live anti-ad warning');
  await page.fill('#gr-desc', 'Pelataan padelia viikoittain, kaikki tasot tervetulleita!');
  await shot('mg-m-group-create');
  await page.click('#gr-save'); await page.waitForSelector('#s-group.active #grp-chat');
  db = await DB(); const gOpen = db.groups.find(g => g.name === 'Kallion padelporukka');
  ok(gOpen && gOpen.visibility === 'open' && gOpen.city === 'Helsinki' && db.group_members.some(m => m.group_id === gOpen.id && m.user_id === OLLI && m.role === 'founder'), 'open group created, Olli = founder');
  ok((await txt('#grp-actions')).includes('perustaja'), 'group page: founder tools explained');
  // Uma finds it nearby and by search, joins, chats
  await loginAs('uma@example.com'); await tab('chats'); await page.click('#chat-seg-groups'); await page.waitForSelector(`#grp-sec-near + .chat-list #grp-row-${gOpen.id}`);
  ok((await txt('#grp-sec-near')).includes('Lähellä'), 'open group listed "Lähellä · Helsinki"');
  await page.fill('#grp-q', 'padel'); await page.waitForSelector(`#grp-row-${gOpen.id}`); await page.fill('#grp-q', 'xyz'); await page.waitForSelector('#grp-empty');
  ok((await txt('#grp-empty')).includes('Ei ryhmiä haulla'), 'search: matches by sport, empty state for no match');
  await page.fill('#grp-q', 'kallion'); await page.click(`#grp-row-${gOpen.id}`); await page.waitForSelector('#s-group.active #grp-join');
  ok(!(await page.$('#grp-members')), 'non-member sees no member list');
  await page.click('#grp-join'); await waitToast(/Tervetuloa ryhmään/); await page.waitForSelector('#grp-chat');
  db = await DB(); ok(db.group_members.some(m => m.group_id === gOpen.id && m.user_id === UMA && m.role === 'member') && db.notifications.some(n => n.user_id === OLLI && n.code === 'group_member_joined'), 'Uma joins; founder notified');
  await page.click('#grp-chat'); await page.waitForSelector('#s-chat.active #cv-img');
  await page.fill('#cv-in', 'Myyn mailoja, soita 040 123 4567'); await page.press('#cv-in', 'Enter'); await waitToast(/Ryhmächatit ovat yhteisöä varten/);
  ok((await page.inputValue('#cv-in')).includes('Myyn mailoja') && !(await DB()).messages.some(m => /Myyn mailoja/.test(m.body)), 'anti-ad guard in group chat: not sent, text kept for editing');
  ok(await M(async cid => { const U = window.__mockSupa.as('uma@example.com'); const r = await U.from('messages').insert({ conversation_id: cid, body: 'www.mailakauppa.fi' }); return r.error && r.error.message === 'commercial_content'; }, (await DB()).conversations.find(c => c.group_id === gOpen.id).id), 'server guard: commercial_content for group chat messages');
  await page.fill('#cv-in', 'Moikka! Pelaan torstaisin 🎾'); await page.press('#cv-in', 'Enter');
  await page.waitForFunction(() => window.__mockSupa.db().messages.some(m => m.body === 'Moikka! Pelaan torstaisin 🎾'));
  await page.setInputFiles('#cv-file', { name: 'maila.jpg', mimeType: 'image/jpeg', buffer: await makePhoto(2400, 1800, 120) });
  await page.waitForFunction(id => window.__mockSupa.db().messages.some(m => m.image_path && m.image_path.startsWith(id)), (await DB()).conversations.find(c => c.group_id === gOpen.id).id, { timeout: 15000 });
  ok(true, 'member sends text + photo in the group chat');
  // realtime: Olli has the chat open and receives Uma's message live
  await loginAs('olli@example.com'); await tab('chats'); await page.click('#chat-seg-groups'); await page.waitForSelector(`#grp-sec-mine + .chat-list #grp-row-${gOpen.id}`);
  ok((await txt(`#grp-row-${gOpen.id}`)).includes('2 jäsentä'), 'my groups list: member count');
  await page.click(`#grp-row-${gOpen.id}`); await page.click('#grp-chat'); await page.waitForSelector('#s-chat.active #cv-msgs .ph img[src]');
  await M(async cid => { await window.__mockSupa.as('uma@example.com').from('messages').insert({ conversation_id: cid, body: 'Nähdään kentällä!' }); }, (await DB()).conversations.find(c => c.group_id === gOpen.id).id);
  await page.waitForFunction(() => /Nähdään kentällä!/.test(document.querySelector('#cv-msgs').textContent));
  ok(true, 'realtime: new group message appears without reload');
  await shot('mg-m-group-chat');

  // ---------- 6. closed group: invite, moderator, join request via link, removal ----------
  await page.click('#s-chat [data-a="back"]'); await page.click('#s-group [data-a="back"]').catch(() => {});
  await tab('chats'); await page.click('#chat-seg-groups'); await page.click('#grp-new'); await page.waitForSelector('#gr-name');
  await page.fill('#gr-name', 'Torstain tuplat'); await page.click('#gr-vis-closed');
  ok((await txt('#gr-vis-hint')).includes('ei näy haussa'), 'closed option explained');
  await page.click('#gr-save'); await page.waitForSelector('#s-group.active #grp-invite');
  db = await DB(); const gC = db.groups.find(g => g.name === 'Torstain tuplat'); ok(gC.visibility === 'closed', 'closed group created');
  await page.click('#grp-invite'); await page.waitForSelector(`#gi-send-${TERO}`);
  await page.click(`#gi-send-${TERO}`); await waitToast(/Kutsu lähetetty/);
  ok((await DB()).notifications.some(n => n.user_id === TERO && n.code === 'group_invite' && n.link_kind === 'group'), 'founder invites Tero (known from the event) -> notification');
  await page.keyboard.press('Escape');
  // Uma: closed group not discoverable; anon sees nothing
  ok(await M(async id => { const r = await window.__mockSupa.as('uma@example.com').from('groups').select('*').eq('id', id); return r.data.length === 0; }, gC.id), 'closed group hidden from outsiders (RLS)');
  ok(await M(async () => { const anon = window.__mockSupa.as('nobody@example.com'); const a = await anon.from('groups_v').select('*'), b = await anon.from('groups').select('*'), c = await anon.from('group_members').select('*'); return !!a.error && !(b.data || []).length && !(c.data || []).length; }), 'guests: groups not readable at all');
  // Tero accepts from the notification
  await loginAs('tero@example.com'); await page.click('#s-home [data-a="open-notifs"]'); await page.waitForSelector('#notif-list');
  await page.click('#notif-list >> text=kutsui sinut ryhmään'); await page.waitForSelector('#s-group.active #grp-accept');
  await shot('mg-m-group-invite');
  await page.click('#grp-accept'); await waitToast(/Tervetuloa ryhmään/);
  ok((await DB()).group_members.some(m => m.group_id === gC.id && m.user_id === TERO), 'Tero accepts the invite -> member of the closed group');
  await loginAs('olli@example.com'); await tab('chats'); await page.click('#chat-seg-groups'); await page.click(`#grp-row-${gC.id}`); await page.waitForSelector(`#grp-role-${TERO}`);
  await page.click(`#grp-role-${TERO}`); await waitToast(/Moderaattori nimitetty/);
  ok((await DB()).group_members.find(m => m.group_id === gC.id && m.user_id === TERO).role === 'moderator', 'founder appoints Tero moderator');
  // Uma opens the shared link /g/<id> -> preview -> join request
  await loginAs('uma@example.com', '/g/' + gC.id); await page.waitForSelector('#s-group.active #grp-request', { timeout: 10000 });
  ok((await txt('#grp-name')) === 'Torstain tuplat' && !(await page.$('#grp-members')), 'shared /g/ link: closed group preview (name, no members/messages)');
  await page.fill('#grp-req-msg', 'Hei! Pelaan tuplia mielelläni.'); await page.click('#grp-request'); await waitToast(/Liittymispyyntö lähetetty/);
  await page.waitForSelector('#grp-req-pending');
  db = await DB(); ok(db.group_join_requests.some(r => r.group_id === gC.id && r.user_id === UMA && r.status === 'pending') && db.notifications.some(n => n.user_id === TERO && n.code === 'group_join_request') && db.notifications.some(n => n.user_id === OLLI && n.code === 'group_join_request'), 'join request stored; founder + moderator notified');
  await loginAs('tero@example.com'); await tab('chats'); await page.click('#chat-seg-groups'); await page.click(`#grp-row-${gC.id}`); await page.waitForSelector(`#grp-req-ok-${UMA}`);
  ok((await txt(`#grp-req-${UMA}`)).includes('Pelaan tuplia'), 'moderator sees the request with its message');
  await shot('mg-m-group-requests', '#grp-mod');
  ok(!(await page.$(`#grp-remove-${UMA}`)) && !(await page.$(`#grp-role-${OLLI}`)), 'moderator has no remove / appoint buttons');
  await page.click(`#grp-req-ok-${UMA}`); await waitToast(/Pyyntö hyväksytty/);
  db = await DB(); ok(db.group_members.some(m => m.group_id === gC.id && m.user_id === UMA) && db.notifications.some(n => n.user_id === UMA && n.code === 'group_request_approved'), 'moderator approves -> Uma member + notified');
  ok(await M(async id => { const r = await window.__mockSupa.as('tero@example.com').rpc('remove_group_member', { p_id: id, p_user: window.__mockSupa.userId('uma@example.com') }); return r.error && r.error.message === 'group_founder_only'; }, gC.id), 'moderator cannot remove members (founder only)');
  await loginAs('olli@example.com'); await tab('chats'); await page.click('#chat-seg-groups'); await page.click(`#grp-row-${gC.id}`); await page.waitForSelector(`#grp-remove-${UMA}`);
  await page.click(`#grp-remove-${UMA}`); await waitToast(/Jäsen poistettu/);
  db = await DB(); const cidC = db.conversations.find(c => c.group_id === gC.id).id;
  ok(!db.group_members.some(m => m.group_id === gC.id && m.user_id === UMA) && db.notifications.some(n => n.user_id === UMA && n.code === 'group_removed'), 'founder removes Uma; Uma notified');
  ok(await M(async cid => { const r = await window.__mockSupa.as('uma@example.com').from('messages').select('*').eq('conversation_id', cid); return r.data.length === 0; }, cidC), 'removed member cannot read the chat');
  await shot('mg-m-group-members', '#grp-members');
  // report a group
  await loginAs('uma@example.com'); await tab('chats'); await page.click('#chat-seg-groups'); await page.click(`#grp-row-${gOpen.id}`); await page.waitForSelector('#grp-report');
  await page.click('#grp-report'); await page.waitForSelector('#rep-sheet'); await page.click('#rep-r-spam'); await page.click('#rep-send'); await waitToast(/Kiitos/);
  ok((await DB()).reports.some(r => r.target_type === 'group' && r.target_id === gOpen.id), 'group reported');
  // guest opens a group link -> asked to log in, nothing loaded
  await M(() => { localStorage.removeItem('molaplan.mock.session'); localStorage.setItem('molaplan.guest', JSON.stringify({ city: 'Helsinki', district: 'Kallio' })); });
  await page.goto('about:blank'); await page.goto(ORIGIN + '/g/' + gOpen.id + '?mock=1'); await page.waitForSelector('#auth-prompt, #s-auth.active, #au-email', { timeout: 8000 }).catch(() => {});
  ok(await M(() => !document.querySelector('#s-group.active #grp-name')) && await M(() => location.pathname === '/'), 'guest with a group link: login prompt, no group data');

  // ---------- 7. desktop screenshots ----------
  if (SHOTS) {
    await page.setViewportSize({ width: 1440, height: 900 });
    await loginAs('olli@example.com'); await page.waitForTimeout(500);
    await page.click(`#s-home .card[data-id="${evId}"]`).catch(() => {}); await page.waitForTimeout(300);
    await page.screenshot({ path: `${SHOTS}/mg-d1440-home.png` });
    await page.goto(BASE + '?mock=1'); await page.waitForSelector('#s-home.active');
    await page.click('#nav [data-t="chats"]'); await page.click('#chat-seg-groups'); await page.waitForTimeout(400); await page.screenshot({ path: `${SHOTS}/mg-d1440-groups.png` });
    await page.click(`#grp-row-${gOpen.id}`); await page.click('#grp-chat'); await page.waitForSelector('#cv-msgs .ph img[src]'); await page.waitForTimeout(500); await page.screenshot({ path: `${SHOTS}/mg-d1440-group-chat.png` });
    await page.click('#nav [data-t="create"]').catch(() => {}); await page.waitForSelector('#c-act-q'); await page.fill('#c-act-q', 'pa'); await page.waitForTimeout(300); await page.screenshot({ path: `${SHOTS}/mg-d1440-create-typeahead.png` });
  }
  ok(!errors.length, 'no page/console errors' + (errors.length ? ': ' + errors.slice(0, 3).join(' | ') : ''));
  await browser.close();
  console.log(`\nALL PASSED: ${passed} checks`);
})().catch(async e => { console.error('FAILED after', passed, 'checks:', e.message.split('\n').slice(0, 14).join(' / ')); try { await (global.__pg && global.__pg.screenshot({ path: '/tmp/test-media-fail.png' })); } catch (x) {} process.exit(1); });
