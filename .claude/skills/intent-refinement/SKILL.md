---
name: intent-refinement
description: >
  Use this skill to take an existing Epic (in whichever tracker is configured — Jira, Azure DevOps,
  GitHub — or a pasted baseline intent for Local) and refine it to full detail through structured
  elaboration. Trigger it on "refine this intent", "elaborate this Epic", "flesh out the Epic",
  "deepen this intent", "add detail to the Epic", or whenever a thin Epic needs to be brought up
  to a fully-detailed standard before building begins. The skill asks for the Epic reference, fetches
  its current content, runs focused elaboration questions, and updates the Epic in the tracker with all
  the refined detail (or presents it for the user to save, when Local).
compatibility: For JIRA/ADO/GITHUB, the corresponding integration (Atlassian MCP / az CLI / gh CLI) must be available. LOCAL requires nothing external.
---

# Intent Refinement

The deep elaboration work: take a real Epic, pull what's there, and through structured
questioning drive it to full detail — measurable success criteria, binding constraints, domain
context, NFRs, risks — then write all of that back to the Epic in the configured tracker.

## What this skill does

0. **Resolve** which tracker is configured (read `## Tracker` from `runtime-artifacts/aire-state.md` if it exists; otherwise ask once for this run).
1. **Ask** the user for the Epic reference (key/ID/URL for JIRA/ADO/GITHUB; for LOCAL, ask them to paste the current intent content instead — there is nothing external to fetch).
2. **Fetch** the Epic's current content from the configured tracker.
3. **Assess** what's already there and what's missing against the full intent template.
4. **Elaborate** through focused question batches (see `references/elaboration-questions.md`).
5. **Update** the Epic in the tracker with all the refined detail AND the `intake-refined` label/tag (or, for LOCAL, present the finished document), confirm-first before writing.

## The single test for "ready"

**Verifiability** — can you prove, at the end of building, that the intent was met? That requires
measurable success criteria with thresholds and verification methods. Everything else supports this.

Fill honestly: a 70%-complete intent with declared unknowns beats a 100%-complete one built on
guesses.

## The flow

### Step 1 — Ask for the Epic

If `## Tracker` isn't already recorded in `runtime-artifacts/aire-state.md`, ask once which tracker to use (JIRA / ADO / GITHUB / Local) before continuing. Then ask the user, per that tracker:
```
Which Epic should we refine?
[JIRA]   Please provide the Epic key (e.g. PROJ-42) or the full Jira URL.
[ADO]    Please provide the Epic work item ID or URL.
[GITHUB] Please provide the Milestone number/URL or tracking issue reference.
[LOCAL]  Paste the current intent content (baseline) directly — there's no external Epic to fetch.
```

### Step 2 — Fetch and read the Epic

Fetch the Epic per the configured tracker: `getJiraIssue` (JIRA), `az boards work-item show` (ADO), `gh api`/`gh issue view` (GITHUB) — per `common/tracker-sync.md` Section 2. For LOCAL, use the content the user pasted in Step 1 directly — there is no fetch. Read the summary, description, and any
existing acceptance criteria or attachments. Note what's already captured and what gaps exist
relative to the full intent template (`assets/intent-template.md`).

Display a brief assessment to the user:
```
 Fetched Epic [KEY]: "[title]"

What's already captured:
- [list what's present]

What's missing or thin:
- [list gaps]

Ready to elaborate? I'll work through focused question batches to fill the gaps.
```

Wait for the user to confirm before proceeding.

### Step 3 — Elaborate through question batches

Read `references/elaboration-questions.md`. Work through the priority sections in order, skipping
questions that are already answered by the Epic content. Ask in focused batches — one section at a
time — using multiple-choice where possible with an open "Other" option. Record genuine unknowns
as Open Questions; do not guess.

After each batch, pause and wait for the user's answers before continuing to the next section.

Stop elaborating once the intent is verifiable: measurable criteria, clear scope, known constraints,
modelled domain, identified risks. Do not ask questions beyond what's needed.

### Step 4 — Draft the refined intent

Synthesise everything gathered into a fully-filled intent document based on `assets/intent-template.md`.
Present it to the user for review:
```
 Refined intent ready for review.

[Full intent content here]

Does this look right? Type "yes" to update the Epic (or, for Local, to finalize this document), or provide corrections.
```

**Do not update the tracker until the user explicitly approves.**

### Step 5 — Update the Epic in the Configured Tracker

