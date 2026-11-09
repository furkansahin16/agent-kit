#!/usr/bin/env bash
# Reports differences between a project's docs skeleton and the current kit templates.
# Read-only: never writes to the project, compares section headings only.
# Usage: ./check.sh [project-dir]   (default: current directory)
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="${1:-$PWD}"
kit_ver="$(tr -d '[:space:]' < "$KIT/VERSION")"
ver_file="$PROJECT/docs/.kit-version"
[ -f "$ver_file" ] || { echo "[check]   $PROJECT has no docs/.kit-version; it was not initialised with the kit."; exit 1; }

proj_ver="$(head -n1 "$ver_file" | tr -d '[:space:]')"
lang="$(sed -n 's/^[[:space:]]*lang:[[:space:]]*\([A-Za-z]*\).*/\1/p' "$ver_file" | head -n1)"; lang="${lang:-en}"
echo "[check]   project skeleton v$proj_ver ($lang), kit v$kit_ver"

headings() { grep -E '^#{2,6}[[:space:]]+[^[:space:]]' "$1" | sed 's/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]' || true; }
issues=0
for t in "$KIT/templates/project/$lang/docs/"*.md; do
  n="$(basename "$t")"; target="$PROJECT/docs/$n"
  if [ ! -f "$target" ]; then echo "[diff]    docs/$n: file missing in project"; issues=$((issues+1)); continue; fi
  have="$(headings "$target")"
  while IFS= read -r h; do
    [ -z "$h" ] && continue
    printf '%s\n' "$have" | grep -qxF -- "$h" || { echo "[diff]    docs/$n: missing section '$h'"; issues=$((issues+1)); }
  done < <(headings "$t")
done
if [ ! -f "$PROJECT/AGENTS.md" ]; then echo "[diff]    AGENTS.md: missing"; issues=$((issues+1))
else
  have="$(headings "$PROJECT/AGENTS.md")"
  for h in '## read first' '## working style'; do
    printf '%s\n' "$have" | grep -qxF -- "$h" || { echo "[diff]    AGENTS.md: missing section '$h'"; issues=$((issues+1)); }
  done
  for d in DESIGN DECISIONS ROADMAP QUESTIONS DISCOVERY; do
    grep -q "docs/$d\.md" "$PROJECT/AGENTS.md" || { echo "[diff]    AGENTS.md: does not mention docs/$d.md"; issues=$((issues+1)); }
  done
fi
[ -f "$PROJECT/CLAUDE.md" ] || { echo "[diff]    CLAUDE.md: missing (should contain @AGENTS.md)"; issues=$((issues+1)); }

if [ "$proj_ver" != "$kit_ver" ] && git -C "$KIT" rev-parse -q --verify "refs/tags/v$proj_ver" >/dev/null 2>&1; then
  echo "[kit]     template changes since v$proj_ver:"
  git -C "$KIT" diff --stat "v$proj_ver" HEAD -- templates/project skills/project-docs | sed 's/^/          /'
fi
if [ "$issues" = 0 ]; then echo "[check]   skeleton structure matches the kit."
else echo "[check]   $issues difference(s). Nothing was changed; apply what you want by hand."; fi
