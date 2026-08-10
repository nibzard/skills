#!/usr/bin/env sh
# ABOUTME: Prints the standard evidence battery for an org recon from a local session-log cache.
# ABOUTME: Usage: forensics.sh <db_path>   — noise split, errors, outcomes, human-takeover tests.
set -e

DB="$1"
if [ -z "$DB" ] || [ ! -f "$DB" ]; then
  echo "usage: forensics.sh <db_path>" >&2
  exit 2
fi

Q() { duckdb "$DB" -readonly -box -c "$1"; }

echo "═══ 1. Per-session overview (reqfail_clean excludes Steel's injected extension) ═══"
Q "
SELECT session_id[1:8] AS sid, strftime(min(timestamp),'%m-%d %H:%M:%S') AS started,
  round(date_diff('second', min(timestamp), max(timestamp))) AS secs,
  count(*) FILTER (WHERE event_type='BrowserInteraction') AS acts,
  count(*) FILTER (WHERE event_type='Navigation')         AS navs,
  count(*) FILTER (WHERE event_type='CDPCommand')         AS cdp_cmds,
  count(*) FILTER (WHERE event_type='PageError')          AS page_errs,
  count(*) FILTER (WHERE event_type='RequestFailed'
    AND coalesce(json_extract_string(data,'\$.error.url'),'') NOT LIKE 'chrome-extension%')
                                                          AS reqfail_clean,
  count(*) AS events
FROM ev GROUP BY 1 ORDER BY min(timestamp);
"
echo "cdp_cmds = 0 with ~2 events means the client never attached: a 'never_driven' session."

echo "═══ 2. Injected-extension noise split (compute error rates AFTER excluding this) ═══"
Q "
WITH r AS (SELECT json_extract_string(data,'\$.request.url') AS u FROM ev WHERE event_type='Request'),
     f AS (SELECT json_extract_string(data,'\$.error.url')   AS u FROM ev WHERE event_type='RequestFailed'),
     p AS (SELECT json_extract_string(data,'\$.response.url') AS u FROM ev WHERE event_type='Response')
SELECT
  (SELECT count(*) FROM r WHERE u='chrome-extension://invalid/')       AS invalid_requested,
  (SELECT count(*) FROM f WHERE u='chrome-extension://invalid/')       AS invalid_failed,
  (SELECT count(*) FROM p WHERE u='chrome-extension://invalid/')       AS invalid_responded,
  (SELECT count(*) FROM r WHERE u LIKE 'chrome-extension://%'
     AND u <> 'chrome-extension://invalid/')                           AS real_ext_requested,
  (SELECT count(*) FROM f WHERE u LIKE 'chrome-extension://%'
     AND u <> 'chrome-extension://invalid/')                           AS real_ext_failed,
  (SELECT count(*) FROM f)                                             AS all_request_failures;
"
Q "
SELECT DISTINCT regexp_extract(json_extract_string(data,'\$.request.url'),
         'chrome-extension://([a-z]+)/', 1) AS extension_id, count(*) AS resources
FROM ev WHERE event_type='Request'
  AND json_extract_string(data,'\$.request.url') LIKE 'chrome-extension://%'
GROUP BY 1 ORDER BY resources DESC;
"
echo "A non-'invalid' extension id is Steel's unless steel-files/extensions/<org>/ is non-empty."

echo "═══ 3. Non-success responses by host (the real error signal) ═══"
Q "
SELECT regexp_extract(json_extract_string(data,'\$.response.url'),'https?://([^/]+)',1) AS host,
       json_extract_string(data,'\$.response.status') AS status, count(*) AS n
FROM ev WHERE event_type='Response'
  AND json_extract_string(data,'\$.response.status') NOT LIKE '2%'
  AND json_extract_string(data,'\$.response.status') NOT LIKE '3%'
GROUP BY 1,2 ORDER BY n DESC LIMIT 25;
"

echo "═══ 4. Page errors by session ═══"
Q "
SELECT session_id[1:8] AS sid, left(json_extract_string(data,'\$.error.message'),90) AS msg,
       count(*) AS n
FROM ev WHERE event_type='PageError' GROUP BY 1,2 ORDER BY 1, n DESC LIMIT 30;
"

echo "═══ 5. First and last navigation per session (last URL usually decides the outcome) ═══"
Q "
WITH n AS (SELECT session_id, timestamp,
             json_extract_string(data,'\$.navigation.url') AS u
           FROM ev WHERE event_type='Navigation')
SELECT session_id[1:8] AS sid,
       left(arg_min(u,timestamp),60) AS first_url,
       left(arg_max(u,timestamp),85) AS last_url
FROM n GROUP BY 1 ORDER BY 1;
"

echo "═══ 6. Wall and challenge markers ═══"
Q "
SELECT session_id[1:8] AS sid,
  count(*) FILTER (WHERE regexp_matches(coalesce(json_extract_string(data,'\$.response.url'),
    json_extract_string(data,'\$.request.url'),''),
    '(?i)(captcha|_incapsula_|incap_|datadome|perimeterx|px-cdn|cf-chl|imperva|awswaf)')) AS wall_assets,
  count(*) FILTER (WHERE regexp_matches(coalesce(json_extract_string(data,'\$.navigation.url'),''),
    '(?i)(checkpoint/challenge|challengesV2|/processing|/chal_t|geo[.]captcha)')) AS challenge_navs,
  count(*) FILTER (WHERE regexp_matches(
    coalesce(json_extract_string(data,'\$.interaction.target.text'),''),
    '(?i)(press *& *hold|confirm you are a human|verify you are human|i am not a robot)')) AS human_widgets
