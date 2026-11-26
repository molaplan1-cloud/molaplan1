# Molaplan order shop – tilaussivu (R240–R247)

A shop-like **order request** page: customers browse products and services, fill a cart and send an
order request. Nothing is paid on the site; the seller replies with an offer and invoices through a
light-entrepreneur invoicing service. No company / Y-tunnus is claimed anywhere.

## Where it lives
| What | Where |
|---|---|
| Static pages (fi/en/sv/es) | `web-site/tilaa/` (served at `/tilaa/`) |
| Worker (API + serves the pages) | `web-site/shop-worker/` → Cloudflare Worker `molaplan-shop` |
| Live | https://shop.molaplan.com/tilaa/ (custom domain of the Worker) |
| molaplan.com | https://molaplan.com/tilaa/ = the same `web-site/tilaa` folder inside the Pages build (`tool/web/build_web.sh` copies it); its pages call the Worker API cross-origin (`API` in `assets/common.js`, CORS in the Worker) |
| Admin | `/tilaa/hallinta/` (installable on the phone home screen) |
| Customer downloads | `/tilaa/lataa/` |
| Privacy notice | `/tilaa/tietosuoja/` |
| Database | `supabase/migrations/20261126200000_shop.sql` (+ `…200100_shop_storage.sql`, Supabase-only: buckets, storage policies, pg_cron purge) |

### Integration with the web app / PWA (molaplan.com)
- The web build script copies **only** `web-site/tilaa` (static files, no Worker source) to `build/web/tilaa`. Keep it that way.
- Shop changes reach molaplan.com/tilaa only with the next Pages deploy; shop.molaplan.com is updated by `web-site/shop-worker/deploy.sh`.
- Optional, cleaner: give the Cloudflare API token **Zone → Workers Routes → Edit** and add the `molaplan.com/tilaa*` routes listed in `web-site/shop-worker/wrangler.jsonc`; then the Worker serves molaplan.com/tilaa directly, independent of Pages deploys.
- The web UI intro (logged-out view) should link **"Tilaa" → `/tilaa/`** (and the admin to nothing – it is not linked publicly). The intro belongs to the web UI task; add the link there.
- The Flutter service worker must not cache or intercept `/tilaa/*` (navigation to /tilaa must hit the network).

## Deploy
```
cd web-site/shop-worker && npm ci && npm test
bash -lc 'CLOUDFLARE_API_TOKEN=$MOLAPLAN_CLOUDFLARE_TOKEN CLOUDFLARE_ACCOUNT_ID=289dfd5c3dad74a2c9632406634f1e80 web-site/shop-worker/deploy.sh'
```
Worker secrets (`wrangler secret put`, values never in git):
- `SHOP_SECRET` – random; its sha256 is in `private.shop_secret`. Only the Worker can call `shop_submit_order` / `shop_log_message`. Rotate: new random value → update the hash row → `wrangler secret put SHOP_SECRET`.
- `TURNSTILE_SECRET` – Turnstile widget `molaplan-shop` (sitekey in `wrangler.jsonc`).
- `RESEND_API_KEY` (optional) – when set, emails go through Resend (molaplan.com is already verified there for the account emails), which sends to any address on its free tier. Without it the Worker uses Cloudflare Email Service (`send_email` binding, molaplan.com onboarded); on the Workers **Free** plan that only reaches verified destination addresses.

## Admins
`private.shop_admins` (email, lower case). Nothing is shipped by default; the deployment adds its own:
`insert into private.shop_admins (email) values ('owner@example.com');`
Admins sign in on `/tilaa/hallinta/` with their Molaplan account (email code or password).

## Data model
- `shop_products` – name, summary, description, category, kind (software/device/service; software needs no address),
  price_mode `fixed` (price_cents + price_note shown) or `quote` ("Tilauskohtainen hinta – pyydä tarjous"), image (public bucket `shop-images`),
  quantity on/off + max, ask_notes + label, `unlocks_pc_app`, hidden, sort, i18n `{en|sv|es: {name, summary, description, category}}`.
  Anyone reads visible products; only admins write.
