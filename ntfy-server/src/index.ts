// Molaplan ntfy: a small ntfy-compatible server on Cloudflare Workers + Durable Objects (free plan).
//
// Implements the part of the ntfy protocol (https://docs.ntfy.sh) that ntfy clients use:
//   publish:   PUT/POST /<topic> (body = message, headers/params Title, Priority, Tags, Click, Icon,
//              Actions, Attach, Filename, Markdown, Cache, Firebase, X-Poll-ID), PUT/POST / with JSON,
//              GET /<topic>/publish|send|trigger
//   subscribe: GET /<topics>/json|sse|raw|ws  (streaming with open + keepalive events, poll=1, since=,
//              id/message/title/tags/priority filters), GET /<topics>/auth
//   misc:      /v1/health, /v1/config, /v1/account, /v1/tiers, /v1/stats, /file/<id>
//
// Design (free plan):
//   - One Durable Object per topic (SQLite) keeps the ~12 h message cache.
//   - Streaming subscribers are held by the stateless Worker. The Worker connects to each topic
//     object with a WebSocket that the object accepts with the Hibernation API, so an idle topic
//     costs no Durable Object duration. Keepalives are written by the Worker (CPU time only).
//   - Streams are closed after STREAM_MAX_SECONDS (default 20 min); ntfy clients reconnect with
//     since=<last id>, so nothing is lost and the Worker's per-request CPU limit is never reached.
//   - Messages are forwarded as poll requests to UPSTREAM_BASE_URL (ntfy.sh) like ntfy's
//     upstream-base-url, so the official iOS app gets instant notifications.
import { DurableObject } from "cloudflare:workers";

export interface Env {
  TOPIC: DurableObjectNamespace<Topic>;
  FILE: DurableObjectNamespace<FileStore>;
  PUBLISH_LIMIT?: RateLimit;
  REQUEST_LIMIT?: RateLimit;
  BASE_URL?: string;
  UPSTREAM_BASE_URL?: string;
  CACHE_SECONDS?: string;
  STREAM_MAX_SECONDS?: string;
  KEEPALIVE_SECONDS?: string;
}

interface Attachment { name: string; type?: string; size?: number; expires?: number; url: string }
export interface Msg {
  id: string;
  time: number;
  expires?: number;
  event: string;
  topic: string;
  title?: string;
  message?: string;
  priority?: number;
  tags?: string[];
  click?: string;
  icon?: string;
  actions?: unknown[];
  attachment?: Attachment;
  poll_id?: string;
  content_type?: string;
}

// "all" | "none" | "latest" | "t:<unix>" | "id:<message id>"
type Since = string;

const TOPIC_RE = /^[-_A-Za-z0-9]{1,64}$/;
const TOPICS_RE = /^\/([-_A-Za-z0-9]{1,64}(?:,[-_A-Za-z0-9]{1,64})*)\/(json|sse|raw|ws|auth)$/;
const MESSAGE_LIMIT = 4096; // bytes; larger bodies become attachments (as in ntfy)
const ATTACHMENT_LIMIT = 5 * 1024 * 1024;
const JSON_PUBLISH_LIMIT = 32 * 1024;
const MAX_TOPICS = 10;
const MAX_CACHED_PER_TOPIC = 1000;
const ID_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
const VERSION = "1.0.0";

const now = () => Math.floor(Date.now() / 1000);

export function randomId(n = 12): string {
  const b = new Uint8Array(n);
  crypto.getRandomValues(b);
  let s = "";
  for (const x of b) s += ID_CHARS[x % ID_CHARS.length];
  return s;
}
const validId = (s: string) => /^[A-Za-z0-9]{12}$/.test(s);

/** JSON in ntfy's field order, empty fields left out. */
export function toJson(m: Msg): string {
  const o: Record<string, unknown> = { id: m.id, time: m.time };
  if (m.expires) o.expires = m.expires;
  o.event = m.event;
  o.topic = m.topic;
  if (m.title) o.title = m.title;
  if (m.message) o.message = m.message;
  if (m.priority) o.priority = m.priority;
  if (m.tags && m.tags.length) o.tags = m.tags;
  if (m.click) o.click = m.click;
  if (m.icon) o.icon = m.icon;
  if (m.actions && m.actions.length) o.actions = m.actions;
  if (m.attachment) o.attachment = m.attachment;
  if (m.poll_id) o.poll_id = m.poll_id;
  if (m.content_type) o.content_type = m.content_type;
  return JSON.stringify(o);
}

// ---------------------------------------------------------------- Durable Objects

