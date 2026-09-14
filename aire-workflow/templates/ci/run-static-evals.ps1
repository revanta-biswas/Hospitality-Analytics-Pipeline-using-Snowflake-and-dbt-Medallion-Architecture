# run-static-evals.ps1 — D1–D7 static eval gate, DELTA-SCOPED (PowerShell variant of run-static-evals.sh).
# 🔴 Local gate AND CI call this; diff logic lives here ONCE. Reads ci.tools/ci.sourcePaths/thresholds
#    from tests/.evals/config.json. NO STUBS: a gate that cannot run => ERROR + non-zero exit; never a fake PASS/N/A.
param([string]$BaseSha = "", [switch]$CoverageOnly)
$ErrorActionPreference = "Continue"

$config = "tests/.evals/config.json"

# ============================================================================================
# 🔴 THIS VARIANT DOES NOT IMPLEMENT ci.roots[] AND MUST NOT PRETEND TO.
#    run-static-evals.sh carries the full multi-root engine (per-root cd, markerFile verification,
#    transitive dependsOn diff-scoping, the cobertura/jacoco/lcov/gocover coverage parsers, the
#    unmatched-file sentinel). This PowerShell variant was never ported - it still assumes a single
#    implicit "src" root.
#    Silently running it would be the worst outcome available: the developer's LOCAL gate would enforce
#    a materially DIFFERENT contract from the one CI enforces, which is precisely what
#    ci-pipeline-generation.md Section 7 exists to forbid ("CI re-verifies in a clean environment what
#    was verified on the developer's machine"). A green local run would mean nothing.
#    So it refuses, loudly, and names the supported path. Exit 2 = setup/tooling problem, never a gate
#    result - it can never be mistaken for a PASS.
$mergedManifestPath = "tests/.evals/_run/merged-manifest.json"
$configPath = "tests/.evals/config.json"
$hasRoots = $false
if (Test-Path $configPath) {
  try {
    $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
    if ($cfg.ci.roots -and @($cfg.ci.roots).Count -gt 0) { $hasRoots = $true }
  } catch { }
}
# 🔴 FRAGMENTS ARE WHERE ROOTS ACTUALLY ACCUMULATE. Checking only config.json and the merged manifest
#    missed the normal case entirely: reconciliation never edits config.json (it writes a NEW file per
#    work unit under ci-manifest.d/), and tests/.evals/_run/ is gitignored and rm -rf'd in CI - so on a
#    fresh clone or a clean dev box neither signal exists and this script sailed past the refusal to
#    enforce the single-implicit-src-root contract, which is the exact divergence it exists to prevent.
$fragmentDir = "tests/.evals/ci-manifest.d"
$hasFragments = (Test-Path $fragmentDir) -and (@(Get-ChildItem -Path $fragmentDir -Filter *.json -File -ErrorAction SilentlyContinue).Count -gt 0)
if ((Test-Path $mergedManifestPath) -or $hasRoots -or $hasFragments) {
  Write-Error @"
run-static-evals.ps1: REFUSING TO RUN - this repository uses the ci.roots[] manifest, which only
run-static-evals.sh implements. Running this variant would enforce a DIFFERENT contract than CI and
report a meaningless PASS.

Run the supported variant instead:

    bash tests/.evals/scripts/run-static-evals.sh <base-sha>

On Windows use Git Bash or WSL. CI (ubuntu-latest) always uses the .sh variant, so this is the same
engine your PR will actually be judged by.
"@
  exit 2
}
# ============================================================================================

$evalKey = if ($env:EVAL_KEY) { $env:EVAL_KEY } else { "local" }
$evidenceDir = "reports/eval-evidence/$evalKey"
$staticDir = "$evidenceDir/static"
New-Item -ItemType Directory -Force -Path "$staticDir/baseline","$evidenceDir/judge","tests/.evals/_run" | Out-Null

function Fail($m) { Write-Error "run-static-evals: ERROR: $m" }
if (-not $BaseSha) { Fail "no BASE_SHA supplied — cannot compute a delta"; exit 2 }
if (-not (Test-Path $config)) { Fail "$config missing"; exit 2 }
if (-not (Get-Command jq -ErrorAction SilentlyContinue)) { Fail "jq not installed"; exit 2 }

