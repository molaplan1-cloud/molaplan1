// Molaplan order shop – admin (orders, products, installers, settings). Finnish only, mobile-first.
import { API, IMG_BASE, LOGO, ICONS, esc, eur, toast, sb, shrinkImage } from './common.js';

const $ = (id) => document.getElementById(id);
const app = () => $('app');
const STATUSES = [
  ['uusi', 'Uusi'], ['tarjottu', 'Tarjottu'], ['laskutettu', 'Laskutettu'],
  ['maksettu', 'Maksettu'], ['toimitettu', 'Toimitettu'], ['peruttu', 'Peruttu'],
];
const ST = Object.fromEntries(STATUSES);
const KINDS = { software: 'Ohjelmisto', device: 'Laite', service: 'Palvelu' };
const SVG = {
  up: '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 15l6-6 6 6"/></svg>',
  down: '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 9l6 6 6-6"/></svg>',
  eye: '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/></svg>',
  eyeoff: '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 3l18 18M10.6 5.1A10 10 0 0 1 12 5c6.5 0 10 7 10 7a17 17 0 0 1-3.2 4.1M6.1 6.1C3.6 7.8 2 12 2 12s3.5 7 10 7a9.7 9.7 0 0 0 5.9-2"/></svg>',
  edit: '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 20h4L19 9l-4-4L4 16v4z"/></svg>',
  back: '<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 6l-6 6 6 6"/></svg>',
};

let session = null;
let me = '';
let orders = [];
let products = [];
let settings = null;
let filter = 'avoimet';
let query = '';
let pollTimer = null;

const fmtDate = (s) => new Date(s).toLocaleString('fi-FI', { day: 'numeric', month: 'numeric', year: '2-digit', hour: '2-digit', minute: '2-digit' });
const centsFromInput = (v) => {
  const s = String(v ?? '').replace(/\s|€/g, '').replace(',', '.');
  if (!s) return null;
  const n = Number(s);
  return Number.isFinite(n) && n >= 0 ? Math.round(n * 100) : NaN;
};
const inputFromCents = (c) => (c == null ? '' : (c / 100).toFixed(2).replace('.', ','));

// --- auth -----------------------------------------------------------------------------------------
async function start() {
  $('brand').innerHTML = `${LOGO}<span>Molaplan <small>· hallinta</small></span>`;
  const { data } = await sb().auth.getSession();
  session = data.session;
  sb().auth.onAuthStateChange((_e, s) => { session = s; });
  if (!session) return renderLogin();
  await afterLogin();
}

function renderLogin(msg = '') {
  $('tabs').hidden = true;
  app().innerHTML = `<div class="login panel form">
    <h2>Kirjaudu hallintaan</h2>
    <p class="muted" style="margin:0">Kirjaudu Molaplan-tilillä, jolla on ylläpito-oikeus.</p>
    ${msg ? `<div class="err">${esc(msg)}</div>` : ''}
    <div class="field"><label for="le">Sähköposti</label><input id="le" type="email" autocomplete="username" inputmode="email"></div>
    <div id="codeStep" hidden class="field"><label for="lc">Sähköpostiin tullut koodi</label><input id="lc" type="text" inputmode="numeric" autocomplete="one-time-code" maxlength="10"></div>
    <div id="pwStep" hidden class="field"><label for="lp">Salasana</label><input id="lp" type="password" autocomplete="current-password"></div>
    <button class="btn primary" id="lsend" type="button">Lähetä kirjautumiskoodi</button>
    <button class="btn primary" id="lverify" type="button" hidden>Kirjaudu</button>
    <button class="btn ghost small" id="lpw" type="button">Kirjaudu salasanalla</button>
  </div>`;
  const email = () => $('le').value.trim().toLowerCase();
  $('lsend').onclick = async () => {
    if (!email()) return toast('Kirjoita sähköposti');
    $('lsend').disabled = true;
    const { error } = await sb().auth.signInWithOtp({ email: email(), options: { shouldCreateUser: false } });
    $('lsend').disabled = false;
    if (error) return toast(error.message.includes('Signups not allowed') ? 'Tällä sähköpostilla ei ole Molaplan-tiliä.' : `Virhe: ${error.message}`, 4000);
    $('codeStep').hidden = false; $('lverify').hidden = false; $('lsend').textContent = 'Lähetä koodi uudelleen'; $('lc').focus();
    toast('Koodi lähetetty sähköpostiin');
  };
  $('lpw').onclick = () => { $('pwStep').hidden = false; $('lverify').hidden = false; $('lsend').hidden = true; $('lpw').hidden = true; $('lp').focus(); };
  $('lverify').onclick = async () => {
    $('lverify').disabled = true;
    const res = $('pwStep').hidden
      ? await sb().auth.verifyOtp({ email: email(), token: $('lc').value.trim(), type: 'email' })
      : await sb().auth.signInWithPassword({ email: email(), password: $('lp').value });
    $('lverify').disabled = false;
    if (res.error) return toast(`Kirjautuminen epäonnistui: ${res.error.message}`, 4000);
    session = res.data.session;
    await afterLogin();
  };
}

async function afterLogin() {
  const { data: isAdmin, error } = await sb().rpc('is_shop_admin');
  if (error || isAdmin !== true) {
    await sb().auth.signOut();
    return renderLogin('Tällä tilillä ei ole ylläpito-oikeutta.');
  }
  me = session.user.email;
  $('tabs').hidden = false;
  await Promise.all([loadOrders(), loadSettings(), loadApplications()]);
  window.addEventListener('hashchange', route);
  clearInterval(pollTimer);
  pollTimer = setInterval(async () => { const n = orders.length; await loadOrders(); if (orders.length > n) { toast('Uusi tilaus!'); route(); } else updateBadge(); }, 60000);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) loadOrders().then(() => { if (location.hash.startsWith('#tilaukset') || !location.hash) route(); }); });
  route();
}

