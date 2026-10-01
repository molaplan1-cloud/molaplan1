#!/bin/bash
# Build the runtime files into /workspace/molaplan-deploy (build.sh: ?v= cache-busting + _headers) and deploy to Cloudflare Pages.
set -e
SRC=/workspace/molaplan; DST=/workspace/molaplan-deploy
bash "$SRC"/build.sh "$DST"
[ "$1" = "--no-deploy" ] && exit 0
# run from the repo root so wrangler bundles ./functions (Pages Functions) together with the static files in $DST
cd "$SRC" && export CLOUDFLARE_ACCOUNT_ID=289dfd5c3dad74a2c9632406634f1e80 && /workspace/cf/node_modules/.bin/wrangler pages deploy "$DST" --project-name molaplan --branch "${DEPLOY_BRANCH:-main}" --commit-dirty=true 2>&1 | tail -3