$tools = @(jq -r '.ci.tools[]?' $config)
$sources = @(jq -r '.ci.sourcePaths[]?' $config); if ($sources.Count -eq 0) { $sources = @("src") }
$semCrit = [int](jq -r '.thresholds.semgrepFindingsAllowed.critical // 0' $config)
$semHigh = [int](jq -r '.thresholds.semgrepFindingsAllowed.high // 0' $config)
$secretsAllowed = [int](jq -r '.thresholds.secretFindingsAllowed // 0' $config)

$gatesFile = "$staticDir/static-results.json.gates"
# 🔴 Only the D1–D7 pass starts a fresh gates file. The -CoverageOnly pass (run later, after the
#    coverage report exists) APPENDS its one line to the SAME file so both invocations land in the
#    same eval.json — never truncate here when only computing the coverage gate.
if (-not $CoverageOnly) { Remove-Item -ErrorAction SilentlyContinue $gatesFile }
$script:overallFail = 0
function Record($id, $status, $reason) {
  "$id`t$status`t$reason" | Out-File -Append -Encoding utf8 $gatesFile
  if ($status -in @("FAIL","ERROR")) { $script:overallFail = 1 }
}
function HasTool($t) { return $tools -contains $t }

# 🔴 D1–D7 run only on the normal pass — see the matching comment in run-static-evals.sh.
if (-not $CoverageOnly) {

if (HasTool "semgrep") {
  if (Get-Command semgrep -ErrorAction SilentlyContinue) {
    $out = "$staticDir/semgrep-delta.json"
    semgrep --config auto --baseline-commit $BaseSha --json --quiet @sources 2>$null | Out-File -Encoding utf8 $out
    if ($LASTEXITCODE -eq 0 -or (Test-Path $out)) {
      $crit = [int](jq '[.results[]? | select(.extra.severity=="ERROR")] | length' $out)
      $high = [int](jq '[.results[]? | select(.extra.severity=="WARNING")] | length' $out)
      if ($crit -gt $semCrit -or $high -gt $semHigh) {
        Record "D3_sast" "FAIL" "new semgrep findings: $crit critical, $high high (allowed $semCrit/$semHigh)"
      } else { Record "D3_sast" "PASS" "no new findings above threshold" }
    } else { Record "D3_sast" "ERROR" "semgrep run failed" }
  } else { Record "D3_sast" "ERROR" "semgrep in manifest but not installed" }
}

if (HasTool "gitleaks") {
  if (Get-Command gitleaks -ErrorAction SilentlyContinue) {
    $out = "$staticDir/gitleaks-delta.json"
    gitleaks detect --no-banner --redact --report-format json --report-path $out --log-opts "$BaseSha..HEAD" 2>$null | Out-Null
    $n = if (Test-Path $out) { [int](jq 'length' $out) } else { 0 }
    if ($n -gt $secretsAllowed) { Record "D7_secrets" "FAIL" "$n secret finding(s) in new commits (allowed $secretsAllowed)" }
    else { Record "D7_secrets" "PASS" "no new secrets" }
  } else { Record "D7_secrets" "ERROR" "gitleaks in manifest but not installed" }
}

}   # end: D3/D7 run only on the normal (non -CoverageOnly) pass

# D1/D2/D4/D5/D6: two-pass baseline diff. The BASE side is the baseline dev-implement.md Step 4.6
# already captured and COMMITTED to this story branch, once, before any code was generated — DeltaDiff
# below reuses that committed file directly instead of re-deriving it. The generator resolves the
# concrete invocations between the markers below (Section 3), or a TRUE N/A, or ERROR — never a silent
# skip. Captured once, before any stash/checkout cycle, so every restore targets a known-good ref.
$script:OrigRef = (git symbolic-ref -q --short HEAD 2>$null)
if (-not $script:OrigRef) { $script:OrigRef = (git rev-parse HEAD) }

