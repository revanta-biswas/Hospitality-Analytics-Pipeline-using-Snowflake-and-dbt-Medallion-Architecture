---
name: raise-defect
description: >
  Helps an ve raise a defect/bug in whichever tracker is configured (Jira, Azure DevOps, GitHub,
  or Local) with a minimal, fixed question set: Title, Description, Severity (Low / Medium / High /
  Critical), Environment Found, and Discovery Activity. Components is always
  "Default" and Associated Org is always "All" for JIRA (never asked). Creates the bug via
  the tracker-appropriate mechanism, tagged with "bug", "defect", "ai-generated", "aire" and "aire-v[N]" labels/tags
  (the framework version read live from CLAUDE.md), or records it in the local Story Tracker for Local. Confirm-first: nothing is
  written to the tracker until the ve reviews and approves the drafted ticket.
when_to_use: >
  Trigger when the user (ve) says: "raise a defect", "raise a bug", "log a defect",
  "file a bug", "report a defect", "create a bug ticket", "found a bug", "new defect",
  "ve bug", "log this issue in Jira" (or ADO/GitHub/locally).
allowed-tools: Read Grep Glob Bash Write
---

# Raise Defect — ve Bug Reporting to the Configured Tracker

You help the tester raise a defect by collecting ONLY the fields below, drafting the
ticket, getting **explicit approval**, and then creating it via the mechanism for whichever tracker
is configured (`## Tracker` → `Type` in `runtime-artifacts/aire-state.md`). **Do NOT ask for anything beyond these fields** — no preconditions, steps to reproduce,
expected/actual, priority, reproducibility, or affected story questions.

---

## Phase 0: Preconditions

1. Read `## Tracker` → `Type` from `runtime-artifacts/aire-state.md`. If it doesn't exist yet, ask the Tracker Selection question (`common/tracker-sync.md` Section 1) first.
2. Confirm the tracker's integration is available: **JIRA** — Atlassian MCP connected; **ADO** — `az account show` succeeds; **GITHUB** — `gh auth status` succeeds; **LOCAL** — nothing to check. If a required integration isn't connected, stop and tell the tester to connect it first — do not attempt workarounds.
3. Determine the target **project/repo** (skip for LOCAL):
   - If the tester gave one, use it.
   - Else check `runtime-artifacts/aire-state.md` (`## Tracker` → `Project Key / Repo / Org`) / `runtime-artifacts/audit.md`
     for the identifier already used on this project and propose it.
   - Else ask: `Which [Jira project / ADO project / GitHub repo] should this defect go into?`

---

## Phase 1: Collect the Defect Fields (ONLY these — ask nothing else)

Present as a short numbered list so the tester can answer inline; fill in anything they already
told you and only ask for what's missing. Do not invent details.

1. **Title** — a concise, descriptive summary of the defect.
2. **Description** — what the defect is, in the tester's words (free text; use it as-is).
3. **Severity** — one of:
   ```
   A) Low
   B) Medium
   C) High
   D) Critical
   ```
   For **JIRA**, this maps to the **Severity** context field on the Bug issue type:
   - Low → `Sev 4 - Low`
   - Medium → `Sev 3 - Med`
   - High → `Sev 2 - High`
   - Critical → `Sev 1 - Critical`
   For **ADO/GITHUB/LOCAL**, it is recorded as a `severity:low|medium|high|critical` tag/label AND as a heading in the description (see Phase 2) — there is no equivalent custom field to look up.
4. **Environment Found** — where the defect was found. For **JIRA**, if the project's `Environment Found`
   field has a fixed option list (check via `getJiraIssueTypeMetaWithFields`), present those
   options; otherwise accept free text, and prompt with a bracketed suggestion so the tester
   knows the typical shape of an answer, e.g. `**Environment Found** (e.g. Production, QA, Staging, Dev):`. For ADO/GITHUB/LOCAL, always free text.
