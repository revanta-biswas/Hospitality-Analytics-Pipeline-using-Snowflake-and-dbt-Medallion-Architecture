# Resolve the work-unit EVAL_KEY from a branch ref (PowerShell variant of resolve-eval-key.sh).
# 🔴 A branch ref contains a slash; the evidence key must NOT. Prefixes come from
#    tests/.evals/config.json -> ci.integrationBranchPrefixes (SINGLE SOURCE OF TRUTH) so `ci/**` no longer
#    crashes here. Fails LOUDLY — never falls through to `unknown`.
param([string]$HeadRef = "", [string]$RefName = "")
$ErrorActionPreference = "Stop"

$ref = if ($HeadRef) { $HeadRef } else { $RefName }
if (-not $ref) { Write-Error "EVAL_KEY unresolved: no branch ref supplied"; exit 1 }

$prefixes = @("epic","bug","enhancement","ci","story","ve")
$config = "tests/.evals/config.json"
if ((Test-Path $config) -and (Get-Command jq -ErrorAction SilentlyContinue)) {
  $fromManifest = (jq -r '.ci.integrationBranchPrefixes // [] | join(" ")' $config) 2>$null
  if ($fromManifest) { $prefixes = $fromManifest -split '\s+' }
}

$key = ""
foreach ($p in $prefixes) {
  if ($ref -like "$p/*") {
    $rest = $ref.Substring($p.Length + 1)
    $segs = $rest -split '-'
    $first = $segs[0]
    $second = if ($segs.Length -gt 1) { $segs[1] } else { "" }
    if ($first -match '^[0-9]+$') {
      $ident = $first                       # story/2-frontend-... -> story-2
    } elseif ($second -match '^[0-9]+$') {
      $ident = "$first-$second"             # bug/PROJ-102-title  -> bug-PROJ-102
    } else {
      $ident = $first                       # ci/agentic-eval-... -> ci-agentic
    }
    $key = "$p-$ident"
    break
  }
}
if (-not $key) { $key = ($ref -replace '/', '-' -replace '[^A-Za-z0-9._-]', '-') }

if ($key -match '/' -or -not $key) {
  Write-Error "EVAL_KEY unresolved from '$ref' -> '$key' (still contains '/' or empty)"; exit 1
}

if ($env:GITHUB_OUTPUT) { "key=$key" | Out-File -Append -Encoding utf8 $env:GITHUB_OUTPUT }
Write-Output $key
