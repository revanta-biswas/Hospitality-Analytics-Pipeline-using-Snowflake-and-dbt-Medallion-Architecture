---
name: intent-intake
description: >
  Use this skill when someone wants to turn a raw idea, feature request, or piece of product context
  into an Intent that can enter the team's issue tracker — the light front-door gate. Trigger it on "I have an idea",
  "capture this as an intent", "start an intent", "get this into Jira" (or ADO/GitHub), "turn this research/PRD/deck
  into an intent", or any moment a fuzzy idea needs to become real. It asks upfront whether the user
  has a document to reference or wants to explain in plain English. It gathers a consistent baseline
  — just enough thought to justify an Epic — produces a baseline intent artifact, and pushes
  the Epic directly to whichever tracker is configured (JIRA/ADO/GITHUB), or presents it for the user to save themselves when Local. It does NOT do deep elaboration or refinement; that happens later, with engineers, in intent-refinement.
compatibility: For JIRA/ADO/GITHUB, the corresponding integration (Atlassian MCP / az CLI / gh CLI) must be available — pushes the Epic directly to the tracker at the end of intake. LOCAL requires nothing external.
---

# Intent Intake

The membrane between fuzzy thinking and a tracked Epic. Everything upstream — research, prototyping, KPI
exploration — lives wherever the team likes (Confluence, git, a napkin). Nothing is "real" until it
clears this gate and becomes an Epic. This skill keeps the gate **fast and consistent**: a baseline
of thought, no more.

## Keep it light on purpose

The overwhelm people feel comes from refinement-depth thinking leaking into the intake moment.
Don't let it. Intake gathers six things and stops. Testable criteria, the domain model, NFRs, risk
registers — **none of that belongs here**; it happens later, with engineers, in intent-refinement. If you
find yourself asking for measurable thresholds or bounded contexts, you've gone too deep — pull back.

## Step -1 — Resolve the tracker (read-only, no writes)

Check whether `runtime-artifacts/aire-state.md` exists and, if so, read `## Tracker` → `Type` from it — reuse that value silently, no question asked. If no such file/section exists (this skill runs standalone, before any aire project), ask once for THIS run only (nothing is persisted, per the guardrails below):

```
Which tracker should the Epic be created in?
A) Jira   B) Azure DevOps   C) GitHub   D) Local only (just show me the finished intent — no push)
[Answer]:
```

## Step 0 — Ask how the person wants to start

**Before doing anything else**, ask the person this question:

```
How would you like to share your idea?

A) I have a document (PRD, research notes, prototype write-up, Confluence page, deck, etc.)
   → paste or share the link/content and I'll read it first
B) I'll explain it in plain English
   → just tell me the idea in your own words

[Answer]: 
```

- **If A**: Read the doc/link they provide, pre-fill every baseline field it already answers, then only ask about the gaps. Capture the `context_link` as the source URL or file reference.
- **If B**: Start from their words. Ask follow-up questions for any of the six baseline fields not covered. Set `context_link` to "plain English — no external doc".

## Step 1 — Capture the idea

Get the outcome in their words, business terms. One outcome per intent — if you hear two, flag and
split.

## Step 2 — Fill the baseline (the six)

Gather exactly these, no more. Ask in one or two short, tappable batches (multiple-choice + an open
"Other") — see `references/intake-questions.md`:

1. **Outcome** — one business sentence.
2. **KPI / business outcome** — the metric this moves.
3. **Rough success signal** — directional only ("faster entry", "fewer failed checkouts"). NOT testable yet.
4. **At least one explicit out-of-scope.**
5. **Known hard constraints** — or an honest "none known."
6. **Confidence + open unknowns**, and the **context link**.

A declared unknown is fine — better than a guess. Record unknowns; don't fill them with plausible fiction.

## Step 3 — Draft the baseline intent

Using `assets/intent-template.md` as a reference shape, draft the filled baseline intent **in chat only** — do not create any local file. Fill the BASELINE sections, leave the FULL sections blank (those are for intent-refinement). Show the draft to the person for review.

## Step 4 — Intake gate