// --- data ----------------------------------------------------------------------------------------
async function loadOrders() {
  const { data, error } = await sb().from('shop_orders').select('*').order('created_at', { ascending: false }).limit(500);
  if (!error) orders = data;
  updateBadge();
}
async function loadProducts() {
  const { data, error } = await sb().from('shop_products').select('*').order('sort').order('name');
  if (!error) products = data;
}
async function loadSettings() {
  const { data } = await sb().from('shop_settings').select('*').eq('id', 1).maybeSingle();
  settings = data || { seller_name: '', contact_email: '', notify_emails: [], ntfy_topic: '', reply_templates: [] };
}
function updateBadge() {
  const n = orders.filter((o) => !o.seen || o.status === 'uusi').length;
  $('newCount').hidden = n === 0;
  $('newCount').textContent = n;
  document.title = `${n ? `(${n}) ` : ''}Tilaukset – Molaplan hallinta`;
}

// --- routing -------------------------------------------------------------------------------------
function route() {
  const h = location.hash || '#tilaukset';
  const tab = h.startsWith('#tuotteet') ? 'tuotteet' : h.startsWith('#asetukset') ? 'asetukset' : h.startsWith('#asentajat') ? 'asentajat' : 'tilaukset';
  document.querySelectorAll('#tabs a').forEach((a) => a.classList.toggle('on', a.dataset.tab === tab));
  if (tab === 'tuotteet') return renderProducts();
  if (tab === 'asetukset') return renderSettings();
  if (tab === 'asentajat') return renderInstallers();
  const m = h.match(/tilaus=([0-9a-f-]{36})/);
  renderOrders(m ? m[1] : null);
}

// --- orders --------------------------------------------------------------------------------------
function matches(o) {
  if (filter === 'avoimet' && ['toimitettu', 'peruttu'].includes(o.status)) return false;
  if (filter !== 'avoimet' && filter !== 'kaikki' && o.status !== filter) return false;
  if (!query) return true;
  const q = query.toLowerCase();
  return [String(o.number), o.name, o.email, o.phone, o.message, ...(o.items || []).map((i) => i.name)].join(' ').toLowerCase().includes(q);
}

function renderOrders(selId) {
  const count = (f) => orders.filter((o) => (f === 'avoimet' ? !['toimitettu', 'peruttu'].includes(o.status) : f === 'kaikki' ? true : o.status === f)).length;
  const chip = (v, l) => `<button class="chip" data-f="${v}" aria-pressed="${filter === v}">${l}<span class="n">${count(v)}</span></button>`;
  const list = orders.filter(matches);
  const mobileDetail = selId && window.matchMedia('(max-width: 979px)').matches;
  app().innerHTML = `
    <div class="split ${selId ? '' : 'single'}">
      <section ${mobileDetail ? 'hidden' : ''}>
        <div class="toolbar"><input type="search" id="q" placeholder="Hae nimellä, numerolla, tuotteella…" value="${esc(query)}"></div>
        <div class="chips status">${chip('avoimet', 'Avoimet')}${STATUSES.map(([v, l]) => chip(v, l)).join('')}${chip('kaikki', 'Kaikki')}</div>
        <div class="olist">${list.length ? list.map((o) => `
          <a class="orow ${o.seen ? '' : 'unseen'} ${o.id === selId ? 'sel' : ''}" href="#tilaukset/tilaus=${o.id}">
            <div class="l1"><span class="num">#${o.number}</span><span class="nm">${esc(o.name)}</span>${o.seen ? '' : '<span class="newtag">UUSI</span>'}<span class="pill st-${o.status}">${ST[o.status]}</span></div>
            <div class="l2"><span class="dt">${fmtDate(o.created_at)}</span> · ${esc((o.items || []).map((i) => `${i.name}${i.qty > 1 ? ` ×${i.qty}` : ''}`).join(', '))}${o.offer_cents != null ? ` · ${eur(o.offer_cents)}` : ''}</div>
          </a>`).join('') : '<div class="empty">Ei tilauksia tällä suodattimella.</div>'}</div>
      </section>
      ${selId ? '<section id="detail" class="detail"><div class="empty">Ladataan…</div></section>' : ''}
    </div>`;
  app().querySelector('.chips').onclick = (e) => { const b = e.target.closest('[data-f]'); if (b) { filter = b.dataset.f; renderOrders(selId); } };
  const q = $('q');
  q.oninput = () => { query = q.value; const pos = q.selectionStart; renderOrders(selId); $('q').focus(); $('q').setSelectionRange(pos, pos); };
  if (selId) renderDetail(selId);
}