On approval, update the Epic in this exact sequence — **every step is mandatory, not optional,
regardless of how confident you are that the label is already applied** (JIRA/ADO/GITHUB only; LOCAL skips straight to presenting the finished document):

1. **Re-fetch the Epic's current labels/tags** immediately before writing, so the
   update is based on live state, not the Step 2 snapshot.
2. **Compute the new labels/tags**: take the current set as-is and **append** `intake-refined` if
   it is not already present, exact string, case-sensitive. **Append-only — never remove or replace
   any existing label/tag** (e.g. `intent-intake` from the intake stage stays untouched). A pre-existing
   *similar-looking* label (`intake_refined`, `Intake-Refined`, `refined`, `intent-refined`, etc.) does
   **NOT** satisfy this requirement — it is not a substitute; still add the exact `intake-refined` label.
3. **Update the Epic** with BOTH the full refined intent content (description) AND the computed
   labels/tags in the same write, per `common/tracker-sync.md` Section 2/Section 9: JIRA via the Atlassian MCP
   (`editJiraIssue`), ADO via `az boards work-item update` (description + `System.Tags`), GITHUB via
   `gh api`/`gh issue edit` (Milestone description + labels). Do not skip the labels/tags field even
   if it looks unchanged from Step 1 — omitting a field some integrations treat as "clear it," which
   would silently drop existing labels.
4. **Verify, don't assume**: re-fetch the Epic after the write and confirm `intake-refined` is present
   in its labels/tags. If it is missing, retry the label update once. If it still fails, stop and
   tell the user explicitly — do NOT report success and do NOT proceed to the next-step prompt below
   with the label unconfirmed.

```
 Epic [KEY] updated in [Jira/ADO/GitHub] with the refined intent.
  Label confirmed: intake-refined

 **Next Step — Activate the AIRE Framework**
To start building this Epic, type:
  using aire implement [tracker-appropriate reference, e.g. jira [KEY]]
(replace [KEY] with the Epic's tracker ID)
```

**For LOCAL**, skip Steps 1–4 above entirely and instead present the finished document in chat:
```
 Refined intent finalized. Save this yourself — this skill creates no local files.

[Full intent content here]

 **Next Step — Activate the AIRE Framework**
To start building this, type: using aire [describe the epic, or paste this document]
```

**This next-step prompt is mandatory** — always display it after a successful Epic update, and only
after the label has been verified per Step 4 above.

## HARD GUARDRAILS — do not violate

- **No file or directory creation.** Do not create, write, or modify any file or folder in the workspace (reading `## Tracker` from `runtime-artifacts/aire-state.md`, if it exists, is fine — that's a read, not a write). The refined intent lives in the configured tracker only (or in chat, for Local — never a local file).
- **No local artifacts.** Do not produce `intent.md`, `intent-template.md`, or any other local document as output. `assets/intent-template.md` is a reference shape only — never instantiate it.
- **Tracker in, tracker out (or chat in, chat out, for Local).** The only I/O is: read the Epic from the configured tracker (or take the user's pasted content, for Local), ask the user questions in chat, then update the Epic in the tracker (or present it, for Local). Nothing else.
- **Confirm before every tracker write.** Never update the tracker without explicit user approval ("yes"). LOCAL has no write to confirm.
- **🔴 EVERY Epic this skill updates in JIRA/ADO/GITHUB MUST carry the exact label/tag `intake-refined` — no exceptions, not optional, not "if relevant."** This is not a judgment call to make per-Epic; it applies unconditionally to every successful non-LOCAL run of Step 5. The label is applied **in the same write** as the description update (never a separate follow-up call you might skip), it is **appended** to whatever labels the Epic already carries (never replacing them), and its presence is **verified by re-fetching the Epic** after the write — before the "Next Step" prompt is shown. A run that updates the description but cannot confirm the label is NOT a successful run; stop and surface the failure to the user rather than reporting success. See Step 5 for the exact sequence.

## Quality bar

- **Success criteria must be testable** — push past "improve X" to a measured threshold + verification method.
- **Scope must include an explicit out-of-scope section** — an empty out-of-scope invites creep.
- **Constraints must be stated or honestly marked unknown** — unknown ≠ absent.
- **Domain context must be modelled** — bounded contexts, key entities, core invariants.
- **Risks must be named** — likelihood, impact, mitigation.
- **Never guess** — if something is unknown, capture it as an Open Question.

## Bundled resources

- `assets/intent-template.md` — the full intent structure; use this as the target shape.
- `references/elaboration-questions.md` — the elaboration question bank.
