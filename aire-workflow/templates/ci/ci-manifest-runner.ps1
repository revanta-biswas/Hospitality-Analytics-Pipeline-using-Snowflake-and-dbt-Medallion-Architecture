# ci-manifest-runner.ps1 — PowerShell variant of ci-manifest-runner.sh. See that file for the full
# contract and rationale (#7a: reads the merged manifest at RUN TIME and executes install/build/coverage
# per root, diff-scoped).
param([string]$Mode = "", [string]$BaseSha = "")
$ErrorActionPreference = "Continue"

$config = "tests/.evals/config.json"
$manifestDir = "tests/.evals/ci-manifest.d"
$mergedManifest = "tests/.evals/_run/merged-manifest.json"

$libDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $libDir "lib-manifest.ps1")

function Fail($m) { Write-Error "ci-manifest-runner: ERROR: $m" }

if ($Mode -notin @("install", "build", "coverage")) {
  Fail "usage: ci-manifest-runner.ps1 -Mode <install|build|coverage> [-BaseSha <sha>]"
  exit 2
}
if (-not (Test-Path $config)) { Fail "$config missing - cannot resolve the manifest"; exit 2 }

Build-MergedManifest -ConfigPath $config -ManifestDir $manifestDir -OutPath $mergedManifest
$merged = @()
try { $merged = @(Get-Content $mergedManifest -Raw | ConvertFrom-Json) } catch { $merged = @() }

if ($merged.Count -eq 0) {
  Write-Output "ci-manifest-runner ($Mode): N/A - no roots in the merged manifest (manifestState: unresolved, or a legacy flat manifest with no roots[] at all)"
  exit 0
}

$changed = ""
if ($BaseSha) {
  $changed = (git diff --name-only "$BaseSha...HEAD" 2>$null) -join "`n"
}

$overallFail = 0

function Invoke-RootCommand {
  param($Root, $Stack, $Marker, $Cmd, $NoTestsExitCode)
  if ($BaseSha -and -not (Test-RootTouched -Root $Root -Changed $changed)) {
    Write-Output "ci-manifest-runner ($Mode): N/A - root '$Root' ($Stack) - no changed files under this root for this PR (diff-scoped, Section 4.0g)"
    return
  }
  $abs = Resolve-AndVerifyRoot -Root $Root -Marker $Marker
  if (-not $abs) {
    Write-ManifestDefect "MANIFEST DEFECT while running '$Mode' for root '$Root' - see above. Never a code defect; fix $config's ci.roots or the owning work unit's fragment."
    $script:overallFail = 1
    return
  }
  if (-not $Cmd) {
    Write-Output "ci-manifest-runner ($Mode): N/A - root '$Root' ($Stack) has no $Mode command (stack genuinely has none)"
    return
  }
  Write-Output "ci-manifest-runner ($Mode): running for root '$Root' ($Stack) at $abs"
  Push-Location $abs
  try {
    Invoke-Expression $Cmd
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
      # See lib-manifest.sh / ci-manifest-runner.sh for the full rationale: "the suite collected ZERO
      # tests" is N/A, never a failure, and never something to self-repair. pytest exits 5 and
      # jest/vitest exit 1 when they find no tests at all - the normal state of a greenfield repo before
      # its first story and of a brownfield repo with no suite yet. Treating it as code-class is what
      # once sent CI self-repair off to invent DUMMY TESTS to turn the gate green (an SH-6 fabricated
      # pass that then poisons the regression baseline). This cannot hide a missing test: coverage_delta()
      # still enforces the threshold on CHANGED files and records ERROR when one has no coverage data.
      if ($null -ne $NoTestsExitCode -and "$NoTestsExitCode" -ne "" -and $LASTEXITCODE -eq [int]$NoTestsExitCode) {
        Write-Output "ci-manifest-runner ($Mode): N/A - root '$Root' ($Stack) - the test runner collected ZERO tests (exit $LASTEXITCODE = ci.roots[].noTestsExitCode). No suite exists here yet; the delta-scoped coverage gate still enforces the threshold on any changed file."
      } else {
        Fail "root '$Root' ($Stack) - '$Mode' command failed: $Cmd"
        $script:overallFail = 1
      }
    } else {
      Write-Output "ci-manifest-runner ($Mode): root '$Root' - OK"
    }
  } catch {
    Fail "root '$Root' ($Stack) - '$Mode' command failed: $Cmd"
    $script:overallFail = 1
  } finally {
    Pop-Location
  }
}

