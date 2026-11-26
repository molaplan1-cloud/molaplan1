// Molaplan order shop – customer side. Cart in localStorage; order goes to /tilaa/api/order.
import { API, SUPABASE_URL, SUPABASE_KEY, IMG_BASE, LOGO, ICONS, esc, eur, toast, pickLang, ptext } from './common.js';
import { STR } from './i18n.js';

const CART_KEY = 'molaplan-shop-cart-v1';
const $ = (id) => document.getElementById(id);
let lang = pickLang();
let t = STR[lang];
let products = [];
let cat = '';
let cart = loadCart();
let turnstileId = null;
let config = { turnstile_sitekey: '' };

function loadCart() {
  try { const c = JSON.parse(localStorage.getItem(CART_KEY) || '[]'); return Array.isArray(c) ? c : []; } catch { return []; }
}
function saveCart() { localStorage.setItem(CART_KEY, JSON.stringify(cart)); renderCartCount(); }
const byId = (id) => products.find((p) => p.id === id);

function catLabel(p) {
  return (lang !== 'fi' && p.i18n?.[lang]?.category) || t.cats[p.category] || p.category;
}
function priceHtml(p) {
  if (p.price_mode === 'fixed' && p.price_cents != null) {
    return `<span class="price">${esc(eur(p.price_cents, lang))}${p.price_note ? ` <small>${esc(p.price_note)}</small>` : ''}</span>`;
  }
  return `<span class="price quote">${esc(t.quote)}</span>`;
}
function imgHtml(p) {
  return p.image_path ? `<img src="${IMG_BASE}${encodeURI(p.image_path)}" alt="" loading="lazy">` : (ICONS[p.kind] || ICONS.device);
}

// --- static texts --------------------------------------------------------------------------
function applyTexts() {
  t = STR[lang];
  document.documentElement.lang = lang;
  $('lang').value = lang;
  $('brand').innerHTML = `${LOGO}<span>Molaplan <small>· ${esc(t.title)}</small></span>`;
  $('cartIcon').innerHTML = ICONS.cart;
  $('cartLabel').textContent = t.cart;
  $('heroH').textContent = t.heroH;
  $('heroP').textContent = t.heroP;
  $('noteIcon').innerHTML = ICONS.info;
  $('nonbinding').textContent = t.nonbinding;
  $('nonbinding2').textContent = t.footerNote;
  $('checkoutH').textContent = t.checkoutH;
  document.querySelectorAll('[data-t]').forEach((el) => { el.textContent = t[el.dataset.t]; });
  $('consentText').innerHTML = t.consent(`/tilaa/tietosuoja/?lang=${lang}`);
  $('sendBtn').textContent = t.send;
  $('summaryH').textContent = t.summary;
  $('editCart').textContent = t.edit;
  $('drawerH').textContent = t.cart;
  $('drawerClose').innerHTML = ICONS.close;
  $('toCheckout').textContent = t.toCheckout;
  $('thanksIcon').innerHTML = ICONS.check;
  $('thanksH').textContent = t.thanksH;
  $('thanksSpam').textContent = t.thanksSpam;
  $('thanksBack').textContent = t.back;
  $('lnkPrivacy').textContent = t.privacy;
  $('lnkPrivacy').href = `/tilaa/tietosuoja/?lang=${lang}`;
  $('lnkDownloads').textContent = t.downloads;
  $('footerNote').textContent = t.footerNote;
  document.title = `${t.title} – Molaplan`;
}

// --- catalog ---------------------------------------------------------------------------------
async function loadProducts() {
  try {
    const r = await fetch(`${SUPABASE_URL}/rest/v1/shop_products?select=id,sort,category,kind,name,summary,description,i18n,price_mode,price_cents,price_note,image_path,allow_quantity,max_quantity,ask_notes,notes_label&order=sort.asc,name.asc`,
      { headers: { apikey: SUPABASE_KEY, authorization: `Bearer ${SUPABASE_KEY}` } });
    if (!r.ok) throw new Error(r.status);
    products = await r.json();
    // Drop cart lines whose product disappeared or was hidden.
    const before = cart.length;
    cart = cart.filter((c) => byId(c.id));
    if (cart.length !== before) saveCart();
  } catch {
    $('grid').innerHTML = `<div class="empty">${esc(t.loadFail)}</div>`;
    return;
  }
  renderCats(); renderGrid(); renderCartCount();
}

