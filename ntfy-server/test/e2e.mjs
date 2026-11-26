// End-to-end test against a running server: BASE=http://localhost:8799 node test/e2e.mjs
// Uses random test topics only (never real device topics).
const BASE = (process.env.BASE || "http://localhost:8799").replace(/\/$/, "");
const rnd = () => "mpltest-" + Math.random().toString(36).slice(2, 12);
let fails = 0;
const ok = (c, name, extra = "") => { console.log(`${c ? "PASS" : "FAIL"} ${name}${extra ? " – " + extra : ""}`); if (!c) fails++; };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function lines(url) {
  const r = await fetch(url);
  return (await r.text()).split("\n").filter(Boolean).map((l) => JSON.parse(l));
}

async function stream(url, ms) {
  const ctl = new AbortController();
  const r = await fetch(url, { signal: ctl.signal });
  const out = []; let buf = "";
  const reader = r.body.getReader(); const dec = new TextDecoder();
  const t0 = Date.now();
  const timer = setTimeout(() => ctl.abort(), ms);
  try {
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      buf += dec.decode(value, { stream: true });
      let i; while ((i = buf.indexOf("\n")) >= 0) { const l = buf.slice(0, i); buf = buf.slice(i + 1); if (l.trim()) out.push({ at: Date.now() - t0, l }); }
    }
  } catch {}
  clearTimeout(timer);
  return { status: r.status, type: r.headers.get("content-type"), out };
}

const health = await (await fetch(`${BASE}/v1/health`)).json();
ok(health.healthy === true, "/v1/health");

// publish via body + headers (RFC 2047 title, like the panel firmware)
const t1 = rnd();
const title = "Hälytys ✓";
const encTitle = "=?UTF-8?B?" + Buffer.from(title).toString("base64") + "?=";
let r = await fetch(`${BASE}/${t1}`, { method: "POST", body: "Hei maailma", headers: { Title: encTitle, Priority: "high", Tags: "warning,camera", Click: "https://example.com" } });
const p1 = await r.json();
ok(r.status === 200 && p1.event === "message" && p1.topic === t1 && p1.message === "Hei maailma" && p1.title === title && p1.priority === 4 && p1.tags?.join() === "warning,camera" && p1.id?.length === 12 && p1.expires > p1.time, "publish POST /<topic>", JSON.stringify(p1));
ok(Object.keys(p1).join() === "id,time,expires,event,topic,title,message,priority,tags,click", "ntfy field order", Object.keys(p1).join());

// JSON publish to /
r = await fetch(`${BASE}/`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ topic: t1, message: "json viesti", title: "Tila JSON", priority: 3, tags: ["bell"], actions: [{ action: "http", label: "Kuittaa", url: `${BASE}/${t1}`, body: "x" }] }) });
const p2 = await r.json();
ok(r.status === 200 && p2.message === "json viesti" && p2.title === "Tila JSON" && p2.actions?.[0]?.label === "Kuittaa" && p2.actions[0].id, "publish JSON POST /");

// PUT + query params
r = await fetch(`${BASE}/${t1}?title=q&priority=1&tags=a`, { method: "PUT", body: "kolmas" });
const p3 = await r.json();
ok(p3.title === "q" && p3.priority === 1 && p3.message === "kolmas", "publish PUT with query params");

// GET /publish
r = await fetch(`${BASE}/${t1}/publish?message=nelj%C3%A4s&t=gettitle`);
const p4 = await r.json();
ok(p4.message === "neljäs" && p4.title === "gettitle", "publish GET /<topic>/publish");

// poll
let ms = await lines(`${BASE}/${t1}/json?poll=1`);
ok(ms.length === 4 && ms[0].id === p1.id && ms[3].id === p4.id, "poll=1 returns all cached", `${ms.length}`);
ms = await lines(`${BASE}/${t1}/json?poll=1&since=${p2.id}`);
ok(ms.length === 2 && ms[0].id === p3.id, "poll since=<id>");
ms = await lines(`${BASE}/${t1}/json?poll=1&since=10m`);
ok(ms.length === 4, "poll since=10m");
ms = await lines(`${BASE}/${t1}/json?poll=1&since=${p1.time}`);
ok(ms.length === 4, "poll since=<unix>");
ms = await lines(`${BASE}/${t1}/json?poll=1&since=latest`);
ok(ms.length === 1 && ms[0].id === p4.id, "poll since=latest");
ms = await lines(`${BASE}/${t1}/json?poll=1&since=none`);
ok(ms.length === 0, "poll since=none");
// iOS app single-message fetch: /json?poll=1&id=<id>
r = await fetch(`${BASE}/${t1}/json?poll=1&id=${p2.id}`);
const single = await r.text();
ok(single.trim().split("\n").length === 1 && JSON.parse(single).id === p2.id, "poll=1&id=<id> (iOS poll_request fetch)");
ms = await lines(`${BASE}/${t1}/json?poll=1&priority=high`);
ok(ms.length === 1 && ms[0].id === p1.id, "filter priority=high");
ms = await lines(`${BASE}/${t1}/json?poll=1&tags=camera`);
ok(ms.length === 1, "filter tags");
r = await fetch(`${BASE}/${t1}/json?poll=1&since=bogus`);
ok(r.status === 400, "invalid since -> 400");

// multi-topic poll
const t2 = rnd();
await fetch(`${BASE}/${t2}`, { method: "POST", body: "toinen aihe" });
ms = await lines(`${BASE}/${t1},${t2}/json?poll=1`);
ok(ms.length === 5 && ms.some((m) => m.topic === t2), "multi-topic poll");

