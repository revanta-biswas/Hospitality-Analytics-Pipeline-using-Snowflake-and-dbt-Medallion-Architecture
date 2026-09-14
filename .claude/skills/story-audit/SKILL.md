---
name: story-audit
description: >
  Audits an existing Story or Epic — in whichever tracker is configured (Jira, Azure DevOps,
  GitHub) or directly from stories.md for Local — against the AIRE quality bar. Fetches the
  issue, assesses what's present vs missing, scores it, and offers to fill gaps through targeted
  questions — then updates the issue in the tracker with the improvements (or the local story
  file, for Local). Works for any issue type
  (Story, Epic, Task) but applies the appropriate checklist for each.
  Trigger on "audit this story", "check this story", "is this story ready",
  "audit this epic", "story audit", "review PROJ-123", "is PROJ-123 complete",
  "validate this ticket", "check this ticket", or any request to verify a tracked issue
  has enough detail to be actionable.
compatibility: For JIRA/ADO/GITHUB, the corresponding integration (Atlassian MCP / az CLI / gh CLI) must be available. LOCAL requires nothing external.
---

# Story & Epic Audit

Fetch an issue from the configured tracker (or the local story file, for Local), measure it against the right quality bar, report what's strong and what's
missing, and — if the user wants — fill the gaps through targeted questions and update the issue
(or local file).

## Philosophy

**Assess first, fix second.** The audit is a read-only diagnosis. Fixing is opt-in. The user
may just want the report, or they may want to walk through the gaps and patch the issue right
now. Support both.

**Type-aware.** Epics and Stories have different quality bars. Detect the issue type from the
tracker (or the story's context, for Local) and apply the matching checklist. If the type is something else (Task, Bug, Initiative), use
the closest checklist and note the adaptation.

---

## Step 1 — Ask for the issue

Read `## Tracker` → `Type` from `runtime-artifacts/aire-state.md` if it exists (reuse silently); otherwise ask the Tracker Selection question (`common/tracker-sync.md` Section 1) once for this run.

If the user already provided a reference (e.g. "audit PROJ-42"), use it. Otherwise ask, per the resolved tracker:
```
Which issue should I audit?
[JIRA]   Provide the issue key (e.g. PROJ-42) or full URL.
[ADO]    Provide the work item ID or URL.
[GITHUB] Provide the issue number or URL.
[LOCAL]  Provide the Story ID (e.g. 1.2) from stories.md.
```

## Step 2 — Fetch and classify

Fetch the issue per the configured tracker — `getJiraIssue` (JIRA), `az boards work-item show` (ADO),
`gh issue view` (GITHUB), per `common/tracker-sync.md` Section 2/Section 8 — or, for **LOCAL**, read the story
directly from `spec/plans/stories.md` / the Story Tracker. Identify:
- **Issue type** (Epic, Story, Task, Bug, etc.)
- **Summary**
- **Description** (full content)
- **Labels/tags**
- **Status**
- **Links** (parent Epic, child issues, related issues)

Select the matching checklist from `references/quality-checklists.md`:
- Epic → **Epic Checklist**
- Story / Task → **Story Checklist**
- Other → **Story Checklist** (adapted, note this to the user)

## Step 3 — Run the audit

Evaluate every item on the checklist. For each item, assign one of:

- **PASS** — present and sufficient
- **WEAK** — present but thin, vague, or incomplete
- **MISSING** — not present at all
- **N/A** — not applicable for this issue

Present the results as a scorecard:

```
Audit: [KEY] — "[summary]" ([issue type])

SCORECARD
=========
[x] Item name                          PASS
[~] Item name                          WEAK — [brief reason]
[ ] Item name                          MISSING
[-] Item name                          N/A

Score: X / Y passing (Z%)

VERDICT: [Ready / Needs Work / Incomplete]
```

**Verdict thresholds:**
- **Ready** — all required items PASS, no MISSING on required fields
- **Needs Work** — no MISSING on required fields, but 1+ WEAK items
- **Incomplete** — 1+ required fields are MISSING

## Step 4 — Offer to fix

If verdict is **Ready**, congratulate and stop.

If verdict is **Needs Work** or **Incomplete**, offer:

```
This issue has gaps. Want me to:

A) Walk through the gaps and help fill them — I'll ask targeted questions, then update the issue (in the tracker, or the local story file for Local)
B) Just take the report — I'll leave the issue as-is

[Answer]:
```

**If A**: For each WEAK or MISSING item, ask focused questions (multiple-choice where possible,
with an open "Other"). Work through them in priority order (required fields first, then
recommended). After gathering answers, draft the updated description and show it to the user
for approval before writing to the tracker (or the local story file).

**If B**: Done. The scorecard is the deliverable.

## Step 5 — Update the issue (only if user chose A)

1. Draft the improved description incorporating all gathered answers.
2. **Show the full updated description** to the user for review.
3. **Confirm before writing**: "Update [KEY] with these improvements? (yes / no)"
4. On yes, update per the configured tracker: `editJiraIssue` (JIRA), `az boards work-item update`
   (ADO), `gh issue edit` (GITHUB), or edit the story's entry in `stories.md` directly (LOCAL). Verify success (non-LOCAL).
5. Report: "Updated [KEY]."

---

## HARD GUARDRAILS — do not violate

- **No file or directory creation**, except the LOCAL update path (Step 5), which edits the existing `stories.md` — never a new file. Reading `## Tracker` from `runtime-artifacts/aire-state.md`, if it exists, is a read and does not violate this.
- **No local artifacts beyond the LOCAL update path.** The audit lives in chat; non-LOCAL fixes go to the tracker only.
- **Tracker in, tracker out (or stories.md in/out, for Local).** Read via the tracker's fetch, update via the tracker's write (or `stories.md` directly, for Local). Nothing else.
- **Confirm before every write.** Never update without explicit user approval ("yes").
- **Never fabricate content.** If something is unknown, ask — don't guess. Mark genuine unknowns as open questions.
- **Preserve existing content.** When updating, merge improvements into the existing description — never discard content that was already there.

---

## Bundled resources

- `references/quality-checklists.md` — the Epic and Story checklists used for scoring.
