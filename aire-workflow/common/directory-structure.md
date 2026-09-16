# Directory Structure

**Purpose**: the canonical layout of an AIRE workspace — where application code goes, where specs go,
where documentation goes, and where every stage/skill writes its artifacts.

**Load this file when**: creating any file or folder whose location isn't already fixed by the rule
file you are following, or when you need to locate an existing artifact by convention.

---

## The five roots

An AIRE workspace has exactly five top-level roots that AIRE owns. Everything AIRE writes goes into
one of them. Nothing AIRE writes goes anywhere else.

| Root         | Holds                                                                                                                                                                                                    | Rule                                                       |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| `src/`     | **ALL application source code**| Greenfield AND brownfield. Never code outside it.          |
| `tests/`   | All test code:`tests/unit/`, `tests/api/` (API & contract tests), `tests/behavior/` (Gherkin), `tests/e2e/` (Playwright); plus the eval framework at **`tests/.evals/`** (thresholds, rubrics, eval runner scripts) | Mirrors`src/` structure under `tests/unit/`. `tests/.evals/` is the source of truth for WHETHER it built it right. |
| `spec/`    | The specs AIRE writes and the docs AIRE writes — `plans/`, `spec-generation/`, `behavior/`, `test-plans/`, `behavior.feature`, `context-project/` | The agent's source of truth for WHAT to build.             |
| `reports/` | **Generated OUTPUTS** — test/eval evidence (unit, behavior, api-contract, eval), review reports (`reviews/`, `code-security-reviews/`) and per-work-unit code summaries (`ticket-summary/`) | Generated proof/findings/summaries only; never a spec.     |
| `runtime-artifacts/` | The cycle's **`audit.md`** (audit trail) and **`aire-state.md`** (session/state), alongside root-level tool caches (`.mypy_cache`, `.ruff_cache`, Playwright exec files) | Session/run state + tool artifacts; recreated fresh each cycle. |

Plus one generated integration point: `.github/workflows/` — the CI pipeline AIRE **generates for
this specific project** (see `common/ci-pipeline-generation.md`).

---

## Full layout

