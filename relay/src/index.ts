/**
 * Molaplan relay: a dumb, end-to-end-encrypted message switch between a home
 * bridge and paired phones. One Durable Object per home. The relay never sees
 * plaintext: payloads ("d") are AES-GCM ciphertext produced by the apps.
 *
 * Routes
 *   GET /health
 *   GET /v1/h/<homeId>/b?k=<bridgeKey>        bridge websocket (bridge key is trusted on first use)
 *   GET /v1/h/<homeId>/c?d=<devId>&t=<token>  paired phone websocket
 *   GET /v1/h/<homeId>/p?c=<code>             pairing websocket (only while the bridge shows a code)
 *   GET /v1/code/<6 digits>                   -> {"home": "<homeId>"} while a pairing code is active
 */
import { DurableObject } from "cloudflare:workers";

export interface Env {
  HOME: DurableObjectNamespace<Home>;
  CODES: DurableObjectNamespace<PairCode>;
}

const HOME_RE = /^[0-9a-f]{32}$/;
const DEV_RE = /^[0-9a-f]{16,32}$/;
const CODE_RE = /^[0-9]{6}$/;
const MAX_FRAME = 1_000_000;
const PAIR_TTL_MS = 10 * 60_000;
const MAX_PAIR_FAILS = 5;
const MAX_DEVICES = 32;

const enc = new TextEncoder();
async function sha256(s: string): Promise<string> {
  const h = await crypto.subtle.digest("SHA-256", enc.encode(s));
  return [...new Uint8Array(h)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

const cors = { "access-control-allow-origin": "*" };
const json = (o: unknown, status = 200) =>
  new Response(JSON.stringify(o), { status, headers: { "content-type": "application/json", ...cors } });

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    const parts = url.pathname.split("/").filter(Boolean);
    if (url.pathname === "/" || url.pathname === "/health") {
      return json({ ok: true, service: "molaplan-relay", v: 1 });
    }
    if (parts[0] === "v1" && parts[1] === "code" && parts.length === 3) {
      if (!CODE_RE.test(parts[2])) return json({ error: "bad_code" }, 400);
      const home = await env.CODES.getByName(parts[2]).lookup();
      return home ? json({ home }) : json({ error: "unknown_code" }, 404);
    }
    if (parts[0] === "v1" && parts[1] === "h" && parts.length === 4) {
      const [, , home, role] = parts;
      if (!HOME_RE.test(home) || !["b", "c", "p"].includes(role)) return json({ error: "bad_path" }, 400);
      if (req.headers.get("upgrade")?.toLowerCase() !== "websocket") return json({ error: "websocket_required" }, 426);
      const fwd = new Request(req.url, req);
      fwd.headers.set("x-home", home);
      return env.HOME.getByName(home).fetch(fwd);
    }
    return json({ error: "not_found" }, 404);
  },
};

/** Short-lived 6-digit code -> home id lookup (one object per code). */
export class PairCode extends DurableObject<Env> {
  async register(home: string, until: number): Promise<boolean> {
    const cur = await this.ctx.storage.get<{ home: string; until: number }>("v");
    if (cur && cur.home !== home && cur.until > Date.now()) return false; // code collision
    await this.ctx.storage.put("v", { home, until });
    await this.ctx.storage.setAlarm(until + 1000);
    return true;
  }
  async lookup(): Promise<string | null> {
    const cur = await this.ctx.storage.get<{ home: string; until: number }>("v");
    return cur && cur.until > Date.now() ? cur.home : null;
  }
  async clear(home: string): Promise<void> {
    const cur = await this.ctx.storage.get<{ home: string; until: number }>("v");
    if (cur?.home === home) await this.ctx.storage.deleteAll();
  }
  async alarm(): Promise<void> {
    await this.ctx.storage.deleteAll();
  }
}

type Att = { role: "b" | "c" | "p"; id: string };

