# run-evals.ps1 — J1/J2 judge gates + merge all results into eval.json (PowerShell variant of run-evals.sh).
# 🔴 The gates block iterates ci.gates (SINGLE SOURCE OF TRUTH). NO STUBS: missing credentials => ERROR,
#    not N/A; a malformed judge response => ERROR after one retry. Legitimate J1/J2 N/A: rubric absent,
#    or an empty diff vs BaseSha (pre-story/zero-diff run — never send an empty diff to the judge).
param([string]$BaseSha = "")
$ErrorActionPreference = "Continue"

$config = "tests/.evals/config.json"
$evalKey = if ($env:EVAL_KEY) { $env:EVAL_KEY } else { "local" }
$evidenceDir = "reports/eval-evidence/$evalKey"
$judgeDir = "$evidenceDir/judge"; $staticDir = "$evidenceDir/static"
New-Item -ItemType Directory -Force -Path $judgeDir,$staticDir,"tests/.evals/_run" | Out-Null

function Fail($m) { Write-Error "run-evals: ERROR: $m" }
if (-not (Test-Path $config)) { Fail "$config missing"; exit 2 }
if (-not (Get-Command jq -ErrorAction SilentlyContinue)) { Fail "jq not installed"; exit 2 }

$archMin = [double](jq -r '.thresholds.llmJudgeArchitectureScoreMin // 0.85' $config)
$secMin = [double](jq -r '.thresholds.llmJudgeSecurityScoreMin // 0.85' $config)
$model = (jq -r '.judge.model // ""' $config)
$rubricVersion = (jq -r '.judge.rubricVersion // ""' $config)
$gates = @(jq -r '.ci.gates[]?' $config)

if (-not $env:CLAUDE_CODE_OAUTH_TOKEN -and -not $env:ANTHROPIC_API_KEY) {
  Fail "no CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY — the judge gate should have run and did not"; exit 2
}
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { Fail "claude CLI not installed"; exit 2 }

# 🔴 An EMPTY --model argument is not a harmless default — claude rejects it outright:
#    "API Error: 400 model: String should have at least 1 character". Fail clearly here, before ever
#    constructing that invocation, rather than let judge.model silently resolve to an empty string.
if (-not $model) {
  Fail "judge.model is not set in $config - cannot invoke claude with an empty --model (set judge.model to a real model name/alias)"
  exit 2
}

function ScoreRubric($rubric, $out, $min) {
  if (-not (Test-Path $rubric)) {
    "{`"status`":`"N/A`",`"reason`":`"rubric $rubric absent — fallback chain bottomed out`"}" | Out-File -Encoding utf8 $out
    return 3
  }
  $diff = (git diff "$BaseSha...HEAD" 2>$null) -join "`n"
  if (-not $diff) {
    "{`"status`":`"N/A`",`"reason`":`"empty diff vs $BaseSha — nothing to score (pre-story/zero-diff run, ci-pipeline-generation.md Section 4.0.6)`"}" | Out-File -Encoding utf8 $out
    return 4
  }
  $prompt = @"
Score the PR diff against this rubric. Score EACH criterion independently (0.0-1.0). Every criterion
below 1.0 MUST cite file:line. Score only what the diff shows; a criterion the diff cannot exercise is
N/A and excluded with remaining weights renormalised to 1.0 — never scored 0. Return STRICT JSON ONLY.
RUBRIC:
$(Get-Content $rubric -Raw)
DIFF:
$diff
"@
  # 🔴 headless/permission flags are resolved from `claude --help` at GENERATION time and written in by
  #    the generator between the markers below — never assumed from memory. Same requirement Section
  #    6.0 states for auto-fix-agent.ps1, applied here too (ci-pipeline-generation.md Section 4.2,
  #    "Authentication alone is not enough") — a bare, unresolved `claude` invocation tries to start an
  #    interactive session with no TTY available in CI and exits almost immediately.
  $claudeErrFile = [System.IO.Path]::GetTempFileName()
  # >>> CLAUDE_JUDGE_INVOCATION START <<<
  $resp = ($prompt | claude 2>$claudeErrFile)
  $rc = $LASTEXITCODE
  # >>> CLAUDE_JUDGE_INVOCATION END <<<
  if ($rc -ne 0) {
    Fail "judge CLI invocation failed: $(Get-Content $claudeErrFile -Raw -ErrorAction SilentlyContinue)"
    Remove-Item -ErrorAction SilentlyContinue $claudeErrFile
    return 2
  }
  $json = ($resp | jq -c '.' 2>$null)
  if (-not $json) { $resp = ($prompt | claude 2>$claudeErrFile); $json = ($resp | jq -c '.' 2>$null) }
  Remove-Item -ErrorAction SilentlyContinue $claudeErrFile
  if (-not $json) {
    "{`"status`":`"ERROR`",`"reason`":`"judge returned unparseable output after one retry`"}" | Out-File -Encoding utf8 $out
    return 2
  }
  ($json | jq --arg m $model --arg rv $rubricVersion '. + {model:$m, rubricVersion:$rv}') | Out-File -Encoding utf8 $out
  $score = [double](jq -r '.score // 0' $out)
  if ($score -ge $min) { return 0 } else { return 1 }
}

