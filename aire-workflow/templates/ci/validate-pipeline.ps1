# validate-pipeline.ps1 — LAYER 2 non-skippable local gate (PowerShell variant of validate-pipeline.sh).
# 🔴 Non-zero exit => the pipeline is NOT committed, it is fixed and re-validated (max 3 attempts).
#    Inspects only; never mutates the repo. Usage: pwsh tests/.evals/scripts/validate-pipeline.ps1 [base-sha]
param([string]$BaseSha = "")
$ErrorActionPreference = "Continue"

$wf = ".github/workflows/agentic-eval-pipeline.yml"
$config = "tests/.evals/config.json"
$script:rc = 0
function Note($m) { Write-Host "  $m" }
function CheckFail($m) { Write-Host "FAIL  $m"; $script:rc = 1 }
function CheckOk($m) { Write-Host "ok    $m" }

Write-Host "validate-pipeline: checking $wf"

if (-not (Test-Path $wf)) { CheckFail "workflow file $wf does not exist" }
else {
  # 🔴 Exclude legitimate RUNTIME shell vars set via step env: (${EVAL_KEY}, ${BASE_SHA}, ${GITHUB_*}).
  $hits = Select-String -Path $wf -Pattern '\$\{[A-Z_]+\}|# GENERATE:|<[a-z][a-z-]*>|>>> [A-Z_ ]+ (START|END) <<<' |
    Where-Object { $_.Line -notmatch '\$\{(EVAL_KEY|BASE_SHA|GITHUB_[A-Z_]+|SONAR_TOKEN|CE_TASK_URL|ANALYSIS_ID|SERVER_URL|REPORT_TASK)\}' }
  if ($hits) { $hits | ForEach-Object { Write-Host $_.Line }; CheckFail "unresolved slot/placeholder/marker remains (V14)" }
  else { CheckOk "no unresolved slots or placeholders (V14)" }
}

if (Get-Command python3 -ErrorAction SilentlyContinue) {
  python3 -c "import yaml,sys; yaml.safe_load(open('$wf'))" 2>$null
  if ($LASTEXITCODE -eq 0) { CheckOk "YAML parses (V1)" } else { CheckFail "YAML parse error (V1)" }
} else { Note "python3 not available — YAML parse (V1) not run" }

if (Get-Command actionlint -ErrorAction SilentlyContinue) {
  actionlint $wf 2>$null
  if ($LASTEXITCODE -eq 0) { CheckOk "actionlint clean (V2)" } else { CheckFail "actionlint errors (V2)" }
} else { Note "actionlint: not available — schema check (V2) not run" }

