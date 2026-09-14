# Reverse Engineering

**Purpose**: Analyze existing codebase and generate comprehensive design artifacts

**Execute when**: Brownfield project detected (existing code found in workspace)

**Skip when**: Greenfield project (no existing code)

**Rerun behavior**: Rerun is controlled by workspace-detection.md. If existing reverse engineering artifacts are found and are still current, they are loaded and reverse engineering is skipped. If artifacts are stale (older than the codebase's last significant modification) or the user explicitly requests a rerun, reverse engineering executes again to ensure artifacts reflect current code state

## Monorepo Handling — Root-Level, Single Pass

**CRITICAL**: In a monorepo (multiple modules/packages under one workspace root), reverse engineering executes **ONCE at the workspace root**, covering ALL modules in a single pass:

- **One artifact set**: All artifacts are generated FLAT in `spec/plans/` (the ROOT reverse engineering documents, alongside `atlas-deep-dive.md`). NEVER generate separate per-module reverse engineering document sets.
- **Module detail lives inside the root docs**: each module/package gets its own component-level sections within `business-overview.md`, `atlas-deep-dive.md`, `code-structure.md`, `component-inventory.md`, and `dependencies.md`.
- **All modules reuse the root artifacts**: every downstream stage (Requirements Analysis, User Stories, design stages, `dev-implement`), regardless of which module a story touches, loads the SAME root artifacts. Do NOT re-run reverse engineering per module or per story.
- **Keeping root docs current**: current-system truth is refreshed **fresh from Atlas via the Helix MCP** at the start of each cycle (`common/helix-atlas-integration.md`), or by re-running this stage. There is no per-cycle delta and no stitching — a cycle never has to diff itself against a prior cycle's documents.

## Standalone Invocation — `reverse-engineering-root` Skill

This stage can also be invoked standalone (outside the main workflow) via the **`reverse-engineering-root`** skill:

- **When**: (a) upfront, before starting a new epic cycle, to create the root artifacts once for all modules; (b) **RECOMMENDED: post release cycle**, after `archive-epic` has archived the previous epic, to regenerate fresh root artifacts from the released codebase.
- **Mode differences in standalone runs**:
  - If `spec/` does not exist yet, create the minimal structure (`spec/plans/`, `runtime-artifacts/audit.md` with an `# Audit Log` header) before Step 1.
  - Execute Steps 1–12 exactly as written. In Step 12, replace the "proceed to **Requirements Analysis**" option with " **Approve & Finish** — artifacts are ready for all modules to use"; the skill ends after approval (Step 13).
  - If artifacts already exist, this is a refresh: regenerate all artifacts against the current code state and update the timestamp file.
- Log the standalone invocation and completion in `runtime-artifacts/audit.md` as with any stage.

## Context Project Folder (root, human-curated — scaffolded here)

As its **very first step** (before Step 1, in BOTH the inline stage and the standalone `reverse-engineering-root` skill), this stage ensures a **`spec/context-project/existing-knowledge/` folder exists** (inside `spec/`, a sibling of `spec/`):

- **Check first, create only if missing**: test whether `spec/context-project/existing-knowledge/` already exists. **If it already exists** (e.g. left by an earlier run, or already curated by the team) — **reuse it AS-IS**: do NOT recreate, empty, overwrite, or delete it or anything under it. **Only if it is absent**, create an empty `spec/context-project/existing-knowledge/` folder. **Do NOT create a README inside it** — humans curate its contents.
- **What it is for**: a human-authored home for **knowledge about the CURRENT project** — how the existing system works, where things live, what each module does (e.g. an `interview.md` explaining a module's behavior and layout). This is context about what already exists, NOT requirements for the new work (those come from the Epic). The framework never auto-populates it.
- **Convention**: one subfolder per repo module, named **exactly** after the module (e.g. for a repo `ALIX_DX` containing `ALIX.BMS`, create `spec/context-project/existing-knowledge/ALIX.BMS/` and place its `interview.md` etc. there).
- **How it is used**: it is read **only when the user opts in** at workflow start (Workspace Detection asks "Are there any context-project artifacts I should use for this task?") and **only at the exact path the user pastes** — Requirements Analysis and Workflow Planning then consult that path as background context about the existing system. Nothing under `spec/context-project/existing-knowledge/` is auto-scanned.

When writing the reverse engineering artifacts, note in `code-structure.md` (or the workspace-layout section of `atlas-deep-dive.md`) that a `spec/context-project/existing-knowledge/` folder is present and is used as human-curated context input to the AIRE workflow — so it is not mistaken for application source.

## Accuracy Rules — Apply to ALL Artifact Writing

These rules govern root artifact generation (Steps 2–9 below, including standalone `reverse-engineering-root` runs) — every reverse engineering document, whichever path writes it:

- **🔴 Ground truth is the code at HEAD, not documents**: before writing ANY factual claim into an artifact (a file/export/route exists, a convention is followed, an element is unused/removed, a token/pattern is used), verify it by reading or grepping the actual code. Prior documents — story summaries, design docs, earlier baselines — record *intent* or *past state*; NEVER treat them as evidence about the current code.
- **🔴 Measured facts must be measured**: every quantitative claim (test totals, pass/fail counts, file counts, page counts, import counts, coverage) MUST be produced by running the real command at writing time — e.g. run the test suite and copy its reported `Tests N passed (M)` totals; use `grep -rl ... | wc -l` for file counts. NEVER sum, estimate, or carry numbers forward from other documents. Where practical, record the command next to the figure so the next run can reproduce the measurement.

A regenerated baseline is only the "highest-fidelity correction" if these rules were followed while writing it — they are not optional in any path.

## Step 1: Multi-Package Discovery

### 1.1 Scan Workspace
- All packages (not just mentioned ones)
- Package relationships via config files
- Package types: Application, CDK/Infrastructure, Models, Clients, Tests

### 1.2 Understand the Business Context
- The core business that the system is implementing overall
- The business overview of every package
- List of Business Transactions that are implemented in the system

### 1.3 Infrastructure Discovery
- CDK packages (package.json with CDK dependencies)
- Terraform (.tf files)
- CloudFormation (.yaml/.json templates)
- Deployment scripts

### 1.4 Build System Discovery
- Build systems: Brazil, Maven, Gradle, npm
- Config files for build-system declarations
- Build dependencies between packages

### 1.5 Service Architecture Discovery
- Lambda functions (handlers, triggers)
- Container services (Docker/ECS configs)
- API definitions (Smithy models, OpenAPI specs)
- Data stores (DynamoDB, S3, etc.)

### 1.6 Code Quality Analysis
- Programming languages and frameworks
- Test coverage indicators
- Linting configurations
- CI/CD pipelines

## Step 2: Generate Business Overview Documentation

Create `spec/plans/business-overview.md`:

```markdown
# Business Overview

## Business Context Diagram
[Mermaid diagram showing the Business Context]

## Business Description
- **Business Description**: [Overall Business description of what the system does]
- **Business Transactions**: [List of Business Transactions that the system implements and their descriptions]
- **Business Dictionary**: [Business dictionary terms that the system follows and their meaning]

## Component Level Business Descriptions
### [Package/Component Name]
- **Purpose**: [What it does from the business perspective]
- **Responsibilities**: [Key responsibilities]
```

## Step 3: Generate Architecture Documentation

Create `spec/plans/atlas-deep-dive.md`:

```markdown
# System Architecture

## System Overview
[High-level description of the system]

## Architecture Diagram
[Mermaid diagram showing all packages, services, data stores, relationships]

## Component Descriptions
### [Package/Component Name]
- **Purpose**: [What it does]
- **Responsibilities**: [Key responsibilities]
- **Dependencies**: [What it depends on]
- **Type**: [Application/Infrastructure/Model/Client/Test]

## Data Flow
[Mermaid sequence diagram of key workflows]

## Integration Points
- **External APIs**: [List with purposes]
- **Databases**: [List with purposes]
- **Third-party Services**: [List with purposes]

## Infrastructure Components
- **CDK Stacks**: [List with purposes]
- **Deployment Model**: [Description]
- **Networking**: [VPC, subnets, security groups]
```

## Step 4: Generate Code Structure Documentation

Create `spec/plans/code-structure.md`:

```markdown
# Code Structure

## Build System
- **Type**: [Maven/Gradle/npm/Brazil]
- **Configuration**: [Key build files and settings]

## Key Classes/Modules
[Mermaid class diagram or module hierarchy]

### Existing Files Inventory
[List all source files with their purposes - these are candidates for modification in brownfield projects]

**Example format**:
- `[path/to/file]` - [Purpose/responsibility]

## Design Patterns
### [Pattern Name]
- **Location**: [Where used]
- **Purpose**: [Why used]
- **Implementation**: [How implemented]

## Critical Dependencies
### [Dependency Name]
- **Version**: [Version number]
- **Usage**: [How and where used]
- **Purpose**: [Why needed]
```

## Step 5: Generate API Documentation

Create `spec/plans/api-documentation.md`:

```markdown
# API Documentation

## REST APIs
### [Endpoint Name]
- **Method**: [GET/POST/PUT/DELETE]
- **Path**: [/api/path]
- **Purpose**: [What it does]
- **Request**: [Request format]
- **Response**: [Response format]

## Internal APIs
### [Interface/Class Name]
- **Methods**: [List with signatures]
- **Parameters**: [Parameter descriptions]
- **Return Types**: [Return type descriptions]

## Data Models
### [Model Name]
- **Fields**: [Field descriptions]
- **Relationships**: [Related models]
- **Validation**: [Validation rules]
```

## Step 6: Generate Component Inventory

Create `spec/plans/component-inventory.md`:

```markdown
# Component Inventory

## Application Packages
- [Package name] - [Purpose]

## Infrastructure Packages
- [Package name] - [CDK/Terraform] - [Purpose]

## Shared Packages
- [Package name] - [Models/Utilities/Clients] - [Purpose]

## Test Packages
- [Package name] - [Integration/Load/Unit] - [Purpose]

## Total Count
- **Total Packages**: [Number]
- **Application**: [Number]
- **Infrastructure**: [Number]
- **Shared**: [Number]
- **Test**: [Number]
```

## Step 7: Generate Technology Stack Documentation

Create `spec/plans/technology-stack.md`:

```markdown
# Technology Stack

## Programming Languages
- [Language] - [Version] - [Usage]

## Frameworks
- [Framework] - [Version] - [Purpose]

## Infrastructure
- [Service] - [Purpose]

## Build Tools
- [Tool] - [Version] - [Purpose]

## Testing Tools
- [Tool] - [Version] - [Purpose]
```

## Step 8: Generate Dependencies Documentation

Create `spec/plans/dependencies.md`:

```markdown
# Dependencies

## Internal Dependencies
[Mermaid diagram showing package dependencies]

### [Package A] depends on [Package B]
- **Type**: [Compile/Runtime/Test]
- **Reason**: [Why dependency exists]

## External Dependencies
### [Dependency Name]
- **Version**: [Version]
- **Purpose**: [Why used]
- **License**: [License type]
```

## Step 9: Generate Code Quality Assessment

Create `spec/plans/code-quality-assessment.md`:

```markdown
# Code Quality Assessment

## Test Coverage
- **Overall**: [Percentage or Good/Fair/Poor/None]
- **Unit Tests**: [Status]
- **Integration Tests**: [Status]

## Code Quality Indicators
- **Linting**: [Configured/Not configured]
- **Code Style**: [Consistent/Inconsistent]
- **Documentation**: [Good/Fair/Poor]

## Technical Debt
- [Issue description and location]

## Patterns and Anti-patterns
- **Good Patterns**: [List]
- **Anti-patterns**: [List with locations]
```

## Step 10: Create Timestamp File

Create `spec/plans/reverse-engineering-timestamp.md`:

```markdown
# Reverse Engineering Metadata

**Analysis Date**: [ISO timestamp]
**Analyzer**: aire
**Workspace**: [Workspace path]
**Analyzed At Commit**: [git HEAD SHA at analysis time, or N/A if not a git repo]
**Total Files Analyzed**: [Number]

## Artifacts Generated
- [x] business-overview.md
- [x] atlas-deep-dive.md
- [x] code-structure.md
- [x] api-documentation.md
- [x] component-inventory.md
- [x] technology-stack.md
- [x] dependencies.md
- [x] code-quality-assessment.md
```

## Step 11: Update State Tracking

Update `runtime-artifacts/aire-state.md`:

```markdown
## Reverse Engineering Status
- [x] Reverse Engineering - Completed on [timestamp]
- **Artifacts Location**: spec/plans/
```

## Step 12: Present Completion Message to User

```markdown
# Reverse Engineering Complete

[AI-generated summary of key findings from analysis in the form of bullet points]

> ** <u>**REVIEW REQUIRED:**</u>**  
> Please examine the reverse engineering artifacts at: `spec/plans/`

> ** <u>**WHAT'S NEXT?**</u>**
>
> **You may:**
>
> **Request Changes** - Ask for modifications to the reverse engineering analysis if required
> **Approve & Continue** - Approve analysis and proceed to **Requirements Analysis**
```

## Step 13: Wait for User Approval

- **MANDATORY**: Do not proceed until user explicitly approves
- **MANDATORY**: Log user's response in runtime-artifacts/audit.md with complete raw input

---

## Keeping the Root Docs Current Across Cycles

There is **no per-cycle delta and no stitching**. Current-system truth is refreshed **fresh from Atlas
via the Helix MCP** at the start of each new cycle (`common/helix-atlas-integration.md`) — the knowledge
graph plus the deepdive docs (`spec/plans/atlas-deep-dive.md` and the flat RE docs under `spec/plans/`) — so a
cycle never has to diff itself against a prior cycle's documents or fold changes back into root
documents. `archive-epic` archives the cycle's `spec/` + `reports/` + `runtime-artifacts/` and generates
no delta.

> **Post-release recommendation**: after `archive-epic` completes, when Atlas is not the source, run the
> **`reverse-engineering-root`** skill to fully regenerate the root artifacts from the released codebase —
> the highest-fidelity local baseline for the next epic.
