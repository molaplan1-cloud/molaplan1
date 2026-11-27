#!/usr/bin/env bash
# v0.19.1 (t299u): fail the build if R8 stripped constructors that Android/WorkManager
# create by reflection at process start (v0.18.0–v0.19.0 crashed on every launch).
# v0.20.1 (R450, t306u): + widget layouts only use RemoteViews-allowed classes.
# Usage: tool/android/verify_release_apk.sh <apk> [<apk>...]
set -euo pipefail
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
dexdump="$(ls -1 "$sdk"/build-tools/*/dexdump 2>/dev/null | sort -V | tail -1 || true)"
[ -x "$dexdump" ] || { echo "dexdump not found under \$ANDROID_HOME/build-tools" >&2; exit 2; }
aapt2="$(ls -1 "$sdk"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1 || true)"
[ -x "$aapt2" ] || { echo "aapt2 not found under \$ANDROID_HOME/build-tools" >&2; exit 2; }
fail=0
for apk in "$@"; do
  tmp="$(mktemp -d)"
  unzip -q -o "$apk" 'classes*.dex' -d "$tmp"
  dump="$tmp/dump.txt"
  for d in "$tmp"/classes*.dex; do "$dexdump" -d "$d" >> "$dump" 2>/dev/null || true; done
  check() { # class descriptor, constructor signature
    if awk -v c="  Class descriptor  : '$1'" -v s="$2" '
        $0 == c {inc=1; next}
        /^Class #/ {inc=0}
        inc && /name *: .<init>./ {init=1; next}
        inc && init && /type *:/ { if (index($0, s)) found=1; init=0 }
        END {exit found ? 0 : 1}' "$dump"; then
      echo "ok   $1 <init>$2"
    else
      echo "FAIL $(basename "$apk"): $1 has no constructor $2 (R8 stripped it)" >&2; fail=1
    fi
  }
  check 'Landroidx/work/impl/WorkDatabase_Impl;' "'()V'"
  check 'Lcom/molaplan/molaplan/WidgetRefreshWorker;' "'(Landroid/content/Context;Landroidx/work/WorkerParameters;)V'"
  for c in MainActivity BridgeService NtfyListenService BootReceiver TileStatusWidget WidgetPinnedReceiver \
           AdminReceiver InstallResultReceiver UpdateTriggerReceiver; do
    check "Lcom/molaplan/molaplan/$c;" "'()V'"
  done
  rm -rf "$tmp"
done
# R450 (t306u): home-screen widget layouts may only use classes RemoteViews can inflate.
python3 "$(dirname "$0")/verify_widget_layouts.py" "$aapt2" "$@" || fail=1
exit $fail
