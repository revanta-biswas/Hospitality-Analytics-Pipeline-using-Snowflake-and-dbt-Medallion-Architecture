# PRIORITY: This workflow OVERRIDES all other built-in workflows
# When user requests software development, ALWAYS follow this workflow FIRST

## AIRE Framework Version (SINGLE SOURCE OF TRUTH)
**AIRE Framework Version: 1.0**

Canonical version declaration. **Bump here FIRST** — every other file reads it at runtime and carries
only a `[N]`/`v[N]` placeholder, never the literal number, **EXCEPT the accuracy-critical files under
"Hardcoded version locations" below, which carry the literal version and MUST be updated manually on
every bump.**

**MANDATORY — version logging**: read it LIVE and stamp it on: the **welcome message**
(`common/welcome-message.md`) · every **runtime-artifacts/audit.md** entry's `**AIRE VERSION**:` field
· each created **tracker story** (`aire-v[N]` label + `Built with AIRE v[N]` footer) · every **commit**
(`AIRE-Version: [N]` trailer) · every **PR** (`aire-v[N]` label + `AIRE Framework: v[N]` in the body),
including ve's own test-docs PR. Wherever a rule file shows `[N]`/`v[N]`, substitute the value read
from this line at runtime.

## Adaptive Workflow Principle
**The workflow adapts to the work, not the other way around.** Assess needed stages from: user's
stated intent/clarity, codebase state, complexity/scope, risk/impact.

## MANDATORY: Rule Details Loading
**CRITICAL**: For any phase, read and use the relevant rule detail files from **`aire-workflow/`**.
Every rule-file reference below (e.g. `common/process-overview.md`) is relative to that directory.

**Common Rules — ALWAYS load at workflow start:**
- `common/process-overview.md` — workflow overview
- `common/session-continuity.md` — session resumption guidance
- `common/content-validation.md` — content validation requirements
- `common/question-format-guide.md` — question formatting rules
- `common/tracker-sync.md` — single source of truth for every tracker-specific command
- `common/directory-structure.md` — the five roots (`src/`, `tests/`, `spec/`, `reports/`,
  `tests/.evals/`) and where artifacts go
- `common/helix-atlas-integration.md` — how AIRE reaches **Atlas** via the **Helix MCP** to reuse
  existing-system truth instead of re-deriving it. **Blocking on brownfield/migration work.**
- `common/behavior-spec.md` — where Gherkin contracts live and the three-tier behaviour gate
- `common/eval-framework.md` — the D1–D7 static gates and **blocking** J1/J2 judge gates

**Loaded on demand (do NOT load at start):**
- `common/ci-pipeline-generation.md` — at the STOP CHECKPOINT, when the CI pipeline is generated
- `implementation/architecture-doc.md` — at the STOP CHECKPOINT, when `architecture.md` + rubric are written

## MANDATORY: Extensions Loading (Context-Optimized)
**CRITICAL**: At workflow start, scan `extensions/` recursively and load ONLY the lightweight
`*.opt-in.md` files — never a full rule file at this stage; that loads on demand, after the user opts
in during Requirements Analysis. An extension with no `*.opt-in.md` is always enforced — load its rules now.

- **Security Baseline is ALWAYS mandatory** — load `extensions/security/baseline/security-baseline.md`
  at workflow start for EVERY project, enforce as blocking. NEVER ask whether security applies; ignore
  any legacy opt-out in `## Extension Configuration`.
- **Playwright Test Automation is ALWAYS mandatory** — load
  `extensions/testing/playwright-automation/playwright-automation.md`; record `Enabled = Yes`.
- Enabled extension rules are **hard constraints**; non-compliance is a **blocking finding**. Rules
  irrelevant to the current stage are **N/A** (not blocking).
- Before enforcing any extension at ANY stage, check `Enabled` in `runtime-artifacts/aire-state.md`
  `## Extension Configuration`; skip disabled ones and log the skip. Default to enforced.

Full mechanics (loading order, deferred loading, enforcement, compliance summary): `common/extensions-loading.md`.

## MANDATORY: Content Validation
**CRITICAL**: Before creating ANY file, validate content per `common/content-validation.md`:
- Validate Mermaid diagram syntax
- Validate ASCII art diagrams (see `common/ascii-diagram-standards.md`)
- Escape special characters properly
- Provide text alternatives for complex visual content
- Test content parsing compatibility
- 🔴 **NEVER write the section-sign character "§" (U+00A7) in ANY file** — rule files, docs, specs,
  code, commit messages, PR bodies, tracker items. Write `Section 3` or just the number — "§" renders
  inconsistently across terminals, trackers and diff views.

## MANDATORY: Question Format
**CRITICAL**: Follow `common/question-format-guide.md` for all question formatting — multiple-choice
(A–E), the `[Answer]:` tag, answer validation and ambiguity resolution.

