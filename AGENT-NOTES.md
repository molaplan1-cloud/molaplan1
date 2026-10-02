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
## D2 – schema applied to live (≈18:50)
- `supabase db query --linked -f supabase/schema.sql --agent no` (9b8ec7f) -> no error, exit 0.
- Verified: friend_requests/event_invites/items/item_contacts tables, friends = VIEW, RPCs send/respond_friend_request,
  remove_friend, invite_friend_to_event, are_friends, submit_item, close_item, is_team_member; friends_after_change dropped;
  events.max_participants nullable (check: NULL only for non-community); link_kind incl. 'friend'; username defaults set;
  activities 34 + events_activity_id_fkey restored; 0 legacy team/business policies; search_profiles not executable by anon.
  Data unchanged: 3 profiles, 4 events, 5 messages, 1 notification, 2 participants; owner is_admin=true, banned=false.
## D3 – real e2e on live (≈18:55–19:00)
- e2e-real.js (unchanged, copy in molaplan-build/e2e-real.before-merge.js): ALL PASSED 56 checks, leftovers 0.
- NEW /workspace/molaplan-e2e/e2e-friends-real.js: 4 throwaway users (D host, E friend, X third party, F admin via SQL, owner guarded),
  UI in headless Chrome with injected Supabase sessions: add friend from participant row -> notification -> accept in profile card ->
  friend_accepted notif -> friends view both ways -> invite from detail sheet -> single event_invite notif -> remove friend -> invite
  rejected; RLS: 3rd user/anon/direct insert/foreign accept/self/search_profiles anon; admin creates public "Ei rajaa (∞)" event in
  the UI -> max null, guest view, 3 joins; community null rejected; non-admin public rejected. ALL PASSED 48 checks.
  Cleanup: users deleted (cascade) + admin event + linked notifications; leftovers all 0; owner untouched.
## D4 – Pages git integration (GET /accounts/{id}/pages/projects/molaplan, ≈19:05) – settings NOT changed
- source: github molaplan1-cloud/molaplan1 (= local origin), production_branch main, deployments_enabled=true,
  production_deployments_enabled=true, preview_deployment_setting=all (every branch -> preview), pr_comments on.
- build_config: build_command "", destination_dir "" (repo root), root_dir "" -> a push serves the WHOLE repo as-is.
- latest_deployment b1bf50c9 = github:push 35f8b1b (09-27 11:35 UTC+3), but canonical (served on molaplan.com / pages.dev)
  = 5309f7aa ad_hoc 09-26 10:40 UTC+3 (rollback). Git deploys b1bf50c9/e4fbfa17/d407b1ac/3cddf3f4 still reachable on their
  <id>.molaplan.pages.dev URLs incl. /AGENT-NOTES.md (owner email/ids/project ref; no secrets).
- Git build of current main would work functionally (index.html + 4 scripts in root) but: no ?v stamping, no deploy _headers,
  and publishes AGENT-NOTES.md, supabase/schema.sql, tests, shots, *.ps1 … Copying deploy.sh's _headers (immutable /*.js) to the
  root would be harmful (unversioned JS cached 1 year).
- Local commit d40031c: build.sh (portable copy+stamp+_headers -> dist/; deploy.sh now calls it, output byte-identical),
  root _headers (revalidate everything, nosniff, noindex internal files), dist/ ignored. npm test still exit 0.
  Recommendation: Pages Settings -> Builds: build command `bash build.sh`, output dir `dist` (user decision).
## D5 – deploy (≈18:56 UTC+3)
- `./deploy.sh` (wrangler pages deploy --branch main; not refused despite git connection) -> deployment 6779f8b8-e727-4932-8c39-03f8925e614b,
  https://6779f8b8.molaplan.pages.dev, production, now latest + canonical (aliases molaplan.com, www.molaplan.com). ?v=907edb3383.
- Right after deploy one curl of molaplan.com/friend-requests.js?v=… got a stale edge copy (text/html SPA fallback, max-age=14400,
  cf-cache-status then EXPIRED) – correct on the next request; browsers that hit that window could keep the HTML for 4 h.
## D6 – live verification (/workspace/molaplan-e2e/verify-live.js via live-shots.js, ≈18:58)
- All live events were in the past (feed empty) -> live-shots.js creates a temporary public unlimited event with a throwaway admin,
  runs verify-live.js, deletes event + user (leftovers 0).
