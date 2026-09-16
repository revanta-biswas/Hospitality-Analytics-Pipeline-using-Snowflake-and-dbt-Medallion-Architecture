# CI Pipeline Generation — AIRE Builds the Project's Own Eval Pipeline

---

## 1. 🔴 Generated from the canonical templates — never hand-authored, never re-derived

🔴 **The pipeline is not written by the model.** `templates/ci/` (this same `aire-workflow/`
directory) holds the canonical, versioned source: `agentic-eval-pipeline.yml.template`, the
`lib-manifest`/`read-manifest`/`ci-manifest-runner`/`run-static-evals`/`run-evals`/`auto-fix-agent`/
`validate-pipeline`/`smoke-test-epic`/`check-test-placement` scripts (`.sh` + `.ps1` — the first three
are #7a's run-time manifest readers, Section 4.0d.1/4.0f; `check-test-placement` is Section 4.0.7), the
`behavior/` Containerfile and entry point, and `sonar-project.properties.tmpl`. Generation means:
detect the stack, fill the `ci` manifest block in `tests/.evals/config.json` (Section 3 below defines what
goes in it), **copy** these files into the target repo, and substitute the fixed `${SLOT}` markers.
Read `templates/ci/TEMPLATE-MANIFEST.md` for the copy table and the complete slot list before generating anything.

🔴 **Note:** CI pipeline generation invocation never ask the user to characterize
implementation scope as "partial" or "full". Scope is always derived mechanically — from stack
detection (Section 3) and, for stage execution, from the PR's own diff (Section 4.0d) — never asked.

🔴 **THE SIZE OF THE JOB IS NEVER A REASON TO GATE IT.** Observed in a real run: the workflow reached
this section, saw what full generation actually involves (~20 canonical scripts copied, the 700+ line
YAML template, the V1–V34 validation sweep, the clean-room dry-run, the Section 4.1.2 SonarQube setup
gate) and, before doing any of it, stopped and presented a fabricated multiple-choice menu —
"Minimal CI bootstrap (Recommended) / Full CI generation per spec / Defer CI entirely, focus on the
fix" — asking the user to pick a scope. **None of those three options exist anywhere in this file.**
That is a fabricated gate, not a documented one, and picking "Minimal" would have silently skipped
SonarQube setup, the clean-room dry-run and most of V1–V34 — producing a non-compliant pipeline the
user never actually asked for. The correct behavior at this point is to generate the full pipeline as
specified, unconditionally, with **zero** prompts of any kind — the job being large, multi-file, or
time-consuming is not itself a trigger to pause and confirm; the only sanctioned halt in this entire
procedure is the Section 4.1.2 SonarQube setup gate, presented verbatim, never summarized, never
offered alongside other "options." If a request for confirmation of ANY kind (a scope choice, a
"proceed? y/n", a menu, a plan-approval prompt) is about to be shown for CI pipeline generation and it
is not the literal Section 4.1.2 block, that is a defect — do not show it, generate the pipeline
instead.

This deletes the failure mode a hand-authored pipeline invites: a model re-writing a constant,
drifting between the verify and self-repair jobs, or quietly breaking the parser. A pasted pipeline
that calls `npm run lint` in a repo whose script is actually `lint:ci` still fails on the first run —
but now that's a **manifest** value read wrong, not a YAML structure re-typed wrong, and it's caught by
`validate-pipeline.{sh,ps1}` (Section 4.0) before commit either way.

**Therefore:**

| Rule | Meaning |
|---|---|
| **Read, never assume** | Every value written into the `ci` manifest is read out of the repo: `package.json` scripts, `Makefile` targets, `pyproject.toml`/`tox.ini`, `pom.xml` plugins, `build.gradle` tasks, the `tests/.evals/config.json` thresholds. The manifest's `ci.roots[]` (Section 4.0d) is what `tests/.evals/scripts/ci-manifest-runner.sh` reads at run time to install/build/measure coverage — never typed directly into the copied YAML, and never re-derived by the script itself. |
| **No invented script names** | If the repo has no lint script, the manifest's install/lint command is the direct tool invocation (`npx eslint .`) — never a script name that does not exist. |
| **No invented services** | Only add a `services:` block for a datastore the repo demonstrably needs (a compose file, a test config, a connection string in test setup). |
| **Verify before committing** | Every referenced script/target must be shown to exist. `validate-pipeline.{sh,ps1}` (Section 4.0.1) is what checks this — list its result in the announcement. |
| **Same thresholds as local** | Read from `tests/.evals/config.json`. Never hardcode a number into the manifest or the YAML that duplicates it. |
| **Files themselves are never re-authored** | `agentic-eval-pipeline.yml.template` and every `tests/.evals/scripts/*` template are copied byte-for-byte except for `${SLOT}` substitution. If a template needs a behavior change, that change is made once in `templates/ci/` — never patched ad hoc in a single generated repo. |
| **No `name:` overrides** | 🔴 A job's or step's `name:` is whatever the template gives it (an omitted `name:` on a job renders as GitHub's own id-to-title casing, e.g. `verify-and-evaluate`). Never add or rewrite a `name:` field that the template itself does not define. A hand-picked display name (`Verify and evaluate`) is proof the YAML was re-authored rather than copied — this is exactly what **V27** below exists to catch. |

🔴 **If a generated repo's pipeline is ever found to disagree with `templates/ci/agentic-eval-pipeline.yml.template`
on step names, job ids, or structure** — whether from a past generation bug, a hand edit, or drift of any
kind — the fix is to **regenerate it from the current template**, never to patch the drifted file in
place. This is an operational rule, not just a validation one: a repo whose pipeline predates V27 should
have it regenerated the next time that cycle touches CI.

---

## 2. When it runs

| Flow | Generate / refresh the pipeline at |
|---|---|
| **First cycle in a repository** | **STOP CHECKPOINT Step 1.6** — generated and committed **on the cycle branch** with the other STOP CHECKPOINT artifacts (Section 2.1). 🔴 Never pushed to base; it reaches base when the cycle's PR merges. |
| **Every later cycle** | 🔴 **Nothing is regenerated** — inherited from base and used as-is. If any artifact is **missing**, create it on the cycle branch (deterministically) rather than halting: `common/directory-structure.md` — Artifact Ownership. |
| Any flow, thresholds changed | Regenerate the threshold-bearing steps only. Announce the diff. |

**Idempotent.** If `.github/workflows/agentic-eval-pipeline.yml` already exists:
- Same stack, same thresholds → leave it **untouched** and say so.
- Thresholds moved → update only those values, preserve every human edit elsewhere, and show the diff.
- 🔴 **Never overwrite a pipeline a human has edited.** Show the drift and ask.
- 🔴 **Any edit to a pinned tool version in an already-committed workflow — by a human, by
  Dependabot/Renovate, or by any later AIRE cycle — MUST re-run `validate-pipeline.{sh,ps1}`
  (specifically its V25 combined-resolution check, Section 4.0.1) before that edit is pushed.**
  A single pin looking fine in isolation says nothing about whether it still coexists with every
  other pin in the same `pip install`/`npm install` line — that is exactly how `pip-audit` moving
  from `2.9.0` to `2.10.1` broke a working `semgrep==1.127.0` pin with no code change on either
  side. Bumping one pin without re-resolving the whole set is a generation-time defect regardless of
  who or what made the edit.

---

### 2.1 🔴 WHERE THE PIPELINE LIVES — the cycle branch, never pushed to base

**GitHub runs a `pull_request` workflow from the HEAD branch, not the base.** The pipeline therefore
only needs to exist on the branch raising the PR — which is always a cycle branch or something cut
from one.

| PR | Head branch has it because | CI runs |
|---|---|---|
| story → epic | story branches are cut from the epic branch |  |
| ve → epic / bug / enh | cut from the cycle branch |  |
| epic → main | the epic cycle created it |  |
| bug → main | the bug cycle created it on the bug branch |  |
| enh → main | the enhancement cycle created it on the enhancement branch |  |

**Base gets it for free.** `.github/workflows/agentic-eval-pipeline.yml` and `tests/.evals/**` are part of
the cycle's own PR diff, so merging the cycle lands them on base. The next cycle branches from base,
finds them present, and leaves them alone (`common/directory-structure.md` — Artifact Ownership).

🔴 **Do NOT push these files directly to base, and do NOT raise a separate `[CI]` PR for them.** They
ride in with the cycle that created them. There is no bootstrap-on-base step.

#### 2.1.1 Generate at the STOP CHECKPOINT, commit with the cycle

1. Check whether each artifact already exists (on this branch, or inherited from base).
2. **Present → leave it completely alone.** Never regenerate, never diff-and-update. 🔴 **One narrow
   exception**: `tests/.evals/ci-manifest.d/` is append-a-new-file territory (Section 4.0f) — a work
   unit ADDS its own new fragment there; it does not "leave it alone" the way it must for every other
   file this rule covers, and it never edits an existing fragment either.
3. **Missing → generate it deterministically** from its canonical template, and commit it alongside
   the cycle's other STOP CHECKPOINT artifacts.
4. Announce what was created versus inherited, and name the branch-protection check the user may want
   to require (see below).
5. Continue. 🔴 **Never block the cycle on any of this.**

#### 2.1.2 The self-repair job no longer constrains where the workflow lives

The historical reason for seeding base was `anthropics/claude-code-action`, which refuses to run with
elevated permissions unless the workflow file is byte-identical to the default branch's copy:

```
Workflow validation failed. The workflow file must exist and have identical
content to the version on the repository's default branch.
```

🔴 **That constraint no longer applies**: self-repair runs the **Claude Code CLI** from
`tests/.evals/scripts/auto-fix-agent.*` (Section 6), which is an ordinary `run:` step with no such guard. It
works on the very PR that introduces the pipeline. If a team overrides this to use the marketplace
action, that guard returns and they must land the workflow on the default branch first — say so, and
do not let it block the cycle.

#### 2.1.3 Enforcement is a repository setting

Requiring CI to pass before merge is **GitHub branch protection** with the verify job's name as a
required status check. That is configured once on the repository and cannot be carried by any branch.
Name the job in the completion announcement so the user can enable it; 🔴 never attempt to change
repository settings automatically.

---

## 3. Stack detection → real commands

🔴 **This section populates the `ci` manifest in `tests/.evals/config.json` — it does not describe YAML typed
by hand.** Every command resolved below becomes a manifest value inside one entry of `ci.roots[]`
(`installCommands`, `tools`, `coverageCommand`, … — `common/eval-framework.md` Section 1.1), which
`templates/ci/TEMPLATE-MANIFEST.md`'s slot table then substitutes into the copied
`agentic-eval-pipeline.yml.template` (Section 1), one `cd`+verify+command block per root (Section 4.0d).
Resolving a command wrong here still means a wrong value, but resolving it into the manifest — not into
hand-typed YAML — is what `validate-pipeline.{sh,ps1}` (Section 4.0) can actually check before commit.

**A single-root repo produces one entry in `ci.roots[]`, with `root: "."`. A monorepo — every package
root recorded under `## Code Root` (`common/directory-structure.md`) — produces one entry per package,
each with its own `root`, `stack`, `markerFile`, and resolved commands.** `root` is always the SAME
value already recorded for that package under `## Code Root`; this section never re-derives a different
one. Detect the stack **within each root**, then resolve each stage's command from what that root
actually provides. Resolve in order: **repo script → direct tool invocation → `N/A` with a stated reason.**

### 3.0 🔴 GREENFIELD — `ci.manifestState`, and what to do when there is nothing to detect

At the STOP CHECKPOINT of a greenfield cycle there is no `package.json`, no lockfile, no test runner, no
source root, no coverage tool — the repo provides nothing to resolve *from*. Every rule in this section
is unsatisfiable, and failing silently in either direction is the actual risk:

- The only input left for `ci.roots[].installCommands`/`tools`/`buildCommand` is
  `spec/plans/architecture.md`, which is a **plan**, not a repo. Resolving from it is precisely the
  invented-command failure this whole section exists to prevent, made undetectable because there is no
  repo state left to contradict the invention. 🔴 **Never populate a stack value from
  `architecture.md`. A planned stack is not a detected stack.**
- The npm lockfile check (above) resolves to "none found → `npm install`" on a repo that will have a
  committed lockfile by story 1 — silently locking the pipeline onto the non-reproducible install command
  forever unless something later corrects it.
- **V3 passes vacuously.** "Every referenced script/target exists" is trivially true when the manifest
  references nothing real — the strongest generation-time check in this framework reports green on
  exactly the case it was written to catch.

**The fix — `ci.manifestState` (`common/eval-framework.md` Section 1), set honestly:**

| State | When | What gets written |
|---|---|---|
| `"unresolved"` | No stack is demonstrably present anywhere in the repo at generation time | `ci.roots` is written as an **empty array** — not omitted, not guessed. Every **structural** fact (`baseBranch`, `integrationBranchPrefixes`, `gates`) is written for real; it is only the **stack** facts that are honestly empty |
| `"resolved"` | At least one root has a demonstrable stack | `ci.roots` has one entry per detected root, each fully resolved per this section |

On `"unresolved"`, the generated pipeline still parses, still triggers, still authenticates, still runs
its fixed structural steps — every install/build/coverage block simply has nothing to iterate, so it
resolves to an explicit no-op per Section 4.0d.1's own rule for a root with nothing to run
("an unresolvable stage is never silently omitted", applied here to the "there is no root at all" case).
Gates scoped to `ci.roots[]` report `N/A` with the reason `"manifestState: unresolved — no stack in the
merged manifest"` — never a silent pass and never a fabricated `PASS`. `manifestState` transitions
`"unresolved"` → `"resolved"` the moment the first work unit's own verified run establishes a real root
(reconciliation, Section 4.0f below) — never guessed forward from a plan.

#### 3.0.1 Validation — V30

**V30 — no untraceable manifest value.** Every non-empty value in `ci.roots[].installCommands`,
`ci.roots[].tools`, `ci.roots[].coverageCommand`, `ci.roots[].buildCommand`, `ci.roots[].sourcePaths`,
and `ci.roots[].testPaths` must be traceable to a file that exists in the repo at generation time (the script it
invokes, the manifest that declares it, the lockfile it implies) — on a repo in ANY state, greenfield or
brownfield. A value with no such file is a generation defect and blocks the commit. This is what makes
the `"unresolved"` rule enforceable rather than advisory: a manifest cannot claim `manifestState:
"resolved"` while carrying a value nothing in the repo actually backs.

| Stage need | JS/TS | Python | Java/Kotlin | Go | .NET |
|---|---|---|---|---|---|
| Install | `npm ci` / `pnpm i --frozen-lockfile` / `yarn --immutable` | `pip install -r requirements.txt` / `poetry install` / `uv sync` | `mvn -B -ntp install -DskipTests` / `gradle build -x test` | `go mod download` | `dotnet restore` |
🔴 **Before emitting `npm ci`, verify the repo has a committed lockfile, check .gitignore of the project make sure package-lock.json or any lockfile is not on .gitignore.** `npm ci` hard-fails
with `EUSAGE` when no lockfile exists. Resolve the install command by reading the repo:

| Lockfile found in repo | Emit |
|---|---|
| `package-lock.json` | `npm ci` |
| `yarn.lock` | `yarn --immutable` |
| `pnpm-lock.yaml` | `pnpm i --frozen-lockfile` |
| **None found** | `npm install` — note in the announcement that no lockfile is committed; installs will be non-reproducible until one is added |

List the lockfile check in V3 (Section 4.0.1): confirm the lockfile the install command
expects was found in the repo before emitting that command.
| Compile/Build | `npm run build` (repo script) / `tsc --noEmit` (no build script) | `N/A` — no compile step | `mvn -B -ntp compile` / `gradle compileJava` | `go build ./...` | `dotnet build` |

🔴 **Compilation is a prerequisite, not a gate.** It runs once, right after `Install dependencies`,
BEFORE Stage 1 (static evals) and Stage 2 (unit + coverage) — static analysis and unit tests on code
that doesn't build are meaningless. The fixed `Compile / build` step (calling
`tests/.evals/scripts/ci-manifest-runner.sh build`, Section 4.0d.1) is byte-identical in **both** the
verify job and the self-repair job — there is no longer a separate slot-equality requirement to track
(Section 3.1 is now structural). It is **not** wrapped in `continue-on-error` and does **not** appear in
the Verdict tally — like `Install eval tools`, a failure here stops the job outright, because nothing
downstream can produce a meaningful result. Resolve in the same order as everything else: repo script → direct
tool invocation → a stack that genuinely has no compile step resolves to an **explicit** no-op
(`run: echo "No compile/build step for this stack (<reason>)"`) — never a silently omitted step
(Section 3's own rule for an unresolvable stage).
| Lint (D1) | `eslint`/`biome` | `ruff check` | `checkstyle`/`spotless:check` | `golangci-lint run` | `dotnet format --verify-no-changes` |
| Types (D2) | `tsc --noEmit` | `mypy` | compiler | `go vet ./...` | build |
| SAST (D3) | `semgrep --config auto` (stack-agnostic) | + `bandit` | + `spotbugs` | + `gosec` | + `security-scan` |
| Deps (D4) | `npm audit --json` | `pip-audit` | `mvn dependency-check:check` | `osv-scanner` | `dotnet list package --vulnerable` |
| Licences (D5) | `license-checker` | `pip-licenses` | `license-maven-plugin` | `go-licenses` | `nuget-license` |
| Complexity (D6) | eslint `complexity` | `radon cc` | PMD | `gocyclo` | analyzers |
| Secrets (D7) | `gitleaks detect` — **prefer the binary/container over `gitleaks/gitleaks-action`** (Section 4.0.3) | — | — | — | — |
| Unit + coverage (and the `coverageFormat` it emits) | `jest --coverage` / `vitest run --coverage` -> **lcov** | `pytest --cov` -> **cobertura** | `mvn test jacoco:report` -> **jacoco** (🔴 NOT cobertura — a different XML schema) | `go test -coverprofile` -> **gocover** | `dotnet test --collect:"XPlat Code Coverage"` -> **cobertura** |
| **Behavioural (Gherkin)** — always invoked via `tests/.evals/behavior/run.sh <tier>` inside Podman | `cucumber-js` | `pytest-bdd` | `mvn verify -Dcucumber` | `godog run` | `reqnroll` |
| **Playwright E2E (headless, CI trust gate)** — see Section 3.0g | `npx playwright test tests/e2e/` (only when `ci.playwright.enabled`) | | | | |

🔴 A stage with no resolvable command is emitted as an explicit **skipped step with a `# reason:`
comment**, never silently dropped and never faked with `echo ok`.

### 3.0e 🔴 CHOOSING `markerFile` — and what to do when a root genuinely has none

The schema lists candidate markers and Section 4.0d verifies the chosen one exists, but the CHOICE
itself needs a rule, because `markerFile` is what proves a recorded root still points at a real project
of the declared stack after a rename or move.

**Pick the file that DEFINES the project for that stack — the one whose absence means "this is no
longer a `<stack>` project here":**

| Stack | `markerFile` | Notes |
|---|---|---|
| node | `package.json` | never a lockfile — a lockfile can live at a workspace root instead |
| python | `pyproject.toml` → `setup.py` → `requirements.txt` | first one present, in that order |
| java | `pom.xml` → `build.gradle` / `build.gradle.kts` | per module, not the aggregator |
| go | `go.mod` | never `go.work` — that is the workspace, not the root |
| dotnet | `*.csproj` → `*.sln` | a glob is legal and expected here |
| rust | `Cargo.toml` | |
| ruby | `Gemfile` | |
| php | `composer.json` | |

🔴 **A glob marker is legal** (`*.csproj`); `lib-manifest.*` expands it, and a marker containing a
space is handled literally.

**A root with genuinely no marker** — a plain C/CMake tree, a shell-script repo, a docs root — records
`markerFile: ""`. That is explicitly allowed and skips the verification step, but 🔴 **say so in the
manifest rather than omitting the field silently**: an empty marker means "this stack has no defining
file", not "we did not look". A root whose stack HAS a conventional marker must never record `""` —
that silently disables the one check that catches a moved or renamed module.

### 3.0d 🔴 RESOLVE `dependsOn` FOR EVERY ROOT IN A MULTI-ROOT REPO

Diff-scoping skips a root the PR did not touch. That is only sound for **independent** roots — and a
monorepo's roots are, by definition, not independent. Without `dependsOn`, a PR changing only a shared
module skips every module that consumes it: those modules are never compiled, their tests never run,
their D-gates report `N/A`, and the verdict is **PASS** on a change that breaks them.

**Resolve each root's `dependsOn` from the repo's OWN declaration — never guess, never infer from
directory nesting:**

| Stack | Where the edge is declared |
|---|---|
| Maven | a `<dependency>` whose `groupId`/`artifactId` matches another module in this repo's `<modules>` |
| Gradle | `project(':other')` in `dependencies { }` |
| npm/pnpm/yarn | a dependency resolving to a `workspaces` member, or a `workspace:*` / `file:` / `link:` specifier |
| Go | `go.work`'s `use` list plus a `replace ./...` directive in `go.mod` |
| .NET | `<ProjectReference Include="../Other/Other.csproj" />` |
| Python | a `-e ../pkg` requirement, or `path = "../pkg"` in `pyproject.toml` |

🔴 **A multi-root manifest where every `dependsOn` is empty is a claim that no module depends on any
other.** For the repo shapes above that claim is almost always false — verify it before writing it,
because the failure is silent: `root_touched` returns false, the root is skipped, and nothing reports
that an edge was missing. A typo'd or dangling edge is caught at run time (`lib-manifest.*` raises a
Manifest defect for a `dependsOn` naming a root that does not exist), but a **missing** edge is
invisible by construction.

Single-root repos and genuinely independent packages keep `dependsOn: []` and behave exactly as before.

### 3.0a 🔴 PREFER THE REPO'S OWN BUILD-TOOL WRAPPER WHEN IT COMMITS ONE

If the repo commits `./mvnw`, `./mvnw.cmd`, `./gradlew` or `./gradlew.bat`, **resolve every Maven/Gradle
command through the wrapper**, not the bare `mvn`/`gradle` binary. A committed wrapper exists precisely
to pin the build-tool version; ignoring it means CI builds with whatever version the runner image ships,
which can differ from what every developer and the repo's own lockstep expect. Resolve
`./mvnw -B -ntp test`, never `mvn -B -ntp test`, whenever the wrapper is present. The same rule applies
to any stack that commits a version-pinning launcher.

### 3.0b 🔴 THE FIVE-COLUMN TABLE IS NOT THE LIST OF SUPPORTED STACKS

The command table below has five columns because the pipeline template carries five permanently-present
`actions/setup-*` blocks — **not** because AIRE only supports five stacks. The manifest schema itself
names `Cargo.toml`, `Gemfile` and `composer.json` as valid `markerFile` values.

For a stack outside `{node, python, java, go, dotnet}`:

1. Resolve its commands the same way as any other — repo script, then direct tool invocation.
2. **Record `ci.roots[].toolchainSetup`** with the commands that install and pin its toolchain, read
   from the repo's own pin file. `ci-manifest-runner.* toolchain` runs them.
3. If a D1–D7 gate genuinely has no tool for that stack, the gate must **ERROR**, not pass. 🔴 It is
   never an earned `N/A`: `eval-framework.md` Section 2.5.1's closed list covers "inapplicable to this
   work unit", not "we have no tool for this language". `run-static-evals.*` now checks each gate
   command's binary is on PATH and ERRORs when it is not, so a missing tool can no longer diff empty
   against empty and record PASS.
4. A root with an unknown `stack` and an empty `toolchainSetup` is a **Manifest** defect, raised by
   `read-manifest.*`. That routes it to Section 6.4's Manifest triage class — reported, never
   "repaired" by self-repair editing source to fix a toolchain pin.

### 3.0c 🔴 D5 AND D6 MUST REFERENCE THEIR THRESHOLD

`disallowedLicenses` and `maxCyclomaticComplexity` were read by **no script at all** — nine mentions
across the rule files and zero consumers — because `delta_diff`'s verdict is simply "are there new
findings versus baseline". D5 therefore failed on any newly-introduced licence rather than a
*disallowed* one, and D6 on any newly-introduced complexity finding rather than one *above the cap*.

`run-static-evals.*` now exports both into every gate command's environment:

| Variable | Source |
|---|---|
| `AIRE_DISALLOWED_LICENSES` | `thresholds.disallowedLicenses`, comma-joined |
| `AIRE_MAX_CYCLOMATIC_COMPLEXITY` | `thresholds.maxCyclomaticComplexity` |

🔴 **The resolved D5 and D6 commands MUST reference them** (e.g. `license-checker --failOn
"$AIRE_DISALLOWED_LICENSES"`, a complexity rule configured from
`$AIRE_MAX_CYCLOMATIC_COMPLEXITY`). Never copy the literal number into the command — `eval-framework.md`
Section 1 is explicit that `thresholds` is the only place a number lives, and a copied value drifts the
moment one of them changes.

### 3.0f 🔴 Playwright E2E — resolving the start command + readiness URL, and CI's trust-gate role

🔴 **CI never originates Playwright coverage — it only re-executes what the local Playwright UI
Automation Gate (`implementation/code-generation.md` Step 11d) already generated and ran.** This
subsection resolves the two facts CI needs to reproduce that run headless, and defines what "trust
gate" means operationally.

**Resolution — the first work unit that runs the Playwright gate for real writes `ci.playwright` into
`tests/.evals/config.json`** (`common/eval-framework.md` Section 1), exactly like a manifest fragment
resolves a new tool: never guessed, always read from something the repo demonstrably has.

| Field | Resolved from |
|---|---|
| `enabled` | `true` the first time a work unit's plan includes a Frontend Components Generation step and the Playwright gate actually ran (not merely planned) |
| `startCommand` | The project's OWN start script (`package.json` `"dev"`/`"start"`, a documented `Makefile` target, or the direct framework invocation) — resolved the same way as every other command in this framework: repo script → direct invocation → never invented |
| `readinessUrl` | The URL/port the story's System Under Test block already names (or the app's documented default) — the same value the local gate polled before running tests |
| `testCommand` | Defaults to `npx playwright test tests/e2e/`; a project with a non-default `testDir` or reporter convention overrides it here, once |

