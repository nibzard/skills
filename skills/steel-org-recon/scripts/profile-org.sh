#!/usr/bin/env sh
# ABOUTME: Prints one Steel organization's identity, session coverage, and stored-artifact profile.
# ABOUTME: Usage: profile-org.sh <org_id>   — read-only against the warehouse and Tigris storage.
#
# Each section prints a small "Success / true" box first. That is steel-duck.sh reporting its
# CREATE SECRET statement, not a result. Ignore it.
set -e

ORG="$1"
if [ -z "$ORG" ]; then
  echo "usage: profile-org.sh <org_id>" >&2
  exit 2
fi

ROOT="${STEEL_SESSION_LAB:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
DUCK="$ROOT/scripts/steel-duck.sh"
STORAGE_ENV="$ROOT/scripts/steel-storage-env.sh"

if [ ! -x "$DUCK" ]; then
  echo "cannot find $DUCK — set STEEL_SESSION_LAB to the session-lab root" >&2
  exit 2
fi

# Use timeout when available so a slow storage listing cannot hang the run.
if command -v timeout >/dev/null 2>&1; then TO="timeout 90"; else TO=""; fi

echo "═══ 1. Organization record ═══"
"$DUCK" "
SELECT org_id, org_name, slug, plan, billing_status, created_at, is_bot, is_deleted
FROM wh.raw_steel_organizations WHERE org_id='$ORG';
SELECT max(created_at) AS warehouse_newest_org, current_date AS today
FROM wh.raw_steel_organizations;
"

echo "═══ 2. Members ═══"
"$DUCK" "
SELECT m.role, m.email, u.first_name, u.last_name, to_timestamp(m.created_at/1000) AS joined_at
FROM wh.raw_clerk_org_memberships m
LEFT JOIN wh.raw_clerk_users u USING (clerk_user_id)
WHERE m.org_id='$ORG' ORDER BY m.created_at;
"

echo "═══ 3. Signup questionnaire (what they SAID they were doing) ═══"
"$DUCK" "
SELECT questionnaire_at, responses_json, metadata_json
FROM wh.raw_steel_questionnaires WHERE org_id='$ORG';
"

echo "═══ 4. Projects ═══"
"$DUCK" "
SELECT project_id, name, namespace, is_default, is_production, created_at, deleted_at
FROM wh.raw_steel_projects WHERE org_id='$ORG' ORDER BY created_at;
"

echo "═══ 5. Daily session totals (NOTE: status_count fields do NOT indicate success) ═══"
"$DUCK" "
SELECT activity_date, sessions_count, round(duration_minutes_sum,1) AS minutes,
       credits_sum, failed_count, stopped_count, first_activity_at, last_activity_at
FROM wh.raw_steel_org_sessions_daily WHERE org_id='$ORG' ORDER BY activity_date;
"

echo "═══ 6. Session tags (only tagged sessions appear here; empty is normal) ═══"
"$DUCK" "
SELECT tag, count(DISTINCT session_id) AS sessions, any_value(source) AS source
FROM wh.raw_steel_session_tags WHERE org_id='$ORG' GROUP BY tag ORDER BY sessions DESC;
"

echo "═══ 7. Coverage reconciliation (warehouse vs object storage) ═══"
"$DUCK" "
SELECT
  (SELECT coalesce(sum(sessions_count),0) FROM wh.raw_steel_org_sessions_daily
     WHERE org_id='$ORG')                                        AS warehouse_sessions,
  (SELECT count(*) FROM glob('s3://steel-logs/logs/$ORG/*/*/logs.parquet')) AS sessions_with_logs;
"
echo "A gap means some sessions wrote no log file. State that ceiling in the report."

echo "═══ 8. Stored artifacts — absence is evidence ═══"
if [ ! -f "$ROOT/.env" ]; then
  echo "(skipped: $ROOT/.env not found)"
  exit 0
fi

# scripts/steel-storage-env.sh resolves .env relative to $0, which breaks when it is sourced from
# outside scripts/. Configure rclone directly from the same credentials instead.
set -a
# shellcheck disable=SC1091
. "$ROOT/.env"
set +a
RCLONE_S3_PROVIDER=Other
RCLONE_S3_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
RCLONE_S3_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
RCLONE_S3_ENDPOINT="$AWS_ENDPOINT_URL_S3"
RCLONE_S3_REGION=auto
export RCLONE_S3_PROVIDER RCLONE_S3_ACCESS_KEY_ID RCLONE_S3_SECRET_ACCESS_KEY \
       RCLONE_S3_ENDPOINT RCLONE_S3_REGION

for prefix in \
  "steel-files/profiles:persisted browser identity (empty => cold browser every session)" \
  "steel-files/extensions:customer-uploaded extensions (empty => any extension seen is Steel's)" \
  "steel-files/files:session file up/downloads" \
  "steel-files/archives:per-session file archives" \
  "steel-recordings/recordings:session video recordings (present => headful)"
do
  path=$(echo "$prefix" | cut -d: -f1)
  note=$(echo "$prefix" | cut -d: -f2-)
  count=$($TO rclone lsf ":s3:$path/$ORG/" --max-depth 1 2>/dev/null | wc -l | tr -d ' ')
  printf '%-34s %6s entries   %s\n' "$path/" "$count" "$note"
done
