# auto-fix-agent.ps1 — CI self-repair via the Claude Code CLI (PowerShell variant of auto-fix-agent.sh).
# 🔴 PRIMARY input = tests/.evals/_run/failed-gates.txt. Missing => PIPELINE DEFECT, exit NON-ZERO (never exit 0
#    on an unrepaired job). eval.json is SUPPLEMENTARY. mkdir before the counter write (rule 2).
$ErrorActionPreference = "Continue"

$config = "tests/.evals/config.json"
$runDir = "tests/.evals/_run"
$failedGates = "$runDir/failed-gates.txt"
$baseSha = $env:BASE_SHA
$evalKey = $env:EVAL_KEY
$evidenceDir = "reports/eval-evidence/$evalKey"
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

function ReportAndExit($m, $code = 1) { Write-Error "auto-fix-agent: $m"; exit $code }

if (-not (Test-Path $failedGates)) {
  ReportAndExit "PIPELINE DEFECT: $failedGates missing — the Verdict step must always produce it. Not exiting 0 on an unrepaired failure." 1
}
$gates = @(Get-Content $failedGates | Where-Object { $_.Trim() -ne "" })
if ($gates.Count -eq 0) { ReportAndExit "failed-gates.txt empty but self-repair triggered — cannot determine what to repair." 1 }

# ==================================================================================================
# TRIAGE (Section 6.4) - RUNS BEFORE THE RETRY COUNTER IS TOUCHED.
# Order matters and this was a real defect: the counter used to be incremented ABOVE the triage block,
# so an infrastructure failure silently burned a retryLimitForSelfRepair attempt even though Section 6.4
# states it never should. A non-repairable class must cost nothing.
# ==================================================================================================

# -- MANIFEST class (Section 6.4) - never repaired here, and never a code edit --
# lib-manifest.* records every Manifest-class defect to this marker (a missing ci.roots[] directory, a
# root whose declared markerFile is gone, a tool named in `tools` with no toolInstallCommands entry).
# Read the MARKER, never grep the log: stderr is interleaved, truncated and locale-dependent.
$manifestDefects = "$runDir/manifest-defects.txt"
if ((Test-Path $manifestDefects) -and (Get-Item $manifestDefects).Length -gt 0) {
  $detail = Get-Content $manifestDefects -Raw
  ReportAndExit "MANIFEST-class failure - not a code defect, not consuming a retry. The manifest does not describe this repo correctly:`n$detail`nFix tests/.evals/config.json's ci.roots[] (or the owning work unit's tests/.evals/ci-manifest.d/ fragment) and push again. Failing gates: $($gates -join ', ')" 1
}

# -- SMOKE-TEST context (Section 4.0.6) - the Code class is EMPTY here, by definition --
# The epic-level pre-handoff smoke test is a deliberately ZERO-DIFF scratch PR. With no code delta, NO
# failure on it can be caused by application code. THIS IS THE GUARD BEHIND THE DUMMY-TEST INCIDENT:
# observed in production, self-repair spent ~45 minutes WRITING FAKE TESTS on a repo whose suite did not
# exist yet - a fabricated pass (SH-6) that then merged and poisoned the regression baseline. It matters
# more now, not less: the smoke watch loop is deliberately UNBOUNDED.
$headRef = $env:HEAD_REF
if (-not $headRef) { $headRef = (git rev-parse --abbrev-ref HEAD 2>$null) }
$smokeContext = $false
if ($headRef -and $headRef -like "ci/epic-smoke-*") { $smokeContext = $true }

# -- INFRASTRUCTURE class (Section 6.4) --
foreach ($g in $gates) {
  if ($g -eq "sonar") {
    $cond = "$runDir/sonar-conditions.txt"
    if (-not ((Test-Path $cond) -and (Get-Item $cond).Length -gt 0)) {
      ReportAndExit "sonar failed WITHOUT reported conditions (auth/unreachable/timeout) — infrastructure, not a code defect. Not consuming a retry." 1
    }
  }
}