🔴 **CREATE IF MISSING, NEVER REGENERATE** (`common/directory-structure.md` Artifact Ownership) — once
`ci.playwright` is resolved by a work unit, every later work unit and CI both read it as-is; a project
with no UI at all simply never sets `enabled: true`, and the CI step below then reports `N/A` — never a
guessed command.

**What "trust gate" means in the generated pipeline**: the CI step (Section 4) installs Playwright +
browsers, starts the app in the background using the SAME `startCommand`, waits on the SAME
`readinessUrl`, runs the SAME `testCommand`, and tears the server down — the same specs and the same
assertions that already ran and passed locally. 🔴 **The one and only difference is the display mode**:
the local gate runs `--headed` (it is the developer's own machine, and watching the browser is the
point), while CI runs headless **because a GitHub runner has no display** — a property of the
environment, never a policy this framework applies locally. 🔴 **CI is NEVER where a Playwright scenario is written, planned,
or healed** — Planner/Generator/Healer only ever run inside the local gate (Step 11d). A CI failure on
a scenario that passed locally is therefore always a **provisioning/manifest defect** (a stale
`startCommand`, a wrong `readinessUrl`, browsers not installed) — triaged and repaired exactly like any
other CI Preflight/Attestation mismatch (`common/ci-pipeline-generation.md` Section 6.6), never a
reason to re-run the Planner or to treat the local pass as unproven.

### 3.0 🔴 THE TEST COMMAND MUST BE NO-TESTS-SAFE — resolve it, and record the runner's zero-tests code

A test runner that finds **no tests at all** exits non-zero on most stacks: **pytest exits `5`**,
**jest and vitest exit `1`**. That is not a failure — it is the correct, expected state of a greenfield
repo before its first story, and of a brownfield repo that has no suite yet. Treating it as a gate
failure is what once sent CI self-repair off to **write dummy tests** to turn the gate green: a
fabricated pass (SH-6) that then merged and became the regression baseline every later work unit is
diffed against.

**Two things are therefore required of every resolved test/coverage command:**

1. **Prefer the runner's own no-tests-is-ok flag** when it has one, so the situation never produces a
   non-zero exit in the first place: `jest --passWithNoTests`, `vitest --passWithNoTests`. Add it to the
   resolved `coverageCommand`, never to the repo's own script.
2. **Record `ci.roots[].noTestsExitCode`** for every root whose runner lacks such a flag — read from
   that runner's documented exit codes, never guessed. `ci-manifest-runner.*` compares the command's
   exit status against it and records **`N/A` — the test runner collected ZERO tests**, returning 0.

| Runner | No-tests flag | `noTestsExitCode` |
|---|---|---|
| pytest | — | `5` |
| jest / vitest | `--passWithNoTests` (preferred) | `1` |
| go test | not applicable — exits `0` with no tests | omit |
| `mvn test` / `gradle test` | not applicable — exits `0` | omit |
| `dotnet test` | not applicable — exits `0` | omit |