async function renderDetail(id) {
  const o = orders.find((x) => x.id === id);
  const el = $('detail');
  if (!o) { el.innerHTML = '<div class="empty">Tilausta ei löytynyt.</div>'; return; }
  if (!o.seen) {
    o.seen = true; updateBadge();
    sb().from('shop_orders').update({ seen: true }).eq('id', id).then(() => {});
  }
  const { data: msgs } = await sb().from('shop_order_messages').select('*').eq('order_id', id).order('created_at');
  const tpls = settings?.reply_templates || [];
  el.innerHTML = `
    <div class="head">
      <a class="iconbtn" href="#tilaukset" aria-label="Takaisin">${SVG.back}</a>
      <h2>#${o.number} · ${esc(o.name)}</h2>
    </div>
    <div class="muted">Vastaanotettu ${fmtDate(o.created_at)} · kieli ${esc(o.lang)}${o.unlocks_pc_app ? ' · sisältää PC-sovelluksen' : ''}</div>
    <div class="seg" id="seg">${STATUSES.map(([v, l]) => `<button type="button" data-s="${v}" class="st-${v} ${o.status === v ? 'on' : ''}">${l}</button>`).join('')}</div>
    ${o.unlocks_pc_app ? `<div class="note" style="margin:0">${ICONS.info}<span>${['maksettu', 'toimitettu'].includes(o.status)
      ? `PC-sovelluksen lataus on avattu tilille ${esc(o.email)} (molaplan.com/tilaa/lataa).`
      : `Kun tila on Maksettu, PC-sovelluksen lataus avautuu Molaplan-tilille ${esc(o.email)}.`}</span></div>` : ''}
    <div class="panel">
      <dl class="kv">
        <dt>Nimi</dt><dd>${esc(o.name)}</dd>
        <dt>Sähköposti</dt><dd><a href="mailto:${esc(o.email)}">${esc(o.email)}</a></dd>
        ${o.phone ? `<dt>Puhelin</dt><dd><a href="tel:${esc(o.phone.replace(/[^\d+]/g, ''))}">${esc(o.phone)}</a></dd>` : ''}
        ${o.address ? `<dt>Osoite</dt><dd class="pre">${esc(o.address)}</dd>` : ''}
      </dl>
    </div>
    <div class="panel items">
      <h2 style="font-size:17px;margin:0 0 6px">Tilatut</h2>
      ${(o.items || []).map((i) => `<div class="it"><b>${esc(i.name)}</b> × ${i.qty} <span class="muted">· ${i.price_mode === 'fixed' && i.price_cents != null ? `${eur(i.price_cents)}${i.price_note ? ' ' + esc(i.price_note) : ''}` : 'tarjouksen mukaan'}</span>${i.notes ? `<div class="n">${esc(i.notes)}</div>` : ''}</div>`).join('')}
      ${o.message ? `<h2 style="font-size:17px;margin:12px 0 6px">Viesti</h2><div class="pre">${esc(o.message)}</div>` : ''}
    </div>
    <div class="panel form">
      <div class="two">
        <div class="field"><label for="offer">Tarjoushinta (€)</label><input id="offer" type="text" inputmode="decimal" placeholder="esim. 249,00" value="${inputFromCents(o.offer_cents)}"></div>
        <div class="field" style="display:flex;align-items:flex-end"><button class="btn" id="saveOffer" type="button" style="width:100%">Tallenna hinta</button></div>
      </div>
      <div class="field"><label for="anotes">Omat muistiinpanot (eivät näy asiakkaalle)</label><textarea id="anotes" style="min-height:60px">${esc(o.admin_notes)}</textarea></div>
    </div>
    <div class="panel form" id="reply">
      <h2 style="font-size:17px;margin:0">Vastaa asiakkaalle</h2>
      <div class="tpl">${tpls.map((tp, i) => `<button class="chip" type="button" data-tpl="${i}">${esc(tp.title)}</button>`).join('')}</div>
      <div class="field"><label for="rsub">Aihe</label><input id="rsub" type="text" value="${esc(`Tilauksesi #${o.number}`)}"></div>
      <div class="field"><label for="rbody">Viesti</label><textarea id="rbody" style="min-height:180px"></textarea></div>
      <label class="check" id="rstatusWrap" hidden><input type="checkbox" id="rstatus" checked><span>Vaihda samalla tilaksi <b id="rstatusName"></b></span></label>
      <div style="display:flex;gap:8px;flex-wrap:wrap">
        <button class="btn primary" id="rsend" type="button">Lähetä sähköposti</button>
        <button class="btn" id="rmail" type="button">Avaa Mail-sovelluksessa</button>
      </div>
      <div class="muted">Lähettäjä: tilaukset@molaplan.com, vastaukset ohjautuvat osoitteeseen ${esc(settings?.contact_email || me)}. Viesti tallentuu tilauksen historiaan.</div>
    </div>
    <div class="panel">
      <h2 style="font-size:17px;margin:0 0 8px">Historia</h2>
      <div class="thread">${(msgs || []).map(msgHtml).join('') || '<div class="muted">Ei viestejä vielä.</div>'}</div>
    </div>
    <div style="display:flex;justify-content:flex-end"><button class="btn ghost danger small" id="delOrder" type="button">Poista tilaus pysyvästi</button></div>`;

  let tplStatus = '';
  const vars = () => ({
    nimi: o.name, numero: o.number, 'sähköposti': o.email,
    hinta: (() => { const c = centsFromInput($('offer').value); return Number.isFinite(c) && c != null ? eur(c) : '[hinta]'; })(),
    'myyjä': settings?.seller_name || 'Molaplan',
    lataus: o.unlocks_pc_app ? `PC-sovelluksen voit ladata osoitteesta https://molaplan.com/tilaa/lataa/ kirjautumalla Molaplan-tilillä, jonka sähköposti on ${o.email}. Jos sinulla ei vielä ole tiliä, luo se samalla sähköpostiosoitteella Molaplan-sovelluksessa tai latussivulla.` : '',
  });
  const fill = (s) => String(s || '').replace(/\{(nimi|numero|hinta|myyjä|lataus|sähköposti)\}/g, (_, k) => vars()[k] ?? '');
  el.querySelector('.tpl').onclick = (e) => {
    const b = e.target.closest('[data-tpl]'); if (!b) return;
    const tp = tpls[+b.dataset.tpl];
    $('rsub').value = fill(tp.subject); $('rbody').value = fill(tp.body);
    tplStatus = tp.status || '';
    $('rstatusWrap').hidden = !tplStatus; $('rstatusName').textContent = ST[tplStatus] || '';
    $('rbody').focus();
  };
  $('seg').onclick = async (e) => {
    const b = e.target.closest('[data-s]'); if (!b || b.dataset.s === o.status) return;
    await setStatus(o, b.dataset.s);
  };
  $('saveOffer').onclick = async () => {
    const c = centsFromInput($('offer').value);
    if (Number.isNaN(c)) return toast('Tarkista hinta');
    const { error } = await sb().from('shop_orders').update({ offer_cents: c }).eq('id', o.id);
    if (error) return toast(`Virhe: ${error.message}`, 4000);
    o.offer_cents = c; toast('Hinta tallennettu');
  };
  $('anotes').onblur = async () => {
    if ($('anotes').value === o.admin_notes) return;
    const { error } = await sb().from('shop_orders').update({ admin_notes: $('anotes').value }).eq('id', o.id);
    if (!error) { o.admin_notes = $('anotes').value; toast('Muistiinpano tallennettu'); }
  };
  const send = async (mode) => {
    const subject = $('rsub').value.trim(), body = $('rbody').value.trim();
    if (!subject || !body) return toast('Kirjoita aihe ja viesti');
    const c = centsFromInput($('offer').value);
    const status = !$('rstatusWrap').hidden && $('rstatus').checked ? tplStatus : '';
    if (mode === 'mailto') {
      location.href = `mailto:${encodeURIComponent(o.email)}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
    }
    const btn = mode === 'send' ? $('rsend') : $('rmail');
    btn.disabled = true;
    try {
      const r = await fetch(`${API}/reply`, {
        method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${session.access_token}` },
        body: JSON.stringify({ order_id: o.id, subject, body, status, mode, offer_cents: Number.isFinite(c) ? c : null }),
      });
      const j = await r.json().catch(() => ({}));
      if (mode === 'send' && !j.delivered) {
        toast(`Sähköposti ei lähtenyt (${j.error || r.status}). Käytä "Avaa Mail-sovelluksessa".`, 6000);
      } else toast(mode === 'send' ? 'Viesti lähetetty' : 'Kirjattu historiaan');
      await loadOrders(); renderOrders(o.id);
    } finally { btn.disabled = false; }
  };
  $('rsend').onclick = () => send('send');
  $('rmail').onclick = () => send('mailto');
  $('delOrder').onclick = async () => {
    if (!confirm(`Poistetaanko tilaus #${o.number} ja sen viestit pysyvästi? (esim. asiakkaan pyynnöstä)`)) return;
    const { error } = await sb().from('shop_orders').delete().eq('id', o.id);
    if (error) return toast(`Virhe: ${error.message}`, 4000);
    await loadOrders(); location.hash = '#tilaukset';
  };
}

