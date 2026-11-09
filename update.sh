#!/usr/bin/env bash
# Updates the agent-kit: git pull, summary of what changed, then install again.
# Usage: ./update.sh [--dry-run] [--skip-mcp] [--force] [--target-home DIR]
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=0; for a in "$@"; do [ "$a" = "--dry-run" ] || [ "$a" = "-n" ] && DRY=1; done

old_ver="$(tr -d '[:space:]' < "$KIT/VERSION")"; old="$(git -C "$KIT" rev-parse HEAD)"
if [ -n "$(git -C "$KIT" status --porcelain)" ]; then echo "Uncommitted changes in $KIT. Commit or stash them first." >&2; exit 1; fi

if [ -z "$(git -C "$KIT" remote)" ]; then
  echo "[note]    no git remote configured; skipping pull and re-running install only"
elif [ "$DRY" = 1 ]; then
  git -C "$KIT" fetch --quiet
  if up="$(git -C "$KIT" rev-parse --abbrev-ref '@{u}' 2>/dev/null)"; then
    echo "[would]   git pull --ff-only ($up). Incoming commits:"
    inc="$(git -C "$KIT" log --oneline --no-decorate "HEAD..$up")"; if [ -n "$inc" ]; then echo "$inc" | sed 's/^/          /'; else echo "          (none, already up to date)"; fi
  else echo "[note]    no upstream branch configured; nothing to pull"; fi
else
  git -C "$KIT" pull --ff-only
fi

new="$(git -C "$KIT" rev-parse HEAD)"; new_ver="$(tr -d '[:space:]' < "$KIT/VERSION")"
if [ "$old" = "$new" ]; then echo "[kit]     already at v$new_ver (${new:0:7})"
else
  echo "[kit]     v$old_ver -> v$new_ver  (${old:0:7} -> ${new:0:7})"
  git -C "$KIT" log --oneline --no-decorate "$old..$new" | sed 's/^/          /'
  echo "[note]    project skeletons are copies; run check.sh <project> to see skeleton changes"
fi
exec "$KIT/install.sh" "$@"