5. **Discovery Activity** — the activity during which the defect was discovered. For **JIRA**, if the
   project's `Discovery Activity` field has a fixed option list (check via
   `getJiraIssueTypeMetaWithFields`), present those options; otherwise accept free text. For ADO/GITHUB/LOCAL, always free text.

**Fixed values — NEVER ask the tester for these** (JIRA only; ADO/GITHUB/LOCAL have no equivalent fields, so these are simply omitted for them):
- **Components** = `Default`
- **Associated Org** = `All`

---

## Phase 2: Draft the Defect

Every tracker gets the same **description body**, built from the Phase 1 answers:
```markdown
### Description
[the tester's Description from Phase 1, as-is]

### Environment Found
[the Environment Found answer]

### Discovery Activity
[the Discovery Activity answer]

### Severity
[Low/Medium/High/Critical]

---
Raised via the AIRE raise-defect skill by ve. Drafted with AI ([MODEL NAME]).
 AIRE Framework: v[N]
```
- `[MODEL NAME]` — the actual session model (e.g., "Claude Sonnet 5") — never left as a placeholder.
- `[N]` — the framework version, read live at runtime from the "AIRE Framework Version" line
  in the project's `CLAUDE.md` (e.g. `aire-v1.0`). Never hardcode and never leave as a placeholder.

Then dispatch the actual creation per `## Tracker` → `Type`:

**JIRA**:
- **issueType**: `Bug` (fall back to the project's nearest defect type if `Bug` doesn't exist —
  check with `getJiraProjectIssueTypesMetadata` and confirm the chosen type with the tester).
- **summary**: the Title from Phase 1. **description**: the body above, in **real Markdown** — the Atlassian MCP
  converts Markdown to Jira's ADF automatically. Never use Jira wiki markup (`h3.`, `*`, `#`) — it lands as literal raw text.
- **labels**: `bug`, `defect`, `ai-generated`, `aire`, `aire-v[N]`.
- **Severity** (Jira context/custom field on the Bug type — find its field ID via
  `getJiraIssueTypeMetaWithFields`): set to the mapped option (`Sev 4 - Low` / `Sev 3 - Med` /
  `Sev 2 - High` / `Sev 1 - Critical`).
- **Environment Found** / **Discovery Activity**: always in the description body (above). If the project ALSO exposes them as custom fields (check
  `getJiraIssueTypeMetaWithFields`), set those fields too with the same answers.
- **Components**: `Default` (if the project's `Component/s` field has no `Default` option,
  check with `getJiraProjectIssueTypesMetadata` and confirm the closest equivalent with the tester).
- **Associated Org**: `All` (if the project doesn't expose an `Associated Org` field, confirm
  with the tester whether to skip it or use the nearest equivalent).

**ADO**:
- `az boards work-item create --type "Bug" --title "<Title>" --description "<body above as HTML>" --project "{PROJECT}" --fields "System.Tags=ai-generated;aire;aire-v[N];bug;defect;severity-<low|medium|high|critical>"`.

**GITHUB**:
- `gh issue create --repo ORG/REPO --title "<Title>" --body "<body above>" --label "bug" --label "defect" --label "ai-generated" --label "aire-v[N]" --label "severity:<low|medium|high|critical>"` (create any missing label first, matching by exact name per `common/tracker-sync.md` Section 9).

**LOCAL**:
- No external issue. Mint a local ID `BUG-LOCAL-N` (next unused N found by scanning `runtime-artifacts/aire-state.md`) and record the full description body as a new row/entry in the local Story Tracker (or a local defects doc if the project keeps one) — the local file IS the ticket.

**Show the full drafted ticket to the tester** (project/repo, type, title, description body, labels/tags —
`bug`, `defect`, `ai-generated`, `aire`, `aire-v[N]`, plus, for JIRA, components `Default` and associated org `All`). Do not create anything yet.

---

## Phase 3: Confirm Before Creating (REQUIRED — do not skip)

