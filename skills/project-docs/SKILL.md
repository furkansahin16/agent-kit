---
name: project-docs
description: Rules for maintaining a project's docs/ set (DESIGN, DECISIONS, ROADMAP, QUESTIONS, DISCOVERY). Use whenever you record a decision, add or tick off a roadmap task, log an open question, or write down a newly learned fact in a repository that has these files.
---

# Project docs: working rules

This skill only describes the rules. It does not edit files by itself. Apply the rules when you touch the files below. The files may be written in English or Turkish (chosen when the project was initialised); the rules are the same, only the section names differ.

## The file set

| File | Purpose |
|---|---|
| `docs/DESIGN.md` | How the thing is built: architecture, data model, flows. Describes the current design, not its history. |
| `docs/DECISIONS.md` | Decisions already made and why. Do not relitigate them. |
| `docs/ROADMAP.md` | Phases and tasks, with status. The current phase and the next task live here. |
| `docs/QUESTIONS.md` | Open questions and their answers. |
| `docs/DISCOVERY.md` | Facts learned about the environment (external systems, real behaviour, constraints) that the code alone does not tell. |

Read the relevant file before changing it, and read `DECISIONS.md` before proposing anything that might contradict an earlier choice.

## DECISIONS.md: append only

- Add new decisions at the end. Never delete or rewrite a past decision.
- Heading format: `## D-NN Title (YYYY-MM-DD)`. `NN` is the next unused number, zero-padded to two digits (`D-01`, `D-02`, ... `D-100`). Use today's date.
- Body: the decision in a sentence or two, then the reason.
- A decision that changes: leave the old one in place and add a line `Superseded by D-xx` to it. Write the new decision as a new entry that says what it replaces.
- A decision that only amends another: say `Amended by D-xx` on the old one.

## ROADMAP.md: statuses and IDs

- Status markers: `[ ]` todo, `[~]` in progress, `[x]` done.
- Task IDs are `P<n>-<nn>`, where `P<n>` is the phase number and `<nn>` the task number inside it (`P1-03`). IDs are never reused or renumbered.
- Tick a task (`[x]`) when it is done, in the same change that finishes it. Mark `[~]` while it is being worked on. Put a short factual note in parentheses after a done task if something is worth remembering (date, what was verified).
- New work gets a new ID at the end of the matching phase, or a new phase.

## QUESTIONS.md: nothing is deleted

- New questions go under the open section as `- [ ] ...`.
- When a question is answered, do not delete it: tick it (`- [x]`), move it to the answered section, and add a pointer to the decision (`see D-NN`). If the answer is a decision, write it in `DECISIONS.md` first.

## DISCOVERY.md

- Record new facts about the environment as they are found: how an external system really behaves, limits, quirks, exact names, where the evidence came from.
- State what was observed, not what was assumed. If something is a guess, mark it as unverified.
- Never write secrets, credentials, or personal data here.

## DESIGN.md

- Keep it current. When a decision changes the design, update the design section and make sure the matching decision exists in `DECISIONS.md`.

## General

- Language: keep each file in the language it already uses.
- Keep entries short and factual. Link to other entries by ID (`D-12`, `P2-04`) instead of repeating them.
- If the docs and the code disagree, say so and ask which one is right before changing either.
- The project's `AGENTS.md` carries a two-line summary of these rules; this skill is the full version.