async function setStatus(o, s) {
  const { error } = await sb().from('shop_orders').update({ status: s, seen: true }).eq('id', o.id);
  if (error) return toast(`Virhe: ${error.message}`, 4000);
  o.status = s;
  toast(`Tila: ${ST[s]}`);
  await loadOrders(); renderOrders(o.id);
}

function msgHtml(m) {
  const when = fmtDate(m.created_at);
  if (m.kind === 'status') return `<div class="msg status">${when} · tila ${esc(m.body)}${m.author ? ` · ${esc(m.author)}` : ''}</div>`;
  const label = { out: 'Lähetetty', auto: 'Automaattinen', in: 'Saapunut', note: 'Muistiinpano' }[m.kind] || m.kind;
  const state = m.delivered === true ? '✓ toimitettu' : m.delivered === false ? `✗ ei lähtenyt: ${esc(m.error)}` : m.error === 'mailto' ? 'Mail-sovelluksen kautta' : '';
  return `<div class="msg ${m.kind === 'out' ? 'out' : ''} ${m.delivered === false ? 'fail' : ''}">
    <div class="mh"><b>${label}</b><span>${when}</span>${state ? `<span>${state}</span>` : ''}</div>
    ${m.subject ? `<div><b>${esc(m.subject)}</b></div>` : ''}${m.body ? `<div class="b">${esc(m.body)}</div>` : ''}</div>`;
}

// --- products ------------------------------------------------------------------------------------
async function renderProducts() {
  await loadProducts();
  app().innerHTML = `
    <div class="toolbar"><h2 style="margin:0;flex:1">Tuotteet ja palvelut</h2><button class="btn primary" id="newP" type="button">+ Lisää tuote</button></div>
    <p class="muted" style="margin:0 0 10px">Järjestä nuolilla, piilota silmästä. Piilotettu tuote ei näy tilaussivulla.</p>
    <div class="plist">${products.map((p, i) => `
      <div class="prow ${p.hidden ? 'hid' : ''}">
        <div class="th">${p.image_path ? `<img src="${IMG_BASE}${encodeURI(p.image_path)}" alt="">` : ICONS[p.kind] || ''}</div>
        <div><div style="font-weight:600">${esc(p.name)}</div>
          <div class="muted">${esc(p.category)} · ${p.price_mode === 'fixed' ? esc(eur(p.price_cents)) + (p.price_note ? ' ' + esc(p.price_note) : '') : 'tarjouksen mukaan'}${p.hidden ? ' · <b>piilotettu</b>' : ''}</div></div>
        <div class="acts">
          <button class="iconbtn" data-up="${i}" aria-label="Ylös" ${i === 0 ? 'disabled' : ''}>${SVG.up}</button>
          <button class="iconbtn" data-down="${i}" aria-label="Alas" ${i === products.length - 1 ? 'disabled' : ''}>${SVG.down}</button>
          <button class="iconbtn" data-hide="${i}" aria-label="${p.hidden ? 'Näytä' : 'Piilota'}">${p.hidden ? SVG.eyeoff : SVG.eye}</button>
          <button class="iconbtn" data-edit="${i}" aria-label="Muokkaa">${SVG.edit}</button>
        </div>
      </div>`).join('') || '<div class="empty">Ei tuotteita.</div>'}</div>`;
  $('newP').onclick = () => editProduct(null);
  app().querySelector('.plist').onclick = async (e) => {
    const b = e.target.closest('button'); if (!b) return;
    if (b.dataset.edit) return editProduct(products[+b.dataset.edit]);
    if (b.dataset.hide) {
      const p = products[+b.dataset.hide];
      await sb().from('shop_products').update({ hidden: !p.hidden }).eq('id', p.id);
      toast(p.hidden ? 'Näkyy nyt tilaussivulla' : 'Piilotettu');
      return renderProducts();
    }
    const i = +(b.dataset.up ?? b.dataset.down);
    const j = b.dataset.up != null ? i - 1 : i + 1;
    if (j < 0 || j >= products.length) return;
    const arr = [...products];
    [arr[i], arr[j]] = [arr[j], arr[i]];
    await Promise.all(arr.map((p, k) => (p.sort !== (k + 1) * 10 ? sb().from('shop_products').update({ sort: (k + 1) * 10 }).eq('id', p.id) : null)));
    renderProducts();
  };
}