🔴 **Two questions are CHAT-ONLY and never get a question `.md` file**: the **Tracker Selection**
question (`common/tracker-sync.md`) and the **Context Opt-In** question
(`planning/workspace-detection.md` Step 4.7). Ask conversationally, persist only the ANSWER (to
`runtime-artifacts/aire-state.md` + `runtime-artifacts/audit.md`).

🔴 **The Section 4.1.2 CI/SonarQube setup gate (`common/ci-pipeline-generation.md`) is a THIRD, stricter
exception — never summarize it into a multiple-choice question, in a file or in chat.** Unlike the two
CHAT-ONLY questions above, it's a literal, multi-paragraph setup-instruction block (`claude
setup-token` steps, SonarCloud/Community steps, exact secret names, how to add them in GitHub) the user
must read and follow verbatim elsewhere. Compressing it — including via a multiple-choice tool —
silently deletes instructions the user needs. Emit it exactly as written in Section 4.1.2, in full, as
plain text; read the reply (`proceed`/`skip`/anything) as free text per Section 4.1.3, never a lettered choice.

## MANDATORY: Custom Welcome Message
**CRITICAL**: On ANY software development request, load `common/welcome-message.md` and display the
complete message — ONCE at workflow start; do NOT reload it later (saves context).

## MANDATORY: Audit Trail, Session Identity & Timestamps
Complete contract in `common/audit-logging.md` — load at workflow start. MANDATORY for EVERY workflow,
stage, agent and skill. Non-negotiables:

- **Log EVERY user input** with the **COMPLETE RAW INPUT** — never summarized/paraphrased — plus every
  approval prompt (before asking) and every response (after receiving).
- **Every `runtime-artifacts/audit.md` entry carries `**User Email**:`** — operator's email, read LIVE
  and silently from session context, never asked, never a name, recorded ONLY there. Local audit
  templates ADD fields to the base format; NEVER drop this one.
- **Every timestamp from a real clock** at write time, ISO 8601 (`YYYY-MM-DDTHH:MM:SSZ`), via EXACTLY
  ONE command — `date -u +%Y-%m-%dT%H:%M:%SZ` or `Get-Date -AsUTC -Format "yyyy-MM-ddTHH:mm:ssZ"`.
  Never estimated, incremented, or copied forward.
- **Append only, chronological, to the END** of `runtime-artifacts/audit.md`. 🔴 NEVER overwrite the
  file with its own contents plus additions — that duplicates the entire history.

# Adaptive Software Development Workflow

---

# PLANNING PHASE

**Purpose**: Planning, requirements gathering, architectural decisions. **Focus**: WHAT to build and WHY.

**Stages**:
- Workspace Detection (ALWAYS)
- Reverse Engineering (CONDITIONAL — Brownfield only)
- Requirements Analysis (ALWAYS — Adaptive depth)
- User Stories (ALWAYS — no questions on team size or creation mode: `team_size` fixed at 2, all
  stories generated at once; the generated story set requires explicit human approval — **GATE 1** —
  before push to the configured tracker, linked to the **Parent Epic** captured at workflow start)
- **Dependency Graph (ALWAYS — immediately after User Stories)** — records each story's `requires`
  dependencies; stories with no unfinished prerequisites are independently implementable in parallel
- Workflow Planning (ALWAYS)
- Application Design (CONDITIONAL)

## MANDATORY: Tracker Selection & Parent Epic Capture
aire asks the user ONCE which tracker to use — **JIRA**, **ADO**, **GITHUB**, or **LOCAL** (no external
tracker; local Story Tracker is authoritative) — BEFORE Parent Epic Capture. **Skip and reuse** if
`## Tracker` already exists (resumed project) — never re-ask. **NEVER infer/auto-select the tracker
from a pasted link (e.g. a Jira Epic URL) — ALWAYS ask and wait for the answer**, even if obvious. Full
mechanics: `common/tracker-sync.md` Section 1 — every tracker-facing rule dispatches on `## Tracker` →
`Type`. **LOCAL is fully complete** — zero external calls, ever (Section 12).

Users typically start with "using aire" + an existing Epic/tracking-item link or key. If provided,
record it in the `## Tracker` block in `runtime-artifacts/aire-state.md` (schema:
`common/tracker-sync.md` Section 1 — Type, Parent Epic, Epic URL, Project Key/Repo/Org). Rules:
- **Fetch the Epic content** per `common/tracker-sync.md` Section 2 (LOCAL: no fetch) into
  `spec/plans/epic-brief.md` — primary input to Requirements Analysis and User Stories.
- **Conflict rule**: a DIFFERENT recorded Epic (resumed project) → ask which to keep — NEVER overwrite.
- No Epic provided → don't block; User Stories Part 3 asks before any push (LOCAL: never asks).
- Single source of truth for linking pushed stories to this Epic, unless the user chose `none`
  (record `Parent Epic: none`).

---

## Workspace Detection (ALWAYS EXECUTE)

