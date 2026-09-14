# lib-manifest.ps1 — shared manifest primitives (PowerShell variant of lib-manifest.sh).
# See lib-manifest.sh for the full contract and rationale. Dot-source this file:  . ./lib-manifest.ps1

# 🔴 Parity with lib-manifest.sh's lib_manifest_defect(): a Manifest-class defect is recorded to a
#    MACHINE-READABLE marker, not only to the error stream. auto-fix-agent.* reads this file to apply
#    Section 6.4's Manifest triage class (report and stop, never repair, never consume a retry).
if (-not $script:ManifestDefectsFile) { $script:ManifestDefectsFile = "tests/.evals/_run/manifest-defects.txt" }
function Write-ManifestDefect {
  param([string]$Message)
  Write-Error "lib-manifest: $Message"
  try {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $script:ManifestDefectsFile) | Out-Null
    Add-Content -Path $script:ManifestDefectsFile -Value $Message -Encoding utf8
  } catch { }
}

# 🔴 WINDOWS POWERSHELL 5.1 DOES NOT ENUMERATE A TOP-LEVEL JSON ARRAY THROUGH THE PIPELINE.
#    `@(Get-Content f -Raw | ConvertFrom-Json)` on `[{...},{...}]` yields a ONE-element array whose
#    single member is the whole Object[] (measured: Count=1, inner type Object[]). Every downstream
#    `Where-Object { $_.root -eq $X }` then matched that wrapper via member-enumeration + array -eq
#    FILTER semantics, so the lookup returned the union of EVERY root's fields regardless of $X - the
#    dependency test answered "does any edge anywhere point at a changed path", not "does THIS root
#    depend on one". Fail-open (over-builds), but the parity claim was false.
function ConvertFrom-JsonArray {
  param([string]$Text)
  if (-not $Text) { return ,@() }
  $parsed = $null
  try { $parsed = $Text | ConvertFrom-Json } catch { return ,@() }
  if ($null -eq $parsed) { return ,@() }
  # 🔴 `,` prevents PowerShell from UNROLLING a single-element array on return - without it a
  #    one-root manifest comes back as a bare PSCustomObject whose .Count is $null, and any caller
  #    doing a count check silently sees "empty".
  if ($parsed -is [Array]) { return ,$parsed }
  return ,@($parsed)
}

function Build-MergedManifest {
  param([string]$ConfigPath, [string]$ManifestDir, [string]$OutPath)
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutPath) | Out-Null
  $base = @()
  if (Test-Path $ConfigPath) {
    $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    if ($cfg.ci.roots) { if ($cfg.ci.roots -is [Array]) { $base = $cfg.ci.roots } else { $base = @($cfg.ci.roots) } }
  }
  $fragments = @()
  if (Test-Path $ManifestDir) {
    Get-ChildItem -Path $ManifestDir -Filter "*.json" -File | Sort-Object Name | ForEach-Object {
      $frText = Get-Content $_.FullName -Raw
      $frEntries = ConvertFrom-JsonArray -Text $frText
      if ($frEntries.Count -eq 0 -and $frText.Trim()) {
        # a fragment that does not parse is a Manifest defect, never an empty array - parity with
        # lib-manifest.sh: dropping it silently removes every root it declares from the merged view
        Write-ManifestDefect "MANIFEST DEFECT - fragment '$($_.FullName)' is not valid JSON. Every ci.roots[] entry it declares is missing from the merged manifest, so those roots would be gated by nothing."
      }
      foreach ($fe in $frEntries) { $fragments += $fe }
    }
  }
  $all = @($base) + @($fragments)
  $merged = @{}
  $order = @()
  foreach ($e in $all) {
    if (-not $e.root) { continue }
    if (-not $merged.ContainsKey($e.root)) {
      $merged[$e.root] = [ordered]@{
        root = $e.root; tools = @(); sourcePaths = @(); testPaths = @(); installCommands = @(); dependsOn = @(); toolchainSetup = @()
      }
      $order += $e.root
    }
    $acc = $merged[$e.root]
    foreach ($prop in $e.PSObject.Properties) {
      # dependsOn/toolchainSetup are arrays too - omitting them made the merge REPLACE rather than
      # union, so a second fragment erased every dependency edge it did not restate (same defect as
      # lib-manifest.sh's jq union list).
      if ($prop.Name -in @("tools", "sourcePaths", "testPaths", "installCommands", "dependsOn", "toolchainSetup")) {
        $existing = @($acc[$prop.Name])
        $incoming = @($prop.Value)
        $acc[$prop.Name] = @($existing + $incoming | Select-Object -Unique)
      } else {
        $acc[$prop.Name] = $prop.Value
      }
    }
  }
  $result = @()
  foreach ($r in $order) { $result += [pscustomobject]$merged[$r] }
  # 🔴 -AsArray is PowerShell 7+ ONLY and THROWS on Windows PowerShell 5.1 ("A parameter cannot be
  #    found that matches parameter name AsArray"), so Build-MergedManifest could not write the
  #    manifest at all there - and ci-manifest-runner.ps1 sets $ErrorActionPreference='Continue', so
  #    it carried on with no manifest rather than stopping. Wrap manually instead.
  if (@($result).Count -eq 0) {
    "[]" | Out-File -Encoding utf8 $OutPath
  } elseif (@($result).Count -eq 1) {
    ("[" + ($result | ConvertTo-Json -Depth 10) + "]") | Out-File -Encoding utf8 $OutPath
  } else {
    ($result | ConvertTo-Json -Depth 10) | Out-File -Encoding utf8 $OutPath
  }
}