```text
<WORKSPACE-ROOT>/
│
├── src/                                  #    ALL APPLICATION CODE — greenfield and brownfield
│   └── [stack-idiomatic structure]       #    layout per code-generation.md; NEVER outside src/
│
├── tests/                                 #   ALL TEST CODE — never under spec/
│   ├── unit/                              #    ALL unit tests — MIRRORS src/ layout 1:1. HARD RULE:
│   │   │                                 #    every unit test (incl. UI/component tests — RTL, jsdom,
│   │   │                                 #    Enzyme, etc.) lives here, never in a sibling top-level
│   │   │                                 #    folder like tests/components/. Grouped/baseline suites
│   │   │                                 #    that cover several src/ modules together still nest
│   │   │                                 #    under the mirrored path of the area they cover (e.g. a
│   │   │                                 #    components baseline suite → tests/unit/components/) —
│   │   │                                 #    "mirrors src/" governs the PARENT path, it does not
│   │   │                                 #    require one file per source file.
│   │   └── <mirror-of-src>/               #    e.g. src/auth/login.ts → tests/unit/auth/login.test.ts
│   │                                     #    one test module per src module (jest / pytest /
│   │                                     #    go test / JUnit); feeds D-coverage + unit evidence
│   ├── api/                               #    API & Contract Testing Gate output (code-generation.md
│   │   │                                 #    Step 11a.5) — tests that call REAL endpoints (supertest /
│   │   │                                 #    httpx / RestAssured / MockMvc / a spun-up test server).
│   │   │                                 #    HARD RULE: this is the ONLY location for these tests —
│   │   │                                 #    never tests/unit/, never colocated with the endpoint's
│   │   │                                 #    unit tests. Not a mirror of src/ — organize per endpoint
│   │   │                                 #    or resource group (e.g. tests/api/articles.route.test.js).
│   ├── behavior/                          #  Gherkin EXECUTION layer (the .feature SPECS live in spec/)
│   │   ├── test_<work-unit>.py            #    loader/runner — points the BDD runner (behave/
│   │   │                                 #    pytest-bdd/cucumber) at spec/behavior/<work-unit>.feature
│   │   ├── environment.py                 #    BDD hooks — before/after scenario setup + teardown,
│   │   │                                 #    fixtures, world/context wiring shared by all steps
│   │   └── steps/                         #    step definitions — bind each Gherkin clause to src/
│   │       ├── common_steps.py            #     shared Given/When/Then reused across features
│   │       └── <work-unit>_steps.py       #     per-work-unit step impls (B1 unit, B2 others, B3 cycle)
│   ├── e2e/                               #   tests/e2e/ — Playwright, UI projects ONLY (skip if no UI)
│   │   ├── seed.spec.ts                   #    ONE shared seed inside testDir — fixture/data setup
│   │   │                                 #    run before story specs; NEVER duplicated per story
│   │   ├── fixtures.ts                    #    shared Playwright fixtures / auth state / helpers
│   │   └── <story-slug>/                  #    Generator output — ONE folder per story
│   │       └── <scenario>.spec.ts         #     one spec per approved manual test scenario;
│   │                                     #     run headed, healed by the Playwright Healer agent
│   ├── playwright-specs/                  #    Playwright Planner output (<story-slug>.md per story)
│   └── .evals/                            #   EVAL FRAMEWORK — nested under tests/; created on the cycle branch if missing
│       ├── config.json                    #    ALL thresholds. The ONLY place a number lives.
│       ├── rubrics/
│       │   ├── architecture-rubric.json   #    derived from spec/plans/architecture.md every cycle
│       │   └── security-rubric.json       #    OWASP-based, created once
│       ├── behavior/                      #    Gherkin container — same image locally and in CI
│       │   ├── Containerfile              #      must be PROVEN to build at bootstrap
│       │   └── run.sh                     #    THE entry point: run.sh <b1|b2|b3>
│       └── scripts/                       #    generated per project, committed, executable
│           ├── run-static-evals.sh        #    D1–D7 baseline diff — local AND CI call this
│           ├── run-evals.sh               #    J1/J2 judge via the Claude Code CLI
│           ├── resolve-eval-key.sh        #    resolves the eval auth/API key from env
│           ├── auto-fix-agent.sh          #    CI self-repair driver (retry-capped from config.json)
│           ├── validate-pipeline.sh       #    lints the generated CI YAML before it is committed
│           └── smoke-test-epic.sh         #    end-to-end sanity run of the cycle's gates
│
├── spec/                                #   SPECS + DOCUMENTATION — never code
│   ├── behavior.feature                  #    ONCE per cycle. Cross-story journeys, @REQ tagged.
│   │                                     #    What the B3 tier runs on the last work unit.
│   ├── plans/                            #    ALL planning + design DOCS, as FLAT files:
│   │   ├── architecture.md               #     ONCE per cycle — system design + inline Mermaid diagrams + Section 10 constraints
│   │   ├── atlas-deep-dive.md            #     current-system architecture, from Atlas via Helix MCP
│   │   ├── business-overview.md          #     + the flat RE docs (from Atlas): code-structure.md,
│   │   │                                 #     api-documentation.md, component-inventory.md,
│   │   │                                 #     technology-stack.md, dependencies.md,
│   │   │                                 #     code-quality-assessment.md,
│   │   │                                 #     reverse-engineering-timestamp.md
│   │   ├── requirements.md               #     epic-brief.md, requirements.md
│   │   ├── stories.md                    #     stories.md, personas.md
│   │   ├── dependency-graph.yml
│   │   ├── executions.md                 #     workflow-planning execution plan (EXECUTE/SKIP per stage)
│   │   ├── functional-design.md          #     consolidated design docs (one per stage)
│   │   ├── nfr.md                        #     nfr-requirements + nfr-design, merged
│   │   ├── infrastructure-design.md
│   │   ├── application-design.md         #     components / methods / services / dependency, merged
│   │   ├── bug-brief.md                  #     ticket-implement (bug-fix): fetched/captured ticket brief
│   │   ├── enhancement-brief.md          #     ticket-implement (enhancement): fetched/captured brief
│   │   └── impact-analysis.md            #     bug-fix / enhancement-implement: affected files + root cause
│   ├── spec-generation/                 #    the *-generation.md plan + clarifying-question files
│   │   ├── story-generation.md          #   nfr-generation.md, application-design-generation.md,
│   │   ├── functional-design-generation.md #   infrastructure-design-generation.md,
│   │   ├── story-N.M-code-generation.md # Bug-generation.md, enhancement-generation.md,
│   │   └── requirement-verification-questions.md
│   ├── behavior/                         #    ONE .feature per work unit — the only per-unit spec
│   │   ├── story-1.1.feature             #     SPEC (contract), stays in spec/ — NOT evidence
│   │   ├── story-1.2.feature
│   │   └── bug-PROJ-123.feature
│   ├── test-plans/                      #   ve Test Plan — one folder per work unit
│   │   └── Test-plan-<feature>-story-<n.m>/  #  integration/e2e/api/contract/security/perf/a11y steps
│   └── context-project/                  #    HUMAN-CURATED INPUT — two subfolders, nothing else.
│       ├── existing-knowledge/           #    HUMAN-AUTHORED — how the CURRENT system works.
│       └── new-references/               #    HUMAN-SUPPLIED — wireframes, mockups, UI/API specs.
│
├── reports/                               #   GENERATED OUTPUTS — evidence + review reports, never a spec
│   ├── unit-test-evidence/               #    per work unit
│   ├── behavior-test-evidence/           #    per unit: b1/ b2/ b3/
│   ├── api-contract-test-evidence/       #    per work unit
│   ├── eval-evidence/                    #    eval.json, eval-summary.md, static/, judge/ — per unit
│   ├── reviews/                          #    code-review reports (per story / all-stories)
│   ├── code-security-reviews/            #    security-review reports (dated)
│   └── ticket-summary/                   #    per-work-unit code-summary docs (story/bug/enh -summary.md)
│
├── runtime-artifacts/                     #   SESSION STATE + tool caches, recreated fresh each cycle
│   ├── audit.md                          #    complete audit trail of decisions and stages
│   ├── aire-state.md                     #    Story Tracker, phases done, base branch, resumability
│   └── (.mypy_cache/, .ruff_cache/, Playwright exec files, … — root tool caches)
│
├── .github/workflows/
│   └── agentic-eval-pipeline.yml         #  GENERATED for this project by ci-pipeline-generation.md
│
├── aire-workflow/                   #   THE FRAMEWORK ITSELF (this directory)
│   ├── aire-workflow-diagram.md                  #    End-to-end flow diagrams for every cycle type
│   ├── common/                           #    Cross-cutting rules loaded by every stage
│   ├── planning/                         #    Planning-phase stage rules
│   ├── implementation/                   #    Implementation-phase stage rules
│   ├── workflows/                        #    Keyword-triggered workflows (dev-implement, …)
│   ├── agents/                           #    Sub-agent procedures
│   └── extensions/                       #    Opt-in and mandatory rule extensions
│
├── aire-archives/                        #  Closed release cycles (archive-epic skill)
│   └── epics|bugs|enhancements/<ID>-<name>/
│       ├── spec/                        #    EXACT MIRROR of the live spec/ at cycle close —
│       │                                 #    all docs, every work-unit .feature, context-project,
│       │                                 #    new-references. One `cp -R`, no unpacking.
│       ├── reports/                      #    EXACT MIRROR of the live reports/ (generated outputs)
│       ├── runtime-artifacts/            #    EXACT MIRROR of runtime-artifacts/ (audit.md, aire-state.md)
│       └── archive-manifest.md
│
├── playwright.config.*                   # Only when the Playwright extension is enabled
├── .mcp.json                             # MCP servers — incl. the Helix MCP for Atlas access
└── CLAUDE.md                             # Repo guardrails — the agent reads this first
```