🔴 **This can never hide a missing test.** `run-static-evals.*`'s `coverage_delta()` independently
enforces `unitTestCoverageMin` on the **changed** files and records **ERROR** (*"no coverage data found
for any changed file"*) when a changed file has no coverage. A work unit that ships code without tests
still fails — on the gate that can actually tell, with a diff to point at. What is suppressed here is
only the vacuous case: nothing changed under this root, or the project genuinely has no suite yet.

🔴 **Never satisfy this by lowering `unitTestCoverageMin`, by pointing the command at a directory known
to contain tests, or by committing a placeholder test.** The correct resolution is a flag or an exit
code, both of which are facts about the runner, not judgements about the repo.

### 3.1 🔴 Tool installation — the self-repair job needs the SAME tools as the verify job

The self-repair job runs on a **fresh runner** — it has no tools from the verify job. If the agent
fixes the code but cannot re-run the evals (because semgrep / mypy / the test runner is not
installed), it pushes an unverified commit. That commit fails the next CI run and wastes a retry.

**Rule**: the self-repair job must install the **same runtimes, project dependencies, and eval tools**
as the verify job. Generate the install steps identically in both jobs — or extract them into a
**composite action** / **reusable workflow** so they cannot drift.

**Complete tool checklist** (install in the self-repair job exactly as in the verify job):

| Category | What to install | Why self-repair needs it |
|---|---|---|
| **Language runtimes** | Node (`actions/setup-node`), Python (`actions/setup-python`), Go, Java — whichever the project uses | The fix may need to compile or run tests |
| **Project dependencies** | `npm ci` / `pip install -r requirements.txt` / `mvn install -DskipTests` — the same command the verify job runs | The tests import the project's own packages |
| **Test runners** | `pytest`, `jest`, `vitest`, `pytest-bdd`, `cucumber-js` — whatever the verify job uses | Rule 4 of Section 6.0.1: re-run evals before committing |
| **Static analysis tools** | `semgrep`, `pip-audit` / `npm audit`, `gitleaks`, `mypy` / `tsc`, the linter | Re-running `run-static-evals.*` requires them |
| **Coverage tools** | `pytest-cov`, `c8` / `istanbul`, `jacoco` | Coverage gate re-verification |
| **Behavioural test infra** | `podman`, the Gherkin runner | B1/B2 re-verification when the fix touches behaviour |
| **Claude Code CLI** | `npm i -g @anthropic-ai/claude-code` | The repair agent itself |

🔴 **If a tool fails to install, exit non-zero immediately.** Do not proceed to repair with a partial
toolset — the re-verification step will fail or skip silently, producing an unverified commit.

### 3.2 🔴 Verify job install steps — no gate may run without its tool

The verify job must install every tool it needs BEFORE any gate step runs. Generate the install
section by reading the project's stack (Section 3), then:

1. **Emit setup actions** for every runtime the project uses (`actions/setup-node`,
   `actions/setup-python`, `actions/setup-java`, `actions/setup-go`). Pin the version to the
   project's own `.node-version` / `pyproject.toml [project] requires-python` / `go.mod` go
   directive. If no pin exists, use the latest LTS.
2. **Emit project dependency install** — the exact command the project uses (`npm ci`, `pip install
   -r requirements.txt`, `poetry install`, `mvn -B install -DskipTests`). Read it from the
   project's `package.json` scripts, `Makefile`, `pyproject.toml`, or build file.
3. **Emit eval tool install** — every tool from the Section 3 table that this stack needs. Combine
   related tools into a single step to reduce job time:
   ```yaml
   - name: "Install eval tools"
     run: |
       pip install semgrep pip-audit
       gitleaks_version="8.21.2"
       curl -sSfL "https://github.com/gitleaks/gitleaks/releases/download/v${gitleaks_version}/gitleaks_${gitleaks_version}_linux_x64.tar.gz" | tar xz -C /usr/local/bin gitleaks
       semgrep --version
       gitleaks version
       pip-audit --version
   ```
  🔴 **Never rely on the project's `requirements-dev.txt`, `package.json`, or any project
dependency file to supply eval tools.** Install ALL eval tools explicitly with pinned
versions in this step, even if they already appear in project deps. Project maintainers
can drop a tool from their deps without breaking the app — which silently removes a CI
gate. The explicit install is the only guarantee.

**Complete "Install eval tools" step for a Python project:**
```yaml
- name: "Install eval tools"
  run: |
    pip install "semgrep==1.127.0" "pip-audit==2.9.0" "pip-licenses==5.0.0" "radon==6.0.1"
    gitleaks_version="8.21.2"
    curl -sSfL "https://github.com/gitleaks/gitleaks/releases/download/v${gitleaks_version}/gitleaks_${gitleaks_version}_linux_x64.tar.gz" \
      | tar xz -C /usr/local/bin gitleaks
    pip check            || { echo "pip dependency graph is broken after eval-tool install"; exit 1; }
    semgrep --version    || { echo "semgrep not found after install";     exit 1; }
    gitleaks version     || { echo "gitleaks not found after install";    exit 1; }
    pip-audit --version  || { echo "pip-audit not found after install";   exit 1; }
    pip-licenses --version || { echo "pip-licenses not found after install"; exit 1; }
    radon --version      || { echo "radon not found after install";       exit 1; }
```

#### 3.2.1 🔴 An exact tool pin can still break later — pin the ecosystem floor too, and prove it in a clean room

Pinning the tool (`semgrep==1.127.0`) is not the whole dependency graph. Its own transitive
dependencies are frequently **unpinned upstream**, so pip is free to resolve them to whatever is
newest on the day the job runs — including packages the tool's old code still imports directly.
**Observed failure**: `semgrep==1.127.0` pins `opentelemetry-instrumentation-requests~=0.46b0`, which
imports `pkg_resources` from `setuptools`; nothing pins `setuptools`, pip resolved the newest release,
and that release no longer ships `pkg_resources` — the install succeeded, but `semgrep --version`
crashed with `ModuleNotFoundError: No module named 'pkg_resources'`. Same tool pin, same code,
different result a week later — purely because an unrelated package moved forward.

**Rules:**

1. Run **V23/V24** (Section 4.0.1a) — the clean-room dry-run plus `pip check` — before committing any
   pinned-tool install step. This is what surfaces the drift while it is still cheap to fix, instead of
   on the team's first real PR.
2. If the dry-run or `pip check` reveals a transitive/ecosystem conflict, **pin the offending
   ecosystem package explicitly**, to the newest version verified compatible with the pinned tool in
   that same clean-room run, with a comment naming why:
   ```yaml
   run: |
     # setuptools>=<broken-version> drops pkg_resources, which semgrep==1.127.0's own
     # opentelemetry-instrumentation==0.46b0 dependency still imports directly.
     # Verified in the clean-room dry-run on <date>; re-check when bumping semgrep.
     pip install "setuptools<<verified-safe-upper-bound>>"
     pip install "semgrep==1.127.0" ...
   ```
   🔴 Never guess the bound from memory — read it off the clean-room run that actually reproduced the
   failure, and never hardcode a version number copied from this document (it will itself go stale).
3. Treat an aging exact pin as a liability, not a one-time decision: when a pinned tool has not been
   bumped in a long time relative to the project's release cadence, re-run the clean-room dry-run
   against it before trusting it again, even if nothing else in the pipeline changed.

**Complete "Install eval tools" step for a JS/TS project:**
```yaml
- name: "Install eval tools"
  run: |
    npm install -g license-checker
    gitleaks_version="8.21.2"
    curl -sSfL "https://github.com/gitleaks/gitleaks/releases/download/v${gitleaks_version}/gitleaks_${gitleaks_version}_linux_x64.tar.gz" \
      | tar xz -C /usr/local/bin gitleaks
    command -v license-checker >/dev/null 2>&1 || { echo "license-checker not found after install"; exit 1; }
    gitleaks version                            || { echo "gitleaks not found after install";         exit 1; }
```

🔴 **Not every tool's `--version` is a trustworthy success signal.** `license-checker` prints its
real version to stdout but still exits non-zero on `--version` — a confirmed, reproduced quirk in
that specific package, not a framework bug. Verifying it with `<tool> --version || exit 1` makes a
correctly-installed tool look broken. When a tool is known to behave this way, verify with
`command -v <tool>` (existence on PATH) instead of invoking it. `license-checker` is the one
confirmed case today; treat any other tool that exits non-zero despite printing correct version
output the same way.

For a mixed Python + JS project, combine both blocks into one step.

🔴 Every version check must be preceded by its install command in the same step.
A version check with no preceding install is a generation defect — it passes on runners
that happen to have the tool pre-installed and breaks silently when the runner image changes.

4. **Verify every tool after installation** — append a version check to each install block. The
   check must exit non-zero if the binary is not in PATH:
   ```yaml
   - name: "Install and verify linter"
     run: |
       npm install -g eslint
       eslint --version || { echo "eslint not found after install"; exit 1; }
   ```

🔴 **No install step may use `|| true` or `continue-on-error: true`.** A failed install must abort
the job immediately. Running gates without their tools produces partial or empty results that look
like passes.

🔴 **Pin tool versions.** An unpinned `pip install semgrep` may install a breaking update between
runs, causing a gate that passed yesterday to fail today for the same code. Pin to a known-working
version and update deliberately.

🔴 **The `curl` install pattern for gitleaks (and similar binaries) must pin the version in the URL
and verify the binary after extraction.** A 404 from a stale URL exits non-zero immediately — the
secret scanner was not installed. Never fall through to the gate with a missing binary.

🔴 **These commands are what `run-static-evals.*` invokes internally — they are NOT pasted into the
workflow as standalone steps.** The YAML calls the script; the script runs the tool twice (base and
HEAD) and diffs. Emitting the raw command as a CI step re-introduces the whole-tree verdict bug
(Section 4.0b).

---

## 4. Pipeline shape — four stages plus self-repair

The generated workflow mirrors `common/eval-framework.md` and the local gate order exactly. **CI does
not introduce new gates and does not relax any.** It is the same contract, re-verified where a human
can see it.

```
on: pull_request → [ <base-branch>, 'epic/**', 'bug/**', 'enh/**' ]   (Section 4.0a)
    push        → [ <base-branch> ]        workflow_dispatch

job: verify-and-evaluate
  ├── Stage 1  Deterministic       tests/.evals/scripts/run-static-evals.sh <base-sha>
  │                                D1 lint · D2 types · D3 SAST(+SonarQube) · D4 deps · D5 licences
  │                                D6 complexity · D7 secrets
  │                                🔴 DELTA-SCOPED vs the base ref — never a whole-tree verdict
  ├── Stage 2  Behavioural         unit tests + coverage ≥ unitTestCoverageMin, then Gherkin
  │                                in Podman — B1 (this unit) · B2 (every other feature file)
  │                                · B3 (whole epic) only on a PR into the base branch, then
  │                                Playwright E2E headless — TRUST GATE, re-executes the local
  │                                Step 11d run, never originates it — N/A when ci.playwright.enabled
  │                                is not true (Section 3.0f)
  ├── Stage 3  Semantic            J1 architecture · J2 security (OWASP) vs tests/.evals/rubrics/*
  │                                BLOCKING at the config minimums
  ├── SonarQube               LAST gate step · if: always() · continue-on-error
  │                                one input to the verdict, never a kill switch
  ├── Verdict                 🔴 the ONLY step that fails the job — tallies every
  │                                gate's outcome (Section 4.0c)
  └── Stage 4  Scorecard           if: always() — publish eval-summary to the PR + job summary

  🔴 EVERY gate step: id + continue-on-error. NEVER `|| true` (Section 4.0c).

job: self-repair          (needs: verify-and-evaluate, if: failure())
  └── Claude Code fixes the failure and pushes a commit   — max retryLimitForSelfRepair attempts
```

### 4.0 🔴 VALIDATION GATE — never commit a pipeline that cannot run

A generated workflow that fails to parse is worse than no workflow: every gate it was supposed to
enforce silently does not run, and the PR looks merely "red" rather than "unverified".

**Validate BEFORE committing. A pipeline that fails any check below is not committed — it is fixed.**

#### 4.0.1 The checks, in order

| # | Check | How |
|---|---|---|
| V1 | **YAML parses** | `python -c "import yaml,sys;yaml.safe_load(open('.github/workflows/agentic-eval-pipeline.yml'))"` — or `yq e . <file> >/dev/null`, or any available parser |
| V2 | **Valid GitHub Actions schema** | `actionlint` when available (`command -v actionlint`). It catches expression errors, bad `needs:`, unknown contexts — things a YAML parser cannot see |
| V3 | **Every referenced script/target exists** | For each `npm run X` / `make X` / `mvn X`, confirm X is defined in the repo (Section 1). A command that does not exist fails on the first run. Also confirm the lockfile the emitted install command expects (`package-lock.json` for `npm ci`, `yarn.lock` for `yarn --immutable`, `pnpm-lock.yaml` for `pnpm i --frozen-lockfile`) was found in the repo before that command was emitted (Section 3) |
| V4 | **Every referenced file exists** | `tests/.evals/config.json`, `tests/.evals/rubrics/*`, `tests/.evals/behavior/run.sh`, `sonar-project.properties` when the Sonar steps are active |
| V5 | **Every referenced secret is named in the announcement** | So the user knows what to add. A step reading an unlisted secret is a generation defect |
| V6 | **Every action's required `permissions:` are declared** | Cross-check each `uses:` against Section 4.0.3. A missing scope fails only at runtime, so a parser and `actionlint` both pass a workflow that cannot work — this check is the only thing that catches it before the first run |
| V7 | **Stage 1 is delta-scoped, against a real merge-base** | 🔴 No bare whole-tree command with `--error`/`--exit-code 1`/`--strict`. Every D1–D7 step either calls `tests/.evals/scripts/run-static-evals.*` or uses the tool's native baseline flag (Section 4.0b). A blunt command passes V1–V6 and still fails every future PR on pre-existing debt. 🔴 ALSO: the delta base passed to `run-static-evals.*`/`auto-fix-agent.*` is `git merge-base <base-branch-sha> HEAD` — never the raw `github.event.pull_request.base.sha` — in **both** the verify job's "Resolve base SHA" step and the self-repair job's own copy of it. A base ref that is not a genuine common ancestor of HEAD is a generation defect (Section 4.0b.1) |
| V8 | **Step failure is isolated** | Every gate step has `id:` + `continue-on-error: true`, no `\|\| true`, exactly one Verdict step tallies them all, and Sonar is last with `if: always()` (Section 4.0c). A pipeline failing this either aborts on the first failure or cannot fail at all — both pass V1–V7 |
| V9 | **No stub can pass** | 🔴 Prove each generated script can FAIL. Run `run-static-evals` and `run-evals` once against a deliberately broken input (an injected lint error, a rubric criterion set to fail) and confirm a non-zero exit. A script that returns PASS or `N/A` unconditionally is the worst defect this generator produces — it removes a gate while looking healthy (Section 5.0). Also grep the scripts for hardcoded `"status": "PASS"` / `"N/A"` literals not derived from a real result |
| V10 | **Trigger covers every integration branch** | The `pull_request` filter names the resolved base branch AND `epic/**`, `bug/**`, `enh/**` (Section 4.0a). A filter of just `[main]` skips every story PR — they merge with no checks at all, and nothing looks wrong |
| V11 | **`EVAL_KEY` resolves to the evidence key, not the branch name** | The `auto-fix-agent.*` script must find `eval.json` at the same path the verify job wrote it. If `EVAL_KEY` is set to `github.head_ref`, the self-repair job will search the wrong directory, find nothing, and exit 0 — hiding a real failure behind a green job (Section 6.0.1 rule 1) |
| V12 | **Every directory the scripts write to is created first** | Grep every script for file writes and confirm a `mkdir -p` precedes each one. A missing directory aborts the script before it reaches the repair logic (Section 6.0.1 rule 2) |
| V13 | **Self-repair re-runs evals before committing** | The `auto-fix-agent.*` script must invoke `run-static-evals.*` and `run-evals.*` after the fix and before the commit, and exit non-zero if they still fail. A commit that does not re-verify wastes a retry attempt (Section 6.0.1 rule 4) |
| V14 | **No `# GENERATE:` or `<placeholder>` comments remain** | Grep the committed YAML for `GENERATE:`, `TODO:`, `PLACEHOLDER`, and angle-bracket placeholders like `<base-branch>`. Any hit means the generator left unresolved instructions in the file |
| V15 | **Verify job uploads eval artifacts** | The verify job must have an `actions/upload-artifact` step that uploads `eval.json`, `eval-summary.md`, and the `static/` + `judge/` evidence directories. The self-repair job's `actions/download-artifact` depends on this — without the upload, self-repair has no `eval.json` and exits 0 on a real failure (Section 6.0.1 rule 3) |
| V16 | **Every tool is verified after installation** | Each install step in the verify job must be followed by a version check (`semgrep --version`, `gitleaks version`, `mypy --version`, etc.). A tool that installs but cannot run crashes mid-gate. In the generated YAML, combine the install and verify in the same `run:` block |
| V17 | **Evidence round trip** | Run each script once; every artifact the path contract declares must exist at the declared path, and each consumer must read the path it was written to (Section 5.3.4). 🔴 A write/read mismatch passes V1–V16 completely — YAML parses, scripts exist, job goes green — while J1/J2 report `N/A` forever |
| V18 | **Every failing gate reaches the scorecard AND the brief** | Force each gate to fail in turn; confirm it appears in `eval.json`'s `gates` block, in `tests/.evals/_run/failed-gates.txt`, and that `verdict` matches the job result. 🔴 A gate that fails the build while `eval.json` says `PASS` — SonarQube being the observed case — leaves self-repair with nothing to act on (Section 4.0c.3) |
| V19 | **Self-repair never exits 0 without repairing** | Run `auto-fix-agent.*` with its inputs deliberately removed. It must exit **non-zero** naming what was missing — never exit 0 and never reclassify its own missing input as an "infrastructure failure" of the build (Section 6.5) |
| V20 | **No deferred-setup `N/A`** | Grep every generated script and its output for `N/A` reasons containing "yet", "TODO", "not wired", "not bootstrapped", "not installed", "not enabled", "pending". Each is **ERROR**, not `N/A` (`common/eval-framework.md` Section 2.4.2). Also assert the log and `eval.json` agree per gate, and that `overall` discloses `checksRun`/`checksTotal` |
| V21 | **Tool install is retried, with a container fallback** | Every install step works the Section 2.4.1 chain — 3 attempts per rung, ending at an OCI image run through Podman — and **halts** rather than degrading to `N/A`. 🔴 A gate recorded `N/A` for a missing tool without the container rung attempted is a bootstrap failure |
| V22 | **Every eval tool verified in "Install eval tools" is also installed in the same step, above the check** | Read the "Install eval tools" step in both `verify-and-evaluate` and `self-repair`. For every line that runs a version check — any command ending in `--version`, `version`, `-v`, or followed by `\|\| { echo "... not found"` — confirm an install command for that same binary appears **earlier in the same step** (`pip install <tool>==...`, `npm install -g <tool>`, `go install <pkg>@<version>`, `dotnet tool install --global <tool>`, `curl ... \| tar xz -C /usr/local/bin <tool>`, or equivalent). A version check with no preceding install in the same step is a generation defect regardless of stack — it passes only when the tool happens to be pre-installed on the runner image, which is not guaranteed and changes without notice. Also confirm that for Go and .NET tools, the tool binary directory (`$(go env GOPATH)/bin`, `~/.dotnet/tools`) is added to `$GITHUB_PATH` before the first version check that needs it. |
| V23 | **Pinned tool installs resolve cleanly in a runner-matching, clean-room environment** | An exact pin (`semgrep==1.127.0`) that was known-working when chosen can still break later, purely because an **unpinned transitive/ecosystem package** (`setuptools`, `pip` itself, a shared build backend) resolved to a newer version between then and now and dropped something the old pin's dependency chain imports at runtime (observed: `opentelemetry-instrumentation==0.46b0`, pinned transitively by `semgrep==1.127.0`, importing `pkg_resources`, which current `setuptools` no longer ships). `--version` checks (V16/V22) catch this only if run in an environment that actually reproduces the drift — see Section 4.0.1a |
| V24 | **`pip check` (or the stack's equivalent dependency-graph check) is run and is clean after every Python/Node/etc. eval-tool install step** | `pip check` fails loudly on a broken/incompatible dependency graph, including cases where a `--version` invocation of one tool happens not to exercise the broken import path. Run it immediately after the install block, before any version checks, in both the verify job and the self-repair job |
| V25 | **The pinned "Install eval tools" set resolves together, as a whole, not tool-by-tool** | `pip install --dry-run` (or the stack equivalent) against the exact combined install line. A pin that is fine in isolation can still conflict with another pin in the same install once their unpinned transitive dependencies are resolved together (Section 3.2.1, Section 2 line 52). Implemented in `validate-pipeline.{sh,ps1}` |
| V26 | **`CLAUDE_REPAIR_INVOCATION` and `CLAUDE_JUDGE_INVOCATION` are resolved, non-bare `claude` calls** | Grep both markers in `auto-fix-agent.*` and `run-evals.*` for a bare `claude` with no flags — headless/permission flags must have been resolved at generation time per Section 6.0, never left for the runner to negotiate interactively. Implemented in `validate-pipeline.{sh,ps1}` |
| V27 | **Structural fidelity to `agentic-eval-pipeline.yml.template`** | After `${SLOT}` substitution, diff the committed `agentic-eval-pipeline.yml`'s step *names* and job *ids* against the template's fixed text (everything outside a `${SLOT}`). Any step present in the committed file with a name absent from the template, any template step missing from the committed file, or any `name:` override not defined by the template itself, fails V27 and blocks the commit. This turns "the model quietly re-authored the YAML instead of copying it" from an undetectable drift into a hard generation-time failure |
| V28 | **Every `ci.roots[]` command runs from a verified working directory** | Post-#7a: a ONE-TIME structural check that the committed `tests/.evals/scripts/ci-manifest-runner.sh` calls `resolve_and_verify_root` (defined in `lib-manifest.sh`) before running any root's command — Section 4.0d.1. There is no per-root generated YAML text left to scan; a copy of the fixed script missing this call is the defect |
| V29 | **Diff-scoped execution on every root** | Post-#7a: a ONE-TIME structural check that `ci-manifest-runner.sh` calls `root_touched` (defined in `lib-manifest.sh`) before running any root's command — Section 4.0g. A copy missing this call would run every root's command unconditionally on every PR, paying for every stack the manifest has ever touched |
| V30 | **No untraceable manifest value** | Every non-empty value in `ci.roots[].installCommands`/`tools`/`coverageCommand`/`buildCommand`/`sourcePaths`/`testPaths` traces to a real file in the repo at generation time — Section 3.0.1. What makes greenfield's `manifestState: "unresolved"` enforceable instead of advisory |
| V31 | **CI purges inherited evidence and resolves by key, never by search** | The verify job has a `Purge inherited evidence` step before any gate; the self-repair job has its own `Resolve EVAL_KEY` step and passes `EVAL_KEY` to `auto-fix-agent.*`; no script resolves an evidence file by `find`/recursive-search where an `EVAL_KEY`-addressed path is available — Section 4.0e |
| V32 | **The Manifest triage class is WIRED, not just documented** | `auto-fix-agent.*` reads `tests/.evals/_run/manifest-defects.txt` and exits non-zero without repairing when it is non-empty, and it does so **before** the retry counter is written. 🔴 Section 6.4 described this class for a release while three scripts emitted `MANIFEST DEFECT` and **nothing consumed it** — a documented triage class with no consumer is the same defect as a documented gate with no step |
| V33 | **Self-repair's scope is ENFORCED, not merely instructed** | `auto-fix-agent.*` compares every path it touched (committed **and** working-tree) against its scope and aborts **before the push** on a violation: on a `ci/epic-smoke-*` head branch `src/**` and `tests/**` (outside `tests/.evals/**`) are forbidden; on a work-unit PR `.github/workflows/**`, `tests/.evals/config.json`, `tests/.evals/rubrics/**`, `tests/.evals/ci-manifest.d/**` and `spec/**` are forbidden. A prompt is guidance; this check is what makes the scope binding |
| V34 | **Every test command is no-tests-safe** | For each `ci.roots[]` entry with a `coverageCommand`, either the command carries the runner's own no-tests flag (`--passWithNoTests`) or the root declares `noTestsExitCode` (Section 3.0). A root with neither turns *"this repo has no suite yet"* into a hard gate failure — the exact condition that once produced 45 minutes of self-repair authoring dummy tests |
| V35 | **`check-test-placement.*` exists, is wired into Stage 1, and can actually fail** | `tests/.evals/scripts/check-test-placement.{sh,ps1}` (Section 4.0.7) exists, appears as its own step in the generated YAML, and — same discipline as V9 — is proven to FAIL against a deliberately misplaced fixture (a `.test.`/`.spec.` file dropped under `src/`, or under a stray `tests/<name>/` outside `tests/unit/`/`tests/api/`) before being trusted on real diffs. Also grep it for a hardcoded `"verdict": "PASS"` literal not derived from the actual scan |

🔴 **V25 and V26 were implemented in `validate-pipeline.sh`/`.ps1` before this table was kept current with
them — they exist and run today even though they were missing from this list until V27 was added
alongside them.** Keep this table and the script in lock-step from here on: a check exists in the
script if and only if it is listed here.

🔴 **If V2's tool is unavailable, say so** and record `actionlint: not available` in the announcement.
Never claim a schema check that did not run.

#### 4.0.1a 🔴 LOCAL DRY-RUN — clean-room, matching the CI runner exactly

After V1–V13 pass, **execute the generated scripts in a clean, disposable environment that matches the
CI runner** — never in the generation agent's own ambient shell.

🔴 **Why "clean-room" is non-negotiable, not a nice-to-have.** A dry-run against the ambient dev
environment can pass while the real CI run fails, because the ambient environment already has
whatever package version happened to be cached or previously installed (an older `setuptools` that
still shipped `pkg_resources`, for example). `ubuntu-latest` in GitHub Actions starts from a bare
image every time and resolves every unpinned package fresh — that is precisely the condition that
surfaces transitive-dependency drift (V23), and it is the one condition an ambient local shell cannot
reproduce.

**How to run it clean:**
- Python: a fresh `python -m venv .dryrun --clear && source .dryrun/bin/activate` (or an equivalent
  disposable interpreter) with **no pre-existing site-packages** — never the interpreter the
  generation agent itself is running under.
- Node: a fresh `npm ci`/`npm install` into a directory with no pre-existing `node_modules`.
- Any stack: prefer running the whole dry-run inside a throwaway container built from the same base
  image the workflow declares (`ubuntu-latest` ≈ `catthehacker/ubuntu:act-latest` or the project's own
  `Containerfile` when one exists), via Podman, so the resolved package graph matches the real runner.
- Delete the disposable environment after the dry-run; never let it leak into the commit.

**Steps, inside that clean environment:**

1. Run `bash tests/.evals/scripts/run-static-evals.sh "$(git merge-base HEAD origin/<base-branch>)"` and
   confirm it produces a non-empty output with real gate results — not stubs, not all-N/A.
2. Run `bash tests/.evals/scripts/run-evals.sh "$(git merge-base HEAD origin/<base-branch>)"` and confirm
   `eval.json` is written with real `gates` entries and that `eval-summary.md` is produced.
3. If either exits non-zero, **that is the correct signal** — it means the scripts work. Read the
   output to confirm the failure is a real finding, not a missing directory, a wrong path, or a
   dependency-resolution crash (V23/V24).
4. Confirm `eval.json` lives at the expected evidence path and that `EVAL_KEY` in the workflow
   resolves to the same directory name.
5. Run `pip check` (or the stack equivalent) inside the same clean environment and confirm it is
   clean — this is what V24 verifies before commit.

🔴 **Do not commit scripts that have never run in a clean, runner-matching environment.** A script
that parses, passes V1–V13, and even runs successfully against a warm ambient shell can still crash
on the very first real CI invocation for reasons that only exist in a fresh dependency resolution.
The clean-room dry-run is what catches that class of defect.

Log the dry-run results in `runtime-artifacts/audit.md` — which scripts ran, their exit codes, and whether the outputs
matched expectations.

#### 4.0.2 YAML rules that prevent the common breakages

These are the failure modes that actually occur when a model writes CI YAML. Follow them while
generating, not only while validating:

1. 🔴 **QUOTE EVERY `name:` VALUE.** A bare colon inside an unquoted scalar is the single most common
   cause of "Invalid workflow file".
   - Correct: `- name: "Stage 1: deterministic gates"`
   - Broken: `- name: Stage 1: deterministic gates`
2. 🔴 **Multi-line commands use a block scalar `|`**, never `>` and never inline. Inside `|`,
   colons, quotes and `#` are literal text and safe.
3. 🔴 **Quote any scalar containing** `: ` · `#` · a leading `*`, `&`, `!`, `%`, `@`, `` ` `` ·
   or a value that could read as a number/bool (`on`, `yes`, `1.10`).
4. 🔴 **`if:` expressions are unquoted GitHub expressions or fully quoted strings — never half.**
   `if: failure() && github.event_name == 'pull_request'`
5. 🔴 **Two-space indentation, spaces only. Never a tab.** A tab anywhere in a YAML file is a
   parse error.
6. 🔴 **No placeholder left in the file.** `<base-branch>`, `<n>`, `<runner>` are for this document —
   the generated file carries real values. Grep the output for `<` followed by a letter before
   committing.
7. **`run: |` bodies keep one consistent indent**; every line of the block indented deeper than the
   `run:` key.

#### 4.0.3 Actions that need a token — wire it, don't ask for it

Some marketplace actions fail with an unhelpful error unless a token is passed in `env:`. **`GITHUB_TOKEN`
is provided automatically by GitHub Actions** — the user never creates it — but it is NOT injected into
a step's environment on its own. 🔴 Wiring it is AIRE's job at generation time, not a user action.

| Action | Needs | Who provides it |
|---|---|---|
| `gitleaks/gitleaks-action@v2` | `GITHUB_TOKEN` in `env:` | Automatic — AIRE wires it |
| `gitleaks/gitleaks-action@v2` on an **organization-owned** repo | `GITLEAKS_LICENSE` secret | 🔴 The user — free for personal and public repos, **paid for org-owned private repos** |
| `SonarSource/sonarqube-scan-action` | `SONAR_TOKEN`, `SONAR_HOST_URL` | The user (Section 4.1.2) |
| `anthropics/claude-code-action@v1` — 🔴 **NOT the default; AIRE uses the CLI (Section 6)** | `id-token: write` (OIDC) + `contents: write` + `pull-requests: write` | Only when the team explicitly chose the action variant. Omitting `id-token: write` fails with *"Could not fetch an OIDC token"*, and the action additionally refuses to run until the workflow matches the default branch |

```yaml
      - name: "D7: secret scan"
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          # GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}   # org-owned repos only
```

🔴 **DEFAULT TO THE BINARY, NOT THE ACTION.** The licence requirement turns a free, zero-setup gate
into a blocked pipeline on exactly the repos most likely to need it. Unless the repo *already* uses
`gitleaks-action`, generate the container form instead — no token, no licence, no marketplace
dependency, identical detection:

```yaml
      - name: "D7: secret scan"
        run: |
          podman run --rm -v "$PWD:/repo" zricethezav/gitleaks:latest \
            detect --source /repo --redact --exit-code 1
```

Use the Action only when the repo already depends on it — and then wire `GITHUB_TOKEN`, and surface
the `GITLEAKS_LICENSE` requirement in the setup gate when the repo is org-owned.

**General rule**: any generated step using a marketplace action must have its required `env:` and
`permissions:` resolved from that action's own documentation **before** the file is committed. A step
that fails on its first run for a missing token is a generation defect, caught by V3/V5 in Section 4.0.1.

#### 4.0.4 On failure

Fix and re-validate — up to **3 attempts**, then HALT and report, exactly like every other loop:

```
CI PIPELINE VALIDATION FAILED

  File:  .github/workflows/agentic-eval-pipeline.yml
  Check: [V1 YAML parse | V2 actionlint | V3 missing script | V4 missing file]
  Error: [exact parser output, including the line number]
  Line:  [the offending line, quoted verbatim]

  Attempt 1 - [what changed] -> [result]
  Attempt 2 - [what changed] -> [result]
  Attempt 3 - [what changed] -> [result]

3 retries ended. Please suggest next steps.
The pipeline has NOT been committed. No gate is currently enforced in CI.
```

🔴 **Never commit the file anyway "so the user can fix it".** An invalid workflow in the repo reads as
a broken build rather than an absent one, and it hides that nothing is being enforced.

#### 4.0.5 Confirm it actually ran

Committing a parseable file is not proof it runs. **After the design commit is pushed**, verify the
workflow was accepted:

```bash
gh run list --workflow=agentic-eval-pipeline.yml --limit 1
```

- A run appears (queued, in progress, or completed) → report its URL and status.
- **No run, or status `action_required` / a startup failure** → the file was rejected by GitHub.
  Report it immediately with the reason. Do not treat "pushed" as "working".
- `gh` unavailable → say the verification could not be performed, and tell the user to check the
  Actions tab. Never assume success.

#### 4.0.6 🔴 EPIC-LEVEL PRE-HANDOFF SMOKE TEST — validate the environment before any story starts

🔴 **Precondition — never run this before or concurrently with the Section 4.1.2 setup gate.** The
Section 4.1.2 block asks the user to add `CLAUDE_CODE_OAUTH_TOKEN`/`ANTHROPIC_API_KEY` and, if they
chose SonarQube, `SONAR_TOKEN`/`SONAR_HOST_URL` as repository secrets, and explicitly HALTs for a
`proceed`/`skip` answer (Section 4.1.3). This smoke test is what first exercises those secrets for
real (its own table above names self-repair end-to-end as exactly what it validates) — running it
before the user has answered that gate means it validates against secrets that do not exist yet, or
races the user's own setup. STOP CHECKPOINT Step 1.6 (pipeline generation + the setup gate) must be
**fully answered** — `proceed` or `skip`, per Section 4.1.3 — before this stage (STOP CHECKPOINT
Step 4) starts. This holds even resuming mid-STOP-CHECKPOINT: check `runtime-artifacts/aire-state.md`
for a recorded `proceed`/`skip` answer before running the smoke test; if absent, present the Section
4.1.2 gate first and wait.

**A run merely starting is not proof the environment is viable.** Direct pushes to the epic branch
never trigger this pipeline at all — the trigger is `pull_request` (plus `push` to the base branch
only, Section 4.0a) — so the design commit at Step 3 of the STOP CHECKPOINT produces zero CI signal on
its own. Before presenting the Development Handoff, run `templates/ci/smoke-test-epic.{sh,ps1}`
(copied to `tests/.evals/scripts/`, same as every other script in Section 5) with the epic branch and epic ID.

**What this validates, and what it deliberately does not:**

| Validates | Does NOT validate |
|---|---|
| Dependency-install conflicts (two pinned tools, or a tool vs. the project's own deps, wanting incompatible transitive versions) | Delta-scoped D1–D7 "new findings vs baseline" — vacuously true with zero diff |
| Tool-installation quirks (a tool that installs but whose verification flag misbehaves) | `unitCoverage`'s multi-report changed-file matching — needs a real diff across stacks to exercise |
| That the workflow is **accepted by GitHub**, triggers on this branch pattern, checks out, and resolves its credentials — the Section 4.0a "no run at all" failure, caught before any story | Whether the **existing test suite runs** — 🔴 it does NOT run here. `ci-manifest-runner.*` is diff-scoped per root (Section 4.0g), and a zero-diff PR touches no root, so every root reports `N/A`. Story 1's PR is the first run with a real diff |
| That `ci-manifest-runner.*` resolves the merged manifest and that every declared `ci.roots[]` directory and `markerFile` still exists (a Manifest defect surfaces here rather than on a story's PR) | Behavior tiers B1/B2 (scoped to a story that does not exist yet) |
| Whether self-repair itself works end-to-end in this repo (CLI flags, credentials, permissions) — for the first time, in a real PR | J1/J2 judge scoring (scoring a diff that is not there) |

🔴 **Never report this as proof the whole pipeline is correct.** It proves the environment this cycle
is about to be built on is viable — nothing more. The first real story's PR is still what exercises
delta-scoped gate logic for the first time; this stage does not replace that.

🔴 **HONEST PER-CHECK REPORTING, never a single PASS/FAIL word.** `smoke-test-epic.{sh,ps1}` reports
`trigger coverage`, `workflow acceptance`, `checkout`, `credential resolution` and `gating mechanics` as
their own lines, then downloads the run's `eval-results` artifact and prints the REAL per-gate breakdown
from `static-results.json.gates` — never fabricated, never collapsed into one word. On a zero-diff PR
this breakdown is **honestly** almost all `N/A` (#4's diff-scoped execution means a root with no changed
files reports `N/A` on its own, mechanically — the script surfaces that real result, it does not
manufacture a separate greenfield classification). This is what makes the completion message consistent
with the table above instead of inviting the reading it forbids.

**Why a zero-diff scratch PR, not `workflow_dispatch` on the epic branch directly**: self-repair's own
guard is `github.event.pull_request.head.repo.full_name == github.repository` — `github.event.pull_request`
does not exist on a `workflow_dispatch` run, so self-repair silently never activates there. A manually
triggered run that fails on the epic branch gets no correction loop at all. Routing through a real,
if trivial, PR means self-repair runs through its already-correct, already-tested path unmodified.

**Mechanics** (`templates/ci/smoke-test-epic.{sh,ps1}` — read the script before assuming its exact
behavior, this is a summary):

1. Cut a scratch branch (`ci/epic-smoke-<EPIC-ID>`) from the epic branch's current tip — identical
   content, zero diff.
2. Open a **draft** PR, scratch branch → epic branch, clearly labeled `[CI-SMOKE] Pre-handoff
   validation — <EPIC-ID>` so it is never confused with the real Epic PR (which stays manual, raised
   later via `pr-generator` — Section 1 of `planning/requirements-analysis.md`).
3. Wait for the run, using `gh run watch`. If it fails, wait for self-repair's follow-up run (a new
   push to the same PR triggers `synchronize`) and watch that instead — **UNBOUNDED**, with no
   independent cap of its own. The loop keeps following new self-repair-triggered runs and terminates
   **only** when `auto-fix-agent.*` itself stops producing a new one — either its own
   `retryLimitForSelfRepair` exhaustion (which already produces its own Retry-Limit Report, the right
   place for a human to see "this kept failing identically"), or a genuine fix. No third termination
   condition — no stall detection, no external attempt count — is introduced alongside this: a stall
   where self-repair keeps pushing commits that come back byte-identical is far more likely evidence
   that AIRE generated the CI pipeline without correctly reading the epic/story/codebase (a wrong
   command resolved into the manifest, a wrong stack detected) than evidence of something only a human
   can solve, and routing it to "ask a human" early would let that real generation defect quietly
   masquerade as an environment problem. **This is the ONE exception to CLAUDE.md's "Bounded
   Self-Healing" principle** — named there explicitly so it never reads as license to uncap any other
   self-healing loop in the framework.
4. **On green**: merge the draft PR into the epic branch (a real merge, not squash — keeps any
   `fix(ci): self-repair attempt N` commits individually visible/traceable), delete the scratch
   branch, log the outcome (including the per-check breakdown above) to `runtime-artifacts/audit.md`,
   proceed to the Development Handoff.
5. **On exhaustion**: leave the draft PR **open** for human inspection, HALT with the same
   Retry-Limit Report format used everywhere else in this framework — naming `auto-fix-agent.*`'s own
   exhaustion as the stopping condition, never an external count this script invented. 🔴 **Development
   Handoff does not happen** until this is resolved — handing a team off to build on an unvalidated
   environment is worse than a slower STOP CHECKPOINT.

🔴 **This runs exactly once per epic**, at the STOP CHECKPOINT — never per story. A story that needs
to change the manifest (a new source path, a new coverage report entry) commits that change as part
of its **own** PR, validated by that PR's own already-working CI run (Section 4.0a's trigger already
covers `story/**` → the epic branch) — adding a second scratch-PR cycle per story would double Actions
minutes for a case the existing per-story flow already covers correctly.

#### 4.0.7 🔴 TEST PLACEMENT CHECK — generate `check-test-placement.*` alongside `run-static-evals.*`

**Purpose**: `common/directory-structure.md` rules 4a/4b and `implementation/code-generation.md` Step
11a.6 (`SH-LOOP-12` in `workflows/dev-implement.md` Step 6.3) state where a test file must live. This
gate is what actually **proves** it, mechanically, instead of relying on the generating run to remember
correctly — exactly the same reasoning that makes D1–D7 deterministic checks rather than a model
re-reading a lint rule.

**Generate** `tests/.evals/scripts/check-test-placement.{sh,ps1}` (copied byte-for-byte from
`templates/ci/`, same rule as every other script in this section — never hand-authored per repo) that:

1. **Takes the diff base as its one argument**, same convention as `run-static-evals.*`: `git diff
   --name-only --diff-filter=ACMR <base-sha>...HEAD`.
2. **Classifies each changed path** as `application`, `unit-test`, `api-test`, or `other`:
   - `unit-test` — matches the stack's unit-test naming convention (`*.test.*`, `*.spec.*`,
     `test_*.py`, `*_test.py` outside Go, `*Test.java`, `*Tests.cs`, RTL/jsdom/Enzyme/Vue-Test-Utils
     component suites), read from `tests/.evals/config.json`'s stack-detection block (Section 3) —
     never hardcoded to one language.
   - `api-test` — a `unit-test`-shaped file that additionally imports/uses a real-endpoint test client
     (`supertest`, `httpx`/`TestClient`, `RestAssured`, `MockMvc`, or spins up a server) — grep the
     file's own imports, since the naming convention alone does not distinguish it.
   - `application` — everything under the resolved code root that is neither of the above.
3. **Fails (non-zero exit, one line per violation) when**:
   - an `application`-classified path is actually test-shaped (a test file was written under `src/`
     or `## Code Root`) — **unless** the stack's own co-location convention applies (Go `_test.go`,
     Rust `#[cfg(test)]`), which is never a violation;
   - a `unit-test` path's parent is not under `tests/unit/` (e.g. `tests/components/`, `tests/foo/`,
     or a bare file at `tests/`);
   - an `api-test` path's parent is not under `tests/api/` (most commonly: found instead under
     `tests/unit/`).
4. **Emits** a JSON summary (`files_scanned`, `violations: [{path, classification, expected_root,
   reason}]`, `verdict: PASS|FAIL`) to stdout, captured by the caller into
   `reports/unit-test-evidence/story-[N.M]/test-placement-check.log` — same evidence contract as every
   other gate in this document, never a hand-written claim.
5. **Both the local run (`code-generation.md` Step 11a.6) and CI call the SAME script** — never a
   second, YAML-inlined copy of the classification logic. Wire it into the generated
   `agentic-eval-pipeline.yml` as its own step in Stage 1 (deterministic checks), immediately after the
   D1–D7 steps and before Stage 2:
   ```yaml
   - name: "Test placement check"
     run: tests/.evals/scripts/check-test-placement.sh "${{ steps.basesha.outputs.sha }}"
   ```
6. **Validation — new check V35** (added to the `validate-pipeline.{sh,ps1}` table in Section 4.0.1):
   `check-test-placement.*` exists, is referenced in the generated YAML, and — same discipline as V9 —
   is proven to FAIL against a deliberately misplaced fixture (a `.test.` file dropped under `src/`)
   before being trusted to pass real diffs. A script that returns `PASS` unconditionally is the same
   defect V9 already forbids for `run-static-evals`/`run-evals`.

🔴 This check is **additional** to D1–D7, never folded into one of them and never a substitute for
`run-static-evals.*` — a repo can lint-clean and type-clean while still writing a unit test under
`src/`, and D1–D7's thresholds have nothing to say about file location.

### 4.0a 🔴 TRIGGER — every AIRE integration branch must be covered

AIRE raises PRs into **several** branches, not just the base. A `pull_request` trigger filtered to
`[ main ]` silently skips **every story PR**, because those target the epic branch. The PR then shows
no checks at all and merges ungated — the most dangerous failure in this document, because nothing
appears wrong.

**Every PR AIRE raises, and where it goes:**

| PR | Head | Target | Must trigger CI |
|---|---|---|---|
| Story | `story/<N.M>-<title>` | the **epic** branch |  |
| ve test docs | `ve/<TICKET-ID>-<title>` | epic / bug / enhancement branch |  |
| Epic | `epic/<EPIC-ID>-<title>` | base branch |  |
| Bug | `bug/<TICKET-ID>-<title>` | base branch |  |
| Enhancement | `enh/<TICKET-ID>-<title>` | base branch |  |
| CI bootstrap | `ci/agentic-eval-pipeline` | base branch |  |

So the filter must name the **base branch and every integration-branch pattern**:

```yaml
on:
  pull_request:
    branches:
      - <base-branch>        # resolved from runtime-artifacts/aire-state.md ## Branching, e.g. main
      - 'epic/**'
      - 'bug/**'
      - 'enh/**'
  push:
    branches:
      - <base-branch>        # whole-codebase scan after a merge
  workflow_dispatch:         # manual re-run without a new commit
```

**Rules:**

1. 🔴 **Resolve `<base-branch>` from `runtime-artifacts/aire-state.md` `## Branching`** — never hardcode `main`. Repos
   use `develop`, `master`, `trunk`.
2. 🔴 **Use `'epic/**'`, not a single epic name.** The filter must survive the next cycle without being
   regenerated; a literal `epic/AIPDLC-123-foo` breaks silently on epic 2.
3. **Quote the glob patterns.** `epic/**` unquoted is valid YAML here but quoting is consistent and
   avoids surprises with other patterns.
4. **`push` on the base branch** gives the post-merge whole-codebase scan a place to run (this is where
   an absolute SonarQube analysis belongs, as opposed to the PR's delta view).
5. **`workflow_dispatch`** so a failed run can be retried after fixing a secret, without an empty commit.
6. 🔴 **Never add `pull_request_target`.** It runs with the base branch's secrets against untrusted head
   code — the wrong tool here, and a real security hazard.

**Verify after generating**: list the branch patterns against the table above and confirm every row is
covered. State the resolved base branch by name in the announcement so a wrong value is obvious
immediately.

### 4.0b 🔴 STAGE 1 MUST BE DELTA-SCOPED — never a bare whole-tree command

This is the single most common way a generated pipeline goes wrong, and it disables the gate within a
week.

**The failure**: the local Static Eval Gate runs a tool, then **diffs the result against the baseline
captured before any code was written**, and classifies each finding as new-vs-pre-existing. A finding
that existed at baseline is recorded and ignored. A bare CI command like

```yaml
        run: semgrep --config auto src --error --severity ERROR --severity WARNING   # 🔴 WRONG
```

has no concept of a baseline. `--error` means *"exit 1 if there are ANY findings"* — a blunt verdict on
the whole tree, every run. One pre-existing warning in old code then fails **every future PR**, for
every story, forever, while the local gate correctly reports PASS. Same tool, same finding, opposite
verdict — purely because the verdict logic differs.

🔴 **`scope: "changed-files"` in `tests/.evals/config.json` is binding on CI exactly as it is locally**
(`common/eval-framework.md` Section 2.2). CI re-verifies the same contract; it does not get a
different, stricter one.

🔴 **This applies to the COVERAGE gate too, not only D1–D7.** A whole-module
`pytest --cov-fail-under=90` fails on pre-existing coverage debt on every PR, regardless of what the
PR touched — the same false-blame defect in a different tool. Measure coverage on the **changed files**
and compare against `unitTestCoverageMin`:

```bash
# WRONG - whole module, fails on pre-existing 86% forever
pytest --cov=src/backend --cov-fail-under=90

# RIGHT - full run for correctness, threshold applied to the changed files only
pytest --cov=src/backend --cov-report=xml          # no --cov-fail-under here
tests/.evals/scripts/run-static-evals.sh "$BASE_SHA"     # owns the changed-file coverage verdict
```

Run the **whole** suite (a change can break a test anywhere), but apply the **threshold** only to
lines in changed files. `run-static-evals.*` owns that computation, exactly as it owns the D1–D7 diff.

#### 4.0b.1 The rule: one script owns the diffing, both callers invoke it

Generate **`tests/.evals/scripts/run-static-evals.*`** and have **both** the local gate and CI call it. Never
re-implement the diff logic in YAML — that is precisely how the two drift apart.

```yaml
      - name: "Stage 1: static evals (delta-scoped)"
        run: tests/.evals/scripts/run-static-evals.sh "${{ steps.basesha.outputs.sha }}"
```

🔴 **Pass the resolved `merge-base`, never the raw `github.event.pull_request.base.sha` directly.** The
"Resolve base SHA" step (Section 4.0a's job skeleton) computes
`git merge-base "${{ github.event.pull_request.base.sha }}" HEAD` — the base branch's raw tip is only
the branch's tip **as of the webhook event**, and once another story merges into an epic/bug/enh branch,
that tip is no longer an ancestor of THIS PR's HEAD. D1/D2/D6's baseline capture checks out the base ref
directly (Section 4.0b.1 below) — checked out at a non-ancestor tip, that baseline can contain code this
PR never touched and be missing code HEAD has, so the baseline capture itself can fail (or silently
misattribute) for reasons belonging to another story's commit, not this PR's. `merge-base` is the only
ref guaranteed to be a common ancestor in both directions, including the inverse case where this PR
itself merges the integration branch in. Both the `verify-and-evaluate` job's "Resolve base SHA" step
AND the `self-repair` job's own copy of that same step must compute it this way — never the bare
expression pasted twice with two different (and, on an active branch, increasingly divergent) meanings.
Checked by **V7**.

The script's contract, identical in both environments:

1. Resolve the **changed file set**: `git diff --name-only <base-sha>...HEAD`.
2. Run D1–D7 against the **base ref** (baseline) and against **HEAD** (post-change).
3. **Diff the finding sets**, matching on `(rule-id, file, message)` — **not on line number**, which
   shifts when unrelated code moves. That line-shift is exactly why the CORS finding at `main.py:12`
   and `main.py:39` must be recognised as the same pre-existing finding.
4. Count only findings that are **NEW versus baseline AND on a changed file** against the thresholds.
5. Emit `eval.json` + `eval-summary.md`, exit non-zero only on a real delta breach.
6. **Report pre-existing findings as non-blocking information** in the PR comment, so debt stays
   visible without failing the build.

#### 4.0b.2 Use each tool's native baseline flag when it has one

Cheaper and more reliable than a two-pass diff. Prefer these:

| Check | Native delta support | Use |
|---|---|---|
| D3 SAST |  semgrep | `semgrep --config auto --baseline-commit <base-sha>` — reports only findings introduced since that commit |
| D7 Secrets |  gitleaks | `gitleaks detect --log-opts "<base-sha>..HEAD"` — scans only the new commits |
| D4 SCA |  partial | Diff the advisory ID set between base and head lockfiles |
| D1 Lint · D2 Types · D6 Complexity |  none | Two-pass diff via the script, matched on `(rule, file, message)` |

🔴 **Never substitute "scope the tool to changed files" for a real baseline diff.** Running
`mypy <changed-files>` still fails on a pre-existing error that happens to live in a file this story
touched — which is the same false blame in a smaller box. Changed-file scoping narrows *where* to look;
the baseline diff decides *who is responsible*. Both are required.

#### 4.0b.3 Forbidden in a generated Stage 1 step

- `--error`, `--exit-code 1`, `--strict`, `--max-warnings 0` on a **whole-tree** invocation
- Any tool run against `src/` (or the whole repo) with no base ref and no baseline comparison
- Thresholds hardcoded in the YAML instead of read from `tests/.evals/config.json`

A step matching any of these is a generation defect, caught by **V7** in Section 4.0.1.

### 4.0c 🔴 STEP FAILURE ISOLATION — one gate must never skip the others

Two opposite defects show up in generated pipelines, and both destroy the verdict.

**Defect A — a hard-failing step aborts the job.** GitHub Actions stops a job at the first failed step.
A step with no error tolerance therefore *skips every gate after it*:

```yaml
      - name: "SonarQube quality gate"          # 🔴 WRONG — no tolerance, and not last
        uses: SonarSource/sonarqube-quality-gate-action@v1
```

When Sonar's gate fails, D1–D7, unit tests, Gherkin and J1/J2 never run. Every later step shows
`⊘ skipped`, and the PR reports a failure that says nothing about the code. Sonar becomes an upstream
kill switch instead of one input among many.

**Defect B — `|| true` makes a gate unable to fail.** The reflexive fix for Defect A is worse:

```yaml
      - name: "D3: SAST"
        run: semgrep --config auto src || true    # 🔴 WRONG — the result is destroyed
```

`|| true` discards the exit code entirely. The step is now decorative: it can never fail the job, and
the scorecard cannot report its real result — which breaks the rule that every figure quoted downstream
must match the stored artifact. **A gate that cannot fail is not a gate.**

#### 4.0c.1 The correct pattern: isolate, collect, then decide once

Every gate step **records** its outcome and lets the job continue. Exactly **one** final step decides
the verdict and is the only step allowed to fail the job.

```yaml
      # every gate step: id + continue-on-error, NEVER `|| true`
      - name: "Stage 1: static evals (delta-scoped)"
        id: static
        continue-on-error: true
        run: tests/.evals/scripts/run-static-evals.sh "${{ steps.basesha.outputs.sha }}"

      - name: "Stage 2: unit + coverage"
        id: unit
        continue-on-error: true
        run: <resolved command>

      - name: "Stage 2: behaviour (Gherkin)"
        id: behavior
        continue-on-error: true
        run: tests/.evals/behavior/run.sh <tiers>

      - name: "Stage 3: judge gates J1 + J2"
        id: judge
        continue-on-error: true
        run: tests/.evals/scripts/run-evals.sh

      # SonarQube LAST among the gates, and never able to abort what follows
      # (shown here as one step for brevity — Section 4.1.1's real implementation splits scan
      #  `id: sonar` and gate `id: sonarqg` into two steps; the gate step needs its OWN `env:
      #  SONAR_TOKEN`, secrets do not carry over from the scan step)
      - name: "SonarQube quality gate"
        id: sonarqg
        if: always()
        continue-on-error: true
        uses: SonarSource/sonarqube-quality-gate-action@v1
        timeout-minutes: 5
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}

      # the ONLY step that fails the job
      - name: "Verdict"
        if: always()
        run: |
          fail=0
          for r in "static:${{ steps.static.outcome }}" \
                   "unit:${{ steps.unit.outcome }}" \
                   "behavior:${{ steps.behavior.outcome }}" \
                   "judge:${{ steps.judge.outcome }}" \
                   "sonar:${{ steps.sonarqg.outcome }}"; do
            name="${r%%:*}"; outcome="${r##*:}"
            echo "$name: $outcome"
            [ "$outcome" = "failure" ] && fail=1
          done
          exit $fail
```

**Rules:**
1. 🔴 **Every gate step has `id:` and `continue-on-error: true`.** Never `|| true`, never
   `continue-on-error` without an `id` (the outcome would be unreadable).
2. 🔴 **Exactly one Verdict step fails the job**, guarded by `if: always()` so it runs even after a
   failed gate.
3. 🔴 **The scorecard publish step is `if: always()`** so results reach the PR on failure — that is
   when they matter most.
4. 🔴 **SonarQube is the LAST gate step**, `if: always()`, `continue-on-error: true`. It is one input
   among many, never a precondition for running the others.
5. **Order gates cheapest-first** — static, unit, behaviour, judge, Sonar — so a fast failure surfaces
   quickly, but *never* let ordering decide what runs. With isolation, everything runs regardless.
6. `continue-on-error: true` on a step whose result is **not** read by the Verdict step is the same
   defect as `|| true`. Every isolated step must appear in the Verdict tally.

#### 4.0c.2 🔴 The Verdict step HANDS the failure to self-repair — it never makes it go looking

The Verdict step already knows exactly which gates failed. **Write that down and pass it on.** Self-repair
must never have to rediscover the failure by hunting for a file, because the file may be absent, at a
different path, or — worse — present and *silent about the thing that actually failed*.

```yaml
      - name: "Verdict"
        id: verdict
        if: always()
        run: |
          mkdir -p tests/.evals/_run
          fail=0
          : > tests/.evals/_run/failed-gates.txt
          for r in "static:${{ steps.static.outcome }}" \
                   "unit:${{ steps.unit.outcome }}" \
                   "behavior:${{ steps.behavior.outcome }}" \
                   "judge:${{ steps.judge.outcome }}" \
                   "sonar:${{ steps.sonarqg.outcome }}"; do
            name="${r%%:*}"; outcome="${r##*:}"
            echo "$name: $outcome"
            if [ "$outcome" = "failure" ]; then echo "$name" >> tests/.evals/_run/failed-gates.txt; fail=1; fi
          done
          exit $fail

      - name: "Upload failure context"
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: eval-results
          path: |
            tests/.evals/_run/failed-gates.txt
            reports/eval-evidence/
```

🔴 **Every step id in the Verdict tally must be able to appear in `failed-gates.txt`.** A gate that can
fail the build but is not in the tally fails it invisibly.

#### 4.0c.3 🔴 A gate that fails the build MUST appear in `eval.json`

Observed in a real run: SonarQube's Quality Gate failed, the Verdict correctly failed the job — and
`eval.json` contained fifteen gates, **none of them SonarQube**. Self-repair then opened the scorecard,
read `"verdict": "PASS"`, and had nothing to repair. The scorecard disagreed with the build.

**The `gates` block is complete or it is wrong.** Every gate the pipeline can fail on:
`D1_lint` … `D7_secrets`, `unitCoverage`, `behaviorB1`, `behaviorB2`, `behaviorB3`,
`J1_architecture`, `J2_security`, **and `sonarqube` whenever it is enabled**.

🔴 **`apiContract` and `regression` are NOT in this list, and must not be added.** They are local-only
gates (`common/eval-framework.md` Section 5) — nothing in this pipeline implements either, so a
declared-but-unimplemented gate would now resolve to ERROR and fail every PR. This list names the gates
the pipeline can actually fail on; it is not a wish list.

🔴 **`verdict` is derived from the `gates` block, and the job's result must agree with it.** If the job
failed while `eval.json` says `PASS`, that is a defect in the scorecard, not a quirk to work around.
The generated `run-evals.*` reads the other steps' outputs (Section 5.3.2) rather than omitting what it
did not compute itself.

#### 4.0c.4 Validation

**V8**: every gate step has an `id:` and `continue-on-error: true`; no gate step uses `|| true`,
`|| exit 0` or `; true`; exactly one Verdict step exists and every isolated step's `id` appears in it;
Sonar is the last gate step and carries `if: always()`.

🔴 A pipeline failing V8 either aborts on the first failure (Defect A) or cannot fail at all
(Defect B). Both pass V1–V7, and both make the PR's green or red meaningless.

### 4.0d 🔴 WORKING DIRECTORY IS A MANIFEST FACT — never a guess, never re-derived independently by each side

**The problem this section closes**: a resolved path (`ci.roots[].root`, `common/eval-framework.md`
Section 1.1) is worthless if the thing that runs a command doesn't actually run it there. Before this
section, no rule anywhere stated what directory an install/build/coverage/D1–D7 command executes in —
every consumer simply assumed `cwd` was already correct. On a monorepo, the **local** gate and the
**CI** gate can then execute the identical manifest command from two different directories and get two
different results, silently — because tool output paths are relative to wherever the command actually
ran, a mismatch does not fail loudly, it just makes real findings fail to match the changed-file set,
and the gate reports clean. This breaks the one contract Section 7 states outright: *"CI re-verifies in
a clean environment what was verified on the developer's machine."*

🔴 **The fix is not "add a `cd` to the YAML".** A `cd` computed independently by the pipeline and a `cd`
computed independently by the local gate can still diverge — two guesses that happen to agree today can
drift the moment either side's detection logic changes. **The working directory is a single manifest
fact, `ci.roots[].root`, established once and read identically by both sides.** Neither the generated
pipeline nor the local gate is ever allowed to detect, infer, or hardcode a working directory on its
own — both `cd` to the value this file already recorded.

#### 4.0d.1 The shared pattern — implemented ONCE, in the fixed `ci-manifest-runner.sh`, never generated per repo

🔴 **Superseded by #7a — read Section 4.0h below before assuming this is generated text.** The version
of this section that predates #7a described this pattern as something generated PER REPO into
`${SETUP_STEPS}`/`${INSTALL_STEPS}`/`${BUILD_COMMAND}`/`${COVERAGE_COMMAND}` — one block per root, baked
into the committed YAML once at generation time. That is no longer true. Those four slots are gone.
This exact shape now lives **once**, in the framework-owned, copied-verbatim
`tests/.evals/scripts/lib-manifest.sh` (`resolve_and_verify_root`, `root_touched`) and
`tests/.evals/scripts/ci-manifest-runner.sh` (the per-root loop that calls them) — the generated
workflow's `Install dependencies`/`Compile / build`/`Stage 2: unit + coverage` steps just **call** that
fixed script, reading the merged manifest **at run time**, every run, rather than substituting text
once. It is followed identically by the local gate (`workflows/dev-implement.md` Steps 1.5.4.6/6,
`implementation/code-generation.md` Steps 11a/11a.5/11b/11c) and by `tests/.evals/scripts/run-static-evals.*`
for D1–D7, which sources the SAME `lib-manifest.sh`:

```bash
# Generated per entry in ci.roots[] — this exact shape, never a bare command with no cd/verify.
REPO_ROOT="$(git rev-parse --show-toplevel)"   # 🔴 resolved FRESH, every single invocation — never
                                                #    cached, never an absolute path from a prior run or
                                                #    a different clone (dev-implement.md Step 1.75 opens
                                                #    a separate clone per parallel story; each one must
                                                #    resolve its OWN toplevel, then apply the SAME
                                                #    recorded relative `root`).
cd "${REPO_ROOT}/<root>" || {
  echo "::error::Manifest defect — ci.roots[] root '<root>' does not exist in this checkout. Fix tests/.evals/config.json, not this workflow (Section 6.4's Manifest triage class)."
  exit 1
}
test -f "<markerFile>" || {
  echo "::error::Manifest defect — root '<root>' declares stack '<stack>' but its marker file '<markerFile>' is missing here. The recorded root no longer matches a real '<stack>' project — likely a rename/move the manifest was never updated for. Fix tests/.evals/config.json, not this workflow."
  exit 1
}
<the bare command — assumes cwd == root, per eval-framework.md Section 1.1>
```

**Rules:**

1. 🔴 **`REPO_ROOT` is resolved fresh at the start of every invocation**, never cached, never assumed
   equal to `$PWD` or `$GITHUB_WORKSPACE` on faith. This is what makes the pattern correct under
   `dev-implement.md` Step 1.75's parallel-clone model with zero changes to that model — two clones each
   resolve their own toplevel and then apply the identical, git-committed, relative `root`.
2. 🔴 **The marker-file check is not optional and not a nice-to-have.** A directory that exists but no
   longer contains the declared stack's marker file (renamed, moved, restructured since the manifest was
   last resolved) is exactly the case a bare `cd` cannot catch — it would silently run the wrong stack's
   tooling, or a stack-agnostic tool against the wrong tree, and report a false clean result. A mismatch
   here is a **Manifest** defect (Section 6.4's triage class) — it is reported and the run stops; it is
   **never** repaired by editing application code, and self-repair must never attempt to.
3. **A single-root manifest (`root: "."`) still runs this exact pattern** — `cd "${REPO_ROOT}/."` is a
   no-op `cd`, and the marker-file check still catches a repo that lost its own `package.json`/`go.mod`/etc.
   There is no "skip verification because there's only one root" exception; the failure this catches
   (a stale marker) is independent of how many roots exist.
4. **`ci-manifest-runner.sh build`/`coverage` iterates every root that has a real command for that
   stage** — never a single bare string, and never one generated block per root either; it is one fixed
   loop over the merged manifest. A root whose stack has no build step (plain Python) still gets its own
   explicit `N/A` (`ci-manifest-runner (build): N/A — root '<root>' (<stack>) has no build command`), per
   Section 3's existing rule that an unresolvable stage is never silently omitted — applied per-root by
   the script's own loop, not by per-root generated text.
5. **The self-repair job calls the exact same fixed script as the verify job** — `Read manifest`,
   the five `actions/setup-*` blocks, and `Install dependencies`/`Compile / build` are byte-identical
   text in both jobs (there is no separate `${SELF_REPAIR_SETUP_STEPS}` slot left to keep in sync
   with). Section 3.1's "same tools" rule is now structural, not a runtime check.
6. **`run-static-evals.*` applies the same pattern internally**, once per root, before invoking that
   root's D1–D7 tools — it already owns all delta-diffing (Section 4.0b.1), so the `cd`+verify+normalize
   sequence belongs inside that one script, not duplicated per gate step in the YAML. See
   `common/eval-framework.md` Section 2.2 for the companion path-normalization rule this makes necessary:
   every path a tool reports from inside a non-`.` root must be prefixed with that root before it is
   compared against `git diff --name-only`, which is always repo-root-relative.
7. **Locally, the identical pattern runs from `workflows/dev-implement.md`/`implementation/code-generation.md`**,
   reading the SAME `ci.roots[]` from the SAME `tests/.evals/config.json` — never a separately detected
   or hardcoded directory. This is what makes "CI re-verifies what was verified on the developer's
   machine" (Section 7) actually true on a monorepo: both sides execute from the one recorded root, not
   from two independent guesses that happen to usually agree.

#### 4.0d.2 Validation — V28

**V28 (post-#7a)**: since the `cd`+verify pattern is no longer per-repo generated text, this is now a
ONE-TIME structural check that the committed `tests/.evals/scripts/ci-manifest-runner.sh` actually calls
`resolve_and_verify_root` (and that `lib-manifest.sh` actually defines it) — never a per-root scan of the
generated YAML, because there is no such per-root text left in it to scan. A copy of
`ci-manifest-runner.sh` that has lost this call is a defect in the copied script itself, not in any one
repo's generation.

### 4.0e 🔴 CI EXECUTES, NEVER DISPLAYS — purge inherited evidence, resolve by key, never by search

**The problem**: the **Verdict** step is computed from GitHub step **outcomes**
(`steps.static.outcome`, etc.), so the pass/fail verdict itself cannot be faked by a committed file — CI
genuinely runs the tools. But three consumers read evidence from the **working tree**, and a checkout
arrives pre-populated: `dev-implement.md` Steps 4.6/6/6.6 and Section E all write to
`reports/eval-evidence/story-[N.M]/` as part of the story's own commit, so that directory is present in
CI's checkout **before any gate runs**. Nothing gitignores `tests/.evals/_run/` either, and
`auto-fix-agent.*`'s own `git add -A` stages it. Three concrete hazards follow:

1. **`Stage 4: publish scorecard`** cats `reports/eval-evidence/${EVAL_KEY}/eval-summary.md`. If a CI
   eval step fails to produce a fresh summary, the step finds the **locally committed** one at that exact
   path and publishes it to the job summary as though CI produced it.
2. **`auto-fix-agent.*` resolving evidence by `find … | head -1`** (or, in the PowerShell variant, a
   recursive `Get-ChildItem`) returns an **arbitrary first match across every work unit's own evidence**
   — after a few merged stories that includes other stories' committed `eval.json`,
   `static-results.json.gates`, and `gitleaks-delta.json`.
3. **Stale `tests/.evals/_run/*.status` files** are present before a tier writes its own, so a tier that
   never executes can leave a committed `PASS` in place.

🔴 **The local run and the CI run are NOT redundant, and this section is not an argument for dropping
either.** Local gates are what let a story self-correct before it ever raises a PR; CI is the independent
re-execution on a clean runner. What must never happen is CI **reporting** the local run's result as its
own.

**What this requires, in every generated pipeline and every generated script:**

1. **A `Purge inherited evidence` step**, immediately after `Resolve EVAL_KEY` and BEFORE any gate step
   (including install/build), in the `verify-and-evaluate` job: `rm -rf tests/.evals/_run
   "reports/eval-evidence/${EVAL_KEY}"`. Everything a gate needs is produced by that gate; anything
   present beforehand is by definition not this run's.
2. **`tests/.evals/_run/` is gitignored** in the generated repo (`common/directory-structure.md`), and
   `auto-fix-agent.*`'s `git add -A` must never stage it. A story's own committed evidence under
   `reports/eval-evidence/story-[N.M]/` is intentionally tracked (Section 5.3) — only the CI-local
   scratch state (`_run/`) is purged and ignored.
3. **Every consumer resolves evidence by `EVAL_KEY` path, never by wildcard search.** `auto-fix-agent.*`
   reads `reports/eval-evidence/${EVAL_KEY}/eval.json` (and `.../static/static-results.json.gates`,
   `.../static/gitleaks-delta.json`) directly, and fails loudly — never silently adopts another work
   unit's file — when `EVAL_KEY` itself is unset. This is why the self-repair job needs its **own**
   `Resolve EVAL_KEY` step (mirroring the verify job's) rather than relying on `BASE_SHA` alone — without
   it, self-repair had no way to resolve its evidence except by searching.

#### 4.0e.1 Validation — V31

**V31**: the generated `verify-and-evaluate` job purges `tests/.evals/_run` and
`reports/eval-evidence/${EVAL_KEY}` before its first gate step; the `self-repair` job has its own
`Resolve EVAL_KEY` step and passes `EVAL_KEY` to `auto-fix-agent.*`; and no script in
`tests/.evals/scripts/` resolves an evidence file by `find`/wildcard search where an `EVAL_KEY`-addressed
path is available. Pairs with **#9** (an attestation is only meaningful if the artifact it downloads was
produced by that run, not inherited).

### 4.0f 🔴 MANIFEST RECONCILIATION — the manifest is frozen at generation time; the code it gates is written per work unit

**The ordering fact this section exists to close**: CI is generated at the STOP CHECKPOINT, once, for
the whole cycle. The code it gates is written afterwards, **per work unit**, by
`implementation/code-generation.md` — whose structural decisions (a new source path, a new coverage
report, a new stack) do not exist yet at generation time. A story that needs to change the manifest
commits that change as part of its **own** PR, validated by that PR's own already-working CI run.

**The key insight is that it never has to guess.** By the time a work unit's local gates have passed
(Section 4.0d's Steps 11a/11a.5/11b/11c, or the workflow-specific equivalent for a bug/enhancement), it
has already *executed* every value the manifest would need:

| Manifest value | Already established by |
|---|---|
| `installCommands`, `tools` | The bootstrap/install step — ran each install, ran each version check |
| `coverageCommand`, `coverageReportPath`, `coverageFormat` | The Unit Test & Coverage step — ran the coverage command, produced a real report at a real path |
| `root`, `markerFile`, `sourcePaths`, `testPaths` | The story's own diff — the files it actually created, under the root it actually verified (Section 4.0d) |
| `tools` **and** `toolInstallCommands` | The bootstrap step — every eval tool it installed, PAIRED with the exact command that installed it. 🔴 **Both or neither.** `ci-manifest-runner.*` raises a **Manifest defect** for any name in `tools` with no matching `toolInstallCommands` entry anywhere in the merged manifest, so writing `tools` alone turns every later install run into a hard failure. |
| `runtimeVersion` | The runtime the bootstrap actually used, read from the repo's own pin (`.node-version`, `pyproject.toml` `requires-python`, `go.mod`'s `go` directive, …). `read-manifest.*` reads it back to pin the matching `actions/setup-*` step; absent, that step falls back to the action's own default and CI can run a different runtime than the local gate proved green on. |
| `noTestsExitCode` | The exit status this root's test runner returns when it collects ZERO tests (pytest `5`, jest/vitest `1` — omit where the runner exits `0`). Section 3.0. Without it, "this repo has no suite yet" is a hard gate failure instead of an earned `N/A`. |
| `dependsOn` | Roots in this same manifest whose source this root consumes, read from the repo's own declaration (a `<dependency>` on a groupId this repo owns, a `workspaces` member, `go.work` `use`, a `<ProjectReference>`, a `-e ../pkg` spec). 🔴 This is what makes diff-scoping sound on a monorepo: without it, a PR touching only a shared module skips every dependent module's build, tests and gates, and the verdict is PASS. |
| `toolchainSetup` | Only for a root whose `stack` is outside `{node, python, java, go, dotnet}` — the commands that install and pin its toolchain, from the repo's own pin file. Absent on such a root, `read-manifest.*` raises a Manifest defect, because nothing would provision it. |

🔴 **A fragment that omits a field the scripts READ is not a partial fragment — it is a defect.** All
five rows above were, at one point, read by the generated scripts and written by nothing: a repo-wide
grep for `toolInstallCommands`, `runtimeVersion`, `noTestsExitCode`, `dependsOn` and `toolchainSetup`
across `workflows/*.md` returned **zero** instructions to write any of them, while `toolInstallCommands`
alone is read by five scripts and gates a hard Manifest defect. Reconciliation writes the COMPLETE entry
for every root it establishes, or it records why a field is genuinely inapplicable.

**Reconciliation writes back what actually ran and proved green** — never a plan, never a guess. Add a
step to each of the workflows that actually generate code — `workflows/dev-implement.md`,
`workflows/bug-fix-implement.md`, `workflows/enhancement-implement.md` — placed **after the local gates
pass and before the commit**: write `tests/.evals/ci-manifest.d/<work-unit-key>.json` (`story-<N.M>.json`,
`bug-<TICKET-ID>.json`, `enh-<TICKET-ID>.json`) containing an array of the `ci.roots[]`-shaped entries
this work unit established or extended, then re-run `validate-pipeline.{sh,ps1}` before committing.
`workflows/ticket-implement.md` gets nothing — it is a pure router that hands off to two of the three
workflows above.

**Reconciliation is append-only.** Add new roots, new source/test paths, new coverage reports, new
tools, new install commands — never remove an existing one. Removal is a cycle-level decision, made by a
human, never inferred by a story.

#### 4.0f.1 🔴 One new file per work unit, never an edit to a shared file

The dependency graph explicitly allows parallel stories (`dev-implement.md` Step 1.75: *"open a NEW
folder/clone of this same repo… and run dev-implement there on an INDEPENDENT story"*), so two work
units genuinely can reconcile at the same time. An in-place edit to `tests/.evals/config.json` would
conflict textually on adjacent array lines — resolving that means an agent hand-merging **the file that
defines the gates** mid-run, the worst possible place for a silent drop.

So reconciliation never edits `config.json`. It writes ONE NEW file:

```text
tests/.evals/config.json                     <- thresholds + STRUCTURAL ci facts. Never edited by a work unit.
tests/.evals/ci-manifest.d/
├── story-1.1.json                           <- written ONLY by story 1.1
├── story-1.2.json                           <- written ONLY by story 1.2
└── bug-PROJ-417.json                        <- written ONLY by that bug cycle
```

Every consumer reads the **merged** view — `config.json`'s `ci.roots[]` (if any) plus every fragment,
filename-sorted, unioned by root (array fields concatenated and deduped, scalar fields taking the
last-seen fragment) — which `tests/.evals/scripts/run-static-evals.*` already does, writing the result to
`tests/.evals/_run/merged-manifest.json` on every invocation. Two work units never touch the same file,
so the conflict class is **impossible by construction**, not resolved by rule. The merged view is still a
single source of truth; the fragments are just its storage, exactly like a `conf.d/` directory.

🔴 **No work unit may edit another unit's fragment.** A work unit that needs to extend a root another
unit already established writes its OWN fragment, adding to that root via the merge — never opens and
edits the earlier unit's file.

🔴 **A tool-pin conflict across two fragments touching the SAME root is a surfaced decision, not a
silent union** (`config.json`'s `ci.roots[].tools`, e.g. `semgrep==1.127.0` vs `semgrep==1.130.0`) —
reconciliation, before writing its own fragment, checks the merged view for an existing pin on the same
tool at a different version and, on a conflict, tells the user and asks which pin wins before writing
(never "last fragment wins" silently), re-running the Section 3.2.1 clean-room dry-run before the choice
is accepted.

#### 4.0f.2 The carve-out this makes unnecessary

`common/directory-structure.md` (Artifact Ownership) and `common/eval-framework.md` Section 1's *"if it
already exists, use it AS-IS"* rule both stay **intact, unamended** for `config.json` — a work unit never
edits it, so there is nothing to carve an exception out of. The only rule that needs a line is a new
one: `ci-manifest.d/` is **append-a-new-file** territory (`common/directory-structure.md`), narrower than
Section 2.1.1's *"present → leave it completely alone"* rule for the rest of `tests/.evals/`, which stays
as written for every file except this one directory.

Fragments are **collapsed** into `config.json`'s `ci.roots[]` and deleted at cycle close, by the
`archive-epic` skill (`agents/archive-epic-agent.md`), which already owns cycle closure — so they never
accumulate across cycles.

#### 4.0f.3 Not an edge case, for the record

An abandoned or closed PR's fragment never reaches the integration branch, and reconciliation is
append-only, so there is nothing to roll back.

### 4.0g 🔴 DIFF-SCOPED EXECUTION — decided fresh on every run, from the real diff, never a plan

**Real monorepo CI (Nx's `affected`, Turborepo, Bazel target graphs, GitHub's own `paths:` triggers) never
bakes a one-time, pre-code guess about scope into the pipeline's structure.** It keeps the full stage set
available and decides, **per run, from the actual file diff**, which stages need to execute. A `root`
this PR never touched (`ci.roots[]`, Section 4.0d) can only ever produce zero NEW findings — its
baseline and its post-change run would be identical — so running its install/lint/type-check/etc. at all
is pure waste on a PR that never touched it, not just a correctness nicety.

**Mechanism — `root_touched(root)`, computed inline, no marketplace action needed**: `git diff --name-only
<merge-base>...HEAD` is already resolved once per run (Section 4.0b.1); a root is "touched" when that
diff contains a path equal to, or nested under, that root (`root: "."` is always touched — the whole
repo is "under" the repo root). This is deliberately NOT a separate `dorny/paths-filter` step exposing
`steps.pathscope.outputs.*` — with the per-root pattern Section 4.0d.1 already establishes (one shell
block per root, inside a single generated step per stage), the scope check belongs INSIDE that same
block, evaluated before the `cd`, not as a GitHub Actions-level `if:` gating a whole separate step:

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
if git diff --name-only "${BASE_SHA}...HEAD" -- "<root>" | grep -q .; then
  cd "${REPO_ROOT}/<root>" || { echo "::error::Manifest defect — root '<root>' missing"; exit 1; }
  test -f "<markerFile>" || { echo "::error::Manifest defect — root '<root>' missing its marker file"; exit 1; }
  <bare command>
else
  echo "N/A: root '<root>' — no changed files under this root for this PR (diff-scoped)"
fi
```

**Rules:**

1. **Applies to `ci-manifest-runner.sh`'s install/build/coverage loop** (Section 4.0d.1 — post-#7a, no
   longer per-repo generated `${INSTALL_STEPS}`/`${BUILD_COMMAND}`/`${COVERAGE_COMMAND}` blocks)
   **and to `run-static-evals.*`'s per-root `delta_diff` calls** (D1/D2/D4/D5/D6) — both skip the actual
   command for an untouched root and record `N/A` instead, never a silent absence. Implemented once, in
   `lib-manifest.sh`'s `root_touched()` helper, sourced by both scripts and called at the top of every
   root-scoped operation.
2. **Whole-repo-class checks stay unconditional** — D3 SAST (semgrep) and D7 secrets (gitleaks) already
   scan the merged `sourcePaths`/commit range as one invocation with their own native baseline flags
   (Section 4.0b.2); splitting them per root would only add complexity for tools that are already
   delta-scoped by their own mechanism. **SonarQube stays whole-repo too** — its own new-code-period
   mechanism computes the PR's delta server-side and needs the whole tree to do that correctly.
3. **`unitCoverage`'s existing "no changed file under this report's `sourcePaths` → PASS vacuously"
   behaviour (`coverage_delta()`) already implements the same principle** for the gate itself; this
   section is what extends it to the STACK'S ACTUAL COMMANDS (install/build/coverage), which is where
   the real cost (a multi-minute `npm ci`) actually lives.
4. **`self-repair`'s per-root blocks mirror the SAME `root_touched()` check**, from the same `BASE_SHA`
   the verify job resolved — Section 3.1's existing "self-repair needs the same tools as verify" rule,
   now extended to "the same diff-scoped skip decisions".
5. **No epic/story reading needed at generation time.** This is computed at CI **run** time, from the
   real diff of that exact PR — strictly more accurate than any guess made from planned-but-unwritten
   stories, and correct on every subsequent PR without the manifest ever needing an "extend the scope"
   recovery step.

#### 4.0g.1 Validation — V29

**V29 (post-#7a)**: a ONE-TIME structural check that the committed `ci-manifest-runner.sh` actually
calls `root_touched` (and that `lib-manifest.sh` defines it) before running any root's command — never a
per-root scan of generated YAML, since the diff-scope check now lives in the fixed script's own loop, not
in per-repo generated text. A copy missing this call would run every root's command unconditionally on
every PR regardless of whether that PR touched it — the exact whole-tree-cost defect this section exists
to remove.

### 4.0h 🔴 #7a — THE YAML HOLDS NO STACK FACTS, IT READS THE MERGED MANIFEST AT RUN TIME

**The ordering problem this closes**: the pipeline is generated ONCE, at the STOP CHECKPOINT, for the
whole cycle. Before this section, `${SETUP_STEPS}`/`${INSTALL_STEPS}`/`${BUILD_COMMAND}`/
`${COVERAGE_COMMAND}`/`${SELF_REPAIR_SETUP_STEPS}` baked per-repo stack facts into the committed YAML at
that one moment — so a LATER work unit that introduced a genuinely new stack (the repo's first frontend
code, say) had no automatic way to get that stack installed in CI: its own `ci-manifest.d/` fragment
(Section 4.0f) taught `run-static-evals.*` about the new root, but the frozen `${INSTALL_STEPS}` text
never ran `npm ci` for it, so the tool was never there and a human had to hand-edit the committed
workflow. **Those five slots are gone.** The generated pipeline now contains only FIXED text that reads
the merged manifest fresh, every single run — never substituted once.

**What replaced them, all fixed, all copied verbatim (never re-authored per repo):**

1. **`Read manifest`** (`bash tests/.evals/scripts/read-manifest.sh >> "$GITHUB_OUTPUT"`) — builds the
   merged manifest (`config.json`'s `ci.roots[]` + every `ci-manifest.d/*.json` fragment, Section 4.0f.1)
   and emits `has_<stack>`/`<stack>_version` for `node`/`python`/`java`/`go`/`dotnet`, read straight from
   each root's `stack`/`runtimeVersion` fields (`eval-framework.md` Section 1.1) — never re-detected from
   the filesystem.
2. **All five `actions/setup-*` blocks, permanently present**, each gated
   `if: steps.readmanifest.outputs.has_<stack> == 'true'`. Nothing is ever added or removed from the
   file for a new stack — only enabled, by a fact the manifest already carries.
3. **`Install dependencies`**, **`Compile / build`**, and (verify job only) **`Stage 2: unit +
   coverage`** each call the ONE fixed
   `bash tests/.evals/scripts/ci-manifest-runner.sh {install,build,coverage} "${{ steps.basesha.outputs.sha }}"`.
   That script (Section 4.0d.1) sources the shared `lib-manifest.sh` and, for every root in the merged
   manifest: diff-scopes it (Section 4.0g's `root_touched`), verifies it (Section 4.0d.1's
   `resolve_and_verify_root`), and runs its command — or reports an earned `N/A`. `Install dependencies`
   also installs the merged, deduped eval tools from every root's `toolInstallCommands`
   (`eval-framework.md` Section 1.1), replacing the old separately-generated "Install eval tools" block.
4. **Byte-identical in the `self-repair` job.** There is no more `${SELF_REPAIR_SETUP_STEPS}` slot to
   keep in sync with the verify job's copy — both jobs call the SAME fixed steps, so Section 3.1's "same
   tools" rule is now structural, verified by V27's byte-comparison rather than a separate runtime
   slot-equality diff.

**What a work unit that introduces a new stack actually needs to do**: write its own
`ci-manifest.d/<unit>.json` fragment (Section 4.0f) and nothing else. `Read manifest` and
`ci-manifest-runner.sh` pick it up the very first time they run on that unit's own PR — zero edits to
the committed workflow file, ever.

**Only two slots remain in `agentic-eval-pipeline.yml.template`** — `${BASE_BRANCH}` and
`${PR_BRANCH_FILTERS}` — because `on:` triggers cannot be dynamic. `${BEHAVIOR_IMAGE_TAG}`,
`${SONAR_STEPS}` and `${CLAUDE_CODE_VERSION}` also remain, but they are **structural**, not stack, facts
(the same regardless of which stack roots a repo has) and were never in scope for this section.

#### 4.0h.1 Validation

Covered by the checks already defined above, applied to the new fixed scripts rather than to per-repo
generated text: **V27** (structural fidelity — the five new step names and the two new scripts' presence
are part of what it verifies), **V28** (`ci-manifest-runner.sh` calls `resolve_and_verify_root`), **V29**
(`ci-manifest-runner.sh` calls `root_touched`). No new V-number is needed — #7a is a delivery-mechanism
change for checks that already existed, not a new property to check.

### 4.0i 🔴 CI PREFLIGHT — the work unit proves the pipeline can RUN, on its own machine, BEFORE the PR exists

Section 4.0f writes the manifest. **This section proves the manifest is EXECUTABLE.** They are different
claims, and only the second one is worth anything to CI: a fragment can name every field, pass
`validate-pipeline`, and still produce a pipeline that cannot run a single gate, because what the
fragment *declares* and what the developer's machine *already happened to have installed* are two
different sets.

**The observed failure this section exists to close** — a real story's first CI run, every local gate
green beforehand:

```
D1_lint       ERROR [src/backend] tool 'ruff' for gate D1_lint is not installed on this runner
D2_types      ERROR [src/backend] tool 'mypy' ... is not installed on this runner
D5_licenses   ERROR [src/backend] tool 'pip-licenses' ... is not installed on this runner
D6_complexity ERROR [src/backend] tool 'radon' ... is not installed on this runner
coverage      ERROR root 'src/backend' — RuntimeError: The starlette.testclient module requires
                    the httpx package to be installed
```

Two distinct root causes, both of them **declaration gaps, not code defects**:

| Root cause | Why the local gates did not catch it | Where the fix belongs |
|---|---|---|
| The eval tools were installed into the **agent's ambient environment** by the Step 4.6 bootstrap (`common/eval-framework.md` Section 2.4.1) and then **never recorded** in the fragment's `tools` + `toolInstallCommands`. D1/D2/D5/D6 ran locally off the ambient binary | The local gate found the binary on `PATH`. Nothing on the local side ever asks *"and would a bare runner have found it?"* | The work unit's own fragment (`ci.roots[].tools` **paired with** `toolInstallCommands`, Section 4.0f) |
| A **test-only runtime dependency** (`httpx`, here, pulled in by `fastapi.testclient`) was present in the ambient environment but absent from the repo's own dependency declaration, so `installCommands` could not install it | Same shape: the import resolved locally because the package was already there | The repo's own dependency declaration (the test/dev group of `requirements*.txt` / `pyproject.toml` / `package.json`), and `installCommands` if that group is not already installed |

🔴 **"It ran on my machine" is not evidence that CI can run it.** Every gate this framework declares is
worth exactly as much as the bare-runner provisioning behind it. A gate that ERRORs on a missing tool
is not a softer failure than a gate that finds a bug — it is *worse*, because it measured nothing while
consuming a full CI run, a full self-repair triage, and the local workflow's attention on the way back.

#### 4.0i.1 The contract — three checks, in this order

Executed by the **owning implement workflow** (`dev-implement.md` Section D Step 2.5,
`bug-fix-implement.md`, `enhancement-implement.md`), **after the work unit's commit and BEFORE the push
and the PR**. Committed-first is not incidental: every CI entrypoint is **diff-scoped**
(Section 4.0g, `root_touched()` against `<merge-base>...HEAD`), so a preflight run with the work unit's
changes still uncommitted scopes every root out and reports a chorus of `N/A` — a preflight that proves
nothing while looking clean.

**P1 — Declaration completeness, read from the MERGED manifest (static, cheap, run first).** Read
`tests/.evals/_run/merged-manifest.json` (or re-derive it exactly as `run-static-evals.*` does) and, for
every root this work unit's diff touches:

1. Resolve every gate in `ci.gates` to the **binary its command actually invokes**, and confirm that
   binary is named in some root's `tools` **and** has a matching `toolInstallCommands` entry. A gate
   whose binary is in neither is the `ruff`/`mypy`/`pip-licenses`/`radon` failure above, already
   detectable here, with no environment and no CI run spent.
2. Confirm `semgrep` (D3) and `gitleaks` (D7) are declared somewhere — they are stack-agnostic, so
   their absence is a manifest gap, never an inapplicable gate (`run-static-evals.*` says exactly this
   when it hits it).
3. Confirm the rest of the Section 4.0f field table is present for each touched root:
   `installCommands`, `coverageCommand` + `coverageReportPath` + `coverageFormat`, `markerFile`,
   `runtimeVersion`, `noTestsExitCode` (or a runner flag that makes the command no-tests-safe),
   `dependsOn`, `toolchainSetup` for a stack outside the built-in five, and `sourcePaths`/`testPaths`
   that actually match the files in this unit's diff.

**P2 — Clean-room execution of the REAL CI entrypoints, provisioned ONLY from the manifest.** In a
disposable environment built exactly as Section 4.0.1a requires (fresh venv / empty `node_modules` /
throwaway Podman container from the runner's own base image — **never the agent's ambient shell, and
never with a manual `pip install` the manifest does not declare**), run the same scripts CI runs, with
`BASE_SHA="$(git merge-base origin/<integration-branch> HEAD)"`:

```bash
bash tests/.evals/scripts/ci-manifest-runner.sh install  "$BASE_SHA"   # roots' deps + every eval tool
bash tests/.evals/scripts/ci-manifest-runner.sh build    "$BASE_SHA"   # where a root declares one
bash tests/.evals/scripts/run-static-evals.sh            "$BASE_SHA"   # D1-D7
bash tests/.evals/scripts/ci-manifest-runner.sh coverage  "$BASE_SHA"  # unit tests + coverage
```

**P3 — Behavioural provisioning.** The behavioural tiers already run in Podman from the committed
`tests/.evals/behavior/Containerfile` (`common/behavior-spec.md` Section 5), so **when the work unit's own
behavioural gate genuinely ran containerised, that IS the clean-room evidence** — cite that run's
evidence manifest (image ref + digest) and do **not** re-run it. Re-run under P2 only when the
behavioural gate ran natively under its one permitted exception (Podman not installed), or when this
unit changed the `Containerfile`, `run.sh`, the step-definition dependencies, or anything the image
installs. Deliberately reusing already-clean-room evidence is the point: preflight exists to stop wasted
runs, not to add one.

#### 4.0i.2 Verdict — what counts as a preflight FAILURE

Any of the following in P1/P2/P3 output, regardless of the script's own exit code:

- `is not installed on this runner` / `command not found` / `No such file or directory` on a tool
- `ModuleNotFoundError`, `ImportError`, `RuntimeError: ... requires the <pkg> package`, `Cannot find
  module` — a dependency the declaration does not provide
- A dependency-resolution failure (`ResolutionImpossible`, `ERESOLVE`, a non-clean `pip check`)
- A **Manifest defect** marker in `tests/.evals/_run/manifest-defects.txt`, or a missing `cd` target or
  `markerFile` (Section 4.0d)
- A gate reporting `N/A`, or zero analysed files, on a root this unit's diff demonstrably touched
  (Section 6.4's stale-manifest signal, caught here instead of in CI)
- 🔴 A gate reporting the **QUALIFIED PASS** wording — *"no findings at base or head … the tool
  produced zero output at BOTH ends"* — for a root this unit touched. That is the tool proving nothing,
  which is the same defect as the tool being absent, wearing a PASS badge.

**Not a preflight failure**: a gate that runs correctly and reports a **real finding**, and a test that
runs correctly and **legitimately fails**. Those are the local gates' own business (SH-LOOP-1 … 4) and
they were already green before this step; if one of them goes red here it goes back to that loop, on
that loop's existing counter (SH-2), never onto the preflight counter.

#### 4.0i.3 Repairing a preflight failure — declarations, never gates

| Missing | Fix |
|---|---|
| An eval tool | Add it to the owning root's `tools` **and** `toolInstallCommands` in **this unit's own fragment** (Section 4.0f.1 — never another unit's file, never `config.json`), pinned, and re-run P2 |
| A runtime or test dependency | Add it to the **repo's own dependency declaration** — the real test/dev group — and to `installCommands` if that group is not already installed. 🔴 Never as a bare `pip install`/`npm i -g` inside the workflow YAML or a script: the repo's declaration is the single source of truth and is what every later run, and every developer, resolves from |
| A runtime version | Record `runtimeVersion` from the repo's own pin, so `read-manifest.*` pins the matching `actions/setup-*` |
| A root/marker/path | Correct the fragment's `root` / `markerFile` / `sourcePaths` / `testPaths` to the paths the diff actually contains |

🔴 **Forbidden ways to pass preflight** — the same SH-6 list, restated for this gate because the
temptation here is specific and strong: removing the gate from `ci.gates`; deleting a tool from `tools`
so nothing checks for it; marking a gate `N/A` for a stack it plainly applies to; excluding the failing
root from `sourcePaths`; skipping the failing test; adding an ignore-list entry; declaring the whole
gate `N/A` because "the runner will have it". **Preflight makes the pipeline runnable. It never makes it
pass.**

#### 4.0i.4 Why this is a work-unit gate and not a `validate-pipeline` V-check

`validate-pipeline.{sh,ps1}` validates the **pipeline** at generation time, once per cycle, against a
manifest that (Section 4.0f) does not yet know about code no story has written. Preflight validates a
**work unit's own fragment against its own diff**, which exists only per PR. Both are needed; neither
substitutes for the other, and preflight adds no V-number (the V-table and the script stay in lock-step
per Section 4.0.1's own note).

The epic-level smoke test (Section 4.0.6) is the third member of this family and stays exactly as it is:
it proves the pipeline *and* self-repair work end-to-end in this repo, once, on a zero-diff PR, before
any story starts. Preflight is the per-story equivalent for the one thing a zero-diff PR can never
exercise — provisioning for code that did not exist yet.

### 4.1 Stage 1 — SonarQube: generate everything, then ask for the token

SonarQube is **additive** to semgrep and the Security Baseline review, never a replacement. But
"optional" does not mean "left half-built". **Generate every artifact AIRE can generate, then present
the two values it cannot and wait.**

#### 4.1.1 What AIRE generates (always, when SonarQube is not already configured)

| Artifact | Generated from |
|---|---|
| `sonar-project.properties` | `sonar.organization` — 🔴 **left as `YOUR_ORG_NAME` for the user to replace**; AIRE cannot know the SonarQube organization key. Required by SonarQube Cloud, omitted for self-hosted · `sonar.projectKey` / `sonar.projectName` from the git remote or the repo directory name · `sonar.sources` from the resolved code root (`runtime-artifacts/aire-state.md` `## Code Root`, default `src/`) · `sonar.tests` from `tests/` **only where that reflects the real layout — see 4.1.1a below for co-located tests** · `sonar.exclusions` for build output, vendor and generated directories · the coverage report path for the detected test runner (`sonar.javascript.lcov.reportPaths`, `sonar.python.coverage.reportPaths`, `sonar.coverage.jacoco.xmlReportPaths`, `sonar.go.coverage.reportPaths`, …) |

##### 4.1.1b 🔴 BOTH GENERATED SONAR STEPS MUST CARRY THE SKIP GUARD

`sonar.sources` is written from the resolved Code Root, which at the STOP CHECKPOINT is a **planned**
path — on a greenfield repo `src/` does not exist yet. SonarScanner treats that as fatal:

```
ERROR Invalid value of sonar.sources for <project>
ERROR The folder 'src' does not exist for <project> (base directory = /home/runner/work/...)
INFO  EXECUTION FAILURE
Error: Process completed with exit code 3
```

and the quality-gate step then fails on its own missing input
(`.scannerwork/report-task.txt does not exist.`), so one absent folder produces two red steps on a PR
that has no code to analyse in the first place.

The fixed `Resolve Sonar scope` step (in the template, before `${SONAR_STEPS}`) rewrites
`sonar.sources`/`sonar.tests` down to paths that actually exist, and sets `skip=true` when none do.
🔴 **The generator MUST emit both Sonar steps guarded by it:**

```yaml
      - name: "SonarQube scan"
        id: sonar
        if: always() && steps.sonarscope.outputs.skip != 'true'
        continue-on-error: true
        uses: SonarSource/sonarqube-scan-action@v4
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
          SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}

      - name: "SonarQube quality gate"
        id: sonarqg
        # 🔴 ALSO requires the scan to have produced its report — without this the gate step fails
        #    with ".scannerwork/report-task.txt does not exist" whenever the scan was skipped OR failed.
        if: always() && steps.sonarscope.outputs.skip != 'true' && hashFiles('.scannerwork/report-task.txt') != ''
        continue-on-error: true
        uses: SonarSource/sonarqube-quality-gate-action@master
        timeout-minutes: 5
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

🔴 **The quality-gate step MUST carry its own `env: SONAR_TOKEN`.** GitHub Actions secrets are not
ambient across a job — each step only sees a secret it names itself. The scan step above wires
`SONAR_TOKEN`/`SONAR_HOST_URL` into its OWN environment; that does not carry over to the next step.
**Observed failure**: the scan step passes, but the quality-gate step fails with `Set the SONAR_TOKEN
env variable. Error: Process completed with exit code 1.` even though `SONAR_TOKEN` exists as a repo
secret — because this step alone had no `env:` block to read it from. `continue-on-error: true` then
masks the failure at the job level, so the run shows green while the actual gate verdict was never
fetched. (`SONAR_HOST_URL` is not required here — the action reads the server URL from
`.scannerwork/report-task.txt`, written by the scan step — but `SONAR_TOKEN` must be present.)

🔴 A skipped Sonar is an **earned N/A**, not a silent omission: `Record SonarQube gate status` already
writes `N/A` when the quality-gate step has no outcome, so the Verdict tally still carries a real entry
(Section 4.0c). Sonar remains one input among many and never a kill switch.

##### 4.1.1a 🔴 `sonar.sources`/`sonar.tests` MUST be disjoint — never list the same directory as both

SonarQube hard-fails the whole scan if the same file is matched by both `sonar.sources` and
`sonar.tests`: `"File <path> can't be indexed twice. Please check that inclusion/exclusion patterns
produce disjoint sets for main and test files."` A blind `sonar.tests=tests/` assumes every stack in
the repo keeps its tests under one shared top-level directory — untrue for a full-stack repo where a
Python backend's tests live under `tests/` but a JS/TS frontend co-locates tests next to the source
they cover (`Component.test.tsx` beside `Component.tsx`, a common Vitest/Jest convention). **Observed
failure**: `sonar.sources=src/backend,src/frontend` combined with `sonar.tests=tests/unit/backend,
src/frontend/src` — listing `src/frontend/src` as BOTH a source root and a separate test root means
every file under it, including plain non-test files, gets indexed twice.

🔴 **`sonar.sources` and `sonar.tests` accept only plain directory/file paths — they do NOT support
wildcards.** The wildcard-capable properties are `sonar.inclusions`/`sonar.exclusions` (for source
files) and `sonar.test.inclusions`/`sonar.test.exclusions` (for test files) — `*`, `**` and `?` only
work there, never inside `sonar.sources`/`sonar.tests` themselves (confirmed against SonarQube's own
documentation — do not assume otherwise).

**Rules:**

1. **Never list the same directory under both `sonar.sources` and `sonar.tests`.** For a co-located
   convention, keep the directory ONLY under `sonar.sources`, then reclassify the specific test files
   within it using `sonar.test.inclusions` (a wildcard pattern, e.g.
   `sonar.test.inclusions=src/frontend/src/**/*.test.ts,src/frontend/src/**/*.test.tsx`) — never as a
   second path in `sonar.tests` itself.
2. **Verify disjointness before treating the artifact as generated correctly** — the same bar Section
   5.0's NO STUBS principle applies everywhere else: a plausible-looking `sonar-project.properties`
   that has never actually been run through a scan is not proof it works. Run the scan once and confirm
   it does not fail with an "indexed twice" error before declaring the setup gate satisfied.
3. **Never widen `sonar.exclusions` to paper over an overlap** — that risks silently excluding real
   source files from analysis too. Fix the actual `sonar.sources`/`sonar.tests`/`sonar.test.inclusions`
   scoping instead.
| The scan steps in `.github/workflows/agentic-eval-pipeline.yml` | `SonarSource/sonarqube-scan-action` followed by `SonarSource/sonarqube-quality-gate-action`, with `env: SONAR_TOKEN` and `SONAR_HOST_URL` wired to repository secrets. Written **active**, not commented out. 🔴 Both go **LAST among the gate steps**, with `if: always()` and `continue-on-error: true` (Section 4.0c) — Sonar is one input to the verdict, never a kill switch that skips D1–D7, the tests and the judge. |
| `tests/.evals/config.json` | `sonarqube.enabled: true` |

🔴 **Never invent the two secret values, and never write them into a file.** A token belongs in the
repository's secret store and nowhere else — not in `sonar-project.properties`, not in the workflow
YAML, not in `tests/.evals/config.json`, not in an `.env` committed to the repo.

**Already configured?** If `SONAR_TOKEN` + `SONAR_HOST_URL` already exist as repository secrets, or a
`sonar-project.properties` is already present, use what is there as-is, skip the gate below entirely,
and say so. Never overwrite a properties file a human wrote.

#### 4.1.2 The setup gate — present verbatim, then HALT

🔴 **Exempt from `common/question-format-guide.md`'s multiple-choice format — this is CLAUDE.md's
third CHAT-ONLY/verbatim exception, and the strictest one.** That guide's "summarize into A/B/C +
`[Answer]:`" pattern is for genuine multiple-choice decisions; this is a block of literal setup
instructions the user must read and follow in another window. Summarizing it — into a question file
OR into a short multiple-choice prompt (including via a structured question tool) — silently deletes
the `claude setup-token` steps, the SonarCloud/Community setup steps, the exact secret names, and how
to add them, leaving the user with a proceed/skip decision but no way to actually satisfy it. Observed
in production: this gate got compressed into a two-option "Proceed with SonarQube / skip" prompt with
a one-sentence description, and the entire instructional block below never reached the user.

Emit the block below exactly as written. **Plain text, no emoji, no decoration** — it is a set of
instructions the user will follow in another window, so it has to read as instructions, not as chat.
Substitute the bracketed values with what was actually generated.

```
CI SETUP REQUIRED

AIRE has generated everything it can for this repository:

  Created   .github/workflows/agentic-eval-pipeline.yml
            all gate steps, the verdict step, and the self repair job
  Created   tests/.evals/scripts/auto-fix-agent.sh
            runs the Claude Code CLI to fix failing gates
  Created   sonar-project.properties
            project key [key], sources [sources], tests [tests], coverage report path
            organization left as YOUR_ORG_NAME for you to set, see below
  Updated   tests/.evals/config.json
            sonarqube.enabled = true

Three values cannot be generated because they belong to your accounts, not to
this repository. Add them as GitHub Actions secrets before the pipeline can run:

  CLAUDE_CODE_OAUTH_TOKEN   lets the pipeline fix its own failing gates
  SONAR_TOKEN               authentication token for SonarQube
  SONAR_HOST_URL            address of your SonarQube server

  sonar.organization        not a secret. Set it in sonar-project.properties,
                            currently YOUR_ORG_NAME. See below.

  GITHUB_TOKEN              nothing to do. GitHub provides this automatically and
                            the pipeline already passes it to the secret scanner.

GET YOUR CLAUDE CODE TOKEN

  1. Install Claude Code, if you do not already have it:
       npm install -g @anthropic-ai/claude-code
  2. Sign in once, interactively:
       claude
     Complete the browser prompt, then leave with /exit
  3. Generate a long lived token for CI and run the command given below in the terminal:
       claude setup-token
  4. Copy the value it prints. It is shown once.
  5. Prefer an API key instead? Create one at https://console.anthropic.com
     under API Keys, and name the secret ANTHROPIC_API_KEY rather than
     CLAUDE_CODE_OAUTH_TOKEN. The pipeline accepts either.

  Without one of these the gates still run and still block the PR.
  Only the automatic self repair job is skipped.

ADD THE CLAUDE CODE OAUTH TOKEN TO GITHUB

  1. Open this repository on GitHub.
  2. Go to Settings, then Secrets and variables, then Actions.
  3. Select New repository secret.
  4. Name: CLAUDE_CODE_OAUTH_TOKEN
     Value: the token from claude setup-token.
     Select Add secret. 


NOW CHOOSE HOW YOU RUN SONARQUBE


OPTION A - SonarQube Cloud. Hosted by Sonar. Free for public repositories.

  1. Open https://sonarcloud.io and sign in with your GitHub account.
  2. On the dashboard, click on + button.
  3. Select Analyze new project and choose this repository and click on Set up.
  4. In this project dashboard, navigate to Administration and click on Analysis Method.
  5. Toggle off the Automatic Analysis if already enabled.
  6. Click on Profile icon and then click on My Account.
  7. Click on Access Tokens and Enter a token name and select Generate.
  8. Copy the token value now. It is shown once and cannot be retrieved later.
  9. Your SONAR_HOST_URL is https://sonarcloud.io

ADD THE SECRETS TO GITHUB

  1. Open this repository on GitHub.
  2. Go to Settings, then Secrets and variables, then Actions.
  3. Select New repository secret.
  4. Name: SONAR_TOKEN
     Value: the token you copied from SonarQube.
     Select Add secret.
  5. Select New repository secret again.
  6. Name: SONAR_HOST_URL
     Value: your server address.
     Select Add secret.

OPTION B - SonarQube Community Build. Free, self-hosted, you run the server.

  1. Start the server:
       podman run -d --name sonarqube -p 9000:9000 docker.io/sonarqube:community
  2. Wait about ninety seconds, then open http://localhost:9000
  3. Sign in with username admin and password admin.
  4. Set a new password when prompted.
  5. Open My Account, then Security.
  6. Enter a token name and select Generate. Copy the token value.
  7. Your SONAR_HOST_URL is the address your CI runner can reach this server on.
     http://localhost:9000 will not work from a GitHub hosted runner. Use a
     reachable host name, or run the pipeline on a self hosted runner.

SET YOUR SONARQUBE ORGANIZATION NAME

  1. Open sonar-project.properties in this repository.
  2. Find the line:  sonar.organization=YOUR_ORG_NAME
  3. Replace YOUR_ORG_NAME with your organization key. Find it in SonarQube Cloud
     under My Organizations, or in the URL of your project page.
  4. Self-hosted SonarQube does not use organizations. Delete the line instead.

IF THIS REPOSITORY IS OWNED BY A GITHUB ORGANIZATION

  The pipeline scans for secrets using the gitleaks container, which needs no token
  and no licence. Nothing to do.

  Only if you later switch to the gitleaks-action marketplace action: that action
  requires a GITLEAKS_LICENSE secret on organization owned repositories. It is free
  for personal and public repositories. See https://gitleaks.io for a licence key.

After adding the secrets and setting your organization name, type: proceed

To continue without SonarQube instead, type: skip
Semgrep and the sixteen rule Security Baseline review still run and still block.
```

#### 4.1.3 Handling the answer

| Answer | Action |
|---|---|
| **`proceed`** | Leave the generated artifacts active. Record in `runtime-artifacts/audit.md` **and** `runtime-artifacts/aire-state.md` that the user confirmed the secrets were added. Do **not** attempt to verify the secret values — they are not readable from here, and a first pipeline run is what proves them. Continue the STOP CHECKPOINT — next is the Section 4.0.6 smoke test (STOP CHECKPOINT Step 4), not before. |
| **`skip`** | Comment out the two scan steps in the workflow with a one-line note naming the secrets that would enable them, set `sonarqube.enabled: false`, and **keep** `sonar-project.properties` so a later `proceed` needs only the secrets. Record the skip and the reason in `runtime-artifacts/audit.md` **and** `runtime-artifacts/aire-state.md`. Continue — next is the Section 4.0.6 smoke test, same as `proceed`. |
| Anything else | Re-present the block once, unchanged. Do not paraphrase it and do not guess at an intent. |

🔴 **This gate blocks the STOP CHECKPOINT, not the whole framework.** It is presented at CI generation
time, immediately before the workflow halts for `dev-implement` anyway, so it costs the user nothing
extra. `skip` is always a valid, first-class answer — never argue with it and never re-ask on a later
run once it is recorded.

🔴 **Recording the answer in `aire-state.md`, not only `audit.md`, is what lets Section 4.0.6 check for
it before running** (its own precondition note) — an answer logged only to the audit trail is easy to
miss on a resumed session; a durable field in `aire-state.md` is not.

🔴 **Never make SonarQube a hard dependency.** A pipeline that cannot run without a server the team has
not provisioned is a pipeline that gets deleted, taking the real gates with it. Security enforcement
must survive its absence: semgrep (deterministic) plus the Security Baseline diff review (LLM) are the
floor; SonarQube raises the ceiling where it exists.

### 4.1b Stage 2 — behavioural tiers, and which PR runs which

Stage 2 runs the **same three tiers** as the local gate (`common/behavior-spec.md` Section 4.4), in the
**same Podman image**, through the **same entry point**. Scope is decided by the PR's target branch:

| PR | Tiers run | Rationale |
|---|---|---|
| **story / bug / enh → integration branch** | **B1 + B2** | Prove this unit works and broke nothing. Fast — one unit's scenarios plus the accumulated suite. |
| **epic / integration → base branch** | **B1 ∪ B2 ∪ B3** | The last gate before the cycle merges. Runs the whole cycle suite plus `spec/behavior.feature`. |

```yaml
      - name: Build behaviour image
        run: podman build -t aire-behavior:ci -f tests/.evals/behavior/Containerfile .

      - name: Resolve behavioural tier
        id: tier
        run: |
          # B3 only on a PR into the base branch; B1+B2 otherwise
          if [ "${{ github.base_ref }}" = "<base-branch>" ]; then
            echo "tiers=b1 b2 b3" >> "$GITHUB_OUTPUT"
          else
            echo "tiers=b1 b2" >> "$GITHUB_OUTPUT"
          fi

      - name: Behavioural tests (Gherkin)
        run: |
          step_fail=0
          for t in ${{ steps.tier.outputs.tiers }}; do
            trc=0
            podman run --rm -v "$PWD:/work:Z" -w /work \
              aire-behavior:ci "bash tests/.evals/behavior/run.sh $t" || trc=$?
            case "$trc" in
              0) : ;;             # PASS
              3) : ;;             # N/A — no story exists yet for this tier to run against
              *) step_fail=1 ;;   # real FAIL
            esac
          done
          exit "$step_fail"
