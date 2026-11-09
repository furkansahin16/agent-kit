# CodeGraph Usage Guide (Global)

This guide applies to all agents when working inside a project that may have CodeGraph installed.

## What CodeGraph is

CodeGraph is a local, pre-indexed knowledge graph of your codebase. It exposes an MCP tool (`codegraph_explore`) and a CLI (`codegraph`) that can answer structural questions — callers, callees, impact radius, symbol definitions, framework routes — in far fewer tool calls than manual `grep`/`glob`/`read` exploration.

## When to use it

Any agent that needs to understand code structure, trace a flow, analyze impact, or find related symbols should prefer CodeGraph when it is available and indexed.

Examples:
- `explorer` → codebase discovery and flow tracing.
- `worker` → finding where to make a change and what it affects.
- `debugger` → tracing how a bug propagates through call chains.
- `reviewer` → checking blast radius of a change.
- `architect` → understanding module/call dependencies.
- `tester` → identifying which tests are affected by a change.
- `coordinator` → scoping tasks based on actual code relationships.

## Availability check

Before relying on CodeGraph:

1. Check that the MCP tool `codegraph_explore` is available in your tool list.
2. If it is not available, try `codegraph status` or `codegraph --version` via bash.
3. If neither is available, CodeGraph is not installed — fall back to built-in tools immediately.

If CodeGraph is installed but the project is not indexed (no `.codegraph/` directory or `status` reports no index), do **not** initialize it yourself unless the user explicitly asks. Report the gap and fall back.

## How to use it

- Prefer the MCP tool `codegraph_explore` for broad or structural questions.
- If only the CLI is available, use commands like:
  - `codegraph explore "<question>"`
  - `codegraph callers <symbol>`
  - `codegraph callees <symbol>`
  - `codegraph impact <symbol>`
  - `codegraph node <symbol>`
  - `codegraph query <search>`
- Treat CodeGraph output as strong evidence, but verify critical claims with `read` when precision matters.
- If CodeGraph returns empty, stale, or confusing results, do not loop — fall back to `grep` / `glob` / `read`.

## Fallback rule

CodeGraph is optional. If it is missing, unindexed, or insufficient, continue the task with built-in tools. Never block waiting for an index.
