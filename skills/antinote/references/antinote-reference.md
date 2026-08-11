# Antinote reference (full manual)

Source: <https://antinote.io/user-manual> (v1.1.7 at capture).
Captured: 2026-08-11.

Antinote publishes no agent-friendly doc (no `llms.txt`, no markdown endpoint). This file is that reference: the full user manual as clean markdown, kept here so an agent can work offline and format content correctly without round-tripping to the website.

## Contents

1. [Design intent and navigation](#design-intent-and-navigation)
2. [Keywords (the core model)](#keywords-the-core-model)
3. [List](#list)
4. [Math, conversions, and variables](#math-conversions-and-variables)
5. [Sum, Average, Count](#sum-average-count)
6. [Code](#code)
7. [Other keywords: timer, paste](#other-keywords-timer-paste)
8. [Simple markdown](#simple-markdown)
9. [URL schemes](#url-schemes)
10. [Search, find and replace](#search-find-and-replace)
11. [Copy and paste behavior](#copy-and-paste-behavior)
12. [Notes storage, backup, export](#notes-storage-backup-export)
13. [Settings index](#settings-index)

---

## Design intent and navigation

Antinote prioritizes the present moment above organization or recall. Moving around should feel like dancing in short-term memory.

- Two-finger swipe left/right goes to the previous / next note. Swiping past the latest note creates a new one. Swiping away from an empty note deletes it.
- `Cmd [` previous note, `Cmd ]` next note.
- `Cmd 1` jump to front (most recent note).
- `Cmd Shift 1` promote the current note to the front.
- `Cmd D` delete the note permanently.
- After navigating, press an arrow key to enter the note: `Down` or `Right` places the cursor at the start; `Up` or `Left` at the end.

Global hotkey: `Option A` shows/hides Antinote even when another app is focused. (On macOS 15.0 and 15.1, option-only shortcuts were disabled by Apple and re-enabled in 15.2; add Cmd or Ctrl to the modifier, or update macOS.)

Link shortening: URLs are visually shortened; the full URL lives in the note data. `Cmd Click` opens a link; `Cmd Shift Click` expands or shortens it. Copying a shortened link copies the full URL. Shortening is disabled in code notes and code blocks.

---

## Keywords (the core model)

A keyword typed on the first line of a note activates a special mode for that note. Example: typing `list` on the first line turns every later line into a list item.

Optional title beside the keyword, with a colon: `list: Today's Tasks`.

Customize keywords in Settings (change the word, allow several words to trigger the same mode, disable keywords). Type `/` as the first character of any line to see the main keywords and paste one with its number.

---

## List

Type `list` at the top to activate list features. Title it with `list: Your Title`.

- Every non-empty line becomes a checklist item.
- Type the check trigger (default `/x`) at the end of a line to check it.
- Math and conversions do not work inside lists.
- `//` at the start of a line makes it a comment (not a checkbox).
- `#`, `##`, or `###` at the start of a line makes it a heading (not a checkbox).

Setting: customize the check trigger.

---

## Math, conversions, and variables

Type `math` at the top to activate math features (or `/` then `math`). Title with `math: Your Title`. `//` at the start of a line comments it out so it is not calculated.

### Calculations

- Adding `=` to the end of a line attempts a calculation.
- Words, punctuation, and currency symbols are stripped out.
- Operators: `+ - * /`, plus `!`, `!!`, `√16`, `∛8`, `sqrt(16)`, `log(355)`, `log2(355)`, `ceil(12.256)`, `floor(12.256)`.
- Colloquial percentages: `100 + 15% = 115`, `25% of 1000 = 250`, `50% of 200 = 100`.
- Conversions are not supported inside a calculation line (e.g. `5cm to inches * 5 =` does not work).
- Supports period-as-thousands-separator with comma-as-decimal (e.g. `1.000,25`). Does not support space as thousands separator.

Settings: number of significant digits (0 to 7), separate thousands with comma.

### Currency conversion

Format: `10 USD to JPY = 1,492.84 JPY`. Rates update daily.

- Using your currency symbol without a code assumes your primary currency: `$10 to JPY`.
- With no target, converts primary to secondary: `$10 = 14.00 CAD`.
- Supported currency codes include major fiat (USD, EUR, GBP, JPY, CAD, AUD, CHF, CNY, INR, etc.) and many crypto and regional codes (BTC, ETH, SOL, ADA, DOGE, USDT, BNB, AAVE, ALGO, ATOM, AVAX, DOT, MATIC, XRP, and dozens more).
- Conversions inside a calculation line are not supported (e.g. `$10 USD to CAD + 5 =`).

Settings: update currencies daily, custom rates (e.g. `NTD:30.23`), primary currency symbol, primary currency, secondary currency.

### Measurement conversion

Format: `10" to cm = 25.40 cm`. Conversions inside a calculation line are not supported.

- Distance: m, meter/metre (+s), cm, km, in, inch (+es), `"` / `″`, ft, foot/feet, `'` / `′`, mile/miles/mi, yard/yd.
- Area: sqm / m², sqcm / cm², sqmm / mm², ha / hectare (+s), sqkm / km², sqft / ft², sqin / in², sqyd / yd², acre (+s), are (+s), section, township, plus regional units (dunam, tsubo/pyeong/ping, bigha, cuerda, rood, perch).
- Volume: liter/L/litre (+s), milliliter/mL, cubicMeter/m³, cubicCentimeter/cm³/cc, cubicMillimeter/mm³, gallon/gal, quart/qt, pint/pt, cup, fluidOunce/fl oz, tablespoon/tbsp, teaspoon/tsp, cubicInch/in³, cubicFoot/ft³, cubicYard/yd³, plus imperial/UK variants (ukGallon, ukQuart, ukPint, ukCup, ukFluidOunce, ukTablespoon, ukTeaspoon).
- Mass: kilogram/kg, gram/g, milligram/mg, microgram/µg/ug/mcg, metric ton/t/tonne, pound/lb, ounce/oz, stone/st, ton/short ton/us ton, long ton/uk ton/imperial ton.
- Temperature: celsius/°C/C/centigrade/degrees Celsius, kelvin/K/kelvins, fahrenheit/°F/F/degrees Fahrenheit.

### Variables

Assign a value or calculation to a variable and reuse it:

```
number of guests : 9
number of guests + 1 = 10
```

- Variable names can contain spaces.
- Updating a value instantly updates everything that uses it.
- Typing 3+ matching letters shows autocomplete; Tab selects (first option if many; a number key picks by index).
- A variable that holds a conversion result stores only the number, not the unit or currency. Reuse it by manually adding the unit.

---

## Sum, Average, Count

- `sum` at the top sums every number in the note. Non-numbers, punctuation, and symbols are stripped.
- `avg` averages every number in the note.
- `count` counts items: every non-empty line after the first. Also offers a Reading Ease / Grade Level estimate (syllable formulas vary by app, so scores differ across tools).
- For all three, `//` at the start of a line comments it out so it is excluded.
- Fractions are not supported and give wrong answers (e.g. `1 1/4 eggs`).

---

## Code

Type `code` at the top. Add a language after a colon for highlighting: `code: py`. With no language, Antinote uses the default from Settings > Misc. Choose the highlighting theme in Settings > Misc.

- With nothing selected, `Cmd C` inside a code block copies the block contents.
- Inside code notes, indent stripping and all hyperlink features are disabled.

---

## Other keywords: timer, paste

Timer (unlike other keywords, timer commands work at the start of any new line):

- `timer` starts a stopwatch.
- `timer 3.5` or `timer 3:30` starts a countdown of 3.5 minutes.
- `timer 5: Do laundry` titles a countdown.
- `timer 5 1` starts a pomodoro with 5 minutes work and 1 minute rest.
- `timer pomo` starts a standard 25/5 pomodoro.
- `timer p` pause/resume, `timer r` restart, `timer s` or `timer 0` stop.
- Click the timer to pause; double-click to stop. `Esc` stops a running timer.

Paste (AutoPaste mode):

- Type `paste` and press enter. Each clipboard copy is pasted into the note as plain text, separated by a newline by default.
- Change the delimiter: `paste(, )` or `paste( | )`.
- `Esc`, or type `paste` again, or click the blinking icon to turn it off.

---

## Simple markdown

Antinote is not a markdown editor; these create basic emphasis and divisions:

- `#`, `##`, `###` headings.
- `**bold**`, `*italic*`, `~~strikethrough~~`, `__underline__`.
- `//` comments a line out (drops it from checklists and calculations).
- `Cmd /` toggles a comment on the current or selected lines.

Note: markdown task checkboxes (`- [ ]`) are not rendered. Use the `list` keyword for checklists.

---

## URL schemes

Antinote supports URL schemes to control it from other apps. Percent-encode parameter values.

| Action | Scheme |
|---|---|
| Open Antinote | `antinote://` |
| Create a note | `antinote://x-callback-url/createNote?content=My%20Note` |
| Append to current note | `antinote://x-callback-url/appendToCurrent?content=My%20Note` |
| Overwrite current note | `antinote://x-callback-url/overwriteCurrent?content=My%20Note` |
| Promote and open a note | `antinote://x-callback-url/promoteAndOpen?noteId=123` |
| Toggle pinned status | `antinote://x-callback-url/togglePin` |
| Trigger global hotkey | `antinote://x-callback-url/hotkey` |
| Search notes | `antinote://x-callback-url/search?searchTerm=My%20Search%20Term&x-success=your-callback-url` |
| Reload DB (advanced) | `antinote://x-callback-url/reloadDB` |

- `noteId` is found in the SQLite DB or via the search endpoint.
- Search sends serialized JSON to the `x-success` callback: `[{"id": UUID, "content": String, "lastModified": String}]`.
- `reloadDB` is for scripts that edit the SQLite DB directly and want changes to show in Antinote.

Custom export (Settings > Export) can target any URL-schemable app using `{CONTENT}`, `{TITLE}`, `{DATE}` placeholders. Schemes that put content in the path (not a query parameter) replace `&` with `+` and `%` with ` percent`.

Sample custom-export URLs:

- Obsidian append: `obsidian://new?vault=Main&name=Title&append=true&silent=true&content={CONTENT}`
- Notebooks: `notebooks://addnote/{CONTENT}&title={TITLE}`
- Shortcuts: `shortcuts://run-shortcut?name=sendToChatGPT&input=text&text={CONTENT}`

---

## Search, find and replace

Search (Antinote is meant for temporary notes, so search stays barebones):

- `Cmd F` to search. With nothing entered, all notes show; a term filters to notes containing it.
- `Up` / `Down` navigate results, `Enter` promotes the selected result to the front, `Esc` closes.

Find and replace (`Cmd Shift F`):

- Modes: Contains, Matches Word, Starts With, Ends With, Regex. The `Aa` icon toggles case sensitivity.
- In the find field: `Enter` next, `Shift Enter` previous, `Tab` opens replace.
- In the replace field: `Enter` replace, `Shift Enter` replace all, `Esc` closes.
- Opening Find and Replace expands all links.

---

## Copy and paste behavior

Copy (only useful text reaches the clipboard):

- A keyword at the top of the note is not copied (an optional title is). In lists, the check trigger symbols are not copied. Shortened links are always expanded when copied. Click a math answer, sum, or average to copy it.
- `Cmd C` with nothing selected copies the whole note. With the cursor in a code block, copies the block. With the cursor in backticks, copies the text between them.

Settings: skip keywords when copying, skip checklist triggers when copying.

Paste (pasted content should never need manual adjusting):

- Formatting, bullets, numbered lists, and leading/trailing spaces per line are stripped. Markdown and empty lines can optionally be stripped.
- `Cmd V` pastes and strips; `Cmd Shift V` pastes as-is.

Settings: strip leading spaces, strip list numbers, strip bullets, strip markdown, strip empty lines (each on/off).

---

## Notes storage, backup, export

- Notes are stored locally in a SQLite DB at `~/Library/Containers/Antinote/Data/Documents/notes.sqlite3`. They are never sent to a server.
- Auto-backup: Antinote backs up the whole note DB on a schedule and keeps the most recent N (both configurable in Settings > Notes). Backups live next to `notes.sqlite3`. To restore: quit Antinote, rename a backup to `notes.sqlite3`, restart.
- Expiring notes: notes unmodified for a set time auto-delete (Today / 1 Week / 1 Month / 1 Year / Never).
- Export: one-click quick export (default `.txt`, destination configurable: Plain Text, Obsidian, Bear, Apple Notes). Also export to Markdown, or send to Obsidian/Bear/Apple Notes via URL schemes or Shortcuts. Export all notes as a zip of `.txt` files. `Cmd S` quick-exports.

Notes management settings: create a new note on launch, delete all notes unmodified since a date, start a new note after the window has been closed for a duration, show note count in the bottom bar.

Other integrations: Raycast store and Alfred workflow (create, search, pin). Homebrew cask: `brew install --cask antinote`. SetApp bundle (from May 2025).

---

## Settings index

- Notes: backup frequency and count, backup folder, create-on-launch, expiring-notes window, new-note-after-close window, note count display.
- Text editing: enable macOS text replacements, paste stripping options.
- Copy: skip keywords, skip checklist triggers.
- Visuals: color theme (light and dark), paper type (Blank/Lines/dots/grid) and opacity, text size, translucent mode (macOS 15+).
- Misc: syntax highlighting theme, default code language.
- Export: quick export destination, per-app export settings, custom URL-scheme export.
- Updates: auto-check, auto-install.

Usage tracking was turned off for everyone as of v1.1.7.