export class Topic extends DurableObject<Env> {
  private sql: SqlStorage;

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    this.sql.exec(`CREATE TABLE IF NOT EXISTS m (
      seq INTEGER PRIMARY KEY AUTOINCREMENT,
      id TEXT NOT NULL UNIQUE,
      time INTEGER NOT NULL,
      expires INTEGER NOT NULL,
      json TEXT NOT NULL)`);
    this.sql.exec(`CREATE INDEX IF NOT EXISTS m_expires ON m(expires)`);
  }

  /** Stores (unless cache=false) and fans out one message. */
  publish(json: string, expires: number, cache: boolean): void {
    const t = now();
    this.sql.exec(`DELETE FROM m WHERE expires < ?`, t);
    if (cache) {
      const m = JSON.parse(json) as Msg;
      this.sql.exec(`INSERT INTO m (id, time, expires, json) VALUES (?, ?, ?, ?)`, m.id, m.time, expires, json);
      this.sql.exec(
        `DELETE FROM m WHERE seq <= (SELECT seq FROM m ORDER BY seq DESC LIMIT 1 OFFSET ?)`,
        MAX_CACHED_PER_TOPIC,
      );
    }
    for (const ws of this.ctx.getWebSockets()) {
      try {
        ws.send(json);
      } catch {
        // closed socket, cleaned up by the runtime
      }
    }
  }

  /** Cached messages for a since marker, oldest first. */
  query(since: Since): string[] {
    const t = now();
    let rows: { json: string }[];
    if (since === "none") return [];
    if (since === "latest") {
      rows = this.sql.exec<{ json: string }>(`SELECT json FROM m WHERE expires >= ? ORDER BY seq DESC LIMIT 1`, t).toArray();
    } else if (since.startsWith("t:")) {
      rows = this.sql
        .exec<{ json: string }>(`SELECT json FROM m WHERE expires >= ? AND time >= ? ORDER BY seq`, t, Number(since.slice(2)))
        .toArray();
    } else if (since.startsWith("id:")) {
      const marker = this.sql.exec<{ seq: number }>(`SELECT seq FROM m WHERE id = ?`, since.slice(3)).toArray()[0];
      rows = this.sql
        .exec<{ json: string }>(`SELECT json FROM m WHERE expires >= ? AND seq > ? ORDER BY seq`, t, marker ? marker.seq : 0)
        .toArray();
    } else {
      rows = this.sql.exec<{ json: string }>(`SELECT json FROM m WHERE expires >= ? ORDER BY seq`, t).toArray();
    }
    return rows.map((r) => r.json);
  }

  /** WebSocket from the Worker: cached messages first, then live ones. Hibernation API. */
  async fetch(req: Request): Promise<Response> {
    if (req.headers.get("Upgrade")?.toLowerCase() !== "websocket") return new Response("expected websocket", { status: 426 });
    const since = new URL(req.url).searchParams.get("since") || "none";
    const pair = new WebSocketPair();
    this.ctx.acceptWebSocket(pair[1]);
    for (const json of this.query(since)) pair[1].send(json);
    return new Response(null, { status: 101, webSocket: pair[0] });
  }

  webSocketMessage(ws: WebSocket, data: string | ArrayBuffer): void {
    if (data === "ping") ws.send("pong");
  }

  webSocketClose(ws: WebSocket, code: number, reason: string): void {
    try {
      ws.close(code === 1005 || code === 1006 ? 1000 : code, reason);
    } catch {
      // already closed
    }
  }
}

/** One object per attachment; removed by its alarm when it expires. */
export class FileStore extends DurableObject<Env> {
  private sql: SqlStorage;

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    this.sql.exec(`CREATE TABLE IF NOT EXISTS meta (k TEXT PRIMARY KEY, v TEXT NOT NULL)`);
    this.sql.exec(`CREATE TABLE IF NOT EXISTS part (n INTEGER PRIMARY KEY, data BLOB NOT NULL)`);
  }

  async put(data: ArrayBuffer, type: string, name: string, expires: number): Promise<void> {
    const CHUNK = 1024 * 1024;
    this.sql.exec(`DELETE FROM part`);
    for (let i = 0, n = 0; i < data.byteLength; i += CHUNK, n++) {
      this.sql.exec(`INSERT INTO part (n, data) VALUES (?, ?)`, n, data.slice(i, i + CHUNK));
    }
    this.sql.exec(`INSERT OR REPLACE INTO meta VALUES ('type', ?), ('name', ?), ('expires', ?), ('size', ?)`,
      type, name, String(expires), String(data.byteLength));
    await this.ctx.storage.setAlarm(expires * 1000);
  }

  get(): { type: string; name: string; data: ArrayBuffer } | null {
    const meta = Object.fromEntries(this.sql.exec<{ k: string; v: string }>(`SELECT k, v FROM meta`).toArray().map((r) => [r.k, r.v]));
    if (!meta.expires || Number(meta.expires) < now()) return null;
    const parts = this.sql.exec<{ data: ArrayBuffer }>(`SELECT data FROM part ORDER BY n`).toArray();
    const out = new Uint8Array(Number(meta.size));
    let o = 0;
    for (const p of parts) {
      const b = new Uint8Array(p.data);
      out.set(b, o);
      o += b.byteLength;
    }
    return { type: meta.type, name: meta.name, data: out.buffer };
  }

  async alarm(): Promise<void> {
    await this.ctx.storage.deleteAll();
  }
}