function editProduct(p) {
  const isNew = !p;
  p = p || { name: '', category: products[0]?.category || 'Laitteet', kind: 'device', summary: '', description: '', price_mode: 'quote', price_cents: null,
    price_note: '', image_path: null, allow_quantity: true, max_quantity: 20, ask_notes: true, notes_label: '', unlocks_pc_app: false, hidden: false, i18n: {} };
  const cats = [...new Set(products.map((x) => x.category))];
  const tr = (l, k) => esc(p.i18n?.[l]?.[k] || '');
  let imagePath = p.image_path;
  let newImage = null;
  const d = $('dlg');
  d.className = 'full';
  d.innerHTML = `<form method="dialog" class="form" id="pf">
    <div class="dhead"><button class="iconbtn" value="cancel" aria-label="Sulje">${ICONS.close}</button><h2>${isNew ? 'Uusi tuote' : 'Muokkaa tuotetta'}</h2><button class="btn primary" id="psave" type="button">Tallenna</button></div>
    <div class="dcontent form">
      <div class="field"><label for="pn">Nimi</label><input id="pn" type="text" maxlength="120" value="${esc(p.name)}" required></div>
      <div class="field"><span class="lbl">Kuva</span>
        <div class="imgpick"><div class="prev" id="pprev">${imagePath ? `<img src="${IMG_BASE}${encodeURI(imagePath)}" alt="">` : ICONS[p.kind] || ''}</div>
          <div style="display:flex;flex-direction:column;gap:6px">
            <label class="btn small">Valitse kuva<input id="pimg" type="file" accept="image/*" hidden></label>
            <button class="btn small ghost danger" type="button" id="pimgrm" ${imagePath ? '' : 'hidden'}>Poista kuva</button>
          </div></div>
        <div class="hint">Puhelimella voit ottaa kuvan suoraan. Kuva pienennetään automaattisesti.</div></div>
      <div class="two">
        <div class="field"><label for="pc">Kategoria</label><input id="pc" type="text" list="pcats" maxlength="60" value="${esc(p.category)}"><datalist id="pcats">${cats.map((c) => `<option value="${esc(c)}">`).join('')}</datalist></div>
        <div class="field"><label for="pk">Tyyppi</label><select id="pk" class="in">${Object.entries(KINDS).map(([k, l]) => `<option value="${k}" ${p.kind === k ? 'selected' : ''}>${l}</option>`).join('')}</select>
          <div class="hint">Ohjelmistolle ei kysytä osoitetta.</div></div>
      </div>
      <div class="field"><label for="ps">Lyhyt kuvaus (kortissa)</label><input id="ps" type="text" maxlength="300" value="${esc(p.summary)}"></div>
      <div class="field"><label for="pd">Pitkä kuvaus</label><textarea id="pd" maxlength="4000" style="min-height:120px">${esc(p.description)}</textarea></div>
      <div class="field"><span class="lbl">Hinta</span>
        <div class="radio">
          <label><input type="radio" name="pm" value="quote" ${p.price_mode !== 'fixed' ? 'checked' : ''}> Tilauskohtainen hinta – pyydä tarjous</label>
          <label><input type="radio" name="pm" value="fixed" ${p.price_mode === 'fixed' ? 'checked' : ''}> Kiinteä hinta (näytetään)</label>
        </div></div>
      <div class="two" id="fixedRow">
        <div class="field"><label for="pp">Hinta (€)</label><input id="pp" type="text" inputmode="decimal" value="${inputFromCents(p.price_cents)}" placeholder="esim. 149,00"></div>
        <div class="field"><label for="pnote">Hinnan lisäteksti</label><input id="pnote" type="text" maxlength="80" value="${esc(p.price_note)}" placeholder="esim. / kpl, alkaen"></div>
      </div>
      <label class="check"><input type="checkbox" id="pq" ${p.allow_quantity ? 'checked' : ''}><span>Asiakas voi valita määrän</span></label>
      <div class="field" id="maxRow"><label for="pmax">Enimmäismäärä</label><input id="pmax" type="number" min="1" max="999" value="${p.max_quantity}"></div>
      <label class="check"><input type="checkbox" id="pan" ${p.ask_notes ? 'checked' : ''}><span>Kysy lisätietoja tuotteesta</span></label>
      <div class="field" id="noteRow"><label for="pnl">Lisätietokentän otsikko</label><input id="pnl" type="text" maxlength="120" value="${esc(p.notes_label)}" placeholder="esim. Laitteen merkki ja malli"></div>
      <label class="check"><input type="checkbox" id="ppc" ${p.unlocks_pc_app ? 'checked' : ''}><span>Maksettu tilaus avaa PC-sovelluksen latauksen asiakkaan Molaplan-tilille</span></label>
      <label class="check"><input type="checkbox" id="ph" ${p.hidden ? 'checked' : ''}><span>Piilotettu (ei näy tilaussivulla)</span></label>
      <details class="box"><summary>Käännökset (englanti, ruotsi, espanja)</summary>
        ${['en', 'sv', 'es'].map((l) => `<div class="form" style="margin-top:12px"><b>${{ en: 'Englanti', sv: 'Ruotsi', es: 'Espanja' }[l]}</b>
          <input type="text" data-tr="${l}.name" placeholder="Nimi" value="${tr(l, 'name')}" maxlength="120">
          <input type="text" data-tr="${l}.category" placeholder="Kategoria" value="${tr(l, 'category')}" maxlength="60">
          <input type="text" data-tr="${l}.summary" placeholder="Lyhyt kuvaus" value="${tr(l, 'summary')}" maxlength="300">
          <textarea data-tr="${l}.description" placeholder="Pitkä kuvaus" maxlength="4000">${tr(l, 'description')}</textarea></div>`).join('')}
        <div class="hint">Tyhjä kenttä näytetään suomeksi.</div>
      </details>
      ${isNew ? '' : '<button class="btn ghost danger" type="button" id="pdel">Poista tuote</button>'}
    </div></form>`;
  const sync = () => {
    $('fixedRow').hidden = d.querySelector('input[name=pm]:checked').value !== 'fixed';
    $('maxRow').hidden = !$('pq').checked; $('noteRow').hidden = !$('pan').checked;
  };
  d.querySelectorAll('input[name=pm]').forEach((r) => (r.onchange = sync)); $('pq').onchange = sync; $('pan').onchange = sync; sync();
  $('pimg').onchange = async () => {
    const f = $('pimg').files[0]; if (!f) return;
    newImage = await shrinkImage(f);
    $('pprev').innerHTML = `<img src="${URL.createObjectURL(newImage)}" alt="">`;
    $('pimgrm').hidden = false;
  };
  $('pimgrm').onclick = () => { newImage = null; imagePath = null; $('pprev').innerHTML = ICONS[$('pk').value] || ''; $('pimgrm').hidden = true; };
  $('psave').onclick = async () => {
    const name = $('pn').value.trim();
    if (!name) return toast('Kirjoita nimi');
    const mode = d.querySelector('input[name=pm]:checked').value;
    const cents = centsFromInput($('pp').value);
    if (mode === 'fixed' && (cents == null || Number.isNaN(cents))) return toast('Kirjoita hinta tai valitse tilauskohtainen hinta');
    $('psave').disabled = true;
    try {
      if (newImage) {
        const ext = newImage.type === 'image/webp' ? 'webp' : newImage.type === 'image/png' ? 'png' : 'jpg';
        const path = `p/${crypto.randomUUID()}.${ext}`;
        const { error } = await sb().storage.from('shop-images').upload(path, newImage, { contentType: newImage.type || 'image/jpeg', cacheControl: '31536000' });
        if (error) throw new Error(`Kuvan lähetys: ${error.message}`);
        imagePath = path;
      }
      const i18n = {};
      d.querySelectorAll('[data-tr]').forEach((el) => {
        const [l, k] = el.dataset.tr.split('.'); const v = el.value.trim();
        if (v) { i18n[l] = i18n[l] || {}; i18n[l][k] = v; }
      });
      const row = {
        name, category: $('pc').value.trim() || 'Muut', kind: $('pk').value, summary: $('ps').value.trim(), description: $('pd').value.trim(),
        price_mode: mode, price_cents: mode === 'fixed' ? cents : null, price_note: mode === 'fixed' ? $('pnote').value.trim() : '',
        image_path: imagePath, allow_quantity: $('pq').checked, max_quantity: Math.max(1, Math.min(999, parseInt($('pmax').value, 10) || 1)),
        ask_notes: $('pan').checked, notes_label: $('pnl').value.trim(), unlocks_pc_app: $('ppc').checked, hidden: $('ph').checked, i18n,
      };
      if (isNew) row.sort = (products.reduce((m, x) => Math.max(m, x.sort), 0) || 0) + 10;
      const q = isNew ? sb().from('shop_products').insert(row) : sb().from('shop_products').update(row).eq('id', p.id);
      const { error } = await q;
      if (error) throw new Error(error.message);
      if (!isNew && p.image_path && p.image_path !== imagePath) sb().storage.from('shop-images').remove([p.image_path]).then(() => {});
      d.close(); toast('Tallennettu'); renderProducts();
    } catch (e) {
      toast(`Virhe: ${e.message}`, 5000);
    } finally { $('psave').disabled = false; }
  };
  $('pdel')?.addEventListener('click', async () => {
    if (!confirm(`Poistetaanko "${p.name}"? Vanhat tilaukset säilyvät. (Voit myös vain piilottaa sen.)`)) return;
    const { error } = await sb().from('shop_products').delete().eq('id', p.id);
    if (error) return toast(`Virhe: ${error.message}`, 4000);
    if (p.image_path) sb().storage.from('shop-images').remove([p.image_path]).then(() => {});
    d.close(); renderProducts();
  });
  d.showModal();
}