function renderCats() {
  const cats = [...new Set(products.map((p) => p.category))];
  if (cats.length < 2) { $('cats').innerHTML = ''; return; }
  const chip = (value, label, n) => `<button class="chip" type="button" data-cat="${esc(value)}" aria-pressed="${cat === value}">${esc(label)}<span class="n">${n}</span></button>`;
  $('cats').innerHTML = chip('', t.all, products.length) +
    cats.map((c) => chip(c, catLabel(products.find((p) => p.category === c)), products.filter((p) => p.category === c).length)).join('');
}

function renderGrid() {
  const list = products.filter((p) => !cat || p.category === cat);
  if (!list.length) { $('grid').innerHTML = `<div class="empty">${esc(t.noProducts)}</div>`; return; }
  $('grid').innerHTML = list.map((p) => {
    const inCart = cart.filter((c) => c.id === p.id).reduce((a, c) => a + c.qty, 0);
    return `<article class="card" data-id="${p.id}">
      <div class="img" data-open="${p.id}">${imgHtml(p)}</div>
      <div class="body">
        <div class="cat">${esc(catLabel(p))}</div>
        <h3 data-open="${p.id}">${esc(ptext(p, lang, 'name'))}</h3>
        <p>${esc(ptext(p, lang, 'summary'))}</p>
        ${priceHtml(p)}
        <div class="row">
          <button class="btn small ghost" type="button" data-open="${p.id}">${esc(t.details)}</button>
          ${inCart ? `<span class="in-cart">${esc(t.inCart(inCart))}</span>` : ''}
          <button class="btn small primary" type="button" data-add="${p.id}">${esc(t.add)}</button>
        </div>
      </div></article>`;
  }).join('');
}

function openProduct(id) {
  const p = byId(id);
  if (!p) return;
  const d = $('pdlg');
  d.innerHTML = `<form method="dialog" class="pd">
    <div class="dimg">${imgHtml(p)}</div>
    <div class="dbody">
      <div class="cat" style="font-size:12px;letter-spacing:.12em;text-transform:uppercase;color:var(--teal);font-weight:700">${esc(catLabel(p))}</div>
      <h2>${esc(ptext(p, lang, 'name'))}</h2>
      ${priceHtml(p)}
      <div class="desc">${esc(ptext(p, lang, 'description') || ptext(p, lang, 'summary'))}</div>
      <div class="form">
        ${p.allow_quantity ? `<div class="field"><span class="lbl">${esc(t.qty)}</span>${qtyHtml('dq', 1, p.max_quantity)}</div>` : ''}
        ${p.ask_notes ? `<div class="field"><label class="lbl" for="dn">${esc((lang === 'fi' && p.notes_label) || t.notes)}</label><textarea id="dn" maxlength="1000" style="min-height:70px"></textarea></div>` : ''}
        <div style="display:flex;gap:10px;justify-content:flex-end;flex-wrap:wrap">
          <button class="btn ghost" value="cancel">${esc(t.continueShopping)}</button>
          <button class="btn primary" value="add" id="dAdd">${esc(t.add)}</button>
        </div>
      </div>
    </div></form>`;
  bindQty(d);
  d.querySelector('#dAdd').addEventListener('click', (e) => {
    e.preventDefault();
    const q = p.allow_quantity ? parseInt(d.querySelector('#dq').value, 10) || 1 : 1;
    addToCart(p.id, q, d.querySelector('#dn')?.value || '');
    d.close();
  });
  d.showModal();
}

function qtyHtml(id, v, max) {
  return `<span class="qty"><button type="button" data-step="-1" aria-label="−">−</button><input id="${id}" type="number" inputmode="numeric" min="1" max="${max}" value="${v}" aria-label="${esc(t.qty)}"><button type="button" data-step="1" aria-label="+">+</button></span>`;
}
function bindQty(root, onChange) {
  root.querySelectorAll('.qty').forEach((q) => {
    const input = q.querySelector('input');
    const clamp = () => { input.value = Math.max(1, Math.min(+input.max || 999, parseInt(input.value, 10) || 1)); onChange?.(+input.value); };
    q.querySelectorAll('button').forEach((b) => b.addEventListener('click', () => { input.value = (parseInt(input.value, 10) || 1) + +b.dataset.step; clamp(); }));
    input.addEventListener('change', clamp);
  });
}

function addToCart(id, qty = 1, notes = '') {
  const p = byId(id);
  if (!p) return;
  const line = cart.find((c) => c.id === id && (c.notes || '') === (notes || ''));
  if (line) line.qty = Math.min(p.allow_quantity ? p.max_quantity : 1, line.qty + qty);
  else cart.push({ id, qty: Math.min(p.allow_quantity ? p.max_quantity : 1, qty), notes });
  saveCart(); renderGrid(); toast(t.added);
}