# -- Retry budget (only a genuinely repairable failure gets this far, so only it consumes an attempt) --
$limit = 3
if ((Test-Path $config) -and (Get-Command jq -ErrorAction SilentlyContinue)) { $limit = [int](jq -r '.retryLimitForSelfRepair // 3' $config) }
$counter = "$runDir/self-repair-attempt"
$prev = if (Test-Path $counter) { [int](Get-Content $counter -Raw) } else { 0 }
$attempt = $prev + 1
if ($attempt -gt $limit) { ReportAndExit "retry limit $limit reached — 3 retries ended. Please suggest next steps. Unresolved: $($gates -join ', ')" 1 }
$attempt | Out-File -Encoding utf8 $counter




# 🔴 Resolve by EVAL_KEY path, NEVER a recursive search across reports/eval-evidence/ (V31, Section
#    4.0e) — a wildcard search silently adopts the FIRST match across every work unit's own committed
#    evidence, which after a few merged stories includes other stories' files.
if (-not $evalKey) {
  ReportAndExit "EVAL_KEY is not set — cannot resolve this run's own evidence directory. The self-repair job's 'Resolve EVAL_KEY' step must run before this script and export EVAL_KEY (Section 4.0e)." 1
}
$evalJsonPath = "$evidenceDir/eval.json"
$evalJson = if (Test-Path $evalJsonPath) { $evalJsonPath } else { $null }
if (-not $evalJson) { Write-Error "auto-fix-agent: note — no eval.json found at $evalJsonPath; repairing from failed-gates.txt + logs (Section 6.5)." }

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { ReportAndExit "claude CLI not installed — cannot self-repair." 1 }

# 🔴 The BRIEF below tells Claude to commit its own fix (it has git tool access) — so "did the agent
#    change anything" can NOT be judged by working-tree dirtiness alone: a clean `git status` after
#    the CLI call means "Claude already committed it", not "nothing happened". Track HEAD movement too.
$beforeSha = (git rev-parse HEAD)

# -- STORY / WORK-UNIT CONTEXT (Section 6.5) - paths only, never file bodies --
$unitFeature = "spec/behavior/$evalKey.feature"
$contextLines = ""
if (Test-Path $unitFeature) { $contextLines += "`n  - This work unit's Gherkin contract (its acceptance criteria, authored BEFORE the code): $unitFeature" }
if (Test-Path "spec/plans/architecture.md") { $contextLines += "`n  - Architecture constraints this repo is held to (Section 10 is what the J1 judge scores): spec/plans/architecture.md" }
if (Test-Path "spec/plans/requirements.md") { $contextLines += "`n  - Requirements: spec/plans/requirements.md" }
if (Test-Path "spec/plans/stories.md") { $contextLines += "`n  - Work-unit definitions and acceptance criteria: spec/plans/stories.md" }
if (Test-Path "runtime-artifacts/aire-state.md") { $contextLines += "`n  - Story Tracker (which unit this is, its tracker id, its dependencies): runtime-artifacts/aire-state.md" }
if ($evalJson) { $contextLines += "`n  - This run's scorecard, with per-criterion judge scores and file:line citations: $evalJson" }

