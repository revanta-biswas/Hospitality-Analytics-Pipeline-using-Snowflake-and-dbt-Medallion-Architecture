---
name: archive-epic
description: >
  Closes an epic's, bug's, OR enhancement's release cycle. Archives the
  complete spec/ + reports/ + runtime-artifacts/ (including audit.md and aire-state.md) into
  aire-archives/epics/<EPIC-ID>-<name>/ (epic cycles), aire-archives/bugs/<BUG-ID>-<name>/
  (bug cycles), or aire-archives/enhancements/<ENH-ID>-<name>/ (enhancement cycles), per the
  Workflow Type recorded in runtime-artifacts/aire-state.md, at the workspace root. Does NOT
  generate a reverse-engineering delta and does NOT stitch anything — current-system truth
  (atlas-deep-dive.md + the flat RE docs) is refreshed fresh from Atlas via the Helix MCP at the start
  of each new cycle. Confirm-first at every destructive step; offers an optional workspace reset
  for the next cycle.
when_to_use: >
  Trigger when the user says: "archive-epic", "archive the epic", "close the release
  cycle", "archive aire docs", "end of release archive", "wrap up this epic", "release archive".
allowed-tools: Read Grep Glob Bash Write Edit
---

# Archive Epic — Release Archive

Load and execute the agent instructions from:

```
aire-workflow/agents/archive-epic-agent.md
```

Read that file completely and follow every step defined in it.

**Key rules**:
- 🔴 **No delta generation, no stitching.** This skill does NOT produce a reverse-engineering delta and does NOT stitch anything. Current-system truth (`spec/plans/atlas-deep-dive.md` + the flat RE docs under `spec/plans/`) is refreshed fresh from Atlas via the Helix MCP at the start of each new cycle — there is nothing to diff or fold back.
- NEVER delete or reset anything before the archive copy is created AND verified
- **Archive layout is FIXED — an EXACT MIRROR of `spec/`, `reports/` AND `runtime-artifacts/`**: every archive folder (`aire-archives/epics|bugs|enhancements/<ID>-<name>/`) contains **`spec/`** (a complete recursive copy of the live `spec/` tree — all flat `plans/` docs, `spec-generation/`, every work-unit `.feature`, `existing-knowledge/`, `new-references/`), **`reports/`** (a complete recursive copy of the live `reports/` tree, when it exists), **`runtime-artifacts/`** (audit.md + aire-state.md, when it exists), and a sibling **`archive-manifest.md`**. `cp -R spec "$ARCH/spec"` plus `cp -R reports "$ARCH/reports"` plus `cp -R runtime-artifacts "$ARCH/runtime-artifacts"` — no unpacking, no renaming, no per-folder logic, no exclusions. NEVER copy any tree's contents into the archive root (that leaves `plans/`, `design docs`, `aire-state.md`, `audit.md` loose beside the manifest). See archive-epic-agent.md Step 3–5 for the copy commands and the mandatory structural verification.
- **Archive EVERYTHING under `spec/`, `reports/` and `runtime-artifacts/` — for EVERY cycle type**: each archived tree is a **complete, recursive, unfiltered, byte-for-byte** copy of the live one — `spec/` (all `plans/` docs incl. architecture.md, atlas-deep-dive.md + flat RE docs, requirements, stories/personas, design docs, dependency-graph.yml; plus `spec-generation/`, `behavior/`, `test-plans/`, `behavior.feature`, `context-project/`), `reports/` (unit/behavior/api-contract/eval evidence, `reviews/`, `code-security-reviews/`, `ticket-summary/`), and `runtime-artifacts/` (audit.md, aire-state.md) — so the snapshot answers *what were we working from*, not only *what did we produce* — every folder and every file at every depth, plus anything else present. The cycle type (`epics/` | `bugs/` | `enhancements/`) changes **only the destination subfolder — never what gets copied**: a bug or enhancement cycle archives the same full trees an epic cycle does. NEVER archive a subset/whitelist, never skip a folder for looking empty/stale/irrelevant-to-this-cycle-type/owned-by-another-role, never filter by extension, name, dotfile-ness, or `.gitignore` (untracked and ignored files are archived too), and never move/delete/rewrite/summarize anything while copying.
- **No exclusions.** The copy is complete and unfiltered. Enforced by the BLOCKING completeness check in archive-epic-agent.md Step 5 — each live-vs-archived relative-path diff (`spec/`, `reports/`, `runtime-artifacts/`) must be COMPLETELY EMPTY before Step 6 is allowed to delete any live docs.
- **Bug mode**: when `runtime-artifacts/aire-state.md` `## Tracker` records `Workflow Type: bug`, the agent runs in bug mode — cycle ID = the defect ticket, archive goes to `aire-archives/bugs/<BUG-ID>-<name>/`, and the readiness check verifies the `[BUG]` PR was raised (the bug's story intentionally stays In Development). Epic archives go to `aire-archives/epics/<EPIC-ID>-<name>/`.
- **Enhancement mode**: when `## Tracker` records `Workflow Type: enhancement`, the agent runs in enhancement mode — identical to bug mode except: cycle ID = the enhancement ticket (`Parent Ticket`), archive goes to `aire-archives/enhancements/<ENH-ID>-<name>/`, and the readiness check verifies the `[ENH]` PR was raised (`Enhancement PR` in `## Branching`).
- If `aire-archives/` (or its `epics/`/`bugs/`/`enhancements/` subfolders) already exists, reuse it — never recreate it or touch other cycle folders inside it; only a same-name cycle folder may be replaced, and only after the user explicitly confirms
- Every destructive step is confirm-first; log everything in runtime-artifacts/audit.md.
- **Auto-triggered ONLY for epic cycles** — by pr-generator on an **Epic → Base PR**: there the Step 6 workspace-reset question is NOT asked — option A (Reset, keep human-curated context) is auto-selected, announced, and logged in runtime-artifacts/audit.md. Option B is never auto-selected.
- 🔴 **Bug and enhancement cycles archive MANUALLY** — the operator invokes this skill themselves. `bug-fix-implement` (Step 12) and `enhancement-implement` (Step 19) deliberately do NOT invoke it, and pr-generator's Phase 7 auto-trigger excludes `[BUG]`/`[ENH]` → Base PRs. Those runs are standalone, so the Step 6 reset question IS asked. **Why**: ve work lands on the cycle branch unsynchronised with the ticket's PR — `/ve-implement` writes `spec/test-plans/<TICKET-ID>-<title>/` on its own `ve/...` branch + PR (often raised after the fix is done) and `ve-list-work` Option C amends test plans later still. Since this skill takes a one-shot destructive snapshot and then resets the live docs, an automatic archive at PR time would silently omit `tests/` or miss later test-plan edits, with nothing left to re-capture them.
- **Step 2.5 ve readiness check (all modes)**: the branch must be up to date with origin, expected `spec/test-plans/<TICKET-ID>-…/` folders must exist, and no `ve/...` PR into the cycle branch may still be open. Gaps are surfaced with a confirm-first "archive anyway?" prompt and, if the user proceeds, recorded as `**Known Gaps**:` in `archive-manifest.md`.
- **Timing invariant (manual runs)**: `archive-epic` must still run **BEFORE the `[BUG]`/`[ENH]` PR merges** — its cycle-close commit rides the open PR so the archive reaches the base branch.
- **The cycle-close changes MUST be committed and pushed on the epic/bug/enhancement branch** (Step 6.5, push confirm-first) — the archive + workspace reset reach the base branch by riding the open PR. The open PR tracks the branch and picks up the commit automatically.
