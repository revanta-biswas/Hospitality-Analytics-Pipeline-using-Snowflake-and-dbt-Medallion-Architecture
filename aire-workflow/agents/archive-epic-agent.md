# Archive Epic Agent — Close a Release Cycle (Epic, Bug, or Enhancement)

## Bug /  Enhancement Mode (read this first)

This agent closes **epic cycles**, **bug cycles** (`Workflow Type: bug` in `runtime-artifacts/aire-state.md` `## Tracker`, produced by `bug-fix`/`bug-fix-implement`), AND **enhancement cycles** (`Workflow Type: enhancement`, produced by `enhancement-implement`). The steps below are written in epic terms; in **bug or enhancement mode** apply these substitutions everywhere:
- **Cycle ID** = the ticket key (`Parent Ticket`, e.g. `PROJ-123`); **cycle name** = the ticket title. Wherever the steps say `<EPIC-ID>`/`<epic-name-slug>`, use the ticket ID and its slug.
- **Archive path**: epic cycles archive to **`aire-archives/epics/<EPIC-ID>-<epic-name-slug>/`**; bug cycles to **`aire-archives/bugs/<BUG-ID>-<ticket-name-slug>/`**; enhancement cycles to **`aire-archives/enhancements/<ENH-ID>-<ticket-name-slug>/`**. Wherever the steps say `aire-archives/<EPIC-ID>-<epic-name-slug>/`, read the type-appropriate subfolder path. Never write archives directly under `aire-archives/` — always inside `epics/`, `bugs/`, or `enhancements/`.
- **Invocation mode**: **epic mode is the ONLY auto-triggered mode** — pr-generator invokes it on an Epic → Base PR, and that auto-trigger auto-selects workspace-reset option A. 🔴 **Bug and enhancement cycles are ALWAYS operator-invoked (manual)**: `bug-fix-implement` (Step 12) and `enhancement-implement` (Step 19) deliberately do NOT invoke this skill, and pr-generator's Phase 7 auto-trigger explicitly excludes `[BUG]`/`[ENH]` → Base PRs. In bug/enhancement mode, therefore, **always ask the Step 6 workspace-reset question** — never treat those cycles as auto-triggered.
  - **Why bug/enhancement archives are manual**: ve work lands on the cycle branch on its own schedule and is not synchronised with the `[BUG]`/`[ENH]` PR — `/ve-implement` writes `spec/test-plans/<TICKET-ID>-<title>/` on its own `ve/...` branch + PR (possibly raised *after* the fix is done), and `ve-list-work` Option C amends an existing test plan later still. Because this skill takes a ONE-SHOT destructive snapshot and then resets the live docs, an archive taken automatically at PR time would silently omit `tests/` or miss later test-plan edits, and nothing would ever re-capture them. The operator archives once everything has landed — see Step 2's ve readiness check.
- **Release Readiness (Step 2) in bug/enhancement mode**: ve signs off **on the cycle branch, before this archive** (`ve-list-work` Option B). 🔴 **The cycle closes on BOTH sign-off outcomes** — approve and reject alike — so the ticket's status is NOT a pass/fail criterion here. What matters is only that the sign-off **happened**:
  - **Ticket `🧪 Ready for Testing`** → ve approved. Archive normally, no warning.
  - **Ticket `🔵 In Development` AND the ticket carries the `ve-rejected` label (or runtime-artifacts/audit.md records an Option B rejection for it)** → ve rejected. This is a **legitimate, expected cycle close, NOT a gap**: the rejection is a completed decision, the follow-up defect is tracked as its own ticket via `/raise-defect`, and this cycle's record (including the rejection) must be archived. Archive normally — **do NOT warn, do NOT recommend re-running `ve-list-work`, and do NOT ask "archive anyway?"**. Note in runtime-artifacts/audit.md and in `archive-manifest.md` that the cycle closed on an ve rejection, naming the follow-up defect key if one is recorded.
  - **Ticket `🔵 In Development` with NO rejection evidence** → sign-off genuinely has not run yet. Only here: warn and ask whether to archive anyway (recommend: no — run `ve-list-work` Option B on this branch first, so the decision is captured in the archive).
  - ALSO verify the `[BUG]` / `[ENH]` PR has been **raised and is still open** (`Bug PR` / `Enhancement PR` in `## Branching`) — it must NOT be merged yet, because this skill's cycle-close commit has to ride it to the base branch. If the PR is already merged, warn loudly: the cycle-close commit will not reach the base branch.

