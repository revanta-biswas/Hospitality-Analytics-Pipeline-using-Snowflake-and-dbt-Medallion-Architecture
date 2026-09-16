# CI Setup Detection — Conditional CI Pipeline Initialization

**Purpose**: Determine whether the repository already has AIRE-Helix CI infrastructure set up, so workflows can:
- **Skip full CI setup** on established AIRE projects (avoid re-bootstrapping)
- **Run full CI setup** on new repos lacking the infrastructure

---

## Detection Mechanism

### Mandatory CI Artifacts

A repository is considered to have **AIRE-Helix CI already configured** if ALL of the following exist:

1. **`.github/workflows/agentic-eval-pipeline.yml`** — the CI pipeline workflow
2. **`tests/.evals/config.json`** — eval framework configuration with thresholds
3. **`tests/.evals/rubrics/architecture-rubric.json`** — architecture scoring rubric
4. **`tests/.evals/rubrics/security-rubric.json`** — security scoring rubric
5. **`tests/.evals/scripts/run-static-evals.sh`** or **`tests/.evals/scripts/run-static-evals.ps1`** — delta-scoped static evaluation script

### Detection Logic

```bash
# All five files must exist
[ -f ".github/workflows/agentic-eval-pipeline.yml" ] && \
[ -f "tests/.evals/config.json" ] && \
[ -f "tests/.evals/rubrics/architecture-rubric.json" ] && \
[ -f "tests/.evals/rubrics/security-rubric.json" ] && \
( [ -f "tests/.evals/scripts/run-static-evals.sh" ] || [ -f "tests/.evals/scripts/run-static-evals.ps1" ] )
# If ALL are true → CI Setup EXISTS
# If ANY is missing → CI Setup MISSING
```

---

## Recording in `runtime-artifacts/aire-state.md`

### Format

Add this section early in the workflow (at the resume check / ticket capture stage):

```markdown
## CI Setup Status
- **Status**: exists | missing
- **Detected At**: [ISO 8601 timestamp when detection ran]
- **Files Found**: [list of found artifacts, or "none"]
```

### Example — CI Exists

```markdown
## CI Setup Status
- **Status**: exists
- **Detected At**: 2026-09-14T10:30:45Z
- **Files Found**: 
  - .github/workflows/agentic-eval-pipeline.yml ✓
  - tests/.evals/config.json ✓
  - tests/.evals/rubrics/architecture-rubric.json ✓
  - tests/.evals/rubrics/security-rubric.json ✓
  - tests/.evals/scripts/run-static-evals.sh ✓
```

### Example — CI Missing

```markdown
## CI Setup Status
- **Status**: missing
- **Detected At**: 2026-09-14T10:30:45Z
- **Files Missing**: 
  - .github/workflows/agentic-eval-pipeline.yml ✗
  - tests/.evals/rubrics/architecture-rubric.json ✗
  - tests/.evals/scripts/run-static-evals.sh ✗
```

---

## Conditional Behavior Based on Detection

### When CI Setup EXISTS (established AIRE project)

**In `bug-fix.md` Step 8.5 (Section 5 — CI Pipeline Setup):**
- ✅ Skip generating `.github/workflows/agentic-eval-pipeline.yml`, `sonar-project.properties`, and the `tests/.evals/scripts/*` set — reuse whatever already exists AS-IS
- ✅ Announce: "CI infrastructure already exists — skipping full setup"
- ✅ Proceed directly to design artifacts (architecture.md, rubrics) — these are ALWAYS created/reused regardless of CI Setup Status; skipping CI setup never skips architecture.md or behavior.feature

**In `bug-fix.md` Step 9, Item 2 (the `smoke-test-epic.{sh,ps1}` scratch-PR run — a DIFFERENT step from Step 8.5's CI pipeline generation, and the one actually observed to misfire):**
- ✅ **Skip it entirely — do not run it, do not present its "Run smoke test? (yes/no)" prompt.** The environment was already validated by a prior cycle's smoke test when the CI infrastructure was first bootstrapped; re-running it on every ticket is redundant.
- ✅ Announce: "CI infrastructure already exists — skipping the pre-handoff smoke test."
- ✅ Item 1 (commit + push the analysis/design artifacts) and Item 3 (the ve break message) still run exactly as written — only the smoke test itself is skipped.

**In `bug-fix-implement.md` Step 9.1.5 (CI Preflight):**
- ✅ Run normally (preflight validates manifest + script executability) — this is a per-fix declaration check, unrelated to the one-time environment smoke test, and is NEVER skipped by CI Setup Status
- ✅ No separate smoke test
- ✅ No duplicate CI artifact generation

**In `enhancement-implement.md` Step 8.5 (Section 5 — CI Pipeline Setup):**
- ✅ Same as `bug-fix.md` Step 8.5 above — skip CI pipeline generation, proceed to design artifacts

**In `enhancement-implement.md`'s ve Handoff Break, Item 2 (the `smoke-test-epic.{sh,ps1}` scratch-PR run):**
- ✅ Same as `bug-fix.md` Step 9 Item 2 above — skip it entirely, announced; Items 1 and 3 still run.

### When CI Setup MISSING (new repo, first AIRE cycle)

**In `bug-fix.md` Step 8.5:**
- ✅ Run full CI setup (pipeline, SonarQube setup gate, scripts) — current behavior
- ✅ Generate all required artifacts

**In `bug-fix.md` Step 9, Item 2:**
- ✅ Run the pre-handoff smoke test before the ve break message — current behavior

**In `bug-fix-implement.md` Step 9.1.5:**
- ✅ Run preflight normally

**In `enhancement-implement.md` Step 8.5:**
- ✅ Run full CI setup — current behavior

**In `enhancement-implement.md`'s ve Handoff Break, Item 2:**
- ✅ Run the pre-handoff smoke test — current behavior

---

## Logging Requirements

Every detection must be logged to `runtime-artifacts/audit.md` with:

```markdown
## CI Setup Detection
**Timestamp**: [ISO 8601]
**User Email**: [session email]
**Detection Result**: [exists / missing]
**Found Artifacts**: [list]
**Next Action**: [Skip full CI setup / Run full CI setup]
```

---

## Important Notes

🔴 **Detection runs ONCE per ticket workflow** — do not re-check in every stage. Record the result and reuse it downstream.

🔴 **Established projects stay unchanged** — reuse existing CI artifacts AS-IS. Never regenerate or update them unless thresholds changed (that happens at a later stage, outside this detection).

🔴 **Artifact Ownership still applies** — if CI artifacts exist on the base branch, inherited cycles use them AS-IS; create-if-missing only applies to artifacts that are genuinely missing.

🔴 **This detection ONLY gates CI pipeline bootstrap (the `.github/workflows/agentic-eval-pipeline.yml` generation stage) and the one-time `smoke-test-epic.{sh,ps1}` scratch-PR run.** It NEVER gates `spec/plans/architecture.md`, `spec/behavior.feature`, the rubrics, or any other STOP CHECKPOINT artifact — those are always created (if genuinely absent) or reused AS-IS, on every ticket, regardless of `## CI Setup Status`. "CI already exists" means "the pipeline and its one-time environment check don't need to run again" — it does not mean "skip the design/behavior/rubric artifacts for this ticket."