- molaplan.com and molaplan.pages.dev: 4 scripts ?v=907edb3383, each 200 application/javascript immutable; MolaplanFriends present;
  landing + home feed + event detail; no 4xx, no console/page errors. www.molaplan.com serves the same index (curl).
- Screenshots 390×844@2x: shots/live-molaplan-com-{landing,home,event}.png, shots/live-molaplan-pages-dev-{landing,home,event}.png
  (not committed – a git build would publish shots/).
- Live meta after migration == replica after migration (only pgcrypto-location noise): /workspace/molaplan-backups/live-db-after-merge-meta/.
- Final live counts: 3 users/profiles, 1 admin (owner, not banned), 4 events, 5 messages, 1 notification, 2 participants, 0 friend rows.
- Nothing pushed. Pages settings unchanged.

# Push + git-build switch – 2026-10-01 19:00 (UTC+3) (user approved deploy + push)
## P0 – start: main b4d6634, 10 ahead of origin/main 35f8b1b.
## P1 – GitHub repo molaplan1-cloud/molaplan1 is PUBLIC (API: private=false, visibility=public, default branch main).
- Secret scan of 35f8b1b..main (excluding node_modules removals): no keys/tokens (only code references to "service_role"/password vars).
## P2 – build.sh: no Node, no /workspace paths; hash fallback sha1sum -> sha256sum -> shasum (commit). Clean clone + `env -i PATH=/usr/bin:/bin
  bash build.sh` -> dist/ (index.html, 4 js, _headers) identical (diff -r) to ./deploy.sh --no-deploy output, ?v=907edb3383.
  Note: Pages build image will still auto-install package.json deps (playwright-core only, no browser download).
## P3 – Pages project PATCHed: build_command "bash build.sh", destination_dir "dist", root_dir "". GET confirms; production branch main,
  deployments_enabled + production_deployments_enabled true, previews all (unchanged).
## P4 – push (≈19:01 UTC+3): `git push https://x-access-token:<token>@… main:main backup/remote-2026-09-27:backup/remote-2026-09-27`
  (credential.helper disabled for the call) -> main 35f8b1b..1d8cfee (fast-forward), new branch backup/remote-2026-09-27 (35f8b1b).
  Token not in .git/config, ~/.git-credentials or ~/.gitconfig.
## P5 – git build: production f64826b9-c20a-4982-9dbd-b172b759911e (1d8cfee) success: npm clean-install (1 pkg) -> `bash build.sh`
  -> dist, "Parsed 3 valid header rules", now canonical for molaplan.com/www. Preview 0f4c85e8 for backup/remote-2026-09-27 failed
  as expected (35f8b1b has no build.sh; preview only).