```

🔴 **`run.sh <tier>` is the single entry point.** The developer runs `./tests/.evals/behavior/run.sh b1`,
AIRE's local gate runs the same thing, and CI runs the same thing. Tier membership is resolved
**inside** `run.sh` from the `spec/` layout and the Story Tracker — never duplicated in the YAML, so
the two can never drift apart.

🔴 **`run.sh` must be invoked as ONE quoted command string** (`"bash tests/.evals/behavior/run.sh $t"`), never
as separate trailing args (`tests/.evals/behavior/run.sh "$t"`). The image's `ENTRYPOINT ["/bin/sh", "-c"]`
(`behavior/Containerfile`) requires it: passed separately, POSIX `sh -c` assigns the tier to the
invoked shell's `$0`, not `run.sh`'s `$1` — `run.sh` then always sees an empty `$1` regardless of
which tier was requested (`common/behavior-spec.md` Section 5.3).

🔴 **`run.sh` exits 3 for a legitimate N/A** — no story has been `dev-implement`'d yet for this tier to
run against (the pre-story epic-level smoke test, Section 4.0.6). The calling step MUST treat exit
code 3 as N/A, distinct from any other non-zero exit (a real FAIL). A bare `if podman run ...; then
PASS; else FAIL; fi` cannot make that distinction and will wrongly block a story's PR on a tier that
has nothing to test yet.

**Services**: when the suite needs a datastore, the generated job creates a **pod** and runs both
containers into it, mirroring Section 4.3's local setup exactly. Only for a datastore the repo demonstrably
needs.

**Podman on GitHub-hosted runners** is preinstalled on the `ubuntu-*` images. Use `podman`
directly — do not fall back to `docker`. Record the podman version in the evidence.

### 4.2 Stage 3 — the judge in CI

Stage 3 invokes `tests/.evals/scripts/run-evals.*` (generated, Section 5) with the PR diff. It reads
`tests/.evals/config.json` and `tests/.evals/rubrics/`, produces `eval.json` + `eval-summary.md`, and **exits
non-zero** when `J1 < llmJudgeArchitectureScoreMin` or `J2 < llmJudgeSecurityScoreMin`, or any
`gates` entry fails. Authentication: `ANTHROPIC_API_KEY` **or** `CLAUDE_CODE_OAUTH_TOKEN` (Section 6).

🔴 **Authentication alone is not enough — the `claude` CLI itself must be installed in THIS job,
before this step.** `run-evals.*`'s own precondition check (`command -v claude`) fails the gate outright
if it is missing, with `"claude CLI not installed — judge cannot run"`. The `self-repair` job installs
the CLI too, but only for itself, and only ever runs *after* `verify-and-evaluate` has already failed —
that install never reaches Stage 3's own job. `verify-and-evaluate` needs its **own**
`- name: "Install Claude Code CLI"` / `run: npm install -g @anthropic-ai/claude-code` step, placed
before this one, exactly mirroring the self-repair job's copy. Omitting it fails J1/J2 on every single
PR before a real judge call is ever attempted.

🔴 **Installing the CLI is not the same as resolving its flags — Section 6.0's requirement applies to
`run-evals.*`'s `CLAUDE_JUDGE_INVOCATION` marker too, not only `auto-fix-agent.*`'s
`CLAUDE_REPAIR_INVOCATION`.** Section 6.0 is written inside "The CI self-repair agent" and names only
`auto-fix-agent.*` explicitly — but `run-evals.*` invokes `claude` exactly the same way, from the exact
same TTY-less CI context, and needs the exact same resolved headless/permission flags. **Observed
failure**: a bare, unresolved `claude` invocation (piped a prompt via `printf '%s' "$prompt" | claude`)
tries to start an interactive session with no TTY available, exits almost immediately, and the
`printf` writing the prompt into the now-closed pipe fails with `write error: Broken pipe` —
surfacing as `"judge CLI invocation failed"` with no further detail if the invocation's stderr is
also being discarded (`2>/dev/null`), which it must not be. Before writing `run-evals.*`, run
`claude --help` and resolve its flags exactly as Section 6.0 instructs for self-repair — never leave
this marker bare on the assumption that only the self-repair script needs it.

🔴 **`judge.model` in `tests/.evals/config.json` must be a real, non-empty model name/alias before the
`CLAUDE_JUDGE_INVOCATION` marker is ever resolved to use `--model`.** `run-evals.*` itself fails clearly
and early (`exit 2`, "judge.model is not set") if it is empty — verified directly: `claude -p
--output-format text --restricted --model ""` returns `API Error: 400 model: String should have at
least 1 character` and exits non-zero before draining a large piped prompt, which is the mechanism
behind the "Broken pipe" symptom above. Never write a resolved invocation that reads `judge.model`
without this precondition already in place.

---

## 5. Generated scripts — `tests/.evals/scripts/`

🔴 **These are not generated from scratch.** `run-static-evals`, `run-evals`, `auto-fix-agent`,
`validate-pipeline` and `smoke-test-epic` are copied verbatim from `templates/ci/*.sh` / `*.ps1`
(Section 1) — pick the `.sh` or `.ps1` variant per `templates/ci/TEMPLATE-MANIFEST.md`, never author a new one.
What follows in this section is
the **contract those copied scripts must satisfy**; if a copied script violates it, the fix belongs in
`templates/ci/`, not as a one-off patch in the target repo.

### 5.0 🔴 NO STUBS. A script that cannot fail is not a gate.

The single most damaging thing this generator can produce is a **plausible placeholder** — a script
that runs, prints reassuring output, writes `"status": "N/A"` and exits 0 without doing the work. It
passes every structural check, turns the PR green, and silently removes a gate from the pipeline. That
is strictly worse than not generating the script at all, because the team believes they are covered.

**Three rules, no exceptions:**

1. 🔴 **Never write a script that hardcodes a passing or `N/A` result.** If the script cannot perform
   its check, it **exits non-zero** with the real reason. It never fabricates an outcome.
2. 🔴 **`N/A` must be earned and must be TRUE.** `N/A` is valid only when the check genuinely does not
   apply, and the recorded `reason` must state the actual cause. Writing
   `"reason": "no judge credentials in this run"` while credentials **are** present is a lie in an
   artifact, and it breaks the rule that every figure quoted downstream matches its source.
3. 🔴 **Distinguish `N/A` from `ERROR`.** Missing credentials, a tool that will not install, an API
   that returns 500 — these are `ERROR` (the check should have run and did not), and they **fail the
   job**. Only "this check does not apply to this work unit" is `N/A`.

**Prove it before committing** — see V9 in Section 4.0.1.

### 5.1 The scripts

| Script | Responsibility |
|---|---|
| `run-static-evals.*` | Takes a base ref. Runs D1–D7 on base and HEAD, diffs the finding sets on `(rule-id, file, message)` — never line numbers — counts only NEW findings on changed files against the `tests/.evals/config.json` thresholds, reports pre-existing findings as non-blocking info. **The local Static Eval Gate and CI both call THIS** — the diff logic exists once (Section 4.0b). |
| `run-evals.*` | Computes the **J1/J2 judge gates** (Section 5.2) and merges them with the deterministic results into `eval.json` + `eval-summary.md`. Exits non-zero on any failed gate or sub-minimum score. |
| `auto-fix-agent.*` | Read `tests/.evals/_run/failed-gates.txt` (**primary** — Section 6.5) plus the failing steps' logs; `eval.json` is supplementary and never a precondition. Triage per Section 6.4, build a precise repair brief (which gate, which file:line, which rubric criterion), invoke the Claude Code CLI, verify the fix re-runs green, commit and push. Enforces `retryLimitForSelfRepair`. |

🔴 All three are **committed to the repo**, not fetched at runtime. A CI gate whose logic lives outside
the repo cannot be reviewed and cannot be reproduced locally.

🔴 **Make them runnable.** Set the executable bit in git
(`git update-index --chmod=+x tests/.evals/scripts/<name>`) **and** invoke them with an explicit interpreter
in the workflow (`run: bash tests/.evals/scripts/<name>.sh`). Either alone is fragile: the bit is lost when
someone recreates the file, and a missing interpreter breaks a non-`.sh` script. Doing both survives
`Permission denied`.

### 5.2 🔴 How `run-evals.*` actually scores J1 and J2

**This is the part that gets stubbed if it is not spelled out.** J1/J2 are LLM judgements, so the
script needs a model call — headless, non-interactive, in a runner with no TTY.

**Mechanism**: the same Claude Code CLI the repair job uses (Section 6). Resolve its headless and
permission flags with `claude --help` at generation time — 🔴 never from memory (Section 6.0).

The script must:

1. **Collect the inputs**: the PR diff (`git diff <base-sha>...HEAD`), `tests/.evals/rubrics/architecture-rubric.json`,
   `tests/.evals/rubrics/security-rubric.json`, and the thresholds from `tests/.evals/config.json`.
2. **Invoke the judge once per rubric**, instructing it to score **each criterion independently** and
   return **strict JSON only** — no prose — in this shape:
   ```json
   { "score": 0.91,
     "criteria": [
       { "id": "ARCH-01", "weight": 0.40, "score": 1.0 },
       { "id": "ARCH-02", "weight": 0.35, "score": 0.8,
         "citation": "src/api/billing.ts:88", "note": "direct ORM call in handler" }
     ] }
   ```
3. **Enforce the scoring discipline** from `common/eval-framework.md` Section 4.1 in the prompt: score
   once, never re-roll; every criterion below 1.0 **must** cite `file:line`; score only what the diff
   shows; a criterion the diff cannot exercise is `N/A` and is excluded with remaining weights
   renormalised to 1.0 — never scored 0.
4. **Validate the response**: it must parse as JSON, carry every criterion id from the rubric, and have
   weights summing to 1.0. 🔴 A malformed or unparseable response is an **ERROR**, not `N/A` — retry
   once, then fail the job.
5. **Compare against the thresholds** and write the result into the **`gates`** block of `eval.json`,
   with the per-criterion breakdown, the pinned judge model and the `rubricVersion`.
6. **Exit non-zero** when `J1 < llmJudgeArchitectureScoreMin` or `J2 < llmJudgeSecurityScoreMin`.

**The only legitimate `N/A` for J1** is the `eval-framework.md` Section 3 fallback chain bottoming out —
no `architecture.md`, no prior rubric, nothing derivable from Atlas or the RE artifacts. Record which
link failed. 🔴 Missing credentials is **ERROR**, never `N/A`: the gate should have run.

**If the rubric file is absent**, say so and fail — do not silently pass. A missing rubric means the
STOP CHECKPOINT did not complete, which is a real problem worth surfacing.

---

### 5.3 🔴 THE EVIDENCE PATH CONTRACT — write and read must be the same path

Every script and every workflow step agrees on **one** layout. These paths are **normative**: a script
that invents its own, or reads from a different directory than it wrote to, produces a gate that
silently reports `N/A` forever while looking healthy.

```text
reports/eval-evidence/<EVAL_KEY>/
├── eval.json                              <- the scorecard.  NOT one level up.
├── eval-summary.md                        <- pasted into the PR body
├── static/
│   ├── baseline/                          <- pre-change tool output
│   └── <tool>-post.<ext>                  <- post-change tool output
└── judge/
    ├── architecture-score.json            <- J1.  Read it from judge/, not from the parent.
    └── security-score.json                 <- J2 (OWASP 2025)
```

**The three mistakes this contract exists to prevent** — all observed in a real generated pipeline:

| Bug | Symptom |
|---|---|
| Judge files written to `<key>/judge/` but read from `<key>/` | J1/J2 **always** `N/A — judge did not run`, even with valid credentials and a working judge |
| `eval.json` written to `<key>/../eval.json` | Self-repair reports *"No eval.json found — nothing to triage"* and repairs nothing |
| A directory written to without `mkdir -p` | `No such file or directory` on the first CI run, where nothing pre-exists |

🔴 **Every script creates every directory it writes to** (enforced by **V12**):
`mkdir -p "$EVIDENCE_DIR/static/baseline" "$EVIDENCE_DIR/judge" tests/.evals/_run`. A local run works only
because earlier runs left the folders behind; CI starts from a clean checkout and does not.

#### 5.3.1 🔴 `EVAL_KEY` is a work-unit slug, never a branch ref

```yaml
  EVAL_KEY: "${{ github.head_ref }}"        # 🔴 WRONG - "story/2-frontend-upgrade-cta"
```

A branch ref **contains a slash**, so `reports/eval-evidence/${EVAL_KEY}` silently becomes a nested
`reports/eval-evidence/story/2-frontend-upgrade-cta/` — a different location from the `reports/eval-evidence/story-2/`
the local gates wrote. Every downstream reader then finds nothing, and reports it as an absence rather
than a mismatch.

**Derive the key from the work unit, and make it filesystem-safe:**

```yaml
      - name: "Resolve EVAL_KEY"
        id: evalkey
        run: |
          # branch: story/2-frontend-... -> key: story-2
          ref="${{ github.head_ref }}"
          key="$(printf '%s' "$ref" | sed -E 's#^(story|bug|enh)/([^-]+).*#\1-\2#')"
          case "$key" in */*|"") echo "EVAL_KEY unresolved from '$ref'" >&2; exit 1 ;; esac
          echo "key=$key" >> "$GITHUB_OUTPUT"
