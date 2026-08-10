#!/usr/bin/env sh
# ABOUTME: Enumerates the event schema, or dumps a flat chronological action trace, from a cache.
# ABOUTME: Usage: dump-trace.sh <db_path> [--schema | --all | --session <prefix>]
set -e

DB="$1"
shift 2>/dev/null || true
if [ -z "$DB" ] || [ ! -f "$DB" ]; then
  echo "usage: dump-trace.sh <db_path> [--schema | --all | --session <prefix>]" >&2
  exit 2
fi

MODE="trace"
SKIP_SCROLL="AND act <> 'scroll'"
FILTER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --schema)  MODE="schema" ;;
    --all)     SKIP_SCROLL="" ;;
    --session) FILTER="AND session_id LIKE '$2%'"; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

if [ "$MODE" = "schema" ]; then
  # Enumerate what is actually present rather than guessing JSON paths. Guessed paths return
  # all-NULL columns that look like real findings.
  duckdb "$DB" -readonly -box -c "
  SELECT event_type, target_type, count(*) AS events
  FROM ev GROUP BY 1,2 ORDER BY events DESC;
  "
  duckdb "$DB" -readonly -box -c "
  SELECT event_type, data_key, count(*) AS n FROM (
    SELECT event_type, unnest(json_keys(data)) AS data_key FROM ev
  ) GROUP BY 1,2 ORDER BY 1, n DESC;
  "
  duckdb "$DB" -readonly -box -c "
  SELECT json_extract_string(data,'\$.interaction.action')    AS act,
         json_extract_string(data,'\$.interaction.eventType') AS dom_event,
         count(*) AS n
  FROM ev WHERE event_type='BrowserInteraction' GROUP BY 1,2 ORDER BY n DESC;
  "
  exit 0
fi

# One line per meaningful action. Read this top to bottom — the sequence is what identifies the
# task. Values are logged as type+length (passwords redacted), so lengths are the fingerprint.
duckdb "$DB" -readonly -noheader -list -c "
WITH a AS (
  SELECT session_id, timestamp,
    json_extract_string(data,'\$.interaction.action')                 AS act,
    json_extract_string(data,'\$.interaction.navigation.url')         AS nav,
    json_extract_string(data,'\$.interaction.value')                  AS val,
    json_extract_string(data,'\$.interaction.target.tagName')         AS tag,
    json_extract_string(data,'\$.interaction.target.accessibleName')  AS aname,
    json_extract_string(data,'\$.interaction.target.text')            AS txt,
    json_extract_string(data,'\$.interaction.target.attributes.placeholder') AS ph
  FROM ev WHERE event_type='BrowserInteraction'
)
SELECT session_id[1:8] || ' | ' || strftime(timestamp,'%m-%d %H:%M:%S') || ' | ' || act || ' | ' ||
  coalesce(
    nav,
    coalesce(tag,'') || '[' || coalesce(nullif(aname,''), coalesce(txt,'')) ||
      coalesce(' ph=' || ph, '') || ']' || coalesce(' = ' || val, ''),
    ''
  )
FROM a
WHERE true $SKIP_SCROLL $FILTER
ORDER BY session_id, timestamp;
"
