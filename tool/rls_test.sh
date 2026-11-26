#!/bin/bash
# Runs the Supabase migrations + RLS tests on a throw-away local Postgres (needs initdb/pg_ctl/psql).
# Usage: tool/rls_test.sh   (CI: the 'rls' job)
set -euo pipefail
cd "$(dirname "$0")/.."
BIN=${PG_BIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)}
D=$(mktemp -d)
PORT=${PG_PORT:-55432}
"$BIN/initdb" -D "$D" -U postgres -A trust >/dev/null
"$BIN/pg_ctl" -D "$D" -o "-p $PORT -k $D -c listen_addresses=''" -l "$D/log" start >/dev/null
trap '"$BIN/pg_ctl" -D "$D" stop -m immediate >/dev/null; rm -rf "$D"' EXIT
P="psql -X -q -v ON_ERROR_STOP=1 -h $D -p $PORT -U postgres -d postgres"
$P -f supabase/tests/auth_stub.sql
for m in supabase/migrations/*.sql; do
  case "$m" in *tile_images*|*shop_storage*) continue;; esac # storage schema is Supabase-only
  $P -f "$m"
done
# Running twice must work (migrations are idempotent).
$P -f supabase/migrations/20261126120000_sharing.sql
$P -o /dev/null -f supabase/tests/sharing_rls_test.sql
$P -f supabase/migrations/20261126200000_shop.sql
$P -f supabase/tests/shop_rls_test.sql
