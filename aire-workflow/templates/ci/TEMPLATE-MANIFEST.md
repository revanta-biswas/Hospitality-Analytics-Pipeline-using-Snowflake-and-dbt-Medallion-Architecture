# CI templates — the static, versioned source the generator COPIES

> These files are the canonical CI pipeline. The AIRE pipeline generator does **not** author YAML or
> shell any more — it **detects the stack, fills the `ci` manifest block in `tests/.evals/config.json`,
> copies these files into the target repo, and substitutes a small fixed set of `${SLOT}` markers.**
> That deletes the whole class of "the model re-wrote a constant and it drifted / broke the parser".
>
> Read `common/ci-pipeline-generation.md` Section 4 for the generation procedure and
> `common/eval-framework.md` Section 1 for the `ci` manifest schema these files read.

## What copies where

| Template | Copied to | Substitution |
|---|---|---|
| `agentic-eval-pipeline.yml.template` | `.github/workflows/agentic-eval-pipeline.yml` | `${SLOT}` markers only |
| `lib-manifest.sh` / `.ps1` | `tests/.evals/scripts/lib-manifest.{sh,ps1}` | none — the shared primitives (`build_merged_manifest`, `resolve_and_verify_root`, `root_touched`), sourced by every other script below. **#7a's foundation**: this is the ONE place the merge/verify/diff-scope logic lives |
| `read-manifest.sh` / `.ps1` | `tests/.evals/scripts/read-manifest.{sh,ps1}` | none — emits `has_<stack>`/`<stack>_version` for the generated workflow's `Read manifest` step |
| `ci-manifest-runner.sh` / `.ps1` | `tests/.evals/scripts/ci-manifest-runner.{sh,ps1}` | none — reads the merged manifest at RUN TIME and executes install/build/coverage per root, diff-scoped. What `${INSTALL_STEPS}`/`${BUILD_COMMAND}`/`${COVERAGE_COMMAND}` called until #7a; the generated workflow now calls this fixed script instead |
| `run-static-evals.sh` / `.ps1` | `tests/.evals/scripts/run-static-evals.{sh,ps1}` | none — reads the manifest |
| `run-evals.sh` / `.ps1` | `tests/.evals/scripts/run-evals.{sh,ps1}` | none — reads the manifest |
| `auto-fix-agent.sh` / `.ps1` | `tests/.evals/scripts/auto-fix-agent.{sh,ps1}` | none — reads the manifest |
| `validate-pipeline.sh` / `.ps1` | `tests/.evals/scripts/validate-pipeline.{sh,ps1}` | none — reads the manifest |
| `smoke-test-epic.sh` / `.ps1` | `tests/.evals/scripts/smoke-test-epic.{sh,ps1}` | none — reads the manifest. Run ONCE at the STOP CHECKPOINT (ci-pipeline-generation.md Section 4.0.6), never per story |
| `behavior/run.sh` | `tests/.evals/behavior/run.sh` | none |
| `behavior/Containerfile` | `tests/.evals/behavior/Containerfile` | `${SLOT}` for the base image |
| `sonar-project.properties.tmpl` | `sonar-project.properties` | `${SLOT}` markers only |

Ship the `.sh` variant for POSIX-primary repos and the `.ps1` variant for Windows-primary repos. Pick
by the repo's primary shell; when in doubt ship `.sh` (GitHub-hosted runners are Linux).

## The `${SLOT}` markers in `agentic-eval-pipeline.yml.template`

🔴 **#7a — the YAML holds NO stack facts.** `${SETUP_STEPS}`, `${INSTALL_STEPS}`, `${BUILD_COMMAND}`,
`${COVERAGE_COMMAND}` and `${SELF_REPAIR_SETUP_STEPS}` no longer exist. Every install/build/coverage
command and every `actions/setup-*` block is now **fixed text**, present in every generated repo
identically — the five slots that used to carry per-repo stack facts are replaced by:

- A **`Read manifest`** step (`bash tests/.evals/scripts/read-manifest.sh >> "$GITHUB_OUTPUT"`) that
  builds the merged manifest fresh, every run, and emits `has_<stack>`/`<stack>_version` for
  `node`/`python`/`java`/`go`/`dotnet`.