- `shop_orders` – customer data, item snapshot (names/prices copied from the DB at submit, never trusted from the client), status
  `uusi → tarjottu → laskutettu → maksettu → toimitettu` / `peruttu`, seen flag, offer_cents, admin_notes. Admin-only; inserts only through `shop_submit_order(secret, payload)`.
- `shop_order_messages` – thread per order: `auto` (confirmation / notifications, with delivery result), `out` (admin replies), `status` (trigger logs every status change).
- `shop_settings` – seller name + contact email (public through `shop_public_info()`), notification emails, ntfy topic, reply templates.

## Order flow
1. Cart in `localStorage` (`molaplan-shop-cart-v1`); checkout asks name, email, phone (optional), address (required only when the cart has a device/service), message, consent.
2. Anti-spam: Turnstile, honeypot field, Worker rate limits (5 orders/min/IP, 60 API calls/min/IP), max 5 orders/hour per email in the DB, secret-gated RPC.
3. The Worker sends the customer confirmation (in the customer's language), then notifies the owner by email and ntfy (`https://ntfy.molaplan.com/<topic>`, click opens the order). Every attempt is logged on the order with the error code if it failed.

## Admin flow (mobile-first)
- **Tilaukset**: red badge = unseen/new orders (also in the tab title), filters Avoimet / each status / Kaikki with counts, search, auto-refresh every 60 s and when the app comes to the foreground.
- **Order**: one-tap status buttons, tap-to-call / mail, offer price (saved on the order), private notes (autosave), reply with templates
  (`{nimi} {numero} {hinta} {myyjä} {lataus} {sähköposti}`; a template can also set the status), **Lähetä sähköposti** (from tilaukset@molaplan.com, reply-to = contact email) or
  **Avaa Mail-sovelluksessa** (mailto with the same text, logged on the thread). Delete order (GDPR erasure).
- **Tuotteet**: add / edit / hide / reorder / delete, image from the phone camera or gallery (shrunk to ≤ 1600 px WebP), fixed price or quote, translations.
- **Asetukset**: seller name, contact email, notification emails, ntfy topic (generate), reply templates, "Lähetä testiviesti itselle", "Päivitä PC-sovellus latauksiin".

## PC app download unlock
- An order containing a product with `unlocks_pc_app` sets `shop_orders.unlocks_pc_app`.
- When such an order is `maksettu` or `toimitettu`, `private.has_pc_license()` is true for a signed-in account whose email equals the order email.
- The customer signs in on `/tilaa/lataa/` (email code; an account is created if missing) → Worker `/tilaa/api/download` → a **signed Storage URL valid 1 h** for the newest `shop-downloads/pc/*.zip` (private bucket; read policy = has_pc_license). If no copy exists yet, it falls back to the GitHub release asset.
- Admin → Asetukset → "Päivitä PC-sovellus latauksiin" copies the latest release's `molaplan-windows-x64.zip` into the bucket (`/tilaa/api/sync-pc`).
- Note: the GitHub repository and its releases are public (the apps update from them), so the zip is also reachable there. Making it truly private needs a private release channel for the Windows build.

## Privacy / retention
`/tilaa/tietosuoja/` (fi + en). pg_cron job `shop-purge` (daily 03:17 UTC) deletes requests that never became a sale after 24 months and invoiced/paid/delivered orders after 7 years.

## Tests
- `bash tool/rls_test.sh` – includes `supabase/tests/shop_rls_test.sql` (anon/customer/admin permissions, secret gate, snapshot + clamping, status log, download unlock by email).
- `cd web-site/shop-worker && npm test` – validation, emails, templates.
- Live (not CI): `test/e2e-live.cjs` (customer flow incl. Turnstile, run headed) and `test/e2e-admin-live.cjs` (admin flow with a throw-away admin account).
