/**
 * Day-ahead electricity spot prices, normalised for the Molaplan app.
 *
 *   GET /v1/prices?zone=FI            -> yesterday … tomorrow (what is published)
 *   GET /v1/prices/zones              -> supported bidding zones
 *
 * Response: {zone, unit:"EUR/MWh", resolution:<seconds>, source, license, updated, points:[[unixSeconds, eurPerMWh], …]}
 * Sources (no API keys): SE1-4 elprisetjustnu.se, DK1-2 Energi Data Service (CC BY 4.0), everything else
 * api.energy-charts.info (Fraunhofer ISE; license per zone is passed through); FI/EE/LV/LT try Elering
 * first (t151u: energy-charts answers 429 to shared Cloudflare egress). Cached at the edge per 15 min,
 * plus a 3-day last-good copy per zone that is served with "stale": true when every source fails.
 * No secrets live here.
 */

export const ZONES: Record<string, string> = {
  FI: "Suomi", EE: "Eesti", LV: "Latvija", LT: "Lietuva",
  SE1: "Sverige SE1 (Luleå)", SE2: "Sverige SE2 (Sundsvall)", SE3: "Sverige SE3 (Stockholm)", SE4: "Sverige SE4 (Malmö)",
  NO1: "Norge NO1 (Oslo)", NO2: "Norge NO2 (Kristiansand)", NO3: "Norge NO3 (Trondheim)", NO4: "Norge NO4 (Tromsø)", NO5: "Norge NO5 (Bergen)",
  DK1: "Danmark DK1 (vest)", DK2: "Danmark DK2 (øst)",
  "DE-LU": "Deutschland / Luxemburg", NL: "Nederland", BE: "Belgique", FR: "France", AT: "Österreich", CH: "Schweiz",
  PL: "Polska", CZ: "Česko", SK: "Slovensko", HU: "Magyarország", SI: "Slovenija", HR: "Hrvatska",
  RO: "România", BG: "България", GR: "Ελλάδα", ES: "España", PT: "Portugal",
  "IT-North": "Italia Nord", "IT-Centre-North": "Italia Centro-Nord", "IT-Centre-South": "Italia Centro-Sud",
  "IT-South": "Italia Sud", "IT-Calabria": "Italia Calabria", "IT-Sicily": "Italia Sicilia", "IT-Sardinia": "Italia Sardegna",
};

type Out = { zone: string; unit: string; resolution: number; source: string; license: string; updated: number; points: [number, number][] };

const day = (d: Date) => d.toISOString().slice(0, 10);

/** UTC midnight of the UTC calendar day of [now] plus [add] days. */
export function utcDayStart(now: Date, add: number): Date {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + add));
}

/**
 * Fetch window that always covers local yesterday…day-after-tomorrow in EU time zones
 * (UTC+0…UTC+3, including EET UTC+2). Using `now ± 1/2 days` then `toISOString().slice(0,10)`
 * as an exclusive end can become tomorrow 00:00 UTC (= 02:00 EET) and cut the day-ahead short
 * (t302u). End is UTC midnight of today+3, start is UTC midnight of today-2.
 */
export function priceFetchWindow(now = new Date()): { from: Date; to: Date } {
  return { from: utcDayStart(now, -2), to: utcDayStart(now, 3) };
}

async function energyCharts(zone: string, from: Date, to: Date): Promise<Out> {
  const u = `https://api.energy-charts.info/price?bzn=${encodeURIComponent(zone)}&start=${day(from)}&end=${day(to)}`;
  const r = await fetch(u, { headers: { "user-agent": "molaplan-relay" } });
  if (!r.ok) throw new Error(`energy-charts ${r.status}`);
  const j = (await r.json()) as { unix_seconds: number[]; price: (number | null)[]; license_info?: string };
  const points: [number, number][] = [];
  j.unix_seconds.forEach((t, i) => { const p = j.price[i]; if (typeof p === "number") points.push([t, p]); });
  return { zone, unit: "EUR/MWh", resolution: guessRes(points), source: "energy-charts.info", license: j.license_info ?? "", updated: Date.now(), points };
}

async function elprisetjustnu(zone: string, days: Date[]): Promise<Out> {
  const points: [number, number][] = [];
  for (const d of days) {
    const [y, m, dd] = day(d).split("-");
    const r = await fetch(`https://www.elprisetjustnu.se/api/v1/prices/${y}/${m}-${dd}_${zone}.json`);
    if (r.status === 404) continue; // not published yet
    if (!r.ok) throw new Error(`elprisetjustnu ${r.status}`);
    const j = (await r.json()) as { EUR_per_kWh: number; time_start: string }[];
    for (const x of j) points.push([Math.floor(Date.parse(x.time_start) / 1000), Math.round(x.EUR_per_kWh * 1000 * 100) / 100]);
  }
  return { zone, unit: "EUR/MWh", resolution: guessRes(points), source: "elprisetjustnu.se", license: "Elpriser tillhandahålls av Elpriset just nu.se", updated: Date.now(), points };
}