1. **MANDATORY**: Log initial user request in runtime-artifacts/audit.md with complete raw input
2. **MANDATORY**: Stamp `**User Email**:` on every audit entry (silent, email-only — `common/audit-logging.md`)
3. Load all steps from `planning/workspace-detection.md`
4. Execute workspace detection:
   - Check for existing runtime-artifacts/aire-state.md (resume if found)
   - Scan workspace for existing code; determine brownfield or greenfield
   - **Resolve the code root** — if brownfield code doesn't live in `src/`, record `## Code Root` in
     runtime-artifacts/aire-state.md per `common/directory-structure.md` and announce it. Never
     mass-move an existing tree.
   - Check for existing RE artifacts anywhere in the repo (standard folder/file names); reuse and
     skip regeneration if found
4.5. **HELIX MCP GATE (`common/helix-atlas-integration.md`)**: on **brownfield**, or when the
   request/Epic indicates **migration, re-platform, port, legacy rewrite or integration with an
   existing system**, Atlas is the source of existing-system truth. Resolve a Helix provider at
   runtime (never hardcode tool names) and record the binding. **If none resolves, emit the connect
   gate verbatim and HALT** — the user connects Helix, supplies exported Atlas docs, or approves local
   generation. Log the prompt and raw response. On greenfield with no existing system referenced, skip silently.
5. **Ask Tracker Selection, then capture the Parent Epic** (both only AFTER the state check; skip
   Tracker Selection if `## Tracker` is already recorded): apply the rules above, then, if the request
   has an Epic link/key, write/merge `## Tracker` and fetch epic-brief.md per the configured tracker;
   log both in runtime-artifacts/audit.md
6. **Create the Epic branch (automatic)**: per workspace-detection.md Step 4.5 /
   `common/branching-strategy.md` — record the base branch, create `epic/<EPIC-ID>-<title>`, record
   `## Branching` in runtime-artifacts/aire-state.md. All work happens here; story branches cut from it
7. Determine next phase: Reverse Engineering (if brownfield and no artifacts) OR Requirements Analysis
8. **MANDATORY**: Log findings in runtime-artifacts/audit.md
9. Present the completion message (formats in workspace-detection.md), then proceed automatically

## Reverse Engineering (CONDITIONAL — Brownfield Only)

**ATLAS FIRST (`common/helix-atlas-integration.md` Section 6)**: AIRE never re-derives documentation
Atlas already holds and a human has reviewed. **First check whether `spec/plans/atlas-deep-dive.md`
already exists locally** (Workspace Detection); only if not, ask Atlas for **one deep dive document**
for the estate/scope. Dispatch on the result:

| Atlas deep dive doc | Behaviour |
|---|---|
| **Already exists locally** | **SKIP.** Reuse `spec/plans/atlas-deep-dive.md` as-is. |
| **Found on Atlas** | **SKIP.** Pull it verbatim into `spec/plans/atlas-deep-dive.md`, with its provenance block. Announce the skip. |
| **Not found** | Tell the user plainly: *"No deep dive document found on Atlas."* Present the connect-gate A/B halt (Section 4 of that file) — on **B**, generate RE artifacts locally with the banner *"Existing-system context derived locally; no Atlas deep dive was available."* on every artifact; on **A**, HALT. |

Otherwise **execute** when existing code is detected and no prior RE artifacts exist; **skip** on
greenfield, or when prior artifacts already exist anywhere in the repo.

🔴 Atlas content is a **read-only input**. Never edit it to fit a plan. An Atlas/plan contradiction is
a finding to surface — follow Atlas, amend the AIRE-side artifact, say so plainly, log it.

**Execution**:
1. **MANDATORY**: Log start of reverse engineering in runtime-artifacts/audit.md
2. Load all steps from `planning/reverse-engineering.md`
3. Execute: analyse all packages/components and generate business overview (covering business
   transactions), architecture, code structure, API docs, component inventory, interaction diagrams,
   technology stack, and dependencies documentation
4. **Wait for Explicit Approval** (message format in reverse-engineering.md) — DO NOT PROCEED until
   the user confirms
5. **MANDATORY**: Log the user's raw response in runtime-artifacts/audit.md

## Requirements Analysis (ALWAYS EXECUTE — Adaptive Depth)

**Always executes**, depth varies by request clarity/complexity:
- **Minimal**: Simple, clear request — just document intent analysis
- **Standard**: Normal complexity — gather functional and non-functional requirements
- **Comprehensive**: Complex, high-risk — detailed requirements with traceability

**Execution**:
1. **MANDATORY**: Log user input this phase in runtime-artifacts/audit.md
2. Load all steps from `planning/requirements-analysis.md`
3. Execute requirements analysis:
   - Load reverse engineering artifacts (if brownfield)
   - **Read the Parent Epic brief** (`spec/plans/epic-brief.md`) if captured — defines what to build,
     primary input here
   - Analyze user request (intent analysis); determine requirements depth needed
   - Assess current requirements; ask clarifying questions (if needed)
   - Generate requirements document