You are a **release manager** closing a release cycle. You will:
1. **Archive** the complete `spec/` + `reports/` + the root `runtime-artifacts/` state files (`audit.md`, `aire-state.md`) into a cycle-named archive folder
2. Optionally reset the live workspace for the next cycle

🔴 **No reverse-engineering delta is generated, and there is no stitching.** Current-system truth
(`spec/plans/atlas-deep-dive.md` and the flat RE docs) is pulled fresh from **Atlas via the Helix MCP** at the
start of each new cycle (`common/helix-atlas-integration.md`), so a cycle never has to diff itself against
the previous one or fold changes back into root documents. This skill's only job is to snapshot the cycle
and (optionally) reset the workspace.

**Confirm-first ethos applies throughout**: every destructive or irreversible step requires explicit user confirmation. NEVER delete anything before the archive copy is verified.

---

## Step 0: Load the Source Rules

**MANDATORY**: Read and load `common/content-validation.md` (content validation for any generated documents).

---

## Step 1: Preconditions & Epic Identification

1. Verify `runtime-artifacts/aire-state.md` exists. If not, STOP: tell the user there is no active AIRE project to archive.
2. Resolve the **cycle type and ID**:
   - Read `## Tracker` in `runtime-artifacts/aire-state.md`. `Workflow Type: bug` → **bug mode**; `Workflow Type: enhancement` → **enhancement mode** (both: Cycle ID = `Parent Ticket`, name from the ticket title / `spec/plans/bug-brief.md` / `spec/plans/enhancement-brief.md`); otherwise **epic mode** (Cycle ID = `Parent Epic`, name from `epic-brief.md`).
   - Fallback: ask the user:
     ```
      Which Epic, Bug, or Enhancement ticket does this release cycle belong to?
        Provide the ID and name (e.g., "PROJ-50, User Authentication",
        "PROJ-123, Login timeout (bug)" or "PROJ-456, Export to CSV (enhancement)").

     [Answer]:
     ```
3. Derive the archive folder: `aire-archives/epics/<EPIC-ID>-<epic-name-slug>/` (epic mode), `aire-archives/bugs/<BUG-ID>-<ticket-name-slug>/` (bug mode), or `aire-archives/enhancements/<ENH-ID>-<ticket-name-slug>/` (enhancement mode) — kebab-case the name (e.g., `PROJ-50-user-authentication`, `PROJ-456-export-to-csv`).
4. **MANDATORY**: Log the invocation in `runtime-artifacts/audit.md` (append-only, complete raw input).

---

## Step 2: Release Readiness Check

Read the `## Story Tracker` in `runtime-artifacts/aire-state.md`:
- 🔴 **First apply the bug/enhancement exception above**: a bug/enhancement ticket left `🔵 In Development` by an **ve rejection** (`ve-rejected` label / an Option B rejection in runtime-artifacts/audit.md) is a legitimate cycle close — treat that row as READY and skip the prompt below for it entirely. Never ask "archive anyway?" for a rejected ticket.
- Otherwise, if any story is NOT `🧪 Ready for Testing`, present the list of incomplete stories and ask:
  ```
   [N] stories are not yet Ready for Testing: [list with statuses]

  Archive anyway? (yes / no)
  ```
- Block until the user answers. Log the answer in runtime-artifacts/audit.md. On "no", STOP.

### Step 2.5: ve Artifact Readiness Check (🔴 MANDATORY — the archive is one-shot)

The archive is a ONE-SHOT snapshot: anything not in the working tree right now is lost from the cycle record, and the workspace reset means nothing re-captures it later. Before archiving, verify the ve's work has actually landed on this branch. **Never skip this check, in any mode** (it is the reason bug/enhancement archives are manual).