Ask explicitly: **"Create this defect in [Jira project / ADO project / GitHub repo] <KEY> with the details above — yes/no?"** (for LOCAL: **"Record this defect locally as <BUG-LOCAL-N> — yes/no?"**)
Do not proceed without an explicit yes. If the tester wants edits, revise and re-confirm.

---

## Phase 4: Create the Defect (only after confirmation)

1. Create the issue per the dispatch in Phase 2 (JIRA: `createJiraIssue` with custom fields via their
   field IDs from `getJiraIssueTypeMetaWithFields`; ADO: `az boards work-item create`; GITHUB: `gh issue
   create`; LOCAL: write the local Story Tracker/defects-doc row). **Verify** it was created (non-LOCAL)
   and capture the new **issue key/number/ID** (e.g. `PROJ-321`, an ADO work item ID, or a GitHub issue number) — or the minted `BUG-LOCAL-N` for LOCAL.
2. Build the full issue URL where applicable: `<site-base-url>/browse/<ISSUE-KEY>` for JIRA (site base
   URL from `getAccessibleAtlassianResources`, or reuse the base already recorded in `spec/`), the
   work-item/issue URL directly for ADO/GITHUB. LOCAL has no URL — use the local ID.
3. **Log in `runtime-artifacts/audit.md`** (append-only at the end — never rewrite the file):
   ```markdown
   ## Defect Raised (ve)
   **Timestamp**: [ISO timestamp]
   **User Email**: [current session email — read live from the session context]
   **Defect**: [<ISSUE-KEY>](<site-base-url>/browse/<ISSUE-KEY>) — [title]  (or the local BUG-LOCAL-N ID)
   **Severity**: [Low/Medium/High/Critical]
   **Environment Found / Discovery Activity**: [..] / [..]
   **Raised by**: [ve user]

   ---
   ```
4. Report back to the tester the created **defect ID as a clickable link** where applicable
   (`[<ISSUE-KEY>](<site-base-url>/browse/<ISSUE-KEY>)` for JIRA, the direct URL for ADO/GITHUB), or the local ID for LOCAL.

---

## Execution Rules

1. **Never create a tracker issue without the Phase 3 confirmation** — non-negotiable gate (LOCAL: never record it without confirmation either).
2. **Only ask the five Phase 1 fields** (Title, Description, Severity, Environment Found,
   Discovery Activity) — never interview for anything else.
3. **Always tag `bug`, `defect`, `ai-generated`, `aire`, and `aire-v[N]` labels/tags** (JIRA/ADO/GITHUB) and set issueType to
   the project's bug/defect type. `[N]` is the framework version read live at runtime from the
   "AIRE Framework Version" line in the project's `CLAUDE.md` — never hardcode, never a
   placeholder. A pre-existing similar label (`AI Generated`, `ai_generated`, `bot`, etc.) is NOT
   a substitute for the exact `ai-generated` label. LOCAL records the version in the local entry's header instead.
4. **For JIRA, always set Components = `Default` and Associated Org = `All`** — mandatory fixed values;
   never leave them blank and never ask the tester to choose them. ADO/GITHUB/LOCAL have no equivalent fields.
5. **Severity is a Jira context (custom) field for JIRA**, not the built-in priority — set it via its
   field ID with the mapped `Sev N - ...` option value. For ADO/GITHUB it is a `severity:*` tag/label plus the description heading; for LOCAL it is just the description heading.
6. **Always verify** creation (non-LOCAL) and capture the real issue key/ID; never report a guessed key.
7. **Always log the raised defect in `runtime-artifacts/audit.md`** with the full tracker hyperlink (or local ID).
8. **Resolve `[MODEL NAME]`** to the actual session model — never leave the placeholder.
9. **Resolve `[N]`** to the framework version read live from the "AIRE Framework Version"
   line in `CLAUDE.md` — never hardcode and never leave the placeholder unresolved.