---

## 🔴 CRITICAL PLACEMENT RULES

1. **ALL application code lives in `src/`.** Greenfield and brownfield alike. If a brownfield repo
   keeps its code somewhere else, see "Brownfield reconciliation" below — never silently write new
   code into a second location.
2. **`spec/` is documentation and specification only.** Never a `.ts`, `.py`, `.java` or any other
   source file. There is **no `aire-docs/` layer** — `spec/` has exactly four subfolders plus
   `behavior.feature` at its root: **`plans/`** (all planning + design docs as flat files —
   `architecture.md`, `atlas-deep-dive.md` + the flat RE docs from Atlas, `requirements.md`, `stories.md`,
   `personas.md`, `epic-brief.md`, `dependency-graph.yml`, `functional-design.md`, `nfr.md`,
   `infrastructure-design.md`, `application-design.md`), **`spec-generation/`** (the `*-generation.md`
   plan / clarifying-question files), **`behavior/`** (one `.feature` per work unit), **`test-plans/`**
   (ve manual test plans), and
   **`context-project/`** — the single human-curated input folder, which has exactly two subfolders:
   `existing-knowledge/` (how the CURRENT system works) and `new-references/` (wireframes, mockups,
   API specs defining the target). 🔴 There is no `context-references/` at the top level — both live
   inside `context-project/`. The framework **creates the folders and reads them only at a path the
   user explicitly supplies** — it never auto-populates them and never auto-scans them. They are
   cross-cycle: `archive-epic`'s option-A reset preserves them in place. The one apparent exception, `<work-unit>.feature`, is a *specification* written in
   Gherkin; its executable step definitions live in `tests/behavior/steps/`.