1. **Pull the branch first**: confirm the current branch is the cycle branch and is up to date with origin (`git fetch origin && git status -sb`). If it is behind, run automatic `git pull --ff-only`.
2. **Check for the expected test docs**: for every ticket/story in scope, look for `spec/test-plans/<TICKET-ID>-<title>/`. Also check for un-merged ve branches/PRs targeting this cycle branch (`gh pr list --base <cycle-branch>` — look for `ve/...` heads).
3. If any expected test folder is **missing**, or an ve PR into this branch is still **open**, warn and ask — do NOT archive silently:
   ```
    ve artifacts look incomplete for this cycle:
      • Missing spec/test-plans/ folder for: [list of tickets/stories]
      • Open ve PR(s) into <cycle-branch> not yet merged: [list with URLs]

   Archiving now permanently omits these from the archive — the archive is one-shot and the
   workspace reset that follows leaves nothing to re-capture. Recommended: merge the ve PR(s),
   `git pull --ff-only` on <cycle-branch>, then re-run archive-epic.

   Archive anyway? (yes — archive incomplete / no — stop so I can merge the ve work)
   ```
   Block until answered. On **no**, STOP (nothing written). On **yes**, proceed and record the omission explicitly in runtime-artifacts/audit.md AND in the Step 5.4 `archive-manifest.md` as a `**Known Gaps**:` line naming exactly what was missing.
4. Log the check — folders found, PRs inspected, and the user's raw answer — in runtime-artifacts/audit.md.

### Step 2.6:  ve COMPLETION Checkpoint — bug & enhancement cycles ONLY (typed `proceed` required)

🔴 **In bug or enhancement mode this checkpoint is MANDATORY and ALWAYS runs**, even if Step 2.5 found no problems and even if the user just typed `archive-epic` deliberately. It exists because those cycles are archived manually precisely so the operator can confirm ve is finished. **Skip this checkpoint in epic mode only** (epic cycles complete ve sign-off on the epic branch before the Epic PR).

Present this message VERBATIM (substituting real values) and then **HALT — do not read, write, copy, or delete anything until the user replies**:

```
 Before I archive this [bug | enhancement] cycle — has ALL the ve work for [TICKET-ID]
   been MERGED and COMPLETED on `<cycle-branch>`

    NOT complete → do NOT proceed. Merge/finish the outstanding ve work into
      `<cycle-branch>`, then `git pull --ff-only` on it, then run `archive-epic` again.
    Complete     → type **proceed**

[Answer]:
```

**Rules for this checkpoint**:
- 🔴 **An ve REJECTION counts as COMPLETE.** "Completed" means the ve's test plan is merged and their Option B **decision has been made** — approve *or* reject. A rejected ticket (still `🔵 In Development`, carrying `ve-rejected`) closes its cycle exactly like an approved one, so never treat a rejection as outstanding work, never push the user back to `ve-list-work` over it, and never imply the archive should wait.
- **Only  `proceed`**opens the checkpoint. Anything else — "yes", "ok", "go ahead", silence, a question — is NOT consent: restate the checkpoint once and keep waiting. Never infer consent from the fact that the user invoked the skill.
- On anything indicating incompleteness, **STOP the whole skill** with nothing written, and tell the user exactly what to merge first.
- Log the checkpoint prompt and the user's complete raw answer in runtime-artifacts/audit.md before continuing.

---

## Step 3: (Removed) — No Delta Generation

🔴 **This skill no longer generates a reverse-engineering delta and does not stitch anything.**
Current-system truth lives in `spec/plans/atlas-deep-dive.md` and the flat RE docs under `spec/plans/`, and
is refreshed **fresh from Atlas via the Helix MCP** at the start of each new cycle
(`common/helix-atlas-integration.md`) — so there is nothing to diff or fold back into root documents at
cycle close. Proceed directly to the archive.

---

## Step 5: Create the Epic Archive

