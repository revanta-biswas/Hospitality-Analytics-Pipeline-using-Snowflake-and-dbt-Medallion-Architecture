---
name: ve-list-work
description: >
  Moves a tracker ticket through the ONE transition this skill performs: `In Development` →
  `Ready for Testing` — ve sign-off of merged work. Works with whichever tracker is configured
  (Jira, Azure DevOps, GitHub, or Local). Pulls the cycle's integration branch — the
  epic branch for epic cycles, the bug/enhancement branch for those cycles, NEVER the base branch —
  then asks the ve to pick one of
  three local actions: A) List — merged vs. still-in-development stories, status read LIVE from
  the tracker; B) Approve/Reject — the sign-off decision (one prompt, one decision per item,
  e.g. `1.1 approve`, `PROJ-103 reject`); approved items get a "ve approved the story"
  comment + ve-approved label/tag + move to Ready for Testing in the Story Tracker AND the tracker,
  rejected items get a "ve rejected the story" comment + ve-rejected label/tag and deliberately
  stay In Development (ve is told to manually log the defect with `/raise-defect`); C) Request
  changes to a story's `/ve-implement`-generated test plan — add/adjust a manual test case, traced to an
  acceptance criterion, without touching code, branches, or status. Every run closes with a
  confirm-first Approve/Request-Changes gate before the completion message. Confirm-first
  throughout; every tracker change is verified after (LOCAL updates the local Story Tracker only). Only Option B writes to the Story Tracker and
  `runtime-artifacts/audit.md`; only Option C writes to a story's `/ve-implement` test-plan files; Option A writes nothing.
when_to_use: >
  Trigger when the user says: "ve-list-work", "ve list work",
  "ve-signoff", "ve sign off", "ve signoff", "which stories are merged",
  "which stories can I test", "what has dev merged into the epic branch",
  "what has dev merged into the bug branch", "show me merged stories to test",
  "move tested stories to ready for testing", "story is tested move it to ready for testing",
  "ve done testing story 1.2", "mark story ready for testing",
  "sign off this bug", "sign off this enhancement", "ticket is tested",
  "ve approved", "ve rejected", "approve the story", "reject the story",
  "found a bug in a merged story", "disapprove this story",
  "change the test plan for this story", "add a test case to the ve test plan",
  "update the test plan for story 1.2".
allowed-tools: Read Grep Glob Edit Write Bash
---

# 🧪 ve List Work — ve Sign-off of Merged Work

**This skill performs exactly ONE tracker transition**: `In Development` → `Ready for Testing`.
There is no other transition to pick — never ask the user which transition they want, and never
offer "Ready for Testing → In Testing", "In Testing → Ready to Deploy", or
"In Testing → Ready for Development". Those do not exist in this skill. Dispatches per `## Tracker` → `Type` (JIRA/ADO/GITHUB/LOCAL), per `common/tracker-sync.md` Section 4.

**Who runs this**: the **ve**, on the **integration branch** — after developers have merged
their PRs into it.

**🔴 The integration branch is ALWAYS the cycle's own working branch — NEVER the base branch:**

| Cycle | `Workflow Type` | Integration branch | What merges into it | What gets signed off |
|-------|-----------------|--------------------|---------------------|----------------------|
| **Epic** | `epic`, or field absent | the **Epic Branch** (e.g. `epic/PROJ-50-checkout`) | each story's `[STORY]` PR + the ve's `ve/…` test-plan PRs | the epic's stories, one or many |
| **Bug** | `bug` | the **Bug Branch** (e.g. `bug/PROJ-123-login-timeout`) | the fix commits + the ve's `ve/PROJ-123-…` test-plan PR | the single bug ticket |
| **Enhancement** | `enhancement` | the **Enhancement Branch** (e.g. `enhancement/PROJ-456-csv-export`) | the enhancement commits + the ve's `ve/PROJ-456-…` test-plan PR | the single enhancement ticket |

🔴 **This skill NEVER runs on the base branch, for ANY cycle type.** All three options (A, B, C) run
on the cycle branch, and they run **BEFORE** `archive-epic` and **BEFORE** the cycle's PR merges into
base — identical to how epic cycles have always worked. Once the cycle's PR merges the cycle is
complete; `ve-list-work` has no role on the base branch.

Why (bug/enhancement cycles changed to this): running sign-off post-merge on the base branch was
broken — by then `archive-epic`'s workspace reset had already deleted `runtime-artifacts/aire-state.md`,
so Option B had no Story Tracker to promote, and Option C's test-plan amendments landed after the
one-shot archive had already been taken (so they were never captured). Signing off on the cycle
branch fixes both: the tracker still exists, and every ve change is on the branch in time for the
archive and for the cycle PR that carries it to base.

**Note on the `[BUG]`/`[ENH]` PR**: on bug/enhancement cycles that PR is **raised but NOT yet merged**
when this skill runs — do NOT require it to be merged. What must be merged/present on the cycle branch
is the **development work itself** (the fix/enhancement commits) and the ve's **test-plan PR**. This
mirrors epic cycles, where sign-off happens on the epic branch while the Epic PR is still open.

Everything below says **integration branch** where the behaviour is identical for all cycles; wherever
epic and bug/enhancement differ, the difference is called out explicitly. "Story" below means *story*
on epic cycles and *ticket* on bug/enhancement cycles — the tracker row and the logic are the same.

**🔴 Once on the integration branch, the ve picks ONE of three local actions (Step 2) — this is
the only menu in this skill:**

```markdown
A) List merged stories with status in-development 
B) Approve / Reject a story after testing (ve sign-off)
C) Request changes to a story's test plan (generated by /ve-implement)
```

