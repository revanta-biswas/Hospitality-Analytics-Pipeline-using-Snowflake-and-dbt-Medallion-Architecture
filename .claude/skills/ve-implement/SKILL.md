---
name: ve-implement
description: >
  ve Test Plan for ONE story, run in PARALLEL with development. Test Plan is not a stage
  of the development workflow — it lives here. Resolves a story, reads its acceptance criteria from
  the configured tracker (JIRA/ADO/GITHUB) / stories.md plus requirements.md and the implementation design artifacts — never application
  source code — and writes that story's Test Plan artifacts as MANUAL test steps
  (integration, E2E, API, contract, security, performance, accessibility — whichever apply; there is
  no build-verification artifact, each plan opens with a System Under Test precondition block instead)
  into spec/test-plans/<TICKET-ID>-<title>/, with every test case traced to an acceptance criterion.
  Needs no DEV code, branch, PR or merge, so ve can run it the moment a story exists — it never
  depends on or waits for the dev's branch/PR. It DOES cut its own `ve/<TICKET-ID>-<title>` branch
  from the resolved integration branch (Epic Branch for epic cycles, Bug/Enhancement Branch for
  those cycles), commit the generated docs, and (confirm-first) push and raise its own PR back into
  that branch, labeled `ai-generated` + `aire-v<version>` (the framework version read live from
  CLAUDE.md, same convention as pr-generator). No test automation, no test execution, no application code
  changes — and never changes story or tracker status (that remains `ve-list-work`'s job).
when_to_use: >
  Trigger when the user says: "/ve-implement 1.2", "/ve-implement PROJ-123", "/ve-implement",
  "Test Plan for story 1.2", "generate test steps for story 1.2",
  "manual test cases for PROJ-123", "test plan for this story",
  "test cases from acceptance criteria", "ve this story", "run ve-implement", "ve-implement".
allowed-tools: Read Grep Glob Bash Write
---

# 🧪 ve Implement — Test Plan (per story)

Load and execute the agent instructions from:

```
aire-workflow/agents/ve-implement-agent.md
```

Read that file completely and follow every step defined in it.

