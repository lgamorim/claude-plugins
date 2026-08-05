# claude-plugins

## Context

This repository exists to make role-based Claude Code
subagents ("personas") reusable across projects instead
of copy-pasted into each one. It is a **Claude Code
plugin marketplace**: a git repo with a
`.claude-plugin/marketplace.json` catalog at the root and
one directory per plugin. Projects opt in per plugin —
`/plugin marketplace add` once, `/plugin install` per
project — and improvements pushed here propagate to every
consumer via `/plugin marketplace update`.

The first plugin, `dotnet-personas`, encodes a
**spec-first development chain** for .NET/C# work:

    feature description
      → spec-writer         (product owner: OpenSpec change proposal)
      → software-architect  (design + waved, persona-tagged execution plan)
      → engineers           (implementation, parallel per wave, routed
                             per task tag: backend / aspnet / blazor)
      → quality-assurance   (adversarial verification)

Three design commitments shape everything in this repo:

1. **Artifacts are the message bus.** Subagents start
   with empty context; anything not written down is
   lost. Personas therefore hand off exclusively through
   files in `openspec/changes/<change-id>/` —
   `proposal.md`, spec deltas, `design.md`, `tasks.md`,
   `verification.md`. Every handoff is reviewable on
   disk, and any phase can be re-run in isolation.
2. **Machine-checkable gates between phases.**
   `openspec validate --strict` after spec and again
   when a design is promoted, `dotnet build` with zero
   warnings and `dotnet test` after implementation.
   Structure is enforced by tools; judgment is reserved
   for human review at each gate.
3. **Roles here, house style in the consuming repo.**
   Plugins are copied to a cache at install time and
   cannot read files outside themselves. Personas
   therefore carry only role definitions — what an agent
   is responsible for, what it must never touch, how its
   output is verified. Project conventions reach agents
   through the consuming repo's own `CLAUDE.md`
   (sourced from `claude-rules`). Rule of thumb: if it
   changes when you switch repos, it belongs in
   `CLAUDE.md`; if it changes when you switch roles, it
   belongs here.

The configuration is tuned for **quality over cost**:
frontier models throughout, effort maxed where output is
open-ended, and quality bought through independent
parallel samples (three architects with competing
briefs, two adversarial QA passes) rather than through
single runs thinking longer.

## Repository structure

    claude-plugins/
    ├── .claude-plugin/
    │   └── marketplace.json          # the catalog
    ├── .github/
    │   └── workflows/
    │       └── checks.yml            # persona drift check on push/PR
    ├── dotnet-personas/
    │   ├── .claude-plugin/
    │   │   └── plugin.json
    │   ├── agents/
    │   │   ├── spec-writer.md
    │   │   ├── software-architect.md
    │   │   ├── backend-engineer.md
    │   │   ├── aspnet-engineer.md
    │   │   ├── blazor-engineer.md
    │   │   └── quality-assurance.md
    │   ├── commands/
    │   │   └── feature.md            # /dotnet-personas:feature
    │   └── README.md
    ├── scripts/
    │   └── check-persona-drift.sh    # persona consistency gate
    ├── LICENSE                       # Apache-2.0
    └── README.md

## Plugins

| Plugin | Contents |
|---|---|
| `dotnet-personas` | spec-writer, software-architect, backend-engineer, aspnet-engineer, blazor-engineer, quality-assurance, `/feature` orchestrator |

## Model and effort strategy

Effort tracks how **underdetermined the output is by the
inputs**, not how important the phase is.

| Persona | Model | Effort | Rationale |
|---|---|---|---|
| spec-writer | opus | max | Open-ended: turns prose into requirements; most leveraged artifact in the chain |
| software-architect | opus | max | Open-ended: decisions with rejected alternatives; run 3× in parallel with competing briefs |
| backend-engineer | opus | high | Closed-ended: executes an approved plan. Deliberately NOT max — surplus reasoning re-litigates settled decisions and invites scope creep. If this persona needs max effort to succeed, the architect phase is under-delivering |
| aspnet-engineer | opus | high | Closed-ended executor, same rationale as backend-engineer; differs only in domain (server-rendered MVC / Razor Pages UI) |
| blazor-engineer | opus | high | Closed-ended executor, same rationale as backend-engineer; differs only in domain (Blazor components — render modes are fixed by the design, never chosen here) |
| quality-assurance | fable | max | Adversarial falsification; run 2× with different briefs. Model deliberately differs from backend-engineer so verifier and implementer do not share blind spots |

Config caveats (verify once per machine):

- `effort` frontmatter overrides the session level but
  NOT the `CLAUDE_CODE_EFFORT_LEVEL` environment
  variable. If that variable is exported anywhere, the
  per-agent tiering is silently dead.
