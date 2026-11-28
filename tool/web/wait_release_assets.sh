#!/bin/bash
# Wait until the GitHub release for VERSION has the Windows zip and SHA256SUMS (R738).
#   tool/web/wait_release_assets.sh 0.20.36
#   tool/web/wait_release_assets.sh 0.20.36 60    # timeout in seconds
#   WAIT_ASSETS_SECS=0 tool/web/wait_release_assets.sh 0.20.36   # one shot, no wait
# Exits 0 when both files return HTTP 200, 1 when they do not appear in time, 2 on bad usage.
# Public HTTPS URLs only – no token. deploy_web.sh uses this so molaplan.com/version.json is
# never published for a version whose installers are still being built (the 0.20.29 updater
# would otherwise offer that version and show "Päivitys ei ole vielä ladattavissa").
set -euo pipefail
ver=${1:-}
[[ $ver == v* ]] && ver=${ver#v}
[ -n "$ver" ] || { echo "usage: wait_release_assets.sh VERSION [timeout_sec]" >&2; exit 2; }
timeout=${2:-${WAIT_ASSETS_SECS:-1200}}
repo=${RELEASE_REPO:-molaplan1-cloud/molaplan1}
base="https://github.com/$repo/releases/download/v${ver}"

ready() {
  local url=$1
  local code
  code=$(curl -sSIL -o /dev/null -w '%{http_code}' --max-time 15 "$url" || true)
  [ "$code" = 200 ]
}

i=0
while :; do
  if ready "$base/molaplan-windows-x64.zip" && ready "$base/SHA256SUMS"; then
    echo "release assets for v$ver are published"
    exit 0
  fi
  if [ "$i" -ge "$timeout" ]; then
    break
  fi
  echo "waiting for v$ver installers (${i}s)..."
  sleep 15
  i=$((i + 15))
done
echo "Windows installers for v$ver are not on GitHub yet; not publishing version.json." >&2
exit 1