- molaplan.com / www / pages.dev: 4 scripts ?v=907edb3383, friend-requests.js 200 application/javascript (immutable),
  /AGENT-NOTES.md, /supabase/schema.sql, /build.sh, /mock-supabase.js, /package.json, /shots/* -> SPA index.html fallback (files not
  served). Headless Chrome (verify-live.js ALLOW_EMPTY=1): no 4xx, no console/page errors, MolaplanFriends loaded. Feed empty (all
  live events past).
## P6 – old deployments (not deleted): 69 total; 50 still serve AGENT-NOTES.md (and supabase/schema.sql) on <id>.molaplan.pages.dev
  (all git pushes 09-26/27 + wrangler deploys of 6b99886 from the repo dir). No email/secrets in those notes.

# UX task (branch ux-2026-10-01) – 2026-10-01 19:15 (UTC+3)
Scope: remove "Vaihda aluetta", desktop layout, navigation + business/team account entry + team account REQUEST flow,
warmer help-request copy/simpler form, SEO. Commit locally only (Pages auto-deploys main AND previews every pushed branch).
## U0 – backup: `git branch backup/pre-ux-2026-10-01` (= main 48674af); work branch ux-2026-10-01. Helpers in
  /workspace/molaplan-build/ux/ (ed.py edit helper, i18n_tool.js = add/delete keys in all 4 langs, seed.js/tour.js/montage.js).
## U1 – "Vaihda aluetta" removed
- Home header .loc-pill (#loc-pill → profile, guest #guest-city → landing picker), profile hero "Vaihda aluetta" link,
  openCitySheet()/citySave() + actions edit-city/city-save/guest-city, .loc-pill/.loc-name/.loc-chg CSS, i18n loc.change (×4).
- Kept: feed filters 📍 (#loc-home-btn) + radius chips, near-me sort, landing picker, home city in profile "Omat tiedot".
- test.js: asserts the element is gone and the radius filter still narrows the near-me feed.
## U2 – desktop layout (≥900px; 520–899px keeps the centred phone frame, <520px mobile unchanged)
- Dark frame kept/strengthened: dark body (#0E0C1B + brand glows), #app = min(1200px, 100vw-64px) × (100dvh-48px), radius 30px,
  10px near-black bezel shadow. --nav-h:0 → bottom nav becomes a left rail (logo, ＋ create, Koti, Kartta, Chatit, Omat, Profiili;
  .nav-desk items only on desktop) and stays visible on push screens (no dead ends).
- Home: 3-column card grid (auto-fill minmax 300px), filters in one row. Map: filters + the same filtered list (#map-side,
  renderMapSide(); selected marker highlights/scrolls its card) on the left, map on the right. Push/tab screens: centred 860px column.
  Sheets become centred dialogs. Landing: hero on top, landing card left, side cards right.
- U2 follow-up (U3 commit): desktop nav-rail logo/profile buttons use data-a="go-tab" data-v=… (not data-t), so mobile selectors
  like `#nav [data-t="home"]` keep matching one visible button. Landing grid: grid-auto-rows:max-content (rows collapsed otherwise).
## U3 – navigation + business/TEAM account entry + team account request flow (commit 0d69bed)
- Paths changed (why: the business/team application was hard to find, teams had only a dead 10 €/kk button behind ?ff=teams):
  - NEW push screen s-orgs "Yritys- ja joukkuetilit" (openOrgs): two options → 🏢 Yritystili (existing s-biz, price as before)
    and 👥 Joukkuetili (NEW s-teamreq). Lists own business applications + team requests. Back → where you came from.
  - Entry points to s-orgs: landing card #land-orgs "Avaa tili yritykselle tai joukkueelle" (replaces the <details> "Yrityksille";
    guest enters the app first, then s-orgs), home card #home-orgs (replaces the purple biz card; ff=teams card untouched),
    profile card #p-biz → "Yritys- tai joukkuetili" + button #open-orgs (was #open-biz straight to s-biz).
  - Guest "Luo ensin oma tili" on s-teamreq / s-biz remembers the target (PENDING team-req / open-biz) → returns after sign-up/login.
  - Admin: 4th tab "Joukkueet" (#adm-sec-teams, pending count) with approve / reject (reason sheet, 3 presets).
  - Notifications: team_request_* → s-teamreq; admin_new_team_request → admin "Joukkueet" tab.
  - ff=teams actions open-team-pricing / team-request-subscribe now open s-teamreq (no mailto, no payment). Full teams UI still hidden.
- DB (schema.sql 7e + link_kind 'team'): table team_requests (RLS: select own or admin; no direct writes; anon nothing),
  RPC request_team_account(req jsonb) (auth + not banned + email verified; 3 pending / 5 per day; notify_admins) and
  admin_review_team_request(p_id, p_status, p_reason) (admin only; reject needs reason; notifies requester). Approval does NOT
  create a team – the admin contacts the requester. No price text, no payment. Mock + supabase/tests/team-requests.sql (26 OK).
- Also fixed: business form used a missing i18n key v.phoneInvalid → v.checkPhone.
## U4 – help requests ("Autetaan toisiamme", kicker "Hyvät teot") (commit 772b1a4)
- Home + landing help card: "💚 Pyydä apua" is the one main button; offering is a small link "🙋 Haluatko itse auttaa? Katso pyynnöt →".
- s-good: warm hero ("Pyytäminen on ihan ok – naapurit auttavat mielellään"), card "Hyvä pyyntö on lyhyt ja ystävällinen" with 3
  short sample requests, small dashed card "Haluatko auttaa tai lahjoittaa jotain?" → scrolls to the requests (offer/donate via a
  request; the separate items/giveaways UI stays behind ff=items).
- Ask form 3 → 2 steps: step 1 = category, title, description, city/area, day/time (+ route/map for Kuljetus); needs/exact place/
  map/duration/helpers folded into "Lisätiedot (vapaaehtoinen)". Step 2 = contact + verification + summary + ONE consent box
  (#ck-all, sends all three consent_* = true as before) + manual-review note. Warmer placeholders. e2e-real.js updated (#ck-all;
  backup /workspace/molaplan-backups/e2e-real.js.pre-ux).
## U5 – SEO (commit 8f2203e)
- <head>: title + description (fi static, per-language via applyStaticI18n incl. og/twitter title+description, og:locale),
  canonical https://molaplan.com/ (JS sets https://molaplan.com/?lang=xx when opened with ?lang=), hreflang fi/en/es/sv via
  ?lang= URLs + x-default, OG + Twitter summary_large_image with og-image.png (1200×630, brand only, made with Chrome from
  /workspace/molaplan-build/ux/assets/og.html), JSON-LD WebSite + Organization, manifest.webmanifest, favicon.ico (32px PNG in ICO),
  icon.svg, icon-192/512, maskable 512, apple-touch-icon, robots meta.
- Static #gate content (first paint, crawlers, no-JS): hero + h1 + fi/en text + cities (Helsinki, Vantaa, Espoo, Tuusula,
  Stockholm, London, Madrid). JS landing: logo is the h1 (sr-only "Molaplan"), new "Mikä Molaplan on?" card (i18n ×4).
- Speed: leaflet/config/cities/i18n/friend-requests `defer`, app script `type="module"` (deferred, same order), fonts + leaflet
  CSS preload/onload (noscript fallback).
- robots.txt (Allow /, Disallow ?mock=, Sitemap), sitemap.xml (root + 4 ?lang URLs with xhtml:link alternates).
- build.sh: copies the 10 static files (fails if one is missing), sed handles `<script defer src=…>` (still exactly 4 stamped),
  _headers: images/icons 1 week, manifest 1 day (+ application/manifest+json), robots/sitemap 1 h.
- SPA limitation: events have no own URL (no routing) → no per-event pages, no JSON-LD Event, crawlers only see the landing.
  Would need /e/<id> routes + Pages Function/prerender later. Check: /workspace/molaplan-build/ux/seo_check.py <url of dist> (49 OK).
## U6 – live DB (17:11–17:20 UTC+3)
- Backup: /workspace/molaplan-backups/live-db-before-ux-1711/ (+ .tgz; export_live.sh: all public tables + meta).
- Applied ONLY the delta (link_kind check + section 7e) in one transaction, twice (idempotent):
  /workspace/molaplan-build/ux/ux-delta-7e.sql. Verified: table + RLS + 1 select policy, grants authenticated:SELECT only,
  RPCs security definer, anon has no execute, check includes 'team'. Owner account untouched.
- Live e2e (local server, real config): e2e-real.js 56 ✔, e2e-friends-real.js 48 ✔, NEW /workspace/molaplan-e2e/e2e-team-real.js
  26 ✔ (anon/RLS, guest landing → team request → login → submit, admin approve in the UI, reject with reason, notifications,
  cleanup: 0 leftovers; the owner gets 2 admin notifications during the run, deleted in cleanup).
## P7 – Part A: publish UX to production (2026-10-01 ≈20:40–20:55 UTC+3)
- og-image.png 497 KB → 133 KB (libimagequant 256 colours, dither 0.5; 1200×630, PSNR ≈42.6; original kept in
  /workspace/molaplan-build/ux/assets/og-image-orig.png) – commit abaef7d.
- main fast-forwarded 48674af → abaef7d, normal push (token only in the env, `credential.helper=` for the call, nothing stored).
- Pages git production build 7ae6ddf4 (main abaef7d) = success. /workspace/molaplan-e2e/verify-live-ux.js on molaplan.com: 4 scripts
  ?v=4152d3346c, robots/sitemap/og-image/manifest/icons with cache headers, canonical/og/JSON-LD/static text, mobile + desktop guest
  landing/feed, no console errors, no 4xx. Note: robots.txt is served max-age=14400 (Cloudflare override of our 3600).
## S1 – shareable event URLs + per-event SEO (branch share-urls-2026-10-01, NOT on main)
- URL: /e/<uuid>-<slug> (slug = ASCII title, ≤48 chars; /e/<uuid> alone works too). index.html uses absolute script paths
  (/config.js …, /mock-supabase.js) so the same HTML works under /e/. build.sh sed accepts both and stamps "/x.js?v=".
- SPA: DEEP_EV parsed at boot. Guests skip the landing and land on the event (their area is NOT saved; the feed behind it uses the
  event's city). Members: opened after loadAll (members may see more, e.g. 18+). Not visible (RLS) → toast "Tapahtumaa ei löytynyt"
  + normal start, URL reset to /. Opening a detail pushes /e/… (history.pushState), closing/back returns to the feed and the URL to /
  (history.back for our own entry, guarded by popGuard against races); browser back/forward handled in popstate. While an event is
  open the document title/canonical/og:url are the event's (applyStaticI18n doesn't overwrite them).
- Share: share icon in the event hero → sheet: Web Share API ("Muut sovellukset…", only when navigator.share exists), WhatsApp
  (wa.me), Facebook (sharer.php), Messenger (fb-messenger:// on touch devices; desktop: copy link + open messenger.com, since the
  web send dialog needs an FB app id), Telegram (t.me/share/url), e-mail (mailto), copy link (clipboard + execCommand fallback),
  plus the link in a read-only field. Brand icons: simple-icons (CC0) paths inline. Not gated for guests.
- Pages Functions at the REPO ROOT (Pages compiles <root>/functions; output dir stays dist): functions/e/[id].js and
  functions/sitemap-events.xml.js, both importing lib/event-page.mjs (pure, unit-tested). The function fetches index.html via
  env.ASSETS and the event from Supabase REST **guest_events** (security_invoker view → anon RLS: upcoming, not 18+, no host ids)
  with the anon key parsed from the deployed config.js (or env SUPABASE_URL/SUPABASE_ANON_KEY). Injects <title>, description,
  canonical, og:url/title/description/locale, twitter:title/description, robots, JSON-LD Event (name, start/end, Place + address
  + geo, organizer = business/organiser name or "Molaplan" – never the host), removes the root hreflang links, adds a static event
  block (h1) in #gate for crawlers/no-JS. og:image = default og-image.png. public/business → index; community → noindex (still a
  full preview when shared; flip INDEX_KINDS in lib/event-page.mjs to index them). Unknown/forbidden/junk id → generic
  "Tapahtumaa ei löytynyt" page, 404 + noindex + X-Robots-Tag (junk ids never hit the DB). Supabase error → 503 no-store.
  Cache-Control public, max-age=60. ?lang= picks fi/en/es/sv strings + date locale; times in the city's time zone.
- /sitemap-events.xml: upcoming public + business events (≤1000), referenced from robots.txt.
- deploy.sh now runs wrangler from the repo root (so ./functions is bundled); DEPLOY_BRANCH env for previews.
- Local: `node serve.js 8765` (new; serves index.html for /e/<id> like Pages) replaces python http.server for the tests.
  Full stack locally: `bash build.sh /tmp/mp-dist && /workspace/cf/node_modules/.bin/wrangler pages dev /tmp/mp-dist --port 8788`
  from the repo root (workerd, real functions, live DB).
## S2 – user changes on the same branch
- Home headline "Mitä tehtäisiin yhdessä?" → "Mola el plan!" (key home.title, Spanish in all 4 languages – SAME_OK in
  test-i18n) + subtitle home.sub (fi "Hyvä suunnitelma on parempi yhdessä. Katso, mitä lähelläsi tapahtuu.", en/es/sv).
  Small card "Mistä nimi Molaplan tulee?" (name.title/name.body ×4) on the home feed (bottom) and the landing (side column).
- Participant limit: one number field (min 2, max 100000) + "Ei rajaa" checkbox (role=checkbox) for ALL event types; the −/+
  stepper for community events is gone. Defaults 6 (community) / 500 (public/business) until the user types. err.maxRange toast.
  DB: events_max_participants_check = NULL or 2..100000 for every kind (the old "community 2–50, never NULL" rule and the
  `update … set 50 where null and community` line removed from schema.sql – re-running schema.sql no longer touches rows).
  The join trigger already treats NULL as unlimited. Mock mirrors it. Pending join after login also works for unlimited events.
  Live: backup /workspace/molaplan-backups/live-db-before-share-1827(.tgz), then /workspace/molaplan-build/share/delta-maxp.sql
  in one transaction (21:39 UTC+3), verified constraint def.
- Place autocomplete (create form "Paikka"): Photon https://photon.komoot.io/api/ (OSM; search-as-you-type allowed – Nominatim's
  policy forbids autocomplete). 300 ms debounce, ≥3 chars, AbortController for stale requests, per-query cache, bias lat/lon =
  map centre (else pin/city), location_bias_scale 0.4, lang=en for the English UI (Photon supports default/en/de/fr; fi/sv/es get
  local names), ≤6 results "name / street nr, district, city". ARIA combobox + listbox, ↑ ↓ Enter Esc, mousedown-preventDefault
  so tap/click works without losing focus, messages for searching / no results / offline / service error, attribution "Haku:
  Photon · © OpenStreetMap". Picking fills the field, sets C.lat/lng, map setView zoom 17 + pin; dragging/tapping the pin works as
  before. Reverse lookup (Nominatim reverse, allowed) on pin moves: debounce 700 ms, ≥1.5 s between requests, same ~10 m spot not
  repeated, skipped offline, now also sets C.place and formats "Testikatu 5" (UK "5 Baker Street"); dragend no longer calls it twice.
## S3 – tests (share-urls branch)
- npm test: test.js 114, test-i18n 233, test-v5 51, test-friends 35 (new community "Ei rajaa"/120/min-2 checks), test-teams 27,
  NEW test-share.js 80 (unit: id parsing, slug == SPA evSlug, injection on the real index.html, escaping/XSS, JSON-LD, noindex,
  404/503, guest_events-only + anon key, sitemap; mock UI: guest deep link on mobile, back/forward, share fallbacks, Web Share,
  clipboard, 18+/unknown ids, member opens 18+ link, headline/name card ×4 languages, Photon autocomplete with mocked Photon +
  Nominatim incl. debounce/keyboard/tap/no results/error/offline/rate limit, lang=en). mock_smoke 40.
- SQL (scratch PG 17 /tmp/pgtest:55432, schema applied twice): friends-teams-unlimited 45 OK (community NULL/300 ok, 1 and 100001
  rejected, switch limit both ways, join unlimited community), team-requests 26 OK.
- Live: NEW /workspace/molaplan-e2e/e2e-share-real.js (TARGET=<deploy>): throwaway admin + user, public + community (NULL limit) +
  18+ events, max 1 rejected, OG/JSON-LD/robots per kind, 404s, sitemap, guest SPA on mobile, OG dump (shots/share-og-dump.*),
  cleanup. e2e-friends-real.js: community "no limit" now expected to succeed (+ min-2 check).

# Media + groups + sports (branch media-groups-2026-10-02) – 2026-10-02 (times UTC+3; box clock runs UTC)
Scope: event cover images + chat photos (Supabase Storage), chat groups (open/closed), sport typeahead + favourites + admin
queue. Build files of the previous (interrupted) worker: /workspace/molaplan-build/media/ (s8.sql, patch_index.py, patch_mock.py,
mg_block.js, i18n_d.py – all already applied, don't rerun; sqltest.sh = scratch-PG suite runner, re-runnable).
## G0 – review of the inherited uncommitted work (≈07:00–07:20)
- schema.sql section 8 (8a sports: name_i18n/status/review + 14 extra sports + admin_review_activity + queue notification;
  8b images: events.cover_path, messages.image_path/w/h, buckets event-covers (public) + chat-images (private) 256 kB webp/jpeg
  with storage.objects policies, storage_object_exists check, image_reported (admin sees reported chat photo);
  8c groups/group_members/group_invites/group_join_requests, conversations kind 'group', RPCs only, groups_v; 8d reports on
  message/event_cover/group + admin_remove_content; 8e grants, anon nothing). Client (index.html): compression, covers in
  card/detail/form, chat photos with signed URLs, report/admin removal, sports typeahead + stars + admin "Lajit" tab, groups UI
  (Chatit → Ryhmät segment, s-group, /g/<id> links). lib/event-page.mjs og:image from cover. Mock mirrors all. i18n 193 keys ×4.
- Baseline on the inherited tree: sqltest.sh (stub+storage stub, schema ×2): friends-teams-unlimited 45, team-requests 26,
  media-groups 93 OK; npm test: 114 / 233 / 51 / 35 / 27 / 85 all passed; mock_smoke 40 PASS. Coherent -> WIP commit.