- **All five `actions/setup-*` blocks, permanently present**, each `if: steps.readmanifest.outputs.has_<stack>
  == 'true'`, using `steps.readmanifest.outputs.<stack>_version` for the pinned version. Nothing is ever
  added or removed from this file for a new stack — only **enabled**, by a fact the manifest already
  carries (`common/eval-framework.md` Section 1.1's `stack`/`runtimeVersion` fields).
- **`Install dependencies`**, **`Compile / build`** and (verify job only) **`Stage 2: unit + coverage`**
  each call the ONE fixed `tests/.evals/scripts/ci-manifest-runner.sh {install,build,coverage}
  "${{ steps.basesha.outputs.sha }}"` — which reads the merged manifest at RUN TIME (`config.json`'s
  `ci.roots[]` + every `tests/.evals/ci-manifest.d/*.json` fragment), iterates every root, diff-scopes
  it (`common/ci-pipeline-generation.md` Section 4.0g), verifies it (`cd`+marker check, Section 4.0d.1),
  and runs its command — or reports an earned `N/A`. `Install dependencies` also installs the merged,
  deduped eval tools from every root's `toolInstallCommands`, replacing the old separately-generated
  "Install eval tools" block.
- **This is byte-identical in the `self-repair` job** — there is no longer a separate
  `${SELF_REPAIR_SETUP_STEPS}` slot to keep in sync with the verify job's copy, because there is no
  per-repo generated text left in either job to diverge. Section 3.1's "same tools" rule is now
  structural, not a runtime check (validated by V27's structural-fidelity check instead of a separate
  slot-equality diff).

**A later work unit's brand-new root or stack** (a story that introduces the repo's first frontend code,
say) needs **zero edits to this committed workflow file** — its own `ci-manifest.d/<unit>.json` fragment
is enough; `Read manifest` and `ci-manifest-runner.sh` pick it up on that work unit's own PR, the very
first time they run. This is what #7a actually fixes: under the old model, a new root's install/build
commands were frozen at generation time and a human had to hand-edit the YAML to add them.

Only these two slots remain, because `on:` triggers cannot be dynamic:

| Slot | Filled from | Example |
|---|---|---|
| `${BASE_BRANCH}` | `ci.baseBranch` | `main` |
| `${PR_BRANCH_FILTERS}` | `ci.integrationBranchPrefixes` → one `- 'prefix/**'` line each | `- 'epic/**'` … |

Three more slots remain because they are **structural**, not stack, facts — SonarQube configuration, the
behaviour-tier image tag, and the pinned Claude Code CLI version are the same regardless of which stack
roots a repo has:

| Slot | Filled from | Example |
|---|---|---|
| `${BEHAVIOR_IMAGE_TAG}` | `tests/.evals/config.json` `behavior.image` | `aire-behavior:ci` |
| `${SONAR_STEPS}` | Section 4.1 — active block, or a commented skip note | see template |
| `${CLAUDE_CODE_VERSION}` | the exact `@anthropic-ai/claude-code` version resolved at generation time (`npm view @anthropic-ai/claude-code version`), the SAME moment `claude --help` is read to resolve the CLAUDE_REPAIR_INVOCATION/CLAUDE_JUDGE_INVOCATION flags (Section 6.0) — never `npm install -g @anthropic-ai/claude-code` unpinned. This package ships multiple releases per DAY; an unpinned install can silently resolve to a different CLI version than the one the flags were verified against, breaking a previously-working invocation with no code change in the repo (ci-pipeline-generation.md Section 6.0.2) | `2.1.258` |

🔴 After substitution, `validate-pipeline.{sh,ps1}` MUST pass before the file is committed. It greps for
any leftover `${` slot, runs `actionlint`, dry-runs the scripts, and asserts every `ci.gates[]` id
appears in both the verdict tally and the `eval.json` schema. A non-zero exit means NOT committed.

## The three script bugs these templates fix permanently

1. **`mkdir -p` precedes every write** — no more `No such file or directory` on a clean CI checkout.
2. **Self-repair never exits 0 on a real failure** — `failed-gates.txt` is the PRIMARY input; a missing
   `eval.json` is a supplementary-input finding, not a free pass.
3. **`EVAL_KEY` handles every integration prefix including `ci/**`** — the resolver reads
   `ci.integrationBranchPrefixes` and fails loudly (never falls through to `unknown`) if the key is
   still unresolved.
