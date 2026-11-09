---
name: codegraph-aware-exploration
description: Use ONLY when exploring or analyzing code in a project that may have CodeGraph. Guides the agent to probe for CodeGraph, prefer codegraph_explore when available, and silently fall back to built-in tools when CodeGraph is missing or unindexed.
---

# CodeGraph-Aware Exploration

## When to use this skill

Use during codebase discovery, flow tracing, impact analysis, or any structural question where a pre-built CodeGraph index could give surgical context in fewer tool calls.

## What CodeGraph provides

- A local, pre-indexed knowledge graph of symbols, call edges, imports, and framework routes.
- MCP tool: `codegraph_explore` (preferred — one call returns source snippets + call paths + blast radius).
- CLI equivalents: `codegraph explore`, `codegraph callers`, `codegraph callees`, `codegraph impact`, `codegraph node`, `codegraph query`, `codegraph files`.

## Graceful availability probe

Before relying on CodeGraph, check availability in order:

1. `codegraph --version` or `codegraph status [path]` via bash.
2. If that fails, CodeGraph is not installed — immediately fall back to `glob`, `grep`, and `read`.
3. If CodeGraph is installed but `.codegraph/` is missing or `status` reports no index, report it as a finding and fall back. Do **not** run `codegraph init` or `codegraph index` during read-only exploration unless the user explicitly asks for it.

## Preferred workflow when CodeGraph is ready

1. For structural/flow questions ("how does X work", "what calls Y", "impact of changing Z"), use `codegraph_explore` if the MCP tool is available.
2. If only the CLI is available, run `codegraph explore "<natural-language query>"` or the narrower commands (`callers`, `callees`, `impact`, `node`).
3. Treat the returned source snippets as evidence, but verify critical claims by reading the exact file/line with `read` when needed.
4. Note any staleness banner (`⚠️`) after recent edits and read pending files directly.
5. If a query returns empty or unclear results, do not loop — fall back to `grep`/`glob`/`read`.

## Fallback rules

- If CodeGraph is missing: use standard exploration (`glob`, `grep`, `read`, `bash` for project metadata).
- If CodeGraph is present but unindexed: mention the gap once, then use standard exploration.
- Never block the task waiting for a CodeGraph index.
- Never treat CodeGraph output as fake-backed evidence; cite the returned source or your own reads.

## Output conventions

- Distinguish CodeGraph evidence from fallback evidence (e.g., "From codegraph_explore:" vs "From grep/read:").
- Keep exact symbol names, file paths, and line numbers.
- If CodeGraph was unavailable, briefly note it in the findings so the coordinator/user knows the exploration used built-in tools.