// --- cart drawer ------------------------------------------------------------------------------
function renderCartCount() {
  const n = cart.reduce((a, c) => a + c.qty, 0);
  $('cartCount').hidden = n === 0;
  $('cartCount').textContent = n;
}
function openCart() { renderCartLines(); $('drawer').hidden = false; $('scrim').hidden = false; $('drawerClose').focus(); }
function closeCart() { $('drawer').hidden = true; $('scrim').hidden = true; }
function renderCartLines() {
  $('toCheckout').disabled = cart.length === 0;
  if (!cart.length) { $('cartLines').innerHTML = `<div class="empty">${esc(t.emptyCart)}</div>`; return; }
  $('cartLines').innerHTML = cart.map((c, i) => {
    const p = byId(c.id);
    if (!p) return '';
    return `<div class="cartline" data-i="${i}">
      <div><div class="name">${esc(ptext(p, lang, 'name'))}</div>${priceHtml(p)}</div>
      <div style="display:flex;flex-direction:column;align-items:flex-end;gap:6px">
        ${p.allow_quantity ? qtyHtml(`cq${i}`, c.qty, p.max_quantity) : ''}
        <button class="btn small ghost danger" type="button" data-rm="${i}">${esc(t.remove)}</button>
      </div>
      ${p.ask_notes ? `<div class="sub"><textarea data-notes="${i}" maxlength="1000" placeholder="${esc((lang === 'fi' && p.notes_label) || t.notes)}" style="min-height:56px">${esc(c.notes)}</textarea></div>` : ''}
    </div>`;
  }).join('');
  $('cartLines').querySelectorAll('.cartline').forEach((el) => {
    const i = +el.dataset.i;
    bindQty(el, (v) => { cart[i].qty = v; saveCart(); });
  });
}

// --- checkout ----------------------------------------------------------------------------------
const needsAddress = () => cart.some((c) => byId(c.id) && byId(c.id).kind !== 'software');
function renderCheckout() {
  const lines = cart.map((c) => byId(c.id) ? `<div class="line"><span>${esc(ptext(byId(c.id), lang, 'name'))} × ${c.qty}${c.notes ? `<br><small style="color:var(--mut)">${esc(c.notes)}</small>` : ''}</span><span>${priceHtml(byId(c.id))}</span></div>` : '').join('');
  $('summaryLines').innerHTML = lines || `<div class="empty">${esc(t.emptyCart)}</div>`;
  $('addrHint').textContent = needsAddress() ? '' : t.addressOpt;
  $('f_address').required = needsAddress();
  const saved = JSON.parse(sessionStorage.getItem('molaplan-shop-form') || '{}');
  for (const k of ['name', 'email', 'phone', 'address', 'message']) if (saved[k] && !$(`f_${k}`).value) $(`f_${k}`).value = saved[k];
  ensureTurnstile();
}
function ensureTurnstile() {
  if (!config.turnstile_sitekey || turnstileId !== null) return;
  const go = () => { turnstileId = window.turnstile.render('#tsBox', { sitekey: config.turnstile_sitekey, language: lang, theme: 'dark', size: 'flexible' }); };
  if (window.turnstile) return go();
  const s = document.createElement('script');
  s.src = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
  s.async = true; s.onload = go;
  document.head.appendChild(s);
}

async function submit(e) {
  e.preventDefault();
  const f = e.target;
  const err = (code) => { $('formErr').textContent = t.errors[code] || t.errors.server; $('formErr').hidden = false; $('formErr').scrollIntoView({ block: 'center', behavior: 'smooth' }); };
  $('formErr').hidden = true;
  const data = {
    name: $('f_name').value.trim(), email: $('f_email').value.trim(), phone: $('f_phone').value.trim(), address: $('f_address').value.trim(),
    message: $('f_message').value.trim(), website: f.querySelector('[name=website]').value, consent: $('f_consent').checked, lang,
    items: cart.map((c) => ({ product_id: c.id, qty: c.qty, notes: c.notes || '' })),
  };
  sessionStorage.setItem('molaplan-shop-form', JSON.stringify({ name: data.name, email: data.email, phone: data.phone, address: data.address, message: data.message }));
  if (!cart.length) return err('empty_cart');
  if (!data.name) { $('f_name').focus(); return err('name'); }
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(data.email)) { $('f_email').focus(); return err('email'); }
  if (needsAddress() && !data.address) { $('f_address').focus(); return err('address'); }
  if (!data.consent) return err('consent');
  if (config.turnstile_sitekey) {
    data.turnstile = window.turnstile?.getResponse(turnstileId) || '';
    if (!data.turnstile) return err('captcha');
  }
  const btn = $('sendBtn');
  btn.disabled = true; btn.innerHTML = `<span class="spin"></span> ${esc(t.sending)}`;
  try {
    const r = await fetch(`${API}/order`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(data) });
    const j = await r.json().catch(() => ({}));
    if (!r.ok || !j.ok) {
      if (config.turnstile_sitekey && window.turnstile) window.turnstile.reset(turnstileId);
      return err(j.error || 'server');
    }
    cart = []; saveCart();
    sessionStorage.removeItem('molaplan-shop-form');
    f.reset();
    sessionStorage.setItem('molaplan-shop-last', String(j.number));
    sessionStorage.setItem('molaplan-shop-sent', j.confirmation_sent ? '1' : '');
    location.hash = '#/kiitos';
  } catch {
    err('network');
  } finally {
    btn.disabled = false; btn.textContent = t.send;
  }
}

