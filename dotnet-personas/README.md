# dotnet-personas

Spec-first .NET personas that hand off through OpenSpec
artifacts on disk rather than through conversation
context.

    description → spec-writer        → proposal.md, spec deltas, tasks.md
                → software-architect → design.md, waved + tagged tasks.md
                → engineers          → source, tests
                → quality-assurance  → tests, verification.md

Implementation is routed per task: the architect tags
each task `[backend]`, `[aspnet]` (server-rendered MVC /
Razor Pages) or `[blazor]`, and the orchestrator
delegates it to the matching engineer persona. An
untagged task is treated as a plan defect: untagged UI
work bounces back to the architect; anything else
routes to `backend-engineer`, flagged at the wave gate.

Each handoff has a machine-checkable gate:
`openspec validate --strict` after the spec and again
at design promotion, then `dotnet build` (zero
warnings) and `dotnet test` at every implementation
wave.

## Contents

| Component | Kind | Model / Effort | Writes |
|---|---|---|---|
| `spec-writer` | agent | opus / max | `openspec/changes/<id>/` only |
| `software-architect` | agent | opus / max | `design.md`, `tasks.md` only |
| `backend-engineer` | agent | opus / high | source + tests in assigned files |
| `aspnet-engineer` | agent | opus / high | source + tests in assigned files |
| `blazor-engineer` | agent | opus / high | source + tests in assigned files |
| `quality-assurance` | agent | fable / max | tests + `verification.md` only |
| `/dotnet-personas:feature` | command | n/a (orchestrates) | promotes + validates winning design, materialises its ADRs, ticks `tasks.md`, commits waves |

Model/effort rationale is in the repo root README.

## Requires

- An `openspec/` directory in the consuming repo
  (`openspec init`) with `project.md` filled in
- .NET SDK on PATH (`dotnet build` / `dotnet test` are
  the gates)
- Project house style in the consuming repo's
  `CLAUDE.md` — the personas defer to it, carrying
  only role-level fallbacks (e.g. QA's default test
  stack for projects that have none)

## Install

    /plugin marketplace add lgamorim/claude-plugins
    /plugin install dotnet-personas

## Use

Full pipeline, gated at every phase:

    /dotnet-personas:feature <feature description>

Or invoke personas individually — describe a feature and
ask for a spec (routes to spec-writer), point at an
approved change and ask for a design, etc.

## Boundaries are prose, not enforcement

Write restrictions ("QA never edits production code")
live in the agent prompts. They are followed, not
enforced. If drift appears, the hardening step is a
`PreToolUse` hook in this plugin that rejects `Write` /
`Edit` outside each persona's allowed paths — add it
when observed behaviour justifies it, not before.