**What this skill does**, in order:
1. Resolves the integration branch (the epic / bug / enhancement branch — never the base branch) and pulls the latest (Step 1).
2. Asks the ve to choose one of the three actions above (Step 2).
3. **Option A**: prints ONE table — the stories whose dev PR has MERGED and that are still
   In Development (live tracker status), i.e. the ones waiting on the ve. Read-only: no second
   table, no approve/reject prompt, no closing gate.
4. **Option B**: prints the same table, then **asks one question**: for each merged item, whether
   the ve **approves** or **rejects** it (bug found) — reported per-item, e.g. `1.1 approve`,
   `1.2 reject`.
   - **Approved** → tracker comment `ve approved the story` + **`ve-approved`** label/tag + move
     `🔵 In Development` → `🧪 Ready for Testing` in the Story Tracker **and** the tracker (LOCAL: Story Tracker only). Announce it
     simply as **passed**, and log it in `runtime-artifacts/audit.md`.
   - **Rejected** → tracker comment `ve rejected the story` (with the ve's finding) + **`ve-rejected`**
     label/tag. **Status deliberately unchanged** — it stays `🔵 In Development` for the dev team to
     fix. Tell the ve to manually log the defect with the **`/raise-defect`** skill.
   - **Epic cycles only**: if that leaves **every** story `🧪 Ready for Testing`, offers
     (confirm-first) to move the **Parent Epic** too, then points at `pr-generator` for the Epic
     PR. Bug/enhancement cycles have no Parent Epic and no Epic PR — their `[BUG]`/`[ENH]` PR already
     exists, so they go on to **`archive-epic` on this same cycle branch** (while that PR is still open),
     then the PR merge completes the cycle.
5. **Option C**: asks for a story's Tracker ID, shows its current `/ve-implement` test plan, asks what to
   add/change and in which plan file, then edits it — never touching code, branches, status, or
   the tracker.
6. **Closes with an Approve / Request Changes gate (Step 9)** before presenting the final
   completion message — never closes silently.
7. Logs the run — list, sign-off decisions, or test-plan edit — in `runtime-artifacts/audit.md`.

**What this skill deliberately does NOT do**: run any build, run any tests, generate new test
artifacts outside an explicit Option C edit, raise/merge/close any PR, promote anything the ve
did not approve, or change the status of anything the ve rejected.

> **Relationship to `/ve-implement`**: `/ve-implement` produces the manual test steps the ve executes
> (`spec/test-plans/<TICKET-ID>-<title>/`) and never changes status. This skill changes
> status — and only on the ve's explicit approval, after the ve has actually tested the work.
> Option C is the one place this skill edits those `/ve-implement` artifacts directly, on the ve's request.

> **Relationship to `/playwright-implement`** (opt-in extension): once a story shows both a merged
> dev PR and merged ve test-plan PR in Step 3's table, `/playwright-implement <story>` can turn the
> manual steps into executable Playwright automation — run it in a separate terminal, since it's a
> longer sequential flow, while this skill keeps working the Approve/Reject queue for other stories.
> It runs **directly on the same integration branch** — no branch of its own, no PR — and pushes
> straight to that branch after its own confirm-first push gate. This skill's Step 3 surfaces
> automation status when the extension is enabled; neither skill changes story or tracker status —
> that remains this skill's Option B alone.

**🔴 File-writing boundary:**
- **Option A**: writes NOTHING.
- **Option B**: updates the `## Story Tracker` in `runtime-artifacts/aire-state.md` and appends one
  entry to `runtime-artifacts/audit.md` recording every approval and rejection. On JIRA/ADO/GITHUB it also adds a
  comment and an `ve-approved` / `ve-rejected` label/tag per item; LOCAL updates only the Story Tracker.
- **Option C**: edits a story's `/ve-implement` test-plan artifacts under `spec/test-plans/` — the only
  other file location this skill ever writes to.
- **None of the three options ever touch application code, branches, or PRs.**

---

## Step 0: Preconditions

1. Read `## Tracker` → `Type` from `runtime-artifacts/aire-state.md`. Confirm the matching integration is available: **JIRA** — Atlassian MCP connected; **ADO** — `az account show` succeeds; **GITHUB** — `gh auth status` succeeds; **LOCAL** — nothing to check. If a required integration isn't connected, stop and tell the user to connect it first — do not attempt workarounds.
   *(Exception: if the integration is unavailable, Option A/B may still reconcile the local Story Tracker
   — it must then clearly report which tracker reads/transitions were skipped.)*
2. `runtime-artifacts/aire-state.md` must exist with a `## Story Tracker` and a `## Branching` section.
   If it doesn't, stop and say there is no project state to read.
3. The GitHub CLI (`gh`) must be available and authenticated (`gh auth status`). Merge state is
   read from GitHub — never guessed. If `gh` is unavailable, stop and say so (Option C, which
   never needs merge state, may still proceed).

---

## Step 1: Get on the Right Branch and Pull Latest

1. Read `## Branching` and `Workflow Type` in `runtime-artifacts/aire-state.md` to resolve the **integration
   branch** — this is the ONE decision that differs between cycle types, so make it first:
   - **Epic cycle** (`Workflow Type: epic`, or the field is absent) → the **Epic Branch** recorded
     in `## Branching` (e.g. `epic/PROJ-50-checkout`). Story PRs merge here.
   - **Bug cycle** (`Workflow Type: bug`) → the **Bug Branch** recorded in `## Branching`
     (e.g. `bug/PROJ-123-login-timeout`). 🔴 **NOT the base branch** — sign-off happens on the bug
     branch, before `archive-epic` and before the `[BUG]` PR merges.
   - **Enhancement cycle** (`Workflow Type: enhancement`) → the **Enhancement Branch** recorded in
     `## Branching`. 🔴 **NOT the base branch** — same reasoning as bug.
   - 🔴 The base branch is NEVER the integration branch for any cycle type. If the ve is standing on
     the base branch, tell them to switch to the cycle branch — a cycle has no base-branch action for
     this skill; the cycle completes when its PR merges.
   - Announce which one you resolved and why, e.g.
     ` Epic cycle → integration branch is the epic branch \`epic/PROJ-50-checkout\`.` or
     ` Bug cycle → integration branch is the bug branch \`bug/PROJ-123-login-timeout\`.`
2. Check the current branch: `git branch --show-current`.
   - If it is **not** the resolved integration branch, say which branch this skill expects for
     THIS cycle type (epic branch / bug branch / enhancement branch) and ask to switch
     (`git checkout <integration-branch>`) — confirm before switching, and never switch while
     there are uncommitted changes.
3. **Pull the latest**: `git fetch origin` then `git pull --ff-only`. Report what came in
   (e.g. `⬇ Pulled 4 commits into epic/PROJ-50-checkout`, or `⬇ Pulled 2 commits into main`). If
   the pull fails (diverged / dirty tree), stop and report — do not force anything.
4. **Exception — Option C (Step 8) does not need this branch context.** If the user's request
   already makes it obvious they only want to edit a `/ve-implement` test plan (option C), you may still run
   Step 1 for consistency (it's harmless), but do not block C on a failed pull or branch mismatch —
   a test plan edit touches documentation only, never code.

---

## Step 2: Choose What To Do

Ask which of the three local actions the ve wants (skip if their request already makes it clear):

```markdown
 What do you want to do on `<integration-branch>`?

   A) List the stories whose dev PR has MERGED and are still In Development  (read-only)
   B) Approve / Reject a story after testing (ve sign-off)
   C) Request changes to a story's test plan (generated by `/ve-implement`)

[Answer]:
```

Accept `A`/`B`/`C`, `1`/`2`/`3`, or unambiguous wording — "which stories are merged" / "what's
still in development" → **A**; "story 1.1 approve", "I tested it, it passed", "reject PROJ-103" →
**B**; "add a test case to...", "change the test plan for..." → **C**.

- **A** → go to **Step 3**, print the one table, then go straight to **Step 10**. **Skip Step 9 entirely** — Option A changes nothing, so there is nothing to approve.
- **B** → go to **Step 3**, then **Step 4 → Step 5/Step 6 → Step 7**.
- **C** → skip Step 3–Step 7 entirely, go straight to **Step 8**.

---

## Step 3: Read the Story Tracker and Classify Every Story — status read LIVE from the tracker

Read `## Story Tracker` in `runtime-artifacts/aire-state.md`. It carries the columns the development
workflows write:

| Story | Title | Requires | Tracker ID | Status | PR | Merged | Start | End | Recorded |
|-------|-------|----------|------------|--------|----|--------|-------|-----|----------|

- **PR** — the PR URL, written by `dev-implement` for a story `[STORY]` PR into the
  **epic branch**, and by `bug-fix-implement` / `enhancement-implement` for a `[BUG]`/`[ENH]` PR
  into the **base branch**. `—` until a PR exists.
- **Merged** — `no` once the PR is raised, `yes` once confirmed merged, `—` before a PR exists.
  🔴 On bug/enhancement cycles this column stays `no` throughout this skill's run — the `[BUG]`/`[ENH]`
  PR merges only after `archive-epic`. That is expected and must NOT block sign-off (see the MERGED
  classification below).

On a **bug or enhancement** cycle the tracker holds a single row (the ticket); on an **epic** cycle
it holds one row per story. The classification below is identical either way.

**🔴 Status comes from the tracker LIVE, not from this file (JIRA/ADO/GITHUB).** For every row that carries a
non-LOCAL Tracker ID, fetch its current status (`getJiraIssue` / `az boards work-item show` / `gh issue view`, per `common/tracker-sync.md` Section 2) and use THAT as the row's status for this
run — the local `Status` column can go stale (e.g. someone transitioned it outside this skill).
If the live tracker status differs from the tracker's `Status` column, treat the drift as a factual
correction: refresh the tracker's `Status` to match the live value and note the correction (this is not an
ve decision — only Step 4's approve/reject changes status). LOCAL rows have no external board
to read from — use the tracker's `Status` column for those.

Classify every row using the live status plus merge state:

**🟩 MERGED — testable now**:

- **Epic cycles** — `Merged = yes`, **or** `PR` is populated and
  `gh pr view <PR-URL-or-number> --json state,mergedAt,baseRefName` reports `state == "MERGED"`, AND
  the live tracker status (or local Status) is still short of `Ready for Testing`. Sanity-check
  `baseRefName` against the resolved integration branch — a story PR should have merged into the
  **epic branch**. If it merged somewhere else, note it but still treat it as merged.
- 🔴 **Bug / enhancement cycles — do NOT require the `[BUG]`/`[ENH]` PR to be merged.** That PR targets
  the base branch and is still **open** at this point by design (it merges only after `archive-epic`).
  Testability here means the work is present on the cycle branch:
  1. the fix/enhancement commits are on the branch (the tracker row has `End` set and a `PR` URL — i.e.
     `bug-fix-implement` / `enhancement-implement` completed and raised the PR), **and**
  2. the ve's own test-plan PR (`ve/<TICKET-ID>-…` → the cycle branch) has **merged**, so
     `spec/test-plans/<TICKET-ID>-…/` exists in the working tree.
  Verify (2) with `gh pr list --base <cycle-branch> --head ve/<TICKET-ID>` (state MERGED) plus the folder's
  presence. Treat the row as 🟩 MERGED when both hold and the live tracker status is short of `Ready for
  Testing`. If the `[BUG]`/`[ENH]` PR happens to be merged already, that is fine too — but never wait for it.
  If (2) is missing, classify the row as NOT testable and tell the ve to merge their `/ve-implement`
  test-plan PR into the cycle branch first — there is no test plan to execute otherwise.
When `gh` confirms a merge that the tracker still has as `Merged = no`, set the tracker's
`Merged` column to `yes` and refresh `Recorded` (a factual correction — the **Status** column is
NOT changed here; only the ve's answer in Step 4 changes status).

**Everything else** — not merged, or already at `Ready for Testing` or beyond — is **simply not
listed**. It is not a sign-off candidate, so it does not belong in the output. Do NOT print a
"still in development", "not started", "already actioned" or "needs attention" table.

**If the Playwright Test Automation extension is enabled** — read `## Extension Configuration` in
`runtime-artifacts/aire-state.md` per `requirements-analysis.md` Step 5.1's canonical table format
(`| Extension | Enabled | Decided At |`); find the row where `Extension` is "Playwright Test
Automation" and check its `Enabled` column for `Yes` — also compute an **Automation** column per
row: check for `tests/e2e/<story-slug>/*.spec.ts` at the workspace root and/or
`spec/test-plans/<TICKET-ID>-<title>/automation-summary.md`. If either exists, show  (with the
pass/fail count from `automation-summary.md` if present); if the row's manual test steps exist but
automation doesn't yet, show "— not generated (run `/playwright-implement <story>` in a separate
terminal)"; if manual test steps don't exist yet either, omit the automation suggestion — there's
nothing for the Planner to scope to until `/ve-implement` runs first. **If no such row exists, or
its `Enabled` column is `No`, omit the Automation column entirely** — do not show it as a permanent
"—".

**Print exactly ONE table — the sign-off candidates** (merged PR + still short of Ready for
Testing). This is the whole of Option A's output, and the same table Option B works from:

```markdown
# ve Sign-off — `<integration-branch>` (<epic branch | bug branch | enhancement branch>, up to date)

## 🟩 Dev PRs MERGED into `<integration-branch>`

| # | Story | Tracker ID | Title | PR | Merged on | Manual test steps | Automation | Live status |
|---|-------|------------|-------|----|-----------|-------------------|------------|-------------|
| 1 | 1.1 | PROJ-101 | [title] | #12 | [date] | `spec/test-plans/PROJ-101-<title>/`  |  13 passing, 1 fixme | 🔵 In Development |
| 2 | 1.2 | PROJ-102 | [title] | #15 | [date] | — not generated (run `/ve-implement 1.2`) | — | 🔵 In Development |

(Drop the **Automation** column entirely if the extension is `Disabled`.)

> 🧪 Merged into `<integration-branch>` — execute the manual test steps in each folder above
> (generate them with `/ve-implement <story>` where missing). You can run them in a separate terminal.
> Where manual steps exist but automation doesn't yet, run `/playwright-implement <story>` — also
> in a separate terminal, since it's a longer sequential run (Planner → your approval → Generator →
> headed execution → Healer).

```

**Nothing else goes in this output.** No second table, no approve/reject wording (that is Option B,
Step 4), no commentary. On a **bug/enhancement** cycle there is normally exactly one row — same
single table, one ticket. If **nothing** has a merged PR, say exactly that in one line and stop.

---

## Step 4: Ask What the ve APPROVES and what the ve REJECTS  *(Option B only)*

Once you have tested a merged item and reached a decision, report it below. An approval is an ve
sign-off, a rejection is an ve defect call. Both are recorded on the tracker ticket (JIRA/ADO/GITHUB) or the local Story Tracker (LOCAL) and in
`runtime-artifacts/audit.md`; only an approval changes status.

**If the Automation column (Step 3) showed a result for an item, factor it into the decision** —
don't treat manual execution and automation as separate tracks. A `test.fixme()` candidate defect
from the Healer is real signal a rejection may be warranted, same as a manually-found bug; passing
automation is corroborating evidence for an approval, not a substitute for having actually tested it.
If automation hasn't been generated yet for an item (Step 3 showed "not generated"), that's fine —
the decision can still be made from manual execution alone; automation is not a blocking prerequisite
for sign-off, just additional evidence when it exists.

**One question, covering every merged item:**

```markdown
> **For each merged item, give your decision: approve or reject.**
> Format: `<story or Tracker ID> approve` or `<story or Tracker ID> reject` — one per line, or
> comma-separated — e.g.:
> 1.1 approve
> 1.2 reject
> PROJ-103 reject
> (Bug/enhancement cycle: there is one ticket — answer with its key and approve/reject.)
> If you found a bug on a rejected item, note it — for logging that as a tracked defect,
> use the skill `/raise-defect` after this.
```

Rules for interpreting the answer:
- Only stories listed under **🟩 MERGED** are eligible for a decision. If the ve names a story
  that is still in development, not started, or already Ready for Testing, say why it can't be
  actioned and process the rest.
- Every merged item must get exactly one decision — `approve` or `reject`. An item left out is
  simply not actioned this run (stays as-is); do not guess a decision for it.
- **A story cannot be both approved and rejected.** If the ve names the same story with both
  decisions, stop and ask which one they meant — never guess, and never apply both.
- **Never approve or reject a story the ve did not name.** No defaults, no "while we're here".
- If no items were given a decision, skip Step 5 and Step 6 and go to Step 9.

---

## Step 5: APPROVED stories — comment, label/tag, transition  *(Option B only)*

For **each** story the ve APPROVED in Step 4:

1. **Story Tracker** (`runtime-artifacts/aire-state.md` → `## Story Tracker`):
   - **Status** → `🧪 Ready for Testing`
   - **Merged** → `yes`
   - **End** → today's date (`YYYY-MM-DD`) if not already set
   - **Recorded** → current timestamp (`YYYY-MM-DD HH:MM`), from a real clock
2. **Tracker** — only if the story's `Tracker ID` column holds a non-LOCAL value (not `—`). Dispatch per `## Tracker` → `Type`, per `common/tracker-sync.md` Section 4/Section 9/Section 10, doing all three (comment, label/tag, transition), in this order:
   - **a) Comment (MANDATORY)** — leading with the exact phrase
     **`ve approved the story`**: JIRA `addCommentToJiraIssue`, ADO `az boards work-item update --discussion`, GITHUB `gh issue comment`:
     ```
     ve approved the story.

     Tested by: [session email]
     Merged PR: <PR URL>
     Test steps: spec/test-plans/<TICKET-ID>-<title>/
     Moving to Ready for Testing.
     ```
   - **b) Label/tag (MANDATORY)** — add **`ve-approved`**: JIRA via `editJiraIssue`, ADO via `System.Tags`, GITHUB via `gh issue edit --add-label`.
     🔴 **APPEND to the existing labels/tags — never replace them.** Re-fetch the issue, take its current
     labels/tags, add `ve-approved` if absent, and write the full set back. Existing labels
     such as `ai-generated` and `aire-v[N]` MUST survive. If the issue already carries
     `ve-rejected` from an earlier round, remove it in the same update — an approved story must
     not stay labelled rejected.
   - **c) Transition** — JIRA: `getTransitionsForJiraIssue` → match the board state that mirrors
     **Ready for Testing** (case-insensitive; accept close variants such as "Ready for QA" /
     "In Review"), then `transitionJiraIssue`; ADO: `az boards work-item update --state "Resolved"` (or the project's verified equivalent); GITHUB: swap the status label to `status:ready-for-testing`. **Verify** by re-fetching the issue.
   - If the transition is rejected, list the available transitions/states and retry with the exact name.
     If it still fails, **report honestly** — never claim a transition that didn't land. The comment
     and label stay on the ticket; say so.
   - LOCAL stories (`Tracker ID = —`/`LOCAL`): update the tracker only — no external comment/label/transition to apply.
3. Announce each one, simply and plainly — the ve doesn't need the mechanics restated every time:
   ` Story 1.1 (PROJ-101) — Passed. → 🧪 Ready for Testing (comment + \`ve-approved\` label added, tracker synced).`
   Log the full detail (comment text, label, transition verification) in `runtime-artifacts/audit.md` regardless —
   the short form is only what's shown to the ve in chat.

**Never update only one side.** The local Story Tracker and the external tracker (when one is configured) stay in sync.

---

## Step 6: REJECTED stories — comment, label/tag, NO status change  *(Option B only)*

For **each** story the ve REJECTED in Step 4. These stories **stay `🔵 In Development`** — the
ve found a bug, so the work goes back to the dev team. **Do NOT transition them, and do NOT
change their Status in the Story Tracker.**

1. **Ask for the reason once per rejected story** (the dev picking it back up needs it):
   ```
   > What did you find wrong with Story [N.M] ([TICKET-ID])?
   > (steps to reproduce / expected vs actual / environment — or `skip` for no detail)
   ```
2. **Tracker** — only if the story's `Tracker ID` column holds a non-LOCAL value (not `—`), dispatched per `## Tracker` → `Type`:
   - **a) Comment (MANDATORY)** — leading with the exact phrase
     **`ve rejected the story`**: JIRA `addCommentToJiraIssue`, ADO `az boards work-item update --discussion`, GITHUB `gh issue comment`:
     ```
     ve rejected the story.

     Tested by: [session email]
     Merged PR: <PR URL>
     Test steps: spec/test-plans/<TICKET-ID>-<title>/
     Finding: [ve's reason from step 1, or "no detail provided"]
     Status unchanged — remains In Development for the dev team to fix.
     ```
   - **b) Label/tag (MANDATORY)** — add **`ve-rejected`**, using the same
     **append-never-replace** rule as Step 5b. If the issue already carries `ve-approved` from an
     earlier round, remove it in the same update.
   - **c) NO transition.** Never transition a rejected story on any tracker.
   - LOCAL stories (`Tracker ID = —`/`LOCAL`): record the rejection in `runtime-artifacts/audit.md` only — no external comment or
     label to apply.