if ($smokeContext) {
  $scopeBlock = @"
SCOPE - THIS IS THE EPIC-LEVEL SMOKE TEST (a deliberately ZERO-DIFF PR).
  There is NO code change on this PR, so no failure here can be caused by application code.
  You are validating and repairing the ENVIRONMENT, nothing else.
  YOU MAY EDIT:    .github/workflows/**, tests/.evals/scripts/**, tests/.evals/behavior/**, and tool
                   pins / install commands in tests/.evals/config.json or tests/.evals/ci-manifest.d/*.json.
  YOU MAY NOT EDIT, FOR ANY REASON: src/**, tests/** (except tests/.evals/**), or any application
     source or test file. In particular you MUST NOT create tests.
  If a test runner reports that it collected ZERO tests, that is the CORRECT and EXPECTED state of
     this repo right now - the first story has not been built yet. It is N/A, not a failure. Do NOT
     write a test, a placeholder test, a dummy assertion or a conftest to make it pass. If that is the
     only thing failing, say so plainly and stop: the pipeline is behaving correctly.
  Never weaken a threshold or delete a gate to make this PR green.
"@
} else {
  $scopeBlock = @"
SCOPE - a normal work-unit PR. Fix the CODE that failed the gates.
  YOU MAY EDIT:    src/** (application code) and tests/** (real tests for that code) - and nothing
                   else. Code belongs in src/, tests belong in tests/. Never introduce a third location.
  YOU MAY NOT EDIT: .github/workflows/**, tests/.evals/config.json, tests/.evals/rubrics/**,
     tests/.evals/ci-manifest.d/**, or spec/**. Those are the contract you are being measured against.
     If the failure is genuinely caused by one of them, that is a MANIFEST or INFRASTRUCTURE class
     failure - report it and stop rather than editing the yardstick.
  Stay inside THIS work unit. Do not touch files another work unit owns just because a gate mentioned them.
"@
}

$brief = @"
The agentic eval pipeline failed on this PR. You are the CI self-repair agent.
You have read, write and commit access to this checkout. Use them - investigate, fix, verify, commit.

FAILED GATES: $($gates -join ', ')

WHERE THE TRUTH IS (read these first, in this order):
  - tests/.evals/_run/failed-gates.txt  - PRIMARY. The authoritative list of what failed.
  - the failing steps' logs in this job - the actual error text to repair against.
  - eval.json (if present)              - per-criterion scores and file:line citations.

WORK-UNIT CONTEXT (open what you need; do not assume):$contextLines

$scopeBlock

HOW TO FIX (stack-agnostic - this repo may be any language, or a mix of several):
  - Read the repo to learn its stack, its conventions and its test layout. Never assume a framework, a
    package manager, a directory layout or a command. tests/.evals/_run/merged-manifest.json records
    the commands this project actually uses, per root, with the directory each one runs from.
  - Match the surrounding code: its language, style, naming, error handling and test idiom.
  - Fix the ROOT CAUSE of each failed gate, one gate at a time. Do not shotgun unrelated changes.
  - Re-run what you can verify yourself (the linter, the type checker, the unit tests, the build) from
    the correct working directory, and confirm it is actually green before you commit.

NON-NEGOTIABLE GUARDRAILS (violating any of these is worse than leaving the gate red):
  - Never delete, skip, weaken or ignore a test to go green. Fix the code the test is failing on.
  - Never write a fake, empty, trivially-true or placeholder test to satisfy a coverage or test gate.
    A test that cannot fail is not a test. If coverage is short, write a REAL test that exercises the
    behaviour; if you cannot, say so and stop.
  - Never suppress a finding: no blanket eslint-disable, no nosec, no type-ignore, no SuppressWarnings,
    no ignore-list entry, no widening of a disallowed-licence list.
  - Never lower a threshold in tests/.evals/config.json, and never edit a rubric.
  - Never edit spec/plans/architecture.md to make the J1 architecture gate pass. The architecture
    changes only when the DESIGN changed - never because a score did not clear.
  - Never edit sonar-project.properties, the Quality Gate, or mark an issue Won't Fix.
  - SECURITY: your fix must satisfy the Security Baseline the review enforces. Never introduce a
    hardcoded credential, token, key or connection string; never log a secret or PII; never disable
    TLS/certificate verification, authentication, authorization or CSRF protection; never widen CORS
    to a wildcard; never build a query by string concatenation instead of parameterising it; never
    weaken input validation to make a test pass. A repair that trades a failing gate for a
    vulnerability is a regression, not a fix.
  - Never commit generated evidence, build output, caches, or tests/.evals/_run/** state.
  - Do NOT try to invoke or re-run the J1_architecture / J2_security judge gates yourself. Scoring them
    means shelling out to claude again from inside your own tool call, which cannot authenticate
    (credentials do not propagate to a nested claude invocation) - that failure is expected, not a bug
    worth reporting. This script re-verifies J1/J2 for real after your turn ends; just fix the cited
    criteria/citations from eval.json and stop.

IF YOU CANNOT FIX IT: say exactly which gate, what you tried, and why it did not work - then stop.
A clear, honest report is a valid outcome. A fabricated pass never is.

Commit with:  fix(ci): self-repair attempt $attempt - $($gates -join ', ')
"@

# >>> CLAUDE_REPAIR_INVOCATION START <<<
$brief | claude
if ($LASTEXITCODE -ne 0) { ReportAndExit "the repair CLI invocation failed on attempt $attempt." 1 }
# >>> CLAUDE_REPAIR_INVOCATION END <<<

# Claude may have committed the fix itself (per the BRIEF) — that leaves the tree clean but HEAD
# moved. Only a clean tree AND an unmoved HEAD means it genuinely made no changes.
$afterSha = (git rev-parse HEAD)
if ($afterSha -eq $beforeSha -and -not (git status --porcelain)) { ReportAndExit "self-repair produced no changes on attempt $attempt — PR stays red." 1 }

# -- SCOPE ENFORCEMENT - the BRIEF states the scope; THIS is what makes it binding --
# A prompt is guidance, not a guarantee. Every path the agent touched (committed or still in the tree)
# is checked against the scope for this context, and a violation aborts BEFORE the push - so a forbidden
# edit can never reach the repository. The local commits die with the ephemeral runner.
$touched = @()
$touched += @(git diff --name-only $beforeSha HEAD 2>$null)
$touched += @(git status --porcelain | ForEach-Object { ($_ -split '\s+')[-1] })
$touched = @($touched | Where-Object { $_ } | Sort-Object -Unique)
$violations = @()
foreach ($f in $touched) {
  if ($smokeContext) {
    if ($f -like "tests/.evals/*") { continue }
    if ($f -like "src/*" -or $f -like "tests/*") { $violations += $f }
  } else {
    if ($f -like ".github/workflows/*" -or $f -eq "tests/.evals/config.json" -or
        $f -like "tests/.evals/rubrics/*" -or $f -like "tests/.evals/ci-manifest.d/*" -or
        $f -like "spec/*") { $violations += $f }
  }
}
if ($violations.Count -gt 0) {
  $list = ($violations -join "`n  ")
  if ($smokeContext) {
    ReportAndExit "SCOPE VIOLATION on the epic smoke PR - self-repair modified application code or tests, which is never a valid repair for a ZERO-DIFF PR. Nothing has been pushed. Offending paths:`n  $list`n`nThe smoke test validates the ENVIRONMENT, not the code. If a test runner reported that it collected zero tests, that is correct and expected before the first story: it is N/A, not a failure. Failing gates: $($gates -join ', ')" 1
  } else {
    ReportAndExit "SCOPE VIOLATION - self-repair modified the contract it is measured against, not the code. Nothing has been pushed. Offending paths:`n  $list`n`nThe workflow, tests/.evals/config.json, the rubrics, the manifest fragments and spec/** are off-limits to this agent (Section 6.4). Failing gates: $($gates -join ', ')" 1
  }
}

# 🔴 D7_secrets is the ONE gate a forward commit can be structurally unable to clear: gitleaks scans
#    --log-opts BASE..HEAD, i.e. every commit's OWN patch in that range — not the final tree. A finding
#    anchored to a commit already pushed to origin before this attempt started stays in that history
#    forever. Refusing to commit in that case would discard real, valuable fixes for no benefit — but
#    silently committing as if D7 passed would hide a genuinely unresolved finding. Do neither.
function D7OnlyHistoryAnchoredRemaining {
  # 🔴 Resolve by EVAL_KEY path, never a recursive search (same rule as above).
  $gatesFile = "$evidenceDir/static/static-results.json.gates"
  if (-not $evalKey -or -not (Test-Path $gatesFile)) { return $false }
  $failing = @()
  foreach ($line in (Get-Content $gatesFile)) {
    $parts = $line -split "`t"
    if ($parts.Count -ge 2 -and ($parts[1] -eq "FAIL" -or $parts[1] -eq "ERROR")) { $failing += $parts[0] }
  }
  # Must be the ONLY thing still failing — anything else means real fixable work remains.
  if ($failing.Count -ne 1 -or $failing[0] -ne "D7_secrets") { return $false }

  $gitleaksReport = "$evidenceDir/static/gitleaks-delta.json"
  if (-not (Test-Path $gitleaksReport) -or -not (Get-Command jq -ErrorAction SilentlyContinue)) { return $false }

  $headRef = if ($env:GITHUB_HEAD_REF) { $env:GITHUB_HEAD_REF } else { "main" }
  $originRef = "origin/$headRef"
  git fetch origin $headRef 2>$null | Out-Null

  $commits = @(jq -r '.[].Commit // empty' $gitleaksReport 2>$null | Sort-Object -Unique)
  foreach ($commit in $commits) {
    if (-not $commit) { continue }
    git merge-base --is-ancestor $commit $originRef 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
  }
  return $true
}

if ($baseSha) {
  bash tests/.evals/scripts/run-static-evals.sh $baseSha 2>$null
  $staticRc = $LASTEXITCODE
  bash tests/.evals/scripts/run-evals.sh $baseSha 2>$null
  $evalsRc = $LASTEXITCODE
  if ($staticRc -ne 0 -or $evalsRc -ne 0) {
    if (D7OnlyHistoryAnchoredRemaining) {
      Write-Host "auto-fix-agent: D7_secrets remains red - every remaining finding is anchored to an already-pushed commit (gitleaks' own --log-opts BASE..HEAD commit-range scan); no forward commit can clear it. Proceeding to commit the real fix(es) made for the other gate(s). D7_secrets needs a human decision: rebase to scrub the secret from that commit and force-push, or (only if it is a rotated/false-positive credential) add a scoped gitleaks allowlist entry for that exact fingerprint - never a blanket suppression."
    } else {
      ReportAndExit "re-verification still FAILS after repair attempt $attempt — not committing an unverified fix." 1
    }
  }
}

# 🔴 A fresh GH Actions runner has no git identity configured — git commit fails outright even after
#    a fully correct repair, wasting a retry on something that was never a code problem. --local scopes
#    it to this checkout only. Same bot-identity convention as smoke-test-epic.sh's aire-ci-smoke commits.
git config --local user.name "aire-self-repair"
git config --local user.email "aire-self-repair@localhost"

# Claude may have already committed its own fix inside the CLI call above. Only create an extra
# commit for whatever it left uncommitted — never treat "nothing left to stage" as a failure.
if (git status --porcelain) {
  # never stage this run's own scratch state (retry counter, failed-gates.txt, merged manifest,
  # manifest-defects.txt all live under tests/.evals/_run/ and are per-run artifacts)
  git add -A -- ':!tests/.evals/_run'
  if ($LASTEXITCODE -ne 0) { git add -A }
  git commit -m "fix(ci): self-repair attempt $attempt — $($gates -join ', ')"
  if ($LASTEXITCODE -ne 0) { ReportAndExit "commit failed on attempt $attempt." 1 }
}
$head = if ($env:GITHUB_HEAD_REF) { $env:GITHUB_HEAD_REF } else { "HEAD" }
git push origin "HEAD:$head"
if ($LASTEXITCODE -ne 0) { ReportAndExit "push failed on attempt $attempt." 1 }

Write-Output "auto-fix-agent: attempt $attempt committed and pushed for gates: $($gates -join ', ')"
exit 0