// sse + raw poll
r = await fetch(`${BASE}/${t1}/sse?poll=1&since=latest`);
let txt = await r.text();
ok(r.headers.get("content-type").startsWith("text/event-stream") && txt.startsWith("data: {") , "sse poll");
r = await fetch(`${BASE}/${t1}/raw?poll=1`);
txt = await r.text();
ok(txt.split("\n")[0] === "Hei maailma", "raw poll");

// auth / account / config
ok((await (await fetch(`${BASE}/${t1}/auth`)).json()).success === true, "/<topic>/auth");
const acct = await (await fetch(`${BASE}/v1/account`)).json();
ok(acct.role === "anonymous" && acct.limits?.messages > 0, "/v1/account");
ok((await (await fetch(`${BASE}/v1/config`)).json()).base_url, "/v1/config");
ok((await (await fetch(`${BASE}/${t1}?up=1`)).json()).unifiedpush?.version === 1, "unifiedpush discovery");

// streaming json: open first, then live message, the panel's since=<id> style
const t3 = rnd();
const s = stream(`${BASE}/${t3}/json`, 4000);
await sleep(1200);
const live = await (await fetch(`${BASE}/${t3}`, { method: "POST", body: "live!" })).json();
const sres = await s;
const evs = sres.out.map((x) => JSON.parse(x.l));
ok(sres.type?.startsWith("application/x-ndjson") && evs[0]?.event === "open" && evs.some((e) => e.event === "message" && e.id === live.id), "stream /json open + live message", JSON.stringify(evs.map((e) => e.event)));
const lat = sres.out.find((x) => x.l.includes(live.id));
console.log(`     live message arrived ${lat ? lat.at : "?"} ms after stream start`);

// stream with since=<id> replays later messages first
const s2 = stream(`${BASE}/${t1}/json?since=${p3.id}`, 2500);
const evs2 = (await s2).out.map((x) => JSON.parse(x.l));
ok(evs2[0]?.event === "open" && evs2[1]?.id === p4.id && evs2.length === 2, "stream since=<id> backlog", JSON.stringify(evs2.map((e) => e.event)));

// sse streaming
const s3 = stream(`${BASE}/${t3}/sse`, 2500);
await sleep(1000);
await fetch(`${BASE}/${t3}`, { method: "POST", body: "sse live" });
const s3r = await s3;
ok(s3r.out[0]?.l.startsWith("event: open") && s3r.out.some((x) => x.l.includes("sse live")), "stream /sse");

// websocket
{
  const t4 = rnd();
  const ws = new WebSocket(`${BASE.replace(/^http/, "ws")}/${t4}/ws`);
  const got = [];
  ws.onmessage = (e) => got.push(JSON.parse(e.data));
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
  await sleep(800);
  await fetch(`${BASE}/${t4}`, { method: "POST", body: "ws live" });
  await sleep(1500);
  ws.close();
  ok(got[0]?.event === "open" && got.some((m) => m.message === "ws live"), "stream /ws", JSON.stringify(got.map((m) => m.event)));
}

// attachment (like the panel: PUT + Filename)
{
  const jpg = new Uint8Array(150 * 1024); jpg[0] = 0xff; jpg[1] = 0xd8; for (let i = 2; i < jpg.length; i++) jpg[i] = i % 251;
  const fr = await fetch(`${BASE}/${t1}`, { method: "PUT", body: jpg, headers: { Filename: "cam1.jpg", Title: "Kuva", Tags: "camera" } });
  const fm = await fr.json();
  ok(fm.attachment?.name === "cam1.jpg" && fm.attachment.type === "image/jpeg" && fm.attachment.size === jpg.length, "attachment publish", JSON.stringify(fm.attachment));
  const dl = await fetch(BASE + new URL(fm.attachment.url).pathname);
  ok(fm.attachment.url.startsWith("https://") || BASE.startsWith("http://localhost"), "attachment url https", fm.attachment.url);
  const b = new Uint8Array(await dl.arrayBuffer());
  ok(dl.status === 200 && b.length === jpg.length && b[100] === jpg[100] && b[b.length - 1] === jpg[jpg.length - 1], "attachment download");
  const big = await fetch(`${BASE}/${t1}`, { method: "POST", body: "x".repeat(5000) });
  const bm = await big.json();
  ok(bm.attachment && bm.message.startsWith("You received a file"), "long text -> attachment");
}

// limits / errors
r = await fetch(`${BASE}/${t1}`, { method: "POST", body: "x", headers: { Priority: "9" } });
ok(r.status === 400, "invalid priority -> 400");
r = await fetch(`${BASE}/${t1}`, { method: "POST", body: "x", headers: { Delay: "10m" } });
ok(r.status === 400, "delay unsupported -> 400");
r = await fetch(`${BASE}/v1/nothing`);
ok(r.status === 404, "unknown path -> 404");

// keepalive + forced reconnect (KEEPALIVE_TEST=1: server started with KEEPALIVE_SECONDS=10, STREAM_MAX_SECONDS=60)
if (process.env.KEEPALIVE_TEST) {
  const t5 = rnd();
  const t0 = Date.now();
  const k = await stream(`${BASE}/${t5}/json`, 95000);
  const kinds = k.out.map((x) => JSON.parse(x.l).event);
  const dur = Date.now() - t0;
  ok(kinds.filter((e) => e === "keepalive").length >= 2, "keepalive events", kinds.join());
  ok(dur < 92000, "stream closed by server for reconnect", `${dur} ms`);
}

console.log(fails ? `\n${fails} FAILED` : "\nALL PASSED");
process.exit(fails ? 1 : 0);