3. **Story Tracker**: leave **Status** and **End** untouched. You MAY refresh **Recorded** to now.
   Nothing else in the row changes.
4. Announce each one:
   ` Story 1.3 (PROJ-103) — ve rejected (comment + \`ve-rejected\` label added). Status unchanged: 🔵 In Development.`
   `Please manually log the defect using the skill /raise-defect.`
5. After all rejections, point the ve at the defect flow — a label is not a bug ticket:
   ```
    Please manually log these as tracked defects using the skill: /raise-defect
   ```

---

## Step 7: Parent Epic → Ready for Testing (EPIC CYCLES ONLY, confirm-first)  *(Option B only)*

**🔴 This step applies to EPIC cycles only** — the ones whose integration branch is the **epic
branch**. Bug and enhancement cycles run on their own cycle branch, have no Parent Epic and no Epic PR:
**skip this step entirely** for them and go to Step 9.

Re-read `## Story Tracker` after Step 5–Step 6. Run this step **only** if **EVERY** story is now
`🧪 Ready for Testing`. If even one story is `🟢 Ready for Development` or `🔵 In Development`,
**skip this step entirely** — the Epic stays where it is.

Resolve the **Parent Epic** from `## Tracker` in `runtime-artifacts/aire-state.md`:
- `Parent Epic: none`, no `## Tracker`, `Type: LOCAL`, or `Workflow Type: bug` / `Workflow Type: enhancement`
  → **skip silently**.
