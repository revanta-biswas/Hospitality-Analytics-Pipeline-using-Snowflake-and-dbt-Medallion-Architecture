
# Playwright Test Automation (orchestrates Playwright's OWN official Test Agents)

**Purpose**: For **ONE story** whose manual Test Plan plan already exists and is Approved,
drive Playwright's own official **Test Agents** — Planner, Generator, Healer, installed via
`npx playwright init-agents --loop=claude` — scoped to that story's **UI-relevant** manual test cases,
through:

```
SEED TEST GATE  →  PLANNER (real agent)  →   USER APPROVAL GATE  →  GENERATOR (real agent)  →  LOCAL EXECUTION (headed)  →  HEALER (real agent)
```

**🔴 THIS FILE DOES NOT DEFINE ITS OWN PLANNER/GENERATOR/HEALER LOGIC.** Those three agents are
Playwright's own, shipped via `npx playwright init-agents --loop=claude` as real, invocable Claude
Code subagents at `.claude/agents/playwright-test-{planner,generator,healer}.md`, backed by the
`playwright-test` MCP server (`.mcp.json`). This file's job is **orchestration only**: gate
prerequisites, hand the right context to the real Planner, gate the human approval the framework
requires, hand the approved plan to the real Generator, run the tests, and hand failures to the real
Healer. Do not re-implement what those agents already do.

**🔴 UI/BROWSER ONLY.** The shipped Generator and Planner agents carry **only** browser MCP tools
(`browser_click`, `browser_navigate`, `browser_snapshot`, etc.) — no `request`-fixture or API tooling
exists in them. Backend/API test cases from the manual plan are **out of scope** for this extension
and remain manual-only, full stop. Do not invent a parallel API-automation mechanism here.

**Owner**: ve-adjacent. Loaded and executed by the **`/playwright-implement` skill**
(`aire-workflow/agents/playwright-implement-agent.md`) for a **post-merge, on-demand** run against the
integration branch, gated on both the dev's and ve's PRs having already merged (Step 2a).

🔴 **A SECOND caller now exists — and it INVOKES the same skill rather than copying it.**
`implementation/code-generation.md` Step 11d (the Playwright UI Automation Gate inside `dev-implement` /
`bug-fix-implement` / `enhancement-implement`) invokes the **`playwright-implement` skill** via the
Skill tool with **`mode: workflow`**, automatically and pre-PR, whenever a work unit's own plan touches
UI. WORKFLOW MODE is defined once, in `agents/playwright-implement-agent.md`'s **Mode Detection**
table; in short it skips the story-picker, the both-merges gate, the integration-branch checkout, the
Step 2 Approval Gate and the Step 12 Push Gate, auto-derives the Step 0d seed, starts and tears down
the app itself, still runs **`--headed` exactly as standalone does** (the developer is at their
machine and watching the story they just built is the point), and treats a `test.fixme()` outcome as a
still-failing gate rather than an advisory flag — its artifacts ride the work unit's own commit.
🔴 **Nothing about the Planner/Generator/Healer mechanics below changes between modes.**

The two callers do not compete: the automatic WORKFLOW MODE run happens first, pre-merge;
`/playwright-implement` remains available standalone afterward for a story this gate skipped (no UI at
plan time, later found to need it) or for re-automation after the fact — and finds
`tests/e2e/<story-slug>/` already populated, applying its normal refresh-or-stop convention.

**🔴 ADDITIVE, NOT A REPLACEMENT.** `test-plan.md` / `/ve-implement` keep producing manual,
black-box, human-executable test steps exactly as today. This file's only input is the **finished,
Approved** manual artifacts for UI-relevant cases; it never asks `/ve-implement` to behave
differently and never edits its output files.

