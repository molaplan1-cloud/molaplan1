// R254: www.molaplan.com -> molaplan.com (one address: one sign-in, one installed app).
if (location.hostname === 'www.molaplan.com') {
  location.replace('https://molaplan.com' + location.pathname + location.search + location.hash);
  throw new Error('redirecting to molaplan.com');
}
{{flutter_js}}
{{flutter_build_config}}

// R252: Molaplan's own service worker (offline app shell, installable PWA). Flutter's built-in
// one is deprecated, so it is not used.
if ('serviceWorker' in navigator) {
  window.addEventListener('load', function () {
    navigator.serviceWorker.register('sw.js').catch(function (e) { console.warn('sw', e); });
  });
}

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    const s = document.getElementById('splash');
    await appRunner.runApp();
    if (s) s.remove();
  },
});