- Otherwise ask, and wait:
  ```
   All [N] stories are 🧪 Ready for Testing — the ve has signed off the whole epic.
  Move Parent Epic [EPIC-ID] to "Ready for Testing"? (yes / skip)
  ```
  On **yes**: transition per `common/tracker-sync.md` Section 4 (JIRA: `getTransitionsForJiraIssue` → `transitionJiraIssue`; ADO: `az boards work-item update --state`; GITHUB: swap the status label) → **verify** by
  re-fetching the issue → add a comment summarising the ve sign-off. If the transition is rejected,
  list the available transitions/states and retry with the exact name; if it still fails, report honestly.
  On **skip**: note the skip and continue.

This is the only thing in this skill that touches the Parent Epic.

---

## Step 8: Request Changes to a Story's Test Plan  *(Option C only)*

**Only run this when the user picked C in Step 2.** This is the one place `ve-list-work`
edits the `/ve-implement` skill's output (`spec/test-plans/<TICKET-ID>-<title>/`) — it never touches
code, branches, PRs, story status, or tracker status.

1. **Ask which story's test plan to change** (skip if already given):
   ```
    Which story's test plan do you want to change? (Tracker ID, e.g. PROJ-102, or Story ID)
   [Answer]:
   ```
2. **Resolve the test folder**: `spec/test-plans/<TICKET-ID>-<title-kebab>/` (or
   `spec/test-plans/story-<N.M>-<title-kebab>/` for a local-only story — see
   `aire-workflow/implementation/test-plan.md` Output Location for the exact naming
   convention). If it doesn't exist, tell the user no test plan has been generated yet and point
   them at `/ve-implement <story>` — do NOT create one here.