if ((Test-Path $config) -and (Get-Command jq -ErrorAction SilentlyContinue)) {
  $gates = @(jq -r '.ci.gates[]?' $config)
  if ($gates.Count -gt 0) { CheckOk "ci.gates present ($($gates.Count) gates)" } else { CheckFail "ci.gates empty (manifest not filled)" }
  foreach ($agg in @("static","unit","coverage","behavior","judge","sonar")) {
    if (-not (Select-String -Path $wf -Pattern "`"${agg}:")) { CheckFail "verdict tally missing aggregate outcome '$agg' (V8/V18)" }
  }
  if (Test-Path "tests/.evals/scripts/run-evals.sh") {
    if (-not (Select-String -Path "tests/.evals/scripts/run-evals.sh" -Pattern 'ci.gates')) { CheckFail "run-evals.sh does not iterate ci.gates (4.0c.3)" }
  }
} else { CheckFail "$config or jq missing — cannot validate the manifest" }

foreach ($f in @("tests/.evals/config.json", "tests/.evals/rubrics/architecture-rubric.json", "tests/.evals/rubrics/security-rubric.json", "tests/.evals/behavior/run.sh")) {
  if (Test-Path $f) { CheckOk "referenced file exists: $f (V4)" } else { CheckFail "referenced file missing: $f (V4)" }
}
if ((Test-Path $config) -and (Get-Command jq -ErrorAction SilentlyContinue)) {
  $sonarEnabled = (jq -r '.sonarqube.enabled // false' $config)
  if ($sonarEnabled -eq "true") {
    if (Test-Path "sonar-project.properties") { CheckOk "sonar-project.properties exists (sonarqube.enabled=true) (V4)" }
    else { CheckFail "sonarqube.enabled=true but sonar-project.properties is missing (V4)" }
  }
}

if (Test-Path $wf) {
  if (Select-String -Path $wf -Pattern 'EVAL_KEY:\s*"\$\{\{\s*github\.head_ref\s*\}\}"') {
    CheckFail "EVAL_KEY set directly from github.head_ref — branch refs contain '/', this must go through resolve-eval-key.sh (V11)"
  } elseif (Select-String -Path $wf -Pattern 'steps.evalkey.outputs.key') {
    CheckOk "EVAL_KEY resolves via resolve-eval-key.sh output (V11)"
  } else {
    CheckFail "no EVAL_KEY resolution via steps.evalkey.outputs.key found (V11)"
  }
}

foreach ($s in @("tests/.evals/scripts/run-static-evals.ps1", "tests/.evals/scripts/run-evals.ps1", "tests/.evals/scripts/auto-fix-agent.ps1")) {
  if (Test-Path $s) {
    if (Select-String -Path $s -Pattern 'New-Item.*-Force') { CheckOk "$s creates its directories before writing (V12)" }
    else { CheckFail "$s has no New-Item -Force directory creation — a clean checkout will hit a missing-path error (V12)" }
  }
}

if (Test-Path $wf) {
  if ((Select-String -Path $wf -Pattern 'actions/upload-artifact') -and (Select-String -Path $wf -Pattern 'name: eval-results')) {
    CheckOk "verify job uploads eval-results artifact (V15)"
  } else {
    CheckFail "no actions/upload-artifact step named 'eval-results' found — self-repair's download-artifact will find nothing (V15)"
  }
}

function Test-InstallOrder($wfPath) {
  $allowed = @("python3","pip","pip3","node","npm","npx","git","jq","curl","bash","sh","podman","docker","echo","printf","exit","tar","gitleaks_version")
  $instep = $false; $seen = @{}
  $missing = @()
  foreach ($line in (Get-Content $wfPath)) {
    if ($line -match '^      - name: "Install eval tools"') { $instep = $true; $seen = @{}; continue }
    if ($instep -and $line -match '^      - name:') { $instep = $false }
    if ($instep -and $line -match '^  [a-zA-Z-]+:') { $instep = $false }
    if ($instep) {
      $isComment = $line -match '^\s*#'
      $isCheck = (($line -match '--version') -and ($line -match '\|\|')) -or (($line -match '\s+version\s+') -and ($line -match '\|\|')) -or ($line -match 'not found after install')
      if ($isCheck -and -not $isComment) {
        $t = $line.TrimStart()
        $tokens = $t -split '\s+'
        if ($tokens[0] -eq "command" -and $tokens[1] -eq "-v") { $tool = $tokens[2] } else { $tool = $tokens[0] }
        if ($tool -and -not $allowed.Contains($tool) -and -not $seen.ContainsKey($tool)) { $missing += $tool }
      } elseif (-not $isComment) {
        foreach ($tok in ($line -split '[ \t"=]+')) { if ($tok) { $seen[$tok] = $true } }
      }
    }
  }
  return $missing
}

if (Test-Path $wf) {
  $missingInstalls = Test-InstallOrder $wf
  if ($missingInstalls.Count -gt 0) {
    foreach ($t in $missingInstalls) { CheckFail "version check for '$t' with no preceding install in the same 'Install eval tools' step (V16/V22)" }
  } else {
    CheckOk "every version check in 'Install eval tools' is preceded by its install in the same step (V16/V22)"
  }
}

function Test-PipCheck($wfPath) {
  $instep = $false; $hasPip = $false; $hasCheck = $false; $missing = $false
  foreach ($line in (Get-Content $wfPath)) {
    if ($line -match '^      - name: "Install eval tools"') {
      if ($instep -and $hasPip -and -not $hasCheck) { $missing = $true }
      $instep = $true; $hasPip = $false; $hasCheck = $false; continue
    }
    if ($instep -and ($line -match '^      - name:' -or $line -match '^  [a-zA-Z-]+:')) {
      if ($hasPip -and -not $hasCheck) { $missing = $true }
      $instep = $false
    }
    if ($instep -and $line -match 'pip install') { $hasPip = $true }
    if ($instep -and $line -match 'pip check') { $hasCheck = $true }
  }
  if ($instep -and $hasPip -and -not $hasCheck) { $missing = $true }
  return $missing
}

if (Test-Path $wf) {
  if (Test-PipCheck $wf) {
    CheckFail "an 'Install eval tools' step runs pip install but never runs 'pip check' before its version checks (V24)"
  } else {
    CheckOk "pip check runs after every pip-based eval-tool install, or no pip install is used (V24)"
  }
}

Note "V23 (clean-room dry-run) cannot be verified statically from this file — confirm Section 4.0.1a's clean-room dry-run was actually performed before this commit."

if (Test-Path $wf) {
  if (Select-String -Path $wf -Pattern '\|\|\s*true|\|\|\s*exit 0|;\s*true') { CheckFail "forbidden '|| true' style masking in a step (V8)" }
  else { CheckOk "no '|| true' style masking (V8)" }
  $vcount = (Select-String -Path $wf -Pattern '^\s*-\s*name:\s*"Verdict"').Count
  if ($vcount -eq 1) { CheckOk "exactly one Verdict step (V8)" } else { CheckFail "expected exactly one Verdict step, found $vcount (V8)" }
}

if ((Test-Path $wf) -and (Test-Path $config) -and (Get-Command jq -ErrorAction SilentlyContinue)) {
  $base = (jq -r '.ci.baseBranch // "main"' $config)
  if (-not (Select-String -Path $wf -Pattern "`"$base`"")) { CheckFail "trigger does not name base branch '$base' (V10)" }
  foreach ($p in @(jq -r '.ci.integrationBranchPrefixes[]?' $config)) {
    if (-not (Select-String -Path $wf -Pattern "'$p/\*\*'")) { CheckFail "trigger missing integration prefix '$p/**' (V10)" }
  }
  CheckOk "trigger coverage checked against manifest (V10)"
}

if (Test-Path "tests/.evals/scripts/auto-fix-agent.ps1") {
  $af = "tests/.evals/scripts/auto-fix-agent.ps1"
  $lines = Get-Content $af
  $codeLines = $lines | Where-Object { $_ -notmatch '^\s*#' }
  $commitLineIdx = ($codeLines | Select-String -Pattern 'git commit' | Select-Object -Last 1).LineNumber
  $staticLineIdx = ($codeLines | Select-String -Pattern 'run-static-evals' | Select-Object -First 1).LineNumber
  $evalsLineIdx = ($codeLines | Select-String -Pattern 'run-evals\.ps1' | Select-Object -Last 1).LineNumber
  if ($commitLineIdx -and $staticLineIdx -and $evalsLineIdx -and $staticLineIdx -lt $commitLineIdx -and $evalsLineIdx -lt $commitLineIdx) {
    CheckOk "auto-fix-agent.ps1 re-runs run-static-evals.ps1 and run-evals.ps1 before git commit (V13)"
  } else {
    CheckFail "auto-fix-agent.ps1 does not clearly re-run both eval scripts before git commit (V13)"
  }

  $v19Bad = $false
  $exitHits = $codeLines | Select-String -Pattern 'exit 0'
  foreach ($hit in $exitHits) {
    if (-not $commitLineIdx -or $hit.LineNumber -lt $commitLineIdx) {
      $v19Bad = $true
      Write-Host "  early exit 0 at line $($hit.LineNumber): $($hit.Line)"
    }
  }
  if ($v19Bad) {
    CheckFail "auto-fix-agent.ps1 has an 'exit 0' reachable before a successful commit — self-repair must never claim success without repairing (V19)"
  } else {
    CheckOk "every 'exit 0' in auto-fix-agent.ps1 follows a successful commit (V19)"
  }
}

$v20Hit = $false
foreach ($s in @("tests/.evals/scripts/run-static-evals.ps1", "tests/.evals/scripts/run-evals.ps1", "tests/.evals/scripts/auto-fix-agent.ps1")) {
  if (Test-Path $s) {
    $hits = Select-String -Path $s -Pattern "N/A" | Where-Object { $_.Line -match 'yet|TODO|not wired|not bootstrapped|not installed|not enabled|pending' }
    if ($hits) { $v20Hit = $true; $hits | ForEach-Object { Write-Host $_.Line } }
  }
}
if ($v20Hit) {
  CheckFail "an 'N/A' reason contains a deferred-setup phrase (yet/TODO/not wired/pending/...) — this must be ERROR, not N/A (V20, eval-framework.md Section 2.4.2)"
} else {
  CheckOk "no deferred-setup language paired with N/A (V20)"
}

if (Test-Path "tests/.evals/scripts/run-static-evals.ps1") {
  $rse = Get-Content "tests/.evals/scripts/run-static-evals.ps1"
  $inRegion = $false; $bad = @()
  foreach ($line in $rse) {
    if ($line -match '>>> STACK-RESOLVED D-GATES START <<<') { $inRegion = $true; continue }
    if ($line -match '>>> STACK-RESOLVED D-GATES END <<<') { $inRegion = $false }
    if ($inRegion -and $line.Trim() -and $line -notmatch '^\s*#' -and $line -notmatch 'DeltaDiff ' -and $line -notmatch 'Record ') {
      $bad += $line
    }
  }
  if ($bad.Count -gt 0) {
    CheckFail "bare command in the stack-resolved D-gates region (not wrapped in DeltaDiff/Record) — whole-tree verdict risk (V7)"
    $bad | ForEach-Object { Write-Host $_ }
  } else {
    CheckOk "stack-resolved D-gates region contains only DeltaDiff/Record calls (V7)"
  }
}

foreach ($s in @("tests/.evals/scripts/run-static-evals.ps1", "tests/.evals/scripts/run-evals.ps1")) {
  if (Test-Path $s) {
    $hits = Select-String -Path $s -Pattern '"status"\s*:\s*"(PASS|N/A)"' | Where-Object { $_.Line -notmatch 'rubric %s absent' }
    if ($hits) {
      CheckFail "hardcoded status literal outside the documented rubric-absent N/A fallback in $s — possible stub (V9)"
      $hits | ForEach-Object { Write-Host $_.Line }
    } else {
      CheckOk "no hardcoded PASS/N-A literal outside the documented rubric-absent fallback in $s (V9)"
    }
  }
}
Note "V9's full requirement — prove each script can FAIL against a deliberately broken input — needs fault injection and is not fully automated here."

$pipCmd = $null
if (Get-Command pip -ErrorAction SilentlyContinue) { $pipCmd = @("pip") }
elseif (Get-Command pip3 -ErrorAction SilentlyContinue) { $pipCmd = @("pip3") }
elseif (Get-Command python3 -ErrorAction SilentlyContinue) { $pipCmd = @("python3", "-m", "pip") }
elseif (Get-Command python -ErrorAction SilentlyContinue) { $pipCmd = @("python", "-m", "pip") }

if ((Test-Path $wf) -and $pipCmd) {
  $lines = Get-Content $wf
  $inStep = $false; $pipLine = $null
  foreach ($line in $lines) {
    if ($line -match '^      - name: "Install eval tools"') { $inStep = $true; continue }
    if ($inStep -and $line -match '^      - name:') { $inStep = $false }
    if ($inStep -and $line -match '^  [a-zA-Z-]+:') { $inStep = $false }
    if ($inStep -and $line -match 'pip install "' -and -not $pipLine) { $pipLine = $line }
  }
  if ($pipLine) {
    $pkgMatches = [regex]::Matches($pipLine, '"([a-zA-Z0-9_.-]+==[a-zA-Z0-9_.-]+)"')
    $pkgs = $pkgMatches | ForEach-Object { $_.Groups[1].Value }
    if ($pkgs.Count -gt 0) {
      $pipCmdArgs = @()
      if ($pipCmd.Length -gt 1) { $pipCmdArgs = $pipCmd[1..($pipCmd.Length-1)] }
      $dryOut = (& $pipCmd[0] @pipCmdArgs install --dry-run @pkgs 2>&1 | Out-String)
      if ($LASTEXITCODE -ne 0) {
        if ($dryOut -match 'ResolutionImpossible|conflicting dependencies') {
          CheckFail "the pinned tool set in 'Install eval tools' cannot be resolved together (V25) — pip install --dry-run reports a real conflict:"
          Write-Host $dryOut
        } else {
          Note "V25: pip install --dry-run could not complete (network/registry issue, not a version conflict) — re-run with connectivity to verify"
        }
      } else {
        CheckOk "the pinned tool set in 'Install eval tools' resolves together (V25)"
      }
    } else {
      Note "V25: no pinned (==) pip packages found in 'Install eval tools' — nothing to dry-run"
    }
  }
} else {
  Note "V25 (combined pip resolution) skipped — pip not available in this environment"
}

if (Test-Path $wf) {
  if (Select-String -Path $wf -Pattern 'gitleaks/gitleaks-action') {
    if (Select-String -Path $wf -Pattern 'GITHUB_TOKEN') { CheckOk "gitleaks-action has GITHUB_TOKEN wired (V6)" }
    else { CheckFail "gitleaks-action present without GITHUB_TOKEN in its env (V6)" }
  }
  if (Select-String -Path $wf -Pattern 'anthropics/claude-code-action') {
    if (Select-String -Path $wf -Pattern 'id-token: write') { CheckOk "claude-code-action present with id-token: write permission (V6)" }
    else { CheckFail "claude-code-action present without id-token: write permission (V6)" }
  }
  if (Select-String -Path $wf -Pattern 'SonarSource/sonarqube-scan-action|SonarSource/sonarqube-quality-gate-action') {
    if ((Select-String -Path $wf -Pattern 'SONAR_TOKEN') -and (Select-String -Path $wf -Pattern 'SONAR_HOST_URL')) {
      CheckOk "SonarQube actions have SONAR_TOKEN/SONAR_HOST_URL wired (V6)"
    } else { CheckFail "SonarQube action present without both SONAR_TOKEN and SONAR_HOST_URL (V6)" }
  }
}

# ── V26: CLAUDE_REPAIR_INVOCATION / CLAUDE_JUDGE_INVOCATION must be a RESOLVED claude call (headless +
#    permission flags from `claude --help` at generation time, Section 6.0) — never a bare `claude`
#    with no flags. Unresolved, it either hangs on an interactive approval prompt in a TTY-less runner
#    or silently repairs/scores nothing while still looking like it ran. V14 does not catch this — its
#    markers live in these SCRIPT files, not in $wf. ──
function CheckInvocationResolved($file, $marker) {
  if (-not (Test-Path $file)) { Note "V26: $file not found - skipping (generated separately, or a different variant is in use)"; return }
  $lines = Get-Content $file
  $grabbing = $false
  $block = @()
  foreach ($l in $lines) {
    if ($l -match ">>> $marker START <<<") { $grabbing = $true; continue }
    if ($l -match ">>> $marker END <<<") { $grabbing = $false }
    if ($grabbing) { $block += $l }
  }
  if ($block.Count -eq 0) {
    CheckFail "could not find the $marker markers in $file - has the fixed template text been hand-edited? (Section 3.1)"
    return
  }
  $joined = $block -join "`n"
  if (($joined -match '\bclaude\b') -and ($joined -notmatch '\bclaude\s+--?[a-zA-Z]')) {
    CheckFail "$marker in $file still invokes a bare 'claude' with no flags - headless/permission flags were never resolved at generation time (V26, Section 6.0)"
  } else {
    CheckOk "$marker in $file invokes claude with resolved flags (V26)"
  }
}
CheckInvocationResolved "tests/.evals/scripts/auto-fix-agent.ps1" "CLAUDE_REPAIR_INVOCATION"
CheckInvocationResolved "tests/.evals/scripts/run-evals.ps1" "CLAUDE_JUDGE_INVOCATION"

# ── V27: structural fidelity to templates/ci/agentic-eval-pipeline.yml.template — every FIXED job id
#    and step name the template declares (everything OUTSIDE a ${SLOT} region) must appear verbatim in
#    the committed workflow, and neither job may carry a `name:` override the template does not define.
#    🔴 KEEP THIS LIST IN SYNC WITH THE TEMPLATE. See validate-pipeline.sh's matching V27 block for the
#    full rationale. ──
if (Test-Path $wf) {
  $fixedJobIds = @("verify-and-evaluate", "self-repair")
  $fixedStepNames = @(
    "Checkout (full history for delta diffs)", "Resolve EVAL_KEY", "Resolve base SHA",
    "Purge inherited evidence", "Read manifest", "Setup Node", "Setup Python", "Setup Java",
    "Setup Go", "Setup .NET", "Install dependencies",
    "Compile / build", "Stage 1: static evals (delta-scoped)", "Stage 2: unit + coverage",
    "Coverage gate (delta-scoped)", "Stage 2: behaviour (Gherkin, Podman)", "Install Claude Code CLI",
    "Stage 3: judge gates J1 + J2", "Record SonarQube gate status", "Verdict",
    "Stage 4: publish scorecard", "Upload eval artifacts", "Checkout PR head",
    "Download eval artifacts", "Autonomous self-repair"
  )
  $wfLines = Get-Content $wf
  $v27Fail = $false

  # Job ids: exactly 2-space-indented identifiers ending in ':', scoped to the top-level `jobs:` block.
  $inJobs = $false
  $actualJobIds = @()
  foreach ($l in $wfLines) {
    if ($l -eq "jobs:") { $inJobs = $true; continue }
    if ($inJobs -and $l -match '^[a-zA-Z]') { break }
    if ($inJobs -and $l -match '^  ([a-zA-Z0-9_-]+):$') { $actualJobIds += $Matches[1] }
  }
  foreach ($jid in $fixedJobIds) {
    if ($actualJobIds -notcontains $jid) {
      CheckFail "job id '$jid' missing from the committed workflow (V27) - has the YAML been re-authored instead of copied from the template?"
      $v27Fail = $true
    }
  }
  $extraJobs = $actualJobIds | Where-Object { $fixedJobIds -notcontains $_ }
  if ($extraJobs) { CheckFail "unexpected job id(s) not in the template: $($extraJobs -join ', ') (V27)"; $v27Fail = $true }

  # No job-level `name:` override — the template defines none for either job.
  foreach ($jid in $fixedJobIds) {
    $seen = $false
    foreach ($l in $wfLines) {
      if ($seen -and $l -match '^  [a-zA-Z0-9_-]+:$') { break }
      if ($seen -and $l -match '^ {4}name:') {
        CheckFail "job '$jid' carries a name: override the template does not define (V27) - e.g. a capitalized/spaced display name is proof the YAML was hand-edited rather than copied"
        $v27Fail = $true
        break
      }
      if ($l -eq "  ${jid}:") { $seen = $true }
    }
  }

  # Every fixed step name must be present verbatim.
  foreach ($sname in $fixedStepNames) {
    if (-not (Select-String -Path $wf -SimpleMatch -Pattern "name: `"$sname`"" -Quiet)) {
      CheckFail "template step `"$sname`" is missing from the committed workflow (V27) - steps may have been merged, renamed, or the YAML re-authored instead of copied"
      $v27Fail = $true
    }
  }

  if (-not $v27Fail) {
    CheckOk "workflow structurally matches agentic-eval-pipeline.yml.template - all fixed job ids and step names present, no unexpected name: overrides (V27)"
  }
}

# ── V30: no untraceable manifest value — see validate-pipeline.sh's matching V30 block for the rationale.
if (Test-Path $config) {
  try {
    $cfg30 = Get-Content $config -Raw | ConvertFrom-Json
    $manifestState = if ($cfg30.ci.manifestState) { $cfg30.ci.manifestState } else { "resolved" }
    $roots30 = if ($cfg30.ci.roots) { @($cfg30.ci.roots) } else { @() }
    if ($manifestState -eq "unresolved" -and $roots30.Count -gt 0) {
      CheckFail "ci.manifestState is 'unresolved' but ci.roots[] has $($roots30.Count) entr(y/ies) - an unresolved manifest must have an EMPTY roots[] (V30, Section 3.0)"
    } elseif ($manifestState -eq "resolved" -and $roots30.Count -eq 0) {
      Note "V30: ci.manifestState is 'resolved' but ci.roots[] is empty - verify manually that this is intentional"
    } else {
      CheckOk "ci.manifestState ('$manifestState') is consistent with ci.roots[] length ($($roots30.Count)) (V30)"
    }
    if ($roots30.Count -gt 0) {
      $v30Fail = $false
      foreach ($r in $roots30) {
        if (-not (Test-Path $r.root)) {
          CheckFail "ci.roots[] root '$($r.root)' does not exist in this checkout (V30) - an untraceable manifest value"
          $v30Fail = $true
        } elseif ($r.markerFile -and -not (Test-Path (Join-Path $r.root $r.markerFile))) {
          CheckFail "ci.roots[] root '$($r.root)' declares markerFile '$($r.markerFile)', which is not present (V30) - an untraceable manifest value"
          $v30Fail = $true
        }
      }
      if (-not $v30Fail) { CheckOk "every ci.roots[] entry's directory and markerFile exist in this checkout (V30)" }
    }
  } catch {
    Note "V30 skipped - could not parse $config as JSON"
  }
}

# ── V28 + V29 (#7a): see validate-pipeline.sh's matching block for the rationale — this is now a
#    ONE-TIME structural check on the FIXED ci-manifest-runner.sh/lib-manifest.sh scripts, not a
#    per-root check on generated YAML text (there is no such generated text left to scan).
$runnerPs = "tests/.evals/scripts/ci-manifest-runner.sh"
$libManifestPs = "tests/.evals/scripts/lib-manifest.sh"
if ((Test-Path $runnerPs) -and (Test-Path $libManifestPs)) {
  if ((Select-String -Path $runnerPs -Pattern 'resolve_and_verify_root' -Quiet) -and (Select-String -Path $libManifestPs -Pattern 'resolve_and_verify_root\(\)' -Quiet)) {
    CheckOk "$runnerPs verifies each root via resolve_and_verify_root before running its command (V28)"
  } else {
    CheckFail "$runnerPs does not call resolve_and_verify_root - a root's command could run from an unverified working directory (V28, Section 4.0d.1)"
  }
  if ((Select-String -Path $runnerPs -Pattern 'root_touched' -Quiet) -and (Select-String -Path $libManifestPs -Pattern 'root_touched\(\)' -Quiet)) {
    CheckOk "$runnerPs diff-scopes each root via root_touched before running its command (V29)"
  } else {
    CheckFail "$runnerPs does not call root_touched - every root's install/build/coverage command would run unconditionally on every PR (V29, Section 4.0g)"
  }
} elseif (Test-Path $wf) {
  Note "V28/V29 skipped - $runnerPs or $libManifestPs not found (a legacy pre-#7a pipeline, or a variant not yet migrated)"
}

# ── Slot-equality (Section 3.1) is now STRUCTURAL under #7a, not a runtime check: both jobs call the
#    SAME fixed steps (Read manifest, Setup Node/Python/Java/Go/.NET, Install dependencies), so there is
#    no per-repo generated text left that could textually diverge between them — nothing to compare here
#    anymore. V27's structural-fidelity check is what still catches a step missing from either job.
if ($BaseSha -and (Test-Path "tests/.evals/scripts/run-static-evals.sh")) {
  Write-Host "  dry-run: run-static-evals against $BaseSha"
  bash tests/.evals/scripts/run-static-evals.sh $BaseSha 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 2) { CheckFail "run-static-evals crashed (exit 2)" }
  else { CheckOk "run-static-evals executed (exit $LASTEXITCODE — a real finding is a valid outcome)" }
} else { Note "dry-run skipped — pass a base sha to enable" }

Note "Not mechanically checked here — verify manually before commit: V3 (every repo script/lockfile the manifest resolved to actually exists — Section 1's own read-never-assume rule), V5 (every secrets.* the workflow references is named in the generation announcement), V17 (the eval.json/judge evidence round trip — needs live judge credentials to exercise), V21 (tool-install retry with an OCI-container fallback, Section 2.4.1)."

Write-Host ""
if ($script:rc -ne 0) { Write-Host "validate-pipeline: FAILED — the pipeline is NOT committed." }
else { Write-Host "validate-pipeline: PASSED — safe to commit." }
exit $script:rc
