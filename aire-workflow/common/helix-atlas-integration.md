# Helix MCP ↔ Atlas Integration — Reuse Existing-System Truth, Never Re-Derive It

**Purpose**: AIRE does not re-discover a system it already has documentation for. **Atlas** holds the
existing-system truth for brownfield estates as **one deep dive `.md` document** for the estate/scope,
landing at `spec/plans/atlas-deep-dive.md`. The **Helix MCP server** is how AIRE reaches Atlas.

**The rule in one line**: when the work touches an existing system, Atlas is the source of the
reverse-engineering truth and AIRE consumes it; AIRE generates that truth locally **only** when Atlas
is genuinely unavailable, and says so out loud when it does.

**Load this file when**: Workspace Detection runs, Reverse Engineering is being considered, a
migration/modernisation is detected, or any stage needs existing-system context.

---

## 1. When Helix is REQUIRED (blocking) vs OPTIONAL

| Situation | Helix MCP |
|---|---|
| **Brownfield** — existing code detected in the workspace | 🔴 **REQUIRED** — prompt to connect and HALT |
| **Migration / modernisation / re-platform** — stated by the user or inferred from the Epic | 🔴 **REQUIRED** — prompt to connect and HALT |
| **Integration with an existing system** the workspace does not contain | 🔴 **REQUIRED** — prompt to connect and HALT |
| **Greenfield**, no existing system referenced anywhere | ⚪ **OPTIONAL** — never prompt, never block |

**Migration/brownfield detection signals** (any one is enough):
- Workspace Detection classified the workspace **brownfield**.
- The Epic / ticket / user request contains: *migrate, migration, modernise/modernize, re-platform,
  replatform, port, legacy, rewrite, refactor <existing system>, strangler, lift and shift, upgrade
  from, replace <system>, integrate with <existing system>*.
- The user names a system that is not in this workspace as something to build against.

---

## 2. Local-first check — before contacting Helix at all

🔴 **Always check the workspace before ever reaching for Atlas.** This runs as part of Workspace
Detection (`planning/workspace-detection.md` Step 3), before Section 1's REQUIRED/OPTIONAL dispatch
even matters:

1. **Check whether `spec/plans/atlas-deep-dive.md` already exists** in the workspace (default location
   first, then the whole-repo glob workspace-detection.md already does for the flat RE docs).
2. **If it exists**: reuse it as current-system truth. Do NOT contact Helix, do NOT re-pull, do NOT
   show the connect gate. Load it like any other existing RE artifact.
3. **If it does NOT exist**: proceed to Section 3 (Discovery) and, per Section 1, resolve a Helix
   provider and pull the deep dive doc from Atlas.

This is a plain file-existence check, not a freshness policy — if the user wants a forced refresh from
Atlas, they say so explicitly and AIRE re-pulls, overwriting the local file.

---

## 3. Discovery — never hardcode, always resolve at runtime

🔴 **Do NOT assume tool names.** Deployments differ. Resolve the server and its tools at the moment
you need them.

**Resolution order:**

1. **Enumerate the connected MCP servers and their tools** available in this session (the host lists
   them; use the tool-discovery mechanism the session provides).
2. **Match a Helix/Atlas provider** — a server or tool whose name or description contains any of:
   `helix`, `atlas`, `deepdive`, `deep dive`, `codebase graph`.
3. **Classify the matched tools by capability**, by what their descriptions say they do:
   - **DOCS** — fetches the deep dive `.md` document for the estate/scope (the pull AIRE actually uses)
   - **GRAPH / SEARCH** — queries relationships or free-text across the indexed estate, used only for a
     targeted inline answer a stage needs (Section 5) — never to produce their own flat artifact file
4. **Record the binding** in `runtime-artifacts/aire-state.md` (Section 7) so later stages and later sessions reuse it without
   re-discovering.

**If matching is ambiguous** (several plausible servers): list what you found and ask the user which
one is Helix. Do not guess — pulling architecture truth from the wrong system is worse than pausing.

### TOOL BINDING — fill in on first successful discovery

Write the resolved binding into `runtime-artifacts/aire-state.md`. Never invent values for it.

