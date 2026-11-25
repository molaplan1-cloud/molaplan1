#!/usr/bin/env python3
"""Molaplan l10n pipeline.

  python3 tool/l10n/translate.py            # extract -> update ARB files (machine-translate new strings) -> strings.g.dart
  python3 tool/l10n/translate.py --table    # only rebuild lib/l10n/strings.g.dart from the ARB files (after hand edits)

ARB files (Flutter gen-l10n format, use-escaping) live in lib/l10n/arb/. app_en.arb is the template.
Existing translations are kept; only new/changed strings are machine-translated (offline, Argos/CTranslate2
models in $MOLAPLAN_MT_MODELS, default /workspace/i18n-tools/models). overrides.json holds hand-reviewed texts
and wins over machine translation. Strings flagged "mt" in @meta are machine translations (review welcome).
"""
import hashlib, json, os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ARB = os.path.join(ROOT, 'lib', 'l10n', 'arb')
TABLE = os.path.join(ROOT, 'lib', 'l10n', 'strings.g.dart')
TARGETS = ['sv', 'et', 'es']
ALL = ['en', 'fi'] + TARGETS
PH = re.compile(r'\{p(\d+)\}')


def key(fi, en):
    return 's' + hashlib.sha1((fi + '\0' + en).encode()).hexdigest()[:10]


# ---- ICU escaping (gen-l10n use-escaping: true) ----
def esc(text):
    out, i = [], 0
    for part in re.split(r'(\{p\d+\})', text):
        if PH.fullmatch(part):
            out.append(part)
        else:
            if '{' in part or '}' in part:
                # Quote the whole literal segment; '' inside a quoted segment is a quote.
                part = "'" + part.replace("'", "''") + "'"
            else:
                part = part.replace("'", "''")
            out.append(part)
    return ''.join(out)


def unesc(msg):
    out, i, n = [], 0, len(msg)
    while i < n:
        c = msg[i]
        if c == "'":
            if i + 1 < n and msg[i + 1] == "'":
                out.append("'"); i += 2; continue
            # quoted literal: until a lone quote; '' inside is a quote
            j = i + 1
            while j < n:
                if msg[j] == "'":
                    if j + 1 < n and msg[j + 1] == "'":
                        out.append("'"); j += 2; continue
                    break
                out.append(msg[j]); j += 1
            i = j + 1; continue
        out.append(c); i += 1
    return ''.join(out)


def load_arb(lang):
    p = os.path.join(ARB, f'app_{lang}.arb')
    if not os.path.exists(p):
        return {}
    return json.load(open(p, encoding='utf-8'))


def skip_mt(en):
    """Technical strings stay in English: codes, value maps, JSON, URLs, single tokens."""
    if not re.search(r'[A-Za-z]{2}', en):
        return True
    if re.search(r'\{"|":|^https?://', en):
        return True
    if re.fullmatch(r'[\w./:-]+', en) and (re.search(r'[./:_0-9]', en) or re.search(r'[a-z][A-Z]', en) or en.isupper()):
        return True  # identifiers, paths, acronyms (MQTT, QoS…)
    if re.search(r'\w=\w[^;]*;', en):  # value maps "0=Off;1=Away"
        return True
    return False


PROTECT = re.compile(r'\{\{\w+\}\}|\{p\d+\}|`[^`]+`|https?://\S+|\b\d+(?:\.\d+){1,3}\b|c/kWh|€/MWh')

# MT-only wording: the models know these words in another sense (floor tile, explosive blaster, car dashboard).
GLOSSARY = [
    (r'\bIR blasters\b', 'IR transmitters'), (r'\bIR blaster\b', 'IR transmitter'),
    (r'\bblasters\b', 'IR transmitters'), (r'\bblaster\b', 'IR transmitter'),
    (r'\bTiles\b', 'Cards'), (r'\btiles\b', 'cards'), (r'\bTile\b', 'Card'), (r'\btile\b', 'card'),
    (r'\bDashboards\b', 'Views'), (r'\bdashboards\b', 'views'), (r'\bDashboard\b', 'View'), (r'\bdashboard\b', 'view'),
]