// ---------------------------------------------------------------- helpers

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, PUT, POST, PATCH, DELETE",
  "Access-Control-Allow-Headers": "*",
  "Access-Control-Expose-Headers": "*",
};

function json(body: unknown, status = 200, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body) + "\n", {
    status,
    headers: { "Content-Type": "application/json", ...CORS, ...extra },
  });
}

function err(http: number, code: number, error: string): Response {
  return json({ code, http, error, link: "https://docs.ntfy.sh" }, http);
}

/** RFC 2047 encoded words (=?UTF-8?B?...?=) and raw UTF-8 bytes in headers. */
export function decodeHeader(v: string): string {
  if (/[\u0080-\u00ff]/.test(v) && !/[^\u0000-\u00ff]/.test(v)) {
    try {
      v = new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(Uint8Array.from(v, (c) => c.charCodeAt(0)));
    } catch {
      // keep as is
    }
  }
  return v.replace(/=\?([^?]+)\?([BbQq])\?([^?]*)\?=\s*/g, (all, charset: string, enc: string, text: string) => {
    try {
      let bytes: Uint8Array;
      if (enc.toUpperCase() === "B") {
        bytes = Uint8Array.from(atob(text), (c) => c.charCodeAt(0));
      } else {
        const s = text.replace(/_/g, " ").replace(/=([0-9A-Fa-f]{2})/g, (_x, h: string) => String.fromCharCode(parseInt(h, 16)));
        bytes = Uint8Array.from(s, (c) => c.charCodeAt(0));
      }
      return new TextDecoder(charset.toLowerCase() === "utf8" ? "utf-8" : charset).decode(bytes);
    } catch {
      return all;
    }
  }).trim();
}

/** Header first, then query parameter (ntfy's readParam). */
function param(req: Request, url: URL, ...names: string[]): string {
  for (const n of names) {
    const h = req.headers.get(n);
    if (h && h.trim()) return decodeHeader(h);
  }
  for (const n of names) {
    const q = url.searchParams.get(n);
    if (q && q.trim()) return q.trim();
  }
  return "";
}

const toBool = (v: string) => ["1", "yes", "true", "on"].includes(v.toLowerCase());
const isFalse = (v: string) => ["0", "no", "false", "off"].includes(v.toLowerCase());

export function parsePriority(v: string | number | undefined): number | null {
  if (v === undefined || v === "" || v === 0) return 0;
  const s = String(v).trim().toLowerCase();
  const names: Record<string, number> = { min: 1, low: 2, default: 3, high: 4, max: 5, urgent: 5 };
  if (s in names) return names[s];
  const n = Number(s);
  return Number.isInteger(n) && n >= 1 && n <= 5 ? n : null;
}

/** ntfy's simple action format: "view, Open, https://x; http, Close, https://y, method=PUT, clear=true". */
export function parseActions(v: string): unknown[] | null {
  v = v.trim();
  if (!v) return [];
  if (v.startsWith("[")) {
    try {
      const a = JSON.parse(v);
      return Array.isArray(a) ? a.map(withActionId) : null;
    } catch {
      return null;
    }
  }
  const out: unknown[] = [];
  for (const part of v.split(";")) {
    const f = part.split(",").map((x) => x.trim().replace(/^"(.*)"$/, "$1").replace(/^'(.*)'$/, "$1"));
    if (f.length < 2 || !f[0]) continue;
    const a: Record<string, unknown> = { action: f[0].toLowerCase(), label: f[1] };
    let pos = 0;
    for (const x of f.slice(2)) {
      const eq = x.indexOf("=");
      const key = eq > 0 ? x.slice(0, eq).trim() : "";
      if (key && /^[a-z][a-z0-9._-]*$/i.test(key)) {
        const val = x.slice(eq + 1).trim();
        if (key.startsWith("headers.") || key.startsWith("extras.")) {
          const [grp, k] = [key.split(".")[0], key.slice(key.indexOf(".") + 1)];
          a[grp] = { ...((a[grp] as Record<string, string>) || {}), [k]: val };
        } else if (key === "clear") a.clear = toBool(val);
        else a[key] = val;
      } else if (pos++ === 0) {
        if (a.action === "copy") a.value = x;
        else if (a.action === "broadcast") a.intent = x;
        else a.url = x;
      }
    }
    out.push(withActionId(a));
  }
  return out;
}

function withActionId(a: unknown): unknown {
  if (a && typeof a === "object" && !(a as Record<string, unknown>).id) return { id: randomId(10), ...(a as object) };
  return a;
}

