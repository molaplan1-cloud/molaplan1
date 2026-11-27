"""Writes build/web/sw.js from tool/web/sw.template.js: precache list + a version hash of the
app files (a new deploy = new cache, the old one is removed on activate)."""
import hashlib, json, os, sys

out = sys.argv[1]
core = ['/', '/main.dart.js', '/flutter.js', '/flutter_bootstrap.js', '/manifest.json', '/favicon.png', '/tile_app.js',
        '/icons/Icon-192.png', '/icons/Icon-512.png']
for root, _, files in os.walk(os.path.join(out, 'assets')):
    for f in files:
        p = '/' + os.path.relpath(os.path.join(root, f), out).replace(os.sep, '/')
        if '/rooms/' in p:  # room pictures are cached when first shown
            continue
        core.append(p)
h = hashlib.sha256()
for root, _, files in sorted(os.walk(out)):
    if os.path.relpath(root, out).startswith('tilaa'):
        continue
    for f in sorted(files):
        if f in ('sw.js', '_headers', '_redirects'):
            continue
        with open(os.path.join(root, f), 'rb') as fh:
            h.update(f.encode()); h.update(fh.read())
version = h.hexdigest()[:16]
tpl = open(os.path.join(os.path.dirname(__file__), 'sw.template.js')).read()
sw = tpl.replace('__VERSION__', version).replace('__PRECACHE__', json.dumps(sorted(set(core))))
open(os.path.join(out, 'sw.js'), 'w').write(sw)
print('sw.js', version, len(core), 'precached')
