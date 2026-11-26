// Molaplan order shop Worker (R240). Static pages come from ./public; this handles /tilaa/api/*.
import { validateOrder, confirmationEmail, ownerEmail, textToHtml, cleanStr, STATUSES } from './lib.js';

const json = (data, status = 200, extra = {}) =>
  new Response(JSON.stringify(data), { status, headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', ...extra } });


export default {
  async fetch(req, env, ctx) {
    const url = new URL(req.url);
    const p = url.pathname;
    if (p === '/en/order' || p.startsWith('/en/order/')) return Response.redirect(`${url.origin}/tilaa/?lang=en`, 302);
    if (p === '/tilaa' || p === '/') return Response.redirect(`${url.origin}/tilaa/${url.search}`, 301);
    if (p.startsWith('/tilaa/api/')) {
      const cors = corsHeaders(req.headers.get('origin'));
      if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
      let res;
      try {
        res = await api(req, env, ctx, p.slice('/tilaa/api/'.length));
      } catch (e) {
        console.error('api error', e?.stack || e);
        res = json({ error: 'server' }, 500);
      }
      for (const [k, v] of Object.entries(cors)) res.headers.set(k, v);
      return res;
    }
    // Only reached when no static file matched (static files are served before the Worker).
    const nf = await env.ASSETS.fetch(new Request(`${url.origin}/tilaa/404.html`));
    return new Response(nf.body, { status: 404, headers: nf.headers });
  },
};

async function api(req, env, ctx, route) {
  const ip = req.headers.get('cf-connecting-ip') || 'x';
  if (env.API_LIMIT) {
    const { success } = await env.API_LIMIT.limit({ key: ip });
    if (!success) return json({ error: 'rate_limited' }, 429);
  }
  if (route === 'config' && req.method === 'GET') {
    return json({ turnstile_sitekey: env.TURNSTILE_SITEKEY || '', supabase_url: env.SUPABASE_URL, supabase_key: env.SUPABASE_KEY },
      200, { 'cache-control': 'public, max-age=300' });
  }
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const origin = req.headers.get('origin');
  if (origin && !isAllowedOrigin(origin, req.url)) return json({ error: 'origin' }, 403);
  if (route === 'order') return submitOrder(req, env, ctx, ip);
  if (route === 'reply') return adminReply(req, env);
  if (route === 'download') return download(req, env);
  if (route === 'sync-pc') return syncPc(req, env);
  if (route === 'test-email') return testEmail(req, env);
  return json({ error: 'not_found' }, 404);
}

export const ALLOWED_ORIGINS = ['https://molaplan.com', 'https://www.molaplan.com', 'https://shop.molaplan.com', 'https://molaplan.pages.dev'];

function isAllowedOrigin(origin, reqUrl) {
  try {
    const o = new URL(origin);
    return o.origin === new URL(reqUrl).origin || ALLOWED_ORIGINS.includes(o.origin) || o.hostname.endsWith('.molaplan.pages.dev');
  } catch { return false; }
}

function corsHeaders(origin) {
  if (!origin || !isAllowedOrigin(origin, 'https://shop.molaplan.com/')) return { vary: 'Origin' };
  return {
    'access-control-allow-origin': origin,
    'access-control-allow-methods': 'GET, POST, OPTIONS',
    'access-control-allow-headers': 'content-type, authorization',
    'access-control-max-age': '86400',
    vary: 'Origin',
  };
}

// --- Supabase helpers ---------------------------------------------------------------------------
function sbHeaders(env, jwt) {
  return { apikey: env.SUPABASE_KEY, authorization: `Bearer ${jwt || env.SUPABASE_KEY}`, 'content-type': 'application/json' };
}
async function rpc(env, fn, args, jwt) {
  const r = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/${fn}`, { method: 'POST', headers: sbHeaders(env, jwt), body: JSON.stringify(args) });
  const body = await r.text();
  let data = null;
  try { data = body ? JSON.parse(body) : null; } catch { data = body; }
  return { ok: r.ok, status: r.status, data };
}
async function rest(env, jwt, path, init = {}) {
  const r = await fetch(`${env.SUPABASE_URL}/rest/v1/${path}`, {
    ...init, headers: { ...sbHeaders(env, jwt), prefer: 'return=representation', ...(init.headers || {}) },
  });
  const body = await r.text();
  let data = null;
  try { data = body ? JSON.parse(body) : null; } catch { data = body; }
  return { ok: r.ok, status: r.status, data };
}
function bearer(req) {
  const h = req.headers.get('authorization') || '';
  return h.startsWith('Bearer ') ? h.slice(7) : '';
}
async function requireAdmin(req, env) {
  const jwt = bearer(req);
  if (!jwt) return null;
  const r = await rpc(env, 'is_shop_admin', {}, jwt);
  if (!r.ok || r.data !== true) return null;
  const u = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, { headers: sbHeaders(env, jwt) });
  const user = u.ok ? await u.json() : {};
  return { jwt, email: user.email || '' };
}

// --- email ----------------------------------------------------------------------------------------
// Email: Resend (molaplan.com is verified there; free tier sends to anyone) when RESEND_API_KEY is set,
// otherwise Cloudflare Email Service (on the Workers Free plan only to verified addresses).
async function sendMail(env, { to, subject, text, html, replyTo }) {
  if (env.RESEND_API_KEY) {
    try {
      const r = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { authorization: `Bearer ${env.RESEND_API_KEY}`, 'content-type': 'application/json' },
        body: JSON.stringify({ from: `${env.MAIL_FROM_NAME || 'Molaplan'} <${env.MAIL_FROM}>`, to: [to], subject, text,
          html: html || textToHtml(text), ...(replyTo ? { reply_to: replyTo } : {}) }),
      });
      if (r.ok) return { ok: true };
      return { ok: false, error: `resend ${r.status}: ${(await r.text()).slice(0, 300)}` };
    } catch (e) {
      return { ok: false, error: `resend: ${String(e?.message || e).slice(0, 300)}` };
    }
  }
  if (!env.EMAIL) return { ok: false, error: 'no_email_binding' };
  try {
    await env.EMAIL.send({
      from: { email: env.MAIL_FROM, name: env.MAIL_FROM_NAME || 'Molaplan' },
      to, subject, text, html: html || textToHtml(text), ...(replyTo ? { replyTo } : {}),
    });
    return { ok: true };
  } catch (e) {
    return { ok: false, error: `${e?.code || 'error'}: ${String(e?.message || e).slice(0, 300)}` };
  }
}

async function ntfy(env, topic, title, message, click) {
  if (!topic) return;
  try {
    await fetch(`${env.NTFY_BASE}/${encodeURIComponent(topic)}`, {
      method: 'POST', body: message,
      headers: { Title: title.replace(/[^\x20-\x7e]/g, '?'), Tags: 'shopping_cart', Priority: '4', ...(click ? { Click: click } : {}) },
    });
  } catch (e) { console.error('ntfy', e); }
}

// --- order submit ----------------------------------------------------------------------------------
async function submitOrder(req, env, ctx, ip) {
  if (env.ORDER_LIMIT) {
    const { success } = await env.ORDER_LIMIT.limit({ key: ip });
    if (!success) return json({ error: 'rate_limited' }, 429);
  }
  let body;
  try { body = await req.json(); } catch { return json({ error: 'bad_request' }, 400); }
  const v = validateOrder(body);
  if (!v.ok) return json({ error: v.error }, v.error === 'spam' ? 200 : 400);

  if (env.TURNSTILE_SECRET) {
    const fd = new FormData();
    fd.append('secret', env.TURNSTILE_SECRET);
    fd.append('response', String(body.turnstile || ''));
    fd.append('remoteip', ip);
    const tr = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', { method: 'POST', body: fd });
    const tj = await tr.json().catch(() => ({}));
    if (!tj.success) return json({ error: 'captcha' }, 400);
  }

  const r = await rpc(env, 'shop_submit_order', { p_secret: env.SHOP_SECRET, p: v.data });
  if (!r.ok) {
    const msg = String(r.data?.message || '');
    const code = msg.includes('unknown product') ? 'unknown_product' : msg.includes('too many orders') ? 'rate_limited'
      : msg.includes('empty cart') ? 'empty_cart' : 'server';
    console.error('submit failed', r.status, msg);
    return json({ error: code }, code === 'server' ? 500 : 400);
  }
  const order = r.data;
  const s = order.settings || {};
  const c = confirmationEmail(order, s, env.SITE_URL);
  const cr = await sendMail(env, { to: order.email, ...c, replyTo: s.contact_email || undefined });
  ctx.waitUntil(afterOrder(env, order, c, cr));
  return json({ ok: true, number: order.number, confirmation_sent: cr.ok === true });
}

async function afterOrder(env, order, c, cr) {
  const s = order.settings || {};
  const site = env.SITE_URL;
  const log = (kind, subject, text, res) => rpc(env, 'shop_log_message', {
    p_secret: env.SHOP_SECRET, p_order: order.id, p_kind: kind, p_subject: subject, p_body: text,
    p_delivered: res.ok, p_error: res.ok ? '' : res.error,
  });
  await log('auto', `Vahvistus asiakkaalle: ${c.subject}`, c.text, cr);
  const o = ownerEmail(order, site);
  for (const to of s.notify_emails || []) {
    const res = await sendMail(env, { to, ...o, replyTo: order.email });
    await log('auto', `Ilmoitus: ${to}`, '', res);
  }
  await ntfy(env, s.ntfy_topic, `Uusi tilaus #${order.number}`,
    `${order.name}: ${order.items.map((i) => `${i.name} x${i.qty}`).join(', ')}`, `${site}hallinta/#tilaus=${order.id}`);
}

// --- admin reply -----------------------------------------------------------------------------------
async function adminReply(req, env) {
  const admin = await requireAdmin(req, env);
  if (!admin) return json({ error: 'forbidden' }, 403);
  const b = await req.json().catch(() => ({}));
  const orderId = String(b.order_id || '');
  if (!/^[0-9a-f-]{36}$/i.test(orderId)) return json({ error: 'bad_request' }, 400);
  const subject = cleanStr(b.subject, 200);
  const text = String(b.body ?? '').slice(0, 20000).trim();
  if (!subject || !text) return json({ error: 'empty' }, 400);
  const o = await rest(env, admin.jwt, `shop_orders?id=eq.${orderId}&select=*`, { method: 'GET' });
  const order = Array.isArray(o.data) ? o.data[0] : null;
  if (!order) return json({ error: 'not_found' }, 404);
  const st = await rest(env, admin.jwt, 'shop_settings?id=eq.1&select=*', { method: 'GET' });
  const s = (Array.isArray(st.data) && st.data[0]) || {};

  const mode = b.mode === 'mailto' ? 'mailto' : 'send';
  let res = { ok: null, error: '' };
  if (mode === 'send') res = await sendMail(env, { to: order.email, subject, text, replyTo: s.contact_email || admin.email || undefined });

  await rest(env, admin.jwt, 'shop_order_messages', {
    method: 'POST',
    body: JSON.stringify({ order_id: orderId, kind: 'out', author: admin.email, subject, body: text,
      delivered: res.ok, error: res.ok === false ? res.error : (mode === 'mailto' ? 'mailto' : '') }),
  });
  const patch = { seen: true };
  if (STATUSES.includes(b.status) && (res.ok || mode === 'mailto')) patch.status = b.status;
  if (b.offer_cents != null && b.offer_cents !== '' && Number.isFinite(Number(b.offer_cents)) && Number(b.offer_cents) >= 0) {
    patch.offer_cents = Math.round(Number(b.offer_cents));
  }
  await rest(env, admin.jwt, `shop_orders?id=eq.${orderId}`, { method: 'PATCH', body: JSON.stringify(patch) });
  return json({ ok: res.ok !== false, delivered: res.ok, error: res.ok === false ? res.error : '' });
}

// One test email to the signed-in admin's own address (Settings → "Lähetä testiviesti").
async function testEmail(req, env) {
  const admin = await requireAdmin(req, env);
  if (!admin) return json({ error: 'forbidden' }, 403);
  const res = await sendMail(env, { to: admin.email, subject: 'Molaplan-tilaukset: testiviesti',
    text: 'Tämä on testiviesti Molaplanin tilaussivun hallinnasta. Sähköpostin lähetys toimii.' });
  return json({ ok: res.ok, error: res.error || '' });
}

// --- PC app download --------------------------------------------------------------------------------
async function latestPcAsset(env) {
  const r = await fetch(`https://api.github.com/repos/${env.GITHUB_REPO}/releases/latest`, {
    headers: { 'user-agent': 'molaplan-shop', accept: 'application/vnd.github+json' },
    cf: { cacheTtl: 300, cacheEverything: true },
  });
  if (!r.ok) return null;
  const rel = await r.json();
  const a = (rel.assets || []).find((x) => x.name === env.PC_ASSET);
  return a ? { tag: rel.tag_name, url: a.browser_download_url, size: a.size } : null;
}

async function download(req, env) {
  const jwt = bearer(req);
  if (!jwt) return json({ error: 'login' }, 401);
  const r = await rpc(env, 'my_shop_downloads', {}, jwt);
  if (!r.ok) return json({ error: 'login' }, 401);
  if (!r.data?.pc_app) return json({ ok: false, pc_app: false, orders: r.data?.orders || [] });
  // Prefer the private copy in Storage (signed, expires in 1 h); fall back to the release asset.
  const list = await fetch(`${env.SUPABASE_URL}/storage/v1/object/list/shop-downloads`, {
    method: 'POST', headers: sbHeaders(env, jwt),
    body: JSON.stringify({ prefix: 'pc', limit: 20, sortBy: { column: 'created_at', order: 'desc' } }),
  });
  const files = list.ok ? await list.json() : [];
  const f = (files || []).find((x) => x.name?.endsWith('.zip'));
  if (f) {
    const s = await fetch(`${env.SUPABASE_URL}/storage/v1/object/sign/shop-downloads/pc/${encodeURIComponent(f.name)}`, {
      method: 'POST', headers: sbHeaders(env, jwt), body: JSON.stringify({ expiresIn: 3600, download: f.name }),
    });
    const sj = await s.json().catch(() => ({}));
    if (s.ok && sj.signedURL) {
      return json({ ok: true, pc_app: true, file: f.name, url: `${env.SUPABASE_URL}/storage/v1${sj.signedURL}`, expires_in: 3600, orders: r.data.orders });
    }
  }
  const a = await latestPcAsset(env);
  if (!a) return json({ ok: false, pc_app: true, error: 'no_asset', orders: r.data.orders });
  return json({ ok: true, pc_app: true, file: `${env.PC_ASSET} (${a.tag})`, url: a.url, orders: r.data.orders });
}

// Admin: copies the latest release's Windows zip into the private bucket (pc/molaplan-windows-x64-<tag>.zip).
async function syncPc(req, env) {
  const admin = await requireAdmin(req, env);
  if (!admin) return json({ error: 'forbidden' }, 403);
  const a = await latestPcAsset(env);
  if (!a) return json({ error: 'no_asset' }, 502);
  const name = `pc/molaplan-windows-x64-${a.tag}.zip`;
  const dl = await fetch(a.url, { headers: { 'user-agent': 'molaplan-shop' } });
  if (!dl.ok) return json({ error: `download ${dl.status}` }, 502);
  const zip = await dl.arrayBuffer();
  const up = await fetch(`${env.SUPABASE_URL}/storage/v1/object/shop-downloads/${name}`, {
    method: 'POST',
    headers: { apikey: env.SUPABASE_KEY, authorization: `Bearer ${admin.jwt}`, 'content-type': 'application/zip', 'x-upsert': 'true' },
    body: zip,
  });
  if (!up.ok) return json({ error: `upload ${up.status}: ${(await up.text()).slice(0, 200)}` }, 502);
  return json({ ok: true, file: name, tag: a.tag, size: a.size });
}
