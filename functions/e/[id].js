// Cloudflare Pages Function: /e/<uuid>[-slug] -> index.html with per-event <title>, description, Open Graph, Twitter and
// JSON-LD Event (logic in lib/event-page.mjs). Reads only the RLS-protected guest_events view with the public anon key
// (taken from the deployed config.js, or env SUPABASE_URL / SUPABASE_ANON_KEY if set), so it can never show more than a guest sees.
import { handleEventRequest } from '../../lib/event-page.mjs';

export async function onRequest(context) {
  const { request, env, params } = context;
  if (request.method !== 'GET' && request.method !== 'HEAD') return new Response('Method not allowed', { status: 405, headers: { Allow: 'GET, HEAD' } });
  const getAsset = p => env.ASSETS.fetch(new Request(new URL(p, request.url).toString(), { method: 'GET' }));
  const r = await handleEventRequest({
    url: request.url, idSeg: params.id, getAsset, fetchImpl: (u, o) => fetch(u, o),
    envCfg: env.SUPABASE_URL && env.SUPABASE_ANON_KEY ? { url: env.SUPABASE_URL, key: env.SUPABASE_ANON_KEY } : null
  });
  return new Response(request.method === 'HEAD' ? null : r.html, { status: r.status, headers: r.headers });
}