3. **Show the current plan** — read `test-plan-summary.md` from that folder and present its
   **Applicable Test Plans** and **Acceptance Criteria → Test Case Coverage** tables, so the ve
   can see what already exists before asking for a change.
4. **Ask what to add or change, and where**:
   ```
    What do you want to add or change, and in which test plan?
      (e.g. "add a negative test case to api-test-steps.md for AC-3",
       "add a boundary case to integration-test-steps.md")
   [Answer]:
   ```
5. **Apply the change** using the exact rules and format from
   `aire-workflow/implementation/test-plan.md`:
   - Every new/changed test case MUST use the `TC-[PLAN]-[nn]` format from that file's Step 3
     (Traces to / Type / Priority / Preconditions / Test data / Steps / Expected result /
     Pass-Fail criteria / Cleanup).
   - Every case MUST trace to an AC (`AC-[n]`) — ask the ve which AC it covers if unclear; never
     invent one.
   - Update `test-plan-summary.md`'s test-plan case count and its
     **Acceptance Criteria → Test Case Coverage** table to include the new/changed case(s).
6. **Show the exact new/changed section** and wait for confirmation before writing anything.
7. On confirmation, write the file(s) and announce:
   ` Updated spec/test-plans/<TICKET-ID>-<title>/<file> — added TC-[PLAN]-[nn], traced to AC-[n].`

