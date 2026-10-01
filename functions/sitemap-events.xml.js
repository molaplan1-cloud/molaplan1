// Cloudflare Pages Function: /sitemap-events.xml – upcoming public and business events (community events are noindex).
// Same RLS-safe source as functions/e/[id].js: the guest_events view with the public anon key.
import { parseConfigJs, sitemapXml } from '../lib/event-page.mjs';

export async function onRequestGet(context) {
  const { request, env } = context;
  let cfg = env.SUPABASE_URL && env.SUPABASE_ANON_KEY ? { url: env.SUPABASE_URL, key: env.SUPABASE_ANON_KEY } : null;
  try {
    if (!cfg) cfg = parseConfigJs(await (await env.ASSETS.fetch(new Request(new URL('/config.js', request.url).toString()))).text());
    const since = new Date().toISOString();
    const u = cfg.url.replace(/\/+$/, '') + '/rest/v1/guest_events?select=id,title,kind,created_at,starts_at&kind=in.(public,business)&last_at=gte.' + encodeURIComponent(since) + '&order=starts_at.asc&limit=1000';
    const r = await fetch(u, { headers: { apikey: cfg.key, Authorization: 'Bearer ' + cfg.key, Accept: 'application/json' } });
    if (!r.ok) throw new Error('supabase ' + r.status);
    return new Response(sitemapXml(await r.json()), { headers: { 'Content-Type': 'application/xml; charset=utf-8', 'Cache-Control': 'public, max-age=3600' } });
  } catch (e) {
    return new Response(sitemapXml([]), { status: 503, headers: { 'Content-Type': 'application/xml; charset=utf-8', 'Cache-Control': 'no-store', 'Retry-After': '300' } });
  }
}
