# Data map

Where the evidence lives. Verified against the warehouse snapshot and Tigris production buckets.

## Access helpers

| Helper | Use |
|---|---|
| `scripts/steel-duck.sh "<sql>"` | DuckDB with the Tigris S3 secret configured and the warehouse attached as `wh` (read-only). No args opens a REPL. |
| `. scripts/steel-storage-env.sh` | Configures rclone for Tigris. Then `rclone lsf :s3:<bucket>/<prefix>/`. |

The warehouse attaches from `$STEEL_WAREHOUSE_DB`, defaulting to
`~/dev/steel/steel-warehouse/data/warehouse.duckdb`. If a query returns no rows for an org that
clearly exists, check snapshot freshness before concluding anything:
`SELECT max(created_at) FROM wh.raw_steel_organizations`.

## Warehouse tables that matter for recon

`SELECT database, schema, name FROM (SHOW ALL TABLES)` — never bare `SHOW ALL TABLES`, which
dumps every column definition and floods the output.

| Table | Key columns |
|---|---|
| `raw_steel_organizations` | `org_id, org_name, slug, plan, billing_status, created_at, updated_at, is_bot, is_deleted, clerk_org_id, stripe_id` |
| `raw_clerk_org_memberships` | `org_id, clerk_user_id, role, identifier, email, created_at` (epoch ms) |
| `raw_clerk_users` | `clerk_user_id, identifier, email, first_name, last_name, image_url` |
| `raw_steel_questionnaires` | `org_id, responses_json, metadata_json, questionnaire_at` |
| `raw_steel_projects` | `org_id, project_id, name, slug, namespace, is_default, is_production, deleted_at` |
| `raw_steel_org_sessions_daily` | `org_id, activity_date, sessions_count, duration_minutes_sum, credits_sum, failed_count, stopped_count, first_activity_at, last_activity_at` |
| `raw_steel_session_tags` | `session_id, org_id, project_id, session_created_at, activity_date, status, duration_ms, credits_used, source, tag` — **one row per tag**, and only for sessions that got tagged. Deduplicate before counting sessions. |
| `raw_steel_org_concurrency_daily`, `org_billing_snapshot`, `org_activity_snapshot` | plan limits, spend, and activity context when the question is commercial |

Known `source` values: `api:sessions`, `api:scrape`, `api:screenshot`, `api:pdf`.

**There is no per-session fact table.** Untagged sessions appear nowhere in the warehouse, so
storage is the only complete inventory of sessions. This is why Phase 1 reconciles the two.

## Object storage

| Bucket / prefix | Contents |
|---|---|
| `steel-logs/logs/{orgId}/{project}/{sessionId}/logs.parquet` | the session event stream — the primary evidence |
| `steel-recordings/recordings/{orgId}/{sessionId}/` | video; presence implies the session was headful |
| `steel-files/profiles/{orgId}/{profileId}/userDataDir.zip` | persisted browser identity. **Sensitive.** Empty prefix = cold browser every session |
| `steel-files/extensions/{orgId}/{extensionId}/<name>.zip` | customer-uploaded extensions. Empty = any extension in the logs is Steel-injected |
| `steel-files/files/{orgId}/{sessionId}/{fileId}` | session file up/downloads |
| `steel-files/archives/{orgId}/{sessionId}/files.zip` | per-session archive; 22 bytes means empty |
| `steel-files/browser-results/{jobId}.json` | scrape/extract job output, keyed by job id — **not** by org, so it cannot be listed per org |

Staging and preview variants exist (`-staging`, `-preview`); production is the unsuffixed name.

Do not list `steel-files/browser-results/` or other flat prefixes with 100k+ objects — the
listing times out. Only list exact `{prefix}/{orgId}/` paths.

## Event schema

Columns: `id, timestamp, event_type, target_type, page_id, data (JSON), context (JSON), indexed_at`.

`context` holds `orgId`, `sessionId`, `namespace`, `createdAt`.

| `event_type` | `data` payload |
|---|---|
| `Request` | `request{method, url, resourceType}` — no headers, so **no user-agent is recoverable** |
| `Response` | `response{url, status, ...}` |
| `RequestFailed` | `error{message, url}` — `net::ERR_FAILED`, `net::ERR_ABORTED` |
| `Navigation` | `navigation{url}` |
| `BrowserInteraction` | `interaction{action, eventType, page, target, value, pointer, keyboard}` |
| `Console` | `console{type, text}` |
| `PageError` | `error{message}` |
| `CDPCommand` / `CDPCommandResult` | `cdp{command, params, sessionId}` |
| `CDPEvent` | `cdp{name, params}` — in practice only `Page.frameNavigated` |

`interaction.action` values: `click`, `doubleClick`, `navigate`, `scroll`, `input`, `change`,
`submit`, `drag`, `keyPress`.

`interaction.target` carries `tagName`, `role`, `accessibleName`, `text`, `attributes`,
`selector{css, id, testId, name, aria}`, and `boundingBox{x,y,width,height}`. The accessible name
is often the most informative field in the whole dataset — it is how you learn that a click was
"Ignore an invitation to connect from …" rather than "button".

`interaction.value` is `{inputType, valueLength, checked?, redacted?}` — the literal value is
never stored here, so **length is the fingerprint**. Passwords come through as
`{"inputType":"password","valueLength":28,"redacted":true}`.

**CDP logging is whitelisted.** Only `Page.navigate`, `Input.dispatchKeyEvent`, and
`Input.dispatchMouseEvent` appear as `CDPCommand`. Absence of `Runtime.evaluate` etc. means "not
logged", not "not used". Consequently most clicks in a trace have no matching CDP command — they
were dispatched in-page.

**Keystrokes are unredacted.** `cdp.params.key` and `cdp.params.text` hold the literal character,
so a keystroke sequence reconstructs into plaintext. This is how you recover an email address or
a one-time code. It also means a client that types a password character-by-character writes it to
these logs in the clear — report that if you see it.