// --- installers (R256–R262) ----------------------------------------------------------------------
// Only admins grant the installer status. The server (SECURITY DEFINER RPCs + RLS) enforces it; this
// page just calls them. Revoking ends every customer access of that installer at once.
let installers = [];
let applications = [];
let userHits = null;
const instSt = { active: 'Voimassa', revoked: 'Poistettu' };

async function loadApplications() {
  const { data, error } = await sb().rpc('admin_list_installer_applications');
  applications = error ? [] : (data || []);
  const n = applications.filter((a) => a.status === 'new').length;
  $('appCount').hidden = n === 0;
  $('appCount').textContent = n;
}
async function loadInstallers() {
  const { data, error } = await sb().rpc('admin_list_installers');
  if (error) throw new Error(error.message);
  installers = data || [];
}
const errText = (e) => {
  const m = String(e?.message || e || '');
  if (m.includes('no Molaplan account')) return 'Tällä sähköpostilla ei ole Molaplan-tiliä.';
  if (m.includes('admin only')) return 'Vain ylläpitäjä voi tehdä tämän.';
  return m;
};

async function renderInstallers() {
  app().innerHTML = '<div class="empty">Ladataan…</div>';
  try { await Promise.all([loadInstallers(), loadApplications()]); } catch (e) {
    app().innerHTML = `<div class="err">Asentajia ei voitu ladata: ${esc(errText(e))}</div>`; return;
  }
  const open = applications.filter((a) => a.status === 'new');
  const hit = (u) => `<div class="prow inst">
      <div><b>${esc(u.email)}</b>${u.display_name ? ` · ${esc(u.display_name)}` : ''}
        <div class="muted">${u.has_app ? '' : 'ei ole vielä avannut sovellusta · '}${u.installer_status ? `asentaja: ${instSt[u.installer_status] || esc(u.installer_status)} ${esc(u.public_id || '')}` : 'ei asentaja'}</div></div>
      <div class="acts"><button class="btn small" type="button" data-grant="${esc(u.email)}" data-name="${esc(u.display_name || '')}">${u.installer_status === 'active' ? 'Muokkaa' : 'Myönnä'}</button></div></div>`;
  app().innerHTML = `<div class="form" id="instPage" style="max-width:760px;padding:18px 0 50px">
    <h2 style="margin:0">Asentajat</h2>
    <div class="muted">Myönnä asentajan oikeus vain, kun olet tarkistanut nimen ja yrityksen. Asiakas antaa asentajalle pääsyn asentajatunnuksella (esim. MPL-K7Q-M2X) ja näkee nämä tiedot. Oikeuden poisto katkaisee heti kaikki asentajan asiakaspääsyt.</div>
    <div class="panel form">
      <h2 style="font-size:17px;margin:0">Hae käyttäjä sähköpostilla</h2>
      <div style="display:flex;gap:8px"><input id="ue" type="search" inputmode="email" placeholder="nimi@esimerkki.fi"><button class="btn" type="button" id="ufind">Hae</button></div>
      <div id="uhits" class="plist" style="padding:0">${userHits == null ? '' : userHits.length ? userHits.map(hit).join('') : '<div class="muted">Käyttäjää ei löytynyt.</div>'}</div>
    </div>
    <div class="panel form">
      <h2 style="font-size:17px;margin:0">Hakemukset${open.length ? ` (${open.length})` : ''}</h2>
      ${open.length ? open.map((a) => `<div class="prow inst">
        <div><b>${esc(a.display_name)}</b>${a.company ? ` · ${esc(a.company)}` : ''}<div class="muted">${esc(a.email)} · ${fmtDate(a.created_at)}</div>${a.message ? `<div class="pre" style="margin-top:4px">${esc(a.message)}</div>` : ''}</div>
        <div class="acts"><button class="btn small primary" type="button" data-approve="${a.id}">Hyväksy</button><button class="btn small ghost danger" type="button" data-decline="${a.id}">Hylkää</button></div></div>`).join('') : '<div class="muted">Ei avoimia hakemuksia.</div>'}
    </div>
    <div class="panel form">
      <h2 style="font-size:17px;margin:0">Hyväksytyt asentajat</h2>
      ${installers.length ? installers.map((i) => `<div class="prow inst ${i.status === 'active' ? '' : 'hid'}">
        <div><b class="mono">${esc(i.public_id)}</b> <span class="pill ${i.status === 'active' ? 'st-maksettu' : 'st-peruttu'}">${instSt[i.status] || esc(i.status)}</span>
          <div><b>${esc(i.display_name)}</b>${i.company ? ` · ${esc(i.company)}` : ''}</div>
          <div class="muted">${esc(i.email || '')} · asiakkaita ${i.customers ?? 0} · myönnetty ${fmtDate(i.granted_at)}${i.revoked_at && i.status !== 'active' ? ` · poistettu ${fmtDate(i.revoked_at)}` : ''}</div>
          ${i.note ? `<div class="muted pre">Muistiinpano: ${esc(i.note)}</div>` : ''}</div>
        <div class="acts"><button class="btn small" type="button" data-edit="${i.user_id}">${i.status === 'active' ? 'Muokkaa' : 'Myönnä uudelleen'}</button>
          ${i.status === 'active' ? `<button class="btn small ghost danger" type="button" data-revoke="${i.user_id}">Poista oikeus</button>` : ''}</div></div>`).join('') : '<div class="muted">Ei vielä asentajia.</div>'}
    </div>
  </div>`;
  const find = async () => {
    const q = $('ue').value.trim();
    if (q.length < 3) return toast('Kirjoita vähintään 3 merkkiä sähköpostista.');
    const { data, error } = await sb().rpc('admin_find_user', { p_email: q });
    if (error) return toast(`Virhe: ${errText(error)}`, 4000);
    userHits = data || [];
    renderInstallers().then(() => { $('ue').value = q; });
  };
  $('ufind').onclick = find;
  $('ue').onkeydown = (e) => { if (e.key === 'Enter') find(); };
  $('instPage').onclick = async (e) => {
    const b = e.target.closest('button');
    if (!b) return;
    if (b.dataset.grant != null) {
      const cur = installers.find((i) => i.email === b.dataset.grant);
      return grantDialog({ email: b.dataset.grant, display_name: cur?.display_name || b.dataset.name, company: cur?.company || '', note: cur?.note || '' });
    }
    if (b.dataset.edit) return grantDialog(installers.find((i) => i.user_id === b.dataset.edit));
    if (b.dataset.approve) {
      const a = applications.find((x) => x.id === b.dataset.approve);
      return grantDialog({ email: a.email, display_name: a.display_name, company: a.company, note: a.message ? `Hakemus: ${a.message}` : '' });
    }
    if (b.dataset.decline) {
      if (!confirm('Hylätäänkö hakemus? Hakija näkee, ettei sitä hyväksytty.')) return;
      const { error } = await sb().rpc('admin_decline_installer_application', { p_id: b.dataset.decline });
      if (error) return toast(`Virhe: ${errText(error)}`, 4000);
      toast('Hakemus hylätty'); return renderInstallers();
    }
    if (b.dataset.revoke) {
      const i = installers.find((x) => x.user_id === b.dataset.revoke);
      if (!confirm(`Poistetaanko asentajan oikeus: ${i.display_name} (${i.public_id})?\n\nKaikki asentajan asiakaspääsyt (${i.customers ?? 0}) katkeavat heti. Tunnus säilyy, jos oikeus myönnetään myöhemmin uudelleen.`)) return;
      const { error } = await sb().rpc('admin_revoke_installer', { p_user: i.user_id });
      if (error) return toast(`Virhe: ${errText(error)}`, 4000);
      userHits = null; toast('Asentajan oikeus poistettu'); return renderInstallers();
    }
  };
}

