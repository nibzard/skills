---
name: steel-org-recon
description: >-
  Reconstruct what a Steel customer organization was actually doing in its browser sessions,
  and whether it succeeded, from warehouse records plus raw session logs in object storage.
  Produces an evidence-backed report: inferred tasks, per-session outcomes, what blocked them,
  agent-quality problems, and what Steel itself cost them. Use this skill whenever someone
  gives you a Steel organization id (a bare UUID counts) and asks what that org was doing,
  what they were building, whether their sessions worked, why they failed, why they churned,
  whether they hit bot walls or CAPTCHAs, what their agent was trying to automate, or asks to
  investigate / explore / profile / dig into / look at an org, customer, account, or user.
  Also use it for questions like "did this session succeed", "was a human driving this",
  "which sites are failing for this customer", or "why does this org look unhealthy" —
  even when they do not say the words "org recon" or name this skill.
---

# Steel org recon

Resolve `SKILL_DIR` to the absolute directory containing this loaded `SKILL.md`.
Use that path for bundled helpers; keep the target project as the working directory.


Reconstruct one organization's real behaviour from evidence, not from status columns.

**Invocation:** `/steel-org-recon <org_id>` — or any request naming an org id.

The whole reason this skill exists: **Steel's own success fields lie.** A day containing ten
hard failures and seventeen sessions that never did anything is recorded as
`sessions_count: 40, failed_count: 0, stopped_count: 40`. Every session ends `stopped` because
that is the normal terminal state. If you answer from `raw_steel_org_sessions_daily` or from
session tags, you will confidently report the opposite of what happened. The truth only exists
in the raw event stream, read chronologically, one session at a time.

## Non-negotiables

**Read-only.** Follow `AGENTS.md`. Warehouse, Tigris, and every production system are read-only
here. No `cp`/`sync` to a bucket, no writes, no deletes, no wildcard mutations. Local scratch
and the local DuckDB cache are yours.

**Privacy has two tiers, and they differ.** Analysis in conversation may name identifiers —
that is the point of the investigation and the person asking has warehouse access. Any file you
write under `analysis/` or anywhere shareable must be scrubbed: no customer or member names, no
email addresses, no raw org/session ids, no full URLs or query parameters, no credentials, no
OTPs, no raw manifests. Aggregate or redact instead. When in doubt, keep the finding in chat and
write the scrubbed version to disk.

**Reconstructed secrets stay in chat.** `Input.dispatchKeyEvent` events store the literal typed
character, so keystroke sequences reconstruct into plaintext emails, search terms, and one-time
codes. Use them when they answer the question, never write them to a file, and flag it if you
find a password among them — that is a Steel logging defect worth reporting, not a detail.

## Method

Run the phases in order. The order is the point: identity before traces, because knowing "solo
developer, `launch` plan, account created 13 minutes ago" reframes everything you read next.
Skipping ahead to the traces is how you end up inventing a narrative and then defending it.

### Phase 1 — Identity and coverage

```sh
${SKILL_DIR}/scripts/profile-org.sh <org_id>
```

One command gives you the org record, members, signup questionnaire, projects, per-day session
totals, a warehouse-vs-storage session count reconciliation, and which stored artifacts exist.

Read it for:

- **Who and how new.** Plan, creation time, member count, and the questionnaire's
  self-description. A one-person `launch` org minutes old is a trial; a paid multi-member org is
  a workload. This single fact changes every downstream interpretation.
- **The self-description gap.** The questionnaire is what they *said*; the traces are what they
  *did*. When those disagree, the disagreement is the finding.
- **Coverage.** Warehouse session count versus log directory count. If they differ, some
  sessions wrote no log and your trace has a known ceiling — say so later rather than implying
  you saw everything.
- **Absence.** Empty `profiles/` means no persisted browser identity, which predicts repeated
  cold logins and challenge walls. Empty `extensions/` means any extension you see in the logs
  is Steel-injected, not theirs. These absences are among the highest-yield facts available and
  they cost seconds to check.

If the org is missing from the warehouse entirely, suspect a stale snapshot before concluding
the org does not exist — compare `max(created_at)` against the session dates.

### Phase 2 — Cache the logs locally

```sh
${SKILL_DIR}/scripts/cache-logs.sh <org_id> [max_sessions]
```

This copies the org's session events into a local DuckDB file so every later query is instant
and free. Do this before exploring. Querying S3 parquet repeatedly is slow enough that it
changes how much you are willing to look, which quietly caps the quality of the answer.

For large orgs, pass `max_sessions` and sample rather than caching everything. Say in the report
that you sampled, and how.

### Phase 3 — Learn the schema, do not guess it

```sh
${SKILL_DIR}/scripts/dump-trace.sh <db_path> --schema
```

This enumerates the JSON keys actually present under each `event_type`. Guessing JSON paths
wastes turns and silently returns all-NULL columns that look like real findings. Enumerate once,
then write queries against what is there. `references/data-map.md` documents the event shapes
you will normally see.

### Phase 4 — Read the flat trace

```sh
${SKILL_DIR}/scripts/dump-trace.sh <db_path> > trace.txt
```

One line per meaningful action, sorted by session and time:
`session | time | action | target[accessibleName] = value`.

**Then actually read it.** This is where understanding happens; everything before is plumbing
and everything after is verification. Typed values, clicked element names, and navigation URLs
in sequence tell you what the person was trying to accomplish in a way no aggregate can. Expect
a few hundred lines for a small org — read it all rather than sampling, because the tasks are
identifiable only from the sequence.