4. Execute at appropriate depth (minimal/standard/comprehensive)
5. **Wait for Explicit Approval**: follow approval format from requirements-analysis.md — DO NOT
   PROCEED until user confirms
6. **MANDATORY**: Log the user's raw response in runtime-artifacts/audit.md
7. Commit the planning artifacts on the Epic branch and push (automatic — no PR raised at this point;
   the Epic PR is raised manually by the user at the end of the cycle via `pr-generator`)

## User Stories (ALWAYS EXECUTE)

**Always executes** for every software development request, ensuring shared understanding, clear
acceptance criteria, and testable specifications regardless of request type/complexity. Every project
produces `stories.md` + `personas.md`, populates the Story Tracker in `runtime-artifacts/aire-state.md`,
and auto-pushes stories to the configured tracker on approval (LOCAL: stays local).

**Note**: If Requirements Analysis executed, Stories can reference those requirements.

**Execution**:
1. **MANDATORY**: Log user input this phase in runtime-artifacts/audit.md
2. Load all steps from `planning/user-stories.md`
3. Load reverse engineering artifacts (if brownfield)
4. If Requirements exist, reference them when creating stories
5. Execute at appropriate depth (minimal/standard/comprehensive)
6. **PART 1 - Planning**: **NEVER ask team size** — record the fixed default `team_size: 2` in
   `runtime-artifacts/aire-state.md` (reused by Dependency Graph, never asked there either) and tune
   granularity so ≥ 2 independent stories can run in parallel. Create the story plan with its
   questions, wait for answers, analyze ambiguities. **The plan is announced, NOT approved**
7. **PART 2 - Generation**: **NEVER ask the creation mode** — `story_creation_mode` is fixed at
   `all-at-once`. Generate every story in a single pass, then populate the Story Tracker (`Requires`
   filled in the next stage)
8. **GATE 1 — Story Set Approval (MANDATORY)**: announce the complete story set (user-stories.md
   Steps 19–20) and **Wait for Explicit Approval** — DO NOT PROCEED to Part 3 until the user chooses
   "Request Changes" or "Approve & Continue" (Step 21). A requested change is applied to
   `stories.md`/the Story Tracker, re-announced, and GATE 1 is presented again
9. **PART 3 - Push to the configured tracker (only after GATE 1 approval)**: follow user-stories.md
   Steps 24–28
10. **MANDATORY**: Log the user's raw response in runtime-artifacts/audit.md

> **Next**: Proceed immediately to **Dependency Graph** stage to map dependencies between all stories.

## Dependency Graph (ALWAYS EXECUTE — immediately after User Stories)

**Purpose**: Analyse story dependencies. Each story gets a `requires` list; stories whose
prerequisites are all Done can be implemented in parallel by different developers. Produces
`spec/plans/dependency-graph.yml` and stamps `Requires` onto every story in the Story Tracker and `stories.md`.

**Execution**:
1. **MANDATORY**: Log start of Dependency Graph stage in runtime-artifacts/audit.md
2. Load all steps from `planning/dependency-graph-generation.md` — defines the execution steps (reuse
   the fixed `team_size: 2` — NEVER ask it), the TRUE-PARALLELISM RULES for computing `requires`, the
   `dependency-graph.yml` schema, and the **Story Tracker table format** (canonical columns: Requires,
   Tracker ID, Status, PR, Merged, Start, End, Recorded)
3. Execute all steps from that file — **`requires` is INFERRED, never asked**
4. **AUTOMATIC — no gate**: announce the graph + ready-stories summary and PROCEED (enforced later by
   the Doability Gate and branch-cut merge check); a user correction is an interrupt
5. **MANDATORY**: Log the graph, inferred edges and any user correction in runtime-artifacts/audit.md

---

## MANDATORY: Tracker Sync Rule (applies everywhere a story status changes)

Mechanics: `common/tracker-sync.md` Section 4. Whenever a story's status changes in the Story Tracker
(`runtime-artifacts/aire-state.md`), dispatch on its **Tracker ID** column:

- **`—`/`LOCAL`** → local tracker only. No external action, ever.
- **A real JIRA/ADO/GITHUB id** → also transition the tracker issue, **confirm-first**
  (`Story 1.2 has Tracker ID PROJ-102. Transition to "[target status]"? (yes/skip)`). Yes: transition,
  verify, log. Skip: local only, note it.
- **EXCEPTION — `In Development` is automatic**: picking a story via `dev-implement` IS the claim.
  Update both sides without asking, verify, announce. Stays In Development through code generation,
  Code Review, Remediate, the PR raise and the auto PR review.

**🔷 Epic Status Sync** (skip silently when `Parent Epic: none` or `Type: LOCAL`):
- **First story starts** → also transition the Parent Epic to "In Development" — automatic, verified, announced, logged.
- **All stories done** (every PR merged, last story at `🧪 Ready for Testing`) → **confirm-first** to
  move the Epic to "Ready for Testing". If any PR is still open, do NOT move it — report the open PRs
  and keep everything In Development.