/** One home: holds the bridge socket, phone sockets and the allow list. Uses websocket hibernation. */
export class Home extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    // Keepalive pings never wake the object.
    ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair("ping", "pong"));
  }

  private home(): Promise<string | undefined> {
    return this.ctx.storage.get<string>("home");
  }

  private sockets(tag: string): WebSocket[] {
    return this.ctx.getWebSockets(tag);
  }

  private bridge(): WebSocket | undefined {
    return this.sockets("b")[0];
  }

  private send(ws: WebSocket, o: unknown) {
    try {
      ws.send(JSON.stringify(o));
    } catch {
      /* socket already gone */
    }
  }

  private accept(tags: string[], att: Att, hello: unknown): Response {
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server, tags);
    server.serializeAttachment(att);
    this.send(server, hello);
    return new Response(null, { status: 101, webSocket: client });
  }

  async fetch(req: Request): Promise<Response> {
    const url = new URL(req.url);
    const role = url.pathname.split("/").filter(Boolean)[3];
    const home = req.headers.get("x-home")!;
    if (!(await this.home())) await this.ctx.storage.put("home", home);

    if (role === "b") {
      const key = url.searchParams.get("k") ?? "";
      if (key.length < 32) return json({ error: "bad_key" }, 400);
      const h = await sha256(key);
      const known = await this.ctx.storage.get<string>("bridgeKey");
      if (known && known !== h) return json({ error: "forbidden" }, 403);
      if (!known) await this.ctx.storage.put("bridgeKey", h);
      for (const old of this.sockets("b")) old.close(4000, "replaced");
      const res = this.accept(["b"], { role: "b", id: "bridge" }, { t: "hello", role: "bridge" });
      for (const c of this.sockets("c")) this.send(c, { t: "status", bridge: true });
      return res;
    }

    if (role === "c") {
      const dev = url.searchParams.get("d") ?? "";
      const tok = url.searchParams.get("t") ?? "";
      if (!DEV_RE.test(dev)) return json({ error: "bad_device" }, 400);
      const allowed = await this.ctx.storage.get<string>(`dev:${dev}`);
      if (!allowed || allowed !== (await sha256(tok))) return json({ error: "not_paired" }, 403);
      return this.accept(["c", `c:${dev}`], { role: "c", id: dev }, { t: "status", bridge: !!this.bridge() });
    }

    // role === "p": pairing
    const code = url.searchParams.get("c") ?? "";
    const p = await this.ctx.storage.get<{ h: string; until: number; fails: number }>("pair");
    if (!p || p.until < Date.now()) return json({ error: "no_pairing" }, 404);
    if (p.h !== (await sha256(`${home}:${code}`))) {
      p.fails++;
      if (p.fails >= MAX_PAIR_FAILS) await this.endPairing();
      else await this.ctx.storage.put("pair", p);
      return json({ error: "wrong_code" }, 403);
    }
    if (!this.bridge()) return json({ error: "bridge_offline" }, 503);
    const id = `p${crypto.randomUUID().replaceAll("-", "").slice(0, 15)}`;
    return this.accept(["p", `p:${id}`], { role: "p", id }, { t: "status", bridge: true });
  }

  private async endPairing() {
    const home = await this.home();
    await this.ctx.storage.delete("pair");
    const code = await this.ctx.storage.get<string>("pairCode");
    await this.ctx.storage.delete("pairCode");
    if (code && home) await this.env.CODES.getByName(code).clear(home);
  }

  async webSocketMessage(ws: WebSocket, raw: string | ArrayBuffer): Promise<void> {
    if (typeof raw !== "string" || raw.length > MAX_FRAME) {
      this.send(ws, { t: "err", code: "frame_too_large" });
      return;
    }
    let m: Record<string, unknown>;
    try {
      m = JSON.parse(raw);
    } catch {
      return;
    }
    const att = ws.deserializeAttachment() as Att;

    if (att.role === "b") return this.fromBridge(m);

    // phone or pairing socket -> bridge
    const b = this.bridge();
    if (m.t === "status") return this.send(ws, { t: "status", bridge: !!b });
    if (!b) return this.send(ws, { t: "err", code: "bridge_offline", id: m.id ?? null });
    if (att.role === "c" && m.t === "m") return this.send(b, { t: "m", from: att.id, d: m.d });
    if (att.role === "p" && m.t === "p") return this.send(b, { t: "p", from: att.id, d: m.d });
  }

  private async fromBridge(m: Record<string, unknown>) {
    const home = (await this.home())!;
    switch (m.t) {
      case "m": {
        for (const c of this.sockets(`c:${m.to}`)) this.send(c, { t: "m", d: m.d });
        return;
      }
      case "p": {
        for (const c of this.sockets(`p:${m.to}`)) this.send(c, { t: "p", d: m.d });
        return;
      }
      case "pairing": {
        // {t:"pairing", code:"123456"} starts, {t:"pairing", code:null} stops.
        await this.endPairing();
        const code = typeof m.code === "string" && CODE_RE.test(m.code) ? m.code : null;
        if (!code) return;
        const until = Date.now() + PAIR_TTL_MS;
        const ok = await this.env.CODES.getByName(code).register(home, until);
        if (!ok) return this.send(this.bridge()!, { t: "err", code: "code_in_use" });
        await this.ctx.storage.put("pair", { h: await sha256(`${home}:${code}`), until, fails: 0 });
        await this.ctx.storage.put("pairCode", code);
        this.send(this.bridge()!, { t: "pairing_ok", until });
        return;
      }
      case "allow": {
        const dev = String(m.dev ?? "");
        const h = String(m.h ?? "");
        if (!DEV_RE.test(dev) || !/^[0-9a-f]{64}$/.test(h)) return;
        const n = (await this.ctx.storage.list({ prefix: "dev:" })).size;
        if (n >= MAX_DEVICES && !(await this.ctx.storage.get(`dev:${dev}`))) {
          return this.send(this.bridge()!, { t: "err", code: "too_many_devices" });
        }
        await this.ctx.storage.put(`dev:${dev}`, h);
        await this.endPairing();
        return;
      }
      case "revoke": {
        const dev = String(m.dev ?? "");
        await this.ctx.storage.delete(`dev:${dev}`);
        for (const c of this.sockets(`c:${dev}`)) c.close(4003, "revoked");
        return;
      }
      case "kick": {
        for (const c of this.sockets(`p:${m.to}`)) c.close(4001, "pairing_closed");
        return;
      }
    }
  }

  async webSocketClose(ws: WebSocket, code: number): Promise<void> {
    const att = ws.deserializeAttachment() as Att | null;
    try {
      ws.close(code === 1005 ? 1000 : code, "bye");
    } catch {
      /* already closed */
    }
    if (att?.role === "b" && this.sockets("b").filter((s) => s !== ws).length === 0) {
      for (const c of this.sockets("c")) this.send(c, { t: "status", bridge: false });
    }
  }

  async webSocketError(ws: WebSocket): Promise<void> {
    await this.webSocketClose(ws, 1011);
  }
}
