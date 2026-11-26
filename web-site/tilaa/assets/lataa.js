// Customer downloads: sign in with the Molaplan account (same email as the order) -> PC app link once paid.
import { API, LOGO, esc, toast, sb, pickLang } from './common.js';

const $ = (id) => document.getElementById(id);
let lang = pickLang();
const S = {
  fi: { h: 'Lataukset', p: 'Kirjaudu Molaplan-tilillä, jonka sähköposti on sama kuin tilauksessasi. PC-sovelluksen lataus avautuu, kun tilaus on maksettu.',
    email: 'Sähköposti', send: 'Lähetä kirjautumiskoodi', code: 'Sähköpostiin tullut koodi', login: 'Kirjaudu', sent: 'Koodi lähetetty',
    ready: 'PC-sovellus (Windows) on valmis ladattavaksi.', dl: 'Lataa PC-sovellus', exp: 'Linkki on voimassa tunnin. Pura zip-tiedosto ja käynnistä molaplan.exe.',
    locked: 'Tilillesi ei ole vielä avattu latauksia. Lataus avautuu, kun PC-sovelluksen tilaus on merkitty maksetuksi.', orders: 'Tilauksesi', none: 'Tällä sähköpostilla ei löytynyt tilauksia.',
    logout: 'Kirjaudu ulos', as: 'Kirjautuneena', back: 'Tilaussivulle', status: { uusi: 'vastaanotettu', tarjottu: 'tarjous lähetetty', laskutettu: 'laskutettu', maksettu: 'maksettu', toimitettu: 'toimitettu', peruttu: 'peruttu' } },
  en: { h: 'Downloads', p: 'Sign in with the Molaplan account that uses the same email as your order. The PC app download opens once the order is paid.',
    email: 'Email', send: 'Send sign-in code', code: 'Code from your email', login: 'Sign in', sent: 'Code sent',
    ready: 'The PC app (Windows) is ready to download.', dl: 'Download the PC app', exp: 'The link is valid for one hour. Unzip the file and start molaplan.exe.',
    locked: 'No downloads are open for your account yet. The download opens once the PC app order is marked as paid.', orders: 'Your orders', none: 'No orders found for this email.',
    logout: 'Sign out', as: 'Signed in as', back: 'Back to ordering', status: { uusi: 'received', tarjottu: 'offer sent', laskutettu: 'invoiced', maksettu: 'paid', toimitettu: 'delivered', peruttu: 'cancelled' } },
};
S.sv = { ...S.en, h: 'Nedladdningar', send: 'Skicka inloggningskod', login: 'Logga in', dl: 'Ladda ner PC-appen', logout: 'Logga ut', back: 'Till beställningen',
  p: 'Logga in med det Molaplan-konto som har samma e-post som din beställning. Nedladdningen öppnas när beställningen är betald.' };
S.es = { ...S.en, h: 'Descargas', send: 'Enviar código', login: 'Entrar', dl: 'Descargar la app para PC', logout: 'Cerrar sesión', back: 'Volver a pedidos',
  p: 'Inicia sesión con la cuenta Molaplan que usa el mismo correo que tu pedido. La descarga se abre cuando el pedido está pagado.' };

async function render() {
  const t = S[lang];
  document.documentElement.lang = lang;
  $('lang').value = lang;
  $('brand').innerHTML = `${LOGO}<span>Molaplan <small>· ${esc(t.h)}</small></span>`;
  const { data } = await sb().auth.getSession();
  const s = data.session;
  if (!s) {
    $('app').innerHTML = `<h1>${esc(t.h)}</h1><p>${esc(t.p)}</p>
      <div class="panel form" style="max-width:440px">
        <div class="field"><label for="le">${esc(t.email)}</label><input id="le" type="email" autocomplete="username"></div>
        <div class="field" id="cs" hidden><label for="lc">${esc(t.code)}</label><input id="lc" type="text" inputmode="numeric" autocomplete="one-time-code"></div>
        <button class="btn primary" id="ls">${esc(t.send)}</button><button class="btn primary" id="lv" hidden>${esc(t.login)}</button>
      </div><p><a href="/tilaa/">${esc(t.back)}</a></p>`;
    $('ls').onclick = async () => {
      const email = $('le').value.trim().toLowerCase(); if (!email) return;
      const { error } = await sb().auth.signInWithOtp({ email, options: { shouldCreateUser: true } });
      if (error) return toast(error.message, 4000);
      $('cs').hidden = false; $('lv').hidden = false; toast(t.sent);
    };
    $('lv').onclick = async () => {
      const { error } = await sb().auth.verifyOtp({ email: $('le').value.trim().toLowerCase(), token: $('lc').value.trim(), type: 'email' });
      if (error) return toast(error.message, 4000);
      render();
    };
    return;
  }
  $('app').innerHTML = `<h1>${esc(t.h)}</h1><div class="empty"><span class="spin"></span></div>`;
  const r = await fetch(`${API}/download`, { method: 'POST', headers: { authorization: `Bearer ${s.access_token}` } });
  const j = await r.json().catch(() => ({}));
  const orders = j.orders || [];
  $('app').innerHTML = `<h1>${esc(t.h)}</h1>
    ${j.ok && j.url ? `<div class="panel"><p style="margin-top:0">${esc(t.ready)}</p><a class="btn primary" href="${esc(j.url)}" rel="noopener">${esc(t.dl)}</a><p class="muted" style="color:var(--mut)">${esc(j.file || '')}<br>${esc(t.exp)}</p></div>`
      : `<div class="note">${esc(t.locked)}</div>`}
    <h2>${esc(t.orders)}</h2>
    ${orders.length ? `<ul>${orders.map((o) => `<li>#${o.number} – ${esc(t.status[o.status] || o.status)} (${new Date(o.created_at).toLocaleDateString(lang)})</li>`).join('')}</ul>` : `<p>${esc(t.none)}</p>`}
    <p class="muted" style="color:var(--mut)">${esc(t.as)} ${esc(s.user.email)}</p>
    <button class="btn ghost small" id="lo">${esc(t.logout)}</button> <a class="btn ghost small" href="/tilaa/">${esc(t.back)}</a>`;
  $('lo').onclick = async () => { await sb().auth.signOut(); render(); };
}
$('lang').onchange = (e) => { lang = e.target.value; localStorage.setItem('molaplan-shop-lang', lang); render(); };
window.addEventListener('DOMContentLoaded', render);