export function parseSince(v: string, poll: boolean): Since | null {
  v = v.trim();
  if (!v) return poll ? "all" : "none";
  if (v === "all" || v === "none" || v === "latest") return v;
  if (validId(v)) return "id:" + v;
  if (/^\d+$/.test(v)) return "t:" + v;
  const re = /(\d+(?:\.\d+)?)(ms|s|m|h|d)/g;
  let total = 0;
  let consumed = 0;
  for (const m of v.matchAll(re)) {
    const n = Number(m[1]);
    total += m[2] === "ms" ? n / 1000 : m[2] === "s" ? n : m[2] === "m" ? n * 60 : m[2] === "h" ? n * 3600 : n * 86400;
    consumed += m[0].length;
  }
  if (consumed !== v.length || consumed === 0) return null;
  return "t:" + Math.floor(now() - total);
}

interface Filters { id: string; message: string; title: string; tags: string[]; priority: number[] }

function passes(m: Msg, f: Filters): boolean {
  if (m.event !== "message") return true;
  if (f.id && m.id !== f.id) return false;
  if (f.message && m.message !== f.message) return false;
  if (f.title && m.title !== f.title) return false;
  if (f.priority.length && !f.priority.includes(m.priority || 3)) return false;
  if (f.tags.length && !f.tags.every((t) => (m.tags || []).includes(t))) return false;
  return true;
}

function clientIp(req: Request): string {
  return req.headers.get("CF-Connecting-IP") || "unknown";
}

async function limited(lim: RateLimit | undefined, key: string): Promise<boolean> {
  if (!lim) return false;
  try {
    return !(await lim.limit({ key })).success;
  } catch {
    return false;
  }
}

