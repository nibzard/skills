# Report template

Deliver the report in conversation. Only write a file if asked, and scrub it first (see below).

## Structure

```markdown
## Verdict
One paragraph: who they are, how mature the account is, what they were trying to do, and how it
went. Lead with the conclusion, not the method.

## What they were doing
A table of inferred tasks with the evidence for each. One row per task, not per session.
| # | Task | Evidence |

## Outcome
Goals reached over driven sessions AND over all sessions created. Then the class breakdown
(never_driven / goal_reached / partial / blocked / client_error / abandoned).
Explicitly contrast this with what Steel's own status fields report for the same period.

## By target host
| Host | Driven | Won | What stopped it |
This is usually where the story is. One site at 0% is more actionable than any average.

## Agent-quality observations
Failures the customer caused themselves, with the specific evidence and, where you can, the root
cause. These are the cheapest things for them to fix.

## What Steel cost them
Feature gaps they hit without knowing (unused profiles causing repeated cold logins), defences we
do not handle, and any of our own bugs visible in their logs. Separate this from their failures.

## Confidence and gaps
What you could not determine and why. Sampling, coverage ceilings, n= for any cross-org
comparison, and claims that are consistent-but-unproven.
```

## Rules that keep the report honest

**Lead with the verdict.** The person asking wants the conclusion, not a tour of your queries.

**Attach evidence to every claim.** A session id prefix, a URL fragment, a count, a timestamp.
Claims without evidence are the ones that turn out wrong.

**Separate "proven" from "inferred" from "consistent-but-unproven"** in the wording, and put the
weakest claims in the gaps section rather than the verdict. If an identification rests on a length
match rather than a reconstruction, say so.

**Never state a harness or framework identity.** Session logs carry no user-agent, headers, or SDK
identifier. You can describe the behavioural profile — typing cadence, click mechanics,
accessibility-tree targeting, whether Steel features were used — but naming a product is a guess.
Point at Steel's API-layer request logs as the place that would answer it.

**Report what Steel's own fields claimed** alongside the truth. That contrast is often the single
most useful line in the report for a product audience.

**Do not moralise about what the customer automated.** Describe what happened and what it means
commercially and technically.

## Privacy scrub for any file you write

The conversation may contain identifiers. Files under `analysis/` or anywhere shareable must not.
Before writing, remove or aggregate:

- customer, organization, and member names
- email addresses and usernames
- raw organization ids, session ids, project ids, user ids
- full URLs and query parameters (keep the host, drop the path and query)
- credentials, tokens, magic-link tokens, one-time codes
- order numbers, booking references, payment identifiers
- third-party personal names appearing in accessible names — element labels routinely contain
  the names of real people
- raw manifests or raw log excerpts

Keep hosts, counts, rates, durations, outcome classes, and timings — those carry the analysis. If
a finding cannot survive the scrub, keep it in conversation and note in the file that the detail
is available in the investigation thread.

Follow the repo `CLAUDE.md` and `AGENTS.md`; when the two conflict with convenience, they win.
