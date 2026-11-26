// Pure helpers of the shop Worker (tested with node --test).

export const LANGS = ['fi', 'en', 'sv', 'es'];
export const STATUSES = ['uusi', 'tarjottu', 'laskutettu', 'maksettu', 'toimitettu', 'peruttu'];

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

export function cleanStr(v, max) {
  return String(v ?? '').replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, '').trim().slice(0, max);
}

/** Validates the checkout payload. Returns {ok, data} or {ok:false, error:<code>}. */
export function validateOrder(b) {
  if (!b || typeof b !== 'object') return { ok: false, error: 'bad_request' };
  if (b.website) return { ok: false, error: 'spam' }; // honeypot
  const items = Array.isArray(b.items) ? b.items : [];
  if (items.length === 0) return { ok: false, error: 'empty_cart' };
  if (items.length > 30) return { ok: false, error: 'too_many_items' };
  const uuid = /^[0-9a-f-]{36}$/i;
  const data = {
    name: cleanStr(b.name, 120),
    email: cleanStr(b.email, 200).toLowerCase(),
    phone: cleanStr(b.phone, 40),
    address: cleanStr(b.address, 400),
    message: cleanStr(b.message, 4000),
    lang: LANGS.includes(b.lang) ? b.lang : 'fi',
    consent: b.consent === true,
    items: items.map((i) => ({
      product_id: String(i?.product_id ?? ''),
      qty: Math.max(1, Math.min(999, parseInt(i?.qty, 10) || 1)),
      notes: cleanStr(i?.notes, 1000),
    })),
  };
  if (!data.name) return { ok: false, error: 'name' };
  if (!EMAIL_RE.test(data.email)) return { ok: false, error: 'email' };
  if (!data.consent) return { ok: false, error: 'consent' };
  if (data.items.some((i) => !uuid.test(i.product_id))) return { ok: false, error: 'bad_item' };
  return { ok: true, data };
}

export function formatEur(cents, lang = 'fi') {
  if (cents == null || cents === '') return '';
  const loc = { fi: 'fi-FI', en: 'en-IE', sv: 'sv-FI', es: 'es-ES' }[lang] || 'fi-FI';
  return new Intl.NumberFormat(loc, { style: 'currency', currency: 'EUR' }).format(Number(cents) / 100)
    .replace(/\u00a0/g, ' ');
}

/** Fills {nimi} {numero} {hinta} {myyjä} {lataus} placeholders (admin reply templates). */
export function fillTemplate(text, vars) {
  return String(text ?? '').replace(/\{(nimi|numero|hinta|myyjä|myyja|lataus|sähköposti)\}/g, (_, k) => {
    const v = vars[k === 'myyja' ? 'myyjä' : k];
    return v == null ? '' : String(v);
  });
}

