# read-manifest.ps1 — PowerShell variant of read-manifest.sh. See that file for the full contract.
# Prints has_<stack>=true|false and <stack>_version=... lines, suitable for appending to $env:GITHUB_OUTPUT.
$ErrorActionPreference = "Continue"

$config = "tests/.evals/config.json"
$manifestDir = "tests/.evals/ci-manifest.d"
$mergedManifest = "tests/.evals/_run/merged-manifest.json"
$stacks = @("node", "python", "java", "go", "dotnet")

$libDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $libDir "lib-manifest.ps1")

if (-not (Test-Path $config)) { Write-Error "read-manifest: ERROR: $config missing"; exit 2 }

Build-MergedManifest -ConfigPath $config -ManifestDir $manifestDir -OutPath $mergedManifest
$merged = @()
try { $merged = @(Get-Content $mergedManifest -Raw | ConvertFrom-Json) } catch { $merged = @() }

foreach ($stack in $stacks) {
  $matching = @($merged | Where-Object { $_.stack -eq $stack })
  $present = $matching.Count -gt 0
  Write-Output "has_${stack}=$($present.ToString().ToLower())"
  if ($present) {
    $version = $matching[0].runtimeVersion
    if (-not $version) { $version = "" }
    Write-Output "${stack}_version=$version"
  } else {
    Write-Output "${stack}_version="
  }
}
