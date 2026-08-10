# Query cookbook

The bundled scripts cover the standard battery. This file covers the traps that will cost you
turns, and the ad-hoc queries worth reaching for when a specific question comes up.

## DuckDB traps

These all bit during a real investigation. Each one costs a round-trip, and one of them returns
wrong answers silently.

**Reserved words as column aliases.** `first`, `last`, `key`, `by`, `action`, `start`, `end`,
`order` all fail with `syntax error at or near ...`. Use `first_url`, `key_name`, `act`, etc.

**`USING SAMPLE n ROWS` combined with `WHERE` silently returns nothing** — the sample is drawn
before the filter, so a filtered sample of a minority event type comes back empty and looks like
"no such events exist". Use `LIMIT` for exploration instead. This is the dangerous one: it fails
as a plausible finding rather than an error.

**JSON operators are not interchangeable.** `data->'error'->>'url'` throws a cast error inside a
`WHERE` clause while `json_extract_string(data,'$.error.url')` on the same path works. Default to
`json_extract_string` everywhere, and `json_extract(...)::DOUBLE` for numbers.

**No slicing a cast timestamp.** `timestamp::TIME::VARCHAR[1:8]` does not parse. Use
`strftime(timestamp,'%H:%M:%S')`.

**`SHOW ALL TABLES` dumps every column definition** — 150KB+. Use
`SELECT name FROM (SHOW ALL TABLES)`.

**A multi-path `read_parquet([...])` can return empty with exit code 0** if one path in the list
is unreadable. Query one org at a time when scanning across orgs, so a bad path fails loudly
instead of poisoning the whole result.

**Shell escaping.** These scripts pass SQL through a double-quoted shell string, so JSON paths
must be written `'\$.foo.bar'`. Prefer `[.]` over `\.` in regexes to avoid escaping entirely.

## Reconstructing typed text

Answers "which account was this?" and "where did that code come from?". Keep the output in chat,
never in a file.

```sql
SELECT session_id[1:8] AS sid, strftime(min(timestamp),'%H:%M:%S') AS started,
       string_agg(k, '' ORDER BY timestamp) AS typed
FROM (
  SELECT session_id, timestamp, json_extract_string(data,'$.cdp.params.key') AS k
  FROM ev WHERE event_type='CDPCommand'
    AND json_extract_string(data,'$.cdp.command')='Input.dispatchKeyEvent'
    AND json_extract_string(data,'$.cdp.params.type')='keyDown'
) GROUP BY session_id ORDER BY 2;
```

Only text typed character-by-character appears. Anything set with a `fill`-style call shows up in
the trace as a single `input` event with a `valueLength` and no keystrokes — for those, length is
all you get, so match lengths against known candidates and say explicitly that it is a length
match rather than a proof.

## Is an extension ours or theirs?

Check `steel-files/extensions/{org}/` first (empty means ours). To confirm, look for the same
extension id in an unrelated org — pick a contemporaneous org from
`raw_steel_org_sessions_daily` and scan one org at a time:

```sql
SELECT count(*) AS resources
FROM read_parquet('s3://steel-logs/logs/<other_org>/*/*/logs.parquet', union_by_name=true)
WHERE json_extract_string(data,'$.request.url') LIKE 'chrome-extension://<id>%';
```

Minutes per org. Budget the number up front and report `n=` honestly.

## Is a failure loop activity-driven or a fixed timer?

Distinguishes "reacting to the page" from "hot-looping". Flat counts per minute against varying
click counts means a timer.

```sql
SELECT strftime(date_trunc('minute', timestamp),'%H:%M') AS minute,
  count(*) FILTER (WHERE event_type='RequestFailed'
    AND json_extract_string(data,'$.error.url')='chrome-extension://invalid/') AS failing,
  count(*) FILTER (WHERE event_type='BrowserInteraction'
    AND json_extract_string(data,'$.interaction.action')='click') AS clicks
FROM ev WHERE session_id LIKE '<prefix>%' GROUP BY 1 ORDER BY 1;
```

Add `median(gap)` over `lag(timestamp)` to get the interval.

## Did a navigation ever commit?

A `Page.navigate` command whose `CDPCommandResult` arrives long after, with no `Navigation` event
and no `Response` from the target host, is a site refusing to answer at all. That deserves its own
outcome note rather than being lumped in with HTTP errors.

```sql
SELECT strftime(timestamp,'%H:%M:%S') AS at_time, event_type,
       coalesce(json_extract_string(data,'$.cdp.params.url'),
                json_extract_string(data,'$.request.url'),
                json_extract_string(data,'$.navigation.url')) AS url
FROM ev WHERE session_id LIKE '<prefix>%'
  AND event_type IN ('CDPCommand','CDPCommandResult','Navigation','Response')
ORDER BY timestamp;
```

## Session pairing

When many sessions are `never_driven`, check whether each one appears near a working session —
that pattern points at an orchestration layer provisioning sessions it never attaches to, rather
than at random client crashes.

```sql
SELECT session_id[1:8] AS sid, strftime(min(timestamp),'%H:%M:%S') AS started,
       count(*) AS events, count(*) FILTER (WHERE event_type='CDPCommand') AS cdp_cmds
FROM ev GROUP BY 1 ORDER BY min(timestamp);
```

Read the ordering by hand: dead sessions starting 20–70 s after a live one is a very different
story from dead sessions clustered at the start of the day.

## Existing tooling worth using first

`uv run steel-unblock extract <org_id>` then `uv run steel-unblock targets <org_id>` gives a
target-host table with error rates, wall percentages, and 403/429 counts in two commands. Run it
early — it is faster than writing the equivalent queries, and it caches incrementally. Read the
"Hard-won facts" section of the repo `README.md` for how to interpret `wall%` (it is not failure).
