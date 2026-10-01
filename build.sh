#!/bin/bash
# Build the deployable site: copy only the runtime files, stamp ?v=<hash> on the local scripts (cache-busting),
# write _headers (HTML always revalidated, versioned JS cached for a year).
# Usage: bash build.sh [outdir]   (default: dist)
# Used by deploy.sh (wrangler direct upload) and usable as the Cloudflare Pages git build:
#   Build command: bash build.sh    Build output directory: dist    Root directory: (empty)
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; DST="${1:-$SRC/dist}"
case "$DST" in /*) ;; *) DST="$SRC/$DST";; esac
[ "$DST" = "$SRC" ] && { echo "build.sh: output dir must not be the source dir" >&2; exit 1; }
# local scripts loaded by index.html (mock-supabase.js is only for ?mock=1 tests and is not deployed)
JS="config cities i18n friend-requests"
rm -rf "$DST" && mkdir -p "$DST"
cp "$SRC"/index.html "$DST"/
for f in $JS; do cp "$SRC/$f.js" "$DST"/; done
V=$(cd "$DST" && cat $(for f in $JS; do echo "$f.js"; done) | sha1sum | cut -c1-10)
sed -i -E "s#<script src=\"(config|cities|i18n|friend-requests)\.js\"></script>#<script src=\"\1.js?v=$V\"></script>#g" "$DST"/index.html
N=$(grep -c "\.js?v=$V\"" "$DST"/index.html || true)
[ "$N" = "4" ] || { echo "cache-busting: expected 4 stamped scripts, got $N" >&2; exit 1; }
cat > "$DST"/_headers <<H
/
  Cache-Control: no-cache, must-revalidate
/index.html
  Cache-Control: no-cache, must-revalidate
/*.js
  Cache-Control: public, max-age=31536000, immutable
H
echo "stamped $N scripts with ?v=$V -> $DST"
