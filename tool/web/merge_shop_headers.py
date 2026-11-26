"""Appends the shop's own header rules (web-site/shop-worker/headers.txt) for /tilaa to the web
app's _headers: its '/*' Content-Security-Policy becomes a '/tilaa/*' rule (the other '/*' headers
are already set once by the app's own rule – Pages would join duplicates), /tilaa/... rules as is."""
import os, sys

src = sys.argv[1]
SHOP_API = 'https://shop.molaplan.com'
if not os.path.exists(src):
    sys.exit(0)
blocks, cur = [], None
for line in open(src):
    if not line.strip():
        continue
    if not line[0].isspace():
        cur = [line.strip(), []]
        blocks.append(cur)
    elif cur:
        cur[1].append(line.strip())
out = []
for path, hs in blocks:
    if path == '/*':
        csp = [h for h in hs if h.lower().startswith('content-security-policy:')]
        # On molaplan.com the shop pages call the shop Worker's API cross-origin (assets/common.js).
        csp = [h.replace('connect-src ', 'connect-src ' + SHOP_API + ' ', 1) if SHOP_API not in h else h for h in csp]
        if csp:
            out.append('/tilaa/*\n' + ''.join(f'  {h}\n' for h in csp))
    elif path.startswith('/tilaa'):
        out.append(path + '\n' + ''.join(f'  {h}\n' for h in hs))
sys.stdout.write('\n# --- order shop (/tilaa), from ' + src + '\n' + ''.join(out))
