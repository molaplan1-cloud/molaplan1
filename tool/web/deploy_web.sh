#!/bin/bash
# Deploys build/web to the Cloudflare Pages project "molaplan" (https://molaplan.com).
#   tool/web/deploy_web.sh            -> production (molaplan.com, www.molaplan.com)
#   tool/web/deploy_web.sh preview    -> a preview URL only (<hash>.molaplan.pages.dev)
# Needs MOLAPLAN_CLOUDFLARE_TOKEN in the login shell (never printed). Old deployments stay in
# Pages (roll back in the dashboard). Build first with tool/web/build_web.sh.
set -euo pipefail
cd "$(dirname "$0")/../.."
root=$(pwd)
branch=main
[ "${1:-}" = preview ] && branch=preview
out=$root/build/web
[ -f "$out/sw.js" ] || { echo "build/web missing – run tool/web/build_web.sh" >&2; exit 1; }
# R738: production version.json is the updater's manifest. Publish it only after the Windows
# zip and SHA256SUMS for this version are on GitHub. Preview deploys do not change molaplan.com.
if [ "$branch" != preview ] && [ "${SKIP_ASSET_WAIT:-}" != 1 ]; then
  ver=$(python3 -c "import json; print(json.load(open('$out/version.json'))['version'])")
  "$root/tool/web/wait_release_assets.sh" "$ver"
fi
WRANGLER=${WRANGLER:-$root/relay/node_modules/.bin/wrangler}
tmp=$(mktemp -d) && mkdir -p "$tmp/node_modules" && cd "$tmp"   # no wrangler.jsonc here: a plain Pages upload
bash -lc "cd '$tmp' && CLOUDFLARE_API_TOKEN=\"\$MOLAPLAN_CLOUDFLARE_TOKEN\" CLOUDFLARE_ACCOUNT_ID=289dfd5c3dad74a2c9632406634f1e80 '$WRANGLER' pages deploy '$out' --project-name molaplan --branch $branch --commit-dirty=true"
rm -rf "$tmp"