```markdown
## Helix MCP Binding
- **Server**: <resolved MCP server name>
- **Docs tool(s)**: <tool name(s)> — <one-line purpose>
- **Graph/Search tool(s)**: <tool name(s)> — <one-line purpose, if any>
- **Estate / workspace id**: <the Atlas workspace or repo identifier queried>
- **Resolved**: <ISO 8601 timestamp>
```

---

## 4. The connect gate (blocking)

When Helix is REQUIRED (Section 1), `spec/plans/atlas-deep-dive.md` does not already exist locally
(Section 2), and either no Helix provider resolves OR Atlas has no deep dive doc for this scope,
**HALT**. Do not fall back to local reverse engineering without the user's explicit instruction —
silently re-deriving what Atlas already holds produces a second, divergent source of truth, which is
the exact failure this integration exists to prevent.

Emit **verbatim**, substituting the bracketed values:

```
 HELIX MCP REQUIRED — connect Atlas to continue

   This is a [brownfield workspace | migration | integration with an existing system].
   AIRE reuses Atlas's existing-system truth instead of re-deriving it: the deep dive doc holds the
   system's architecture, components, dependencies and behaviour, already reviewed.

   [No Helix MCP server is connected in this session | Helix is connected, but Atlas has no deep dive
   document for this codebase].

 How do you want to proceed?
   A)  I'll connect Helix now / I will generate deep-dive document on Atlas — stop, and I will re-run once it's connected/generated. (Recommended)
   B)  Proceed WITHOUT Atlas — AIRE generates reverse-engineering artifacts locally from the code
         in this workspace. This choice is recorded in runtime-artifacts/aire-state.md and runtime-artifacts/audit.md.

[Answer]:
```

🔴 **Only options A and B — never add a third.** Both triggers for this gate (no Helix connected, or
Helix connected but no deep dive doc found) land on the exact same two-option prompt and resolve
through option B's same recorded outcome. Never invent an option C.

- **A** → HALT. Log the halt in `runtime-artifacts/audit.md`. Nothing else runs.
- **B** → record `Source: local-generation (Atlas unavailable — user approved)` in the provenance
  block, in `runtime-artifacts/aire-state.md`, and in `runtime-artifacts/audit.md`, then run the normal
  `planning/reverse-engineering.md` stage to **generate** the reverse-engineering artifacts locally.
  🔴 Every downstream artifact derived this way carries the line *"Existing-system context derived
  locally; Atlas was not consulted."*

🔴 Log the prompt and the raw user response in `runtime-artifacts/audit.md`. This is a real decision with downstream
consequences and it must be attributable.

---

## 5. What to pull, and where it lands

Once a Helix provider is bound, pull **before** any planning stage that needs system context — that
is, before Reverse Engineering is even considered, and before Requirements Analysis reads its inputs.

🔴 **Atlas is the source of current-system truth at the START of EVERY cycle**, when it hasn't already
been pulled locally (Section 2). Each new cycle that needs a fresh pull gets the deep dive doc from
Atlas (`spec/plans/atlas-deep-dive.md`) rather than carrying forward, diffing, or folding back anything
from a prior cycle. There is no per-cycle reverse-engineering delta and nothing to stitch: because the
truth is always refreshed from Atlas, a cycle never has to reconcile itself against a previous cycle's
documents. When the cycle's PR merges, the next cycle simply pulls again.

| Pull | Via | Lands in | Replaces |
|---|---|---|---|
| **Deep dive document** — one `.md` document covering the estate/scope | DOCS tool | `spec/plans/atlas-deep-dive.md`, verbatim | Locally generated RE artifacts |
| **Targeted answers** — a specific contract, schema, or flow a stage needs | SEARCH / GRAPH | Quoted inline in the consuming artifact, with the citation | Guessing |

🔴 **If the DOCS tool reports no deep dive document for the resolved scope**, do not treat this as an
error to retry or paper over. Tell the user plainly: **"No deep dive document found on Atlas."** Then
go to Section 4 (the connect gate) and present the same A/B halt — if the user picks B, **generate**
the reverse-engineering artifacts locally, exactly as any other local-generation path, and say so in
every artifact's provenance.

### 5.1 Scoping the pull — pull what the work touches, not the whole estate

🔴 **Never dump the entire estate.** Resolve scope in this order and pull only that:
1. The components named in the Epic / ticket / requirements.
2. Their **direct** dependencies and dependents, per the deep dive doc's own component map (one hop).
3. Any component that owns a data store or contract the work will read or write.