Group the trace into **tasks**, not sessions. One task often spans several sessions (a login
request in one, the magic-link click in another), and one session often does several unrelated
things. Deep-link URL parameters are especially informative: dates, origins, destinations,
party sizes, and search terms are usually right there in the query string.

### Phase 5 — Forensics battery

```sh
${SKILL_DIR}/scripts/forensics.sh <db_path>
```

Prints the standard evidence set: per-session overview, injected-extension noise split, non-2xx
responses by host, page errors, first/last URL per session, CDP input summary, keystroke cadence,
and click-coordinate deltas.

Two of these need explaining, because they answer questions people always ask:

**Noise split.** Steel injects a CAPTCHA-solver extension. When its context dies it can hot-loop
failed fetches to `chrome-extension://invalid/` — in one real org that was 92% of every
`RequestFailed` event. Compute error rates *after* excluding `chrome-extension://` URLs, or you
will report our bug as the customer's unreliability. Related: an extension id appearing in the
logs is Steel's unless `extensions/{org}/` is non-empty; confirm by checking whether the same id
appears in an unrelated org.

**Human takeover.** People ask whether a human was driving. Decide it on physics, not vibes:

- Programmatic typing has a near-constant inter-keystroke gap (a fixed delay plus round-trip
  jitter — e.g. 535 ms ±10 ms, identical for `@` and `.` as for letters). Human typing runs
  80–300 ms with 50–150 ms deviation and strong digraph variation.
- Programmatic clicks land on the target's exact bounding-box centre (`dx = dy = 0.0`) at
  sub-pixel coordinates. Non-zero offsets that are *constant* are computed offsets, not jitter.
- Absent `mouseMoved` events mean no cursor simulation.
- A composite key like `Control+a` sent as one `keyDown` with no modifier bitmask is synthesized;
  real keyboards emit separate events.

Watching is not takeover. Steel logs do not record live-viewer attachment, so you can rule out
human *input* with confidence but cannot prove nobody was watching. State it that way.

### Phase 6 — Classify every session

Assign exactly one outcome per session using observable evidence. `references/outcomes.md` has
the full rubric and the signatures for each class. Summary:

| Class | Signature |
|---|---|
| `never_driven` | zero CDP commands, ~2 events, final URL `about:blank` — client never attached |
| `goal_reached` | terminal success state: confirmation/thank-you page, `is_success=true`, target view loaded |
| `partial` | authenticated or reached a candidate/result state, no terminal action |
| `blocked` | wall unresolved at session end: 403 cluster on target host, challenge as final URL, captcha widget still being poked, navigation that never commits |
| `client_error` | the agent broke itself — malformed input, off-viewport coordinates, blind submits — with no wall evidence |
| `abandoned` | navigated, no interactions, no wall, stopped |

Report the rate two ways, because they answer different questions: goals reached over *driven*
sessions (how well the automation works) and over *all* sessions created (what the customer
actually paid for).

Two traps the repo already documents in `README.md` and worth re-reading there: a wall marker is
not a failure — government portals load Incapsula and reCAPTCHA assets as ordinary page assets —
and Steel session tags are not failure evidence.

### Phase 7 — Report

Use the structure in `references/report-template.md`. Lead with a one-paragraph verdict, then the
inferred tasks, the scorecard, blockers by target host, agent-quality observations, what Steel
itself cost them, and an explicit confidence-and-gaps section.

## Discipline that prevents wrong answers

These are the failure modes that actually happen. They cost real rework.

**Name the artifact before you claim.** Before asserting anything, say what would have to exist
on disk or in the warehouse if it were true, then go look. "This is their own product" implies
ownership artifacts. "They used feature X" implies X's stored state. A story that merely fits is
not evidence, and the moment you have a coherent narrative is exactly when you stop testing it.

**Check timestamp order before claiming causation.** "They read the code from their inbox" needs
the inbox access to *precede* the code entry. Sort the events before you explain them.

**Absence is evidence.** An empty storage prefix explained seven wasted logins in one
investigation. A missing session before an OTP proved the access was out-of-band. Look for the
thing that is not there.

**Reconcile two independent sources.** Warehouse count versus storage count, tags versus events.
Where they disagree, that gap is a finding, not an inconvenience.

**Separate our noise from their failures** before computing any rate. See Phase 5.

**Distinguish "not logged" from "did not happen."** Steel's CDP logging is whitelisted — in
practice only `Page.navigate`, `Input.dispatchKeyEvent`, and `Input.dispatchMouseEvent` appear.
The absence of `Runtime.evaluate` does not mean the client never used it. This limit blocks
harness identification: session logs carry no user-agent, headers, or SDK identifier, so if asked
what framework a customer used, say it is not determinable from these logs and point at Steel's
API-layer request logs instead. Do not name a framework you cannot evidence.

**Bound expensive work explicitly.** Cross-org S3 scans cost minutes each. Decide how many you
are buying, and if you end up with a single comparison, say `n=1` rather than implying a survey.

## Reference files

- `references/data-map.md` — warehouse tables, bucket layouts, log paths, event payload shapes.
  Read when you need a column or path you do not remember.
- `references/query-cookbook.md` — the query battery plus DuckDB traps that will bite you
  (reserved words, JSON operator inconsistency, a sampling clause that silently returns nothing).
  Read before writing ad-hoc SQL.
- `references/outcomes.md` — the full outcome rubric with evidence signatures per class.
- `references/report-template.md` — output structure and the privacy scrub list.