```

🔴 **Fail loudly if the key still contains `/` or is empty.** A malformed key must stop the run, never
fall through to `unknown` — `reports/eval-evidence/unknown/` is how a whole cycle's evidence gets orphaned.
The key CI computes MUST equal the key the local gates used; they address the same directory.

#### 5.3.2 🔴 Never hardcode a gate result the script did not compute

```python
"D1_lint":       {"status": "N/A"},          # 🔴 WRONG - the static script measured it
"unitCoverage":  {"status": "N/A", "reason": "measured by the workflow's own step"},   # 🔴 WRONG
```

A gate is `N/A` only when it genuinely does not apply (Section 5.0). If another step computed it,
**read that step's output and report the real result** — `run-static-evals.*` writes a machine-readable
summary precisely so `run-evals.*` can merge it. Marking five of seven D-gates `N/A` because the
script did not bother to read them turns the scorecard into decoration.

#### 5.3.3 The scorecard is published from the evidence directory

```yaml
      - name: "Stage 4: publish scorecard"
        if: always()
        run: |
          SUMMARY="reports/eval-evidence/${{ steps.evalkey.outputs.key }}/eval-summary.md"
          if [ -f "$SUMMARY" ]; then cat "$SUMMARY" >> "$GITHUB_STEP_SUMMARY"
          else echo "::error::No eval-summary.md at $SUMMARY - the eval step did not produce one." ; fi