3. **`spec/plans/architecture.md` is the architecture source of truth, and there is exactly one.**
   🔴 A work unit never gets its own architecture document — it reads the relevant section of this
   one. The blocking J1 rubric is derived from its Section 10 and from nothing else.
   3b. **One `.feature` per work unit is the ONLY per-unit spec file**, under
   `spec/behavior/`. No per-story requirements, architecture,
   constraints or deep-dive documents — that information is already authoritative in
   `stories.md`, `requirements.md`, `architecture.md` and `tests/.evals/config.json`, and copying it per
   story only creates something that can drift.
4. **Test code lives in `tests/`, never in `src/`** unless the stack's own convention is co-location
   (Go `_test.go`, Rust `#[cfg(test)]`), in which case follow the stack.
   4a. 🔴 **HARD RULE — ALL unit tests live under `tests/unit/`, with no exceptions and no sibling
   folders.** This includes UI/component tests (RTL, jsdom, Enzyme, Vue Test Utils, etc.) — a
   component-testing baseline or guard-test suite is still a unit test and nests under the mirrored
   `tests/unit/<area>/` path (e.g. `tests/unit/components/`), never a new top-level folder such as
   `tests/components/`. "Mirrors `src/`" constrains the *parent path*, not the file count — a suite
   that intentionally covers many `src/` modules together (a baseline/guard suite) is still placed at
   the mirrored path for the area it covers, not exempted into a new root-level folder for being
   grouped. There is no ambiguity to resolve here at generation time: if it is a unit test, it goes in
   `tests/unit/`.
   4b. 🔴 **HARD RULE — API & Contract Testing Gate output (`code-generation.md` Step 11a.5) lives
   ONLY in `tests/api/`.** These are not unit tests (Step 11a) — they call real endpoints — so they
   never go in `tests/unit/`, and they never get created ad hoc at another path. Organize by endpoint
   or resource group, not mirrored 1:1 from `src/`.
   4c. 🔴 **Rules 4a/4b are mechanically enforced, not merely narrated.** The **Test Placement
   Verification Gate** (`code-generation.md` Step 11a.6, `SH-LOOP-12` in `workflows/dev-implement.md`
   Step 6.3) runs `tests/.evals/scripts/check-test-placement.*` — a deterministic script, generated
   once per project per `common/ci-pipeline-generation.md` Section 4.0.7 — against this story's diff on
   every `dev-implement` run, and CI re-runs the same script on every PR. A misplaced test file is a
   gate failure, capped at 3 self-healing attempts, never a silent drift left for a later cleanup.
5. **Generated outputs are not specifications.** Raw tool output and review reports go under the
   top-level `reports/` root (`reports/unit-test-evidence/`, `reports/behavior-test-evidence/`,
   `reports/api-contract-test-evidence/`, `reports/eval-evidence/`, `reports/reviews/`,
   `reports/code-security-reviews/`, `reports/ticket-summary/`), never into `spec/` and never into a
   design or requirements document. The `.feature` contracts under `spec/behavior/` are
   specifications, not outputs, and stay in `spec/`.
6. **Never write outside these roots.** No stray files at the workspace root; no code in
   `spec/`; no docs in `src/`.

---

## 🔴 ARTIFACT OWNERSHIP — create if missing, never regenerate

**This table is the single authority on which branch writes each generated artifact, and what to do
when it is absent.**

