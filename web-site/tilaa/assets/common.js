// Shared helpers for the shop pages.
export const SUPABASE_URL = 'https://fhuqbzdumxlqmgibhobl.supabase.co';
export const SUPABASE_KEY = 'sb_publishable_37EfuCKp5F9x5AieZH3qvA__oP-Z82a';
export const IMG_BASE = `${SUPABASE_URL}/storage/v1/object/public/shop-images/`;
export const LANGS = ['fi', 'en', 'sv', 'es'];
// The API lives on the shop Worker. Same origin on shop.molaplan.com (and local dev); from the
// molaplan.com Pages copy it is called cross-origin.
const SAME_ORIGIN_API = /^(shop\.molaplan\.com|localhost|127\.0\.0\.1)$|\.workers\.dev$/.test(location.hostname);
export const API = SAME_ORIGIN_API ? '/tilaa/api' : 'https://shop.molaplan.com/tilaa/api';

export const LOGO = `<svg viewBox="0 0 400 400" aria-hidden="true"><defs><linearGradient id="lg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2EC4B6"/><stop offset="1" stop-color="#159A8E"/></linearGradient></defs><rect x="40" y="40" width="140" height="140" rx="32" fill="url(#lg)"/><rect x="200" y="40" width="140" height="140" rx="32" fill="#E5EEF0" opacity=".18"/><rect x="40" y="200" width="140" height="140" rx="32" fill="#E5EEF0" opacity=".18"/><rect x="200" y="200" width="140" height="140" rx="32" fill="#E5EEF0" opacity=".28"/><path d="M70 150 L95 120 L115 135 L150 90" stroke="#12171E" stroke-width="12" fill="none" stroke-linecap="round" stroke-linejoin="round"/><circle cx="270" cy="270" r="30" fill="none" stroke="#2EC4B6" stroke-width="10"/></svg>`;

export const ICONS = {
  software: '<svg viewBox="0 0 24 24" fill="none" stroke="#2EC4B6" stroke-width="1.6"><rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/></svg>',
  device: '<svg viewBox="0 0 24 24" fill="none" stroke="#2EC4B6" stroke-width="1.6"><rect x="5" y="2.5" width="14" height="19" rx="2.5"/><path d="M10 18.5h4"/></svg>',
  service: '<svg viewBox="0 0 24 24" fill="none" stroke="#2EC4B6" stroke-width="1.6"><path d="M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 0 0 5.4-5.4l-2.5 2.5-2.4-.6-.6-2.4z"/></svg>',
  cart: '<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M3 4h2l2.2 10.2a2 2 0 0 0 2 1.6h7.6a2 2 0 0 0 2-1.5L21 8H6"/><circle cx="10" cy="20" r="1.4"/><circle cx="17" cy="20" r="1.4"/></svg>',
  info: '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.5"/></svg>',
  check: '<svg viewBox="0 0 24 24" width="38" height="38" fill="none" stroke="#2EC4B6" stroke-width="2.4"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>',
  close: '<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 6l12 12M18 6L6 18"/></svg>',
};

export function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

export function eur(cents, lang = 'fi') {
  if (cents == null) return '';
  const loc = { fi: 'fi-FI', en: 'en-IE', sv: 'sv-FI', es: 'es-ES' }[lang] || 'fi-FI';
  return new Intl.NumberFormat(loc, { style: 'currency', currency: 'EUR' }).format(cents / 100);
}

export function toast(msg, ms = 2600) {
  const el = document.createElement('div');
  el.className = 'toast';
  el.setAttribute('role', 'status');
  el.textContent = msg;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), ms);
}

let _sb;
export function sb() {
  if (!_sb) {
    _sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY, {
      auth: { persistSession: true, autoRefreshToken: true, storageKey: 'molaplan-shop-auth', detectSessionInUrl: false },
    });
  }
  return _sb;
}

export function pickLang() {
  const q = new URLSearchParams(location.search).get('lang');
  if (LANGS.includes(q)) { localStorage.setItem('molaplan-shop-lang', q); return q; }
  const saved = localStorage.getItem('molaplan-shop-lang');
  if (LANGS.includes(saved)) return saved;
  for (const l of navigator.languages || [navigator.language || 'fi']) {
    const c = String(l).slice(0, 2).toLowerCase();
    if (LANGS.includes(c)) return c;
  }
  return 'fi';
}

/** Product text in a language (falls back to Finnish). */
export function ptext(p, lang, key) {
  return (lang !== 'fi' && p.i18n?.[lang]?.[key]) || p[key] || '';
}

/** Shrinks a picked image (iPhone photos) to max 1600 px WebP/JPEG before upload. */
export async function shrinkImage(file, max = 1600) {
  const bmp = await createImageBitmap(file).catch(() => null);
  if (!bmp) return file;
  const s = Math.min(1, max / Math.max(bmp.width, bmp.height));
  const c = document.createElement('canvas');
  c.width = Math.round(bmp.width * s); c.height = Math.round(bmp.height * s);
  c.getContext('2d').drawImage(bmp, 0, 0, c.width, c.height);
  const type = c.toDataURL('image/webp').startsWith('data:image/webp') ? 'image/webp' : 'image/jpeg';
  const blob = await new Promise((r) => c.toBlob(r, type, 0.85));
  return blob || file;
}