$j1 = ScoreRubric "tests/.evals/rubrics/architecture-rubric.json" "$judgeDir/architecture-score.json" $archMin
$j1Status = switch ($j1) { 0 {"PASS"} 1 {"FAIL"} 3 {"N/A"} 4 {"N/A"} default {"ERROR"} }
$j2 = ScoreRubric "tests/.evals/rubrics/security-rubric.json" "$judgeDir/security-score.json" $secMin
$j2Status = switch ($j2) { 0 {"PASS"} 1 {"FAIL"} 3 {"N/A"} 4 {"N/A"} default {"ERROR"} }

$staticStatus = @{}; $staticReason = @{}
$gatesFile = "$staticDir/static-results.json.gates"
if (Test-Path $gatesFile) {
  Get-Content $gatesFile | ForEach-Object {
    $p = $_ -split "`t"; $staticStatus[$p[0]] = $p[1]; $staticReason[$p[0]] = $p[2]
  }
}
function StepStatus($g) { $f = "tests/.evals/_run/$g.status"; if (Test-Path $f) { Get-Content $f -Raw } else { "N/A" } }

$anyFail = $false
$gateObjs = foreach ($g in $gates) {
  switch -Regex ($g) {
    # 🔴 unitCoverage reads from $staticStatus (coverage_delta writes it via Record into the same
    #    gates file as D1-D7), NOT from StepStatus — it was previously falling to `default` here,
    #    so its real computed result never reached eval.json. Fixed.
    '^D[1-7]_|^unitCoverage$' { $st = if ($staticStatus[$g]) { $staticStatus[$g] } else { "N/A" }; $rs = if ($staticReason[$g]) { $staticReason[$g] } else { "not run by static script" } }
    '^J1_' { $st = $j1Status; $rs = "architecture judge" }
    '^J2_' { $st = $j2Status; $rs = "security judge" }
    default { $st = (StepStatus $g).Trim(); $rs = "from workflow step outcome" }
  }
  if ($st -in @("FAIL","ERROR")) { $anyFail = $true }
  [pscustomobject]@{ id = $g; status = $st; reason = $rs }
}

$evalJson = "$evidenceDir/eval.json"
$gatesMap = @{}; foreach ($o in $gateObjs) { $gatesMap[$o.id] = @{ status = $o.status; reason = $o.reason } }
$verdict = if ($anyFail) { "FAIL" } else { "PASS" }
@{ evalKey = $evalKey; model = $model; rubricVersion = $rubricVersion; gates = $gatesMap; verdict = $verdict } |
  ConvertTo-Json -Depth 6 | Out-File -Encoding utf8 $evalJson

$summary = @("# AIRE eval summary — $evalKey","","| Gate | Status | Notes |","|---|---|---|")
foreach ($o in $gateObjs) { $summary += "| $($o.id) | $($o.status) | $($o.reason) |" }
$summary += @("","**Verdict:** $verdict")
$summary -join "`n" | Out-File -Encoding utf8 "$evidenceDir/eval-summary.md"

Write-Output "run-evals: wrote $evalJson (verdict $verdict)"
if ($verdict -ne "PASS") { exit 1 }
exit 0