**The rule in one line: if it exists, use it as-is. If it does not exist, create it on the cycle
branch. Nothing is ever pushed to the base branch.**

| Path                                            | Written on       | If MISSING                                     |
| ----------------------------------------------- | ---------------- | ---------------------------------------------- |
| `.github/workflows/agentic-eval-pipeline.yml` | cycle branch     | **Create it** (deterministically)        |
| `tests/.evals/config.json`                          | cycle branch     | **Create it**|
| `tests/.evals/scripts/**`                           | cycle branch     | **Create it**|
| `tests/.evals/behavior/**` (Containerfile, run.sh)  | cycle branch     | **Create it**|
| `tests/.evals/rubrics/security-rubric.json`         | cycle branch     | **Create it**|
| `tests/.evals/rubrics/architecture-rubric.json`     | cycle branch     | Derive from`spec/plans/architecture.md` Section 10 |
| `spec/**`                                     | cycle branch     | Generate during the cycle                      |
| `reports/**` (generated evidence)             | work-unit branch | Written during code generation / gate runs     |
| `runtime-artifacts/{audit.md,aire-state.md}`  | cycle branch     | Created by Workspace Detection at cycle start  |
| `src/**`, `tests/**`                        | work-unit branch | Generate during code generation                |
| `.gitignore`'s `tests/.evals/_run/` entry     | cycle branch     | **Add it** if the entry is missing — never overwrite the rest of an existing `.gitignore` |
| `tests/.evals/ci-manifest.d/<work-unit-key>.json` | **work-unit branch** | **Create it** — one NEW file per work unit, written ONLY by that unit at the end of its own run (`common/ci-pipeline-generation.md` Section 4.0f) |

**"Cycle branch"** = the epic branch for an epic cycle, the bug branch for a bug cycle, the
enhancement branch for an enhancement cycle.

🔴 **`tests/.evals/_run/` is CI-local scratch state, never committed** (`common/ci-pipeline-generation.md`
Section 4.0e) — it holds the per-run `failed-gates.txt`, `*.status` files and the self-repair attempt
counter, all of which must be purged and freshly rewritten by every single run, local or CI. This is
the ONE exception to "reports/eval-evidence/ is tracked" (Section 5.3 of `common/ci-pipeline-generation.md`)
— that directory stays committed as part of a story's own evidence trail; `tests/.evals/_run/` never is.
`auto-fix-agent.*`'s `git add -A` must never be allowed to stage it, which is exactly what this
`.gitignore` entry prevents.

🔴 **`tests/.evals/ci-manifest.d/<work-unit-key>.json` is the ONE row in this table not written on the
cycle branch** — it is **append-a-new-file** territory, written on the **work-unit branch** by the story,
bug, or enhancement that established the stack facts it records. This is what keeps two parallel
`dev-implement` sessions (Step 1.75) conflict-free on CI configuration specifically: neither
`tests/.evals/config.json` nor another unit's fragment is ever touched by a different work unit. Section
2.1.1's "present → leave it completely alone" rule stays exactly as written for the REST of
`tests/.evals/` — this directory is the one, narrow exception, and only because a new file with a unique
name is being added, never an existing one edited.

### Why nothing is pushed to base

**GitHub runs a `pull_request` workflow from the HEAD branch, not the base.** So the pipeline only
has to exist on the branch raising the PR:

| PR                 | Head branch has the workflow because                       | CI runs? |
| ------------------ | ---------------------------------------------------------- | -------- |
| story → epic      | story branches are cut from the epic branch                |        |
| ve → epic/bug/enh | cut from the cycle branch                                  |        |
| epic → main       | the epic branch created it                                 |        |
| bug → main        | the bug cycle created it on the bug branch                 |        |
| enh → main        | the enhancement cycle created it on the enhancement branch |        |

**Base ends up with it anyway, for free** — the cycle's own PR diff includes
`.github/workflows/agentic-eval-pipeline.yml` and `tests/.evals/**`, so merging the cycle lands them on
base. The next cycle then branches from base, finds them present, and leaves them alone.

🔴 **Never push these files directly to the base branch, and never raise a separate `[CI]` PR for
them.** They ride in with the cycle that created them.

### The two rules that make this conflict-free

