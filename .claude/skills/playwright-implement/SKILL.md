---
name: playwright-implement
description: >
  Turns a story's already-Approved manual Test Plan plan into executable Playwright UI
  automation by orchestrating Playwright's OWN official Test Agents (Planner, Generator, Healer --
  installed once per repo via `npx playwright init-agents --loop=claude` as real Claude Code
  subagents backed by the playwright-test MCP server). Never re-implements those agents' own logic.
  Flow: Prerequisite Gate (Playwright + its agents installed, local frontend server up, fixture data
  seeded) -> Seed Test Gate (derive/confirm tests/e2e/seed.spec.ts with the user before the Planner runs)
  -> invoke the real Planner agent, scoped strictly to this story's UI-relevant manual test cases ->
  a mandatory user Approval Gate on the Planner's own plan output (tests/playwright-specs/<story-slug>.md) -> invoke
  the real Generator agent per scenario (writes tests/e2e/<story-slug>/*.spec.ts) -> local execution via
  `npx playwright test tests/e2e/<story-slug>/ --headed` -> invoke the real Healer agent on any failure
  (its own loop, never shortcut; a test.fixme() outcome is a candidate product defect signal, routed
  to raise-defect) -> a confirm-first Push Gate, then commits and pushes directly to the integration
  branch (epic/bug/enhancement) -- no branch of its own, no PR; the Push Gate is this skill's only
  review checkpoint before that branch changes. Runs only after both the dev's PR and /ve-implement's
  own PR have already merged into that branch, so its Planner/Generator have the real code and the
  manual test docs to work from. UI/browser only -- Playwright's shipped agents carry no API/request-fixture
  tooling, so backend/API manual test cases stay manual-only, always. Additive only -- never modifies
  /ve-implement's manual, black-box test steps, and never touches Story Tracker or tracker status.
  Only runs when the Playwright Test Automation extension is opted into during Requirements Analysis.
  TWO MODES: STANDALONE (the user types /playwright-implement — everything above applies as written,
  post-merge, with the both-merges gate, the Approval Gate and the Push Gate), and WORKFLOW (invoked as
  a step by dev-implement / bug-fix-implement / enhancement-implement with mode: workflow and the story
  passed in — pre-PR, on the work unit's own branch: the story-picker, the both-merges gate, the branch
  checkout, the Approval Gate and the Push Gate are all SKIPPED, the seed auto-derives, the app is
  started and torn down by the skill itself, and the generated artifacts ride the caller's own commit).
  Execution is --headed in BOTH modes — it is the developer's own machine, and headless belongs to CI
  alone, where a runner has no display. Skipping approvals never skips verification.
when_to_use: >
  Trigger when the user says: "/playwright-implement 1.2", "/playwright-implement AT-898",
  "/playwright-implement", "automate this story's tests", "generate playwright scripts for story 1.2",
  "turn the Test Plan plan into automation", "playwright automation for AT-898",
  "run playwright tests for this story", "playwright-implement".
allowed-tools: Read Grep Glob Bash Write Edit Agent
---

# Playwright Implement — orchestrates Playwright's own Planner/Generator/Healer for ONE story

Load and execute the agent instructions from:

```
aire-workflow/agents/playwright-implement-agent.md
```

That file in turn loads and executes:

```
aire-workflow/extensions/testing/playwright-automation/playwright-automation.md
```

Read both completely and follow every step defined in them, in order.

🔴 **FIRST resolve the mode** (`playwright-implement-agent.md` → **Mode Detection**):
- **STANDALONE** (the user typed the trigger) — never skip the Prerequisite Gate (Step 0), the
  both-merges gate (Step 2a), the Approval Gate (Step 2/7) or the Push Gate (Step 12).
- **WORKFLOW** (`mode: workflow`, invoked by `dev-implement` / `bug-fix-implement` /
  `enhancement-implement` with the story passed in) — the Mode Detection table governs: approvals,
  the both-merges gate, the branch checkout and the push are skipped; the Prerequisite Gate, the real
  Planner/Generator/Healer subagents and the actual `--headed` test run all still happen.

🔴 The Prerequisite Gate (Step 0) is never skipped in **either** mode.
