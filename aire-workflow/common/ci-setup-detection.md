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

**In `bug-fix.md` Step 8.5:**
- ✅ Skip the complete CI setup + smoke test PR stage
- ✅ Announce: "CI infrastructure already exists — skipping full setup"
- ✅ Proceed directly to design artifacts (architecture.md, rubrics)
- ✅ Scripts that are affected by bug changes are evaluated as normal (via dev-implement's own preflight)

**In `bug-fix-implement.md` Step 9.1.5 (CI Preflight):**
- ✅ Run normally (preflight validates manifest + script executability)
- ✅ No separate smoke test
- ✅ No duplicate CI artifact generation

**In `enhancement-implement.md` Step 8.5:**
- ✅ Skip the complete CI setup + smoke test PR stage
- ✅ Proceed to design artifacts
- ✅ Same flow as bug-fix

### When CI Setup MISSING (new repo, first AIRE cycle)

**In `bug-fix.md` Step 8.5:**
- ✅ Run full CI setup with smoke test PR (current behavior)
- ✅ Generate all required artifacts
- ✅ Run pre-handoff smoke test before Development Handoff

**In `bug-fix-implement.md` Step 9.1.5:**
- ✅ Run preflight normally

**In `enhancement-implement.md` Step 8.5:**
- ✅ Run full CI setup with smoke test PR (current behavior)

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
