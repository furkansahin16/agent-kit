---
name: project-init
description: Set up the docs/ structure and an AGENTS.md in a repository from the agent-kit templates, asking the user for the project-specific parts (language, stack, commands, hard rules). Use when the user asks to initialise project docs, bootstrap AGENTS.md, or start a new project with the standard docs set.
---

# Project init

Copies the agent-kit project skeleton into the current repository and fills `AGENTS.md` together with the user. This is a judgment task, not a script: the content of `AGENTS.md` comes from the user's answers.

## 1. Find the kit and the target

- Kit root: `$AGENT_KIT_HOME` if set, otherwise `~/agent-kit`. The templates are in `<kit>/templates/project/`. If neither exists, ask the user where the kit is. Do not invent templates.
- Target: the repository root of the current working directory (`git rev-parse --show-toplevel`; if it is not a git repo, use the current directory and say so).
- Kit version: the content of `<kit>/VERSION`.

## 2. Check what already exists

List `AGENTS.md`, `CLAUDE.md` and `docs/` in the target.

- Never overwrite an existing file. If `AGENTS.md`, `CLAUDE.md`, or any of the five docs files exists, skip that file and tell the user. Offer to merge by hand if they want it.
- If `docs/.kit-version` exists the project was initialised before: stop and suggest the kit's `check` script instead.

## 3. Ask the user (one batch of questions)

1. Docs language: English (default) or Turkish. Affects only the five docs files.
2. Project name and a one-or-two sentence description.
3. Stack (languages, frameworks, storage, deployment). Skip if unknown.
4. Commands: setup, run, test, lint/format, build. Ask the user; discover candidates from the repo (`package.json`, `*.csproj`, `pyproject.toml`, `Makefile`, ...) and propose them for confirmation instead of asking from scratch.
5. Hard rules: things an agent must never do in this project (secrets handling, real-money or irreversible actions, forbidden paths, approvals needed). Ask explicitly; an empty answer is fine.
6. Language rule for code, comments and commit messages, if the user has one.

Do not guess answers to 3-6. Leave out a section rather than fill it with assumptions.

## 4. Create the files

1. Copy `<kit>/templates/project/<lang>/docs/*.md` (`<lang>` is `en` or `tr`) to `<target>/docs/`. Replace the `{{PROJECT_NAME}}` placeholder in the titles. Do not add content of your own.
2. Create `AGENTS.md` from `<kit>/templates/project/AGENTS.md.tmpl`: replace `{{PROJECT_NAME}}` and `{{DESCRIPTION}}`. The template contains "Read first" and "Working style". Add the sections the user answered, between those two, in this order: `## Stack`, `## Hard rules`, `## Language` (only if given), and after "Working style" `## Commands`. Use short bullet lists in the user's words.
3. Create `CLAUDE.md` from `<kit>/templates/project/CLAUDE.md` (it contains only `@AGENTS.md`).
4. Write `<target>/docs/.kit-version` with two lines: the kit version (content of `<kit>/VERSION`) and `lang: en` or `lang: tr`. The kit's `check` script reads this file.

## 5. Report

Show the user the list of created and skipped files and the filled `AGENTS.md`. Do not commit; leave that to the user. Mention that the working rules for the docs live in the `project-docs` skill and that `check` in the kit reports skeleton changes later without touching their content.