**1. 🔴 PRESENT → USE AS-IS. Never regenerate, never "refresh", never "upgrade".**
If the file exists — created earlier in this cycle, or inherited by branching from base — it is
correct by definition. The repo's own standards win. Regenerating an existing file is what produces
merge conflicts, and it is forbidden regardless of how stale the file looks. To *change* one
deliberately, do it as an explicit, announced edit and say why.

**2. 🔴 MISSING → CREATE IT on the cycle branch, then move on.**
An absent bootstrap artifact is **never a reason to halt the cycle**. Generate it from the canonical
template, commit it with the cycle's other artifacts, and continue. The gates work immediately.

🔴 **Never stop a cycle because base has not been bootstrapped.** The framework's job is to create
that infrastructure, not to wait for it.

### 🔴 Why concurrent cycles do not collide: DETERMINISM

Two cycles running against an unbootstrapped base will both create these files, and both will merge
into base. That is safe **only if both produce byte-identical content**, so generation must be
deterministic:

- **No timestamps, run ids, hostnames or absolute paths** anywhere in the file.
- **Stable ordering** — JSON keys in the canonical order shown in the template, arrays sorted.
- **Values from fixed sources only** — the template, and facts read from the repo (detected stack,
  resolved code root). Never a value that varies between two runs on the same repo.
- **Two-space JSON indent**, trailing newline, LF endings.

A file generated twice from the same repo state must be identical. If it is not, that is a defect in
the generator — fix the non-determinism rather than restricting who may write the file.

### One thing that IS a repo setting, not a file

If the team wants "CI must pass before merge" **enforced**, that is GitHub **branch protection** with
the job name as a required check — configured once on the repository, not something any branch can
carry. Name it in the completion announcement so the user can set it; do not attempt it automatically.

---

## Brownfield reconciliation — when existing code is not in `src/`

Detected at Workspace Detection. Do **not** mass-move an existing tree; that produces an
unreviewable diff and breaks every import in the repo.

| Situation                                                              | What to do                                                                                                                                                                                    |
| ---------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Existing code already in`src/`                                       | Nothing to do. Continue.                                                                                                                                                                      |
| Existing code in a single other root (`app/`, `lib/`, `server/`) | **Record it** in `runtime-artifacts/aire-state.md` under `## Code Root` and treat that directory as `src/` for the whole cycle. Announce it. Every rule that says `src/` means the recorded root. |
| Monorepo with several package roots                                    | Record each in`## Code Root` as a list. New code goes into the package the work unit belongs to, at that package's own `src/`.                                                            |

🔴 **ENUMERATING a monorepo's package roots — do not eyeball it.** `## Code Root` is what Section 3 of
`common/ci-pipeline-generation.md` turns into `ci.roots[]`, and a package missing from this list gets
no root, so it is never installed, built, tested or gated — **silently**, because diff-scoping reports
an absent root exactly like an untouched one. Read the repo's own workspace declaration rather than
scanning directories:

| Ecosystem | Where the package list is declared |
|---|---|
| npm / yarn / pnpm | `workspaces` in the root `package.json`, or `packages:` in `pnpm-workspace.yaml` |
| Maven | `<modules>` in the aggregator `pom.xml` (recursively — modules may declare their own) |
| Gradle | `include(...)` in `settings.gradle` / `settings.gradle.kts` |
| Go | `use (...)` in `go.work` |
| .NET | the project list in the `.sln` |
| Python | path/editable installs (`-e ../pkg`, `path = "../pkg"`), or a `packages/*` convention |
| Nx / Turborepo / Lerna | `nx.json` / `turbo.json` / `lerna.json` project globs |

Record EVERY package the declaration names. If a package is deliberately excluded, record why — an
unexplained omission is indistinguishable from an oversight, and its cost is an entire module outside
CI for the life of the repo.
| No discernible code root (files loose at repo root)                    | Create`src/`, put **only new** code there, and record it. Leave existing files alone.                                                                                                 |

🔴 Record the decision once, in `runtime-artifacts/aire-state.md`, and never re-derive it per story — an inconsistent
code root across stories is worse than a non-standard one.

```markdown
## Code Root
- **Type**: single | monorepo | new
- **Path(s)**: src/ | app/ | packages/api/src, packages/web/src
- **Recorded**: 2026-08-26T10:14:00Z
- **Note**: existing tree left in place; `src/` semantics map to `app/` for this repo
```