- Model resolution order is env var
  (`CLAUDE_CODE_SUBAGENT_MODEL`) → per-invocation
  parameter → frontmatter → session model. The
  `/feature` command instructs the orchestrator never to
  pass a per-invocation model for this reason.
- `xhigh`/`max` effort are not supported on every model
  tier; on unsupported tiers they warn or fall back.
- Misspelled frontmatter fields fail silently. After
  install, run each agent once and confirm model and
  effort took effect (check the agent detail in
  `/agents` or the run view).

## Bootstrap

### 1. Prepare the consuming repo (once per repo)

    dotnet new sln ...                # or an existing solution
    openspec init                     # creates openspec/, fill in project.md
    # ensure CLAUDE.md carries the house style (from claude-rules)

The personas assume: `openspec/` at the repo root,
`dotnet build` and `dotnet test` runnable from the root,
and warnings treated as errors in the build.

### 2. Install the plugin (once per repo)

In a Claude Code session inside the consuming repo:

    /plugin marketplace add lgamorim/claude-plugins
    /plugin install dotnet-personas

Confirm with `/agents` — the six personas should list
with their models. Later, to pull persona improvements:

    /plugin marketplace update lgamorim-plugins

Note the two identifiers: `add` takes the GitHub repo
path, while `update` takes the marketplace `name` field —
`lgamorim-plugins`, not `claude-plugins`, because
validation rejects names reserved/too close to official
ones. The repo name and install path are unaffected.

### 3. Run a feature end-to-end (new session)

    /dotnet-personas:feature Add a validation report to the level pipeline

The orchestrator stops for approval after every phase:

1. **Spec** — review `proposal.md` and the deltas;
   answer Open Questions. Nothing proceeds until
   `openspec validate --strict` passes AND you approve.
2. **Design** — three architects run with competing
   briefs, each writing to its own `design.<brief>.md`
   / `tasks.<brief>.md`; you pick from a decision
   table — one design wholesale, or a hybrid via one
   further architect run. The winner becomes the
   canonical `design.md` / `tasks.md`, re-validated
   before implementation; rejected designs are deleted
   without residue.
3. **Implement** — engineers run per wave, parallel
   only across disjoint files; the gate is a clean
   build and green tests re-run by the orchestrator,
   which then ticks the wave's tasks and commits it
   (engineers never commit or tick — both race in a
   shared tree).
4. **Verify** — two adversarial QA passes, each with
   its own verification report and test files, produce
   a merged defect list; defects route back to Phase 3
   (verification re-runs after fixes), spec/design
   defects route back to their owning persona.
   Downstream never patches upstream.

Personas can equally be used à la carte — ask for a spec
without the pipeline and the spec-writer routes in on
its own description.

### Local development of the plugin itself

    claude --plugin-dir ./dotnet-personas   # try without installing
    claude plugin validate .                # validate marketplace + plugin
    sh scripts/check-persona-drift.sh       # persona consistency gate

Agent files cannot include shared content, so the
engineer personas carry verbatim copies of their
Process, Rules and Report back sections, and the two
frontend personas share their Domain rules preamble
word for word. The drift check fails when any copy
diverges, or when an engineer's task tag is not wired
into the architect, the orchestrator and the plugin
README — adding an engineer persona means satisfying
it for the new tag. CI runs it on every push and pull
request.

## Known limitations, by design

- **Write boundaries are prose.** "QA never edits
  production code" is instruction, not enforcement.
  Harden with a `PreToolUse` hook once real drift is
  observed.
- **Subagents cannot ask questions mid-task.** The
  spec-writer's Open Questions section is the only
  escalation channel; every other persona is instructed
  to STOP and report rather than guess.
- **Engineers share one working tree.** Parallel
  build/test runs can see a sibling's half-finished
  work or contend on `obj/`/`bin/`; personas report
  such failures as sibling interference, and the
  orchestrator's own gate run settles them. Worktree
  isolation is on the roadmap.
- **`version` is intentionally omitted** from
  plugin.json so consumers always get the latest commit
  (Claude Code uses the git SHA as the version).
  Introduce semver only if a plugin gains external
  consumers.
- **Quality ceiling is the spec, not the model tier.**
  A vague spec verified at max effort is still a vague
  spec, verified expensively. The Phase 1 gate is where
  human attention pays most.

## Roadmap

- `PreToolUse` hooks hard-enforcing per-persona write
  boundaries
- `unity-personas` plugin (unity-engineer,
  level-designer) and `library-author` for reusable
  .NET libraries
- Dynamic-workflow variant of Phase 3 — each task's
  engineer in an isolated worktree, removing the
  sibling-interference caveat — once wave sizes
  justify it (one agent per task is already how
  Phase 3 runs)