🔴 **Path rule for this step and every step after it**: wherever the text below writes a shorthand archive path like `aire-archives/<EPIC-ID>-<epic-name-slug>/`, the REAL path ALWAYS includes the cycle-type subfolder resolved in Step 1.3 — `aire-archives/epics/<EPIC-ID>-<slug>/`, `aire-archives/bugs/<BUG-ID>-<slug>/`, or `aire-archives/enhancements/<ENH-ID>-<slug>/`. Nothing is ever written directly under `aire-archives/`.

1. Append a final audit entry to `runtime-artifacts/audit.md` recording the archive event (epic, timestamp, archive path) — do this BEFORE copying, so the archive carries the complete trail.
2. Create the archive folder resolved in Step 1.3 — `aire-archives/epics/<EPIC-ID>-<epic-name-slug>/`, `aire-archives/bugs/<BUG-ID>-<slug>/`, or `aire-archives/enhancements/<ENH-ID>-<slug>/` — at the workspace root (create the `epics/`/`bugs/`/`enhancements/` subfolder if missing).
   - **If `aire-archives/` (or its subfolders) already exist**: reuse them as-is. NEVER recreate them, and NEVER touch, replace, or delete any OTHER cycle folder inside them — only the folder for THIS cycle is ever written.
   - **If a folder with this exact epic name already exists** inside `aire-archives/`, do NOT silently overwrite — ask:
     ```
      Archive folder aire-archives/<EPIC-ID>-<epic-name-slug>/ already exists.

     Replace it with a fresh archive from this run? (yes / no)
     ```
     - On **yes**: delete only that same-name epic folder and recreate it fresh from this run's `spec/`. All other epic folders remain untouched.
     - On **no**: STOP the archive step — do not write anything into `aire-archives/`. Log the decision in runtime-artifacts/audit.md.
   - Log the collision check and the user's raw answer in runtime-artifacts/audit.md.