```

🔴 **Never look for `eval-summary.md` at the repo root** — nothing writes it there. And a missing
summary is an **error to surface**, not a neutral "none produced this run" note: it means Stage 3 did
not complete.

#### 5.3.4 Verification before committing — the round trip

**V17**: run each script once and assert that **every artifact the contract declares exists at the
declared path**, then assert each consumer reads the same path it was written to. Concretely: after
`run-evals.*`, `eval.json`, `eval-summary.md` and both `judge/*.json` must exist under
`reports/eval-evidence/<EVAL_KEY>/`, and `eval.json` must contain a real J1/J2 status — not
`"judge did not run"` when credentials were present.

🔴 A write/read path mismatch passes V1–V16 completely: the YAML parses, the scripts exist and are
executable, the job goes green. Only the round trip catches it.

---

## 6. The CI self-repair agent — the CLI, not the marketplace action

🔴 **Run Claude Code through the generated `tests/.evals/scripts/auto-fix-agent.*` script, using the CLI.
Do NOT use `anthropics/claude-code-action`.**

**Why.** The marketplace action runs with elevated permissions, so GitHub enforces that the workflow
file on the PR branch is **byte-identical to the copy on the default branch**:

```
Workflow validation failed. The workflow file must exist and have identical
content to the version on the repository's default branch.
```

That guard is correct and unavoidable — but it means the action **cannot run on the very PR that
introduces or edits the pipeline**, which is exactly the first cycle in every repository. The CLI has
no such guard: it is an ordinary command in an ordinary step, so self-repair works from the first PR,
on any branch, including the one that created the pipeline.

It is also consistent with the rule already stated in Section 5 — CI logic lives in a committed,
reviewable script that can be reproduced locally — and it removes the need for `id-token: write`
entirely, since there is no OIDC exchange.

### 6.0 🔴 Resolve the CLI flags at generation time — never from memory

CI has **no TTY and no human to approve a tool call**. A headless agent run without the correct
permission flags either hangs until the job times out or completes having changed nothing — and both
look identical to "self-repair ran and found nothing to fix", which is the worst possible failure mode.

Before writing `auto-fix-agent.*`, **run `claude --help` and read the current flags** for:

- print / headless mode (no interactive session)
- permission handling (how tool calls are approved without a human)
- allowed tool restriction (limit it to file edits and the test commands)

Write the resolved flags into the script with a comment naming where they came from, e.g.
`# flags resolved from `claude --help`, CLI vX.Y`. 🔴 Never copy flag names from this document or from
memory — they change, and a wrong flag fails silently.

**Scope the permissions.** The runner is ephemeral, so broader permissions are more defensible there
than on a developer machine — but still restrict the agent to editing the repo and running the
project's own test commands. It must never need network write access or credentials beyond the ones
the job already holds.

**Verify the run did something.** After the CLI exits, the script checks `git status --porcelain`.
No changes plus a zero exit code means the agent made no edits — report that explicitly as
"self-repair produced no changes" rather than letting the job look successful.

```yaml
  self-repair:
    needs: verify-and-evaluate
    if: |
      failure() &&
      github.event.pull_request.head.repo.full_name == github.repository
    runs-on: ubuntu-latest
    permissions:
      contents: write          # push the repair commit
      pull-requests: write     # comment the outcome
                               # no id-token needed — the CLI does not use OIDC
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.ref }}
          fetch-depth: 0
      - uses: actions/download-artifact@v4
        with: { name: eval-results }

      # ── Install the SAME runtimes and tools as the verify job ──
      # These steps MUST mirror the verify job's setup exactly.
      # Without them, the re-verification after the fix will fail or skip.
      - name: "Set up runtimes"
        # GENERATE: the same setup-node/setup-python/setup-go steps as verify
      - name: "Install project dependencies"
        # GENERATE: the same pip install / npm ci / mvn install as verify
      - name: "Install eval tools"
        # GENERATE: the same semgrep, gitleaks, pip-audit, etc. as verify

      - name: "Install Claude Code CLI"
        run: npm install -g @anthropic-ai/claude-code@<resolved-version>   # PINNED — Section 6.0.2

      - name: "Autonomous self-repair"
        env:
          # 🔴 Emit ONLY the variable whose secret is actually configured. An unset
          #    secret expands to an EMPTY STRING, and an empty credential is worse than
          #    an absent one: the SDK sees the variable, tries it, and fails with an auth
          #    error instead of falling through to the other mechanism.
          CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
        run: bash tests/.evals/scripts/auto-fix-agent.sh
```

🔴 **The `# GENERATE:` comments above are NOT placeholders to leave in the committed YAML.** They
are instructions to the pipeline generator: resolve each one to the actual commands for this project's
stack (from Section 3), identical to the verify job's steps. A committed pipeline with `# GENERATE:`
comments fails V14. To keep them in sync, extract the shared install steps into a reusable composite
action or duplicate them verbatim — never paraphrase or abbreviate.

`auto-fix-agent.*` installs the CLI (`npm i -g @anthropic-ai/claude-code`, pinned), triages the
failure per Section 6.4, builds the repair brief from `eval.json` and the logs, and invokes Claude Code
non-interactively with the brief below, then verifies, commits and pushes.

### 6.0.1 🔴 `auto-fix-agent.*` script requirements — the defects that look like success

These are the exact bugs that produce a green self-repair job that repaired nothing. Each one
was hit in production and must be prevented at generation time.

1. **`EVAL_KEY` must resolve to the same key `eval.json` was written under.** The verify job writes
   evidence to `reports/eval-evidence/<key>/eval.json` where `<key>` is
   `story-N.M`, `bug-<ID>`, or `enhancement-<ID>` — read from the Story Tracker or the ticket ID.
   The self-repair job must find it at the same path. 🔴 **Never derive the key from
   `github.head_ref`** (the branch name) — branch names do not match evidence keys. Instead, pass
   the resolved key as a workflow-level `env:` variable set in the verify job and consumed by
   self-repair, or have `auto-fix-agent.*` discover it by searching for `eval.json` under the
   evidence root.
2. **`mkdir -p` every directory before writing.** The script uses counter files (e.g.
   `tests/.evals/_run/self-repair-attempt`) to track the retry budget. If the directory does not exist,
   the write fails and the script exits before reaching the repair logic — reporting "nothing to
   triage" when the real problem is a missing directory.
3. **"No eval.json found" is not a free pass.** If `eval.json` is absent AND the verify job failed,
   the script must **exit non-zero** with a clear message ("eval.json missing — cannot triage the
   failure; the verify job's evidence was not produced or not uploaded"). Exiting 0 hides a real
   failure behind a green job.
4. **After each repair attempt, re-run the full eval locally** before committing. Run
   `run-static-evals.*` and `run-evals.*` inside the repair job and confirm the failing gate is now
   green. A commit that does not re-verify is guessing, and a push that fails the next CI run wastes
   a retry attempt on nothing.
5. **Set a git identity before committing.** A fresh GH Actions runner has no `user.name`/`user.email`
   configured, so `git commit` fails outright — `"Author identity unknown... fatal: empty ident name"`
   — even after a fully correct repair that already re-verified green. `git config --local user.name
   "aire-self-repair"` + `user.email "aire-self-repair@localhost"` (scoped `--local`, never `--global`)
   before the commit, same bot-identity convention as `smoke-test-epic.*`'s `aire-ci-smoke` commits.
   Observed in production: self-repair diagnosed and fixed the real bug, re-verified 45/45 tests green,
   then wasted the entire attempt on a commit that never had anywhere to go.
6. **`git status --porcelain` alone cannot detect "the agent made no changes"** once the BRIEF tells
   Claude to commit its own fix — Claude has git tool access and will follow that instruction literally,
   leaving a clean working tree that looks identical to a genuine no-op. Capture `HEAD` before invoking
   `claude`; only a clean tree **and** an unmoved `HEAD` means nothing happened. Symmetrically, the
   script's own commit step (rule 4) must not assume there is always something left to stage — if Claude
   already committed everything, `git commit` with nothing staged fails outright and must be skipped, not
   treated as a repair failure. And the BRIEF's own "prove it green" instruction must never ask Claude to
   re-run a gate that requires a **nested** `claude` invocation (J1/J2): Claude's Bash tool sandboxes its
   subprocesses and does not propagate `CLAUDE_CODE_OAUTH_TOKEN`/`ANTHROPIC_API_KEY` into a `claude` call
   it shells out to itself, so that nested call always reports "not logged in" — expected sandbox
   behaviour, not a missing secret, and not something worth Claude spending its turn on. Observed in
   production: self-repair correctly fixed lint and coverage, committed them itself, then the wrapper's
   own dirty-tree check reported "produced no changes... PR stays red" and exited before ever pushing the
   real fix — while Claude's summary separately (and misleadingly) reported the J1 gate as blocked by
   missing credentials that were, in fact, present the entire time at the job level.

**The repair brief — non-negotiable rules, passed verbatim:**

```
The agentic eval pipeline failed on this PR.
Read eval.json and the attached logs. Fix ONLY what failed.
Rules (non-negotiable):
  - Never delete, skip or weaken a test to go green.
  - Never suppress a finding (eslint-disable, # nosec, # type: ignore, ignore-lists).
  - Never lower a threshold in tests/.evals/config.json or edit a rubric.
  - Never edit spec/plans/architecture.md to make the J1 gate pass.
  - Never edit sonar-project.properties or the Quality Gate to pass a Sonar finding.
  - Fix the code. If the failing gate is something you can run yourself (lint, a unit test, a build
    command), re-run it and confirm it is green.
  - Do NOT try to invoke or re-run the J1_architecture / J2_security judge gates yourself. Scoring
    them means shelling out to claude again from inside your own tool call, which cannot authenticate
    (credentials do not propagate to a nested claude invocation) — that failure is expected, not a bug
    worth reporting. This script re-verifies J1/J2 for real after your turn ends; just fix the cited
    criteria/citations from eval.json and stop.
Commit with:  fix(ci): self-repair attempt <n> — <gate>
```

**If the team prefers the marketplace action anyway**: it is a valid choice, but generate it with
`id-token: write` added to `permissions:`, and warn plainly that self-repair stays inert until the
workflow file reaches the default branch (Section 2.1).

### 6.0.2 🔴 Pin the Claude Code CLI version — flags resolved today can break on any future run

Resolving flags from `claude --help` "at generation time" (Section 6.0) only holds if the CLI version
that generated them is the version every future run actually installs. `npm install -g
@anthropic-ai/claude-code` with **no version pin** breaks that: this package ships **multiple releases
per day**, so an unpinned install can silently resolve to a different CLI version on any later run —
including one where a flag was renamed or removed — with **zero code change in the repo**. This is the
exact same class of drift Section 3.2.1 already warns about for eval-tool dependencies ("same tool pin,
same code, different result a week later"), just for the CLI itself instead of a transitive package.

**Observed failure**: `--restricted` (verified valid against one CLI version at generation time) later
failed with `error: unknown option '--restricted'` in a CI run that installed a different, unpinned
version of the same package.

**Rule**: resolve `${CLAUDE_CODE_VERSION}` (`npm view @anthropic-ai/claude-code version`, or an
explicit pin the team chooses) at the **same moment** `claude --help` is read to resolve the
`CLAUDE_REPAIR_INVOCATION`/`CLAUDE_JUDGE_INVOCATION` flags — never at a different time, and never left
unpinned. Both `- name: "Install Claude Code CLI"` steps (`verify-and-evaluate` and `self-repair`) use
`npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}`, the identical pinned version, so the
resolved flags and the installed CLI always correspond to each other. Re-resolve both together — never
bump one without checking whether the other now needs to move too (mirrors the runner/runtime
discipline in `behavior-spec.md` Section 5.2.1).

### 6.1 Obtaining and configuring the token

Include this verbatim in the completion announcement — the pipeline cannot self-repair without it:

```
CI secrets required
   CLAUDE_CODE_OAUTH_TOKEN   run `claude setup-token` locally, then add it at
                             Settings > Secrets and variables > Actions > New repository secret
   ANTHROPIC_API_KEY         alternative to the OAuth token, for both the judge and self-repair
   SONAR_TOKEN + SONAR_HOST_URL   SonarQube; AIRE prompts for these at the Section 4.1.2 setup gate

   Without one of the first two, the gates still run and still block. Only the
   automatic self-repair job is skipped.
```

### 6.2 Retry limit and its relationship to local self-healing

- CI self-repair is capped by **`retryLimitForSelfRepair`** in `tests/.evals/config.json` (default **3**),
  counted as commits tagged `fix(ci): self-repair attempt <n>` on the PR head.
- 🔴 **This is a separate budget from the local SH-LOOP counters.** A local loop that exhausted its 3
  attempts halts locally and never reaches CI; CI's 3 attempts apply to failures that appear only in
  the CI environment.
- **On exhaustion**: stop, post a PR comment naming every unresolved gate, what each attempt changed,
  and why it did not resolve — closing with *"3 retries ended. Please suggest next steps."* Do not
  push further commits. Do not close or merge the PR.
- 🔴 **Never let the self-repair job pass the build.** It repairs and re-runs; the verify job's own
  result is the only thing that turns the PR green.
- 🔴 **The two budgets are also never spent on the same failure.** Which agent owns a given red run is
  decided by Section 6.4's triage class and enforced by **Section 6.6** — the local workflow owns CI
  configuration and provisioning, self-repair owns code, and neither pushes into the other's in-flight
  repair on the shared PR head.

### 6.3 Safety rails on the repair job

- Skips on **fork PRs** (secrets are unavailable and untrusted code must not run with write scope).
- `permissions:` is the minimum shown — never `write-all`. With the CLI, `id-token` is **not** needed;
  add it only if the team chose the marketplace-action variant.
- Never force-pushes; never touches any branch other than the PR head.
- Every attempt is one commit, so the whole repair history is reviewable in the PR.
- 🔴 Triage before repairing (Section 6.4). An infrastructure failure is never a code defect.

### 6.4 🔴 TRIAGE BEFORE REPAIRING — not every red job is a code defect

The job fails when **any** gate's outcome is `failure` (Section 4.0c), so self-repair is reached from
several very different causes. **Classify first. Repair second.** An agent that starts editing source
because a token expired does real damage.

| Failure | Class | Self-repair |
|---|---|---|
| D1–D7 **new** findings on changed files | Code |  Repair |
| Unit test failure or coverage below the floor | Code |  Repair |
| Behaviour (Gherkin) scenario failing | Code |  Repair |
| API-contract or regression failure | Code |  Repair |
| J1 / J2 below the configured minimum | Code |  Repair the cited criteria |
| **SonarQube Quality Gate failed WITH reported conditions** (e.g. *"C Reliability Rating on New Code"*) | Code |  Repair — these are real findings on new code |
| **SonarQube auth / unreachable / timeout / missing or wrong `sonar.organization`** | Infrastructure |  **Never** — report and stop |
| Workflow-validation failure (Section 2.1) | Infrastructure |  **Never** |
| Missing secret, runner or network error, dependency-install failure (e.g. `pip`/`npm` reports `ResolutionImpossible` or a conflicting-dependencies error between two pinned tools) | Infrastructure |  **Never** — the fix is re-pinning the tool set correctly and re-running `validate-pipeline.{sh,ps1}`'s V25 check, not editing application code |
| **A gate ERRORs because its tool is not installed on the runner** (`tool 'ruff' for gate D1_lint is not installed on this runner`), **or a test/coverage command errors on a dependency the repo never declared** (`RuntimeError: … requires the httpx package`, `ModuleNotFoundError`, `Cannot find module`) — the tool/package existed in the developer's ambient environment and was never recorded in `tools` + `toolInstallCommands` or in the repo's own dependency declaration | **Manifest / provisioning** |  **Never** — writing the missing tool into a workflow step, or `pip install`-ing it from inside a script, patches the symptom in the one place that is not the source of truth. Report which gate/root and which binary or package, then stop. The owning workflow fixes the declaration on its next push — and **Section 4.0i's preflight gate is supposed to have caught this before the PR existed** |
| **A `ci.roots[]` entry's `cd` target does not exist, or exists but is missing its declared `markerFile`** (Section 4.0d) — the recorded root no longer matches a real project directory, most often because a rename/move happened after the manifest was last resolved | **Manifest** |  **Never** — the fix is correcting `tests/.evals/config.json`'s `ci.roots[]` (or re-running the owning work unit's reconciliation), never editing application source. Report which root failed and why, then stop |
| **A gate reports `N/A`, or reports zero analysed files, while the PR's own diff contains files the manifest's `sourcePaths`/`testPaths` should have matched** — the manifest never learned about a path this story actually touched | **Manifest** |  **Never** — same disposition as the row above: report and stop. This is the general detection signal for a stale or incomplete manifest, distinct from a directory that is simply missing |
| **The test runner exited with the root's declared `ci.roots[].noTestsExitCode`** — it collected ZERO tests (pytest `5`, jest/vitest `1`). Normal on a greenfield repo before its first story, and on a brownfield repo with no suite yet | **Not a failure at all** |  **Never reaches triage.** `ci-manifest-runner.*` records it `N/A` and returns 0. 🔴 Writing a test to make this "pass" is a fabricated pass (SH-6) — observed in production, where self-repair spent ~45 minutes authoring DUMMY TESTS on a repo that simply had no suite yet, which then merged and poisoned the regression baseline every later work unit is diffed against. The delta-scoped coverage gate still fails a work unit that ships code without tests, so nothing is hidden |
| **ANY failure on the epic-level smoke PR** (head branch `ci/epic-smoke-*`, Section 4.0.6) | **Environment — the Code class is EMPTY here by definition** |  **Never a code repair.** A zero-diff PR has no code delta, so no failure on it can be caused by application code. CI infrastructure may be repaired (`.github/workflows/**`, `tests/.evals/scripts/**`, `tests/.evals/behavior/**`, tool pins); `src/**` and `tests/**` (outside `tests/.evals/**`) are off-limits and `auto-fix-agent.*` **aborts before pushing** if they were touched. This matters more, not less, because the smoke watch loop is deliberately unbounded |
| **`D7_secrets` finding(s) all anchored to a commit already pushed to `origin`** (gitleaks' own `--log-opts BASE..HEAD` scans each commit's patch, not the final tree — a forward commit can never edit an already-pushed commit's own patch) | History-rewrite-required (neither pure code nor infrastructure) |  **Never via forward commit** — commit any OTHER real fixes made in the same attempt (never discard those), report the D7 finding plainly, and stop; only a human-approved rebase + force-push, or a scoped gitleaks allowlist entry for that exact fingerprint, resolves it |

**Telling the two SonarQube cases apart, mechanically**: `sonarqube-quality-gate-action@v1` itself only
ever outputs `PASSED`/`WARN`/`FAILED` — it never exposes the underlying failed conditions as a GitHub
Actions output. `auto-fix-agent.*`'s triage (`case sonar) ... if [ -s "${RUN_DIR}/sonar-conditions.txt"
]`) depends on that file actually existing and being non-empty ONLY when real conditions were reported
— **the "Record SonarQube gate status" step must populate it**, by querying the SonarQube Web API
directly (`api/qualitygates/project_status?analysisId=...`, resolved from the scan step's own
`.scannerwork/report-task.txt`) when the gate outcome is a failure. 🔴 **If nothing ever writes this
file, every Sonar failure is silently misclassified as infrastructure, even a genuine coverage/bug/smell
finding** — this was an observed real defect, not a hypothetical one: self-repair reported *"sonar
failed WITHOUT reported conditions (auth/unreachable/timeout) — infrastructure, not a code defect"* on
a PR where the Quality Gate had genuinely failed on real new-code coverage, because nothing had ever
populated the file the triage reads. Conditions present in that file → real findings, repair them. An
error *before* evaluation — `401`/`403`, host unreachable, project not found, the `timeout-minutes`
expiring, or the API query itself returning nothing — means the gate never ran, or its real cause
could not be resolved; there is nothing to repair.

🔴 **TRIAGE RUNS BEFORE THE RETRY COUNTER IS TOUCHED.** A non-repairable class must cost nothing, so
`auto-fix-agent.*` classifies first and only then increments `tests/.evals/_run/self-repair-attempt`.
Incrementing first — the original order — silently burned an attempt on every infrastructure failure.

🔴 **The Manifest class is detected from a MARKER FILE, never from a log grep.** `lib-manifest.*` appends
every Manifest-class defect to `tests/.evals/_run/manifest-defects.txt`; `auto-fix-agent.*` reads that file.
stderr is interleaved, truncated and locale-dependent — a marker file is none of those. Before this existed
the `MANIFEST DEFECT` string was emitted by three scripts and **consumed by none**, so a stale `ci.roots[]`
entry was triaged as a code defect and self-repair edited application source to fix a configuration bug.

🔴 **Division of labour, stated once**: **self-repair fixes CODE; the owning implement workflow owns
`ci.roots[]`** (its manifest-reconciliation step, on its next push). Neither ever edits the other's territory.
**Section 6.6 makes that operational** — exclusive territories, who owns which triage class, and the
no-concurrent-push rule that keeps two repair agents off the same PR head at the same time.

🔴 **A missing eval tool or a missing test dependency is a MANIFEST/provisioning failure, never a code
defect** — `tool 'ruff' … is not installed on this runner`, `RuntimeError: … requires the httpx package`,
`ModuleNotFoundError` on a package the declaration never named. Self-repair **never** repairs these: it
reports and stops, burning no attempt, and the owning workflow fixes the declaration. And it should
almost never see them at all — **Section 4.0i's preflight gate catches this whole class on the
developer's machine, before the PR exists.**

🔴 **An Infrastructure or Manifest failure never consumes a `retryLimitForSelfRepair` attempt**, never
enters `eval.json` as a gate result, and never triggers a source edit. Post one clear PR comment naming
the cause and what the user must fix, then stop. **The division of labour is exact: self-repair fixes
code; the owning implement workflow's own reconciliation step owns `ci.*`** — a Manifest failure is
handed back to that workflow's next push, never patched from inside the CI job.

🔴 **Never "fix" a Sonar finding by editing `sonar-project.properties`, changing the Quality Gate,
lowering a condition, or marking an issue Won't Fix.** That is suppression (SH-6) and is forbidden — fix
the code, or report that it cannot be fixed automatically.

**Telling the D7 history-anchored case apart, mechanically**: after a repair attempt re-verifies and
`D7_secrets` is the ONLY gate still failing, `auto-fix-agent.*` reads that gate's `gitleaks-delta.json`
(each finding records the `Commit` SHA whose patch it matched) and runs `git merge-base --is-ancestor
<commit> origin/<branch>` for every one. If ALL of them are already ancestors of the remote branch —
i.e. they were pushed before this attempt even started — no forward commit can retroactively edit that
history, so the script commits and pushes whatever else it genuinely fixed and reports the D7 finding
plainly rather than either discarding real progress or silently pretending the gate passed. If even one
finding's commit is NOT yet on `origin` (still part of this attempt's own unpushed work), or if anything
besides `D7_secrets` is still failing, this exception does NOT apply — treat it as ordinary unresolved
code-class work per rule 4 above (re-verification must pass before committing).

---

### 6.5 🔴 SELF-REPAIR'S INPUT CONTRACT — it is GIVEN the failure, it does not hunt for it

**Order of inputs, and what each is allowed to do:**

| Input | Role | If missing |
|---|---|---|
| `tests/.evals/_run/failed-gates.txt` (from the Verdict step) | **PRIMARY.** The authoritative list of what failed. | 🔴 **Pipeline defect.** Report it and exit **non-zero**. The Verdict step must always produce it. |
| The failing steps' **logs** | Primary detail — the actual error text to repair against | Report what is missing; continue with what is available |
| `reports/eval-evidence/<EVAL_KEY>/eval.json` | **SUPPLEMENTARY** context: per-criterion scores, citations | 🔴 Continue anyway. See below. |

🔴 **`eval.json` is NOT a precondition for repairing.** The build failed; that fact is established by
the Verdict step, not by the scorecard. If `eval.json` is absent or unreadable, repair from
`failed-gates.txt` plus the logs — and report the missing scorecard as a **separate finding**.

🔴 **"I could not find my input" is NEVER an infrastructure failure of the build.** Observed in a real
run:

```
No eval.json found at .../eval-evidence/story/2-frontend-.../eval.json — nothing to triage.
Treating as infrastructure failure, not repairing.
```

Three things wrong with that, all forbidden:

1. It **misclassified** a real SonarQube code failure as infrastructure (Section 6.4 triages the
   *failure*, never the agent's own inability to locate a file).
2. It **exited 0**, so a job that should have stayed red reported success.
3. It **stopped**, when `failed-gates.txt` and the step logs both said plainly what had failed.

**The correct behaviour**: read `failed-gates.txt`, see `sonar`, triage it per Section 6.4 (conditions
were reported → code-class), repair the reliability findings, re-run, commit.

🔴 **Self-repair NEVER exits 0 on a job it did not repair.** Exit 0 means "the failure was addressed".
Anything else — could not classify, could not locate its inputs, chose not to act — exits **non-zero**
with the reason, so the PR stays red.

---

### 6.6 🔴 ONE WHEEL AT A TIME — the local workflow and CI self-repair never repair the same PR head at once

Section 6.4 states the division of labour in one line. This section makes it operational, because the
two repair agents **share a single PR head branch** and, left unsynchronised, they overwrite and
re-trigger each other. Observed: CI failed on missing eval tools and missing test dependencies; the CI
self-repair job triaged and started work; the local `dev-implement` run, watching the same PR, started
its own repair of the same red run. Both pushed to the same head, each push re-triggered the pipeline,
and the entire exchange was spent on a class of failure that neither side owned outright.

**Territory — exclusive, not "preferred":**

| | Local implement workflow (post-PR) | CI self-repair (`auto-fix-agent.*`) |
|---|---|---|
| Owns | **CI configuration and provisioning**: `tests/.evals/ci-manifest.d/<unit>.json`, the repo's own dependency declarations, `.github/workflows/**`, `tests/.evals/scripts/**`, `tests/.evals/config.json`, `tests/.evals/rubrics/**`, tool pins | **Application code and tests**: `src/**` (or the recorded `## Code Root`) and `tests/**` outside `tests/.evals/**` |
| Triage classes it repairs | **Manifest** + the provisioning half of **Infrastructure** (a missing tool/dependency declaration is a declaration bug) | **Code** — every row in Section 6.4 marked *Repair* |
| Never touches | Application source or tests, in response to a CI failure | `.github/workflows/**`, `tests/.evals/config.json`, `tests/.evals/rubrics/**`, `tests/.evals/ci-manifest.d/**`, `spec/**` — enforced, not merely instructed (**V33**) |
| Budget | The workflow's own 3-attempt loops (`dev-implement` SH-LOOP-9 for preflight, SH-LOOP-10 for the CI Attestation Gate — both governed by the SELF-HEALING RETRY POLICY: per-loop counter, SH-3 attempt logging, SH-4 exhaustion halt) | `retryLimitForSelfRepair`, default 3 |

**Hand-off rules:**

1. **A CI failure has exactly one owner, decided by Section 6.4's class.** Code class → CI self-repair
   fixes it; the local workflow does **not** fix it, does not push a code change for it, and does not
   spend one of its own attempts on it. Manifest class (and a provisioning/Infrastructure failure) →
   `auto-fix-agent.*` posts one PR comment, **burns no attempt**, and stops; the local workflow's next
   push carries the fix.
2. **The local side never pushes into an in-flight repair.** Before pushing anything to a PR head it is
   watching, the implement workflow checks for a self-repair job that is `queued` or `in_progress` on
   that head (`gh run list --branch <head> --json status,name`) and for any commit tagged
   `fix(ci): self-repair attempt <n>` newer than its own local `HEAD`. If either is true it **waits for
   that run to conclude, then `git fetch` + rebase onto it** and re-reads the result before deciding
   anything. Never force-push; never revert self-repair's commit to apply its own.
3. **Neither side re-litigates the other's conclusion.** A gate self-repair already fixed is not
   re-fixed locally, and a declaration the local side corrected is not "improved" by self-repair on the
   next run.
4. **The budgets are independent and neither resets the other** (Section 6.2). Two agents, two counters,
   two exhaustion reports — and an exhausted local loop halts locally without ever reaching CI.
5. 🔴 **Preflight (Section 4.0i) is what makes this rule cheap.** The provisioning class — missing eval
   tools, missing test dependencies, a stale `sourcePaths` — is exactly the class that used to arrive at
   CI, fail every gate, reach self-repair, get correctly refused as not-its-territory, and come back to
   the local workflow anyway. Caught at preflight it costs one clean-room run on the developer's
   machine and never enters the shared branch at all.

---

## 7. Relationship to the local gates — 🔴 CI adds, it never replaces

| | Local (`dev-implement`) | CI (this pipeline) |
|---|---|---|
| When | Before the PR is raised | On every PR push |
| Gates | D1–D7, unit+coverage, behavioural, API contract, regression, J1, J2 | D1–D7, unit+coverage, behavioural, J1, J2 — 🔴 **API contract and regression are local-only**; CI runs each touched root's full test command, but has no baseline diff to attribute a failure to this work unit |
| Self-heal | SH-LOOP-1…9, 3 attempts each | `retryLimitForSelfRepair`, 3 attempts |
| Repairs | **CI configuration + provisioning** (manifest fragment, dependency declarations, pipeline scripts) — and, before the PR exists, its own code via SH-LOOP-1…8 | **Application code and tests only** (Section 6.4 Code class, Section 6.6 territory table) |
| Authority | Blocks the PR from being raised | Blocks the PR from being merged |

🔴 **Nothing in this file changes the local gates or the local self-healing loops.** They keep their
definitions, their order and their budgets. CI is an outer ring: it re-verifies in a clean
environment what was verified on the developer's machine, and it is what branch protection can
actually enforce.

🔴 **The bridge between the two rings is the CI Preflight Gate (Section 4.0i).** "CI re-verifies in a
clean environment what was verified on the developer's machine" only holds if the developer's machine
verified it *in a clean environment too* — otherwise CI's first run measures the provisioning gap rather
than the code. Preflight runs CI's own entrypoints, from CI's own manifest, in a clean room, on the
committed work unit, **before the push** — so the first real CI run has a chance of being about the code.
After the PR exists, **Section 6.6** decides which ring owns each failure, so no failure is worked twice.

---

## 8. Completion announcement

```
 CI pipeline generated — .github/workflows/agentic-eval-pipeline.yml
   Stack: <detected>   Package manager: <detected>
   Commands resolved from: <package.json scripts | Makefile | pyproject.toml | pom.xml>
   Stage 1 (deterministic): <n> checks   SonarQube: [configured | awaiting secrets | skipped by user]
   Stage 2 (behavioural):   <runner> + coverage ≥ <unitTestCoverageMin>%
   Stage 3 (semantic):      J1 ≥ <min> · J2 ≥ <min>  — BLOCKING
   Verdict step:            the ONLY step that fails the job — tallies every gate
   Self-repair:             Claude Code CLI, max <retryLimitForSelfRepair> attempts
   Scripts written (executable + invoked with an explicit interpreter):
     tests/.evals/scripts/run-static-evals.<ext>  — D1–D7, delta vs base ref
     tests/.evals/scripts/run-evals.<ext>         — J1/J2 via the CLI, real scores
     tests/.evals/scripts/auto-fix-agent.<ext>    — self-repair
   Trigger:  PRs into <base-branch>, epic/**, bug/**, enh/**(Section 4.0a)
   Verified: V1 YAML parses | V2 actionlint | V3 scripts exist | V4 files exist
             V5 secrets listed | V6 permissions declared | V7 delta-scoped
             V8 failures isolated | V9 gates proven able to FAIL | V10 branches covered
    Secrets to add: <list>
    Pushed directly to <base-branch> (<commit>) — self-repair can run from the next PR onward.
      [or] Raised as PR <url> into <base-branch> — merge before dev-implement. Gates enforce either way.
```

Log the same in `runtime-artifacts/audit.md`, including the full list of resolved commands and their source, so a
reviewer can check that nothing was invented.