**Never changes story or tracker status here.** That remains Option B's job alone.

---

## Step 9: Approve or Request Changes (confirm-first gate — **Options B and C only**)

**🔴 Option A never reaches this step** — it is read-only, so there is nothing to approve and no
changes to request. Option A goes from Step 3 straight to Step 10.

For Options B and C, present what happened and require an explicit decision before closing —
never close silently.

```markdown
[Summary of what this run did:
 - Option B: the sign-off decisions from Step 4–Step 7
 - Option C: the test-plan change from Step 8]

 **Do you approve this, or do you want to request changes?**

   1)  Approve — accept this as final
   2)  Request Changes — go back and adjust

[Answer]:
```

- On **Approve** → proceed to **Step 10** (Close the Run).
- On **Request Changes** → ask what to adjust, loop back to the relevant step (**Step 4** to
  change a decision, or **Step 8** to revise the test-plan edit), then
  re-present this gate once the adjustment is made. Never skip straight to closing — always land
  back on this gate.

---

## Step 10: Close the Run

**Option A (list only)** — the Step 3 table IS the output. Nothing changed, so add only this
one-line footer beneath it and stop:
```markdown
➡ Run this skill again and pick **B** once you have tested, or **C** to adjust a test plan.
```
Do not repeat the table, do not restate the branch, do not add a summary block.

**Option B (sign-off)**:
```markdown
# ve sign-off recorded

** ve approved → 🧪 Ready for Testing**: [Story 1.1 (PROJ-101), … — or "none this run"]
   (comment + `ve-approved` label added on each)
** ve rejected — stay 🔵 In Development**: [Story 1.3 (PROJ-103), … — or "none this run"]
   (comment + `ve-rejected` label added on each; no status change — please manually log the
   defect using the skill `/raise-defect`)
**Still 🔵 In Development (not actioned)**: [merged-but-not-yet-tested, plus open-PR stories]
**Parent Epic**: [EPIC-KEY → Ready for Testing (verified) / skipped / not applicable]
**Branch**: `<integration-branch>` — <epic branch | bug branch | enhancement branch> (pulled to latest)

➡ **Next, whenever you are ready:**
   • `/ve-implement <story>` — generate the Test Plan manual steps for a story that has none
   • this skill again (**A**) — check what else is merged and ready to test
   • this skill again (**B**) — after you have tested more merged stories
   • `/raise-defect` — manually log a tracked bug for anything you rejected
```

**If this run signed off the last outstanding item**, replace the "Next" list above with the
matching completion handoff — pick by cycle type:

