// R511 (t315u): molaplan.com/?view=<tileId> and /?price=<zone> are single-tile home-screen apps.
// Runs before Flutter: gives the page the tile's name and makes "Add to Home Screen" start at
// THIS address (not at "/"). iPhone/iPad: the manifest is dropped, so Safari keeps the current
// URL and uses apple-mobile-web-app-title; elsewhere a per-tile manifest (blob, absolute URLs).
// Never contains anything secret – only what is already in the address.
(function () {
  try {
    var q = new URLSearchParams(location.search);
    var view = q.get('view'), price = q.get('price');
    if (!view && !price) return;
    var name = (q.get('name') || '').trim().slice(0, 40) || (price ? 'Sähkö ' + price : 'Molaplan');
    document.title = name;
    var t = document.querySelector('meta[name="apple-mobile-web-app-title"]');
    if (t) t.setAttribute('content', name);
    var link = document.querySelector('link[rel="manifest"]');
    var ios = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    if (ios) { if (link) link.parentNode.removeChild(link); return; }
    var o = location.origin;
    var m = {
      name: name, short_name: name, id: '/' + location.search, start_url: location.href, scope: o + '/',
      display: 'standalone', background_color: '#10161b', theme_color: '#10161b', lang: document.documentElement.lang || 'fi',
      icons: [
        { src: o + '/icons/Icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
        { src: o + '/icons/Icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
        { src: o + '/icons/Icon-maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' }
      ]
    };
    if (link) link.setAttribute('href', URL.createObjectURL(new Blob([JSON.stringify(m)], { type: 'application/manifest+json' })));
  } catch (e) { /* the normal app manifest stays */ }
})();
