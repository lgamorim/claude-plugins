---
description: Spec-first feature pipeline with review gates
argument-hint: <feature description>
---
You are orchestrating a gated feature pipeline. The
feature description is:

$ARGUMENTS

Run the phases below IN ORDER. After each phase, print
the artifact paths and a 3-line summary, then STOP and
ask the user to approve, revise, or abort. Do not
proceed to the next phase without explicit approval.
State is handed off exclusively through the artifacts in
`openspec/changes/<change-id>/` — never through your own
summaries. When delegating, pass file paths, not
paraphrases. Never pass an explicit model parameter when
delegating; each persona's frontmatter declares its
model and effort deliberately.

Phase 1 — SPEC (sequential)
  Delegate to the spec-writer subagent. Pass the feature
  description VERBATIM — do not summarize it.
  Gate: `openspec validate <change-id> --strict` passes
  AND the user approves. Surface any Open Questions and
  get answers before proceeding; the spec-writer must
  fold the answers into the proposal.

Phase 2 — DESIGN (parallel, then synthesize)
  Spawn THREE software-architect subagents in the same
  turn, each pointed at `openspec/changes/<change-id>/`
  with an explicitly different brief:
    a) "optimize for testability"
    b) "optimize for minimal blast radius"
    c) "optimize for long-term evolvability"
  Assign each architect its own output filenames —
  `design.<brief>.md` and `tasks.<brief>.md` (brief =
  testability | blast-radius | evolvability) — so
  parallel runs never write the same file. State the
  assigned filenames explicitly in each delegation.
  Synthesize: present the material disagreements between
  the three designs as a decision table, with your
  recommendation and its trade-offs.
  Gate: the user picks an approach — one design
  wholesale, or a hybrid of decisions across designs.
  For a hybrid, never merge files yourself: delegate
  one further software-architect run, its brief the
  chosen decision set, writing directly to the
  canonical `design.md` and `tasks.md`; that output
  becomes the winner. Then, in order:
  (1) rename the winning architect's files to the
  canonical `design.md` and `tasks.md` (already
  canonical after a hybrid run); (2) delete every
  non-canonical `design.*.md` / `tasks.*.md` pair —
  rejected alternatives leave no residue in the change
  directory; (3) if the
  winning design carries a Draft ADRs section,
  materialise it into `docs/adr/` — architects never
  write there themselves; (4) run
  `openspec validate <change-id> --strict`. The
  architects' own validate runs cannot see suffixed
  filenames, so this is the first validation that
  covers the chosen design — it must pass before
  Phase 3 opens.

Phase 3 — IMPLEMENT (parallel where waves allow)
  Read tasks.md. For each wave, delegate independent
  tasks to separate engineer subagents in one turn —
  one agent per task, routed by the task's persona tag:
  [backend] → backend-engineer, [aspnet] →
  aspnet-engineer, [blazor] → blazor-engineer. An
  untagged task is a defect in tasks.md, not a routing
  case: if its files include UI files (.cshtml,
  .razor, wwwroot/), send it BACKWARD to the
  software-architect for tagging, like any other
  upstream defect; otherwise route it to
  backend-engineer and flag the missing tag to the
  user at the wave gate. Each agent is told its exact
  task numbers and owned files. Tasks touching the
  same file are never parallelised, even across
  different personas.
  Gate: `dotnet build` with zero warnings and
  `dotnet test` green, verified by running them
  yourself, not by trusting agent reports — an
  engineer reporting a failure rooted outside its own
  files is reporting sibling interference, and your
  run settles it. Once the gate passes, YOU tick the
  wave's completed tasks in `tasks.md` from the
  engineers' reports, then YOU commit the wave with a
  conventional-commit message naming the change id.
  Engineers never run `git commit` and never edit
  `tasks.md` — parallel commits in one working tree
  race on the index and can sweep up a sibling's
  half-finished files, and parallel ticks race on the
  one file every task would share.

Phase 4 — VERIFY (two independent passes)
  Spawn TWO quality-assurance subagents in the same
  turn with different adversarial briefs:
    a) "hunt spec violations: prove a scenario false.
        You own coverage — write the missing test for
        any scenario not already covered"
    b) "hunt weak tests: boundaries the spec implies
        but does not enumerate, and tests that cannot
        fail. Do not write coverage-gap tests; the
        sibling pass owns those"
  Assign each pass its own artifacts so the parallel
  runs never write the same file: verification reports
  `verification.spec-violations.md` and
  `verification.weak-tests.md`, and any NEW test files
  suffixed with the pass name. Tell each pass it must
  not edit existing test files — additions only, in its
  own files. State the assignments explicitly in each
  delegation.
  Merge their findings into one defect list,
  de-duplicated, ordered by which requirement each
  defect breaks.
  Gate: zero defects, or the user explicitly accepts
  the remainder. If defects remain and the user wants
  them fixed, return to Phase 3 with the defect list as
  the task input, then re-run Phase 4: fixes get fresh
  verification reports from quality-assurance, never
  self-certification by the engineers who made them.

Throughout:
- Never let a subagent write outside its phase's
  artifacts. If a report shows it did, flag it to the
  user before the gate.
- If any phase reports a defect in an upstream artifact
  (spec or design), the pipeline moves BACKWARD to the
  owning persona; downstream personas never patch
  upstream artifacts.