**Story↔Parent-Epic links** (User Stories Part 3) are **automatic, not confirm-first** — GATE 1 already
gave explicit approval — but still verified.

🔴 **NEVER** silently update only one side. Local and external trackers must stay in sync.

---

## Workflow Planning (ALWAYS EXECUTE)

1. **MANDATORY**: Log user input this phase in runtime-artifacts/audit.md
2. Load all steps from `planning/workflow-planning.md`
3. **MANDATORY**: Load content validation rules from `common/content-validation.md`
4. Load all prior context: RE artifacts (if brownfield), intent analysis, requirements (if executed), user stories
5. Execute workflow planning: determine which phases to run and their depth, create multi-package
   change sequence (if brownfield), generate workflow visualization (VALIDATE Mermaid syntax first)
6. **MANDATORY**: Validate all content before file creation per content-validation.md rules
7. **AUTOMATIC — no gate**: present the plan per workflow-planning.md Step 9 (stages can be
   added/removed any time) and proceed; each selected stage keeps its own approval
8. **MANDATORY**: Log the finalized plan and any user change in runtime-artifacts/audit.md

## Application Design (CONDITIONAL)

**Execute IF**: new components or services needed · component methods/business rules need definition ·
service layer design required · component dependencies need clarification

**Skip IF**: changes within existing component boundaries · no new components or methods · pure
implementation changes

**Execution**:
1. **MANDATORY**: Log user input this phase in runtime-artifacts/audit.md
2. Load all steps from `planning/application-design.md`
3. Load reverse engineering artifacts (if brownfield)
4. Execute at appropriate depth (minimal/standard/comprehensive)
5. **Wait for Explicit Approval**: present detailed completion message (format in
   application-design.md) — DO NOT PROCEED until user confirms
6. **MANDATORY**: Log the user's raw response in runtime-artifacts/audit.md

## Transition to IMPLEMENTATION PHASE

