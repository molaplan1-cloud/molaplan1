/* Molaplan i18n + cities tests (en / fi / es / sv) – run against the in-memory mock (index.html?mock=1).
   Start a static server first:  python3 -m http.server 8765 --bind 127.0.0.1
   Then:  node test-i18n.js      (screenshots -> shots/v2-en-*, v2-es-*, v2-sv-*) */
const fs = require('fs');
const { chromium } = require('playwright-core');
const SHOTS = __dirname + '/shots/';
const BASE = process.env.URL || 'http://127.0.0.1:8765/index.html';
const LANGS = ['fi', 'en', 'sv', 'es'];
let passed = 0;
const ok = (c, m) => { if (!c) throw new Error('ASSERT: ' + m); passed++; console.log('✔', m); };

// ---------- A. static dictionary checks (node side) ----------
global.window = {}; eval(fs.readFileSync(__dirname + '/i18n.js', 'utf8'));
const D = window.MOLAPLAN_I18N;
global.window = {}; eval(fs.readFileSync(__dirname + '/cities.js', 'utf8'));
const CITIES = window.MOLAPLAN_CITIES;
const html = fs.readFileSync(__dirname + '/index.html', 'utf8');
const schema = fs.readFileSync(__dirname + '/supabase/schema.sql', 'utf8');
const KEYS = Object.keys(D.en);
ok(LANGS.every(l => D[l] && typeof D[l] === 'object'), 'dictionary has all four languages (fi, en, sv, es)');
for (const l of LANGS) {
  const miss = KEYS.filter(k => !(k in D[l])), extra = Object.keys(D[l]).filter(k => !(k in D.en));
  ok(!miss.length && !extra.length, `every key exists in "${l}" (${KEYS.length} keys)` + (miss.length || extra.length ? ' missing: ' + miss.concat(extra).slice(0, 8).join(', ') : ''));
}
const ph = s => (s.match(/\{\w+\}/g) || []).sort().join();
const tags = s => (s.match(/<\/?[a-z]+/g) || []).sort().join();
const badVal = [];
for (const k of KEYS) for (const l of LANGS) { const v = D[l][k]; if (typeof v !== 'string' || !v.trim()) badVal.push(l + ':' + k + ' empty'); else { if (ph(v) !== ph(D.fi[k])) badVal.push(l + ':' + k + ' placeholders'); if (tags(v) !== tags(D.fi[k])) badVal.push(l + ':' + k + ' html'); } }
ok(!badVal.length, 'no empty values; placeholders and HTML tags match across languages' + (badVal.length ? ': ' + badVal.slice(0, 8).join(', ') : ''));
// untranslated: a non-Finnish value identical to Finnish is only allowed for names that really are the same
const SAME_OK = new Set(['act.padel', 'act.tennis', 'chat.chat', 'dur.2-3h', 'dur.24h', 'view.list']);   // + cityname.* (e.g. Madrid is Madrid everywhere)
const same = [];
for (const k of KEYS) for (const l of ['en', 'sv', 'es']) if (D[l][k] === D.fi[k] && /[a-zåäöñ]{3,}/i.test(D.fi[k].replace(/<[^>]+>|\{\w+\}|Molaplan|OpenStreetMap/g, '')) && !SAME_OK.has(k) && !/^cityname\./.test(k)) same.push(l + ':' + k);
ok(!same.length, 'no Finnish text left untranslated in en/sv/es' + (same.length ? ': ' + same.slice(0, 10).join(', ') : ''));
// every key literally referenced in the code exists (tx('k'), txn('k'), tx(c?'a':'b'), data-i18n="k")
const used = new Set(), plural = new Set();
for (const m of html.matchAll(/\b(txn?)\(([^()]*?)(?:,|\))/g)) for (const q of m[2].matchAll(/'([a-z][\w-]*\.[\w.-]+)'/g)) (m[1] === 'txn' ? plural : used).add(q[1]);
for (const m of html.matchAll(/data-i18n="([^"]+)"/g)) used.add(m[1]);
const missingUsed = [...used].filter(k => !(k in D.en) && !/\.$/.test(k)).concat([...plural].filter(k => !(k + '.one' in D.en && k + '.other' in D.en)).map(k => k + '.one/.other'));
ok(used.size > 400 && !missingUsed.length, `all ${used.size + plural.size} keys referenced in index.html exist` + (missingUsed.length ? ': ' + missingUsed.join(', ') : ''));
// data keys: activities, categories, levels, durations, server message codes
const actIds = [...html.matchAll(/\['([a-z]+)','[^']+','[^']+',\d+/g)].map(m => m[1]);
const seedIds = [...schema.matchAll(/^\s*\('([a-z]+)',\s*'[^']+',\s*'/gm)].map(m => m[1]);
const catIds = [...new Set([...html.matchAll(/\['(siivous|maalaus|koira|kuljetus|seura|muutto|kauppa|piha|muu)','/g)].map(m => m[1]))];
const codes = new Set([...schema.matchAll(/post_system_message\(\w+,\s*'([a-z_]+)'/g)].map(m => 'sys.' + m[1]).concat([...schema.matchAll(/notify(?:_admins)?\((?:[\w.]+,\s*)?'[^']*',\s*'([a-z_]+)'/g)].map(m => 'notif.' + m[1])));
const dataKeys = [...new Set(actIds.concat(seedIds))].map(i => 'act.' + i).concat(catIds.map(i => 'cat.' + i), ['all', 'beginner', 'intermediate', 'advanced'].map(i => 'level.' + i), ['1h', '2-3h', 'halfday', 'day', '24h', 'days'].map(i => 'dur.' + i), ['clvl.1', 'clvl.2', 'clvl.3'], [...codes]);
const missData = dataKeys.filter(k => !(k in D.en));
ok(actIds.length >= 30 && catIds.length === 9 && codes.size >= 16 && !missData.length, `activity (${new Set(actIds.concat(seedIds)).size}), category (9), level, duration and server-code (${codes.size}) keys all translated` + (missData.length ? ': ' + missData.join(', ') : ''));
// cities data
const cityIds = CITIES.map(c => c.id);
ok(['Helsinki', 'Vantaa', 'Espoo', 'Tuusula', 'Stockholm', 'London', 'Madrid'].every(c => cityIds.includes(c)) && cityIds.length === 7, 'cities: Helsinki, Vantaa, Espoo, Tuusula, Stockholm, London, Madrid');
ok(cityIds.slice(0, 4).every(c => CITIES.find(x => x.id === c).cc === 'FI') && CITIES.every(c => ['FI', 'SE', 'GB', 'ES'].includes(c.cc)), 'every city has a country code; Finnish cities first');
ok(CITIES.every(c => ['en', 'fi', 'sv', 'es'].every(l => D[l]['cityname.' + c.id]) && ['en', 'fi', 'sv', 'es'].every(l => D[l]['country.' + c.cc])), 'city and country names translated in all four languages');
ok(D.fi['cityname.Stockholm'] === 'Tukholma' && D.es['cityname.London'] === 'Londres' && D.es['cityname.Stockholm'] === 'Estocolmo' && D.sv['cityname.Helsinki'] === 'Helsingfors', 'localized city names (Tukholma, Londres, Estocolmo, Helsingfors)');
const dn = id => CITIES.find(c => c.id === id).areas.flatMap(a => a.d.map(d => d[0]));
ok(['Kallio', 'Vuosaari', 'Etu-Töölö', 'Pasila', 'Oulunkylä'].every(d => dn('Helsinki').includes(d)) && ['Tapiola', 'Leppävaara', 'Matinkylä', 'Otaniemi'].every(d => dn('Espoo').includes(d)) && ['Tikkurila', 'Myyrmäki', 'Hakunila', 'Koivukylä'].every(d => dn('Vantaa').includes(d)) && ['Hyrylä', 'Jokela', 'Kellokoski', 'Riihikallio', 'Rusutjärvi'].every(d => dn('Tuusula').includes(d)), 'official districts present (e.g. Kallio, Tapiola, Tikkurila, Hyrylä, Jokela, Kellokoski, Riihikallio, Rusutjärvi)');
ok(CITIES.every(c => c.areas.every(a => a.d.every(d => Math.abs(d[2] - c.c[0]) < 0.35 && Math.abs(d[3] - c.c[1]) < 0.5))), 'every district has coordinates inside its city');
{ const an = id => CITIES.find(c => c.id === id).areas.map(a => a.fi);
  ok(an('Stockholm').length === 11 && ['Norra innerstaden', 'Södermalm', 'Kungsholmen', 'Bromma', 'Järva', 'Hässelby-Vällingby', 'Hägersten-Älvsjö', 'Skärholmen', 'Enskede-Årsta-Vantör', 'Skarpnäck', 'Farsta'].every(a => an('Stockholm').includes(a)) && dn('Stockholm').length >= 100 &&
     ['Södermalm', 'Östermalm', 'Kungsholmen', 'Vasastan', 'Norrmalm', 'Gamla stan', 'Hammarby sjöstad', 'Kista', 'Vällingby', 'Farsta', 'Skärholmen', 'Hägersten', 'Tensta', 'Rinkeby', 'Alvik', 'Årsta'].every(d => dn('Stockholm').includes(d)), `Stockholm: 11 stadsdelsområden, ${dn('Stockholm').length} stadsdelar (Södermalm, Vasastan, Hammarby sjöstad, Kista…)`);
  ok(an('London').length === 33 && an('London').includes('City of London') && ['Westminster', 'Camden', 'Hackney', 'Tower Hamlets', 'Croydon', 'Havering', 'Hillingdon', 'Kingston upon Thames'].every(a => an('London').includes(a)) &&
     ['Shoreditch', 'Camden Town', 'Brixton', 'Notting Hill', 'Canary Wharf', 'Greenwich', 'Hackney', 'Islington', 'Clapham', 'Wimbledon', 'Stratford'].every(d => dn('London').includes(d)), `London: City of London + 32 boroughs, ${dn('London').length} areas (Shoreditch, Brixton, Canary Wharf…)`);
  ok(an('Madrid').length === 21 && dn('Madrid').length === 131 && ['Centro', 'Salamanca', 'Chamberí', 'Retiro', 'Fuencarral-El Pardo', 'San Blas-Canillejas', 'Villa de Vallecas', 'Barajas'].every(a => an('Madrid').includes(a)) &&
     CITIES.find(c => c.id === 'Madrid').areas[0].d.map(d => d[0]).sort().join() === 'Cortes,Embajadores,Justicia,Palacio,Sol,Universidad', 'Madrid: 21 distritos, 131 barrios (Centro = Sol, Embajadores, Cortes, Justicia, Universidad, Palacio)');
  ok(CITIES.every(c => { const n = c.areas.flatMap(a => a.d.map(d => d[0])); return new Set(n).size === n.length && n.every(x => x.length <= 40); }), 'district names unique within each city and ≤ 40 chars (DB check)'); }

{ const def = html.slice(html.indexOf('const ICONS={'), html.indexOf('};', html.indexOf('const ICONS={')));
  const have = new Set([...def.matchAll(/(?:^|[,{\s])([a-z]+):'/g)].map(m => m[1])), usedI = [...new Set([...html.matchAll(/icon\('([a-z]+)'\)/g)].map(m => m[1]))];
  const missI = usedI.filter(i => !have.has(i));
  ok(!missI.length, `every icon used in index.html is defined (${usedI.length} icons, incl. the city picker icon)` + (missI.length ? ': ' + missI.join(', ') : '')); }

{ const fs2 = require('fs'), bad = [];
  for (const f of ['index.html', 'i18n.js', 'cities.js', 'config.js']) { const t = fs2.readFileSync(__dirname + '/' + f, 'utf8'); for (const m of t.matchAll(/.{0,30}(demo|prototyyp|esimerkki|localStorage-only).{0,30}/gi)) bad.push(f + ': ' + m[0].trim()); }
  ok(!bad.length, 'runtime files contain no demo/prototype wording (grep demo|prototyyp|esimerkki)' + (bad.length ? ': ' + bad.slice(0, 5).join(' | ') : '')); }

// ---------- B. browser tests ----------
const FI_WORDS = /(?<![\p{L}])(ja|tai|klo|tulossa|avoinna|uutta|uusi|menot|sijainti|osallistujat|tarvitaan|syy|reitti|kaveri|lukematon\w*|tarkistusjono|vahvistettu|takaisin|muokkaa|ilmoitukset|tänään|huomenna|eilen|kaikki|tapahtum\w*|mukana|mukaan|pyyntö\w*|avunpyyn\w*|tallenna|kirjaudu\w*|sähköpost\w*|salasan\w*|järjestäjä|hullu\w*|talkoo\w*|auttaj\w*|ylläpi\w*|kaupunginosa|valitse|lähetä|peru|sulje|takaisin|profiili|omat|koti|kartta|luo)(?![\p{L}])/iu;
const KEY_RE = new RegExp('\\b(?:' + [...new Set(KEYS.map(k => k.split('.')[0]))].join('|') + ')\\.[A-Za-z0-9_.-]+', 'g');
(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROME || '/usr/bin/google-chrome', args: ['--no-sandbox'] });
  const errors = [];
  const newPage = async (locale) => {
    const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale, timezoneId: 'Europe/Helsinki' });
    const page = await ctx.newPage();
    page.on('pageerror', e => errors.push(locale + ' pageerror: ' + e.message));
    page.on('console', m => { if (m.type() === 'error' && !/tile\.openstreetmap|Failed to load resource/.test(m.text())) errors.push(locale + ' console: ' + m.text()); });
    page.on('dialog', d => d.accept());
    return { ctx, page };
  };
  const shotOf = page => async name => { await page.waitForTimeout(350); await page.screenshot({ path: SHOTS + 'v2-' + name + '.png' }); };

  // B1. default language follows the browser (fi/en/sv/es), anything else -> English
  for (const [locale, want] of [['en-US', 'en'], ['fi-FI', 'fi'], ['sv-SE', 'sv'], ['es-ES', 'es'], ['de-DE', 'en'], ['ja-JP', 'en']]) {
    const { ctx, page } = await newPage(locale);
    await page.goto(BASE + '?mock=1'); await page.evaluate(() => { if (window.__mockSupa) window.__mockSupa.reset(); localStorage.clear(); sessionStorage.clear(); }); await page.reload();
    await page.waitForSelector('#landing #land-locate');
    const got = await page.evaluate(() => [window.__molaplan.lang, document.documentElement.lang, document.querySelector('#land-locate').textContent.trim(), document.title, document.querySelector('#lang-gate .on').dataset.v]);
    ok(got[0] === want && got[1] === want && got[2] === D[want]['land.locate'] && got[3] === D[want]['meta.title'] && got[4] === want, `browser ${locale} -> UI language "${want}" (landing + top-corner switcher)`);
    await ctx.close();
  }

  // B2. language picker on the login screen switches all four languages and is remembered
  {
    const { ctx, page } = await newPage('de-DE');
    await page.goto(BASE + '?mock=1'); await page.evaluate(() => { if (window.__mockSupa) window.__mockSupa.reset(); localStorage.clear(); sessionStorage.clear(); }); await page.reload();
    await page.waitForSelector('#lang-gate');
    for (const l of ['fi', 'sv', 'es', 'en']) {
      await page.click(`#lang-gate [data-v="${l}"]`);
      await page.waitForFunction(l => window.__molaplan.lang === l, l);
      const r = await page.evaluate(() => [document.documentElement.lang, document.querySelector('#land-locate').textContent.trim(), localStorage.getItem('molaplan.lang'), document.querySelector('#lang-gate .on').dataset.v, document.querySelector('#land-login').textContent.trim()]);
      ok(r[0] === l && r[1] === D[l]['land.locate'] && r[2] === l && r[3] === l && r[4] === D[l]['guest.login'], `first-screen picker -> ${l} (text, <html lang>, localStorage)`);
    }
    await page.click('#land-login'); await page.waitForSelector('#auth-card #tab-login.on');
    ok((await page.textContent('#tab-login')).trim() === D.en['auth.tabLogin'], 'login screen follows the chosen language');
    await page.click('#lang-gate [data-v="sv"]'); await page.reload(); await page.waitForSelector('#s-home.active #guest-login');
    ok(await page.evaluate(() => window.__molaplan.lang) === 'sv', 'chosen language survives a reload (localStorage)');
    await ctx.close();
  }

  // B3. full flow in en / es / sv
  const scan = async (page, lang, where) => {
    const r = await page.evaluate(() => {
      const t = [document.body.innerText, document.title];
      document.querySelectorAll('[placeholder],[aria-label],[title]').forEach(e => { ['placeholder', 'aria-label', 'title'].forEach(a => { const v = e.getAttribute(a); if (v) t.push(v); }); });
      document.querySelectorAll('option,optgroup').forEach(o => t.push(o.label || o.textContent));
      return { text: t.join('\n'), missing: window.__molaplan.i18nMissing, lang: window.__molaplan.lang };
    });
    const keys = (r.text.match(KEY_RE) || []).filter(k => k in D.en);
    const fi = lang === 'fi' ? null : r.text.replace(/Molaplan|¡Mola el plan!/g, '').match(FI_WORDS);
    ok(r.lang === lang && !keys.length && !fi && !r.missing.length, `[${lang}] ${where}: no raw keys, no Finnish leftovers, no missing translations` + (keys.length ? ' keys: ' + keys.join(',') : '') + (fi ? ' finnish: "' + fi[0] + '"' : '') + (r.missing.length ? ' missing: ' + r.missing.join(',') : ''));
  };
  const cfg = {
    en: { locale: 'en-GB', city: 'Espoo', district: 'Tapiola', at: ' at ', tab: 'Home', evCity: 'London', evDistrict: 'Shoreditch' },
    es: { locale: 'es-ES', city: 'Vantaa', district: 'Tikkurila', at: ' a las ', tab: 'Inicio', evCity: 'Madrid', evDistrict: 'Sol' },
    sv: { locale: 'sv-FI', city: 'Tuusula', district: 'Hyrylä', at: ' kl. ', tab: 'Hem', evCity: 'Stockholm', evDistrict: 'Södermalm' },
  };
  for (const lang of ['en', 'es', 'sv']) {
    const c = cfg[lang];
    const { ctx, page } = await newPage(c.locale);
    const shot = shotOf(page);
    const M = (fn, ...a) => page.evaluate(fn, ...a);
    const email = `me-${lang}+test@example.com`;
    await page.goto(BASE + '?mock=1'); await page.evaluate(() => { if (window.__mockSupa) window.__mockSupa.reset(); localStorage.clear(); sessionStorage.clear(); }); await page.reload();
    await page.waitForSelector('#landing');
    await scan(page, lang, 'landing');
    ok(await page.isVisible('#land-locate') && !(await page.isVisible('#land-city')), `[${lang}] landing: "${D[lang]['land.locate']}" first, manual picker behind "${D[lang]['land.manual']}"`);
    await page.click('#land-manual-btn');
    { const og = await page.$$eval('#land-city optgroup', g => g.map(x => x.label + ':' + [...x.querySelectorAll('option')].map(o => o.value).join('/')));
      ok(og.length === 4 && og[0] === D[lang]['country.FI'] + ':Helsinki/Espoo/Vantaa/Tuusula' && og.slice(1).join('|') === [D[lang]['country.SE'] + ':Stockholm', D[lang]['country.GB'] + ':London', D[lang]['country.ES'] + ':Madrid'].join('|'), `[${lang}] landing city picker grouped by country, Finland first: ${og.join(' | ')}`);
      for (const [city, n] of [['Stockholm', 100], ['London', 300], ['Madrid', 131]]) { await page.selectOption('#land-city', city); const v = await page.$$eval('#land-district option', o => o.length); ok(v >= n, `[${lang}] landing: ${city} (${await page.$eval('#land-city option:checked', o => o.textContent)}) has ${v} districts`); } }
    await page.selectOption('#land-city', c.city); await page.selectOption('#land-district', c.district);
    await page.click('#land-go'); await page.waitForSelector('#s-home.active #guest-login');
    await scan(page, lang, 'guest home');
    if (lang === 'en') { await page.waitForTimeout(600); await shot('en-00-guest-home'); }
    await page.click('#nav [data-t="create"]'); await page.waitForSelector('#auth-prompt'); await page.waitForTimeout(350);
    await scan(page, lang, 'login sheet');
    if (lang !== 'en') await shot(lang + '-00-login-sheet');
    await page.click('#ap-later'); await page.waitForTimeout(300);
    await page.click('#guest-strip [data-a="guest-auth"]'); await page.waitForSelector('#auth-card #tab-signup.on');
    await scan(page, lang, 'sign-up screen');
    if (lang === 'en') await shot('en-01-sign-up');
    await page.fill('#au-email', email); await page.fill('#au-pw', 'password123'); await page.click('#auth-submit');
    await page.waitForSelector('#onb.active #onb-name');
    await scan(page, lang, 'onboarding');
    // onboarding: language picker keeps typed values, city + district selection
    await page.fill('#onb-name', 'Enn');
    const other = lang === 'es' ? 'fi' : 'es';
    await page.click(`#lang-onb [data-v="${other}"]`); await page.waitForFunction(l => window.__molaplan.lang === l, other);
    ok(await page.inputValue('#onb-name') === 'Enn' && (await page.textContent('[data-a="onb-next"]')).trim() === D[other]['onb.next'], `[${lang}] onboarding picker switches to ${other} and keeps the typed name`);
    await page.click(`#lang-onb [data-v="${lang}"]`); await page.waitForFunction(l => window.__molaplan.lang === l, lang);
    for (const [city, must] of [['Helsinki', ['Kallio', 'Vuosaari']], ['Espoo', ['Tapiola', 'Leppävaara']], ['Vantaa', ['Tikkurila', 'Myyrmäki']], ['Tuusula', ['Hyrylä', 'Jokela', 'Kellokoski', 'Riihikallio', 'Rusutjärvi']]]) {
      await page.selectOption('#onb-city', city);
      const vals = await page.$$eval('#onb-district option', o => o.map(x => x.value));
      ok(must.every(d => vals.includes(d)) && vals.length >= 20, `[${lang}] onboarding ${city}: ${vals.length} districts incl. ${must.join(', ')}`);
    }
    if (lang === 'sv') {
      await page.selectOption('#onb-city', 'Helsinki');
      const lbl = await page.$eval('#onb-district option[value="Kallio"]', o => o.textContent);
      const cityLbl = await page.$eval('#onb-city option[value="Helsinki"]', o => o.textContent);
      ok(lbl === 'Berghäll' && cityLbl === 'Helsingfors', 'Swedish UI shows official Swedish place names (Kallio -> Berghäll, Helsinki -> Helsingfors), stored value stays Finnish');
    }
    await page.selectOption('#onb-city', c.city); await page.selectOption('#onb-district', c.district);
    if (lang === 'es') await shot('es-01-onboarding');
    await page.click('[data-a="onb-next"]'); await page.waitForSelector('#s-lajit.active');
    await scan(page, lang, 'activity picker');
    ok((await page.textContent('#s-lajit')).includes(D[lang]['act.lautapelit']) && (await page.textContent('#s-lajit')).includes(D[lang]['act.nakuuinti']), `[${lang}] activity names translated (${D[lang]['act.lautapelit']}, ${D[lang]['act.nakuuinti']})`);
    for (const id of ['padel', 'lautapelit', 'kahvi']) await page.click(`#s-lajit [data-v="${id}"]`);
    await page.click('[data-a="lajit-done"]'); await page.waitForSelector('#s-home.active');
    const prof = await M(e => { const d = window.__mockSupa.db(); return d.profiles.find(p => p.id === window.__mockSupa.userId(e)); }, email);
    ok(prof.language === lang && prof.city === c.city && prof.district === c.district, `[${lang}] profile saved with language="${lang}", city ${c.city}, district ${c.district}`);
    ok((await page.textContent('#nav')).includes(c.tab), `[${lang}] navigation translated ("${c.tab}")`);
    // other users' content in the chosen city
    const bobId = await M(async ({ city, district }) => {
      const id = window.__mockSupa.createUser('bob+test@example.com', 'Bob', { phone: '+358401111111', city, district });
      window.__mockSupa.createUser('carol+test@example.com', 'Carol', { phone: '+358402222222', city, district });
      const s = new Date(Date.now() + 864e5); s.setHours(18, 0, 0, 0);
      const ci = window.MOLAPLAN_CITIES.find(x => x.id === city); const d = ci.areas.flatMap(a => a.d).find(x => x[0] === district);
      await window.__mockSupa.as('bob+test@example.com').from('events').insert({ activity_id: 'padel', title: 'Padel 🎾', description: '🎾🎾', starts_at: s.toISOString(), city, district, place: 'Center Court', lat: d[2], lng: d[3], max_participants: 4, skill_level: 'beginner' });
      const s2 = new Date(Date.now() + 2 * 864e5); s2.setHours(12, 0, 0, 0);
      await window.__mockSupa.as('carol+test@example.com').from('events').insert({ activity_id: 'pyjamabrunssi', title: 'Brunch 🥞', starts_at: s2.toISOString(), city, district, place: 'Park', lat: d[2] + 0.004, lng: d[3] + 0.004, max_participants: 8 });
      return id;
    }, { city: c.city, district: c.district });
    await M(() => window.__molaplan.refresh()); await page.waitForTimeout(300);
    await page.evaluate(() => document.querySelector('#s-home').scrollTop = 0);
    ok(await page.locator('#s-home .card').count() === 2, `[${lang}] home lists the two events in ${c.city}`);
    const homeTxt = await page.textContent('#s-home');
    ok(homeTxt.includes(c.at.trim()) || homeTxt.includes(D[lang]['date.tomorrow']), `[${lang}] dates/times use the ${lang} locale`);
    const banners = await page.evaluate(() => ['#cz-banner .cta small', '#good-banner .hc-count small'].map(q => document.querySelector(q)).filter(Boolean).map(e => e.textContent.trim()));
    const pr = new Intl.PluralRules({ en: 'en-GB', es: 'es-ES', sv: 'sv-FI' }[lang]);
    const f = n => pr.select(n) === 'one' ? 'one' : 'other';
    ok(banners.length === 2 && banners[0] === D[lang]['home.czCount.' + f(1)].replace('{n}', 1) && banners[1] === D[lang]['home.goodCount.' + f(0)].replace('{n}', 0), `[${lang}] home banner counters translated + pluralised ("${banners.join('", "')}")`);
    ok(homeTxt.includes(D[lang]['level.beginner']), `[${lang}] skill level stored as key and shown translated (${D[lang]['level.beginner']})`);
    await scan(page, lang, 'home');
    await page.waitForFunction(() => !document.querySelector('#toast').classList.contains('show'), null, { timeout: 8000 }).catch(() => {});
    if (lang === 'en') await shot('en-02-home'); else await shot(lang + '-04-home');
    // event detail + chat with translated system messages
    const evId = await M(() => window.__mockSupa.db().events.find(e => e.title === 'Padel 🎾').id);
    await page.click(`#s-home .card[data-id="${evId}"]`); await page.waitForSelector('#s-detail.active');
    await page.click('#s-detail [data-a="join"]');
    await page.waitForFunction(id => window.__molaplan.state.meetups.find(m => m.id === id).people.length === 2, evId);
    await page.waitForTimeout(300);
    await scan(page, lang, 'event detail');
    ok((await page.textContent('#s-detail')).includes(D[lang]['act.padel']) && (await page.textContent('#s-detail')).includes(c.at.trim()), `[${lang}] event detail: translated activity + localized time`);
    if (lang === 'sv') await shot('sv-02-event');
    await page.click('#s-detail .d-chat, #s-detail [data-a="open-chat"]'); await page.waitForSelector('#s-chat.active #cv-in');
    const joinedTxt = D[lang]['sys.joined'].replace('{name}', 'Enn');
    await page.waitForFunction(t => document.querySelector('#cv-msgs').textContent.includes(t), joinedTxt, { timeout: 4000 });
    ok(true, `[${lang}] system message from DB code "joined" rendered as "${joinedTxt}"`);
    await page.fill('#cv-in', '👋'); await page.press('#cv-in', 'Enter');
    await scan(page, lang, 'chat');
    if (lang === 'sv') await shot('sv-03-chat');
    await page.click('#s-chat [data-a="back"]'); await page.click('#s-detail [data-a="back"]');
    // notification text from code (Bob joins MY event later) -> check event created by me
    // create: free-form city (GitHub 2026-09-26); a supported city moves the pin, the district is derived from the pin
    await page.click('#nav [data-t="create"]'); await page.waitForSelector('#s-create.active #c-title');
    ok(await page.inputValue('#c-city') === c.city && !(await page.$('#c-district')), `[${lang}] create form defaults to my city (free-form input)`);
    await page.fill('#c-city', c.evCity.toLowerCase());
    await page.fill('#c-title', 'Board game night 🎲'); await page.click('#s-create [data-a="c-act"][data-v="lautapelit"]');
    await page.fill('#c-place', 'Library 📚');
    await scan(page, lang, 'create event');
    if (lang === 'en') { await page.evaluate(() => document.querySelector('#s-create').scrollTop = 0); await shot('en-03-create'); }
    await page.click('#ck-rule'); await page.click('#s-create [data-a="publish"]'); await page.waitForSelector('#s-detail.active');
    const myEv = await M(() => window.__mockSupa.db().events.find(e => e.title === 'Board game night 🎲'));
    { const d = await M(city => window.MOLAPLAN_CITIES.find(x => x.id === city).areas[0].d[0], c.evCity);
      ok(myEv && myEv.city === c.evCity && myEv.district === d[0] && myEv.skill_level === 'all' && Math.abs(myEv.lat - d[2]) < 0.03 && Math.abs(myEv.lng - d[3]) < 0.03, `[${lang}] event created in ${c.evCity} / ${d[0]} (city name normalised, pin moved to the city, district from the pin, level key "all")`); }
    await M(async id => { await window.__mockSupa.as('bob+test@example.com').from('event_participants').insert({ event_id: id, user_id: window.__mockSupa.userId('bob+test@example.com') }); }, myEv.id);
    const joinNotif = D[lang]['notif.joined_your_event'].replace('{name}', 'Bob').replace('{title}', 'Board game night 🎲');
    await page.waitForFunction(t => window.__molaplan.state.notifs.some(n => n.text === t), joinNotif, { timeout: 4000 });
    ok(true, `[${lang}] notification from DB code rendered as "${joinNotif}"`);
    await page.click('#s-detail [data-a="back"]');
    // map: (city filter was removed on GitHub 2026-09-26 – feed/map are no longer city-scoped) – activity menu + markers
    await page.click('#nav [data-t="map"]'); await page.waitForSelector('#s-map.active #act-filter-btn-map');
    await page.click('#act-filter-btn-map'); await page.waitForSelector('#act-filter-popup-map:not(.hidden)');
    ok(await page.isVisible('#act-filter-popup-map [data-v="all"]') && !(await page.isVisible('#act-filter-popup-home')), `[${lang}] map activity menu opens its own popup`);
    await page.click('#act-filter-popup-map [data-v="all"]'); await page.waitForTimeout(400);
    ok(await page.locator('#s-map .leaflet-marker-icon').count() >= 2, `[${lang}] map shows the ${c.city} events`);
    await scan(page, lang, 'map');
    if (lang === 'es') await shot('es-02-map');
    // good deeds + help request with city/district
    await page.click('#nav [data-t="home"]'); await page.click('#good-banner'); await page.waitForSelector('#s-good.active');
    await scan(page, lang, 'good deeds');
    ok((await page.textContent('#s-good')).includes(D[lang]['cat.kauppa']), `[${lang}] help category names translated (${D[lang]['cat.kauppa']})`);
    if (lang === 'es') { await page.evaluate(() => document.querySelector('#s-good').scrollTop = 0); await shot('es-03-good'); }
    await page.click('#s-good [data-a="ask-help"]'); await page.waitForSelector('#s-ask.active #a-title');
    ok(await page.inputValue('#a-city') === c.city, `[${lang}] help request form has city select (default ${c.city})`);
    await page.selectOption('#a-city', 'Vantaa'); await page.selectOption('#a-district', 'Tikkurila');
    await page.fill('#a-title', 'Moving boxes 📦'); await page.fill('#a-desc', '📦📦📦 2nd floor, no lift – 2 people.');
    const tmr = await M(() => { const d = new Date(Date.now() + 864e5); return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); });
    await page.fill('#a-date', tmr); await page.fill('#a-time', '12:00');
    await scan(page, lang, 'help request step 1');
    await page.click('#s-ask [data-a="a-next"]'); await page.waitForSelector('#vblock');
    await page.fill('#v-phone', '+358 40 123 4567'); await page.click('[data-a="v-phone-save"]'); await page.waitForSelector('#vr-phone.ok');
    await scan(page, lang, 'help request step 2');
    await page.click('#s-ask [data-a="a-next"]'); await page.waitForSelector('#ck-vol');
    for (const k of ['vol', 'terms', 'review']) await page.click('#ck-' + k, { position: { x: 16, y: 16 } });
    await scan(page, lang, 'help request step 3');
    await page.click('#s-ask [data-a="a-submit"]'); await page.waitForSelector('#s-mine.active .card.req');
    const req = await M(() => window.__mockSupa.db().help_requests.find(h => h.title === 'Moving boxes 📦'));
    ok(req && req.city === 'Vantaa' && req.district === 'Tikkurila', `[${lang}] help request saved with chosen city/district (Vantaa / Tikkurila)`);
    await scan(page, lang, 'mine');
    const sent = D[lang]['notif.request_sent'].replace('{title}', 'Moving boxes 📦');
    await page.waitForFunction(t => window.__molaplan.state.notifs.some(n => n.text === t), sent, { timeout: 4000 });
    ok(true, `[${lang}] "request sent" notification translated`);
    // notifications sheet, chats, hullut
    await page.click('#nav [data-t="home"]'); await page.click('#s-home .bell'); await page.waitForSelector('#notif-list');
    await scan(page, lang, 'notifications');
    await page.keyboard.press('Escape'); await page.click('[data-a="sheet-close"]').catch(() => {});
    await page.waitForTimeout(300);
    await page.click('#nav [data-t="chats"]'); await page.waitForSelector('#s-chats.active');
    await scan(page, lang, 'chats');
    await page.click('#nav [data-t="home"]'); await page.click('#cz-banner'); await page.waitForSelector('#s-hullut.active');
    await scan(page, lang, 'Hullut');
    await page.click('#s-hullut [data-a="back"]');
    // admin queue
    await M(e => window.__mockSupa.makeAdmin(e), email); await page.reload(); await page.waitForSelector('#s-home.active');
    await page.click('#s-home [data-t="profile"]'); await page.waitForSelector('#s-profile.active #open-admin');
    await page.click('#open-admin'); await page.waitForSelector('#s-admin.active .card.adm');
    await scan(page, lang, 'admin queue');
    // v5: business queue + reports queue (seeded by another user)
    await M(async (l) => { const S = window.__mockSupa, e = 'biz-' + l + '@example.com'; if (!S.userId(e)) S.createUser(e, 'Carla', { phone: '+358409999999' }); const B = S.as(e);
      await B.rpc('apply_business', { biz: { name: 'Carla Studio Ltd', business_code: { en: '0737546-2', es: '1572860-0', sv: '1234567-1' }[l], country: 'FI', website: 'https://carla.example', consent_terms: true }, contact: { contact_email: e, phone: '+358409999999', billing_address: 'Street 1, 00100 Helsinki' } });
      const ev = S.db().events.find(x => x.host_id && x.host_id !== B.id && (x.kind || 'community') === 'community'); if (ev) await B.from('reports').insert({ target_type: 'event', target_id: ev.id, reason: 'business_ad' }); }, lang);
    await M(() => window.__molaplan.refresh()); await page.click('#adm-sec-biz'); await page.waitForSelector('#adm-biz-list .card');
    await scan(page, lang, 'admin business queue');
    await page.click('#adm-sec-reports'); await page.waitForSelector('#adm-rep-list .card');
    await scan(page, lang, 'admin reports queue');
    await M(async (l) => { const S = window.__mockSupa, e = 'team-' + l + '@example.com'; if (!S.userId(e)) S.createUser(e, 'Tero', {}); const B = S.as(e);
      await B.rpc('request_team_account', { req: { team_name: 'FC Kaislikko', sport: 'Football', city: 'Helsinki', contact_name: 'Tero', contact_email: e, description: 'Sunday league team' } }); }, lang);
    await M(() => window.__molaplan.refresh()); await page.click('#adm-sec-teams'); await page.waitForSelector('#adm-tr-list .tr-adm');
    await scan(page, lang, 'admin team requests queue');
    await page.click('#adm-sec-help');
    await page.click('#s-admin [data-a="back"]'); await page.waitForSelector('#s-profile.active');
    await scan(page, lang, 'profile');
    await page.click('#open-orgs'); await page.waitForSelector('#s-orgs.active #org-team');
    await scan(page, lang, 'business/team account options');
    await page.click('#org-biz'); await page.waitForSelector('#s-biz.active #biz-form');
    await scan(page, lang, 'business account');
    await page.click('#s-biz [data-a="back"]'); await page.waitForSelector('#s-orgs.active');
    await page.click('#org-team'); await page.waitForSelector('#s-teamreq.active #tr-form');
    await scan(page, lang, 'team account request');
    await page.click('#s-teamreq [data-a="back"]'); await page.waitForSelector('#s-orgs.active');
    await page.click('#s-orgs [data-a="back"]'); await page.waitForSelector('#s-profile.active');
    await page.click('[data-a="open-guide"]'); await page.waitForSelector('#guide-list');
    await scan(page, lang, 'community guidelines');
    await page.click('[data-a="sheet-close"]').catch(() => {}); await page.waitForTimeout(300);
    if (lang === 'sv') { await page.evaluate(() => document.querySelector('#s-profile').scrollTop = 0); await shot('sv-01-profile'); }
    // Profiili picker: switch through all four, saved to profiles.language + localStorage
    for (const l of ['fi', 'es', 'sv', 'en', lang]) {
      await page.click(`#lang-prof [data-v="${l}"]`); await page.waitForFunction(l => window.__molaplan.lang === l, l);
      await page.waitForFunction(({ e, l }) => { const d = window.__mockSupa.db(); return d.profiles.find(p => p.id === window.__mockSupa.userId(e)).language === l; }, { e: email, l }, { timeout: 4000 });
      const r = await M(() => [localStorage.getItem('molaplan.lang'), document.querySelector('#nav [data-t="home"]').textContent.trim(), document.documentElement.lang]);
      ok(r[0] === l && r[1].includes(D[l]['nav.home']) && r[2] === l, `[${lang}] Profiili picker -> ${l}: UI, localStorage and profiles.language updated`);
      if (l !== 'fi') await scan(page, l, 'profile after switching');
    }
    // the profile language wins after login on a device with another saved choice
    await page.click('#logout-btn'); await page.waitForSelector('#s-home.active #guest-login');
    const deviceLang = lang === 'en' ? 'fi' : 'en';
    await page.click('#guest-lang'); await page.waitForSelector('#lang-sheet'); await page.click(`#lang-sheet [data-v="${deviceLang}"]`);
    await page.waitForFunction(l => window.__molaplan.lang === l, deviceLang);
    await page.click('#guest-login'); await page.waitForSelector('#auth-card #tab-login.on'); await page.fill('#au-email', email); await page.fill('#au-pw', 'password123'); await page.click('#auth-submit');
    await page.waitForSelector('#s-home.active'); await page.waitForFunction(l => window.__molaplan.lang === l, lang, { timeout: 4000 });
    ok(await M(() => localStorage.getItem('molaplan.lang')) === lang, `[${lang}] after login the saved profile language (${lang}) replaces the device choice (${deviceLang})`);
    await ctx.close();
  }

  // B4. Finnish UI still clean after a runtime switch back (no stale strings)
  {
    const { ctx, page } = await newPage('fi-FI');
    await page.goto(BASE + '?mock=1'); await page.evaluate(() => { if (window.__mockSupa) window.__mockSupa.reset(); localStorage.clear(); sessionStorage.clear(); }); await page.reload();
    await page.waitForSelector('#landing');
    await page.click('#lang-gate [data-v="en"]'); await page.click('#lang-gate [data-v="fi"]');
    await scan(page, 'fi', 'landing after en -> fi switch');
    await page.click('#land-signup'); await page.waitForSelector('#auth-card');
    await scan(page, 'fi', 'sign-up screen after en -> fi switch');
    ok((await page.textContent('#tab-signup')).trim() === D.fi['auth.tabSignup'], 'switching back to Finnish restores Finnish texts');
    await ctx.close();
  }

  ok(errors.length === 0, 'no page/console errors' + (errors.length ? ': ' + errors.join(' | ') : ''));
  console.log(`\nALL PASSED: ${passed} checks`);
  await browser.close();
})().catch(async e => { console.error('✘', e.message, `\n(${passed} checks passed before failure)`); process.exit(1); });
