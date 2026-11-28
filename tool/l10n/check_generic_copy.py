#!/usr/bin/env python3
"""R561: fail if user-facing copy refers to the owner's test setup.

Scans l10n ARB files, translation overrides, in-app help/wizard string
sources, website copy and the README. Developer comments, tests,
requirements and historical release notes are out of scope.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# Phrases that assume a particular test device or place. Generic platform
# lists ("PC, tablet, phone") and "a tablet" as one possible home-bridge
# device are allowed and are not listed here.
BANNED = [
    r'kuten tabletilla',
    r'niin kuin tabletilla',
    r'niinkuin tabletilla',
    r'kodin tabletilla',
    r'kodin tabletissa',
    r'kodin tabletille',
    r'kodin tabletista',
    r'kodin tabletti\b',
    r'seinätabletti',
    r'as on the tablet',
    r'like the tablet',
    r'like the android tablet',
    r'\bthe home tablet\b',
    r'\bhome tablet\b',
    r'wall tablet',
    r'väggtablett',
    r'väggplatta',
    r'hemmatablett',
    r'hem surfplattan',
    r'som på surfplattan',
    r'nagu tahvelarvutis',
    r'kodutahvl',
    r'seinatahvel',
    r'como en la tableta',
    r'tableta casera',
    r'tableta de inicio',
    r'tableta de pared',
    r'galaxy tab',
    r'sm-t575',
    r'htc 5g',
    r'5g hub',
    r'active3',
    r'r52t',
    r'kotselainen',
    r'\benn kotselainen\b',
    r'kv-8s7o',
    r'kv-wou9',
    r'172\.20\.10\.',
]

COMPILED = [(p, re.compile(p, re.I)) for p in BANNED]
STRING_LIT = re.compile(r"""(['\"])(?:\\.|(?!\1).)*\1""")


def hits_in(text: str) -> list[str]:
    found = []
    for name, cre in COMPILED:
        if cre.search(text):
            found.append(name)
    return found


def arb_values(path: Path) -> list[tuple[str, str]]:
    data = json.loads(path.read_text(encoding='utf-8'))
    out = []
    for key, val in data.items():
        if isinstance(val, str):
            out.append((key, val))
        elif isinstance(val, dict):
            for mk, mv in val.items():
                if isinstance(mv, str):
                    out.append((f'{key}.{mk}', mv))
    return out


def dart_string_literals(text: str) -> list[str]:
    """Quoted literals only, so developer comments are ignored."""
    # Strip // line comments and /* */ blocks first, but keep strings that
    # contain comment-like text. A simple state machine:
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ''
        if c == '/' and nxt == '/':
            while i < n and text[i] != '\n':
                i += 1
            continue
        if c == '/' and nxt == '*':
            i += 2
            while i + 1 < n and not (text[i] == '*' and text[i + 1] == '/'):
                i += 1
            i = min(n, i + 2)
            continue
        if c in ('"', "'"):
            quote, i, buf = c, i + 1, []
            raw = (i >= 2 and text[i - 2] == 'r') or (i >= 1 and False)
            # Dart raw strings: r'...' or r"..."
            raw = False  # handled below if needed
            while i < n:
                ch = text[i]
                if ch == '\\' and i + 1 < n:
                    buf.append(ch)
                    buf.append(text[i + 1])
                    i += 2
                    continue
                if ch == quote:
                    i += 1
                    break
                buf.append(ch)
                i += 1
            # Unescape for matching (today\'s -> today's) but also keep raw
            lit = ''.join(buf).replace("\\'", "'").replace('\\"', '"')
            out.append(lit)
            continue
        i += 1
    return out


def collect() -> list[tuple[str, str, str]]:
    """Return (location, snippet, pattern) hits."""
    hits = []

    for path in sorted((ROOT / 'lib' / 'l10n' / 'arb').glob('app_*.arb')):
        for key, val in arb_values(path):
            for pat in hits_in(val):
                snippet = val.replace('\n', ' ')
                if len(snippet) > 180:
                    snippet = snippet[:180] + '…'
                hits.append((f'{path.relative_to(ROOT)}:{key}', snippet, pat))

    for rel in ('tool/l10n/overrides_src.py', 'tool/l10n/overrides.json'):
        path = ROOT / rel
        if not path.exists():
            continue
        for i, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
            for pat in hits_in(line):
                hits.append((f'{rel}:{i}', line.strip()[:180], pat))

    dart_roots = [
        ROOT / 'lib' / 'ui',
        ROOT / 'lib' / 'core',
        ROOT / 'lib' / 'templates',
        ROOT / 'lib' / 'sharing',
    ]
    for folder in dart_roots:
        if not folder.exists():
            continue
        for path in sorted(folder.rglob('*.dart')):
            text = path.read_text(encoding='utf-8')
            for lit in dart_string_literals(text):
                for pat in hits_in(lit):
                    snippet = lit.replace('\n', ' ')
                    if len(snippet) > 180:
                        snippet = snippet[:180] + '…'
                    hits.append((str(path.relative_to(ROOT)), snippet, pat))

    web_files = []
    tilaa = ROOT / 'web-site' / 'tilaa'
    if tilaa.exists():
        for path in tilaa.rglob('*'):
            if not path.is_file():
                continue
            if 'vendor' in path.parts or 'fonts' in path.parts:
                continue
            if path.suffix.lower() in {'.html', '.js', '.css', '.json', '.webmanifest'}:
                web_files.append(path)
    web = ROOT / 'web'
    if web.exists():
        for path in web.rglob('*'):
            if not path.is_file():
                continue
            if path.suffix.lower() in {'.html', '.js', '.css'} and 'canvaskit' not in path.parts:
                web_files.append(path)
    readme = ROOT / 'README.md'
    if readme.exists():
        web_files.append(readme)

    for path in web_files:
        for i, line in enumerate(path.read_text(encoding='utf-8', errors='replace').splitlines(), 1):
            for pat in hits_in(line):
                hits.append((f'{path.relative_to(ROOT)}:{i}', line.strip()[:180], pat))

    return hits


def main() -> int:
    hits = collect()
    if not hits:
        print('generic-copy check: OK (no banned test-setup phrasing)')
        return 0
    print(f'generic-copy check: {len(hits)} hit(s) – user-facing text must not refer to the owner\'s test setup (R560):')
    for loc, snippet, pat in hits:
        print(f'  {loc}  [{pat}]  {snippet}')
    return 1


if __name__ == '__main__':
    sys.exit(main())
