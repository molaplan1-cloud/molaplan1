// Molaplan – per-event pages for shareable URLs (/e/<uuid>[-slug]).
// Used by the Cloudflare Pages Functions in functions/ (free tier, no secrets: the public anon key + RLS-protected
// guest_events view) and by the unit tests (node test-share.js). Pure functions only; fetch is injected.
export const SITE = 'https://molaplan.com';
export const OG_IMAGE = SITE + '/og-image.png';
/* event kinds whose pages may be indexed by search engines. Community (user-made) events are shareable with full previews
   but marked noindex, so people's own meetups don't end up in search results (guests can still open them, as today). */
export const INDEX_KINDS = new Set(['public', 'business']);
export const GUEST_COLS = 'id,title,description,starts_at,ends_at,city,district,place,lat,lng,kind,organizer_name,business_name,price_info,official_url,is_adult';

const UUID_RE = /^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})(?:-[^/]*)?\/?$/i;
export function parseEventId(seg) { const m = UUID_RE.exec(String(seg == null ? '' : seg)); return m ? m[1].toLowerCase() : null; }
/* same algorithm as evSlug() in index.html */
export function slugify(t) { return String(t || '').normalize('NFKD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+/, '').slice(0, 48).replace(/-+$/, ''); }
export function eventPath(ev) { const s = slugify(ev.title); return '/e/' + ev.id + (s ? '-' + s : ''); }
export function esc(s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;'); }
/* JSON inside <script>: no "</script>", no HTML comments, no U+2028/9 */
export function jsonForScript(o) { return JSON.stringify(o).replace(/</g, '\\u003c').replace(/>/g, '\\u003e').replace(/&/g, '\\u0026').replace(/\u2028/g, '\\u2028').replace(/\u2029/g, '\\u2029'); }
const clean = s => String(s || '').replace(/\s+/g, ' ').trim();
export function clip(s, n) { s = clean(s); if (s.length <= n) return s; const c = s.slice(0, n - 1); const i = c.lastIndexOf(' '); return (i > n * 0.6 ? c.slice(0, i) : c).replace(/[\s,.;:–-]+$/, '') + '…'; }

const CC = { Helsinki: 'FI', Vantaa: 'FI', Espoo: 'FI', Tuusula: 'FI', Stockholm: 'SE', London: 'GB', Madrid: 'ES' };
const TZ = { FI: 'Europe/Helsinki', SE: 'Europe/Stockholm', GB: 'Europe/London', ES: 'Europe/Madrid' };
export const TXT = {
  fi: { locale: 'fi-FI', og: 'fi_FI', join: 'Lähde mukaan – Molaplanissa löydät seuraa harrastuksiin omassa kaupungissasi.', nfTitle: 'Tapahtumaa ei löytynyt', nfDesc: 'Tapahtuma voi olla jo ohi tai näkyä vain kirjautuneille. Katso, mitä lähelläsi tapahtuu Molaplanissa.' },
  en: { locale: 'en-GB', og: 'en_GB', join: 'Join in – Molaplan helps you find people for sports and hobbies in your city.', nfTitle: 'Event not found', nfDesc: 'The event may be over already or visible to signed-in users only. See what’s happening near you on Molaplan.' },
  es: { locale: 'es-ES', og: 'es_ES', join: 'Apúntate: en Molaplan encuentras gente para tus deportes y aficiones en tu ciudad.', nfTitle: 'Evento no encontrado', nfDesc: 'Puede que el evento ya haya terminado o que solo lo vean los usuarios con sesión iniciada. Mira lo que pasa cerca de ti en Molaplan.' },
  sv: { locale: 'sv-SE', og: 'sv_SE', join: 'Häng med – på Molaplan hittar du sällskap för sport och hobbyer i din stad.', nfTitle: 'Evenemanget hittades inte', nfDesc: 'Evenemanget kan redan vara över eller bara synas för inloggade. Se vad som händer nära dig på Molaplan.' }
};
export function pickLang(url) { const l = new URL(url).searchParams.get('lang'); return TXT[l] ? l : 'fi'; }
export function countryOf(city) { return CC[city] || null; }
export function formatWhen(iso, city, lang) {
  const d = new Date(iso); if (isNaN(d)) return '';
  const tz = TZ[countryOf(city) || 'FI'];
  try { return new Intl.DateTimeFormat(TXT[lang].locale, { weekday: 'short', day: 'numeric', month: 'numeric', hour: '2-digit', minute: '2-digit', timeZone: tz }).format(d); }
  catch (e) { return d.toISOString().slice(0, 16).replace('T', ' '); }
}

/* RLS-safe lookup: the anon key can only read the guest_events view (upcoming, not 18+, no host ids). */
export async function fetchGuestEvent(id, cfg, fetchImpl) {
  if (!id || !cfg || !cfg.url || !cfg.key) return { ev: null, error: 'config' };
  const u = cfg.url.replace(/\/+$/, '') + '/rest/v1/guest_events?select=' + GUEST_COLS + '&id=eq.' + encodeURIComponent(id) + '&limit=1';
  const r = await fetchImpl(u, { headers: { apikey: cfg.key, Authorization: 'Bearer ' + cfg.key, Accept: 'application/json' } });
  if (!r.ok) return { ev: null, error: 'http ' + r.status };
  const rows = await r.json();
  const ev = Array.isArray(rows) && rows[0] && rows[0].id === id && !rows[0].is_adult ? rows[0] : null;
  return { ev, error: null };
}
export function parseConfigJs(src) {
  const g = re => { const m = re.exec(String(src || '')); return m ? m[1] : ''; };
  return { url: g(/SUPABASE_URL\s*=\s*['"]([^'"]+)['"]/), key: g(/SUPABASE_ANON_KEY\s*=\s*['"]([^'"]+)['"]/) };
}

export function buildEventMeta(ev, lang) {
  const T = TXT[lang] || TXT.fi;
  const when = formatWhen(ev.starts_at, ev.city, lang);
  const where = [clean(ev.place), clean(ev.city)].filter(Boolean).join(', ');
  const url = SITE + eventPath(ev);
  const desc = clean(ev.description);
  const lead = [when, where].filter(Boolean).join(' · ');
  const description = clip(lead + '. ' + (desc || T.join), 160);
  const ogDescription = clip(lead + '. ' + (desc || T.join), 200);
  const org = clean(ev.business_name || ev.organizer_name);
  const cc = countryOf(ev.city);
  const ld = {
    '@context': 'https://schema.org', '@type': 'Event', name: clean(ev.title), url,
    startDate: ev.starts_at, eventStatus: 'https://schema.org/EventScheduled', eventAttendanceMode: 'https://schema.org/OfflineEventAttendanceMode',
    location: Object.assign({ '@type': 'Place', name: clean(ev.place) || clean(ev.city), address: Object.assign({ '@type': 'PostalAddress', addressLocality: clean(ev.city) }, ev.district ? { addressRegion: clean(ev.district) } : {}, cc ? { addressCountry: cc } : {}) },
      ev.lat != null && ev.lng != null ? { geo: { '@type': 'GeoCoordinates', latitude: Number(ev.lat), longitude: Number(ev.lng) } } : {}),
    image: [OG_IMAGE], description: clip(desc || lead, 300),
    organizer: org ? { '@type': 'Organization', name: org } : { '@type': 'Organization', name: 'Molaplan', url: SITE + '/' }
  };
  if (ev.ends_at) ld.endDate = ev.ends_at;
  if ((ev.kind || 'community') === 'community') ld.isAccessibleForFree = true;
  return {
    found: true, lang, url, title: clip(ev.title, 70) + (when ? ' · ' + when : '') + ' | Molaplan', ogTitle: clip(ev.title, 90) + (when ? ' – ' + when : ''),
    description, ogDescription, robots: INDEX_KINDS.has(ev.kind) ? 'index, follow, max-image-preview:large' : 'noindex, follow, max-image-preview:large',
    jsonLd: ld, h1: clean(ev.title), lead, body: desc, ogLocale: T.og
  };
}
export function buildNotFoundMeta(lang) {
  const T = TXT[lang] || TXT.fi;
  return { found: false, lang, url: SITE + '/', title: T.nfTitle + ' | Molaplan', ogTitle: T.nfTitle + ' – Molaplan', description: T.nfDesc, ogDescription: T.nfDesc, robots: 'noindex, follow', jsonLd: null, h1: T.nfTitle, lead: '', body: T.nfDesc, ogLocale: T.og };
}

/* Inject the meta into the deployed index.html (string edits on our own markup; each step is optional so a markup change
   never breaks the page – the unit test checks that every step still applies to the real index.html). */
export function injectMeta(html, m) {
  const steps = {};
  const rep = (name, re, val) => { let n = 0; html = html.replace(re, (...a) => { n++; return typeof val === 'function' ? val(...a) : val; }); steps[name] = n; };
  rep('title', /<title>[^<]*<\/title>/, '<title>' + esc(m.title) + '</title>');
  rep('description', /<meta name="description" content="[^"]*">/, '<meta name="description" content="' + esc(m.description) + '">');
  rep('canonical', /<link rel="canonical" href="[^"]*">/, '<link rel="canonical" href="' + esc(m.url) + '">');
  rep('hreflang', /[ \t]*<link rel="alternate" hreflang="[^"]*" href="[^"]*">\r?\n?/g, '');
  rep('robots', /<meta name="robots" content="[^"]*">/, '<meta name="robots" content="' + esc(m.robots) + '">');
  rep('ogUrl', /<meta property="og:url" content="[^"]*">/, '<meta property="og:url" content="' + esc(m.url) + '">');
  rep('ogTitle', /<meta property="og:title" content="[^"]*">/, '<meta property="og:title" content="' + esc(m.ogTitle) + '">');
  rep('ogDescription', /<meta property="og:description" content="[^"]*">/, '<meta property="og:description" content="' + esc(m.ogDescription) + '">');
  rep('ogLocale', /<meta property="og:locale" content="[^"]*">/, '<meta property="og:locale" content="' + esc(m.ogLocale) + '">');
  rep('twTitle', /<meta name="twitter:title" content="[^"]*">/, '<meta name="twitter:title" content="' + esc(m.ogTitle) + '">');
  rep('twDescription', /<meta name="twitter:description" content="[^"]*">/, '<meta name="twitter:description" content="' + esc(m.ogDescription) + '">');
  if (m.jsonLd) rep('jsonLd', /<\/head>/, '<script type="application/ld+json" id="ld-event">' + jsonForScript(m.jsonLd) + '</script>\n</head>');
  /* static first paint for crawlers / no-JS: the event (or "not found") above the about text; the SPA replaces #gate on boot */
  rep('aboutH1', /(<article class="onb-card land-about" id="seo-about">\s*)<h1>([^<]*)<\/h1>/, (all, pre, h) =>
    '<article class="onb-card land-about" id="seo-event"><h1>' + esc(m.h1) + '</h1>' + (m.lead ? '<p><b>' + esc(m.lead) + '</b></p>' : '') + (m.body ? '<p>' + esc(clip(m.body, 600)) + '</p>' : '') + '</article>\n   ' + pre + '<h2>' + h + '</h2>');
  return { html, steps };
}
export const INJECT_STEPS = ['title', 'description', 'canonical', 'hreflang', 'robots', 'ogUrl', 'ogTitle', 'ogDescription', 'ogLocale', 'twTitle', 'twDescription', 'aboutH1'];

export function sitemapXml(rows) {
  const urls = (rows || []).filter(r => r && r.id && INDEX_KINDS.has(r.kind)).map(r =>
    '  <url><loc>' + esc(SITE + eventPath(r)) + '</loc>' + (r.created_at ? '<lastmod>' + String(r.created_at).slice(0, 10) + '</lastmod>' : '') + '</url>');
  return '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + urls.join('\n') + (urls.length ? '\n' : '') + '</urlset>\n';
}

/* the whole request handler, with its dependencies injected (Pages: env.ASSETS + global fetch; tests: stubs) */
export async function handleEventRequest({ url, idSeg, getAsset, fetchImpl, envCfg }) {
  const lang = pickLang(url);
  const id = parseEventId(idSeg);
  const htmlRes = await getAsset('/');
  let html = await htmlRes.text();
  let ev = null, error = null;
  if (id) {
    try {
      const cfg = envCfg && envCfg.url && envCfg.key ? envCfg : parseConfigJs(await (await getAsset('/config.js')).text());
      ({ ev, error } = await fetchGuestEvent(id, cfg, fetchImpl));
    } catch (e) { error = String(e && e.message || e); }
  }
  const meta = ev ? buildEventMeta(ev, lang) : buildNotFoundMeta(lang);
  html = injectMeta(html, meta).html;
  const status = ev ? 200 : error ? 503 : 404;
  const headers = { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': error ? 'no-store' : 'public, max-age=60', 'X-Content-Type-Options': 'nosniff' };
  if (!ev || meta.robots.startsWith('noindex')) headers['X-Robots-Tag'] = 'noindex';
  if (error) headers['Retry-After'] = '30';
  return { status, headers, html, meta, error };
}
