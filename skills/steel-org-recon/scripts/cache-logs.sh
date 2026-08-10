#!/usr/bin/env sh
# ABOUTME: Copies one organization's raw session events from Tigris into a local DuckDB cache.
# ABOUTME: Usage: cache-logs.sh <org_id> [max_sessions]   — prints the cache path when finished.
set -e

ORG="$1"
MAX="$2"
if [ -z "$ORG" ]; then
  echo "usage: cache-logs.sh <org_id> [max_sessions]" >&2
  exit 2
fi

ROOT="${STEEL_SESSION_LAB:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
DUCK="$ROOT/scripts/steel-duck.sh"
OUTDIR="$ROOT/data/recon"
DB="$OUTDIR/$ORG.duckdb"
mkdir -p "$OUTDIR"

GLOB="s3://steel-logs/logs/$ORG/*/*/logs.parquet"

# Session id is the directory above logs.parquet; project is the one above that. Deriving both
# from the path keeps this working for orgs that use projects other than 'default'.
PROJECTION="*,
  regexp_extract(filename, '([^/]+)/logs[.]parquet\$', 1) AS session_id,
  regexp_extract(filename, 'logs/[^/]+/([^/]+)/', 1)      AS project"

if [ -n "$MAX" ]; then
  echo "caching at most $MAX session files for $ORG ..."
  SOURCE="SET VARIABLE recon_files = (
      SELECT list(file) FROM (SELECT file FROM glob('$GLOB') ORDER BY file LIMIT $MAX)
    );
    CREATE OR REPLACE TABLE ev AS
    SELECT $PROJECTION
    FROM read_parquet(getvariable('recon_files'), union_by_name=true, filename=true);"
else
  echo "caching all session files for $ORG ..."
  SOURCE="CREATE OR REPLACE TABLE ev AS
    SELECT $PROJECTION
    FROM read_parquet('$GLOB', union_by_name=true, filename=true);"
fi

"$DUCK" "
ATTACH '$DB' AS cache;
USE cache;
$SOURCE
SELECT count(*) AS events, count(DISTINCT session_id) AS sessions,
       count(DISTINCT project) AS projects,
       min(timestamp) AS first_event, max(timestamp) AS last_event
FROM ev;
"

echo ""
echo "cache ready: $DB"
echo "query it with:  duckdb '$DB' -readonly -c \"SELECT ... FROM ev\""