function Resolve-AndVerifyRoot {
  param([string]$Root, [string]$Marker = "")
  $repoRoot = (git rev-parse --show-toplevel 2>$null)
  if (-not $repoRoot) { Write-Error "lib-manifest: git rev-parse --show-toplevel failed - not a git checkout?"; return $null }
  $abs = Join-Path $repoRoot $Root
  if (-not (Test-Path $abs -PathType Container)) {
    Write-ManifestDefect "MANIFEST DEFECT - ci.roots[] root '$Root' does not exist at $abs. Fix tests/.evals/config.json's ci.roots, not this script (Section 6.4's Manifest triage class)."
    return $null
  }
  if ($Marker -and -not (Test-Path (Join-Path $abs $Marker))) {
    Write-ManifestDefect "MANIFEST DEFECT - root '$Root' declares a marker file '$Marker' that is not present at $abs. The recorded root no longer matches a real project (renamed/moved?). Fix tests/.evals/config.json's ci.roots, not this script."
    return $null
  }
  return $abs
}

function Test-RootPrefixTouched {
  param([string]$Root, [string]$Changed)
  if ($Root -eq ".") { return $true }
  $r = $Root.TrimEnd("/")
  foreach ($line in ($Changed -split "`n")) {
    $l = $line.Trim()
    if (-not $l) { continue }
    if ($l -eq $r -or $l.StartsWith($r + "/")) { return $true }
  }
  return $false
}

# TRANSITIVE dependency closure over ci.roots[].dependsOn - cycle-safe via the visited set.
# Parity with lib-manifest.sh's _root_dep_touched; see that file for the full rationale.
function Test-RootDepTouched {
  param([string]$Root, [string]$Changed, [System.Collections.Generic.HashSet[string]]$Seen)
  $mm = $env:MERGED_MANIFEST
  if (-not $mm) { $mm = "tests/.evals/_run/merged-manifest.json" }
  if (-not (Test-Path $mm)) { return $false }
  if (-not $Seen.Add($Root)) { return $false }   # already visited - cycle guard
  $entries = ConvertFrom-JsonArray -Text (Get-Content $mm -Raw)
  $entry = $entries | Where-Object { $_.root -eq $Root } | Select-Object -First 1
  if (-not $entry -or -not $entry.dependsOn) { return $false }
  foreach ($dep in @($entry.dependsOn)) {
    if (Test-RootPrefixTouched -Root $dep -Changed $Changed) { return $true }
    if (Test-RootDepTouched -Root $dep -Changed $Changed -Seen $Seen) { return $true }
  }
  return $false
}

# A ROOT IS TOUCHED WHEN IT, OR ANYTHING IT CONSUMES, CHANGED. A root with no dependsOn behaves
# exactly as the old pure-prefix test did.
function Test-RootTouched {
  param([string]$Root, [string]$Changed)
  if (Test-RootPrefixTouched -Root $Root -Changed $Changed) { return $true }
  $seen = New-Object System.Collections.Generic.HashSet[string]
  return (Test-RootDepTouched -Root $Root -Changed $Changed -Seen $seen)
}
