#!/bin/bash
# Copy runtime files to deploy folder, stamp cache-busting versions, deploy to Cloudflare Pages.
set -e
SRC=/workspace/molaplan; DST=/workspace/molaplan-deploy
rm -rf "$DST" && mkdir -p "$DST"
# local scripts loaded by index.html (mock-supabase.js is only for ?mock=1 tests and is not deployed)
JS="config cities i18n friend-requests"
cp "$SRC"/index.html "$DST"/
for f in $JS; do cp "$SRC/$f.js" "$DST"/; done
V=$(cd "$DST" && cat $(for f in $JS; do echo "$f.js"; done) | sha1sum | cut -c1-10)
sed -i -E "s#<script src=\"(config|cities|i18n|friend-requests)\.js\"></script>#<script src=\"\1.js?v=$V\"></script>#g" "$DST"/index.html
N=$(grep -c "\.js?v=$V\"" "$DST"/index.html)
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
[ "$1" = "--no-deploy" ] && exit 0
cd /workspace/cf && export CLOUDFLARE_ACCOUNT_ID=289dfd5c3dad74a2c9632406634f1e80 && ./node_modules/.bin/wrangler pages deploy "$DST" --project-name molaplan --branch main --commit-dirty=true 2>&1 | tail -2
