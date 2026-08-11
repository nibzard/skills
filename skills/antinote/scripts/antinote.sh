#!/usr/bin/env bash
# ABOUTME: Push content to Antinote (a macOS scratchpad app) through antinote:// URL schemes.
# ABOUTME: Handles percent-encoding so multiline content and special characters survive the URL.
set -euo pipefail

APP="/Applications/Antinote.app"
BASE="antinote://x-callback-url"

die() { echo "antinote: $*" >&2; exit 1; }

# Percent-encode stdin for a URL query value. safe="" encodes everything that is
# not unreserved, including newlines (%0A) and spaces (%20), as Antinote requires.
encode() {
  python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=""))'
}

ensure_env() {
  command -v open >/dev/null 2>&1 || die "'open' not found. Antinote is macOS only."
  command -v python3 >/dev/null 2>&1 || die "python3 is required for percent-encoding."
  [[ -d "$APP" ]] || die "Antinote not found at $APP. Install with: brew install --cask antinote"
}

# Read content from, in order: --file FILE, piped stdin, or trailing args.
read_content() {
  if [[ "${1:-}" == "--file" ]]; then
    [[ -r "${2:-}" ]] || die "cannot read file: ${2:-<none>}"
    cat "$2"
  elif [[ ! -t 0 ]]; then
    cat
  elif [[ $# -gt 0 ]]; then
    printf '%s\n' "$*"
  else
    die "no content. Pipe text, pass args, or use --file FILE."
  fi
}

send_content() {
  local scheme="$1"; shift
  local content; content="$(read_content "$@")"
  [[ -n "$content" ]] || die "refusing to send empty content."
  local enc; enc="$(printf '%s' "$content" | encode)"
  open "$BASE/$scheme?content=$enc"
  echo "antinote: $scheme done."
}

usage() {
  cat <<'EOF'
antinote.sh — send content to Antinote via URL schemes

usage:
  antinote.sh create    [text | --file FILE]   create a new note (default action)
  antinote.sh append    [text | --file FILE]   append to the current note
  antinote.sh overwrite [text | --file FILE]   replace the current note
  antinote.sh promote   NOTEID                 promote + open a note by id
  antinote.sh search    TERM                   open Antinote's search
  antinote.sh pin                               toggle pinned status
  antinote.sh hotkey                            trigger the global hotkey
  antinote.sh reload                            reload the DB (after direct sqlite edits)

content is read from --file FILE, piped stdin, or trailing args (checked in that order).
If the first argument is not a known action, it is treated as `create` with all args as content.

examples:
  antinote.sh "remember the milk"
  echo "## Today" | antinote.sh create
  antinote.sh append --file note.md
EOF
}

main() {
  local action="${1:-create}"
  case "$action" in
    -h|--help|help) usage; exit 0 ;;
    create)    ensure_env; shift; send_content createNote "$@" ;;
    append)    ensure_env; shift; send_content appendToCurrent "$@" ;;
    overwrite) ensure_env; shift; send_content overwriteCurrent "$@" ;;
    promote)
      ensure_env
      [[ -n "${2:-}" ]] || die "promote needs a noteId."
      open "$BASE/promoteAndOpen?noteId=$(printf '%s' "$2" | encode)"
      ;;
    search)
      ensure_env
      [[ -n "${2:-}" ]] || die "search needs a term."
      open "$BASE/search?searchTerm=$(printf '%s' "$2" | encode)"
      ;;
    pin)    ensure_env; open "$BASE/togglePin" ;;
    hotkey) ensure_env; open "$BASE/hotkey" ;;
    reload) ensure_env; open "$BASE/reloadDB" ;;
    *)
      # Unknown first token: treat the whole invocation as `create` with content.
      ensure_env; send_content createNote "$@" ;;
  esac
}

main "$@"