def glossary(t):
    for a, b in GLOSSARY:
        t = re.sub(a, b, t)
    return t


def mt(lang, texts):
    sys.path.insert(0, os.path.dirname(__file__))
    import ctranslate2, sentencepiece as spm, glob
    models = os.environ.get('MOLAPLAN_MT_MODELS', '/workspace/i18n-tools/models')
    d = glob.glob(f'{models}/{lang}/*')[0]
    tr = ctranslate2.Translator(d + '/model', device='cpu', inter_threads=4)
    sp = spm.SentencePieceProcessor(model_file=d + '/sentencepiece.model')
    prepared, tokens = [], []
    for t in texts:
        toks = []
        def sub(m):
            toks.append(m.group(0))
            return f'{{p{90 + len(toks) - 1}}}' if not m.group(0).startswith('{p') else m.group(0)
        prepared.append(PROTECT.sub(sub, glossary(t)))
        tokens.append(toks)
    out = []
    for i in range(0, len(prepared), 24):
        chunk = prepared[i:i + 24]
        # Translate per line so multi-line help texts keep their layout.
        lines = [c.split('\n') for c in chunk]
        flat = [l for ls in lines for l in ls]
        enc = [sp.encode(l, out_type=str) if l.strip() else [] for l in flat]
        res = tr.translate_batch([e or ['▁'] for e in enc], beam_size=4, max_decoding_length=400)
        dec = [sp.decode(r.hypotheses[0]).replace('▁', ' ').strip() if flat[k].strip() else flat[k] for k, r in enumerate(res)]
        k = 0
        for ls in lines:
            out.append('\n'.join(dec[k:k + len(ls)])); k += len(ls)
    # restore protected tokens
    final = []
    for t, toks in zip(out, tokens):
        protected = [x for x in toks if not x.startswith('{p')]
        def back(m):
            n = int(m.group(1))
            return protected[n - 90] if n >= 90 and n - 90 < len(protected) else m.group(0)
        final.append(PH.sub(back, t))
    return final


def placeholders_ok(src, dst):
    return sorted(PH.findall(src)) == sorted(PH.findall(dst)) and \
        sorted(re.findall(r'\{\{\w+\}\}', src)) == sorted(re.findall(r'\{\{\w+\}\}', dst))


