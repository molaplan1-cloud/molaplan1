import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateOrder, formatEur, fillTemplate, confirmationEmail, ownerEmail, itemLines, escapeHtml } from '../src/lib.js';

const pid = '11111111-2222-3333-4444-555555555555';
const base = { name: ' Matti ', email: 'Matti@Example.com', consent: true, items: [{ product_id: pid, qty: '3', notes: 'x' }] };

test('valid order is cleaned', () => {
  const v = validateOrder(base);
  assert.equal(v.ok, true);
  assert.equal(v.data.name, 'Matti');
  assert.equal(v.data.email, 'matti@example.com');
  assert.equal(v.data.items[0].qty, 3);
  assert.equal(v.data.lang, 'fi');
});
test('rejects missing name, bad email, no consent, empty cart, bad ids, honeypot', () => {
  assert.equal(validateOrder({ ...base, name: '' }).error, 'name');
  assert.equal(validateOrder({ ...base, email: 'nope' }).error, 'email');
  assert.equal(validateOrder({ ...base, consent: 'true' }).error, 'consent');
  assert.equal(validateOrder({ ...base, items: [] }).error, 'empty_cart');
  assert.equal(validateOrder({ ...base, items: [{ product_id: 'x' }] }).error, 'bad_item');
  assert.equal(validateOrder({ ...base, website: 'http://spam' }).error, 'spam');
  assert.equal(validateOrder({ ...base, items: Array(31).fill({ product_id: pid }) }).error, 'too_many_items');
});
test('qty clamps and strings are capped', () => {
  const v = validateOrder({ ...base, items: [{ product_id: pid, qty: -5 }, { product_id: pid, qty: 5000 }], message: 'a'.repeat(5000), lang: 'xx' });
  assert.deepEqual(v.data.items.map((i) => i.qty), [1, 999]);
  assert.equal(v.data.message.length, 4000);
  assert.equal(v.data.lang, 'fi');
});
test('euro formatting', () => {
  assert.equal(formatEur(19900, 'fi'), '199,00 €');
  assert.equal(formatEur(null), '');
});
test('template placeholders', () => {
  assert.equal(fillTemplate('Hei {nimi}, #{numero}: {hinta}. {myyja}/{myyjä} {tuntematon}', { nimi: 'A', numero: 1001, hinta: '10,00 €', 'myyjä': 'M' }),
    'Hei A, #1001: 10,00 €. M/M {tuntematon}');
});
const order = { id: 'o1', number: 1001, name: 'Anna', email: 'anna@example.com', phone: '', address: '', message: 'Valot <b>', lang: 'sv',
  items: [{ name: 'ESP IR -ohjain', qty: 2, notes: 'Mitsubishi', price_mode: 'quote' }, { name: 'Kiinteä', qty: 1, price_mode: 'fixed', price_cents: 4900, price_note: '/ kpl' }] };
test('confirmation email: language, non-binding text, no company claims, escaped html', () => {
  const m = confirmationEmail(order, { seller_name: 'Myyjä' }, 'https://molaplan.com/tilaa/');
  assert.match(m.subject, /#1001/);
  assert.match(m.text, /inte bindande/);
  assert.match(m.text, /pris enligt offert/);
  assert.match(m.text, /49,00 € \/ kpl/);
  assert.doesNotMatch(m.text, /Y-tunnus|Oy\b|AB\b/);
  assert.match(m.html, /Valot &lt;b&gt;/);
  assert.match(m.text, /tietosuoja\//);
});
test('owner email links to the order', () => {
  const m = ownerEmail(order, 'https://molaplan.com/tilaa/');
  assert.match(m.text, /hallinta\/#tilaus=o1/);
  assert.match(m.subject, /Uusi tilauspyyntö #1001/);
});
test('item lines + escapeHtml', () => {
  assert.match(itemLines(order.items, 'fi'), /hinta tarjouksen mukaan/);
  assert.equal(escapeHtml(`<a href="x">'</a>`), '&lt;a href=&quot;x&quot;&gt;&#39;&lt;/a&gt;');
});
