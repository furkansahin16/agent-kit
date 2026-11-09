# agent-kit

One git repository that sets up skills, agents and global instructions for Claude Code and Codex CLI, and carries a docs/AGENTS.md skeleton for new projects. Clone it on any machine, run `install`, run `update` later.

## Layout

```
skills/                    shared skills (one folder each, SKILL.md)
  project-docs/            working rules for the docs/ set
  project-init/            sets up docs/ and AGENTS.md in a repo (asks questions)
  codegraph-aware-exploration/
  dotnet-lts-upgrade/
agents/                    Claude Code agents, single source (name, description, tools, body)
instructions/AGENTS.md     global instructions (CodeGraph guide)
templates/project/         project skeleton: AGENTS.md.tmpl, CLAUDE.md, en/docs, tr/docs
install.ps1 | install.sh   global install
update.ps1  | update.sh    git pull + install + change summary
check.ps1   | check.sh     report skeleton changes for a project (read-only)
VERSION                    kit version (git tags: vX.Y.Z)
```

## Install

```powershell
git clone <repo-url> ~/agent-kit
~/agent-kit/install.ps1 -WhatIf     # dry run first
~/agent-kit/install.ps1
```

```sh
git clone <repo-url> ~/agent-kit
~/agent-kit/install.sh --dry-run
~/agent-kit/install.sh
```

Use the `.ps1` scripts on Windows (PowerShell 7). The `.sh` scripts are for Linux and macOS.

What install does (idempotent, safe to re-run):

| Part | Claude Code | Codex CLI |
|---|---|---|
| Skills | junction/symlink per skill in `~/.claude/skills/<name>` | junction/symlink per skill in `~/.agents/skills/<name>` |
| Agents | copied to `~/.claude/agents/` | not installed (see below) |
| Global instructions | `~/.claude/CLAUDE.md` gets a block that `@`-imports `instructions/AGENTS.md` | `~/.codex/AGENTS.md` gets a managed block with a copy |
| CodeGraph MCP | `claude mcp add --scope user` if missing | `codex mcp add` if missing |

Rules install follows:
- Existing real folders or links that point elsewhere are never touched; a warning is printed.
- `~/.claude/skills/synced` (managed by claude.ai) is never touched.
- Existing `CLAUDE.md` / `AGENTS.md` content is kept: the kit only owns the block between `<!-- agent-kit:begin -->` and `<!-- agent-kit:end -->`, and a timestamped `.agent-kit.bak-*` copy is made before any change.
- Agents that were edited locally are skipped with a warning unless `-Force` / `--force`.
- Options: `-SkipMcp` / `--skip-mcp`, `-TargetHome` / `--target-home` (install into another directory, mainly for testing).
- Remove a skill link with `cmd /c rmdir <link>` (Windows) or `rm <link>` (never `Remove-Item -Recurse`, which can delete the target's content).

The CodeGraph index (`.codegraph/`) is never created by the kit. Run `codegraph init -i` in a repository when you want it.

## Update

```powershell
~/agent-kit/update.ps1 -WhatIf   # shows incoming commits, changes nothing
~/agent-kit/update.ps1
```

`update` = `git pull --ff-only` + install again + a summary (old to new version and commits). Skills update at once through the links; agents are re-copied.

## Start a project

In a repository, ask Claude Code or Codex to run the `project-init` skill. It asks for the docs language (English default, Turkish available), project name, stack, commands and hard rules, then creates `docs/` and `AGENTS.md` (plus `CLAUDE.md` containing `@AGENTS.md`) without overwriting anything. It writes `docs/.kit-version`.

The skeleton is a copy, not a link, so it works without the kit. Later:

```powershell
~/agent-kit/check.ps1 -Project <path>
```

lists missing sections and files compared with the current templates. It never writes anything.

## Things worth knowing

- **Agents are Claude Code only for now.** Codex custom agents are TOML and cannot enforce a read-only sandbox, so no `.toml` is generated yet.
- **Read-only agents** (`explorer`, `reviewer`, ...) have `Edit`, `Write` and `NotebookEdit` removed and an explicit `tools` list that includes `mcp__codegraph__*`. They keep `Bash`, which can still write files; the roles are instructed not to.
- **Command-level Bash rules do not exist in agent frontmatter.** `Bash(git *)` style patterns only work in `settings.json` (`permissions.allow` / `permissions.deny`). Agents that need Bash get the whole tool and follow the normal permission prompts.
- Claude Code reads a repository's `AGENTS.md` only when no `CLAUDE.md` exists there. Projects from `project-init` have both, with `CLAUDE.md` importing `AGENTS.md`.
- MCP servers, permissions, models and plugin settings are not shared between the tools.
- Packaging as a Claude plugin is out of scope for now; the layout does not prevent it later.
