# Workspace Detection

**Purpose**: Determine workspace state and check for existing aire projects

## Step 1: Check for Existing aire Project

Check if `runtime-artifacts/aire-state.md` exists:
- **If exists**: Resume from last phase (load context from previous phases)
- **If not exists**: Continue with new project assessment

## Step 1.5: Capture Session Identity (silent, email-only, runtime-artifacts/audit.md ONLY)

Apply the **MANDATORY: Session Identity Capture** rules from the root workflow file (CLAUDE.md / equivalent). No shell commands, MCP, or external calls — and NO confirmation question to the user:

1. Read the **session email** from the session context provided by the AI environment (Claude Code injects the logged-in account's email automatically). Use it AS-IS — do NOT ask the user to confirm it, and do NOT derive or record a display name (email is the only identity field)
2. Only if the environment provides NO session email (non-Claude environments), ask the user for their email once
3. **Do NOT persist it anywhere**: the email goes ONLY into runtime-artifacts/audit.md entries as the `**User Email**:` field — NEVER into runtime-artifacts/aire-state.md (no `## Session Identity` section) or any other artifact
4. From this point stamp every runtime-artifacts/audit.md entry with `**User Email**:` (read live from the session context) — at every approval flow this field records who approved. A different developer resuming the project automatically logs under their own session email

## Step 1.6: Sync the Local Base Branch with Remote (MANDATORY, before any freshness assessment)

**Why**: a new session's local base branch is often **behind** the remote (prior cycles' merged PRs land there). Syncing FIRST means the code Step 2 scans and the state Step 3 assesses reflect the true current base, not a stale local checkout.

**Run BEFORE scanning for code and BEFORE the Step 3 freshness assessment:**

1. Record the base branch: `git branch --show-current` (the branch the workflow started on — do NOT assume `main`). This runs before any epic branch exists, so the current branch IS the base branch.
2. `git fetch origin` — update remote-tracking refs.
3. **Fast-forward the local base branch to the remote**:
   - If the working tree is clean and the local base can fast-forward: `git pull --ff-only`.
   - **If the tree is dirty or the branches have diverged**: do NOT clobber. Show `git status` / the divergence and ask the user how to proceed (stash, commit, or continue against the current local state). Log the choice in runtime-artifacts/audit.md.