async function sha256hex(s: string): Promise<string> {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function baseUrl(url: URL): string {
  return url.origin;
}

function extFor(type: string, name: string): string {
  const m = /\.([A-Za-z0-9]{1,8})$/.exec(name);
  if (m) return "." + m[1].toLowerCase();
  const map: Record<string, string> = {
    "image/jpeg": ".jpg", "image/png": ".png", "image/gif": ".gif", "image/webp": ".webp",
    "application/pdf": ".pdf", "text/plain": ".txt", "application/json": ".json", "video/mp4": ".mp4",
  };
  return map[type] || ".bin";
}

function sniffType(b: Uint8Array, name: string): string {
  if (b[0] === 0xff && b[1] === 0xd8) return "image/jpeg";
  if (b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47) return "image/png";
  if (b[0] === 0x47 && b[1] === 0x49 && b[2] === 0x46) return "image/gif";
  if (b[0] === 0x25 && b[1] === 0x50 && b[2] === 0x44 && b[3] === 0x46) return "application/pdf";
  const e = /\.([A-Za-z0-9]+)$/.exec(name)?.[1]?.toLowerCase();
  const byExt: Record<string, string> = { jpg: "image/jpeg", jpeg: "image/jpeg", png: "image/png", gif: "image/gif", webp: "image/webp", pdf: "application/pdf", txt: "text/plain", json: "application/json", mp4: "video/mp4" };
  if (e && byExt[e]) return byExt[e];
  try {
    new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(b);
    return "text/plain";
  } catch {
    return "application/octet-stream";
  }
}

// ---------------------------------------------------------------- publish

interface PublishInput {
  topic: string;
  message: string;
  title: string;
  priority: number;
  tags: string[];
  click: string;
  icon: string;
  actions: unknown[];
  attachUrl: string;
  filename: string;
  markdown: boolean;
  cache: boolean;
  upstream: boolean;
  pollId: string;
  body: ArrayBuffer | null; // attachment bytes
}

async function publish(p: PublishInput, env: Env, ctx: ExecutionContext, url: URL): Promise<Response> {
  const t = now();
  const ttl = Number(env.CACHE_SECONDS || 43200);
  const m: Msg = { id: randomId(), time: t, expires: t + ttl, event: "message", topic: p.topic };
  if (p.title) m.title = p.title;
  if (p.priority) m.priority = p.priority;
  if (p.tags.length) m.tags = p.tags;
  if (p.click) m.click = p.click;
  if (p.icon) m.icon = p.icon;
  if (p.actions.length) m.actions = p.actions;
  if (p.markdown) m.content_type = "text/markdown";
  if (p.pollId) {
    m.event = "poll_request";
    m.poll_id = p.pollId;
    m.message = p.message || "New message";
  }
  if (p.body) {
    const bytes = new Uint8Array(p.body);
    const type = sniffType(bytes.subarray(0, 4096), p.filename);
    const name = p.filename || "attachment" + extFor(type, "");
    const ext = extFor(type, name);
    await env.FILE.getByName(m.id).put(p.body, type, name, t + ttl);
    m.attachment = { name, type, size: bytes.byteLength, expires: t + ttl, url: `${baseUrl(url)}/file/${m.id}${ext}` };
    m.message = p.message || `You received a file: ${name}`;
  } else if (p.attachUrl) {
    let name = p.filename;
    if (!name) {
      try {
        name = decodeURIComponent(new URL(p.attachUrl).pathname.split("/").pop() || "") || "attachment";
      } catch {
        name = "attachment";
      }
    }
    m.attachment = { name, url: p.attachUrl };
    m.message = p.message || `You received a file: ${name}`;
  } else if (!m.message) {
    m.message = p.message || "triggered";
  }
  const out = toJson(m);
  await env.TOPIC.getByName(p.topic).publish(out, m.expires!, p.cache);
  if (p.upstream && m.event === "message" && env.UPSTREAM_BASE_URL) {
    ctx.waitUntil(forwardPollRequest(env.UPSTREAM_BASE_URL, baseUrl(url), m));
  }
  return new Response(out + "\n", { headers: { "Content-Type": "application/json", ...CORS } });
}

/** Same as ntfy's upstream-base-url: POST <upstream>/<sha256(base/topic)> with X-Poll-ID. */
async function forwardPollRequest(upstream: string, base: string, m: Msg): Promise<void> {
  try {
    const hash = await sha256hex(`${base}/${m.topic}`);
    const r = await fetch(`${upstream.replace(/\/+$/, "")}/${hash}`, {
      method: "POST",
      headers: { "X-Poll-ID": m.id, "User-Agent": `ntfy/${VERSION} (molaplan-ntfy)` },
      body: "",
    });
    if (!r.ok) console.log(`upstream poll request -> HTTP ${r.status}`);
    await r.body?.cancel();
  } catch (e) {
    console.log(`upstream poll request failed: ${e}`);
  }
}

async function handlePublishPath(req: Request, env: Env, ctx: ExecutionContext, url: URL, topic: string, readBody: boolean): Promise<Response> {
  const len = Number(req.headers.get("Content-Length") || 0);
  if (len > ATTACHMENT_LIMIT) return err(413, 41301, "attachment too large, or bandwidth limit reached");
  const priority = parsePriority(param(req, url, "x-priority", "priority", "prio", "p"));
  if (priority === null) return err(400, 40007, "invalid priority");
  const actions = parseActions(param(req, url, "x-actions", "actions", "action"));
  if (actions === null) return err(400, 40018, "invalid request: actions invalid");
  if (param(req, url, "x-delay", "delay", "x-at", "at", "x-in", "in")) {
    return err(400, 40004, "invalid delay parameter: scheduled delivery is not supported on this server");
  }
  let body: ArrayBuffer | null = null;
  let message = param(req, url, "x-message", "message", "m");
  const filename = param(req, url, "x-filename", "filename", "file", "f");
  if (readBody) {
    const buf = await req.arrayBuffer();
    if (buf.byteLength > ATTACHMENT_LIMIT) return err(413, 41301, "attachment too large, or bandwidth limit reached");
    if (buf.byteLength > 0) {
      let text: string | null = null;
      if (!filename && buf.byteLength <= MESSAGE_LIMIT) {
        try {
          text = new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(buf);
        } catch {
          text = null;
        }
      }
      if (text !== null) message = text.trim() ? text : message;
      else body = buf;
    }
  }
  if (new TextEncoder().encode(message).byteLength > MESSAGE_LIMIT && !body) {
    body = new TextEncoder().encode(message).buffer as ArrayBuffer;
    message = "";
  }
  const tags = param(req, url, "x-tags", "tags", "tag", "ta").split(",").map((s) => s.trim()).filter(Boolean);
  const md = param(req, url, "x-markdown", "markdown", "md");
  const ct = (req.headers.get("Content-Type") || "").toLowerCase();
  return publish(
    {
      topic,
      message,
      title: param(req, url, "x-title", "title", "ti", "t"),
      priority,
      tags,
      click: param(req, url, "x-click", "click"),
      icon: param(req, url, "x-icon", "icon"),
      actions,
      attachUrl: param(req, url, "x-attach", "attach", "a"),
      filename,
      markdown: (md !== "" && toBool(md)) || ct.startsWith("text/markdown"),
      cache: !isFalse(param(req, url, "x-cache", "cache")),
      upstream: !isFalse(param(req, url, "x-firebase", "firebase")) && !toBool(param(req, url, "x-unifiedpush", "unifiedpush", "up")),
      pollId: param(req, url, "x-poll-id", "poll-id"),
      body,
    },
    env,
    ctx,
    url,
  );
}

async function handlePublishJson(req: Request, env: Env, ctx: ExecutionContext, url: URL): Promise<Response> {
  const buf = await req.arrayBuffer();
  if (buf.byteLength > JSON_PUBLISH_LIMIT) return err(413, 41301, "request too large");
  let j: Record<string, unknown>;
  try {
    j = JSON.parse(new TextDecoder().decode(buf));
  } catch {
    return err(400, 40017, "invalid request: request body must be message JSON");
  }
  if (!j || typeof j !== "object") return err(400, 40017, "invalid request: request body must be message JSON");
  const topic = String(j.topic ?? "");
  if (!TOPIC_RE.test(topic)) return err(400, 40009, "invalid topic: path invalid");
  const priority = parsePriority(j.priority as string | number | undefined);
  if (priority === null) return err(400, 40007, "invalid priority");
  if (j.delay || j.at || j.in) return err(400, 40004, "invalid delay parameter: scheduled delivery is not supported on this server");
  let actions: unknown[] = [];
  if (Array.isArray(j.actions)) actions = j.actions.map(withActionId);
  else if (typeof j.actions === "string") actions = parseActions(j.actions) || [];
  let message = typeof j.message === "string" ? j.message : "";
  let body: ArrayBuffer | null = null;
  if (new TextEncoder().encode(message).byteLength > MESSAGE_LIMIT) {
    body = new TextEncoder().encode(message).buffer as ArrayBuffer;
    message = "";
  }
  const str = (k: string) => (typeof j[k] === "string" ? (j[k] as string) : "");
  return publish(
    {
      topic,
      message,
      title: str("title"),
      priority,
      tags: Array.isArray(j.tags) ? j.tags.map(String).filter(Boolean) : [],
      click: str("click"),
      icon: str("icon"),
      actions,
      attachUrl: str("attach"),
      filename: str("filename"),
      markdown: j.markdown === true,
      cache: j.cache !== false && j.cache !== "no",
      upstream: j.firebase !== false && j.firebase !== "no",
      pollId: str("poll_id"),
      body,
    },
    env,
    ctx,
    url,
  );
}

// ---------------------------------------------------------------- subscribe

type Kind = "json" | "sse" | "raw" | "ws";

function encode(kind: Kind, m: Msg, raw: string): string {
  if (kind === "json") return raw + "\n";
  if (kind === "sse") return m.event === "message" ? `data: ${raw}\n\n` : `event: ${m.event}\ndata: ${raw}\n\n`;
  if (kind === "raw") return m.event === "message" ? (m.message || "").replace(/\n/g, " ") + "\n" : "\n";
  return raw;
}

const CONTENT_TYPE: Record<Kind, string> = {
  json: "application/x-ndjson; charset=utf-8",
  sse: "text/event-stream; charset=utf-8",
  raw: "text/plain; charset=utf-8",
  ws: "",
};

async function handleSubscribe(req: Request, env: Env, url: URL, topics: string[], kind: Kind): Promise<Response> {
  if (kind === "ws" && req.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
    return err(400, 40016, "invalid request: client not using the websocket protocol");
  }
  const pollV = param(req, url, "x-poll", "poll", "po");
  const poll = pollV !== "" && toBool(pollV);
  const since = parseSince(param(req, url, "x-since", "since", "si"), poll);
  if (since === null) return err(400, 40008, "invalid since parameter");
  const priority: number[] = [];
  for (const p of param(req, url, "x-priority", "priority", "prio", "p").split(",").filter((s) => s.trim())) {
    const n = parsePriority(p);
    if (!n) return err(400, 40007, "invalid priority");
    priority.push(n);
  }
  const filters: Filters = {
    id: param(req, url, "x-id", "id"),
    message: param(req, url, "x-message", "message", "m"),
    title: param(req, url, "x-title", "title", "t"),
    tags: param(req, url, "x-tags", "tags", "tag", "ta").split(",").map((s) => s.trim()).filter(Boolean),
    priority,
  };
  const topicsStr = topics.join(",");

  if (poll) {
    const lists = await Promise.all(topics.map((t) => env.TOPIC.getByName(t).query(since)));
    const items: { m: Msg; raw: string }[] = [];
    for (const l of lists) for (const raw of l) items.push({ m: JSON.parse(raw) as Msg, raw });
    if (topics.length > 1) items.sort((a, b) => a.m.time - b.m.time);
    const picked = items.filter((x) => passes(x.m, filters));
    if (kind === "ws") {
      const pair = new WebSocketPair();
      pair[1].accept();
      for (const x of picked) pair[1].send(x.raw);
      pair[1].close(1000, "poll");
      return new Response(null, { status: 101, webSocket: pair[0] });
    }
    return new Response(picked.map((x) => encode(kind, x.m, x.raw)).join(""), {
      headers: { "Content-Type": CONTENT_TYPE[kind], "Cache-Control": "no-store", ...CORS },
    });
  }

  // Streaming: one hibernatable WebSocket per topic object, merged here.
  const upstreams: WebSocket[] = [];
  let done = false;
  let opened = false;
  const pending: { m: Msg; raw: string }[] = [];
  let sendOut: (s: string) => Promise<void> = async () => {};
  let finish: () => void = () => {};

  const emit = (m: Msg, raw: string) => {
    if (done || !passes(m, filters)) return;
    if (!opened) {
      pending.push({ m, raw });
      return;
    }
    sendOut(encode(kind, m, raw)).catch(() => cleanup());
  };

  let keepalive: ReturnType<typeof setInterval> | undefined;
  let maxTimer: ReturnType<typeof setTimeout> | undefined;
  const cleanup = () => {
    if (done) return;
    done = true;
    if (keepalive) clearInterval(keepalive);
    if (maxTimer) clearTimeout(maxTimer);
    for (const ws of upstreams) {
      try {
        ws.close(1000, "bye");
      } catch {
        // ignore
      }
    }
    finish();
  };

  try {
    for (const t of topics) {
      const r = await env.TOPIC.getByName(t).fetch(`https://topic/ws?since=${encodeURIComponent(since)}`, {
        headers: { Upgrade: "websocket" },
      });
      const ws = r.webSocket;
      if (!ws) throw new Error(`topic ${t}: no websocket (${r.status})`);
      ws.accept();
      ws.addEventListener("message", (e) => {
        if (typeof e.data !== "string") return;
        try {
          emit(JSON.parse(e.data) as Msg, e.data);
        } catch {
          // ignore malformed
        }
      });
      ws.addEventListener("close", () => cleanup());
      ws.addEventListener("error", () => cleanup());
      upstreams.push(ws);
    }
  } catch (e) {
    cleanup();
    console.log(`subscribe failed: ${e}`);
    return err(500, 50001, "internal server error");
  }

  const ka = Math.max(10, Number(env.KEEPALIVE_SECONDS || 45)) * 1000;
  const maxS = Math.max(60, Number(env.STREAM_MAX_SECONDS || 1200));
  const event = (ev: string): Msg => ({ id: randomId(), time: now(), event: ev, topic: topicsStr });
  const start = () => {
    const open = event("open");
    sendOut(encode(kind, open, toJson(open))).catch(() => cleanup());
    opened = true;
    for (const x of pending.splice(0)) sendOut(encode(kind, x.m, x.raw)).catch(() => cleanup());
    keepalive = setInterval(() => {
      const k = event("keepalive");
      sendOut(encode(kind, k, toJson(k))).catch(() => cleanup());
    }, ka);
    // Close a little before the limit, with jitter so many clients do not reconnect at once.
    maxTimer = setTimeout(() => cleanup(), (maxS - Math.floor(Math.random() * 30)) * 1000);
  };

  if (kind === "ws") {
    const pair = new WebSocketPair();
    const client = pair[1];
    client.accept();
    sendOut = async (s: string) => {
      client.send(s);
    };
    finish = () => {
      try {
        client.close(1000, "reconnect");
      } catch {
        // ignore
      }
    };
    client.addEventListener("close", () => cleanup());
    client.addEventListener("error", () => cleanup());
    start();
    return new Response(null, { status: 101, webSocket: pair[0] });
  }

  const ts = new TransformStream<Uint8Array, Uint8Array>();
  const writer = ts.writable.getWriter();
  const enc = new TextEncoder();
  sendOut = (s: string) => writer.write(enc.encode(s));
  finish = () => {
    writer.close().catch(() => {});
  };
  start();
  return new Response(ts.readable, {
    headers: {
      "Content-Type": CONTENT_TYPE[kind],
      "Cache-Control": "no-cache, no-store, no-transform",
      "X-Accel-Buffering": "no",
      ...CORS,
    },
  });
}

// ---------------------------------------------------------------- other endpoints

function landing(url: URL): Response {
  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>ntfy server</title><style>body{font-family:system-ui,sans-serif;max-width:40rem;margin:3rem auto;padding:0 1rem;line-height:1.5;color:#222}code{background:#f2f2f2;padding:.1rem .3rem;border-radius:4px}</style></head>
<body><h1>ntfy-compatible server</h1>
<p>This is a small <a href="https://ntfy.sh">ntfy</a>-compatible push server (Molaplan). There is no web app here;
use the ntfy apps or any HTTP client with the base URL <code>${url.origin}</code>.</p>
<p>Publish: <code>curl -d "Hello" ${url.origin}/your-secret-topic</code><br>
Subscribe: <code>curl -s ${url.origin}/your-secret-topic/json</code></p>
<p>Topic names work like passwords: anyone who knows a topic can read and write it. Messages are kept for about 12 hours.</p>
</body></html>`;
  return new Response(html, { headers: { "Content-Type": "text/html; charset=utf-8" } });
}

function account(env: Env): Response {
  const ttl = Number(env.CACHE_SECONDS || 43200);
  const big = 1_000_000;
  return json({
    username: "*",
    role: "anonymous",
    language: "en",
    notification: {},
    subscriptions: [],
    reservations: [],
    tokens: [],
    phone_numbers: [],
    limits: {
      basis: "ip",
      messages: big,
      messages_expiry_duration: ttl,
      emails: 0,
      calls: 0,
      reservations: 0,
      attachment_total_size: 100 * ATTACHMENT_LIMIT,
      attachment_file_size: ATTACHMENT_LIMIT,
      attachment_expiry_duration: ttl,
      attachment_bandwidth: 1000 * ATTACHMENT_LIMIT,
    },
    stats: {
      messages: 0,
      messages_remaining: big,
      emails: 0,
      emails_remaining: 0,
      calls: 0,
      calls_remaining: 0,
      reservations: 0,
      reservations_remaining: 0,
      attachment_total_size: 0,
      attachment_total_size_remaining: 100 * ATTACHMENT_LIMIT,
    },
  });
}

function config(url: URL): Response {
  return json({
    base_url: url.origin,
    app_root: "/app",
    enable_login: false,
    require_login: false,
    enable_signup: false,
    enable_payments: false,
    enable_calls: false,
    enable_emails: false,
    enable_reservations: false,
    enable_web_push: false,
    billing_contact: "",
    web_push_public_key: "",
    disallowed_topics: ["docs", "static", "file", "app", "account", "settings", "signup", "login", "v1"],
  });
}

async function handleFile(env: Env, id: string): Promise<Response> {
  if (!validId(id)) return err(404, 40401, "page not found");
  const f = await env.FILE.getByName(id).get();
  if (!f) return err(404, 40401, "page not found");
  return new Response(f.data, {
    headers: {
      "Content-Type": f.type || "application/octet-stream",
      "Content-Length": String(f.data.byteLength),
      "Content-Disposition": `inline; filename*=UTF-8''${encodeURIComponent(f.name)}`,
      "Cache-Control": "private, max-age=3600",
      ...CORS,
    },
  });
}

const RESERVED = new Set(["docs", "static", "file", "app", "account", "settings", "signup", "login", "v1"]);

export default {
  async fetch(req: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(req.url);
    const path = url.pathname.replace(/\/+$/, "") || "/";
    const m = req.method;
    const ip = clientIp(req);

    if (m === "OPTIONS") return new Response(null, { status: 200, headers: CORS });
    if (m === "GET" && path === "/v1/health") return json({ healthy: true });
    if (await limited(env.REQUEST_LIMIT, ip)) return err(429, 42901, "limit reached: too many requests, please be nice");

    try {
      if (m === "HEAD" && path === "/") return new Response(null, { status: 200 });
      if (m === "GET" && path === "/") return landing(url);
      if (m === "GET" && path === "/v1/config") return config(url);
      if (m === "GET" && path === "/v1/account") return account(env);
      if (m === "GET" && path === "/v1/tiers") return json([]);
      if (m === "GET" && path === "/v1/stats") return json({ messages: 0, messages_rate: 0 });
      if (m === "GET" && path === "/v1/version") return json({ version: VERSION, commit: "", date: "" });
      if (m === "GET" && path === "/config.js") {
        return new Response(`var config = ${JSON.stringify({ base_url: url.origin, app_root: "/app" })};\n`, {
          headers: { "Content-Type": "application/javascript" },
        });
      }
      const file = /^\/file\/([A-Za-z0-9]{12})(\.[A-Za-z0-9]{1,8})?$/.exec(path);
      if (file && (m === "GET" || m === "HEAD")) return handleFile(env, file[1]);

      if ((m === "PUT" || m === "POST") && path === "/") {
        if (await limited(env.PUBLISH_LIMIT, ip)) return err(429, 42908, "limit reached: too many messages, please be nice");
        return handlePublishJson(req, env, ctx, url);
      }

      const sub = TOPICS_RE.exec(path);
      if (sub && m === "GET") {
        const topics = sub[1].split(",");
        if (topics.length > MAX_TOPICS) return err(400, 40009, "invalid topic: too many topics");
        if (sub[2] === "auth") return json({ success: true });
        return handleSubscribe(req, env, url, topics, sub[2] as Kind);
      }

      const pub = /^\/([-_A-Za-z0-9]{1,64})(?:\/(publish|send|trigger))?$/.exec(path);
      if (pub && !RESERVED.has(pub[1])) {
        const topic = pub[1];
        if ((m === "PUT" || m === "POST") && !pub[2]) {
          if (await limited(env.PUBLISH_LIMIT, ip)) return err(429, 42908, "limit reached: too many messages, please be nice");
          return handlePublishPath(req, env, ctx, url, topic, true);
        }
        if (pub[2] && (m === "GET" || m === "PUT" || m === "POST")) {
          if (await limited(env.PUBLISH_LIMIT, ip)) return err(429, 42908, "limit reached: too many messages, please be nice");
          return handlePublishPath(req, env, ctx, url, topic, m !== "GET");
        }
        if (m === "GET" && !pub[2]) {
          const up = param(req, url, "x-unifiedpush", "unifiedpush", "up");
          if (up && toBool(up)) return json({ unifiedpush: { version: 1 } });
          return landing(url);
        }
      }
      return err(404, 40401, "page not found");
    } catch (e) {
      console.log(`error ${m} ${path}: ${e instanceof Error ? e.stack || e.message : e}`);
      return err(500, 50001, "internal server error");
    }
  },
} satisfies ExportedHandler<Env>;
