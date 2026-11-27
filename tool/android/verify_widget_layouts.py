#!/usr/bin/env python3
"""R450 (t306u): fail if a home-screen widget layout in a built APK uses a class that
RemoteViews refuses to inflate (v0.18.1–v0.20.0 used a plain <View> -> every widget
showed "Can't load widget" / "Widgetiä ei voi ladata").

Reads the compiled manifest, follows every android.appwidget.provider meta-data to its
<appwidget-provider> XML, then checks initialLayout / previewLayout /
initialKeyguardLayout (all resource configurations, <include>s followed).
Usage: verify_widget_layouts.py <aapt2> <apk> [<apk>...]
"""
import re
import subprocess
import sys

# https://developer.android.com/develop/ui/views/appwidgets/advanced (RemoteViews classes)
ALLOWED = {
    'FrameLayout', 'LinearLayout', 'RelativeLayout', 'GridLayout',
    'AnalogClock', 'Button', 'Chronometer', 'ImageButton', 'ImageView', 'ProgressBar',
    'TextView', 'TextClock', 'ViewFlipper', 'ListView', 'GridView', 'StackView',
    'AdapterViewFlipper', 'ViewStub',
}
ALLOWED_API31 = {'CheckBox', 'RadioButton', 'RadioGroup', 'Switch'}
# LayoutInflater tags that are not classes.
META = {'include', 'requestFocus', 'tag'}
ATTRS = ('initialLayout', 'previewLayout', 'initialKeyguardLayout')


def aapt(aapt2, *args):
    return subprocess.run([aapt2, *args], check=True, capture_output=True, text=True).stdout


def resource_files(aapt2, apk):
    """resource id (int) -> [(name, config, file)]"""
    out, cur, name = {}, None, None
    for line in aapt(aapt2, 'dump', 'resources', apk).splitlines():
        m = re.match(r'\s+resource 0x([0-9a-f]+) (\S+)', line)
        if m:
            cur, name = int(m.group(1), 16), m.group(2)
            continue
        m = re.match(r'\s+\((.*?)\) \(file\) (\S+)', line)
        if m and cur is not None:
            out.setdefault(cur, []).append((name, m.group(1), m.group(2)))
    return out


def api_of(config):
    m = re.search(r'\bv(\d+)\b', config or '')
    return int(m.group(1)) if m else 0


def min_sdk(aapt2, apk):
    m = re.search(r'minSdkVersion\(0x[0-9a-f]+\)=(\d+)', aapt(aapt2, 'dump', 'xmltree', '--file', 'AndroidManifest.xml', apk))
    return int(m.group(1)) if m else 1


def check_apk(aapt2, apk):
    errors, checked = [], []
    files = resource_files(aapt2, apk)
    manifest = aapt(aapt2, 'dump', 'xmltree', '--file', 'AndroidManifest.xml', apk)
    msdk = min_sdk(aapt2, apk)
    providers = re.findall(
        r'name\(0x01010003\)="android\.appwidget\.provider".*?\n\s*A: \S*resource\(0x01010025\)=@0x([0-9a-f]+)',
        manifest)
    if not providers:
        errors.append('no android.appwidget.provider meta-data found in the manifest')
    seen = set()

    def check_layout(rid, via):
        for name, config, path in files.get(rid, []):
            if path in seen:
                continue
            seen.add(path)
            api = max(api_of(config), msdk)
            checked.append(f'{name} ({config or "default"}) <- {via}')
            tree = aapt(aapt2, 'dump', 'xmltree', '--file', path, apk)
            for tag in re.findall(r'^\s*E: (\S+)', tree, re.M):
                short = tag[len('android.widget.'):] if tag.startswith('android.widget.') else tag
                if short in ALLOWED or short in META:
                    continue
                if short in ALLOWED_API31 and api >= 31:
                    continue
                why = 'needs layout-v31' if short in ALLOWED_API31 else 'not allowed in RemoteViews'
                errors.append(f'{name} ({config or "default"}): <{tag}> {why}')
            for inc in re.findall(r'E: include.*?\n(?:\s+A: .*\n)*?\s+A: (?:\S*:)?layout(?:\(0x[0-9a-f]+\))?=@0x([0-9a-f]+)', tree):
                check_layout(int(inc, 16), f'{name} <include>')

    for prid in providers:
        for pname, _, ppath in files.get(int(prid, 16), []):
            tree = aapt(aapt2, 'dump', 'xmltree', '--file', ppath, apk)
            for attr in ATTRS:
                for rid in re.findall(attr + r'\(0x[0-9a-f]+\)=@0x([0-9a-f]+)', tree):
                    check_layout(int(rid, 16), f'{pname}:{attr}')
    return errors, checked


def main(argv):
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    aapt2, fail = argv[1], 0
    for apk in argv[2:]:
        errors, checked = check_apk(aapt2, apk)
        for c in checked:
            print(f'ok   widget layout {c}')
        if not checked and not errors:
            errors.append('no widget layout checked')
        for e in errors:
            print(f'FAIL {apk}: {e}', file=sys.stderr)
            fail = 1
    return fail


if __name__ == '__main__':
    sys.exit(main(sys.argv))
