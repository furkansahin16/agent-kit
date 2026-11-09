---
name: dotnet-lts-upgrade
description: Use ONLY for .NET SDK, target-framework, NuGet, EF Core, SQL provider, Docker, or CI upgrades to an LTS release where behavior and database compatibility must be preserved.
---

# .NET LTS Upgrade

## Objective

Upgrade a .NET repository to a supported LTS release with the smallest compatible change set. Preserve behavior, public contracts, database semantics, and deployment behavior. The task includes user-authorized Docker support, legacy `Startup.cs` to minimal `Program.cs` modernization, and an architecture recommendation report.

## Guardrails

- Verify the target is currently supported LTS from official support information; never infer it from version ordering.
- Start with `git status`, repository instructions, and a baseline restore/build/test result. Keep unrelated user changes untouched.
- Inventory all version inputs before editing: `global.json`, `*.sln`, `*.csproj`, `Directory.Build.*`, `Directory.Packages.props`, `NuGet.config`, lock files, Dockerfiles, CI, deployment manifests, and scripts.
- Do not run blanket package upgrades. Version changes must be deliberate, compatible, and scoped.
- Do not mix unrelated cleanup, refactoring, API redesign, formatting churn, package replacement, or behavior changes into the upgrade.
- Do not suppress compiler, analyzer, restore, or test failures to make the upgrade appear successful.
- Never commit, amend, push, stage, or open a pull request. The user owns the final commit.

## Branch And Solution Scope

1. Determine the target LTS major version, then create `upgrade/dotnet-<target-major>-lts` from the current `HEAD` before changing files.
2. If the original worktree is dirty, preserve it exactly: create the branch in a separate sibling `git worktree` and work there. Do not stash, reset, or move user changes.
3. If the branch already exists or isolation cannot be created safely, stop and ask the user.
4. Inventory every `*.sln` and `*.csproj`, including projects outside the primary solution. Classify executable, library, test, tool, and sample projects; map their project references and central/shared package versions.
5. Build and test every in-scope solution. Resolve cross-library target-framework and dependency conflicts at their source; do not leave an incompatible project behind or force an unproven package version.

## Compatibility Analysis

Record a compact matrix before making changes:

| Area | Current | Target | Constraint | Verification |
| --- | --- | --- | --- | --- |
| SDK / TFM | | | supported LTS and project compatibility | restore/build |
| Packages | | | dependency and provider compatibility | restore/tests |
| Runtime / deployment | | | images, RID, hosting compatibility | build/startup |
| Persistence | | | EF Core/provider/database behavior | persistence tests |

Use CodeGraph for entry-point, caller/callee, and impact analysis when available and indexed. Otherwise use the repository's normal inspection tools. Inspect public endpoints, messages, serialized models, background jobs, configuration, feature flags, and persistence boundaries before changing code required by a compatibility break.

## EF Core And SQL Providers

- Treat `Microsoft.EntityFrameworkCore.*`, the database provider, `Design`, `Tools`, and related extensions as one compatible set.
- Confirm the provider supports the target EF Core and target .NET version. Do not substitute providers without approval.
- Inspect migrations, model configuration, raw SQL, value conversions, precision, collation, null semantics, transactions, retries, concurrency, and command interceptors.
- Never alter migrations or apply database changes without explicit approval.
- Prefer existing repository persistence tests. Use only local ephemeral resources or user-approved databases. Never use production-like credentials, data, or endpoints.

## Hosting And Containers

- If a legacy ASP.NET Core `Startup.cs` pattern is present, convert it to minimal `Program.cs` hosting. Preserve service-registration and middleware order, configuration/host sources, route mappings, filters, environment-specific paths, authentication, authorization, and error handling. Do not claim equivalence without inspecting both startup paths.
- Update existing Dockerfiles, Compose files, CI images, and runtime images to the target LTS version.
- If no Docker support exists, add a production-oriented multi-stage `Dockerfile`, `.dockerignore`, and Compose file using project conventions. Derive ports, environment variables, and dependent services from repository evidence only. Never add secrets, credentials, or production endpoints.
- When Docker is locally available, build the image and validate the Compose configuration. Otherwise report the exact missing validation prerequisite.

## Verification

1. Restore and build before edits; record existing failures.
2. After each coherent upgrade batch, restore and build again.
3. Run affected tests first, then the full existing suite when practical.
4. Run existing EF/integration tests when their local prerequisites are available.
5. Compare baseline and final failures and identify newly introduced failures only.
6. If safe and supported by the repository, validate a representative startup path.
7. Review the final diff for contract, persistence, and deployment changes unrelated to the upgrade.

If an integration environment is unavailable, report the precise missing prerequisite and the smallest safe command needed to complete verification. Do not claim full compatibility from compilation alone.

## Architecture Report

After upgrade verification, identify architecture improvements without implementing them. Save a Markdown report in the repository's established documentation location, or `docs/architecture-recommendations-dotnet-<target-major>-lts.md` if none exists. For every recommendation, include evidence, affected projects, expected benefit, risk, priority, and an explicit note that it was excluded from the compatibility upgrade.

## Escalation Conditions

Ask before continuing when the work requires schema/data changes, a public contract change, provider replacement, non-local database access, authentication/authorization changes, unavailable private packages, or a major dependency strategy decision.