**🔴 Always mandatory — no opt-in, no gate**: per CLAUDE.md, this extension is loaded and enforced
for EVERY project like Security Baseline. `runtime-artifacts/aire-state.md`'s `## Extension
Configuration` table carries a **Playwright Test Automation** row with `Enabled = Yes`, recorded
automatically at workflow start — never asked as a question, never left to the user to decide. If
that row is somehow absent or reads `No` (e.g. a stale/legacy project state), treat it as drift to
correct — set it to `Yes` — rather than a reason to refuse running.

---

## Prerequisites

- The target story has an Approved Test Plan plan. **There is no file literally named
  `test-plan.md` generated per story** — that's the rule file
  (`aire-workflow/implementation/test-plan.md`), not an artifact. Check instead:
  1. `spec/test-plans/<TICKET-ID>-<title>/` exists and contains whichever of the actual generated
     artifacts apply per that rule's own Step 2 applicability table:
     `test-plan-summary.md`, `e2e-test-steps.md`, `integration-test-steps.md`,
     `api-test-steps.md`, `contract-test-steps.md`, `security-test-steps.md`,
     `performance-test-steps.md`, `accessibility-test-steps.md`.
  2. **The Approval decision itself lives only in `runtime-artifacts/audit.md`** — find that story's
     `/ve-implement` run entry (`**Context**: /ve-implement skill — Test Plan
     (build-and-test.md)`) and confirm its `**Approve / Request Changes checkpoint**` field reads
     `Approved`. `test-plan-summary.md` itself does not carry an explicit approval field — do
     not infer approval from the summary's mere existence or from its "Open Questions" being empty.
  3. If `runtime-artifacts/audit.md` shows no Approved checkpoint for this story (or you can't find one), **stop** and
     tell the user this story's Test Plan plan needs to be Approved first via `/ve-implement`
     — do not proceed as if it were approved.
- The Playwright Test Automation extension is `Enabled`.
- No dependency on the DEV's code, branch, PR, or merge state to run the **Planner** phase (it explores
  the live local frontend, not the app's source). Generator/Execution/Healer also need that same
  running local instance — never a deployed environment, same doctrine as `test-plan.md`.

---

## Inputs (read these)
build
| # | Source | What it gives you |
|---|--------|-------------------|
| 1 | `spec/test-plans/<TICKET-ID>-<title>/*.md` (e2e, integration, security, accessibility — whichever exist) | The manual test cases the real Planner is scoped to. **Filter to UI-relevant cases only** before handing them over — see Step 1 |
| 2 | `spec/test-plans/<TICKET-ID>-<title>/test-plan-summary.md` | AC → test case coverage, to reconcile automated vs. remaining-manual coverage afterward |
| 3 | `runtime-artifacts/aire-state.md` | `## Story Tracker`, `## Tracker`, `## Branching`, `## Extension Configuration` |
| 4 | `tests/e2e/seed.spec.ts` (inside `<playwright-root>/tests/e2e/`, matching `testDir` — Playwright's own convention, ONE shared file, extended over time, never per-story) | The environment bootstrap the real Planner/Generator run against |
| 5 | `tests/playwright-specs/` (under `<playwright-root>/tests/` — AIRE's chosen location, relocated from Playwright's own default bare `specs/`, see Step 0a) | Where the real Planner saves its markdown plan (`planner_save_plan`) |
| 6 | The **live local frontend**, once the Prerequisite Gate passes | The real DOM/selectors — the manual plan never contains these (black-box, by design); only the real Planner/Generator/Healer agents (via their MCP browser tools) resolve them, never this orchestrating file |

---

## Step -1: The Playwright Project Root Is ALWAYS the True Workspace Root — Never a Subdirectory

**🔴 CORRECTED — a previous version of this file resolved a monorepo subdirectory (e.g. `frontend/`)
as `<playwright-root>` and installed everything there. That was wrong and is now fixed: it silently
broke subagent invocation, because Claude Code only ever scans `.claude/agents/*.md` and `.mcp.json`
at the actual project root it was launched from — the same directory `spec/` lives in. A
nested `frontend/.claude/agents/` is invisible to the session no matter how many times you restart.**

`<playwright-root>` = the true workspace root, **always**, in every project shape including
monorepos with `frontend/`/`backend/` subdirectories. Do not scan for or ask about candidate
subdirectories — there is no decision to make here.

- `playwright.config.ts`'s `baseURL` (not physical co-location) is what points Playwright at the
  running app — e.g. `http://localhost:3000` for a frontend that happens to live in `frontend/`.
  Playwright does not need to sit inside the app's own package to test it over HTTP/the browser.
- If the workspace root has no `package.json` yet, `npm i -D @playwright/test` (see Step 0a — never
  the interactive `npm init playwright@latest`) creates one there — this is a normal, independent
  root-level tooling package and does not conflict with `frontend/`'s or `backend/`'s own
  `package.json`.
- If a prior run of this extension mistakenly installed `.claude/agents/`, `.mcp.json`,
  `seed.spec.ts`, or `tests/playwright-specs/` inside a subdirectory (from before this correction),
  **do not just leave it there and add a second copy at root** — tell the user to move/recreate that
  scaffolding at the true workspace root, then restart the Claude Code session once so it picks up the
  corrected location.

---

## Output Locations (Playwright's own repo-root conventions, with `specs/` renamed and relocated by AIRE — see Step 0a)

```
<playwright-root>/                                   # the TRUE workspace root — same directory as spec/ — NEVER a subdirectory, even in a monorepo
├── playwright.config.ts                          # MUST set testDir: './tests/e2e' — seed and every generated spec live under tests/e2e/
├── .mcp.json                                    # playwright-test MCP server (from init-agents)
├── .claude/agents/
│   ├── playwright-test-planner.md               # installed verbatim by init-agents — never edited
│   ├── playwright-test-generator.md              #   "
│   └── playwright-test-healer.md                 #   "
└── tests/
    ├── playwright-specs/                          # AIRE's renamed/relocated home for Playwright's plan output (Playwright itself always scaffolds a bare `specs/` at root — Step 0a auto-relocates it here)
    │   └── <story-slug>.md                       # this story's Planner output (e.g. AT-898-training-feedback-rating-widget.md)
    └── e2e/                                        # testDir — matches common/directory-structure.md
        ├── seed.spec.ts                            # ONE shared seed, extended across stories, never per-story
        └── <story-slug>/
            └── <test-name-kebab>.spec.ts        # this story's Generator output, one file per scenario

spec/test-plans/<TICKET-ID>-<title-kebab>/        # DOCS — reporting only, no code
└── automation-summary.md                          # cross-reference to tests/playwright-specs/<story-slug>.md + tests/e2e/<story-slug>/, AC coverage, healer outcome
```

**🔴 Note — `tests/playwright-specs/` is OUTSIDE `testDir` (`./tests/e2e`) on purpose.** These are markdown
plan files, never `.spec.ts` test files, so Playwright's test runner never scans them and this
placement cannot conflict with test discovery. Only actual `.spec.ts` files (`seed.spec.ts`,
generated specs) must stay inside `testDir`.

**🔴 CONFIRMED INCIDENT — `seed.spec.ts` at the bare repo root (outside `testDir`) is invisible to
`npx playwright test` and caused a real "Playwright Test did not expect test() to be called here"
failure.** `init-agents` scaffolds `seed.spec.ts` at whatever directory it's run from, and
`create-playwright`'s default `playwright.config.ts` sets `testDir: './tests'` — if `seed.spec.ts`
ends up outside that directory, it's orphaned relative to the actual test project even though it
still exists on disk. **`seed.spec.ts` MUST live at `tests/e2e/seed.spec.ts`, matching `testDir`.** If it
is ever found at bare `<playwright-root>/seed.spec.ts` instead, move it into `tests/` before doing
anything else — do not leave two copies, and do not assume the bare-root one is the canonical one.

- `<story-slug>` = the same kebab-case title used in the story's `spec/test-plans/<TICKET-ID>-<title>/`
  folder, so the two are trivially cross-referenced without duplicating naming conventions.
- `tests/e2e/seed.spec.ts` and `tests/playwright-specs/` are **never** per-story — they are shared,
  repo-wide files. A story's Planner run may **extend** `tests/e2e/seed.spec.ts` (e.g. add a new
  login helper) but never overwrites another story's setup out of it.
- If `tests/playwright-specs/<story-slug>.md` or `tests/e2e/<story-slug>/` already exists, say so and
  ask whether to **refresh** (re-run Planner/Generator) or **stop** — same convention as
  `test-plan.md`.

---

## Step 0: Prerequisite Gate (blocking — MANDATORY STOP if any check fails)

### Step 0a — Playwright + its official Claude agents installed

```bash
test -f package.json && grep -q '"@playwright/test"' package.json    # base Playwright
test -f .claude/agents/playwright-test-planner.md                     # agents scaffolded
test -f .mcp.json && grep -q '"playwright-test"' .mcp.json            # MCP server registered
```
- **Base Playwright missing** → confirm-first, then run (verified non-interactive — do **NOT** use
  `npm init playwright@latest` bare; that command is an **interactive wizard** — language choice,
  test folder, GitHub Actions, browser download prompts — and hangs/errors when run through a
  non-interactive shell, which is how this framework always invokes it):
  ```bash
  npm i -D @playwright/test && npx playwright install
  ```
  This installs the dependency and downloads browser binaries with no prompts. It does **not** create
  `playwright.config.ts` — that's fine, Step 3 (Generator) creates/extends it itself. Do not
  additionally run `create-playwright`/`npm init playwright@latest` — one non-interactive path only.
- **Agents/MCP config missing** → confirm-first, then run (from `<playwright-root>`, resolved in
  Step -1):
  ```bash
  cd <playwright-root> && npx playwright init-agents --loop=claude
  ```
  This creates `.claude/agents/playwright-test-{planner,generator,healer}.md`, `.mcp.json`,
  `seed.spec.ts`, and `specs/README.md` inside `<playwright-root>` — **never edit the three agent
  definition files**; they are Playwright's own and get regenerated by re-running this command when
  Playwright itself is updated. It does **not** clobber a pre-existing `seed.spec.ts` (leaves it
  untouched if already present at `tests/e2e/seed.spec.ts`).
- **🔴 CREATE THE PLAN DIRECTORY, AND AUTO-RELOCATE `specs/README.md` — UNCONDITIONALLY, on EVERY run
  of this gate.** 🔴 Step 1 below is **not** a precondition of this bullet: run it whether `init-agents`
  just ran, was already present, or never needed to run at all. It was previously written as a
  side-effect of `init-agents`, which meant that on any repo where the agents were already scaffolded
  the `mkdir` silently never executed — and `tests/playwright-specs/` is created **nowhere else in this
  framework** (the same "every directory written to is created first" rule `ci-pipeline-generation.md`
  V12 enforces for CI scripts). `init-agents` is Playwright's own third-party command; it always writes
  `specs/README.md` at the bare `<playwright-root>/specs/` and there is no flag to point it elsewhere,
  and AIRE's convention is `tests/playwright-specs/`. So, automatically — no confirmation needed, it's
  just Playwright's own placeholder README, never story content:
  1. `mkdir -p tests/playwright-specs`  ← 🔴 ALWAYS, every run, before the Planner is invoked
  2. If `specs/README.md` exists at bare root, move it to `tests/playwright-specs/README.md`
     (overwrite is fine — it's Playwright's static boilerplate, identical every time).
  3. Remove the now-empty bare `specs/` directory at root (only if it's empty — never delete it if a
     story's plan `.md` somehow ended up there from an older run; move that file into
     `tests/playwright-specs/` instead and tell the user).
  4. Log this relocation once in `runtime-artifacts/audit.md` the first time it happens for a project.
- **🔴 CONFIRMED DESTRUCTIVE BEHAVIOR — `.mcp.json` is fully overwritten, not merged.** If
  `.mcp.json` already exists with OTHER MCP servers configured, `init-agents` replaces the whole file
  with just the `playwright-test` entry, silently deleting the others. Before running it:
  1. If `.mcp.json` exists, `Read` it and keep its current `mcpServers` content in memory.
  2. Run `npx playwright init-agents --loop=claude`.
  3. If step 1 found other servers, `Edit`/`Write` `.mcp.json` back to a merged form — the
     `playwright-test` entry `init-agents` just wrote, plus every other server that was there before.
     Confirm the merge with the user before writing it back (this touches shared project
     config — do not silently assume the merge is correct).
  4. If `.mcp.json` didn't exist before, no merge is needed — proceed as-is.
- **🔴 IF `init-agents` JUST RAN IN THIS SESSION — HALT IMMEDIATELY AND ASK FOR A SESSION RESTART.
  Both modes. Do NOT continue to Step 0b, do NOT invoke the Planner, do NOT wait for a subagent to
  fail first.** Claude Code loads MCP servers **at session start**, so the `playwright-test` server
  `init-agents` just wrote into `.mcp.json` is **not connected in this session** — the
  Planner/Generator/Healer subagents physically cannot work yet. This is a Claude Code host
  limitation, not something a rule file can route around, so the pause is the correct behaviour, not
  a failure. 🔴 **This halt is a sanctioned hard stop, NOT an approval prompt** — it is exactly the
  same class as the Retry-Limit halt: the run cannot physically continue, so asking nothing is not an
  option. It does not violate any workflow's "no prompts after the story key" rule.

  Emit this **verbatim**, substituting every bracketed value, then **STOP**:

  ```
   PLAYWRIGHT AGENTS INSTALLED — RESTART THIS SESSION TO CONTINUE

     Just installed:  [@playwright/test + browser binaries | Playwright's own Planner/Generator/Healer
                      subagents + the playwright-test MCP server | both]
     Work unit:       [Story N.M / TICKET-ID] — [title]
     Branch:          [current branch]

     Claude Code loads MCP servers at session start, so the `playwright-test` server just written to
     .mcp.json is NOT connected in this session yet. The Planner, Generator and Healer subagents
     cannot run until it is.

     🔴 Nothing is lost. [list what has already passed and is recorded in runtime-artifacts/audit.md].
        No commit, no push, no PR, and no tracker change has happened.

  ➡ NEXT ACTIONS:
     1⃣  Restart / reload this Claude Code session.
     2⃣  Re-invoke with the SAME work unit: [dev-implement | bug-fix-implement |
         enhancement-implement | /playwright-implement <story or TICKET-ID>]

     On resume it reads runtime-artifacts/audit.md, SKIPS every gate already recorded as passed, and
     picks up at the Planner — it does not redo the code, the earlier gates, or this install.

  🔴 Type the keyword EXACTLY as shown — any other phrasing is not a framework trigger.
  ```

  **On resume — do NOT restart this skill's flow from Step 0.** Re-read `runtime-artifacts/audit.md`
  for this work unit's run entry (Step 7 format) and skip every gate/check already logged there before
  the restart — Prerequisite Gate results (dependency/agent-scaffolding, local server, fixture-data
  checklist), the Seed Test Gate decision, and any scope decision (which manual cases are in/out of
  automation scope) all carry forward unchanged. Resume at the first step whose confirmation is NOT yet
  in `runtime-artifacts/audit.md` — normally the Planner (Step 1). In WORKFLOW MODE the invoking
  workflow likewise resumes at its Playwright gate, **not** at story selection or code generation. Only
  re-run an already-logged gate if the user says something changed (e.g. the local server is now down,
  or they want to revise the scope decision).

  **Reactive fallback (belt and braces)**: if the Planner/Generator/Healer are nonetheless invoked and
  report missing `mcp__playwright-test__*` tools, emit the same block and stop there — never work
  around it, and never fall back to hand-authoring (Rule 1b).
- **All present** → proceed, log in `runtime-artifacts/audit.md`. 🔴 **Still run the AUTO-RELOCATE step above** — its `mkdir -p tests/playwright-specs` is what creates the Planner's output directory, and it is NOT conditional on `init-agents` having just run.

#### 🔴 Step 0a in WORKFLOW MODE — "confirm-first" resolves to INSTALL, never to skip

The install actions above are **confirm-first**, which has a defined answer in each mode. Getting this
wrong is the single observed failure of this gate, so it is spelled out rather than implied:

| Mode | A missing dependency / agent scaffolding / MCP entry means |
|---|---|
| **STANDALONE** | Ask the user, then install on yes. |
| **WORKFLOW** | 🔴 **INSTALL IT AUTOMATICALLY — announced, never asked.** The invoking workflow has no approval gates, so "confirm-first" resolves to "proceed"; it NEVER resolves to "skip". Run `npm i -D @playwright/test && npx playwright install` and/or `npx playwright init-agents --loop=claude` exactly as written above, then continue the gate. |

🔴 **"The Planner/Generator/Healer agents are not installed" is an ERROR to fix, never a gap to
disclose.** It is the same class as `"gitleaks not installed"`, which `common/eval-framework.md`
Section 2.5.2 already rules an **ERROR, never `N/A`** — deferred setup is not an inapplicable check.
Installing them is a single non-interactive command that this step owns.

🔴 **A hand-authored `.spec.ts` is NOT a result of this gate.** If the real Generator subagent did not
write it, it does not count — exactly as `eval-framework.md` Section 2.5.2 rules a hand-written claim
out for D1–D7: *the gate is the TOOL's output, or it is ERROR; there is no third option.* Writing
Playwright specs by hand from the manual test plan, however faithfully, and disclosing it as a known
gap, is **not** a sanctioned outcome — it produces tests nobody generated from the live DOM, with
locators nobody verified against the running app, which is precisely what the Planner/Generator exist
to prevent.

🔴 **A prior run's disclosed gap is NEVER precedent.** "Stories 1.1 and 1.2 did it this way too" is a
reason to backfill those stories, not a licence to repeat it. Cite it as a defect, never as a pattern.

🔴 **The ONE genuine blocker** is the MCP-server-not-loaded case documented below (the newly written
`.mcp.json` not yet connected in this session). That is a **HALT** — tell the user to restart the
session and resume — never a reason to fall back to hand-authoring.

### Step 0b — Local frontend server up

```bash
curl -sf http://localhost:<FRONTEND_PORT> >/dev/null
```
- Port sourced from the story's manual plan **System Under Test** block — never guessed; mark
  ` TO CONFIRM` if undocumented.
- **Down** → **STOP**. Tell the user which command to run (read from the project's own
  README/`package.json` scripts — never invented). Do not silently background-start it.
- **Up** → proceed.

### Step 0c — Test data / fixture accounts seeded

Checklist extracted from every UI-relevant `Test data / accounts to seed` row across the story's
manual test files:

```markdown
 This story's UI test cases assume the following fixture state exists locally:
   - [account/state 1]
   Confirm this is seeded in your local DB? (yes / not yet /  some rows are already TO CONFIRM in the manual plan)
```
- **yes** → proceed. **not yet** → **STOP**, point at the project's own seeding docs (never invent one).

All three checks are re-verified before Step 4 (execution) and again by the real Healer's own
`test_run` step in Step 5.

---

## Step 0d: Seed Test Gate — the "Planner Gate"

Playwright's Planner needs `tests/e2e/seed.spec.ts` to bootstrap the environment (login state, starting
route) before it can explore anything. This is a **shared, repo-wide file** — check its current
content first.

1. **If `seed.spec.ts` already covers this story's starting state** (e.g. it already logs in as the
   role/persona this story's manual preconditions need) → skip to Step 1, no changes needed.
2. **Otherwise, attempt to derive what's missing** from the story's manual test files' `Preconditions`
   / `Test data` fields (e.g. `"Log in as Learner A"`, a base URL from the System Under Test block).
   Draft a **proposed addition** to `tests/e2e/seed.spec.ts` (or a proposed file, if none exists yet) covering
   just that login/navigation flow.
3. **Always present the draft for confirmation before writing it — this is the Planner Gate the user
   asked for** (🔴 **STANDALONE MODE only. In WORKFLOW MODE — `playwright-implement-agent.md` Mode
   Detection — auto-apply a confidently-derived draft, announced, never asked; and if it genuinely
   cannot be derived, HALT with a one-time request for the seed content rather than guessing a login
   flow silently**):
   ```markdown
    Seed Test Gate — tests/e2e/seed.spec.ts

   [existing content, if any]

   Proposed addition for this story's precondition ("Log in as Learner A"):
   ```ts
   [drafted steps]
   ```

    Confirm this addition, provide your own seed steps instead, or skip (Planner will start from
   whatever state tests/e2e/seed.spec.ts already reaches)?
   [Answer]:
   ```
4. **If confident derivation isn't possible** (ambiguous role, multiple distinct login flows implied,
   no clear precondition to anchor on) — **skip drafting entirely** and ask the user directly to
   supply or confirm the seed content. Never guess a login flow silently.
5. Once confirmed, append to (never blindly overwrite) `tests/e2e/seed.spec.ts` — it is reused and extended
   across every future story's `/playwright-implement` run, per Playwright's own convention.

---

## Step 1: PLANNER — Invoke Playwright's Real Planner Agent

**Filter first**: from the story's manual test files, select only the **UI-relevant** test cases —
e2e cases, accessibility cases, and any integration/security case whose observable check is entirely
in the browser (e.g. "widget renders read-only view" — automatable via UI; drop anything whose
check is fundamentally a raw HTTP call/response, e.g. an admin/manager list endpoint hit directly).
List explicitly, in your own tracking (not the plan itself), which manual cases were excluded as
backend/API-only — they stay manual-only.

Invoke the agent (via the Agent tool, `subagent_type: "playwright-test-planner"`) with a prompt that
hands it this story's manual plan as its **required scope** — do not let it explore unscoped:

```
Using tests/e2e/seed.spec.ts as your environment seed, explore <frontend base URL from System Under Test>.
Produce a comprehensive Playwright test plan that covers EXACTLY the following UI-relevant scenarios
(and no others) drawn from this story's approved manual Test Plan plan:

[paste each selected UI-relevant TC-[PLAN]-[nn]: title, preconditions, steps, expected result]

Save the plan via planner_save_plan to tests/playwright-specs/<story-slug>.md.
```

🔴 **Before invoking the Planner, assert `tests/playwright-specs/` exists** (`mkdir -p` it if not —
Step 0a owns this, but assert it here too; `planner_save_plan` is Playwright's own MCP tool and this
framework must not assume it creates directories).

🔴 **After the Planner completes, verify `tests/playwright-specs/<story-slug>.md` actually exists — and
have a remedy, not just a check.** If it is absent, look for the plan at Playwright's own default bare
`specs/` (its native convention, and where it lands if the target directory was missing), move it into
`tests/playwright-specs/`, and re-verify. Only if no plan file exists anywhere did the Planner genuinely
fail — report that as an ERROR and stop; never continue to the Generator without a real plan, and never
substitute one you wrote yourself.

The real Planner subagent does everything else itself (calls `planner_setup_page`, explores via
`browser_*` tools, calls `planner_save_plan`) — do not write the plan yourself, do not second-guess
its exploration.

---

## Step 2: USER APPROVAL GATE (this framework's addition — mandatory, hard stop)

Playwright's own shipped flow has no built-in human checkpoint between Planner and Generator. This
gate is **this framework's requirement**, layered on top.

🔴 **STANDALONE MODE only. In WORKFLOW MODE this gate is SKIPPED** (`playwright-implement-agent.md`
Mode Detection): the invoking implement workflow has no approval gates, so the Planner's plan is
auto-approved and the Generator runs immediately. Log
`Playwright plan auto-approved (workflow mode, no gate) — tests/playwright-specs/<story-slug>.md`
in `runtime-artifacts/audit.md` and proceed to Step 3. The compensating control is that the caller's own gate
requires every generated spec to actually PASS before code review, and any failure is remediated in
that same run.

```markdown
# 🧪 Playwright Test Plan Ready — [TICKET-ID] [Story title]

 Plan (Playwright Planner's own output): tests/playwright-specs/<story-slug>.md
 UI-relevant manual cases covered: [list of TC-IDs]
 Manual cases excluded as backend/API-only (stay manual-only): [list, or "none"]

 **Approve this plan, or request changes?**

   1)  Approve — hand this plan to the Generator agent
   2)  Request Changes — re-invoke the Planner with feedback, or hand-edit
      tests/playwright-specs/<story-slug>.md directly

[Answer]:
```
- **Request Changes** → either re-run Step 1 with the user's feedback folded into the prompt, or let
  the user hand-edit `tests/playwright-specs/<story-slug>.md` directly, then re-present this gate.
  Never proceed to Step 3 without an Approve landed here.
- **Approve** → proceed to Step 3. Log the approval (with session email) in `runtime-artifacts/audit.md`.

---

## Step 3: GENERATOR — Invoke Playwright's Real Generator Agent, Per Scenario

**🔴 STRICTLY SEQUENTIAL — never invoke multiple Generator calls in parallel, for any story, no
matter how many scenarios there are.** Each invocation spawns its own `run-test-mcp-server` process
and browser instance, and all of them write to the same `playwright.config.ts` and the same
`tests/e2e/<story-slug>/` directory. Running several at once is a confirmed, reproduced failure mode:
they race to bootstrap `playwright.config.ts` if it doesn't exist yet, none of them wins cleanly, and
the leftover `run-test-mcp-server` processes pile up (observed: 14 parallel calls left 16 zombie MCP
server processes still running and contending for the same files, blocking even a subsequent "solo"
retry until they were manually killed). One scenario, one Generator call, wait for it to finish,
**then** the next. The same rule applies to Planner (Step 1) and Healer (Step 5) invocations — never
run more than one Playwright subagent at a time in this extension, regardless of what other parts of
this environment support running agents in parallel.

For each top-level scenario in the Approved `tests/playwright-specs/<story-slug>.md`, **in sequence**, invoke the agent
(`subagent_type: "playwright-test-generator"`) using its own documented per-scenario contract:

```
<test-suite>[top-level scenario name from the plan]</test-suite>
<test-name>[scenario item name from the plan]</test-name>
<test-file>tests/e2e/<story-slug>/tc-[plan]-[nn]-<short-description-kebab>.spec.ts</test-file>
<seed-file>tests/e2e/seed.spec.ts</seed-file>
<body>[the scenario's steps + expected outcomes, verbatim from the approved plan]</body>
```

**🔴 Construct `<test-file>` yourself — never copy the Planner's own `**File:**` suggestion from
`tests/playwright-specs/<story-slug>.md` verbatim.** The Planner is inconsistent about including the TC-ID in its own
file-path suggestion (observed: some runs produce `tc-e2e-01-desktop-load.spec.ts`, others produce
`e2e-desktop-alignment.spec.ts` with no numbering at all), which breaks scannability once a story has
many specs. Always build the filename yourself as `tc-[plan]-[nn]-<short-description-kebab>.spec.ts`
(e.g. `tc-e2e-01-desktop-alignment.spec.ts`, `tc-a11y-03-keyboard-nav-order.spec.ts`) — `[plan]`/`[nn]`
from the manual test case's own `TC-[PLAN]-[nn]` ID, the description a short kebab summary of the
scenario. Content-level traceability (the TC-ID inside the `test()` title) is a good sign but not a
substitute for a consistently numbered filename.

The real Generator subagent does everything else itself (`generator_setup_page`, executes each step
live via `browser_*` tools, `generator_read_log`, `generator_write_test`) — do not write `.spec.ts`
content yourself.

---

## Step 3.5: Cross-Scenario Consistency Pass (MANDATORY, after ALL scenarios are generated)

**🔴 Each Generator invocation in Step 3 runs independently, with no visibility into sibling specs
generated for other scenarios in the same story.** This causes two concrete, observed failure modes
that must be checked for every time, not just when something looks wrong:

1. **Divergent locator strategies for the same UI element.** If scenario A discovers a fragile
   locator for some control (e.g. "first button with no text") and scenario B, generated later,
   discovers a more robust one for the *same* control (e.g. an icon-scoped selector), scenario A is
   never revisited — it keeps the fragile version. **Read every generated spec in
   `tests/e2e/<story-slug>/` together** and, for any UI element referenced in more than one file, reconcile
   to the single most robust strategy found across all of them (prefer role/label/testid/icon-scoped
   locators over positional ones like bare `.first()`).
2. **Leftover generic-template artifacts not grounded in this app.** A Generator invocation can
   introduce a selector or check that isn't actually derived from this app's live DOM (e.g. a
   framework-specific dev-tooling selector from an unrelated stack). Any assertion that isn't
   traceable to something actually observed on **this** app's live page during generation must be
   removed — grep each new spec for anything that looks like boilerplate rather than an app-specific
   finding, and cross-check suspicious ones against the app's real source if needed.

This is a plain read-and-edit pass over the files already written — it does not re-invoke the
Generator agent. Log what was reconciled/removed in `automation-summary.md` (Step 6) under a short
"Consistency Pass" note; if nothing needed fixing, say so explicitly rather than omitting the section.

---

## Step 4: LOCAL EXECUTION — Headed

Re-verify Step 0's checks, then (from `<playwright-root>`):
```bash
cd <playwright-root> && npx playwright test tests/e2e/<story-slug>/ --headed
```
A visible browser window opens for each test — this is the "open the instance in headed mode"
behavior. Capture pass/fail per spec for the summary; anything failing goes to Step 5.

🔴 **WORKFLOW MODE runs `--headed` too — this step is IDENTICAL in both modes.** The developer is at
their own machine while `dev-implement` runs, and watching the browser exercise the story they just
built is exactly the point; there is no reason to hide it. **The ONLY environment that runs headless
is CI**, and only because a GitHub runner has no display at all — that is a property of CI, never a
policy this framework applies locally.

**The one permitted local fallback**: if the machine genuinely has no display (a container or an SSH
session with no X server, proven by the run failing on a missing display — not assumed), fall back to
headless for that run, **record `"headed": false, "reason": "<the actual error>"` in the evidence
manifest**, and say so in the output. Never silently choose headless, and never make it the default.

---

## Step 5: HEALER — Invoke Playwright's Real Healer Agent

Invoke the agent (`subagent_type: "playwright-test-healer"`), pointing it at the failing test(s)
under `tests/e2e/<story-slug>/`. The real Healer subagent runs its own complete loop
(`test_run` → `test_debug` → inspect/patch → re-run until it passes, or marks `test.fixme()` with an
explanatory comment if it has high confidence the test is correct and the failure reflects a real app
issue) — **do not intervene in or shortcut that loop**, and do not add a separate retry cap of our
own on top of it; the shipped agent owns its own completion criteria.

If the Healer marks a test `test.fixme()`, treat that as a **candidate product defect signal** — flag
it in the summary and point the user at `raise-defect`. Never edit a `test.fixme()` back to passing
yourself; that decision belongs to the Healer agent and, ultimately, to the DEV/QA judgment on the
underlying app behavior.

---

## Step 6: Generate `automation-summary.md` and Present Completion

```markdown
# Playwright Automation Summary — [TICKET-ID] [Story title]

**Plan**: tests/playwright-specs/<story-slug>.md (Approved [date])
**Generated tests**: tests/e2e/<story-slug>/
**Generated**: [ISO 8601]   **AIRE VERSION**: [N]

## UI Test Cases Automated
| Manual TC | Generated spec | Result |
|-----------|-----------------|--------|

## Manual Cases Excluded (backend/API-only — out of scope for this extension)
| Manual TC | Reason |
|-----------|--------|

## Consistency Pass (Step 3.5)
[What was reconciled across specs (divergent locator strategies unified, generic-template artifacts
removed) — or "Nothing needed fixing" if the generated specs were already consistent.]

## Healer Outcomes
| Spec | Outcome | Notes |
|------|---------|-------|
|      | Passed after healing / test.fixme() — candidate defect | |

## AC Coverage (automated UI + remaining manual combined)
[n]/[n] acceptance criteria have ≥1 automated OR manual test case.  / 
```

Present completion with the same confirm-first Approve/Request-Changes checkpoint pattern as
`test-plan.md` Step 6, then Step 7 logs the run.

---

## Step 7: Log the Run in runtime-artifacts/audit.md

```markdown
## Playwright Automation (playwright-implement skill)
**Timestamp**: [ISO 8601 — real clock]
**User Email**: [current session email]
**User Input**: "[complete raw user input]"
**Story**: "[Story ID N.M] — [title] — [TICKET-ID link or local Story ID]"
**Seed Test Gate**: "[no change needed / addition confirmed / user supplied own seed]"
**Plan approval**: "[Approved / Request Changes → re-did [what] → re-approved]" — approver: [session email]
**UI cases automated**: "[n] of [n] manual UI cases"
**Excluded (backend/API-only)**: "[n] cases, remain manual-only"
**Execution**: "[pass]/[fail] before healing"
**Healer outcome**: "[n] healed to passing, [n] marked test.fixme() as candidate defects"
**Code location**: `tests/e2e/<story-slug>/`   **Plan location**: `tests/playwright-specs/<story-slug>.md`
**AI Response**: "[what was generated/changed]"
**Context**: `/playwright-implement` skill — Playwright Test Automation

---
```

---

## Critical Rules

1. **Orchestration only — never re-implement the Planner/Generator/Healer.** Their real definitions
   live at `.claude/agents/playwright-test-{planner,generator,healer}.md`, installed by
   `npx playwright init-agents --loop=claude`, and are never edited by this framework.
1b. 🔴 **"Never re-implement" includes never HAND-WRITING the output.** A `.spec.ts` this framework
   typed itself — however faithfully transcribed from the manual test plan — is **not** a result of
   this extension, and a `tests/playwright-specs/<story-slug>.md` this framework wrote instead of the
   Planner is not a plan. The gate is the real subagents' output or it is **ERROR**; there is no third
   option (`common/eval-framework.md` Section 2.5.2). Missing agents are **installed** (Step 0a), never
   worked around, never "disclosed as a gap" — and a prior story that did work around it is a defect
   to backfill, never precedent.
2. **UI/browser only.** No backend/API automation mechanism exists in this extension. Backend/API
   manual cases stay manual-only, reported not hidden.
3. **Additive, not a replacement** for `test-plan.md` / `/ve-implement`.
4. **Two mandatory human gates — in STANDALONE MODE**: the Seed Test Gate (Step 0d, for anything not
   already covered by the shared seed) and the Approval Gate (Step 2, on the Planner's own plan
   output). Neither is skippable there. 🔴 **In WORKFLOW MODE both are skipped by the invoking
   workflow's own authorization** (`agents/playwright-implement-agent.md` Mode Detection) — the seed
   auto-derives and the plan auto-approves — but **every verification step still runs**, and a failing
   spec still fails the caller's gate. Skipping an approval is never skipping a check.
5. **AIRE's convention, layered on Playwright's own agents**: ONE shared `tests/e2e/seed.spec.ts`, ONE
   `tests/playwright-specs/` folder (renamed and relocated from Playwright's own default bare
   `specs/` — the auto-relocate step in Step 0a runs every time `init-agents` is invoked, since that
   command has no flag to change where it drops its own `specs/README.md`), `tests/e2e/<story-slug>/`
   for generated specs. No per-story seed files.
6. **Never intervene inside the Healer's own loop** or impose a separate retry cap — it owns its
   completion criteria (pass, or `test.fixme()`).
7. **A `test.fixme()` from the Healer is a candidate product defect signal**, routed to
   `raise-defect` — never silently edited back to passing by this framework.
8. **Local execution only, never deployed** — same doctrine as `test-plan.md`. Runs `--headed`.
9. **Never touch Story Tracker or tracker status** — same rule as `ve-implement-agent.md`.
10. **Timestamps from a real clock, ISO 8601; `[N]` read live from `CLAUDE.md`'s canonical version
    line.**
11. **`<playwright-root>` is ALWAYS the true workspace root (Step -1), never a monorepo subdirectory**
    like `frontend/` — Claude Code only scans `.claude/agents/` and `.mcp.json` there. This is not a
    per-project judgment call; never install this scaffolding anywhere else.
12. **`.mcp.json` is overwritten, not merged, by `init-agents`** — always read and preserve any other
    configured MCP servers before running it, and confirm the merge with the user afterward.
13. **There is no file literally named `test-plan.md` generated per story.** Approval status
    lives only in `runtime-artifacts/audit.md`'s `/ve-implement` run entry, never in a file of that name
    and never inferred from `test-plan-summary.md`'s mere existence.
14. **Per-scenario Generator invocations have no memory of each other** (Step 3.5) — always run the
    cross-scenario consistency pass after all scenarios are generated; never assume independently
    generated specs are internally consistent with each other just because each one individually
    looked fine.