function grantDialog(cur) {
  const d = $('dlg');
  d.className = '';
  d.innerHTML = `<form method="dialog" class="form" style="padding:18px;min-width:min(440px,90vw)">
    <h2 style="margin:0;font-size:19px">Asentajan oikeus</h2>
    <div class="muted">${esc(cur.email)}${cur.public_id ? ` · ${esc(cur.public_id)}` : ''}</div>
    <div class="field"><label for="gn">Tarkistettu nimi</label><input id="gn" type="text" maxlength="80" value="${esc(cur.display_name || '')}"></div>
    <div class="field"><label for="gc">Yritys</label><input id="gc" type="text" maxlength="80" value="${esc(cur.company || '')}" placeholder="esim. Kevytyrittäjä"><div class="hint">Asiakas näkee nimen ja yrityksen.</div></div>
    <div class="field"><label for="gt">Muistiinpano (vain ylläpito)</label><textarea id="gt" rows="2" maxlength="500">${esc(cur.note || '')}</textarea></div>
    <div id="gerr" class="err" hidden></div>
    <div style="display:flex;gap:8px;justify-content:flex-end"><button class="btn ghost" value="cancel" type="submit">Peruuta</button><button class="btn primary" type="button" id="gok">Myönnä</button></div>
  </form>`;
  d.showModal();
  $('gok').onclick = async () => {
    const name = $('gn').value.trim();
    if (!name) { $('gerr').hidden = false; $('gerr').textContent = 'Nimi puuttuu.'; return; }
    const { data, error } = await sb().rpc('admin_grant_installer', { p_email: cur.email, p_display_name: name, p_company: $('gc').value.trim(), p_note: $('gt').value.trim() });
    if (error) { $('gerr').hidden = false; $('gerr').textContent = errText(error); return; }
    d.close(); userHits = null;
    toast(`Asentaja ${data?.public_id || ''}: ${name}`, 4000);
    renderInstallers();
  };
}