4. Log the sync result (fetched, fast-forwarded to `<sha>`, or the user's chosen action) in runtime-artifacts/audit.md.

> 🔴 Current-system truth is NOT carried across cycles on the base branch. Each new cycle pulls fresh existing-system truth (`spec/plans/atlas-deep-dive.md` plus the flat RE docs under `spec/plans/`) from **Atlas via the Helix MCP** (`common/helix-atlas-integration.md`) — there is no delta to replay and no ledger to reconcile.

This step ONLY synchronizes the local base branch; it does not create the epic branch (that is Step 4.5).

## Step 1.7: Tracker Selection (ask ONCE, record, reuse on resume)

**Skip entirely if `runtime-artifacts/aire-state.md` already contains a `## Tracker` section** (resumed project) — reuse the recorded value, do NOT re-ask.

Otherwise, load `common/tracker-sync.md` Section 1 and execute it exactly: ask which issue tracker to use (JIRA / ADO / GITHUB / LOCAL), record the answer in `## Tracker` in `runtime-artifacts/aire-state.md`, then ask the type-specific one-time follow-up (ADO org/project, or GitHub org/repo — skipped entirely for LOCAL and for JIRA). Verify CLI/MCP auth for ADO (`az account show`) and GitHub (`gh auth status`) at this point; LOCAL requires no auth check at all.

Log the question and the complete raw answer in `runtime-artifacts/audit.md`. This MUST run before Step 4.5 (Epic Branch Creation, which needs no tracker info) and before Parent Epic Capture (run by CLAUDE.md immediately after Workspace Detection completes) — Parent Epic Capture depends on knowing which tracker to query.

## Step 2: Scan Workspace for Existing Code

**Determine if workspace has existing code:**
- Scan workspace for source code files (.java, .py, .js, .ts, .jsx, .tsx, .kt, .kts, .scala, .groovy, .go, .rs, .rb, .php, .c, .h, .cpp, .hpp, .cc, .cs, .fs, etc.)
- Check for build files (pom.xml, package.json, build.gradle, etc.)
- Look for project structure indicators
- Identify workspace root directory (NOT spec/)

**Record findings:**
```markdown
## Workspace State
- **Existing Code**: [Yes/No]
- **Programming Languages**: [List if found]
- **Build System**: [Maven/Gradle/npm/etc. if found]
- **Project Structure**: [Monolith/Microservices/Library/Empty]
- **Workspace Root**: [Absolute path]
```

## Step 3: Determine Next Phase

**IF workspace is empty (no existing code)**:
- Set flag: `brownfield = false`
- Next phase: Requirements Analysis

**IF workspace has existing code**:
- Set flag: `brownfield = true`
- **Search the ENTIRE repo for existing reverse engineering artifacts — they can live ANYWHERE, not only at the default path.** RE docs live FLAT in `spec/plans/`; file names are always the same, so search by name:
  1. First check the default location: `spec/plans/` (the flat RE docs, alongside `atlas-deep-dive.md`)
  2. If not there, glob the whole workspace for the standard artifact filenames at any depth: `business-overview.md`, `code-structure.md`, `api-documentation.md`, `component-inventory.md`, `technology-stack.md`, `dependencies.md`, `code-quality-assessment.md`, `reverse-engineering-timestamp.md`, `atlas-deep-dive.md` — a directory containing several of these IS the artifact set even if it lives elsewhere
  3. If found outside the default path, record the discovered location in `runtime-artifacts/aire-state.md` (`## Workspace State` → `Reverse Engineering Artifacts: <path>`) and use THAT path everywhere the artifacts are loaded later (Requirements Analysis, User Stories, design stages)
- **IF reverse engineering artifacts exist (at ANY location found above)** — do NOT regenerate them:
    - Current-system truth is refreshed **fresh from Atlas via the Helix MCP** at the start of each cycle (`common/helix-atlas-integration.md`), so existing artifacts from a prior cycle are treated as a starting point only. The Helix MCP gate (CLAUDE.md Step 4.5) decides whether to re-pull from Atlas or run local Reverse Engineering — there is no delta to replay and no stitch ledger to consult.
    - **IF the artifacts are usable as-is** (Atlas unavailable and the user is content with the existing docs): Load them, skip to Requirements Analysis
    - **IF a fresh Atlas pull or rerun is warranted, or the user explicitly requests it**: Next phase is Reverse Engineering
- **IF no reverse engineering artifacts**: Check `aire-archives/epics/`, `aire-archives/bugs/` AND `aire-archives/enhancements/` for archive folders (created by the `archive-epic` skill at the end of a previous epic, bug, or enhancement release cycle)
    - **IF archives exist**: The most recently archived cycle folder — across all subfolders, by archive date in `archive-manifest.md` — holds a complete snapshot of that cycle, useful for **human-curated context** (requirements, stories, decisions). 🔴 Current-system truth is NOT restored from the archive — it is refetched fresh from Atlas via the Helix MCP each cycle. Ask the user:
      ```
       No live reverse engineering artifacts found, but an archived cycle snapshot exists
         ([EPIC-KEY or BUG-KEY] — [name], archived [date]).

      A) Restore human-curated context from the archive (current-system truth will still be
         refetched fresh from Atlas)
      B) Start clean and run fresh reverse engineering against the current codebase

      [Answer]:
      ```
      On A: copy the human-curated context from the archived `spec/plans/` into `spec/plans/`, log the restore in runtime-artifacts/audit.md, then proceed to Requirements Analysis (current-system truth is refetched from Atlas by the Helix MCP gate). On B: next phase is Reverse Engineering.
    - **IF no archives**: Next phase is Reverse Engineering

**Monorepo note**: Reverse engineering artifacts are always checked/generated at the workspace ROOT only — one artifact set covering all modules. Never look for or create per-module artifact sets (see `planning/reverse-engineering.md` "Monorepo Handling").

## Step 4: Create Initial State File

Create `runtime-artifacts/aire-state.md`:

```markdown
# aire State Tracking

## Project Information
- **Project Type**: [Greenfield/Brownfield]
- **Start Date**: [ISO timestamp]
- **Current Stage**: PLANNING - Workspace Detection

## Workspace State
- **Existing Code**: [Yes/No]
- **Reverse Engineering Needed**: [Yes/No]
- **Workspace Root**: [Absolute path]

## Code Location Rules
- **Application Code**: Workspace root (NEVER in spec/)
- **Documentation**: spec/ only
- **Structure patterns**: See code-generation.md Critical Rules

## Stage Progress
[Will be populated as workflow progresses]
```

## Step 4.5: Create the Epic Branch (automatic)

Load `common/branching-strategy.md` and execute **Section 1 — Epic Branch Creation**:
- Record the **base branch** (the branch the workflow started on — do not assume `main`)
- Create `epic/<EPIC-KEY>-<kebab-case-epic-title>` automatically (confirm a name with the user only when no Epic was provided)
- Record `## Branching` (Base Branch, Epic Branch) in `runtime-artifacts/aire-state.md`
- **Skip** if `## Branching` already exists (resumed project) — verify the epic branch exists and switch to it

Log the branch creation (name + base branch) in runtime-artifacts/audit.md.

## Step 4.6: Ensure the Context Project Folder (ALL flows — check first, create only if missing)

Ensure **`spec/context-project/`** exists with its two subfolders. This is the human-authored home for
everything a person wants the framework to read — the framework **never auto-populates it and never
auto-scans it**.

```text
spec/context-project/
├── existing-knowledge/    # How the CURRENT system works — module notes, interview.md,
│                          # where things live, what each component does.
│                          # Brownfield only; leave empty on greenfield.
└── new-references/        # What to BUILD — UX wireframes, design mockups, UI specs,
                           # API specs, architecture diagrams, research docs.
                           # Applies to BOTH greenfield and brownfield.
```

- **Check first**: if `spec/context-project/` (or either subfolder) already exists — reuse AS-IS.
  Do NOT recreate, empty, overwrite or delete it or anything under it.
- **Only if absent**: create the folder and both empty subfolders. Do NOT create a README inside them.
- `existing-knowledge/` uses one subfolder per repo module, named **exactly** after the module
  (e.g. `existing-knowledge/ALIX.BMS/interview.md`).
- This is a safety net so the folders exist even on flows that skip reverse engineering.

## Step 4.7: Context Opt-In (ALL flows — ask ONCE, in chat, record in state)

**Skip entirely if `runtime-artifacts/aire-state.md` already contains a `## Context Project` section** — a resumed
project already answered. Reuse the recorded values; do NOT re-ask.

🔴 **ASK THIS IN THE CHAT SESSION ONLY.** Do NOT create a question `.md` file for it, and do not
apply `common/question-format-guide.md`'s file-based convention here — this question is answered
conversationally, in one turn, and only the ANSWER is persisted (to `runtime-artifacts/aire-state.md` and `runtime-artifacts/audit.md`).

🔴 **EMIT THE BLOCK BELOW VERBATIM — WORD FOR WORD, BOTH PARTS, BOTH FOLDER PATHS.** This is the same
class of rule as the Section 4.1.2 CI setup gate (`common/ci-pipeline-generation.md`): it is not a
question to be paraphrased into your own words, because the *content* is the deliverable. The user
cannot place a file in a folder whose name you did not tell them.

**Observed failure — do not repeat it.** The block was compressed into:

> *"Context folders are set up. One more quick chat-only question before I wrap up Workspace
> Detection: Do you have any reference materials I should use for this work? (UX wireframes, design
> mockups, API specs, architecture diagrams, or other docs defining the target state). Reply with the
> exact path(s), or 'no'."*

That paraphrase silently **deleted part 1 entirely** (existing-knowledge — the brownfield half), and
**dropped both folder paths**, so the user was asked where to put files without being told either
destination. A user who answers "no" to a question that never mentioned `existing-knowledge/` has not
declined it; they were never asked.

🔴 **Specifically forbidden**: rewording the two part labels, merging the two parts into one question,
omitting `spec/context-project/existing-knowledge/` or `spec/context-project/new-references/`,
replacing a path with a description of it, adding a preamble about folders being "set up", or
converting it to a lettered multiple-choice prompt. The ONLY permitted edit is the bracketed greenfield
instruction on part 1 (see the rules below).

Ask both parts together, once:

```
Do you have any context I should use for this work?

1) Existing knowledge — human-authored notes on how the CURRENT system works
   (module notes, interview.md, where things live). Place under
   spec/context-project/existing-knowledge/
   [brownfield only — omit this part on greenfield]

2) New references — what to BUILD: UX wireframes, design mockups, UI specs,
   API specs, architecture diagrams, research docs. Place under
   spec/context-project/new-references/

HOW TO ANSWER — give one ans per part shown above:

  1) <path>        or   1) no
  2) <path>        or   2) no

Every part shown needs its own answer. Answering "no" to one part does not
skip the other. For several paths in one part, separate them with commas.

Example answer:
  1) no 2) spec/context-project/new-references/checkout-wireframes/

[Answer]:
```

Record the answer in `runtime-artifacts/aire-state.md`:

```markdown
## Context Project
- **Existing Knowledge**: [Yes/No]
- **Existing Knowledge Path(s)**: [exact path(s) the user gave — or —]
- **New References**: [Yes/No]
- **New Reference Path(s)**: [exact path(s) the user gave — or —]
```

Rules:
- 🔴 **Both folder names appear in the asked question, spelled in full**:
  `spec/context-project/existing-knowledge/` and `spec/context-project/new-references/`. They are the
  two — and only two — subfolders of `spec/context-project/` (`common/directory-structure.md`), and the
  user needs the exact name to put a file in the right one.
- Record the paths **exactly as given**. Only those paths are ever read — there is no auto-scan of the
  rest of `spec/context-project/`.
- If a supplied path does not exist, say so and re-ask that part.
- On greenfield, ask part 2 only — the answer is then a single line (`2) <path>` or `2) no`) — and
  record `Existing Knowledge: No`.
- A reply that answers only ONE of two parts shown is INCOMPLETE, not a "no" to the other. Ask again
  for the missing part alone; never infer silence as a decline, and never record a value the user did
  not actually give.
- Log the prompt and the user's complete raw answer in `runtime-artifacts/audit.md`.
- Downstream, **Requirements Analysis**, **Workflow Planning**, **Application Design**, **Functional
  Design**, **User Stories** and **Code Generation** read `## Context Project`:
  **existing-knowledge** grounds understanding of what already exists; **new-references** is
  authoritative for what to build — wireframes and mockups dictate the UI, API specs dictate the
  endpoints and shapes.

## Step 4.8: Load the Design Reference Guardrail (NO question — enforcement only)

**Load `common/design-reference-grounding.md` and apply it for the remainder of the workflow.**

**Do NOT ask the user anything here.** This step adds no prompt. The guardrail is purely reactive: whenever the user names a file path, folder path, spec document, screenshot, or design URL in ANY input at ANY stage — the initial request, a clarifying answer, a request-changes message, a remediation comment — that artifact MUST be registered in `## Design References` in `runtime-artifacts/aire-state.md` and its **actual content read** in the stage where it was named (rules DR-1 / DR-2 / DR-4), then re-consulted before design and code artifacts (DR-5).

If the user's initial request already names such an artifact, register it now and log it in `runtime-artifacts/audit.md`.

## Step 5: Present Completion Message

**For Brownfield Projects:**
```markdown
# Workspace Detection Complete

Workspace analysis findings:
• **Project Type**: Brownfield project
• [AI-generated summary of workspace findings in bullet points]
• **Next Step**: Proceeding to **Reverse Engineering** to analyze existing codebase...
```

**For Greenfield Projects:**
```markdown
# Workspace Detection Complete

Workspace analysis findings:
• **Project Type**: Greenfield project
• **Next Step**: Proceeding to **Requirements Analysis**...
```

## Step 6: Automatically Proceed

- **No user approval required** - this is informational only
- Automatically proceed to next phase:
  - **Brownfield**: Reverse Engineering (if no existing artifacts) or Requirements Analysis (if artifacts exist)
  - **Greenfield**: Requirements Analysis
