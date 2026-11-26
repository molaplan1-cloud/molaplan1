#!/bin/bash
# Deploys the shop Worker (molaplan.com/tilaa*). Static files come from ../tilaa (copied to ./public/tilaa).
# Usage (token inline, never printed):
#   bash -lc 'CLOUDFLARE_API_TOKEN=$MOLAPLAN_CLOUDFLARE_TOKEN CLOUDFLARE_ACCOUNT_ID=289dfd5c3dad74a2c9632406634f1e80 web-site/shop-worker/deploy.sh'
set -euo pipefail
cd "$(dirname "$0")"
rm -rf public && mkdir -p public && cp -r ../tilaa public/tilaa && cp headers.txt public/_headers
npx wrangler deploy "$@"
