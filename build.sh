#!/bin/bash
# Build the deployable site: copy only the runtime files, stamp ?v=<hash> on the local scripts (cache-busting),
# write _headers (HTML always revalidated, versioned JS cached for a year).
# Usage: bash build.sh [outdir]   (default: dist)
# Needs only bash + coreutils/sed/grep (no Node). Used by deploy.sh (wrangler direct upload) and usable as the Cloudflare Pages git build:
#   Build command: bash build.sh    Build output directory: dist    Root directory: (empty)
# Pages Functions (functions/e/[id].js = per-event OG/SEO pages, functions/sitemap-events.xml.js) live in /functions at the REPO ROOT,
# not in dist: Pages (git builds) compiles <root>/functions itself, and `wrangler pages deploy dist` uses ./functions of its cwd
# (deploy.sh runs it from this directory). They import lib/event-page.mjs (bundled by Pages/wrangler).
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; DST="${1:-$SRC/dist}"
case "$DST" in /*) ;; *) DST="$SRC/$DST";; esac
[ "$DST" = "$SRC" ] && { echo "build.sh: output dir must not be the source dir" >&2; exit 1; }
# local scripts loaded by index.html (mock-supabase.js is only for ?mock=1 tests and is not deployed)
JS="config cities i18n friend-requests orgs"
# static SEO / PWA files served from the site root (not versioned -> moderate cache lifetimes in _headers below)
STATIC="robots.txt sitemap.xml manifest.webmanifest og-image.png favicon.ico icon.svg icon-192.png icon-512.png icon-maskable-512.png apple-touch-icon.png"
rm -rf "$DST" && mkdir -p "$DST"
cp "$SRC"/index.html "$DST"/
for f in $JS; do cp "$SRC/$f.js" "$DST"/; done
for f in $STATIC; do [ -f "$SRC/$f" ] || { echo "build.sh: missing $f" >&2; exit 1; }; cp "$SRC/$f" "$DST"/; done
if command -v sha1sum >/dev/null 2>&1; then H="sha1sum"; elif command -v sha256sum >/dev/null 2>&1; then H="sha256sum"; else H="shasum"; fi
V=$(cd "$DST" && cat $(for f in $JS; do echo "$f.js"; done) | $H | cut -c1-10)
sed -i -E "s#<script (defer )?src=\"/?(config|cities|i18n|friend-requests|orgs)\.js\"></script>#<script \1src=\"/\2.js?v=$V\"></script>#g" "$DST"/index.html
N=$(grep -c "\.js?v=$V\"" "$DST"/index.html || true)
[ "$N" = "5" ] || { echo "cache-busting: expected 5 stamped scripts, got $N" >&2; exit 1; }
cat > "$DST"/_headers <<H
/
  Cache-Control: no-cache, must-revalidate
/index.html
  Cache-Control: no-cache, must-revalidate
/*.js
  Cache-Control: public, max-age=31536000, immutable
/og-image.png
  Cache-Control: public, max-age=604800
/favicon.ico
  Cache-Control: public, max-age=604800
/icon.svg
  Cache-Control: public, max-age=604800
/icon-192.png
  Cache-Control: public, max-age=604800
/icon-512.png
  Cache-Control: public, max-age=604800
/icon-maskable-512.png
  Cache-Control: public, max-age=604800
/apple-touch-icon.png
  Cache-Control: public, max-age=604800
/manifest.webmanifest
  Cache-Control: public, max-age=86400
  Content-Type: application/manifest+json
/robots.txt
  Cache-Control: public, max-age=3600
/sitemap.xml
  Cache-Control: public, max-age=3600
H
echo "stamped $N scripts with ?v=$V -> $DST"