**Epic cycle (integration branch = epic branch), every story now `🧪 Ready for Testing`:**
```markdown
➡ **NEXT ACTION — one keyword:**
   1⃣  Confirm you are on the epic branch `<epic-branch>`.
   2⃣  Type this keyword: /pr-generator
       It raises/updates the Epic PR `<epic-branch>` → `<base-branch>` and AUTO-triggers
       archive-epic. Merging that Epic PR completes the cycle.

🔴 Type the keyword `pr-generator` EXACTLY as shown — do not describe what you want in your own
   words. Any other phrasing is not a framework trigger and the workflow will not advance.
```

**Bug / enhancement cycle (integration branch = the bug/enhancement branch), ticket now `🧪 Ready for Testing`:**
```markdown
➡ **NEXT ACTIONS — do these in order:**
   1⃣  Commit + push any test-plan edits you made (Option C) so they are on `<cycle-branch>`
       — the archive in 2⃣ can only capture what is on the branch.
   2⃣  Use the skill archive-epic — run it HERE, on `<cycle-branch>`, while the [BUG]/[ENH] PR is
       still OPEN. It archives the complete spec/, reports/ and runtime-artifacts/, and its commit
       resides in the open PR. It generates NO reverse-engineering delta and stitches nothing.
   3⃣  Merge the [BUG]/[ENH] PR into `<base-branch>`: <pr-url> — this completes the cycle. The next
       cycle pulls fresh current-system truth from Atlas via the Helix MCP.

🔴 archive-epic MUST run BEFORE the PR merges (2⃣ before 3⃣), so its cycle-close archive commit rides
   the open PR.
🔴 Use the skill names EXACTLY as shown — do not describe what you want in your own words.
   Any other phrasing is not a framework trigger and the workflow will not advance.
```

**Option C (test-plan edit)** — confirm the artifact change:
```markdown
# Test plan updated

**Story**: [Story N.M / TICKET-ID]
**File changed**: spec/test-plans/<TICKET-ID>-<title>/<file>
**Added/changed**: TC-[PLAN]-[nn], traced to AC-[n]
**State**: edited on your working tree only — this skill does not commit, push, or open a PR

➡ NEXT ACTIONS:
   1⃣  Commit and push the edited test plan yourself so the change reaches the branch
       (fold it into this story's existing `ve/<TICKET-ID>-<title>` PR if that PR is still open).
   2⃣  Execute the manual test steps in `spec/test-plans/<TICKET-ID>-<title>/`
       against a system built from `<integration-branch>` after the dev's PR has merged.
   3⃣  Then use this skill again and pick **B** to sign the story off, or **C** to adjust more.
   • Use the skill raise-defect for anything your testing finds.

🔴 Nothing about story or tracker status changed here — only Option B does that.
```

Say nothing after the applicable block above.

---

## Step 11: Log the Run in runtime-artifacts/audit.md

Append (never rewrite) one entry to `runtime-artifacts/audit.md`:

```markdown
## ve Sign-off (ve-list-work)
**Timestamp**: [ISO 8601 — real clock]
**User Email**: [current session email — read live from the session context]
**User Input**: "[complete raw user input]"
**Mode**: "[A — list only | B — sign-off | C — test-plan edit]"
**Cycle / Branch**: "[epic | bug | enhancement] — integration branch <integration-branch> (<epic branch | base branch>), pulled to latest"
**TRACKER ITEM**: "[each story involved — [PROJ-XXX](<site>/browse/PROJ-XXX) or local Story ID]"
**Merged stories reported**: "[Story N.M (PROJ-XXX), … or none]"
**Still in development**: "[Story N.M (PROJ-XXX), … or none]"
**ve APPROVED (→ 🧪 Ready for Testing)**: "[Story N.M ([PROJ-XXX](<site>/browse/PROJ-XXX)) — comment 've approved the story' added, label `ve-approved` applied, transition verified; … or none / n/a for this mode]"
**ve REJECTED (stayed 🔵 In Development)**: "[Story N.M ([PROJ-XXX](<site>/browse/PROJ-XXX)) — comment 've rejected the story' added, label `ve-rejected` applied, no transition; finding: [ve's reason]; told to log via /raise-defect; … or none / n/a for this mode]"
**Tracker labels/tags applied**: "[ve-approved → PROJ-101, PROJ-102 | ve-rejected → PROJ-103 | none / n/a for LOCAL]"
**Test-plan edit**: "[Story N.M (PROJ-XXX) — <file> — TC-[PLAN]-[nn] added/changed, traced to AC-[n] | n/a for this mode]"
**Anomalies (closed-not-merged / PR not found)**: "[… or none]"
**Epic transition**: "[EPIC-KEY → Ready for Testing (verified) / skipped by user / n/a — epic not complete / n/a — bug or enhancement cycle / n/a for this mode]"
**Approve / Request Changes gate**: "[Approved / Request Changes → re-did [step] / n/a — Option A]"
**AI Response**: "[what was changed, with verification results]"
**Context**: ve-list-work skill (ve sign-off)

---
```

Write tracker-linked stories as clickable Markdown links (`[PROJ-XXX](<site-base-url>/browse/PROJ-XXX)` for JIRA, the direct URL for ADO/GITHUB),
never bare text. Use the local Story ID for LOCAL stories.

**🔴 This audit entry, the Story Tracker update (Option B), and the test-plan file (Option C) are
the ONLY files this skill writes.** Option A writes nothing at all.

---

## Critical Rules

- 🔴 **This skill performs exactly ONE tracker transition** — `In Development` → `Ready for Testing`.
  Never offer or perform any other transition (no "Ready for Testing → In Testing", no
  "In Testing → Ready to Deploy", no "In Testing → Ready for Development").
- 🔴 **The A/B/C menu (Step 2) picks a LOCAL ACTION, not a transition.** Only Option B ever
  transitions a tracker ticket; A and C never do.