Record the scope you resolved and why. If a later stage needs a component outside the pulled scope,
pull it then — incrementally — and note the extension.

### 5.2 Provenance block — MANDATORY on every artifact sourced from Atlas

Every file written from Atlas content opens with this block. An Atlas-derived document without
provenance is indistinguishable from an AI-invented one, which destroys its value as truth.

```markdown
> **Source**: Atlas via Helix MCP
> **Server / tool**: <server> · <tool>
> **Estate**: <estate or repo identifier>
> **Scope pulled**: <components and the rule that selected them>
> **Fetched**: <ISO 8601 timestamp>
> **Freshness**: <Atlas's own last-indexed timestamp, if it exposes one — else "not reported">
```

### 5.3 🔴 Never edit Atlas content to make it fit

Atlas documents are **read-only inputs**. Copy them faithfully. If Atlas contradicts an assumption in
the Epic, the requirements, or a design artifact, that contradiction is a **finding to surface**, not
a discrepancy to smooth over:

> **Atlas conflict** — `<component>`: Atlas states `<X>`; `<artifact>` assumes `<Y>`.
> Proceeding on Atlas (existing-system truth wins) and amending `<artifact>` to match.
> Recorded in runtime-artifacts/audit.md.

Follow Atlas, amend the AIRE-side artifact to stay truthful, say so plainly, log it. Never the reverse
— never rewrite an Atlas document to agree with a plan.

---

## 6. Effect on the Reverse Engineering stage

`planning/reverse-engineering.md` becomes **conditional on whether Atlas returns a deep dive document**:

| Atlas deep dive doc | Reverse Engineering stage |
|---|---|
| **Already exists locally** (`spec/plans/atlas-deep-dive.md`, Section 2) |  **SKIPPED.** Reuse it as-is. Record `Source: atlas (local file)`. |
| **Found** on Atlas for the resolved scope |  **SKIPPED.** Pull it into `spec/plans/atlas-deep-dive.md`, verbatim — it IS the artifact. Record `Source: atlas`. Announce the skip and what it saved. |
| **Not found** (Helix connected, but Atlas has no deep dive doc for this scope) | Tell the user *"No deep dive document found on Atlas."* Then present the Section 4 connect gate (A/B) — on **B**, ▶ **generate** the reverse-engineering artifacts locally, with the "Atlas was not consulted" banner on every artifact. |
| **Helix unavailable**, user chose option B at the connect gate (Section 4) | ▶ **generate** the reverse-engineering artifacts locally, exactly as before, with the "Atlas was not consulted" banner on every artifact. |

Record which branch was taken in `runtime-artifacts/aire-state.md` and `runtime-artifacts/audit.md`. Announce it — the user needs to know
whether they are reading reviewed estate truth or a fresh AI derivation.

---

## 7. State recorded in `runtime-artifacts/aire-state.md`

```markdown
## Existing-System Context
- **Workspace type**: brownfield | greenfield | migration
- **Helix MCP**: connected | not connected | declined by user
- **Source**: atlas (local file) | atlas | local-generation
- **Components in scope**: <list>
- **Atlas deep dive doc**: spec/plans/atlas-deep-dive.md | not found | not fetched
- **Recorded**: <ISO 8601 timestamp>
```

---

## 8. Downstream consumers — who reads Atlas content and for what

| Stage / artifact | Uses |
|---|---|
| Requirements Analysis | `atlas-deep-dive.md` to ground scope and spot impacted components the Epic omitted |
| User Stories | Component boundaries from `atlas-deep-dive.md` to keep stories independently implementable |
| Dependency Graph | Real inter-component dependencies from `atlas-deep-dive.md` — not guessed from story titles |
| `spec/plans/architecture.md` | Existing architecture is the **starting state**; the design records the delta from it |
| `tests/.evals/rubrics/architecture-rubric.json` | Fallback chain link 3 — derive criteria from Atlas truth when no design stage ran |
| Code Generation | Real signatures, error shapes and conventions of the code being changed |

🔴 **A stage that needs existing-system context and has none must say so** — not proceed on
assumption. "I don't have Atlas coverage for `<component>`" is a valid, required output.
