#!/bin/bash
# Copy runtime files to deploy folder, stamp cache-busting versions, deploy to Cloudflare Pages.
set -e
SRC=/workspace/molaplan; DST=/workspace/molaplan-deploy
rm -rf "$DST" && mkdir -p "$DST"
cp "$SRC"/index.html "$SRC"/config.js "$SRC"/cities.js "$SRC"/i18n.js "$DST"/
V=$(cat "$DST"/config.js "$DST"/cities.js "$DST"/i18n.js | sha1sum | cut -c1-10)
sed -i -E "s#<script src=\"(config|cities|i18n)\.js\"></script>#<script src=\"\1.js?v=$V\"></script>#g" "$DST"/index.html
cat > "$DST"/_headers <<H
/
  Cache-Control: no-cache, must-revalidate
/index.html
  Cache-Control: no-cache, must-revalidate
/*.js
  Cache-Control: public, max-age=31536000, immutable
H
grep -c "?v=$V" "$DST"/index.html
[ "$1" = "--no-deploy" ] && exit 0
cd /workspace/cf && export CLOUDFLARE_ACCOUNT_ID=289dfd5c3dad74a2c9632406634f1e80 && ./node_modules/.bin/wrangler pages deploy "$DST" --project-name molaplan --branch main --commit-dirty=true 2>&1 | tail -2
