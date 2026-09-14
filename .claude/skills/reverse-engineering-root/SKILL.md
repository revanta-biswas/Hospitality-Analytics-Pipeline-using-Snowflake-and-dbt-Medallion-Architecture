---
name: reverse-engineering-root
description: >
  Generates the ROOT reverse engineering artifacts for the whole workspace in a single
  pass — one artifact set flat in spec/plans/ covering ALL
  modules of a monorepo (business overview, architecture, code structure, APIs,
  component inventory, technology stack, dependencies, code quality, timestamp with
  commit fingerprint). All modules and all downstream AIRE stages reuse these root
  artifacts for development. Run it upfront before starting an epic cycle, and
  (recommended) re-run it post release cycle — after archive-epic — to regenerate a
  fresh baseline from the released codebase.
when_to_use: >
  Trigger when the user says: "reverse-engineering-root", "reverse engineer the root",
  "generate root reverse engineering docs", "refresh reverse engineering artifacts",
  "regenerate reverse engineering baseline", "reverse engineer the monorepo",
  "post-release reverse engineering".
allowed-tools: Read Grep Glob Bash Write
---

# Reverse Engineer Root — Root-Level Artifacts for All Modules

Load and execute the reverse engineering stage instructions from:

```
aire-workflow/planning/reverse-engineering.md
```

Read that file completely and follow every step defined in it, applying its
**"Monorepo Handling — Root-Level, Single Pass"** and
**"Standalone Invocation — `reverse-engineering-root` Skill"** sections:

- **As the very first step**, ensure the root-level `spec/context-project/existing-knowledge/` folder exists per reverse-engineering.md's "Context Project Folder" section — check first, and create an EMPTY folder only if it is absent (never recreate/overwrite an existing one, and do NOT add a README inside it)
- Execute ONCE at the workspace root, covering ALL modules — one artifact set, never per-module sets
- **Accuracy Rules are MANDATORY** (see "Accuracy Rules — Apply to ALL Artifact Writing" in that file): verify every factual claim against the actual code at HEAD before writing it, and produce every quantitative figure by running the real command at generation time — never estimate, sum, or carry numbers forward from other documents
- If `spec/` does not exist, create the minimal structure first
- If artifacts already exist, this is a refresh against the current code state
- In the Step 12 completion message, offer " Approve & Finish" instead of proceeding to Requirements Analysis
- Log the invocation, completion, and user approval in `runtime-artifacts/audit.md`
