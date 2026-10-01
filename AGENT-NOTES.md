# Guest mode – agent progress log

## Step 1 (worker 3, started 07:31 box time = UTC) – state assessment
Inherited from crashed worker (07:05-07:17), diffed against /workspace/molaplan-backups/before-guest-0704.tgz:
- schema.sql: section 5b added (anon column grants + RLS on activities/events/help_requests, lat/lng_approx generated cols,
  guest_events / guest_help_requests security_invoker views, count functions). NOT yet verified whether applied to real DB.
- index.html: landing (#landing), loadPublic(), auth prompt sheet (#auth-prompt), resumePending(), guest header, city icon added.
- i18n.js: guest.* and land.* keys in all 4 langs; desk.note rewritten.
- mock-supabase.js: guestView() for anon.
- test.js / test-i18n.js: guest-mode sections added.
Next: run tests, fix failures.

## Step 2 – tests green on inherited code
- node test.js -> 85/85 passed; node test-i18n.js -> 204/204 passed (server: python3 -m http.server 8765 in /workspace/molaplan, already running).
- Real DB already has guest_events / guest_help_requests (anon: activities ok, messages/contacts 42501) -> 5b seems applied; will re-apply to be sure.
- Fixed es gate.errorBody ("podemos" matched grep "demo"). grep demo|prototyyp|esimerkki in runtime files now clean.
- /workspace/molaplan-e2e/e2e-real.js already adapted by previous worker for guest flow (not yet run).
Next: v3 screenshots (shots-v3.js), visual check of city icon + landing, re-apply schema, RLS curl check, e2e, deploy copy.

## Step 3 – screenshots done
- New script shots-v3.js (mock, seeds localized sample data) -> shots/v3-guest-landing.png, v3-guest-landing-en.png, v3-guest-map.png,
  v3-login-sheet.png, v3-home-es.png, v3-home-sv.png (+ v3-guest-home.png). Checked visually: city icon renders in filter row,
  top-corner EN/FI/ES/SV switcher, wide-screen desk-note translated (no "prototyyppi").
Next: re-apply schema.sql to real DB, curl RLS check, run e2e-real.js, rerun tests, deploy copy.

## Step 4 – schema applied to real DB + RLS verified
- Applied with: supabase db query --linked --project-ref fhuqbzdumxlqmgibhobl -f supabase/schema.sql --agent no (Management API; no DB password needed).
- Added to schema.sql: revoke execute on is_admin/can_help/is_helper/is_conversation_member from public, anon (re-applied OK).
- anon grants now: SELECT on guest_events/guest_help_requests views + column grants on activities/events/help_requests only.
- curl with anon key: guest_events/guest_help_requests/activities 200; events.host_id, help_requests.place/lat/lng/requester_id,
  help_request_contacts, messages, conversations, profiles, profile_private, notifications, event_participants, help_offers -> 401 (42501);
  guest_help_requests.phone/place -> 400 (column does not exist); rpc/is_admin -> 401.
Next: run e2e-real.js (live smoke), rerun tests, deploy copy.

## Step 5 – live smoke test passed
- e2e-real.js (added: anon contact/address column checks; cleanup of notifications/events/help_requests linked to test rows):
  31/31 checks passed; leftovers: events 0, help requests 0, e2e users 0, notifications/messages mentioning E2E 0.
Next: rerun test.js + test-i18n.js, copy runtime files to /workspace/molaplan-deploy.

## Step 6 (07:39 box time/UTC) – DONE
- test-i18n.js: added static check "runtime files contain no demo/prototype wording".
- Final runs: test.js 85/85, test-i18n.js 205/205 (all passed).
- /workspace/molaplan-deploy/ replaced with index.html, config.js, i18n.js, cities.js (only local files index.html loads;
  mock-supabase.js excluded, it is loaded dynamically only with ?mock=1). NOT deployed to Cloudflare.
- Auth settings untouched (email confirmation stays ON).
Nothing left from the task list. Possible follow-ups: brand slogan "¡Mola el plan!" intentionally untranslated (brand);
index.prototype.html / test.prototype.js are old non-runtime files still in the project folder (not deployed).

# Cities task (Stockholm, London, Madrid) – started 2026-09-26 07:49 box time
## C0 – backup
- /workspace/molaplan-backups/before-cities-0749.tgz (node_modules excluded)
## C1 – study done
- cities.js format: {id, sv, c:[lat,lng], z, areas:[{fi, sv, d:[[name, svName|0, lat, lng]]}]}; index.html builds CITIES/DSV from it,
  cityLabel() (sv only), areaLabel(), cityOptions() in array order. district name = stored value, max 40 chars (schema check).
- schema.sql: city/district only char_length checks (no enum) -> likely no DB change. Overpass: overpass.kumi.systems works (overpass-api.de 406).
## C2 – data gathering (in progress)
- Stockholm: now 11 stadsdelsområden (Järva, Norra innerstaden merged 2023; source start.stockholm), NOT 13. Stadsdelar from Wikidata
  (P31 Q2983893, P131 Stockholms kommun, 115) + extras; area assignment via OSM level-9 polygons (citydata/sthlm_geom.json).
- Madrid: OSM 21 distritos + 131 barrios (citydata/madrid_admin.json centers). Work dir /workspace/citydata.
- EXTRA TASK queued (from parent, 10:57): location-first landing (geolocation -> nearest city/district, all events by distance,
  List/Map toggle, distance on cards, you-are-here marker), no forced sport selection, tests + v4-location/near-me shots.
## C3 – cities.js written (07:5x UTC... see mtime)
- Added "cc" country code to all cities; appended Stockholm (11 områden/122), London (33 boroughs incl. City/359), Madrid (21/131).
  Build: /workspace/citydata/build_cities.py (+ madrid_list.py, london_list.py, *_pts.json). Header comment lists sources.
Next: index.html (cityLabel i18n, country optgroups), i18n keys.
- index.html: cityLabel() uses i18n 'cityname.<id>' when present; cityOptions() groups by country (optgroup 'country.<cc>').
## L1 – location-first design (starting index.html edits)
- HERE (molaplan.here in localStorage), nearestPlace() over all district points (<=50 km), landing: #land-locate primary,
  #land-manual-btn reveals picker (#land-manual, hidden by default; expanded on deny/too-far/"Change area"), auto if permission granted.
- Distance sort + .dist-pill on cards when HERE near view city; map centers on HERE + .me-dot; List/Map toggle (#vt-list/#vt-map, #map-list).
- Onboarding lajit step skippable (#lajit-skip), no minimum pick.
- L2: index.html patched (landing, near sort, dist pill, map toggle, me marker, lajit skip) + 28 i18n keys x4 (+land.sub reworded) via /workspace/citydata/i18n_merge.js
- L3: tests updated (test.js: landing/locate/skip + section 13 geolocation mocks; test-i18n.js: 7 cities, country groups, events in London/Madrid/Stockholm, map centering)
- L4: node test.js -> 107/107 passed
- L5: node test-i18n.js -> 236/236 passed
## C4 – DB check: live DB has only char_length checks on city/district (<=40), no enum/seed/function restricting values -> NO schema change, schema not re-applied
- L6: home header: loc pill own row (+'Vaihda aluetta'), near mode shows first 3 events before banners; shots-v4.js written & run; shots-v3.js adapted to collapsed picker
- L7: re-ran after layout change: test.js 107/107, test-i18n.js 236/236 (all passed); demo/prototyyp/esimerkki grep clean.
## DONE (08:20 box time)
- /workspace/molaplan-deploy/ updated with index.html, config.js, i18n.js, cities.js (mock-supabase.js excluded). NOT deployed; Supabase auth untouched.
- Screenshots: shots/v4-landing-stockholm-sv, v4-landing-london-en, v4-landing-madrid-es, v4-map-madrid-es, v4-home-madrid-es,
  v4-location-landing, v4-near-me-top, v4-near-me-list (tall 390x1900), v4-near-me-map (node shots-v4.js).

# Business/public events/rebalance task – started 2026-09-26 08:21 box time
## B0 – backup
- /workspace/molaplan-backups/before-business-0821.tgz (molaplan + molaplan-e2e, node_modules excluded)
## B1 – study done (08:35)
- Live DB: 0 events, 0 help requests, 1 profile (owner, admin). pg_cron NOT installed (won't install) -> expiry notices via
  admin-callable RPC business_expiry_sweep() (run when admin opens business queue) + auto-schedule only if pg_cron exists.
- i18n edits: use /workspace/citydata/i18n_merge.js <additions.json> (NOT gen.py). test-i18n derives act ids from BASE_ACTS/seed
  and notif codes from schema notify(...,'icon','code') calls -> new notif.* / act.* keys needed.
- Design: events.kind community|public|business; host_id NULL for public/business (no personal host); organizer_name,
  official_url (https), price_info, ends_at, last_at (generated coalesce(ends_at,starts_at)), business_id.
  businesses (public profile) + business_private (contact/billing; members+admin only) + business_members.
## B2 – schema.sql extended (08:50) – validated on a LOCAL scratch Postgres first
- Build files: /workspace/molaplan-build/business/ (s1b.sql, s2.sql, s3_events.sql, s3_biz.sql, s4.sql, patch_schema.py [already applied – don't rerun],
  supa_stub.sql = auth/roles stub, rls_test.sql = SQL scenario test). Local cluster: /tmp/pgtest port 55432 (pg 17, initdb, socket /tmp).
- Old schema -> new schema -> new again (idempotent) OK; fresh DB OK; rls_test.sql: non-admin public event blocked (public_event_admin_only),
  admin public event host_id NULL, pending/approved-without-subscription/expired business blocked (business_subscription_required),
  member cannot self-approve, anon: business_private/business_code/subscription denied, guest_events has business_name, no host_id.
Next: apply schema to live DB.
## B3 – schema applied to LIVE DB (08:53) – verified: 7 new events cols, 3 business tables, 4 new activities, guest_events.business_name,
  apply_business/business_expiry_sweep/valid_y_tunnus exist; owner still is_admin. Old client stays compatible (kind defaults to community).
Next: mock-supabase.js (kinds, businesses, rpc apply_business/business_expiry_sweep, guest view), then index.html UI.
## B4 – STEERING ADDITION received 11:27 (UTC+3): anti-advertising for normal events
- Create form rule text + link to business offer + required checkbox; server guard looks_commercial() in events_before_write for
  community events by non-admins (URLs/domains, emails, phone numbers, price/sales words) -> 'commercial_content'; client mirror;
  price field only for public/business (already: events_kind_fields forces price_info='' for community).
- No existing report mechanism -> new reports table (reporter, target_type/id, reason business_ad|inappropriate|spam|other, note, status),
  profiles.banned (protected) blocks events+messages (RLS + triggers), admin RPC admin_moderate(uid, action) warn/ban/unban,
  admin Reports tab (remove event / warn / ban / dismiss). Tests mock + e2e.
## B5 – moderation schema done + applied LIVE (09:05)
- schema.sql 1c: profiles.banned (profiles_protect: only changeable via admin RPC), looks_commercial(t), is_banned(), reports table;
  events_before_write raises account_banned / commercial_content (community + non-admin); messages_before_insert account_banned;
  RLS: events insert & messages insert require not is_banned(); reports RLS; RPC admin_moderate(uid, warn|ban|unban).
- Local tests (mod_test.sql): URLs/domains/emails/phones/€/eur/-20%/alennus/varaa/discount/oferta/boka/rea blocked;
  "omakustanteinen", "jaetaan kulut", "Klo 18.30-20, 4.10.2026", "10 000 askelta", "Eurooppa", "Tarjoilen" allowed.
- Build files: s_mod.sql, s_mod_trg.sql, s_mod_rls.sql, patch_schema2.py (applied, don't rerun).
Next: mock-supabase.js.
## B6 – mock-supabase.js updated
- New SEED acts, tables businesses/business_private/business_members/reports, eventRules() (kind rules, commercial guard = same regexes as looks_commercial, banned, business_can_post),
  rpc apply_business / business_expiry_sweep / admin_moderate, afterBizUpdate notifications, guest businesses (public cols only), guest_events new cols, hooks setBusiness/today.
- Smoke test: /workspace/molaplan-build/business/mock_smoke.js (40 checks PASS). Patch script patch_mock.py already applied – DON'T rerun.
## B7 – index.html v5 UI (09:55)
- Patch scripts in /workspace/molaplan-build/ui/p1..p6 (applied; DON'T rerun). Backup of pre-UI index: molaplan-build/ui/index.before-ui.html
- Data: loadAll loads businesses/business_members/business_private/reports; events by last_at; mapEvent kind/ends/org/url/price/biz; isPast uses end date.
- F1: new tagline/meta, 💚 bubble, landing pillars + "Autetaan toisiamme" card (land-help offer/ask) + <details> Yrityksille; chips Kaikki,Hyvät teot,Yritykset,normal acts,Hullut,crazy acts;
  help card (#help-card, keeps #good-banner id) above filters / after 3 cards in near mode; soft #cz-banner at the end; business events in own "Yritysten tapahtumat" section.
- F2: create modes (Oma/Julkinen/Yritys), end datetime, organiser, https url, price, max; badges, Virallinen sivu, Kiinnostaa/Lähden mukaan, "Etsi seuraa" chat; edit-event for admin/business members.
- F3: s-biz push screen (offer 49 €/kk + ALV, apply form w/ Y-tunnus normalise+check, my businesses), profile card, admin tabs Avunpyynnöt/Yritykset/Ilmoitukset (approve/reject/extend 1 kk/end/set date, sweep on open).
- Steering: rule text + required #ck-rule + live #c-adwarn (AD_RES mirror), report sheet (4 reasons + note), admin report actions (delete/warn/ban/dismiss), banned notice.
- i18n: 175 keys merged (molaplan-build/ui/i18n_add.json). test.js 109 ✓, test-i18n 236 ✓ (tests updated: tick #ck-rule; banner counter selectors).
## B8 – tests + screenshots (10:25)
- NEW test-v5.js (50 checks ✓): landing/home rebalance, guard client+server, admin public event (+edit, guest view, "Etsi seuraa"), business apply→approve→extend→event→expired→anon, sweep, end, report→ban→blocked.
- test-i18n.js: +9 scans (admin business/reports queue, business screen) → 245 ✓. test.js 109 ✓. npm test runs all three.
- shots-v5.js → shots/v5-landing, v5-landing-en, v5-home-good-deeds, v5-public-event-detail, v5-business-events, v5-create-rules, v5-business-apply, v5-admin-business-queue(-2), v5-admin-reports.
Next: e2e-real.js extensions, deploy.sh --no-deploy.

## B9 – Real e2e against the live project (2026-09-26 ~11:55 UTC+3)
- /workspace/molaplan-e2e/e2e-real.js extended (pre-change copy: molaplan-build/e2e-real.before-v5.js):
  - UI flow: clicks #land-manual-btn before the city select (picker is behind the button now) and ticks #ck-rule before publishing.
  - New throwaway admin user C (made admin via `supabase db query --linked`, guarded against the owner id).
  - v5 checks: public event admin-only, host_id null, guest view; commercial_content guard (URL/phone/price, "Varaa"), no price_info on community events, cost-sharing wording allowed; apply_business + invalid Y-tunnus; anon/other-user isolation of business_code/subscription/business_private; pending/lapsed business blocked, active allowed; notifications approved/extended/ended; sweep admin-only; report "business_ad", duplicate 409, admin-only visibility, admin notification; non-admin cannot moderate; warn + ban; banned user blocked from events and messages, cannot self-unban.
  - Cleanup now also deletes reports by target, the test business (cascade) and notifications linked to business/event ids; prints leftover businesses/reports.
- Result: ALL PASSED, 56 checks. Leftovers 0 (events, help requests, users, businesses, reports, notifications). Owner still is_admin=true, banned=false; 1 admin, 0 banned in live profiles.

## B10 – Deploy copy (NOT deployed)
- Ran `./deploy.sh --no-deploy` (no new local JS files, so deploy.sh unchanged; mock-supabase.js is only loaded on localhost and is not shipped).
- /workspace/molaplan-deploy: index.html, config.js, cities.js, i18n.js, _headers. Script tags stamped `?v=74970c0214` (3 tags); JS files are byte-identical to the source; index.html identical apart from ?v. Source index.html keeps the plain script tags.
- Served the deploy folder locally: landing renders, no page errors, no 4xx responses.
- No Cloudflare deploy and no auth-setting changes were made.

# Giveaways ('Annetaan pois'/'Tarvitaan') + privacy/terms task – started 2026-09-26 11:58 (UTC+3)
## G0 – backup
- /workspace/molaplan-backups/before-giveaways-0858.tgz (box clock label; molaplan + molaplan-e2e/e2e-real.js, node_modules excluded)

# Merge with GitHub – 2026-10-01
(times UTC+3; box clock runs UTC)
## M0 – backup (17:43)
- /workspace/molaplan-backups/before-merge-1743.tgz (whole /workspace/molaplan incl. .git, node_modules excluded).
- Local branch backup/remote-2026-09-27 -> origin/main 35f8b1b (no upstream, never pushed).
- State: working tree == fbf8cda for all app files (only node_modules deleted from disk, still tracked in fbf8cda).
## M1 – inspection of fbf8cda..origin/main (18 commits, not only friend requests)
- Baseline on working tree (== fbf8cda): test.js 109 ✓, test-i18n 245 ✓, test-v5 50 ✓.
- origin/main history: 50ee8d4 (deploy.sh mode only) · bf93eec free-form city in create form · 469c4a8 Give/Need chips (giveaways scaffolding)
  · 93f422c unlimited participants (max null), radius filter + loc button, act dropdown, desktop CSS, items(give/need) schema, reverse geocode
  · ba81ac2/a191ebb/fb52073/5b39cad layout/filter tweaks (city select removed from filters) · 042c86a teams schema · bb3623e/73bbed9 teams UI + 10 €/kk pricing
  · a015f8a profile "Vaihda aluetta" button, push.ps1/fix_schema.ps1 · b429e73 home biz/team promo cards · c0a6d06 · 6b99886 openCitySheet
  · 91a3809/c5ed0f1 friend-requests.js (localStorage prototype + best-effort Supabase sync; tables friend_requests/friends NOT in schema)
  · 38a0e13 index.html cut to 4.7 KB skeleton loading non-existent app.js (35f8b1b) -> broken.
- index.html @6b99886 (331 KB) = fbf8cda full app + all user's later UI work -> used as merge base for index.html (superset of working tree).
- Bugs found in origin code: teams UI uses columns that schema lacks (event_date/event_time/place_*/rsvp status/created_at), teams RLS
  recursive (teams<->team_members) and `m.team_id = id` compares to team_members.id; items/teams RLS+grants placed before CREATE TABLE
  (schema.sql fails on a fresh/live DB); loadAll() would fail if team tables missing; `Acts` undefined in act dropdown label;
  JSX `<>` fragment in detail spots; duplicate full-check makes unlimited community events "full"; items never loaded, no create UI.
- Giveaways: working tree has NO partial giveaway code (G0 died before edits). origin has only scaffolding (items schema, Give/Need chips, empty list).
## M2 – branch merge-2026-10-01 (from origin/main 35f8b1b, no upstream) + index.html (≈17:55–18:05)
- index.html = full app @6b99886 (fbf8cda + user's 09-26 UI work) patched by /workspace/molaplan-build/merge/patch_index.py (do not rerun):
  feature flags FF/ff() (`?ff=teams,items` or localStorage molaplan.ff) – teams UI + Give/Need hidden by default (no backend/pricing yet);
  tolerant team loading; fixed `Acts`, JSX fragment, duplicate full-check; unlimited participants ("Ei rajaa (∞)") only for public/business
  events (community stays 2–50), card chip + detail "Osallistujia enintään: Ei rajaa"; friends hooks (.prow[data-uid], #d-friends, #p-friends,
  window.MolaplanApp API, notif kind 'friend'); <script src="friend-requests.js"> after the app script.
- openCitySheet (6b99886) kept: it is the profile "Vaihda aluetta" sheet for the logged-in user; guest "Vaihda aluetta" keeps the landing picker.
## M3 – i18n.js merged (/workspace/molaplan-build/merge/i18n_build.js + i18n_add.json, re-runnable)
- all fbf8cda keys/values kept, origin keys added, missing es/sv/fi filled, new fr.* / notif.friend_* / event_invite / pub.noLimitChip keys; 1052 keys × 4 langs.
## M4 – friend-requests.js rewritten for the full app (Supabase RPCs instead of localStorage prototype)
- participant rows get Lisää kaveriksi / Pyyntö lähetetty / Hyväksy / Kaveri ✓; detail "💌 Kutsu kavereita" sheet; profile card "Kaverit"
  (incoming accept/decline, list + remove, outgoing cancel). window.MolaplanFriends {load, render, stateWith, friendIds}.
## M5 – mock-supabase.js: friend_requests, event_invites, teams tables + RPCs send/respond_friend_request, remove_friend, invite_friend_to_event
## M6 – supabase/schema.sql (base = fbf8cda schema; idempotent; no ';;' found anywhere)
- events.max_participants nullable; check: NULL only for public/business, community 2–50 (NULL-safe: `is not null and …` – a plain
  `between` would let NULL through); link_kind + 'friend'; section 7: 7a items (fixed order), 7b teams (UI columns, security-definer helpers,
  no recursion, migration from GitHub's starts_at/location_id/sent_at columns), 7c friends (friend_requests, event_invites, view friends,
  RPCs, rate limits), 7d grants (anon revoked).
- Verified on local Postgres 17 (/workspace/molaplan-sqltest): fresh DB ×2, old fbf schema → new ×2, old + GitHub-style team tables with
  data → new ×2: no errors. New scenario test 30-merge-tests.sql (friends, invites, unlimited, teams RLS, anon): ALL PASSED on all 3 DBs.
  business rls_test/mod_test outputs identical old vs new schema.
## M7 – tests adapted to the user's 09-26 UI changes + bugs fixed on the way (≈18:10)
- Activity chips → dropdown: tests use .act-filter-item; filtersHTML ids are now per context (act-filter-btn-home/-map) – before, the map
  dropdown toggled the hidden home popup (duplicate ids); added "🤪 Hullut" (CZ_ALL) item back to the dropdown.
- City filter removed by user ("Remove city restrictions"): near-me feed now includes other cities (last, by distance) – test updated;
  test-i18n map city loop replaced by map activity-menu + markers check.
- Free-form city in create: city normalised to the supported name, pin moves to a supported city when typed, district derived from the pin
  (nearest district ≤25 km, '' for unknown cities) – before, the old district/pin of the home city was saved with any typed city.
- Teams UI used undefined icon 'settings' → added; team.membersN → plural keys .one/.other.
## M8 – repo hygiene + commits on merge-2026-10-01 (≈18:15–18:20)
- `git rm -r --cached node_modules supabase/.temp`; .gitignore (node_modules/, supabase/.temp/, .env*, *.pem/*.key, *.tgz/*.zip, logs).
  shots/ stays tracked. Secret scan of tracked files: only the anon key in config.js (role=anon) + project ref; config.toml uses
  env(RESEND_API_KEY). push.ps1 / fix_schema.ps1 kept (user's Windows helpers, harmless; fix_schema.ps1 not needed – no ';;').
- deploy.sh: exec bit restored, friend-requests.js copied + ?v= stamped (same hash for all 4 local scripts, aborts if not 4).
- supabase/tests/: 00-supabase-stub.sql + friends-teams-unlimited.sql (scratch DB only).
## M9 – verification (≈18:20–18:30)
- `npm test` (now incl. test-friends.js): test.js 109 ✓, test-i18n 227 ✓ (was 245: the 7-city map-filter loop ×3 langs removed with
  the city filter, +3 map menu checks), test-v5 50 ✓, test-friends 29 ✓ → exit 0. mock_smoke.js 40 PASS / 0 FAIL.
- `./deploy.sh --no-deploy` → /workspace/molaplan-deploy (4 scripts ?v=907edb3383). Served on :8766, headless Chrome with and without
  ?mock=1 (supabase.co requests aborted – live DB never contacted): all local files 200, no console/page errors.
  (deploy hash changes if scripts change – rerun deploy.sh before a real deploy.)
- Screenshots 390×844@2x: shots/m-home.png, shots/m-friends.png, shots/m-event-unlimited.png (`SHOTS=shots node test-friends.js`).
## M10 – local main fast-forwarded to merge-2026-10-01 (nothing pushed, nothing deployed, live DB untouched)

# Live DB migration + deploy – 2026-10-01 18:28 (UTC+3; box clock runs UTC)
## D0 – start: main 8825d58, 5 ahead of origin/main 35f8b1b (fast-forward). Nothing pushed.
## D1 – live DB backup (18:29–18:33)
- `supabase db dump --linked` needs Docker (not installed) -> fallback: every public table as JSON + schema metadata via
  `supabase db query --linked -o json`: /workspace/molaplan-backups/live-db-before-merge-1829/ (+ .tgz), script export_live.sh.
  data-<table>.json (25 tables: profiles 3, events 4, event_participants 2, conversations 4, messages 5, notifications 1, …),
  auth-users-noSecrets.json (no password hashes), meta-{columns,constraints,indexes,policies,functions,views,triggers,grants,rls}.json.
## D2a – live DB had drift not made by schema.sql (dashboard changes) -> schema.sql would have failed on live
- profiles/businesses/teams.username NOT NULL *without default* -> `insert into profiles … on conflict do nothing` (line ~1540)
  and handle_new_user fail => new sign-ups were broken on live. public.friends is a TABLE (requester/addressee/status, trigger
  friends_after_change inserting into non-existent notifications.link) -> blocks `create view friends`. friend_requests in old shape.
  Team tables in dashboard shape with permissive policies (team_events/places/roles insert with check true, select true everywhere).
  "Anyone can read business usernames" select true -> pending business applications readable by every user.
  activities recreated (empty, no policies/triggers, events_activity_id_fkey gone). search_profiles() security definer, anon-callable.
- Local replica: /workspace/molaplan-sqltest/live-replica (build.sh = stub + fbf8cda schema + extras.sql drift + live-data.sql);
  metadata diff vs live snapshot = only formatting/pgcrypto-location noise.
- Fix: schema.sql section 5b (conditional drift handling) + activities FK restore after seed. Commit 9b8ec7f.
  Replica: applies 3× without errors; RLS suite 64 OK (empty drift replica), merge suite 39 OK (replica with live data);
  fresh DB run.sh OK (10-rls-tests.sql seed count fixed 30→34, stale test).
