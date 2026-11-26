# molaplan-ntfy – ntfy-compatible server on Cloudflare (free plan)

Live: https://ntfy.molaplan.com (also https://molaplan-ntfy.molaplan1.workers.dev)

- Worker + SQLite Durable Object per topic (`Topic`) and per attachment (`FileStore`).
- Streaming subscribers are held by the Worker; it connects to the topic object with a WebSocket
  that the object accepts with the Hibernation API (no Durable Object duration while idle).
- Streams close after `STREAM_MAX_SECONDS` (1200) and clients reconnect with `since=<id>`.
- Poll requests are forwarded to `UPSTREAM_BASE_URL` (ntfy.sh) for the iOS app (ntfy's upstream-base-url).
  Publish with `Firebase: no` to skip that for a message.
- Not supported: login/ACL, scheduled delivery (delay/at/in → 400), e-mail/call, web app, UnifiedPush rate visitors.

Deploy: `npm install && bash -lc 'CLOUDFLARE_API_TOKEN="$MOLAPLAN_CLOUDFLARE_TOKEN" CLOUDFLARE_ACCOUNT_ID=289dfd5c3dad74a2c9632406634f1e80 npx wrangler deploy'`

Test: `BASE=https://ntfy.molaplan.com node test/e2e.mjs` (random `mpltest-…` topics only).
Local: `npx wrangler dev --port 8799 --local --var UPSTREAM_BASE_URL:` then `BASE=http://localhost:8799 node test/e2e.mjs`
(`KEEPALIVE_TEST=1` with `--var KEEPALIVE_SECONDS:10 --var STREAM_MAX_SECONDS:60`).