Run the **Intake gate** checklist mentally. It only checks the six are present and non-garbage
— KPI named, out-of-scope not blank, unknowns declared, context linked. It does **not** check for
testable criteria; that bar is intentionally not here. Confirm with the person before proceeding.

## Hand off — Push Epic to the Configured Tracker

Once the intake gate passes, **push the Epic** using the mechanism for the tracker resolved in Step -1 (JIRA/ADO/GITHUB), or present it for Local. Follow this sequence:

1. **Confirm before pushing** (skip entirely for LOCAL — go straight to the LOCAL branch below) — show the user a brief summary of what will be created:
   ```
   Ready to create a [Jira/ADO/GitHub] Epic with the following details:
   - Title: [intent title]
   - Description: [full intent content from the filled template]
   - Labels/tags: intent-intake

   Push? (yes / no)
   ```
2. **On yes**, create the Epic per the configured type:
   - **JIRA**: `createJiraIssue` — `issueType`: Epic, `summary`: the intent title, `description`: the **complete filled intent artifact** (all BASELINE sections as-is, verbatim — do not summarise or shorten), `labels`: `["intent-intake"]`, `project`: confirm the PROJECT_KEY with the user if not already known.
   - **ADO**: `az boards work-item create --type "Epic" --title "<intent title>" --description "<complete filled intent artifact>" --project "{PROJECT}"`, then add `intent-intake` to `System.Tags`.
   - **GITHUB**: create a Milestone (`gh api repos/{ORG}/{REPO}/milestones --method POST -f title="<intent title>" -f description="<complete filled intent artifact>"`), or a tracking issue labeled `epic` + `intent-intake` if the repo doesn't use Milestones as Epics — ask the user which convention their repo uses if unclear.
   - **LOCAL**: no push. Present the complete filled intent artifact in chat as the final output and tell the user to save it themselves wherever they track local work — this skill creates no files.
3. **Verify, don't assume** (JIRA/ADO/GITHUB only): re-fetch the created item and confirm BOTH (a) it is real and resolvable, AND (b) the `intent-intake` label/tag is present, exact string. Some integrations silently drop a labels/tags field passed at create time — do not treat a successful creation response alone as proof it landed. If missing, retry once by updating the item's labels/tags (append `intent-intake` to whatever is there). If it still fails after the retry, stop and tell the user explicitly — do NOT report the intake as complete with the label unconfirmed.

After the Epic is live **and the label/tag is confirmed** (or, for LOCAL, after the artifact is presented), tell the person the next step is **intent-refinement**.

## HARD GUARDRAILS — do not violate

- **No file or directory creation.** Do not create, write, or modify any file or folder in the workspace. The intent lives in the configured tracker only (or in chat, for Local — never a local file).
- **No local artifacts.** Do not save or instantiate `intent-template.md` locally. It is a reference shape — draft the content in chat, then push it (or present it, for Local).
- **No runtime-artifacts/audit.md writes.** Do not write to `runtime-artifacts/audit.md` or any other log file.
- **Tracker push only, no other writes.** The only write action is creating the Epic in the configured tracker (plus, if needed, one retry label/tag update per Step 3 of the hand-off sequence). Reading `## Tracker` from `runtime-artifacts/aire-state.md` (Step -1) is read-only and does not violate this.
- **Confirm before every tracker write.** Never create an Epic without explicit user approval ("yes"). LOCAL has no write to confirm.
- **🔴 EVERY Epic this skill creates in JIRA/ADO/GITHUB MUST carry the exact label/tag `intent-intake` — no exceptions, not optional.** This applies unconditionally to every successful non-LOCAL run, not a per-Epic judgment call. A pre-existing *similar-looking* label elsewhere in the project (`intake`, `intent_intake`, `Intent-Intake`, etc.) is NOT a substitute — the exact string `intent-intake` must be present. Its presence is **verified by re-fetching the created item** (never assumed from the create call's response alone) before the intake is reported complete. A run that creates the Epic but cannot confirm the label is NOT a successful run; stop and surface the failure to the user. See Step 3 of the hand-off sequence for the exact procedure.

## Bundled resources

- `assets/intent-template.md` — reference shape only; never instantiate it as a local file.
- `references/intake-questions.md` — the light question batches for the six baseline fields.
