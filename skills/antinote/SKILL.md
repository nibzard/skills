---
name: antinote
description: Send notes, task lists, summaries, and snippets to Antinote, a local macOS scratchpad app, through antinote:// URL schemes, and format content to use Antinote's keyword features (lists, math, code, timers). Use whenever the user wants to add, append, overwrite, or push any text to Antinote, mentions Antinote or their scratchpad, or wants quick capture to a local temporary note. Trigger even when the user does not name Antinote but asks to jot something to their local note app. macOS only; requires Antinote installed.
---

# Antinote

Push content to Antinote, a fast local macOS scratchpad for temporary notes and quick calculations. Antinote is built for short-lived notes, not a permanent store, so reach for it when the user wants something to glance at and discard: a task list for the day, a summary to act on now, a snippet to paste, a quick calculation.

## When to use

Use it whenever the user wants text in their local Antinote app. Triggering phrases and situations:

- "send / add / push / put this in Antinote" or "in my scratchpad"
- "jot this down" or "make a quick note" when Antinote is their note app
- They want a temporary note they will throw away, not a filed document
- You are formatting a task list, quick math, or code snippet to look right in Antinote

Do not use it for a vault, Obsidian, Notion, Apple Notes, or any other note store. Antinote is the ephemeral scratchpad; those are for keeping. If unsure which app the user means, ask.

## Prerequisites

- macOS. Antinote is Mac-only and has no CLI; we drive it through `antinote://` URL schemes and the `open` command.
- Antinote installed. Verify: `ls -d /Applications/Antinote.app`
- If missing: `brew install --cask antinote`

Append, overwrite, and pin act on the note that is currently open, so Antinote should be running for those. Create works whether it is running or not.

## Preferred: the helper script

The bundled script handles percent-encoding (required for multiline content) and the macOS and install guards. Path, relative to a standard skill install:

```bash
S=~/.claude/skills/antinote/scripts/antinote.sh

# Create a new note from a string (also the default action)
$S create "Ship MCP v2 this week"
$S "Ship MCP v2 this week"          # action optional for create

# From stdin (good for long or generated content)
echo -e "## Today\n- one\n- two" | $S create

# From a file
$S create --file tasks.md

# Append to whatever note is open right now
$S append "one more thing"

# Replace the current note
$S overwrite "fresh content"

# Non-content actions
$S pin                  # toggle pinned status
$S hotkey               # trigger the global hotkey
$S reload               # reload after direct sqlite edits
$S promote <noteId>     # promote + open a note by id
$S search "billing"     # open Antinote's search
```

Run `antinote.sh` with no args (or `-h`) for full usage.

## How it works: the URL schemes

If you ever need to do it by hand, the schemes are:

| Action | URL |
|---|---|
| Create note | `antinote://x-callback-url/createNote?content=<encoded>` |
| Append to current | `antinote://x-callback-url/appendToCurrent?content=<encoded>` |
| Overwrite current | `antinote://x-callback-url/overwriteCurrent?content=<encoded>` |
| Promote + open | `antinote://x-callback-url/promoteAndOpen?noteId=<id>` |
| Toggle pin | `antinote://x-callback-url/togglePin` |
| Trigger hotkey | `antinote://x-callback-url/hotkey` |
| Reload DB | `antinote://x-callback-url/reloadDB` |
| Search | `antinote://x-callback-url/search?searchTerm=<encoded>&x-success=<callback>` |

Percent-encode the value of every parameter (newlines become `%0A`). By hand:

```bash
enc=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=""))' <<< "$text")
open "antinote://x-callback-url/createNote?content=$enc"
```

There is no title parameter. Antinote shows the first line as the preview, so lead the content with a heading or a clear first line.

Search returns results to an `x-success` callback URL as JSON, which is awkward from a plain shell, so the script just opens Antinote's search UI. For programmatic search, Raycast and Alfred both have Antinote extensions.

## Format content for Antinote (important)

Antinote is not a full markdown editor. To make notes look right:

**Supported markdown:** `#` `##` `###` headings, `**bold**`, `*italic*`, `~~strikethrough~~`, `__underline__`, and `` `backticks` ``. Start a line with `//` to comment it out (a comment line drops out of checklists and calculations).

**No task checkboxes.** Antinote does not render `- [ ]`. For a checklist, use the `list` keyword below instead of markdown task syntax.

**Keywords give a note special powers.** Put the keyword on the first line. Add an optional title with a colon, e.g. `list: Today's tasks`.

- `list` turns every non-empty line into a checklist item. Check an item by typing the check trigger (default `/x`) at the end of the line. Start a line with `#` / `##` / `###` or `//` to keep it out of the checklist.
- `math` evaluates lines ending in `=`. Supports `+ - * /`, colloquial percentages (`100 + 15% =`, `50% of 200 =`), `sqrt(16)`, `log(355)`, `ceil()`, `floor()`, variables, currency conversion, and unit conversion. See the reference for the full operator, currency, and unit lists.
- `sum` / `avg` / `count` aggregate every number in the note.
- `code` (or `code: py`) for a syntax-highlighted snippet. `//` comments still work.
- `timer 5: Laundry` starts a 5-minute countdown; `timer pomo` starts a pomodoro; `timer p` pauses.
- `paste` enters auto-paste mode (each clipboard copy appends to the note).

**Keep it short.** Antinote is for temporary notes. The app's own author advises against writing very long notes in it. If the content is large, summarize and link out, or send it to a store meant for keeping.

For the complete keyword behavior, every supported currency and unit, variables, and all settings, read `references/antinote-reference.md`.