3. 🔴 **Copy the live `spec/` tree, the live `reports/` tree, AND the root `runtime-artifacts/` folder into the archive, each as ONE folder.** The archive is an exact mirror — three copy commands, no unpacking, no per-folder logic, no exclusions:
   ```bash
   ARCH="aire-archives/epics/<EPIC-ID>-<epic-name-slug>"   # or bugs/ | enhancements/
   mkdir -p "$ARCH"
   cp -R spec "$ARCH/spec"
   [ -d reports ] && cp -R reports "$ARCH/reports"                       # generated outputs — mirror if present
   [ -d runtime-artifacts ] && cp -R runtime-artifacts "$ARCH/runtime-artifacts"  # audit.md + aire-state.md
   ```
   Those copies carry **everything** the cycle was built from and produced:
   - `spec/` — `architecture.md` (`spec/plans/architecture.md`) and all flat docs under `spec/plans/` (requirements, stories, personas, the design docs, `dependency-graph.yml`, `atlas-deep-dive.md` and the flat RE docs), `spec/spec-generation/`, `spec/behavior/`, `spec/test-plans/`
   - `spec/behavior/` — one `.feature` file per work unit: the Gherkin contract the code was built against
   - `reports/` — the generated outputs: `unit-test-evidence/`, `behavior-test-evidence/`, `api-contract-test-evidence/`, `eval-evidence/`, `reviews/`, `code-security-reviews/`, `ticket-summary/` (mirrored only when the live `reports/` folder exists)
   - `runtime-artifacts/` — the cycle's `audit.md` and `aire-state.md` (mirrored only when the live folder exists)
   - `spec/context-project/existing-knowledge/` and `spec/context-project/new-references/` — the human-authored inputs: the notes describing the existing system, and the wireframes/specs/mockups that defined the target

   🔴 **Mirror each exactly — same folder name, same structure, same depth.** The archive contains `spec/`, and (when present) `reports/` and `runtime-artifacts/`, not a renamed or unpacked copy. Use `ls -a` to inspect it. Keeping the names identical is what makes the copy verifiable with a single diff and the restore path unambiguous.

   The copy is ALWAYS unfiltered — there are NO exclusions.
   - **Size**: `new-references/` can hold large binaries (mockups, PDFs, videos). Record the archive's total byte size in the manifest so growth stays visible. Do **not** filter it — an incomplete reference set is worse than a large one.
   - 🔴 **GUARDRAIL — NEVER flatten**: do NOT copy any tree's *contents* into the archive folder root (never `cp -R spec/. "$ARCH/"` or `cp -R spec/* "$ARCH/"`). The archive folder must contain exactly `spec/`, `reports/` (when present), `runtime-artifacts/` (when present) and `archive-manifest.md` — never `requirements/`, `design/`, `aire-state.md` or `audit.md` sitting loose beside the manifest. Flattening instead of mirroring is the #1 cause of inconsistent archive layouts across cycles.
   - 🔴 **GUARDRAIL — ARCHIVE EVERYTHING, for EVERY cycle type**: a **complete, recursive, unfiltered** copy — every folder and every file at every depth, whatever it is named and whoever produced it. **The cycle type only changes the destination subfolder (`epics/` | `bugs/` | `enhancements/`), never WHAT gets copied**: a bug cycle archives the same full tree an epic cycle does. There are **NO exclusions** in this skill.
     - **NEVER** archive a hand-picked subset, whitelist, or "the folders this cycle touched".
     - **NEVER** skip a folder for looking empty, unused, stale, irrelevant to this cycle type, produced by another role (ve's `test-plans/`), or authored by a human rather than the framework (`existing-knowledge/`, `new-references/`). If it is inside `spec/`, it goes into the archive.
     - **NEVER** exclude dotfiles/dot-folders, hidden files, or files without a `.md` extension (logs, `.yml`, `.json`, coverage reports, images, binaries). Do not use extension- or name-based filters, and do not apply `.gitignore` rules — untracked and ignored files inside `spec/` are still archived. Use a plain recursive copy, never `git archive`, never a `find … -name '*.md'` loop.
     - **NEVER** move, delete, rewrite, truncate, reformat, summarize, or "tidy" anything while copying — the archive is a byte-for-byte snapshot, not a curated export.

4. Write `aire-archives/<type>/<CYCLE-ID>-<slug>/archive-manifest.md` (as a SIBLING of the `spec/` folder just created — NOT inside it):
   ```markdown
   # Cycle Archive Manifest
   - **Cycle**: [CYCLE-ID] — [Cycle name] ([epic | bug | enhancement])
   - **Archived**: [ISO timestamp]
   - **Stories**: [total] ([n] Ready for Testing, [n] other — list any incomplete)
   - **Analyzed At Commit**: [SHA]
   - **Archived Files**: [N] files, [total size] (complete recursive mirror of `spec/` + `reports/` + `runtime-artifacts/`; verified equal to the live trees)
   - **Contents**: spec/ docs · reports/ outputs [present/absent] · runtime-artifacts/ state [present/absent] · [N] work-unit bundles ([list slugs]) · context-project [present/absent] · new-references [present/absent, [size]]
   - **ve Artifacts**: [test folders present: list |  Known Gaps: <what was missing / which ve PR was still open> — user chose to archive anyway at Step 2.5]
   ```
5. **Verify the copy** — check BOTH of the following before proceeding; do NOT proceed until both pass:
   - **Structural check (layout guardrail)**: list the archive folder's immediate children (`ls -a aire-archives/epics/<EPIC-ID>-<epic-name-slug>/`) — it MUST contain EXACTLY `spec/`, `archive-manifest.md`, and (when the corresponding live folder exists) `reports/` and `runtime-artifacts/`. If any OTHER entry appears at this level (e.g. `requirements/`, `design/`, `aire-state.md`, `audit.md`), the copy was flattened instead of mirrored — redo Step 3 before continuing.
   - **Content check**: spot-check key files exist at their mirrored paths: `runtime-artifacts/aire-state.md`, `runtime-artifacts/audit.md`, `spec/plans/architecture.md`, `spec/plans/atlas-deep-dive.md`, one `spec/behavior/<work-unit>.feature`, and (when `reports/` was copied) one evidence file such as `reports/eval-evidence/<work-unit>/eval.json`.
   - 🔴 **Completeness check (BLOCKING — same for every cycle type)**: prove nothing was dropped, by comparing each live tree against its archived copy — every diff MUST be **completely empty**:
     ```bash
     diff <(cd spec && find . | sort) \
          <(cd "aire-archives/<type>/<CYCLE-ID>-<slug>/spec" && find . | sort)
     [ -d reports ] && diff <(cd reports && find . | sort) \
          <(cd "aire-archives/<type>/<CYCLE-ID>-<slug>/reports" && find . | sort)
     [ -d runtime-artifacts ] && diff <(cd runtime-artifacts && find . | sort) \
          <(cd "aire-archives/<type>/<CYCLE-ID>-<slug>/runtime-artifacts" && find . | sort)
     ```
     (PowerShell equivalent: `Compare-Object` on the `-Force` relative-path lists.)
     🔴 **Every diff must be empty.** Any line at all means the copy dropped or added something — re-run the full recursive copy of Step 3 and re-verify.
     **Do NOT proceed to Step 6 (which deletes the live docs) until every diff is empty.** Report the archived file count in the completion message and the manifest.
   - Log the structural check, the file count, and the completeness-diff result in the live `runtime-artifacts/audit.md` (Step 6 has not yet deleted it at this point).

**MANDATORY reference layout** — every archive folder produced by this skill MUST match this shape exactly (no exceptions, no variation between epic/bug/enhancement cycles):
```
aire-archives/epics/<EPIC-ID>-<epic-name-slug>/
├── spec/                  ← the ENTIRE spec/ tree, folder name preserved
│   ├── plans/                         ← architecture.md, atlas-deep-dive.md + flat RE docs, requirements,
│   │                                     Stories/Personas, design docs, dependency-graph.yml
│   ├── spec-generation/               ← *-generation.md plan/clarifying-question files
│   ├── behavior/                       ← .feature contracts
│   ├── test-plans/                    ← ve manual test plans
│   ├── behavior.feature
│   ├── context-project/               ← human-curated inputs (kept on option-A reset)
│   └── …                         ← EVERY other folder/file that exists under spec/, at every depth
├── reports/                       ← the ENTIRE reports/ tree (generated outputs), when it exists
│   └── …                         ← unit / behavior / api-contract / eval evidence + reviews/ + code-security-reviews/ + ticket-summary/, at every depth
├── runtime-artifacts/             ← the ENTIRE runtime-artifacts/ tree, when it exists
│   ├── audit.md
│   └── aire-state.md
└── archive-manifest.md           ← sibling of spec/, reports/ and runtime-artifacts/, never inside them
```
(`bugs/<BUG-ID>-<slug>/` and `enhancements/<ENH-ID>-<slug>/` follow the identical shape and the identical full-tree contents — the folders shown above are illustrative, not a whitelist: archive whatever exists, nothing less.)

> The **latest cycle archive folder** is a complete snapshot of the cycle — workspace detection can offer to restore human-curated context from it when a new cycle starts. Current-system truth (`atlas-deep-dive.md` and the flat RE docs) is refreshed fresh from Atlas each cycle, not restored from the archive.

---

## Step 5.5: Collapse CI Manifest Fragments (MANDATORY)

`tests/.evals/ci-manifest.d/` is not part of the `spec/`/`reports/`/`runtime-artifacts/` mirror-and-reset
above — `tests/.evals/` persists across cycles at base, inherited by the next cycle "as-is"
(`common/directory-structure.md` Artifact Ownership). Left uncollapsed, every cycle's fragments would
keep accumulating in the next cycle's checkout forever. This is the ONE place they get folded back in.

1. If `tests/.evals/ci-manifest.d/` does not exist or is empty, log that there was nothing to collapse
   and skip to Step 6.
2. Otherwise, merge every `tests/.evals/ci-manifest.d/*.json` fragment into `tests/.evals/config.json`'s
   `ci.roots[]` array, using the SAME filename-sorted, root-keyed merge
   `tests/.evals/scripts/run-static-evals.*` already performs at every gate run
   (`common/ci-pipeline-generation.md` Section 4.0f.1) — never a different, ad hoc merge here. Write the
   merged `roots[]` directly into `config.json`, and set `ci.manifestState: "resolved"` if it was
   `"unresolved"` and at least one root now exists.
3. **Delete every file under `tests/.evals/ci-manifest.d/`** (the directory itself may remain, empty) —
   their content is now permanently part of `config.json`.
4. **Verify before proceeding**: re-run `tests/.evals/scripts/validate-pipeline.{sh,ps1}` against the
   collapsed `config.json` and confirm it still passes (in particular **V28/V30** — every root's
   directory and marker file still verify) before this becomes what the next cycle inherits.
5. Log the collapse in `runtime-artifacts/audit.md` (still live at this point, before Step 6 deletes
   it): which fragments were collapsed, the resulting `roots[]` count, and the `validate-pipeline`
   result.

---

## Step 6: Reset the Live Workspace (Confirm-First)

**Auto-triggered exception — EPIC CYCLES ONLY**: if this skill was invoked **automatically by pr-generator after an Epic → Base branch PR** (not by the user typing a trigger phrase), do NOT ask the question below — **auto-select option A**. 🔴 This exception NEVER applies to bug or enhancement cycles: those are always operator-invoked, so **always ask the question** there, even if the user ran `archive-epic` immediately after the `[BUG]`/`[ENH]` PR. Announce the auto-selection to the user:

```
 Auto-triggered from pr-generator (Epic → Base PR) — applying workspace reset
   option A: clear cycle-scoped content, keep human-curated context.
```

Log the auto-selection (and that the question was skipped, with the reason) by appending to the **archived** audit copy at `aire-archives/epics/<EPIC-ID>-<epic-name-slug>/runtime-artifacts/audit.md` (the live runtime-artifacts/audit.md is deleted by this reset), then perform option A's reset. Option B is NEVER auto-selected.

Otherwise (standalone invocation), ask the user — NEVER reset without explicit choice:

```
 Archive created and verified at aire-archives/<EPIC-ID>-<epic-name-slug>/

How should the live workspace be prepared for the next cycle?

A) Reset, keep human-curated context (recommended) — clear cycle-scoped
   content (all of spec/plans/, spec/spec-generation/, spec/behavior/, spec/test-plans/,
   spec/behavior.feature, the whole reports/ tree, and runtime-artifacts/) but KEEP:
     - spec/context-project/existing-knowledge/ and spec/context-project/new-references/
       — human-authored, cross-cycle; the next cycle reads them again
   The next cycle pulls fresh current-system truth (atlas-deep-dive.md + RE docs) from Atlas.
B) Full reset — remove spec/ entirely (every doc + every work-unit bundle, AND the
   context-project/ with both its subfolders), remove reports/, and remove runtime-artifacts/
    also removes the human-curated context inputs from the working tree. They are
   in this archive, but re-curating them is manual — prefer A unless you mean to
   start from nothing

[Answer]:
```

🔴 **`spec/` (including every work unit's `.feature` file), `reports/` (all generated outputs) AND `runtime-artifacts/` are cleared on BOTH A and B** — all cycle-scoped, and Step 3 mirrored them into `<archive>/spec/`, `<archive>/reports/` and `<archive>/runtime-artifacts/`. Verify each mirror exists before deleting the corresponding live tree; if `<archive>/spec/` is missing, STOP and redo Step 3. (`reports/` may legitimately be absent if the cycle produced no outputs — only delete what was mirrored.) On option A, `spec/context-project/` is preserved in place.

🔴 **`spec/context-project/existing-knowledge/` and `spec/context-project/new-references/` are deleted ONLY on B.** They are human-authored inputs, not cycle output, so option A preserves them in place — deleting them would silently discard work no framework step can regenerate.

On A or B, `runtime-artifacts/audit.md` and `runtime-artifacts/aire-state.md` are **deleted along with the other cycle-scoped docs — do NOT seed a replacement audit.md or state file**. The archive copy holds the cycle's complete trail; the next cycle's Workspace Detection creates fresh ones. This also keeps parallel cycles conflict-free: no two PRs carry competing audit/state files onto the base branch.

**MANDATORY**: From this point on, the live `runtime-artifacts/audit.md` no longer exists — log the user's raw answer (or the auto-selection), the reset actions taken, and everything in Step 6.5 by APPENDING to the **archived** copy at `aire-archives/epics/<EPIC-ID>-<epic-name-slug>/runtime-artifacts/audit.md`, so the trail stays complete.

---

## Step 6.5: Commit & Push the Cycle-Close Changes (MANDATORY)

Everything this skill produced so far exists only in the working tree. 🔴 **If it is not committed and pushed, the cycle PR will NOT carry the archive and workspace reset.**

1. Stage the cycle-close changes:
   - `aire-archives/<EPIC-ID>-<epic-name-slug>/` (the verified archive — includes the mirrored `spec/`, `reports/` and `runtime-artifacts/`)
   - The workspace-reset changes from Step 6 (deleted cycle-scoped docs, the deleted `reports/` tree, and the deleted `runtime-artifacts/` — including `audit.md` and `aire-state.md`)
   - The Step 5.5 collapse: `tests/.evals/config.json` (updated `ci.roots[]`/`manifestState`) and the deleted `tests/.evals/ci-manifest.d/*.json` fragment files
2. Commit on the current (cycle) branch:
   ```
   docs: close cycle <EPIC-ID> — release archive, workspace reset
   ```
3. **Push (confirm-first)** — ask:
   ```
   ⬆ Push the cycle-close commit to origin/<cycle-branch>?
      [If a PR is already open for this branch:] The open PR (<PR URL/number>) tracks this
      branch and will automatically include this commit.
      (yes / no)
   ```
   On yes: push and verify (`git log origin/<cycle-branch> -1`). On no: warn that the archive + reset are not on origin until this commit is pushed. Log the answer and outcome by appending to the archived audit copy (`aire-archives/epics/<EPIC-ID>-<epic-name-slug>/runtime-artifacts/audit.md`).
4. If a PR is open for this branch (`gh pr list --head <cycle-branch>`), confirm after pushing that the PR now includes the commit.
5. **Update the PR description** so reviewers aren't surprised by the cycle-close diff: fetch the current body (`gh pr view <PR> --json body`) and append (via `gh pr edit <PR> --body ...`, never replacing the existing content):
   ```markdown
   ##  Cycle-Close Commit (added after PR creation)
   This PR also includes the cycle-close commit from `archive-epic`:
   - **Added**: release archive at `aire-archives/<EPIC-ID>-<slug>/` (complete `spec/` + `reports/` + `runtime-artifacts/` snapshot incl. audit trail and state)
   - **Removed**: cycle-scoped working docs (spec/plans, spec/spec-generation, behavior, test-plans), the `reports/` tree, and `runtime-artifacts/` (`audit.md`, `aire-state.md`) — preserved in the archive above
   ```

---

## Step 7: Completion Message

```markdown
# Cycle Archive Complete

- **Archive**: `aire-archives/<EPIC-ID>-<epic-name-slug>/`
- **Contents**: `spec/` (all planning/design artifacts, every work-unit `.feature`) + `reports/` (generated outputs) + `runtime-artifacts/` (audit.md, aire-state.md)
- **Workspace**: [reset choice taken]
- **Cycle-close commit**: [pushed to origin/<cycle-branch> — included in PR <URL> |  NOT pushed — push it so the archive reaches the base branch]

➡ NEXT ACTION:
   1⃣  Merge the open PR into `<base-branch>`: <PR URL>
       (the cycle-close commit above rides this PR)

   The next cycle pulls fresh current-system truth (atlas-deep-dive.md + RE docs) from Atlas via the
   Helix MCP — there is nothing to stitch.
```

**Rules for this message**:
- Substitute every placeholder with real values (`<base-branch>` and the PR URL from `## Branching` / `gh pr list`) — never ship a placeholder to the user.
- If the cycle-close commit was **NOT pushed** (the user answered "no" at Step 6.5), replace line 1⃣ with: `1⃣   Push the cycle-close commit first: git push origin <branch>`.
- Output **nothing after this block** — no options menu, no further suggestions.
