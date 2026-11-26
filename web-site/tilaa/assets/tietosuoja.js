import { LOGO, SUPABASE_URL, SUPABASE_KEY, esc, pickLang } from './common.js';
const $ = (id) => document.getElementById(id);
let lang = pickLang();
function show() {
  const l = lang === 'fi' ? 'fi' : 'en';
  $('fi').hidden = l !== 'fi'; $('en').hidden = l !== 'en';
  document.documentElement.lang = l; $('lang').value = lang;
  $('brand').innerHTML = `${LOGO}<span>Molaplan <small>· ${l === 'fi' ? 'Tietosuoja' : 'Privacy'}</small></span>`;
}
$('lang').onchange = (e) => { lang = e.target.value; localStorage.setItem('molaplan-shop-lang', lang); show(); };
show();
fetch(`${SUPABASE_URL}/rest/v1/rpc/shop_public_info`, { method: 'POST', headers: { apikey: SUPABASE_KEY, authorization: `Bearer ${SUPABASE_KEY}`, 'content-type': 'application/json' }, body: '{}' })
  .then((r) => r.json()).then((i) => {
    if (i?.seller_name) document.querySelectorAll('[data-seller]').forEach((el) => { el.textContent = i.seller_name; });
    if (i?.contact_email) document.querySelectorAll('[data-contact]').forEach((el) => { el.textContent = i.contact_email; el.href = `mailto:${esc(i.contact_email)}`; });
  }).catch(() => {});
