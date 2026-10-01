#!/bin/bash
# Build the runtime files into /workspace/molaplan-deploy (build.sh: ?v= cache-busting + _headers) and deploy to Cloudflare Pages.
set -e
SRC=/workspace/molaplan; DST=/workspace/molaplan-deploy
bash "$SRC"/build.sh "$DST"
[ "$1" = "--no-deploy" ] && exit 0
cd /workspace/cf && export CLOUDFLARE_ACCOUNT_ID=289dfd5c3dad74a2c9632406634f1e80 && ./node_modules/.bin/wrangler pages deploy "$DST" --project-name molaplan --branch main --commit-dirty=true 2>&1 | tail -2