FROM ev GROUP BY 1 HAVING wall_assets+challenge_navs+human_widgets > 0 ORDER BY 1;
"
echo "Wall assets alone are NOT failure — many sites load these as ordinary page assets."

echo "═══ 7. CDP input summary ═══"
Q "
SELECT session_id[1:8] AS sid,
  count(*) FILTER (WHERE json_extract_string(data,'\$.cdp.command')='Input.dispatchMouseEvent'
    AND json_extract_string(data,'\$.cdp.params.type')='mousePressed') AS mouse_down,
  count(*) FILTER (WHERE json_extract_string(data,'\$.cdp.command')='Input.dispatchMouseEvent'
    AND json_extract_string(data,'\$.cdp.params.type')='mouseMoved')   AS mouse_moved,
  count(*) FILTER (WHERE json_extract_string(data,'\$.cdp.command')='Input.dispatchKeyEvent'
    AND json_extract_string(data,'\$.cdp.params.type')='keyDown')      AS keystrokes,
  count(*) FILTER (WHERE json_extract_string(data,'\$.cdp.command')='Page.navigate') AS navigate_cmds
FROM ev WHERE event_type='CDPCommand' GROUP BY 1 ORDER BY 2 DESC, 4 DESC;
"
echo "mouse_moved = 0 means no cursor simulation. Only 3 command types are logged by Steel,"
echo "so absence of others means 'not logged', NOT 'not used'."

echo "═══ 8. Human-takeover test A: keystroke cadence ═══"
Q "
WITH k AS (
  SELECT session_id, timestamp,
    date_diff('millisecond',
      lag(timestamp) OVER (PARTITION BY session_id ORDER BY timestamp), timestamp) AS gap
  FROM ev WHERE event_type='CDPCommand'
    AND json_extract_string(data,'\$.cdp.command')='Input.dispatchKeyEvent'
    AND json_extract_string(data,'\$.cdp.params.type')='keyDown')
SELECT session_id[1:8] AS sid, count(*) AS gaps,
  round(median(gap)) AS median_ms,
  round(quantile_cont(gap,0.25)) AS p25_ms,
  round(quantile_cont(gap,0.75)) AS p75_ms,
  round(quantile_cont(gap,0.75) - quantile_cont(gap,0.25)) AS iqr_ms
FROM k WHERE gap IS NOT NULL AND gap < 2000 GROUP BY 1 ORDER BY 1;
"
echo "iqr_ms is the discriminator, not the mean or stddev: think-pauses between bursts inflate"
echo "those even for a machine. A tight IQR (single-digit to ~20ms) around a fixed median is"
echo "programmatic typing. Humans run 80-300ms median with an IQR of 50-150ms and obvious"
echo "per-character variation (punctuation slower than common letters)."

echo "═══ 9. Human-takeover test B: click offset from element centre ═══"
Q "
WITH m AS (SELECT session_id, timestamp,
    json_extract(data,'\$.cdp.params.x')::DOUBLE AS x,
    json_extract(data,'\$.cdp.params.y')::DOUBLE AS y
  FROM ev WHERE event_type='CDPCommand'
    AND json_extract_string(data,'\$.cdp.command')='Input.dispatchMouseEvent'
    AND json_extract_string(data,'\$.cdp.params.type')='mousePressed'),
 c AS (SELECT session_id, timestamp,
    json_extract(data,'\$.interaction.target.boundingBox.x')::DOUBLE AS bbx,
    json_extract(data,'\$.interaction.target.boundingBox.y')::DOUBLE AS bby,
    json_extract(data,'\$.interaction.target.boundingBox.width')::DOUBLE  AS bbw,
    json_extract(data,'\$.interaction.target.boundingBox.height')::DOUBLE AS bbh,
    json_extract_string(data,'\$.interaction.target.tagName') AS tag
  FROM ev WHERE event_type='BrowserInteraction'
    AND json_extract_string(data,'\$.interaction.action') IN ('click','doubleClick'))
SELECT m.session_id[1:8] AS sid, strftime(m.timestamp,'%H:%M:%S') AS at_time,
  m.x, m.y, c.tag,
  round(m.x-(c.bbx+c.bbw/2),3) AS dx, round(m.y-(c.bby+c.bbh/2),3) AS dy
FROM m LEFT JOIN c
  ON c.session_id=m.session_id AND abs(date_diff('millisecond',m.timestamp,c.timestamp))<400
ORDER BY m.session_id, m.timestamp;
"
echo "dx=dy=0.0 at sub-pixel coordinates = computed element centre = programmatic."
echo "Large offsets against a <html> target are meaningless (its box is the whole document)."

echo "═══ 10. Composite-key check (synthesized input, and a known clear-field bug) ═══"
Q "
SELECT session_id[1:8] AS sid, json_extract_string(data,'\$.cdp.params.key') AS key_name,
       json_extract_string(data,'\$.cdp.params.modifiers') AS modifiers, count(*) AS n
FROM ev WHERE event_type='CDPCommand'
  AND json_extract_string(data,'\$.cdp.command')='Input.dispatchKeyEvent'
  AND json_extract_string(data,'\$.cdp.params.key') LIKE '%+%'
GROUP BY 1,2,3 ORDER BY 1;
"
echo "A composite like 'Control+a' as ONE keyDown with no modifier bitmask does not select text."
echo "It deletes one character instead, so the next typing APPENDS. Watch for value lengths that"
echo "grow past the expected field length in the trace."