// --- routing -------------------------------------------------------------------------------------
function route() {
  const h = location.hash;
  const show = (v) => { for (const id of ['viewShop', 'viewCheckout', 'viewThanks']) $(id).hidden = id !== v; };
  closeCart();
  if (h === '#/tilaus') {
    if (!cart.length) { location.hash = '#/'; return; }
    show('viewCheckout'); renderCheckout();
  } else if (h === '#/kiitos') {
    show('viewThanks');
    const sent = !!sessionStorage.getItem('molaplan-shop-sent');
    $('thanksP').innerHTML = t.thanksP(esc(sessionStorage.getItem('molaplan-shop-last') || ''), sent);
    $('thanksSpam').hidden = !sent;
  } else if (h === '#/kori') {
    show('viewShop'); openCart();
  } else show('viewShop');
  window.scrollTo(0, 0);
}

// --- wiring --------------------------------------------------------------------------------------
applyTexts();
$('lang').addEventListener('change', (e) => {
  lang = e.target.value; localStorage.setItem('molaplan-shop-lang', lang);
  const u = new URL(location.href); u.searchParams.set('lang', lang); history.replaceState(null, '', u);
  applyTexts(); renderCats(); renderGrid(); renderCartCount();
  if (!$('drawer').hidden) renderCartLines();
  if (!$('viewCheckout').hidden) renderCheckout();
  if (!$('viewThanks').hidden) route();
});
$('cartBtn').addEventListener('click', openCart);
$('drawerClose').addEventListener('click', closeCart);
$('scrim').addEventListener('click', closeCart);
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !$('drawer').hidden) closeCart(); });
$('toCheckout').addEventListener('click', () => { closeCart(); location.hash = '#/tilaus'; });
$('editCart').addEventListener('click', () => { location.hash = '#/kori'; });
$('thanksBack').addEventListener('click', (e) => { e.preventDefault(); location.hash = '#/'; });
$('cats').addEventListener('click', (e) => {
  const b = e.target.closest('[data-cat]'); if (!b) return;
  cat = b.dataset.cat; renderCats(); renderGrid();
});
$('grid').addEventListener('click', (e) => {
  const a = e.target.closest('[data-add]');
  if (a) {
    const p = byId(a.dataset.add);
    // Products that ask for details open the detail dialog so the customer can fill them in.
    if (p?.ask_notes && p.kind !== 'software') return openProduct(p.id);
    return addToCart(a.dataset.add);
  }
  const o = e.target.closest('[data-open]');
  if (o) openProduct(o.dataset.open);
});
$('cartLines').addEventListener('click', (e) => {
  const rm = e.target.closest('[data-rm]');
  if (rm) { cart.splice(+rm.dataset.rm, 1); saveCart(); renderCartLines(); renderGrid(); }
});
$('cartLines').addEventListener('input', (e) => {
  const n = e.target.dataset?.notes;
  if (n != null) { cart[+n].notes = e.target.value.slice(0, 1000); saveCart(); }
});
$('pdlg').addEventListener('click', (e) => { if (e.target === $('pdlg')) $('pdlg').close(); });
$('orderForm').addEventListener('submit', submit);
$('orderForm').addEventListener('input', () => { $('formErr').hidden = true; });
window.addEventListener('hashchange', route);
window.addEventListener('storage', (e) => { if (e.key === CART_KEY) { cart = loadCart(); renderCartCount(); renderGrid(); } });

fetch(`${API}/config`).then((r) => r.ok ? r.json() : {}).then((c) => { config = { ...config, ...c }; if (!$('viewCheckout').hidden) ensureTurnstile(); }).catch(() => {});
loadProducts().then(route);
