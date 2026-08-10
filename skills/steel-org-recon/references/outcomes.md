# Outcome rubric

Assign exactly one class per session from observable evidence. Never from Steel's `status` field:
every normally-terminated session reads `stopped`, so a day with ten hard failures still reports
`failed_count: 0`.

## Classes and their signatures

### `never_driven`
Zero `CDPCommand` events, roughly two events total, first and last navigation both `about:blank`,
duration near zero. A session was provisioned and no client ever attached.

This is not a site failure and not an automation failure — it is waste, and it is usually
invisible to the customer. Count it separately and always report it, because it is simultaneously
a billing fact, a churn signal, and often a bug in the customer's orchestration layer.

### `goal_reached`
A terminal success state is visible in the last events. Look for:

- a confirmation or receipt URL (`/thankyou`, `purchaseId=`, `authorizationResult=APPROVED`,
  `reservations/manage/?is_success=true`, `orderId=`)
- the authenticated destination the session was aiming at (`/dashboard`, `/feed/`, an app view
  reached after a login flow)
- the expected data view loaded with the right parameters in the URL (a search-results page whose
  query string matches the task the trace shows the agent assembling)
- a bulk action completed and then re-verified — a reload of the same list after N mutations is
  the agent checking its own work

A verification reload at the end is strong evidence. Prefer URL evidence over event counts.

### `partial`
Real progress, no terminal action. Typically: authenticated successfully, or reached a candidate
or results state, then stopped without booking, buying, submitting, or extracting. Common when a
task needs a decision the agent would not take.

Report these as their own class rather than folding them into success or failure — the difference
between "could not log in" and "logged in but never completed" points at completely different
product work.

### `blocked`
Evidence that a defence stopped it, unresolved at session end:

- a cluster of `403`s from the *target* host (not from third-party assets)
- a challenge URL as the final navigation (`checkpoint/challenge`, `challengesV2`, a vendor
  interstitial such as `/processing`)
- continued interaction with a human-verification widget until the session ends — repeated
  `drag`/`click` on "Press & Hold to confirm you are a human" is a loss even without an HTTP error
- a `Page.navigate` that never commits: no `Navigation` event and no response from the host, with
  the command result arriving tens of seconds later

Do **not** classify as blocked on wall-asset presence alone. Many legitimate sites load Incapsula,
reCAPTCHA, or DataDome assets as ordinary page assets; in one customer 78% of sessions touched a
wall marker with almost no HTTP errors. Require an unresolved end state.

### `client_error`
The automation broke itself, with no wall evidence. Signatures seen in practice:

- submit clicked before fields were filled (repeated submits with empty inputs, then a fill)
- a field value that grows past its plausible length — the append-instead-of-replace bug, usually
  caused by a synthesized `Control+a` that deleted one character instead of selecting all
- an over-long paste into a short field (an unparsed email body dropped into a 6-digit code box)
- a click dispatched at a document-relative coordinate outside the viewport, so it hit nothing
- a date or locale field retried many times in a row

These are the most useful findings to pass back to a customer, because they are cheap for them to
fix and they are invisible in any aggregate.

### `abandoned`
Navigated somewhere, no meaningful interactions, no wall evidence, stopped. Distinguish from
`never_driven` — here the client did attach and did navigate.

## Reporting the rate

Report two denominators, because they answer different questions:

- **goals reached / driven sessions** — how well the automation works
- **goals reached / all sessions created** — what the customer actually paid for

State both. The gap between them is the waste, and it is often the single most actionable number
in the report.

Then break the same data down **by target host**, because that is where the story usually is: one
site at 100% and another at 0% is far more useful than an overall average, and it tells you
whether the problem is the customer's automation or a specific defence.

## Grouping sessions into tasks

Sessions are the billing unit, not the unit of intent. One task frequently spans several sessions
(request a login link in one, open the emailed link in another) and one long session frequently
covers several unrelated tasks. Group by what the trace shows the agent pursuing — deep-link query
parameters, the sequence of hosts, and the accessible names of clicked elements — then judge
outcomes at the task level as well as the session level. A customer who completed 6 of 8 tasks
using 23 sessions is in a very different position from one who completed 6 of 23 sessions.