function DeltaDiff($gate, $cmd) {
  $base = "$staticDir/baseline/$gate.txt"; $head = "$staticDir/$gate-head.txt"

  # 🔴 REUSE the already-committed baseline when one exists. dev-implement.md Step 4.6 captures this
  #    EXACT file once, on the story branch, BEFORE any code is generated, and commits it — making
  #    reports/eval-evidence/<key>/static/baseline/ a TRACKED path in this branch's history, never
  #    disposable scratch space. Recomputing it here via a BaseSha checkout writes an untracked file
  #    at that same tracked path while displaced at BaseSha; returning to OrigRef then makes git
  #    REFUSE the checkout ("untracked working tree file would be overwritten by checkout") because
  #    the committed version is still sitting there — a real FATAL abort, observed in CI. Trust the
  #    committed baseline and skip the whole checkout dance in that case; only recompute via checkout
  #    when no baseline is committed yet (the pre-story epic-level smoke test, which has no story
  #    branch to have captured one — ci-pipeline-generation.md Section 4.0.6).
  if (-not (Test-Path $base)) {
    $beforeStash = (git stash list).Count
    git stash push -q --include-untracked 2>$null | Out-Null
    $afterStash = (git stash list).Count
    $stashed = $afterStash -gt $beforeStash

    $checkoutErr = (git checkout -q $BaseSha 2>&1)
    if ($LASTEXITCODE -ne 0) {
      Record $gate "ERROR" "cannot checkout base ref: $checkoutErr"
      if ($stashed) {
        git stash pop -q 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
          Fail "FATAL: could not restore stash after a failed checkout — working tree left dirty. Aborting rather than running further gates or stages against a broken tree."
          exit 3
        }
      }
      return
    }

    # 🔴 Defensive re-mkdir: the checkout above can leave this untracked directory gone by the time we
    #    write to it. Without this, the write below silently fails, the baseline read comes back empty,
    #    and every pre-existing finding gets miscounted as "new" — a fabricated FAIL from a capture
    #    that never actually happened (violates Section 5.0 NO STUBS).
    New-Item -ItemType Directory -Force -Path "$staticDir/baseline" | Out-Null
    Invoke-Expression $cmd 2>$null | Out-File -Encoding utf8 $base
    $baseOk = Test-Path $base

    $checkoutErr = (git checkout -q $script:OrigRef 2>&1)
    if ($LASTEXITCODE -ne 0) {
      Fail "FATAL: could not return to $script:OrigRef after checking out the base ref: $checkoutErr. Aborting rather than running further gates or stages against a broken tree."
      exit 3
    }

    if ($stashed) {
      $checkoutErr = (git stash pop -q 2>&1)
      if ($LASTEXITCODE -ne 0) {
        Fail "FATAL: git stash pop failed (likely a conflict): $checkoutErr. Working tree left dirty. Aborting rather than running further gates or stages against a broken tree."
        exit 3
      }
    }

    if (-not $baseOk) {
      Record $gate "ERROR" "baseline capture failed — $base was not written while checked out at $BaseSha (cannot compute a delta from a missing baseline, Section 5.0)"
      return
    }
  }

  New-Item -ItemType Directory -Force -Path $staticDir | Out-Null
  Invoke-Expression $cmd 2>$null | Out-File -Encoding utf8 $head
  if (-not (Test-Path $head)) {
    Record $gate "ERROR" "head capture failed — $head was not written at $script:OrigRef"
    return
  }
  $baseSet = @(Get-Content $base -ErrorAction SilentlyContinue | Sort-Object -Unique)
  $headSet = @(Get-Content $head -ErrorAction SilentlyContinue | Sort-Object -Unique)
  $new = @($headSet | Where-Object { $baseSet -notcontains $_ }).Count
  if ($new -gt 0) { Record $gate "FAIL" "$new new finding(s) vs baseline on changed files" }
  else { Record $gate "PASS" "no new findings vs baseline" }
}
function CoverageDelta {
  $min = [double](jq -r '.thresholds.unitTestCoverageMin // 90' $config)

  $reportCount = [int](jq -r '.ci.coverageReports // [] | length' $config)
  $reportPaths = @(); $reportFormats = @(); $reportSourcePaths = @()
  if ($reportCount -gt 0) {
    $rows = @(jq -r '.ci.coverageReports[] | [.path, .format, (.sourcePaths // [] | join("|"))] | @tsv' $config)
    foreach ($row in $rows) {
      $parts = $row -split "`t"
      $reportPaths += $parts[0]; $reportFormats += $parts[1]; $reportSourcePaths += $parts[2]
    }
  } else {
    $singlePath = (jq -r '.ci.coverageReportPath // ""' $config)
    $singleFormat = (jq -r '.ci.coverageFormat // ""' $config)
    if (-not $singlePath -or -not $singleFormat) {
      Record "unitCoverage" "ERROR" "neither ci.coverageReports nor ci.coverageReportPath/ci.coverageFormat is set in the manifest — cannot compute the delta-scoped coverage gate (Section 4.0b)"
      return
    }
    $reportPaths = @($singlePath); $reportFormats = @($singleFormat)
    $reportSourcePaths = @(($sources -join '|'))
  }

  $changed = @(git diff --name-only "$BaseSha...HEAD" -- @sources 2>$null | Where-Object { $_ })
  if ($changed.Count -eq 0) {
    Record "unitCoverage" "PASS" "no changed files under $($sources -join ',') — threshold vacuously satisfied"
    return
  }

  $hit = 0; $found = 0; $hadError = $false

  foreach ($f in $changed) {
    $matchedIdx = -1
    for ($i = 0; $i -lt $reportSourcePaths.Count; $i++) {
      $spArr = $reportSourcePaths[$i] -split '\|'
      $matched = $false
      foreach ($sp in $spArr) {
        if ($f -eq $sp -or $f.StartsWith("$sp/")) { $matched = $true; break }
      }
      if ($matched) { $matchedIdx = $i; break }
    }
    if ($matchedIdx -eq -1) { continue }   # not owned by any configured report — not every changed file is coverable

    $rp = $reportPaths[$matchedIdx]; $rfmt = $reportFormats[$matchedIdx]
    if (-not (Test-Path $rp)) {
      Write-Host "run-static-evals: ERROR: unitCoverage: coverage report not found at $rp — needed for changed file $f"
      $hadError = $true
      continue
    }

    switch ($rfmt) {
      "cobertura" {
        [xml]$xmlDoc = Get-Content $rp -Raw
        $classes = $xmlDoc.SelectNodes("//class") | Where-Object {
          $_.filename -eq $f -or $_.filename.EndsWith("/$f") -or $f.EndsWith("/$($_.filename)")
        }
        foreach ($cls in $classes) {
          foreach ($line in $cls.lines.line) {
            $found++
            if ([int]$line.hits -gt 0) { $hit++ }
          }
        }
      }
      "lcov" {
        # Bidirectional match — see the matching comment in run-static-evals.sh's coverage_delta().
        $curFile = ""; $active = $false; $curLH = 0; $curLF = 0
        foreach ($line in (Get-Content $rp)) {
          if ($line -match '^SF:(.*)$') {
            $curFile = $matches[1]
            $active = ($curFile -eq $f) -or $curFile.EndsWith("/$f") -or $f.EndsWith("/$curFile")
          } elseif ($active -and $line -match '^LH:(\d+)$') {
            $curLH = [int]$matches[1]
          } elseif ($active -and $line -match '^LF:(\d+)$') {
            $curLF = [int]$matches[1]
          } elseif ($line -match '^end_of_record$' -and $active) {
            $hit += $curLH; $found += $curLF
            $active = $false; $curLH = 0; $curLF = 0
          }
        }
      }
      default {
        Write-Host "run-static-evals: ERROR: unitCoverage: unsupported format '$rfmt' for report $rp — only cobertura and lcov are implemented"
        $hadError = $true
      }
    }
  }

  if ($hadError) {
    Record "unitCoverage" "ERROR" "one or more changed files' coverage reports were missing or unsupported — see the job log above"
    return
  }
  if ($found -eq 0) {
    Record "unitCoverage" "ERROR" "no coverage data found for any changed file across the configured report(s) — report/changed-file path mismatch"
    return
  }

  $pct = [math]::Round(($hit / $found) * 100, 1)
  if ($pct -ge $min) {
    Record "unitCoverage" "PASS" "changed-file coverage $pct% >= $min% ($hit/$found lines)"
  } else {
    Record "unitCoverage" "FAIL" "changed-file coverage $pct% < $min% ($hit/$found lines)"
  }
}

if (-not $CoverageOnly) {
# >>> STACK-RESOLVED D-GATES START <<<
# >>> STACK-RESOLVED D-GATES END <<<
}

# unitCoverage runs ONLY on the -CoverageOnly pass, called after "unit + coverage" has produced the
# report this function reads (Section 4.0b). See the CoverageDelta definition above.
if ($CoverageOnly) { CoverageDelta }

Write-Output "static eval gates (delta vs $BaseSha):"
Get-Content $gatesFile -ErrorAction SilentlyContinue | ForEach-Object {
  $p = $_ -split "`t"; "{0,-14} {1,-5} {2}" -f $p[0],$p[1],$p[2]
}
if ($script:overallFail -ne 0) { Write-Error "run-static-evals: at least one D-gate FAILED or ERRORED"; exit 1 }
exit 0
