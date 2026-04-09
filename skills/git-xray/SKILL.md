---
name: git-xray
description: "Run diagnostic git commands to assess a codebase's health before reading any code. Use this skill whenever the user asks you to understand a new codebase, audit a repo, assess technical debt, find risky code, check project health, figure out where to start reading, identify bus factor risks, or explore an unfamiliar repository. Also use it when the user asks 'what's going on in this repo', 'where are the problem areas', 'give me a health check', or 'what should I look at first'. If the user wants to understand a codebase at a strategic level before diving into code, this is the skill to use."
---

# Git X-Ray

Before reading a single line of code, run five diagnostic git commands to build a strategic picture of the repository. These commands reveal which files are hotspots, who built what, where bugs cluster, whether the project has momentum, and how often the team is firefighting. The whole process takes under a minute and transforms your initial exploration from random wandering into targeted investigation.

This approach is based on the insight that commit history is a behavioral record of a codebase — it tells you what actually happened, not what the architecture docs claim happened.

**Inspired by:** [Five git commands that tell you where a codebase hurts before you open a single file](https://piechowski.io/post/git-commands-before-reading-code/) by Ally Piechowski.

## The Diagnostic Sequence

Run these five commands in order. Each builds on the picture from the previous ones.

### 1. What Changes the Most (Churn Analysis)

```bash
git log --format=format: --name-only --since="1 year ago" | sort | uniq -c | sort -nr | head -20
```

This surfaces the 20 most-modified files in the past year. High-churn files often indicate areas people are afraid to touch properly — they keep getting patched rather than fixed. A 2005 Microsoft Research study found that churn-based metrics predicted defects more reliably than complexity metrics.

**Adapt the time window:** If the repo is younger than a year, drop `--since` entirely. If it's very large or very old, 1 year is a good default. Check repo age first:
```bash
git log --reverse --format='%ad' --date=short | head -1
```

### 2. Who Built This (Contributor Map)

```bash
git shortlog -sn --no-merges
```

This ranks contributors by commit count across the full history.

Then check recent activity:
```bash
git shortlog -sn --no-merges --since="6 months ago"
```

**What to look for:**
- One person at 60%+ of commits = bus factor risk
- Original top contributors absent from the recent list = institutional knowledge may have left
- Very few recent contributors on a large codebase = possible understaffing

**Caveat:** Squash-merge workflows compress multiple authors into one committer. If you see suspiciously uniform authorship, note this limitation.

### 3. Where Do Bugs Cluster (Defect Map)

```bash
git log -i -E --grep="fix|bug|broken" --name-only --format='' | sort | uniq -c | sort -nr | head -20
```

This maps files by how often they appear in bug-related commits.

**The key cross-reference:** Compare this list against the churn list from step 1. Files appearing on *both* lists are the highest-risk code in the repository — they're repeatedly patched but never properly resolved. Flag these prominently.

**Limitation:** This only works as well as the team's commit message discipline. If commit messages are vague or inconsistent, this command will undercount.

### 4. Is This Project Accelerating or Dying (Momentum)

```bash
git log --format='%ad' --date=format:'%Y-%m' | sort | uniq -c
```

This shows commit frequency by month across the project's full history.

**Patterns to identify:**
- Steady rhythm → healthy, sustained development
- Sudden drop → someone left or a reorg happened
- Declining trend → project losing momentum or entering maintenance mode
- Periodic spikes → batched release cycles or deadline-driven development

### 5. How Often Is the Team Firefighting (Stability)

```bash
git log --oneline --since="1 year ago" | grep -iE 'revert|hotfix|emergency|rollback'
```

This counts reverts, hotfixes, and emergency deployments.

**Interpretation:** Frequent entries here point to systemic issues — weak testing, inadequate staging environments, or a deployment process that makes people nervous. This is about process health, not individual blame.

## Synthesizing the Report

After running all five commands, produce a structured report. The value isn't in the raw numbers — it's in the cross-references and the story they tell together.

### Report Structure

```
# Git X-Ray: [repo name]

## Top Findings
[2-3 bullet points with the most important/actionable discoveries]

## Churn Hotspots
[Top 10 most-changed files, with notes on any that also appear in the bug list]

## Contributor Landscape
[Total contributors, bus factor assessment, recent vs historical contributors]

## Bug Clusters
[Top bug-associated files, with cross-reference to churn list]
[Files on BOTH lists get a ⚠️ flag — these are the highest-priority investigation targets]

## Project Momentum
[Trend description: accelerating, steady, declining, or irregular]
[Notable inflection points with approximate dates]

## Stability & Firefighting
[Revert/hotfix count and frequency]
[Assessment of deployment/testing health]

## Recommended Reading Order
[Based on all the above, suggest which files/areas to investigate first and why]
```

The "Recommended Reading Order" section is the payoff — it turns the diagnostics into a concrete action plan for where to start reading code.

## Edge Cases

- **Empty repo or very few commits:** State that there isn't enough history for meaningful analysis and skip to reading the code directly.
- **Monorepo:** The commands work but the output may be noisy. Consider scoping with `-- path/to/subdirectory` if the user is interested in a specific area.
- **Non-standard branching:** These commands run against the current branch's history. If the user cares about a different branch, switch or specify it.