async function energiDataService(zone: string, from: Date): Promise<Out> {
  const filter = encodeURIComponent(JSON.stringify({ PriceArea: [zone] }));
  const start = `${day(from)}T00:00`;
  const r = await fetch(`https://api.energidataservice.dk/dataset/DayAheadPrices?start=${start}&filter=${filter}&sort=TimeUTC%20asc&limit=1000`);
  if (!r.ok) throw new Error(`energidataservice ${r.status}`);
  const j = (await r.json()) as { records: { TimeUTC: string; DayAheadPriceEUR: number | null }[] };
  const points: [number, number][] = [];
  for (const x of j.records) if (typeof x.DayAheadPriceEUR === "number") points.push([Math.floor(Date.parse(x.TimeUTC + "Z") / 1000), x.DayAheadPriceEUR]);
  return { zone, unit: "EUR/MWh", resolution: guessRes(points), source: "energidataservice.dk", license: "CC BY 4.0, Energinet", updated: Date.now(), points };
}

/** Elering (Estonian TSO) republishes Nord Pool day-ahead for FI/EE/LV/LT; not rate-limited like
 *  energy-charts, which answers 429 to Cloudflare's shared egress (t151u root cause). */
const ELERING = new Set(["FI", "EE", "LV", "LT"]);

async function elering(zone: string, from: Date, to: Date): Promise<Out> {
  const u = `https://dashboard.elering.ee/api/nps/price?start=${day(from)}T00:00:00.000Z&end=${day(to)}T00:00:00.000Z`;
  const r = await fetch(u, { headers: { "user-agent": "molaplan-relay" } });
  if (!r.ok) throw new Error(`elering ${r.status}`);
  const j = (await r.json()) as { data?: Record<string, { timestamp: number; price: number | null }[]> };
  const points: [number, number][] = [];
  for (const x of j.data?.[zone.toLowerCase()] ?? []) if (typeof x.price === "number") points.push([x.timestamp, x.price]);
  points.sort((a, b) => a[0] - b[0]);
  return { zone, unit: "EUR/MWh", resolution: guessRes(points), source: "elering.ee (Nord Pool)", license: "Elering AS, open data", updated: Date.now(), points };
}

function guessRes(p: [number, number][]): number {
  return p.length > 1 ? p[1][0] - p[0][0] : 3600;
}

const nonEmpty = (o: Out): Out => {
  if (o.points.length === 0) throw new Error(`${o.source} empty`);
  return o;
};

export async function prices(req: Request, ctx: ExecutionContext): Promise<Response> {
  const url = new URL(req.url);
  const cors = { "access-control-allow-origin": "*" };
  const json = (o: unknown, status = 200, maxAge = 0) =>
    new Response(JSON.stringify(o), {
      status,
      headers: { "content-type": "application/json", ...cors, ...(maxAge ? { "cache-control": `public, max-age=${maxAge}` } : {}) },
    });
  if (url.pathname.endsWith("/zones")) return json({ zones: ZONES }, 200, 86400);
  const zone = url.searchParams.get("zone") ?? "";
  if (!(zone in ZONES)) return json({ error: "unknown_zone", zones: Object.keys(ZONES) }, 400);

  // One cache entry per zone per 15 minutes (tomorrow's prices appear ~12:45 CET).
  const slot = Math.floor(Date.now() / 900_000);
  const key = new Request(`https://cache.molaplan/prices/${zone}/${slot}`);
  const cache = caches.default;
  const hit = await cache.match(key);
  if (hit) return new Response(hit.body, { headers: { "content-type": "application/json", ...cors, "x-cache": "hit" } });

  const now = new Date();
  const { from, to } = priceFetchWindow(now);
  const chain: (() => Promise<Out>)[] = [];
  if (ELERING.has(zone)) chain.push(() => elering(zone, from, to));
  if (zone.startsWith("SE")) chain.push(() => elprisetjustnu(zone, [from, now, new Date(now.getTime() + 86_400_000)]));
  if (zone.startsWith("DK")) chain.push(() => energiDataService(zone, from));
  chain.push(() => energyCharts(zone, from, to));
  const errors: string[] = [];
  let out: Out | undefined;
  for (const f of chain) {
    try {
      out = nonEmpty(await f());
      break;
    } catch (e) {
      errors.push(String(e));
    }
  }
  // Last good copy per zone (3 days): served marked stale when every source fails.
  const lastKey = new Request(`https://cache.molaplan/prices/${zone}/last`);
  if (!out) {
    const last = await cache.match(lastKey);
    if (last) {
      const o = (await last.json()) as Out;
      return json({ ...o, stale: true, detail: errors.join("; ") });
    }
    return json({ error: "source_failed", detail: errors.join("; ") }, 502);
  }
  const res = json(out, 200, 900);
  ctx.waitUntil(cache.put(key, res.clone()));
  ctx.waitUntil(cache.put(lastKey, json(out, 200, 3 * 86400)));
  return res;
}