- 🔴 **Confirm-first, then verify** on every tracker change (non-LOCAL): show what will change, wait for explicit
  approval, apply it, then re-fetch to confirm it landed. Never claim an unverified
  success.
- 🔴 **Serves ALL cycle types — always the cycle's own branch, NEVER the base branch.** Resolve the
  integration branch from `Workflow Type` FIRST (Step 1): **epic cycle → the Epic Branch; bug cycle →
  the Bug Branch; enhancement cycle → the Enhancement Branch.** Never assume the epic branch, never
  run against the base branch (a cycle completes when its PR merges), and never run against an
  individual *story* branch.
- 🔴 **Status is read LIVE from the tracker (Step 3) for JIRA/ADO/GITHUB, never trusted from `runtime-artifacts/aire-state.md`
  alone.** The local Story Tracker `Status` column can go stale; the tracker's own fetch is the source of
  truth for any row with a non-LOCAL Tracker ID. Reconcile drift as a factual correction, not an ve decision. LOCAL rows have no external source — the local `Status` column is authoritative.
- 🔴 **The ve decides.** Anything moves to `🧪 Ready for Testing` ONLY when the ve approves it
  in Step 4. A merged PR alone is NOT sufficient — merging makes it *testable*, ve approval makes
  it *Ready for Testing*. This holds identically for epic stories and bug/enhancement tickets.
- 🔴 **ALWAYS collect a per-item decision in Step 4** (`approve` or `reject`, Option B only) — the
  ve must get the chance to flag a bug on any item. Never infer a decision from silence, and
  never skip an item present in the 🟩 MERGED table without an explicit decision.
- 🔴 **Every approval gets BOTH a comment starting `ve approved the story` AND the
  `ve-approved` label/tag** (Step 5, JIRA/ADO/GITHUB only). Every rejection gets BOTH a comment starting `ve rejected the
  story` AND the `ve-rejected` label/tag (Step 6). Comment and label/tag are mandatory and always
  paired — never one without the other. LOCAL has no external comment/label — the Story Tracker update alone is the record.
- 🔴 **Labels/tags are APPENDED, never replaced.** Re-fetch the issue's labels/tags, add the new one, write
  the full set back — `ai-generated`, `aire-v[N]` and every other existing label MUST survive.
  Clear the opposite ve label in the same update so an item is never both approved and rejected.
- 🔴 **A REJECTED item NEVER changes status.** No transition, no Story Tracker `Status`
  or `End` change — it stays `🔵 In Development` for the dev team. The label and comment are the
  entire tracker-side effect (non-LOCAL). Tell the ve to manually log the defect with the `/raise-defect` skill.
- 🔴 **The same story can never be both approved and rejected in one run.** If the ve gives it
  both decisions in Step 4, stop and ask which they meant.
- 🔴 **runtime-artifacts/audit.md records the mode (A/B/C) plus BOTH lists** — approvals and rejections, each with
  the tracker link (or local ID), the comment that was posted, the label applied, and (for rejections) the ve's
  stated finding.
- 🔴 **NEVER guess merge state** — read it from `gh pr view`. If `gh` is unavailable, stop and report.
- 🔴 **Always pull the integration branch first** (Step 1) — the epic / bug / enhancement branch — so the
  merged list is current.
- 🔴 **Read merge state from the same tracker columns the dev workflows write** (`PR`, `Merged`) —
  `dev-implement` (story PR → epic branch), `bug-fix-implement` and `enhancement-implement`
  (`[BUG]`/`[ENH]` PR → base branch). 🔴 On bug/enhancement cycles that PR is deliberately still OPEN
  when this skill runs — never require `Merged = yes` there; require the ve's `ve/…` test-plan PR
  to have merged into the cycle branch instead.
- 🔴 **Runs NO build and NO tests.** The ve tests the merged work manually, using the steps `/ve-implement`
  generated in `spec/test-plans/<TICKET-ID>-<title>/`.
- 🔴 **Option C only edits `/ve-implement` test-plan artifacts** (Step 8) — new/changed test cases MUST
  follow the `TC-[PLAN]-[nn]` format and AC traceability rules in
  `aire-workflow/implementation/test-plan.md`. It never changes story or tracker status.
- 🔴 **Parent Epic transition is EPIC-CYCLE ONLY** (confirm-first, and only when every story is
  `🧪 Ready for Testing`); skip it silently on bug/enhancement cycles, on LOCAL, and when `## Tracker` records
  `Parent Epic: none`. Never raise/merge/close PRs, and never touch feature branches.
- 🔴 **Never update only one side** — the local Story Tracker and the external tracker (when one is configured) must both reflect the sign-off.
- 🔴 **Options B and C close through the Step 9 Approve / Request Changes gate** before the Step 10
  completion message. **Option A does NOT** — it is read-only, so it goes Step 3 → Step 10 and never
  asks for an approval.
- 🔴 **Option A prints ONE table and nothing else** — the merged, still-In-Development sign-off
  candidates, with live tracker status. No second table (no "still in development", "not started",
  "already actioned", "needs attention"), no approve/reject wording, no summary block, no
  commentary. If nothing is merged, say so in one line and stop.
- 🔴 **Close with the handoff that matches the cycle**: epic → `pr-generator` for the Epic PR;
  bug/enhancement → **`archive-epic` here on the cycle branch** (while the `[BUG]`/`[ENH]` PR is still
  open) → merge that PR, which completes the cycle. Never offer `pr-generator` on a
  bug/enhancement cycle, and never send the ve to the base branch.
- 🔴 **Append to `runtime-artifacts/audit.md` — never rewrite it.** Timestamps come from a real clock in ISO 8601.