switch ($Mode) {
  "install" {
    foreach ($e in $merged) {
      $root = $e.root; $stack = if ($e.stack) { $e.stack } else { "unknown" }; $marker = $e.markerFile
      $cmds = @($e.installCommands)
      if ($cmds.Count -eq 0) {
        Write-Output "ci-manifest-runner (install): N/A - root '$root' ($stack) has no installCommands"
        continue
      }
      if ($BaseSha -and -not (Test-RootTouched -Root $root -Changed $changed)) {
        Write-Output "ci-manifest-runner (install): N/A - root '$root' ($stack) - no changed files under this root for this PR (diff-scoped)"
        continue
      }
      $abs = Resolve-AndVerifyRoot -Root $root -Marker $marker
      if (-not $abs) {
        Write-ManifestDefect "MANIFEST DEFECT while running 'install' for root '$($e.root)' - see above. Never a code defect; fix $config's ci.roots or the owning work unit's fragment."
        $overallFail = 1; continue
      }
      foreach ($oneCmd in $cmds) {
        if (-not $oneCmd) { continue }
        Write-Output "ci-manifest-runner (install): root '$root' ($stack) at ${abs}: $oneCmd"
        Push-Location $abs
        try {
          Invoke-Expression $oneCmd
          if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            Fail "root '$root' ($stack) - install command failed: $oneCmd"
            $overallFail = 1
            break
          }
        } catch {
          Fail "root '$root' ($stack) - install command failed: $oneCmd"
          $overallFail = 1
          break
        } finally {
          Pop-Location
        }
      }
    }

    # Eval tools (semgrep, gitleaks, ...) deduped by name across every root's toolInstallCommands - see
    # ci-manifest-runner.sh's matching block for the full rationale.
    $allTools = @($merged | ForEach-Object { $_.tools } | Where-Object { $_ } | ForEach-Object { $_ } | Select-Object -Unique)
    foreach ($tool in $allTools) {
      $cmd = $null
      foreach ($e in $merged) {
        if ($e.toolInstallCommands -and $e.toolInstallCommands.PSObject.Properties.Name -contains $tool) {
          $cmd = $e.toolInstallCommands.$tool
          break
        }
      }
      if (-not $cmd) {
        Write-ManifestDefect "MANIFEST DEFECT - tool '$tool' is listed in ci.roots[].tools but no root's toolInstallCommands names it. Fix the owning work unit's fragment, not this script."
        $overallFail = 1
        continue
      }
      Write-Output "ci-manifest-runner (install): eval tool '${tool}': $cmd"
      try {
        Invoke-Expression $cmd
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) { Fail "eval tool '$tool' install failed: $cmd"; $overallFail = 1 }
      } catch {
        Fail "eval tool '$tool' install failed: $cmd"
        $overallFail = 1
      }
    }
  }
  "build" {
    foreach ($e in $merged) {
      $stackName = "unknown"; if ($e.stack) { $stackName = $e.stack }
      Invoke-RootCommand -Root $e.root -Stack $stackName -Marker $e.markerFile -Cmd $e.buildCommand
    }
  }
  "coverage" {
    foreach ($e in $merged) {
      $stackName = "unknown"; if ($e.stack) { $stackName = $e.stack }
      Invoke-RootCommand -Root $e.root -Stack $stackName -Marker $e.markerFile -Cmd $e.coverageCommand -NoTestsExitCode $e.noTestsExitCode
    }
  }
}

exit $overallFail