After Application Design is approved (or Workflow Planning approval when skipped), proceed directly to
the **IMPLEMENTATION PHASE**. Its design stages run **once at system level**, scoped to the **intake
brief** at `spec/plans/epic-brief.md` (written from the provided Epic in whichever tracker was
configured, or from the user's requirements/natural-language description). Log the transition.

---

# 🟢 IMPLEMENTATION PHASE

**Purpose**: Detailed design, NFR implementation, and code generation. **Focus**: HOW to build it.

**Stages**:

1. **System-Level DESIGN Stages** (single pass, scoped to the intake brief; **no code generated here**)
   — Functional Design · NFR Requirements · NFR Design · Infrastructure Design (each CONDITIONAL).
2. **`architecture.md` + Architecture Rubric + CI Pipeline** (ALWAYS — at the STOP CHECKPOINT,
   automatic, no gate): the design stages consolidate into `spec/plans/architecture.md`; its Section 10
   Verifiable Constraints mechanically derive `tests/.evals/rubrics/architecture-rubric.json` (the
   **blocking** J1 gate); this project's own `.github/workflows/agentic-eval-pipeline.yml` is generated
   from the repo's real stack/thresholds.
3. **MANDATORY STOP** — the workflow HALTS and waits. Code Generation NEVER starts on its own.
4. **Development Handoff** — announce the ready stories; the user drives each one with **`dev-implement`**.
5. **Code Generation** (per-**story**, via the **`dev-implement`** keyword only) — full definition in
   `workflows/dev-implement.md`. In order:
   - **Story Selection** from the Dependency Graph, with a **Doability Gate** that never merges a
     prerequisite PR itself — even an approved one; merging stays a manual user action.
   - **Story branch** cut from the Epic branch (`common/branching-strategy.md`), then D1–D7 +
     regression **baseline** capture.
   - **Behaviour spec** written to `spec/behavior/story-<N.M>.feature` — Gherkin authored BEFORE the
     code, since it's the contract. 🔴 The story's ONLY spec file; ACs, requirements, architecture and
     thresholds are read from existing sources (`common/behavior-spec.md`).
   - **Code generation** into **`src/`**, tests into `tests/`.
   - **Gates, in sequence**: unit + coverage → Gherkin in Podman (**B1** this unit → **B2** every
     other feature file → **B3** whole cycle, last unit only) → API & contract (when touching an API
     layer) → full regression vs baseline → static D1–D7 → automated Code Review including the
     diff-scoped Security Baseline review and **blocking** J1/J2 judge gates.
   - **Every self-healing loop is capped at 3 attempts**; on exhaustion HALTS with the Retry-Limit
     Report rather than proceeding.
   - On a clean verdict: commit, push, PR, auto PR review. Stays `🔵 In Development` until its PR
     **merges** and ve signs it off.
   - **Fully automatic — naming the story is the only user input.** Plan announced (no GATE 2), review
     routes on its own verdict (no GATE 3), findings auto-remediated and re-reviewed until clean or budget spent.
6. **Code Review & Remediate** — `workflows/code-review.md` and `workflows/remediate.md`. Every review
   checks the acceptance criteria/requirements **and** the always-mandatory Security Baseline via a
   diff-scoped automated security review (`agents/code-security-review-agent.md` Phase 2.5), whose
   🔴/🟠 findings on the changed surface become real `SEC-ISS-XXX` findings, and computes the
   **blocking** J1/J2 gates. Both run automatically inside every implement workflow and are also
   invokable standalone, where they stay confirm-first.

**🧪 Test Plan is NOT part of this phase**, epic or story level — it's ve's, run per story via `/ve-implement`.

**Note on the STOP CHECKPOINT**: after design stages complete/skip, the workflow MUST stop and present
the Development Handoff — never proceed into Code Generation on its own; the user drives it with `dev-implement`.

---

## System-Level DESIGN Stages (Single Pass)

**These DESIGN stages execute in sequence, ONCE for the whole system, scoped to the intake brief
captured at workflow start. Code Generation is NOT part of them** — it happens later, per-story, via
`dev-implement`, after the mandatory STOP CHECKPOINT.

**Primary inputs for EVERY design stage** (load before Step 1): `epic-brief.md` (defines WHAT to
build) · `requirements.md` · `stories.md` + `## Story Tracker` · Application Design artifacts if that
stage ran · Atlas existing-system truth when the Helix MCP is bound — on brownfield the existing
architecture is the **starting state**, and the design records the delta from it.

### The stages

| Stage | Rule file | Execute IF | Skip IF |
|---|---|---|---|
| **Functional Design** | `implementation/functional-design.md` | New data models/schemas · complex business logic · business rules need detailed design | Simple logic changes · no new business logic |
| **NFR Requirements** | `implementation/nfr-requirements.md` | Performance/security/scalability considerations · tech stack selection required | No NFR requirements · stack determined |
| **NFR Design** | `implementation/nfr-design.md` | NFR Requirements executed · patterns to incorporate | No NFR requirements · NFR Requirements skipped |
| **Infrastructure Design** | `implementation/infrastructure-design.md` | Infra services need mapping · deployment/cloud resources required | No infra changes · already defined |

### Execution pattern — IDENTICAL for all four stages

1. **MANDATORY**: Log user input this stage in runtime-artifacts/audit.md
2. Load all steps from the stage's rule file (table above)
3. Execute the stage **for the whole system**
4. **MANDATORY**: Present the standardized **2-option** completion message from that stage's rule
   file — 🔴 DO NOT invent a 3-option menu or other navigation pattern
5. **Wait for Explicit Approval**: the user chooses "Request Changes" or "Continue to Next Stage" —
   DO NOT PROCEED until they confirm
6. **MANDATORY**: Log the user's raw response in runtime-artifacts/audit.md

> **End of the System-Level DESIGN stages.** Once completed (or skipped), DO NOT generate code.
> Proceed to the mandatory STOP CHECKPOINT below.

---

## MANDATORY STOP — After Infrastructure Design, Before Code Generation

**This is a hard halt.** After design stages complete (Infrastructure Design done or skipped), the
workflow MUST stop and wait. **Code Generation MUST NOT start automatically.** Present the Development
Handoff below, then block until the user invokes `dev-implement`.

1. **MANDATORY**: Log reaching the stop CHECKPOINT.
1.3. **WRITE `spec/behavior.feature`** (automatic, no gate), per `common/behavior-spec.md` Section 3:
   the **cross-story journeys that belong to no single story**, tagged `@REQ-<id>`. Written ONCE per
   cycle — what the **B3 tier** runs on the last work unit. 🔴 Genuine cross-unit journeys only, never
   copies of per-story scenarios; if none exist, record that explicitly.
1.4. **WRITE `architecture.md`** (MANDATORY, automatic, no gate), per `implementation/architecture-doc.md`:
   consolidate the design stages into **`spec/plans/architecture.md`** — system context, component
   inventory, layering/boundaries, data architecture, API/integration contracts, cross-cutting
   decisions, non-functional targets, infrastructure, the delta from the existing system (brownfield),
   and **Section 10 Verifiable Constraints**. **Assembled from approved design artifacts and Atlas
   truth — never authored fresh**; a skipped stage says so explicitly, not filled with an invented
   decision. 🔴 **Diagram assertion (before the design commit)**: MUST contain the two ALWAYS inline
   Mermaid diagrams from Section 2.1 of that rule file — a **System Context** (`C4Context`) block in
   Section 1 and a **Component Architecture** (`flowchart`) block in Section 2 (plus an `erDiagram`
   when any store/schema changed) — validated per `common/content-validation.md`. Missing/unparseable
   ALWAYS block → do NOT commit, fix it first. Section 10 is mandatory and makes the blocking J1 gate
   fair: 3–8 constraints, each with an ID, an imperative one-sentence constraint, a *verifiable-as*
   rule naming exactly what scores 0 in a diff, a weight, and its source artifact; weights sum to 1.0.
   Version and log it in runtime-artifacts/audit.md.
1.5. **Derive the rubrics** (automatic, no gate), per `implementation/architecture-doc.md` Section 4
   and `common/eval-framework.md` Section 3: generate `tests/.evals/rubrics/architecture-rubric.json`
   **mechanically from `architecture.md` Section 10** — same constraints, same wording, same weights,
   `rubricVersion` **equal to** the `architecture.md` version. Also create
   `tests/.evals/rubrics/security-rubric.json` (OWASP-based, per Section 4.1 of that file) and
   `tests/.evals/config.json` from eval-framework.md Section 1's template if absent. 🔴 **Artifact
   Ownership (`common/directory-structure.md`) — create if missing, never regenerate.** `config.json`,
   `scripts/`, `behavior/`, `security-rubric.json`: use AS-IS if inherited from base; **if ABSENT,
   create them** deterministically (no timestamps, stable key order) and commit **on the cycle
   branch**. 🔴 Never push to base or raise a `[CI]` PR — they reach base at merge. 🔴 Never
   halt a cycle because base wasn't bootstrapped. 🔴 **Never hand-write/hand-edit a rubric** — edit
   Section 10 and regenerate; J1 is blocking and an untraceable rubric can't fairly fail a story. If
   nothing is derivable, apply the Section 3 fallback chain and record J1 as `N/A` (never blocks). Log
   in runtime-artifacts/audit.md.
1.6. **Generate the CI pipeline** (automatic; one setup gate), per `common/ci-pipeline-generation.md`:
   generate `.github/workflows/agentic-eval-pipeline.yml` **for THIS project** — every command from
   the repo's own build files, every threshold from `tests/.evals/config.json`. Four stages mirror
   local gates. **🔴 VALIDATE BEFORE COMMITTING (Section 4.0)**: YAML must parse, pass `actionlint`,
   reference only existing scripts — quote every `name:`, no bare colons, no `<placeholders>`. Never
   commit an invalid workflow; confirm a run started after pushing. **SonarQube**: generate
   `sonar-project.properties` + scan steps, present the setup gate (Section 4.1.2) and **HALT for
   `proceed`/`skip`**; 🔴 never write a token into any file, plus a self-repair job via **Claude Code
   CLI authenticated by `CLAUDE_CODE_OAUTH_TOKEN`**, capped at `retryLimitForSelfRepair`. Also generate
   `tests/.evals/scripts/run-static-evals.*` (🔴 owns the D1–D7 baseline diff), `run-evals.*` and
   `auto-fix-agent.*`. 🔴 **Commit the pipeline + scripts on the CYCLE branch** (Section 2.1) — CI works
   from the first PR (GitHub runs `pull_request` workflows from the HEAD branch) and reaches base at
   merge. Never push to base or raise a separate `[CI]` PR. **Idempotent** — never overwrites a
   human-edited pipeline. 🔴 CI **re-verifies** local gates, never relaxes them.
2. Mark in `runtime-artifacts/aire-state.md`: `Design complete — awaiting dev-implement`.
3. **Commit + push the design artifacts on the Epic branch (automatic — unblocks ve)**: stage
   `spec/plans/**`, `spec/plans/architecture.md`, `tests/.evals/` (architecture-rubric + any files
   created by Step 1.5's create-if-missing rule), `runtime-artifacts/aire-state.md`,
   `runtime-artifacts/audit.md`. Commit with an `AIRE-Version: [N]` trailer and push. If push fails,
   tell the user to push manually — **ve cannot start until this branch is on origin**.
4. **🧪 Epic-level pre-handoff smoke test** (automatic; HARD HALT on exhaustion), per
   `common/ci-pipeline-generation.md` Section 4.0.6: run `tests/.evals/scripts/smoke-test-epic.{sh,ps1}`
   against the epic branch just pushed. Validates the environment (dependency conflicts, tooling
   quirks, test suite runs, self-repair works) via a zero-diff scratch PR — proof only that the
   environment is viable to build on, not that the pipeline's delta-scoped logic is correct. On a pass,
   the scratch PR merges and deletes automatically; on exhaustion, it's left open and **Development
   Handoff does NOT happen** until resolved — same Retry-Limit Report format used everywhere else.
5. Present the **Development Handoff** message (below).
6. **HALT.** Do not proceed to Code Generation or any later stage until the user types `dev-implement`

## Development Handoff — Use `dev-implement` to Build Each Story

At Step 4 above, load `common/development-handoff.md` and emit its message **verbatim** — that file
carries the template and substitution rules. Never ship an unsubstituted placeholder. Log the handoff
in runtime-artifacts/audit.md, then **HALT**.

---

## Code Generation (Only execute when the user types `dev-implement`, per-story)

**On the `dev-implement` keyword, read `workflows/dev-implement.md` and follow it exactly.**

---

## Code Review & Remediate

**Status**: OPTIONAL standalone invocations, for **a specific story** or **all stories together**. Both
also run automatically inside every implement workflow — this section covers standalone use.

- **`code-review`** → read `workflows/code-review.md` and follow it exactly (REVIEWER, read-only).
- **`remediate`** → read `workflows/remediate.md` and follow it exactly (DEV, code-editing).

Self-contained — no separate detail file to load. 🔴 **NEVER auto-run them here**; standalone
invocations are user-initiated. After a story's PR is raised, *suggest* both as optional next steps
without running either. Log every response and tracker update.

---

# TICKET WORKFLOW (keyword: `ticket-implement <TICKET-ID>` — Bug OR Enhancement)

**On `ticket-implement <TICKET-ID>`** (existing ticket in the configured tracker; omit the ID for LOCAL
— describe the item inline instead): read `workflows/ticket-implement.md` and follow it exactly.

---

## Key Principles

- **Adaptive Execution** — run only the stages that add value; complex changes get full treatment,
  simple changes stay efficient.
- **Transparent Planning** — always show the execution plan before starting; the user may add or
  remove stages any time.
- **Progress Tracking** — record executed and skipped stages in `runtime-artifacts/aire-state.md`.
- **Complete Audit Trail** — every interaction logged with complete raw input, not just approvals.
- **Content Validation** — validate all content before file creation (`common/content-validation.md`).
- **Bounded Self-Healing** — every automatic fix loop is capped at **3 attempts**; on exhaustion the
  run HALTS at that gate with the Retry-Limit Report and asks the user for next steps. A failing gate
  is never skipped, weakened, or carried forward. 🔴 **One named exception**: the epic-level smoke
  test's own watch loop (`common/ci-pipeline-generation.md` Section 4.0.6, above) is UNBOUNDED,
  terminating only via `auto-fix-agent.*`'s own `retryLimitForSelfRepair` exhaustion or a genuine fix —
  never license to uncap any OTHER loop in the framework.
- 🔴 **NO EMERGENT BEHAVIOR** — Implementation-phase design stages MUST use the standardized
  **2-option** completion message from their own rule file. Never invent a 3-option menu or other pattern.

## MANDATORY: Plan-Level Checkbox Enforcement

1. **NEVER complete work without updating the plan checkboxes.** Immediately after finishing ANY step
   in a plan file, mark it `[x]` — in the **SAME interaction** where the work completed. No exceptions.
2. **Two levels**: plan-level tracks detailed progress within a stage; stage-level tracks overall
   progress in `runtime-artifacts/aire-state.md`. Both update in the same interaction as the work.

## Prompts Logging Requirements
Same non-negotiables as the Audit Trail section above, applied to EVERY user input and AI response.
Additionally: Implementation-flow entries add `**TRACKER ITEM**:`, `**Epic Link**:` and
`**AIRE VERSION**:`; self-healing entries add `**SH-LOOP**:`, `**Root cause**:` and `**Verification**:`.

## Directory Structure

**CRITICAL RULE — five roots, nothing outside them**:
- **`src/`** — ALL application code, greenfield AND brownfield. If a brownfield repo keeps code
  elsewhere, record that root ONCE as `## Code Root` in `runtime-artifacts/aire-state.md`, treat as
  `src/` for the cycle. 🔴 Never a second code location; never mass-move an existing tree.
- **`tests/`** — `unit/`, `behavior/` (Gherkin step definitions), `e2e/` (Playwright)
- **`spec/`** — specs/docs ONLY, 🔴 never a source file: `behavior.feature` at root (**once per cycle,
  never per story**), plus four subfolders: **`plans/`** — flat planning/design docs
  (`architecture.md`, `atlas-deep-dive.md` + flat RE docs from Atlas, `requirements.md`, `stories.md`,
  `personas.md`, `epic-brief.md`, `dependency-graph.yml`, `functional-design.md`, `nfr.md`,
  `infrastructure-design.md`, `application-design.md`); **`spec-generation/`** — `*-generation.md`
  plan/clarifying-question files; **`behavior/`** — one `.feature` per work unit; **`test-plans/`** —
  ve manual test plans; plus human-authored **`context-project/`** (`existing-knowledge/`,
  `new-references/`; read only at a user-supplied path, never auto-scanned)
- **`reports/`** — generated OUTPUTS ONLY: `unit-test-evidence/`, `behavior-test-evidence/`,
  `api-contract-test-evidence/`, `eval-evidence/`, `reviews/`, `code-security-reviews/`,
  `ticket-summary/` (per-work-unit summaries). 🔴 `.feature` contracts stay in `spec/behavior/`, never here.
- **`tests/.evals/`** — `config.json`, `rubrics/`, `scripts/`
- Per project: **`.github/workflows/agentic-eval-pipeline.yml`** (`common/ci-pipeline-generation.md`)
- Structure inside `src/`: see `implementation/code-generation.md` for patterns by project type

**Full canonical layout**: `common/directory-structure.md`. Load on demand to place an artifact
whose path isn't already fixed by the rule file you're following.