def build_table():
    en = load_arb('en')
    keys = [k for k in en if not k.startswith('@')]
    arbs = {l: load_arb(l) for l in ALL}
    def col(l):
        a = arbs[l]
        return [unesc(a.get(k, '')) for k in keys]
    def lit(s):
        return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$').replace('\n', '\\n').replace('\r', '') + "'"
    lines = ['// GENERATED by tool/l10n/translate.py from lib/l10n/arb/*.arb – do not edit by hand.',
             '// ignore_for_file: lines_longer_than_80_chars', '']
    for l in ['fi', 'en'] + TARGETS:
        lines.append(f'const l10n{l.capitalize()} = <String>[')
        lines += ['  ' + lit(s) + ',' for s in col(l)]
        lines.append('];\n')
    lines.append('const l10nTables = <String, List<String>>{' + ', '.join(f"'{l}': l10n{l.capitalize()}" for l in TARGETS) + '};')
    open(TABLE, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    # Test helper: the same strings through the gen-l10n classes (checks ARB escaping and the table agree).
    g = ['// GENERATED by tool/l10n/translate.py – do not edit by hand.',
         "import 'package:molaplan/l10n/gen/app_localizations.dart';", '',
         'final l10nGetters = <String Function(AppLocalizations)>[']
    for k in keys:
        phs = sorted(set(PH.findall(en[k])) | set(PH.findall(arbs['fi'].get(k, ''))), key=int)
        meta = en.get('@' + k, {}).get('placeholders', {})
        names = list(meta.keys())
        if names:
            g.append(f"  (l) => l.{k}(" + ', '.join(f"'{{{n}}}'" for n in names) + '),')
        else:
            g.append(f'  (l) => l.{k},')
    g.append('];')
    os.makedirs(os.path.join(ROOT, 'test', 'support'), exist_ok=True)
    open(os.path.join(ROOT, 'test', 'support', 'l10n_getters.g.dart'), 'w', encoding='utf-8').write('\n'.join(g) + '\n')
    print('table:', len(keys), 'strings')


def main():
    if '--table' in sys.argv:
        build_table(); return
    os.makedirs(ARB, exist_ok=True)
    tool = os.path.dirname(os.path.abspath(__file__))
    tmp = os.path.join(tool, '.strings.json')
    subprocess.run(['dart', 'run', 'bin/extract.dart', os.path.join(ROOT, 'lib'), 'extract', tmp], cwd=tool, check=True)
    items = json.load(open(tmp, encoding='utf-8'))
    os.remove(tmp)
    norm = lambda s: re.sub(r'\{#(\d+)\}', r'{p\1}', s)
    entries = []
    for it in items:
        fi, en = norm(it['fi']), norm(it['en'])
        if '{?' in en:
            en = re.sub(r'\{\?[^}]*\}', '', en)
        entries.append((key(fi, en), fi, en, it['where']))
    old = {l: load_arb(l) for l in ALL}
    overrides = json.load(open(os.path.join(tool, 'overrides.json'), encoding='utf-8')) if os.path.exists(os.path.join(tool, 'overrides.json')) else {}
    out = {l: {'@@locale': l} for l in ALL}
    for k, fi, en, where in entries:
        out['en'][k] = esc(en)
        meta = {'description': f'fi: {fi[:120]}', 'x-where': where}
        phs = sorted(set(PH.findall(fi)) | set(PH.findall(en)), key=int)
        if phs:
            meta['placeholders'] = {f'p{p}': {'type': 'String'} for p in phs}
        out['en']['@' + k] = meta
        out['fi'][k] = esc(fi)
    for l in TARGETS:
        todo = []
        for k, fi, en, where in entries:
            ov = overrides.get(l, {}).get(en)
            if ov is not None:
                out[l][k] = esc(ov); continue
            prev = old[l].get(k)
            if prev is not None and not old[l].get('@' + k, {}).get('stale'):
                out[l][k] = prev
                if '@' + k in old[l]:
                    out[l]['@' + k] = old[l]['@' + k]
                continue
            if skip_mt(en) or fi == en:
                out[l][k] = esc(en); continue
            todo.append((k, en))
        if todo:
            print(l, 'machine-translating', len(todo))
            res = mt(l, [e for _, e in todo])
            # Second try for lost placeholders: numbers survive MT better than {p0}.
            retry = [i for i, ((k, en), t) in enumerate(zip(todo, res)) if not t or not placeholders_ok(en, t)]
            if retry:
                num = lambda t: PH.sub(lambda m: str(9001 + int(m.group(1))), t)
                again = mt(l, [num(todo[i][1]) for i in retry])
                for i, t in zip(retry, again):
                    res[i] = re.sub(r'900([1-9])', lambda m: '{p%d}' % (int(m.group(1)) - 1), t)
            bad = 0
            for (k, en), t in zip(todo, res):
                # MT likes to add a full stop / change the trailing space of short labels.
                if t and not en.rstrip().endswith(('.', '!', '?', '…')) and t.endswith('.') and not t.endswith('..'):
                    t = t[:-1]
                if en.endswith(' ') and not t.endswith(' '):
                    t += ' '
                if en.startswith(' ') and not t.startswith(' '):
                    t = ' ' + t
                if not t or not placeholders_ok(en, t):
                    t = en; bad += 1
                out[l][k] = esc(t)
                out[l]['@' + k] = {'x-mt': True}
            print(l, 'placeholder mismatches (kept English):', bad)
    for l in ALL:
        json.dump(out[l], open(os.path.join(ARB, f'app_{l}.arb'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
        open(os.path.join(ARB, f'app_{l}.arb'), 'a').write('\n')
    print('entries:', len(entries))
    build_table()


if __name__ == '__main__':
    main()