// --- settings ------------------------------------------------------------------------------------
function renderSettings() {
  const s = settings;
  app().innerHTML = `<div class="form" style="max-width:760px;padding:18px 0 50px">
    <h2 style="margin:0">Asetukset</h2>
    <div class="panel form">
      <div class="two">
        <div class="field"><label for="sn">Myyjän nimi</label><input id="sn" type="text" value="${esc(s.seller_name)}"><div class="hint">Näkyy viestien allekirjoituksessa ja tietosuojasivulla.</div></div>
        <div class="field"><label for="sc">Yhteyssähköposti</label><input id="sc" type="email" value="${esc(s.contact_email)}"><div class="hint">Asiakkaiden vastaukset ohjautuvat tänne. Näkyy tietosuojasivulla.</div></div>
      </div>
      <div class="field"><label for="se">Ilmoitus uusista tilauksista sähköpostiin</label><input id="se" type="text" value="${esc((s.notify_emails || []).join(', '))}"><div class="hint">Useampi pilkulla erotettuna.</div></div>
      <div class="field"><label for="st">Ilmoitus puhelimeen (ntfy-aihe)</label>
        <div style="display:flex;gap:8px"><input id="st" type="text" value="${esc(s.ntfy_topic)}" placeholder="tyhjä = ei ilmoitusta"><button class="btn small" type="button" id="stgen">Luo</button></div>
        <div class="hint">Tilaa sama aihe iPhonen ntfy-sovelluksessa palvelimelta https://ntfy.molaplan.com. Aiheen nimi on salasana – älä jaa sitä.</div></div>
    </div>
    <div class="panel form">
      <h2 style="font-size:17px;margin:0">Vastauspohjat</h2>
      <div class="muted">Paikkamerkit: {nimi} {numero} {hinta} {myyjä} {lataus} {sähköposti}. "{hinta}" tulee tilauksen tarjoushinnasta.</div>
      <div id="tpls" class="form"></div>
      <button class="btn small" type="button" id="tadd">+ Lisää pohja</button>
    </div>
    <button class="btn primary" type="button" id="ssave">Tallenna asetukset</button>
    <div class="panel form">
      <h2 style="font-size:17px;margin:0">Sähköposti ja lataukset</h2>
      <div class="muted">Testiviesti lähetetään vain omaan osoitteeseesi (${esc(me)}).</div>
      <div style="display:flex;gap:8px;flex-wrap:wrap">
        <button class="btn" type="button" id="stest">Lähetä testiviesti itselle</button>
        <button class="btn" type="button" id="ssync">Päivitä PC-sovellus latauksiin</button>
      </div>
      <div id="sres" class="muted"></div>
    </div>
    <div class="panel"><div class="muted">Kirjautuneena: ${esc(me)}</div><button class="btn ghost small" type="button" id="logout" style="margin-top:8px">Kirjaudu ulos</button></div>
  </div>`;
  let tpls = JSON.parse(JSON.stringify(s.reply_templates || []));
  const drawTpls = () => {
    $('tpls').innerHTML = tpls.map((tp, i) => `<details class="box"><summary>${esc(tp.title || 'Uusi pohja')}</summary><div class="form" style="margin-top:10px">
      <input type="text" data-k="title" data-i="${i}" value="${esc(tp.title)}" placeholder="Nimi (painike)">
      <input type="text" data-k="subject" data-i="${i}" value="${esc(tp.subject)}" placeholder="Aihe">
      <textarea data-k="body" data-i="${i}" style="min-height:140px" placeholder="Viesti">${esc(tp.body)}</textarea>
      <select class="in" data-k="status" data-i="${i}"><option value="">Ei tilan muutosta</option>${STATUSES.map(([v, l]) => `<option value="${v}" ${tp.status === v ? 'selected' : ''}>Vaihda tilaksi: ${l}</option>`).join('')}</select>
      <button class="btn ghost danger small" type="button" data-rm="${i}">Poista pohja</button></div></details>`).join('');
  };
  drawTpls();
  $('tpls').oninput = (e) => { const el = e.target; if (el.dataset.k) tpls[+el.dataset.i][el.dataset.k] = el.value; };
  $('tpls').onchange = $('tpls').oninput;
  $('tpls').onclick = (e) => { const b = e.target.closest('[data-rm]'); if (b) { tpls.splice(+b.dataset.rm, 1); drawTpls(); } };
  $('tadd').onclick = () => { tpls.push({ title: 'Uusi pohja', subject: 'Tilauksesi #{numero}', body: 'Hei {nimi},\n\n\n\nYstävällisin terveisin\n{myyjä}', status: '' }); drawTpls(); $('tpls').lastElementChild.open = true; };
  $('stgen').onclick = () => { const a = new Uint8Array(12); crypto.getRandomValues(a); $('st').value = `tilaukset-${[...a].map((x) => 'abcdefghijkmnpqrstuvwxyz23456789'[x % 32]).join('')}`; };
  $('ssave').onclick = async () => {
    const row = {
      id: 1, seller_name: $('sn').value.trim(), contact_email: $('sc').value.trim(),
      notify_emails: $('se').value.split(/[,;\s]+/).map((x) => x.trim()).filter(Boolean), ntfy_topic: $('st').value.trim(), reply_templates: tpls,
    };
    const { error } = await sb().from('shop_settings').upsert(row);
    if (error) return toast(`Virhe: ${error.message}`, 4000);
    await loadSettings(); toast('Asetukset tallennettu');
  };
  const call = async (path, label) => {
    $('sres').textContent = `${label}…`;
    const r = await fetch(`${API}/${path}`, { method: 'POST', headers: { authorization: `Bearer ${session.access_token}` } });
    const j = await r.json().catch(() => ({}));
    $('sres').textContent = j.ok ? `${label}: OK ${j.file ? `(${j.file})` : ''}` : `${label}: ei onnistunut – ${j.error || r.status}`;
  };
  $('stest').onclick = () => call('test-email', 'Testiviesti');
  $('ssync').onclick = () => call('sync-pc', 'PC-sovelluksen päivitys');
  $('logout').onclick = async () => { await sb().auth.signOut(); location.hash = ''; location.reload(); };
}

window.addEventListener('DOMContentLoaded', () => start().catch((e) => { app().innerHTML = `<div class="err">Virhe: ${esc(e.message)}</div>`; }));
