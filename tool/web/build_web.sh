#!/bin/bash
# Builds the Molaplan web app / PWA for https://molaplan.com (Cloudflare Pages project "molaplan").
#   tool/web/build_web.sh            -> build/web (deploy with tool/web/deploy_web.sh)
# The shop (web-site/tilaa, another component) is copied in as /tilaa when present, so one
# Pages deployment always carries both.
set -euo pipefail
cd "$(dirname "$0")/../.."
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run "$@"
out=build/web
# Not needed in production (debug symbols, Flutter's deprecated self-unregistering worker).
find "$out" -name '*.symbols' -delete
rm -f "$out/flutter_service_worker.js" "$out/flutter.js.map"
cp tool/web/_headers "$out/_headers"
# The order shop (another component, its own files – not edited here): static pages at /tilaa.
tilaa=${TILAA_DIR:-web-site/tilaa}
if [ -d "$tilaa" ]; then
  rm -rf "$out/tilaa" && cp -r "$tilaa" "$out/tilaa"
  python3 tool/web/merge_shop_headers.py "${SHOP_HEADERS:-web-site/shop-worker/headers.txt}" >> "$out/_headers"
  # The shop Worker's short English link (molaplan.com/en/order) – Pages has no Worker here.
  printf '/en/order /tilaa/?lang=en 302\n/en/order/* /tilaa/?lang=en 302\n' > "$out/_redirects"
fi
if [ -d web-site/esittely ]; then
  rm -rf "$out/esittely" && cp -r web-site/esittely "$out/esittely"
fi
python3 tool/web/make_sw.py "$out"
echo "web build ready: $out ($(du -sh "$out" | cut -f1))"