export function escapeHtml(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

export function textToHtml(text) {
  const body = escapeHtml(text).replace(/(https:\/\/[^\s<]+)/g, '<a href="$1">$1</a>').replace(/\n/g, '<br>');
  return `<!doctype html><html><body style="margin:0;background:#F3F7F8;padding:24px 12px">` +
    `<div style="max-width:560px;margin:0 auto;background:#fff;border-radius:12px;border-top:4px solid #2EC4B6;padding:24px;` +
    `font-family:'Fira Sans',Segoe UI,Roboto,Arial,sans-serif;font-size:15px;line-height:1.55;color:#12171E">${body}</div>` +
    `<div style="max-width:560px;margin:10px auto 0;font-family:Arial,sans-serif;font-size:12px;color:#5B6675;text-align:center">Molaplan · molaplan.com</div>` +
    `</body></html>`;
}

const T = {
  fi: {
    subject: (n) => `Tilauspyyntösi #${n} on vastaanotettu – Molaplan`,
    hello: (name) => `Hei ${name},`,
    thanks: (n) => `kiitos tilauspyynnöstäsi #${n}. Tässä yhteenveto:`,
    qty: 'kpl', quote: 'hinta tarjouksen mukaan',
    next: 'Tilauspyyntö ei ole sitova eikä siitä vielä veloiteta mitään. Saat meiltä tarjouksen sähköpostiin, yleensä muutaman arkipäivän kuluessa. Kun hyväksyt tarjouksen, lasku lähetetään erikseen laskutuspalvelun kautta.',
    reply: 'Voit vastata tähän viestiin, jos haluat täydentää tilausta.',
    message: 'Viestisi', contact: 'Yhteystiedot', sign: 'Ystävällisin terveisin',
    privacy: 'Tietosuoja',
  },
  en: {
    subject: (n) => `We received your order request #${n} – Molaplan`,
    hello: (name) => `Hi ${name},`,
    thanks: (n) => `thank you for your order request #${n}. Here is a summary:`,
    qty: 'pcs', quote: 'price on request',
    next: 'The order request is not binding and nothing is charged yet. We will send you an offer by email, usually within a few working days. Once you accept the offer, the invoice is sent separately through an invoicing service.',
    reply: 'You can reply to this email to add details to your order.',
    message: 'Your message', contact: 'Contact details', sign: 'Best regards',
    privacy: 'Privacy',
  },
  sv: {
    subject: (n) => `Vi har tagit emot din beställningsförfrågan #${n} – Molaplan`,
    hello: (name) => `Hej ${name},`,
    thanks: (n) => `tack för din beställningsförfrågan #${n}. Här är en sammanfattning:`,
    qty: 'st', quote: 'pris enligt offert',
    next: 'Förfrågan är inte bindande och ingenting debiteras ännu. Du får en offert per e-post, vanligen inom några arbetsdagar. När du godkänner offerten skickas fakturan separat via en faktureringstjänst.',
    reply: 'Du kan svara på detta meddelande om du vill komplettera beställningen.',
    message: 'Ditt meddelande', contact: 'Kontaktuppgifter', sign: 'Med vänliga hälsningar',
    privacy: 'Dataskydd',
  },
  es: {
    subject: (n) => `Hemos recibido tu solicitud de pedido n.º ${n} – Molaplan`,
    hello: (name) => `Hola ${name}:`,
    thanks: (n) => `gracias por tu solicitud de pedido n.º ${n}. Este es el resumen:`,
    qty: 'uds.', quote: 'precio según presupuesto',
    next: 'La solicitud no es vinculante y todavía no se cobra nada. Te enviaremos un presupuesto por correo, normalmente en pocos días laborables. Cuando lo aceptes, la factura se envía aparte a través de un servicio de facturación.',
    reply: 'Puedes responder a este correo para completar tu pedido.',
    message: 'Tu mensaje', contact: 'Datos de contacto', sign: 'Saludos cordiales',
    privacy: 'Privacidad',
  },
};

export function itemLines(items, lang) {
  const t = T[lang] || T.fi;
  return items.map((i) => {
    const price = i.price_mode === 'fixed' && i.price_cents != null
      ? `${formatEur(i.price_cents, lang)}${i.price_note ? ' ' + i.price_note : ''}` : t.quote;
    return `• ${i.name} – ${i.qty} ${t.qty} – ${price}${i.notes ? `\n   ${i.notes.replace(/\n/g, '\n   ')}` : ''}`;
  }).join('\n');
}

/** Customer confirmation email. */
export function confirmationEmail(order, settings, siteUrl) {
  const lang = LANGS.includes(order.lang) ? order.lang : 'fi';
  const t = T[lang];
  const seller = settings?.seller_name || 'Molaplan';
  const text = [
    t.hello(order.name), '', t.thanks(order.number), '', itemLines(order.items, lang), '',
    order.message ? `${t.message}:\n${order.message}\n` : null,
    `${t.contact}: ${[order.name, order.email, order.phone, order.address].filter(Boolean).join(', ')}`, '',
    t.next, '', t.reply, '', t.sign, seller, '', `${t.privacy}: ${siteUrl}tietosuoja/`,
  ].filter((l) => l !== null).join('\n');
  return { subject: t.subject(order.number), text, html: textToHtml(text) };
}

/** Notification to the shop owner. */
export function ownerEmail(order, siteUrl) {
  const text = [
    `Uusi tilauspyyntö #${order.number}`, '',
    itemLines(order.items, 'fi'), '',
    `Nimi: ${order.name}`, `Sähköposti: ${order.email}`,
    order.phone ? `Puhelin: ${order.phone}` : null, order.address ? `Osoite: ${order.address}` : null,
    `Kieli: ${order.lang}`, '', order.message ? `Viesti:\n${order.message}\n` : null,
    `Avaa tilaus: ${siteUrl}hallinta/#tilaus=${order.id}`,
  ].filter((l) => l !== null).join('\n');
  return { subject: `Uusi tilauspyyntö #${order.number} – ${order.name}`, text, html: textToHtml(text) };
}
