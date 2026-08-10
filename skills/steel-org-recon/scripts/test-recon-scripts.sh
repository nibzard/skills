#!/usr/bin/env sh
# ABOUTME: Smoke test for the steel-org-recon scripts — syntax, live warehouse/storage reads, cache.
# ABOUTME: Usage: test-recon-scripts.sh <org_id>   — needs an org that has session logs.
set -e

ORG="$1"
if [ -z "$ORG" ]; then
  echo "usage: test-recon-scripts.sh <org_id>" >&2
  echo "Pass an org id that has session logs. None is hardcoded here on purpose:" >&2
  echo "customer identifiers must not live in checked-in files." >&2
  exit 2
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${STEEL_SESSION_LAB:-$(cd "$HERE/../../../.." && pwd)}"

echo "1/6 shell syntax"
for f in "$HERE"/*.sh; do sh -n "$f"; done

echo "2/6 usage errors exit non-zero"
for f in profile-org.sh cache-logs.sh dump-trace.sh forensics.sh; do
  if "$HERE/$f" >/dev/null 2>&1; then
    echo "FAIL: $f exited 0 with no arguments" >&2
    exit 1
  fi
done

echo "3/6 profile-org.sh reaches warehouse and storage"
"$HERE/profile-org.sh" "$ORG" > /tmp/recon-profile.$$ 2>&1
for section in "1. Organization record" "7. Coverage reconciliation" "8. Stored artifacts"; do
  grep -q "$section" /tmp/recon-profile.$$ || {
    echo "FAIL: missing section '$section'" >&2; cat /tmp/recon-profile.$$ >&2; exit 1; }
done
grep -q "steel-recordings/recordings/" /tmp/recon-profile.$$ || {
  echo "FAIL: storage listing did not run" >&2; cat /tmp/recon-profile.$$ >&2; exit 1; }
rm -f /tmp/recon-profile.$$

echo "4/6 cache-logs.sh builds a bounded local cache"
"$HERE/cache-logs.sh" "$ORG" 2 > /dev/null
DB="$ROOT/data/recon/$ORG.duckdb"
[ -f "$DB" ] || { echo "FAIL: cache not created at $DB" >&2; exit 1; }
duckdb "$DB" -readonly -noheader -list -c \
  "SELECT CASE WHEN count(*) > 0 AND count(DISTINCT session_id) > 0
                AND count(*) FILTER (WHERE session_id IS NULL OR session_id='') = 0
           THEN 'ok' ELSE 'bad' END FROM ev" | grep -q '^ok$' || {
  echo "FAIL: cache rows or session_id extraction look wrong" >&2; exit 1; }

echo "5/6 dump-trace.sh schema and trace modes"
"$HERE/dump-trace.sh" "$DB" --schema | grep -q "event_type" || {
  echo "FAIL: schema mode produced no schema" >&2; exit 1; }
"$HERE/dump-trace.sh" "$DB" > /dev/null

echo "6/6 forensics.sh prints all ten sections"
"$HERE/forensics.sh" "$DB" > /tmp/recon-forensics.$$ 2>&1
count=$(grep -c '^═══ ' /tmp/recon-forensics.$$ || true)
if [ "$count" -ne 10 ]; then
  echo "FAIL: expected 10 sections, found $count" >&2
  cat /tmp/recon-forensics.$$ >&2
  exit 1
fi
grep -qi 'error:\|Parser Error\|Binder Error\|Conversion Error' /tmp/recon-forensics.$$ && {
  echo "FAIL: a forensics query errored" >&2
  grep -i 'error' /tmp/recon-forensics.$$ >&2
  exit 1; }
rm -f /tmp/recon-forensics.$$

echo ""
echo "all steel-org-recon script checks passed (cache left at $DB)"
