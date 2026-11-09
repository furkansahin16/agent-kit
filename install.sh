#!/usr/bin/env bash
# Installs the agent-kit into Claude Code and Codex CLI (global layer). POSIX counterpart of install.ps1.
#   skills  -> one symlink per skill in ~/.claude/skills and ~/.agents/skills
#   agents  -> copied into ~/.claude/agents (manifest-tracked; local edits are never overwritten without --force)
#   instructions -> managed block in ~/.codex/AGENTS.md, @import block in ~/.claude/CLAUDE.md
#   MCP     -> codegraph registered via the CLIs only when missing
# Usage: ./install.sh [--dry-run] [--skip-mcp] [--force] [--target-home DIR]
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HOME="${HOME}"; DRY=0; SKIP_MCP=0; FORCE=0; WARNINGS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run|-n) DRY=1 ;;
    --skip-mcp) SKIP_MCP=1 ;;
    --force) FORCE=1 ;;
    --target-home) TARGET_HOME="${2:?--target-home needs a value}"; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

VERSION="$(tr -d '[:space:]' < "$KIT/VERSION")"
BEGIN='<!-- agent-kit:begin -->'; END='<!-- agent-kit:end -->'
say()  { printf '%-9s %s\n' "[$1]" "$2"; }
warn() { WARNINGS=$((WARNINGS+1)); say warn "$1"; }
run()  { if [ "$DRY" = 1 ]; then say would "$*"; else "$@"; fi; }
sha()  { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }
write_file() { if [ "$DRY" = 1 ]; then say would "write $1"; else mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; fi; }
backup() { local b="$1.agent-kit.bak-$(date +%Y%m%d%H%M%S)"; run cp "$1" "$b"; say backup "$b"; }

case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) warn "Windows detected: prefer install.ps1 (junctions need no admin rights; ln -s may copy instead of linking)";; esac
say kit "agent-kit v$VERSION at $KIT"; say target "$TARGET_HOME"

# --- 1. Skills: one symlink per skill ---
for d in "$KIT"/skills/*/; do
  name="$(basename "$d")"; src="${d%/}"
  for root in "$TARGET_HOME/.claude/skills" "$TARGET_HOME/.agents/skills"; do
    link="$root/$name"
    if [ -L "$link" ]; then
      if [ "$(readlink "$link")" = "$src" ]; then say ok "skill $name -> $link"; else warn "$link is a link to somewhere else; left alone"; fi
    elif [ -e "$link" ]; then warn "$link exists as a real directory; left alone"
    else run mkdir -p "$root"; run ln -s "$src" "$link"; say new "skill $name -> $link"
    fi
  done
done

# --- 2. Agents: copy, tracked in a manifest ---
AGENT_DIR="$TARGET_HOME/.claude/agents"; MANIFEST="$AGENT_DIR/.agent-kit-manifest"
manifest_get() { [ -f "$MANIFEST" ] && grep -E "^$1 " "$MANIFEST" | cut -d' ' -f2 || true; }
manifest_set() {
  [ "$DRY" = 1 ] && return 0
  mkdir -p "$AGENT_DIR"; local tmp; tmp="$(mktemp)"
  { [ -f "$MANIFEST" ] && grep -v -E "^$1 " "$MANIFEST" || true; echo "$1 $2"; } > "$tmp"; mv "$tmp" "$MANIFEST"
}
shopt -s nullglob
kit_agents=("$KIT"/agents/*.md)
for f in "${kit_agents[@]}"; do
  n="$(basename "$f")"; dst="$AGENT_DIR/$n"; new="$(sha "$f")"; action=""
  if [ ! -e "$dst" ]; then action=new
  else
    cur="$(sha "$dst")"
    if [ "$cur" = "$new" ]; then say ok "agent ${n%.md}"; [ "$(manifest_get "$n")" = "$new" ] || manifest_set "$n" "$new"; continue
    elif [ "$(manifest_get "$n")" = "$cur" ] || [ "$FORCE" = 1 ]; then action=update
    else warn "agent ${n%.md}: $dst differs and is not managed by the kit (or was edited); skipped (use --force)"; continue
    fi
  fi
  run mkdir -p "$AGENT_DIR"; run cp "$f" "$dst"; manifest_set "$n" "$new"; say "$action" "agent ${n%.md}"
done
if [ -f "$MANIFEST" ]; then
  while read -r n _; do [ -e "$KIT/agents/$n" ] || say note "agent $n was removed from the kit; its installed copy is left in place"; done < "$MANIFEST"
fi

# --- 3. Global instructions: managed blocks ---
set_block() {
  local file="$1" content="$2" label="$3" block raw="" trimmed
  block="$BEGIN"$'\n'"$content"$'\n'"$END"$'\n'
  if [ -f "$file" ]; then raw="$(cat "$file"; printf x)"; raw="${raw%x}"; fi
  trimmed="$(printf '%s' "$raw" | tr -d '[:space:]')"
  if [ -z "$trimmed" ]; then write_file "$file" "$block"; say new "$label -> $file"; return; fi
  if [[ "$raw" == *"$BEGIN"* && "$raw" == *"$END"* ]]; then
    local prefix="${raw%%"$BEGIN"*}" rest="${raw#*"$END"}"; rest="${rest#$'\n'}"
    local new="$prefix$block$rest"
    if [ "$new" = "$raw" ]; then say ok "$label in $file"; return; fi
    backup "$file"; write_file "$file" "$new"; say update "$label in $file"; return
  fi
  backup "$file"; write_file "$file" "$(printf '%s' "$raw" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"$'\n\n'"$block"; say update "$label appended to $file"
}
instr="$KIT/instructions/AGENTS.md"
set_block "$TARGET_HOME/.codex/AGENTS.md" "$(cat "$instr")" "global instructions (copy)"
case "$instr" in "$TARGET_HOME"/*) import_path="~${instr#"$TARGET_HOME"}";; *) import_path="$instr";; esac
set_block "$TARGET_HOME/.claude/CLAUDE.md" "@$import_path" "global instructions (@import)"

# --- 4. CodeGraph MCP (only when missing) ---
if [ "$SKIP_MCP" = 1 ]; then say skip "MCP registration (--skip-mcp)"
elif ! command -v codegraph >/dev/null 2>&1; then warn "codegraph CLI not found on PATH; MCP registration skipped (install it, then re-run)"
else
  for tool in claude codex; do
    if ! command -v "$tool" >/dev/null 2>&1; then say skip "$tool not installed"; continue; fi
    if "$tool" mcp get codegraph >/dev/null 2>&1; then say ok "$tool already has the codegraph MCP server"; continue; fi
    if [ "$tool" = claude ]; then run claude mcp add --scope user codegraph -- codegraph serve --mcp
    else run codex mcp add codegraph -- codegraph serve --mcp; fi
    [ "$DRY" = 1 ] || say new "$tool MCP server codegraph"
  done
fi
say done "agent-kit v$VERSION, $WARNINGS warning(s). The .codegraph index is not created here: run 'codegraph init -i' per repository when you want it."
