#!/usr/bin/env bash
# lib-manifest.sh — shared manifest primitives, sourced by every script that reads ci.roots[].
#
# 🔴 THE ONE PLACE this logic lives (common/ci-pipeline-generation.md Section 4.0f/4.0d/4.0g). Every
#    consumer — run-static-evals.*, ci-manifest-runner.*, the generated "Read manifest" YAML step —
#    sources THIS file rather than re-implementing any part of it. That is what makes it impossible for
#    the merge logic, the root-verification logic, or the diff-scope logic to drift between callers.
#
# Provides:
#   build_merged_manifest <config-path> <manifest-dir> <out-path>
#       Writes config.json's ci.roots[] UNIONED with every <manifest-dir>/*.json fragment (filename-
#       sorted, root-keyed merge) to <out-path>. See common/ci-pipeline-generation.md Section 4.0f.1 for
#       the merge semantics (array fields concatenated+deduped, scalar fields last-fragment-wins).
#   resolve_and_verify_root <root> [<marker>]
#       Prints the resolved absolute path on success (repo toplevel resolved FRESH every call — never
#       cached, so this is correct across dev-implement.md Step 1.75's parallel clones). Returns non-zero
#       and prints nothing on a Manifest defect (missing dir or missing marker) — callers must check the
#       exit code.
#   root_touched <root>
#       True if $CHANGED (must be set by the caller — `git diff --name-only <base>...HEAD`) contains a
#       path equal to, or nested under, <root>, OR under any root in <root>'s TRANSITIVE
#       ci.roots[].dependsOn closure. Always true for root ".". Section 4.0g's diff-scoping.
#       Reads $MERGED_MANIFEST (default tests/.evals/_run/merged-manifest.json) for the closure;
#       with no manifest or no dependsOn it degrades to the plain prefix test.
#
# Requires: jq. Callers must `set -uo pipefail` themselves; this file does not set shell options.

lib_manifest_fail() { echo "lib-manifest: ERROR: $*" >&2; }

# 🔴 A Manifest-class defect is recorded to a MACHINE-READABLE marker, not only to stderr.
#    auto-fix-agent.* reads this file to apply Section 6.4's Manifest triage class (report and stop,
#    never repair, never consume a retry). Before this existed the "MANIFEST DEFECT" string was
#    emitted by lib-manifest.*, ci-manifest-runner.* and run-static-evals.* and consumed by NOTHING —
#    so a stale ci.roots[] entry was triaged as a code defect and self-repair edited application
#    source to "fix" a configuration bug. Never downgrade this to a log grep: stderr is interleaved,
#    truncated and locale-dependent; the marker file is none of those.
MANIFEST_DEFECTS_FILE="${MANIFEST_DEFECTS_FILE:-tests/.evals/_run/manifest-defects.txt}"
lib_manifest_defect() {
  lib_manifest_fail "$*"
  mkdir -p "$(dirname "$MANIFEST_DEFECTS_FILE")" 2>/dev/null || true
  printf '%s\n' "$*" >> "$MANIFEST_DEFECTS_FILE" 2>/dev/null || true
}

build_merged_manifest() {
  local config="$1" manifest_dir="$2" out="$3"
  mkdir -p "$(dirname "$out")"
  {
    jq -n --argjson base "$(jq '.ci.roots // []' "$config" 2>/dev/null || echo '[]')" '$base'
    if [ -d "$manifest_dir" ]; then
      find "$manifest_dir" -maxdepth 1 -name '*.json' 2>/dev/null | sort | while IFS= read -r frag; do
        # 🔴 A FRAGMENT THAT DOES NOT PARSE IS A MANIFEST DEFECT, NEVER AN EMPTY ARRAY.
        #    `|| echo '[]'` silently dropped a corrupt fragment, and with it EVERY root that fragment
        #    declared: those roots then had no entry, so their install/build/coverage and D1-D7 all
        #    reported "no roots"/N-A and the build went green having gated nothing. Verified: a
        #    2-fragment repo with one corrupt file merged to 2 roots instead of 3, with no warning
        #    anywhere. Now it is recorded to the marker auto-fix-agent reads (Section 6.4 Manifest class).
        if ! jq -c '.' "$frag" 2>/dev/null; then
          lib_manifest_defect "MANIFEST DEFECT — fragment '${frag}' is not valid JSON. Every ci.roots[] entry it declares is missing from the merged manifest, so those roots would be gated by nothing. Fix or remove the fragment; never let it merge as an empty array."
          echo '[]'
        fi
      done
    fi
  } | jq -s '
    add | group_by(.root) | map(
      reduce .[] as $e (
        {root: null, tools: [], sourcePaths: [], testPaths: [], installCommands: [], dependsOn: [], toolchainSetup: []};
        # capture the accumulator PRE-merge array values as $acc first: dot-star-e REPLACES (does not
        # concatenate) array-valued fields, so reading dot-tools AFTER that merge would only ever see the
        # current entry tools, silently dropping every earlier fragment tools/sourcePaths/etc the moment
        # a second fragment touches the same root (confirmed as a real bug via testing before this fix)
        . as $acc
        | ($acc * $e)
        | .tools = (($acc.tools // []) + ($e.tools // []) | unique)
        | .sourcePaths = (($acc.sourcePaths // []) + ($e.sourcePaths // []) | unique)
        | .testPaths = (($acc.testPaths // []) + ($e.testPaths // []) | unique)
        | .installCommands = (($acc.installCommands // []) + ($e.installCommands // []) | unique)
        # 🔴 dependsOn and toolchainSetup are ARRAYS and MUST union like the rest. Falling through to
        #    ($acc * $e) meant jq REPLACED them (verified: {a:[1,2]} * {a:[3]} -> {a:[3]}), so the
        #    second work unit to reconcile an existing root ERASED every dependency edge it did not
        #    itself restate - reviving the exact monorepo skip this design exists to prevent. The
        #    documented contract (Section 4.0f.1) always said "array fields concatenated and deduped".
        | .dependsOn = (($acc.dependsOn // []) + ($e.dependsOn // []) | unique)
        | .toolchainSetup = (($acc.toolchainSetup // []) + ($e.toolchainSetup // []) | unique)
      )
    )
  ' | tr -d '\r' > "$out" 2>/dev/null || echo '[]' > "$out"
}

resolve_and_verify_root() {
  local root="$1" marker="${2:-}"
  local repo_root abs
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || { lib_manifest_fail "git rev-parse --show-toplevel failed — not a git checkout?"; return 1; }
  abs="${repo_root}/${root}"
  if [ ! -d "$abs" ]; then
    lib_manifest_defect "MANIFEST DEFECT — ci.roots[] root '${root}' does not exist at ${abs}. Fix tests/.evals/config.json's ci.roots, not this script (Section 6.4's Manifest triage class)."
    return 1
  fi
  # 🔴 markerFile MAY BE A GLOB. The schema (eval-framework.md Section 1.1) explicitly lists
  #    `*.csproj` and `*.sln` as valid values. `[ -e ]` does NOT glob-expand, so it tested for a file
  #    literally named "*.csproj" and always failed — while PowerShell's Test-Path DOES glob, so the
  #    SAME manifest passed on a Windows dev box and hard-failed as a MANIFEST DEFECT on every Linux
  #    CI run. Every .NET repo set up exactly as documented hit this. Unquoted ${marker} below is
  #    deliberate: that is what makes the glob expand. With no match the pattern stays literal and the
  #    -e test correctly fails, so a genuinely missing marker is still a defect.
  # 🔴 GLOB WITHOUT WORD-SPLITTING. Making the marker unquoted fixed `*.csproj` but introduced a new
  #    regression of the SAME shape: an ordinary .NET marker containing a space ("My App.sln") split
  #    into two words, matched nothing, and was reported a MANIFEST DEFECT even though the file exists
  #    - passing on Windows (Test-Path handles it) and hard-failing on Linux CI, exactly what the fix
  #    was written to remove. A literal marker is tested QUOTED; only a marker that actually contains
  #    glob metacharacters is expanded, and IFS is emptied around that expansion so the pattern itself
  #    is never split on spaces.
  local marker_found=0 _m _oldifs
  if [ -n "$marker" ]; then
    case "$marker" in
      *'*'*|*'?'*|*'['*)
        _oldifs="$IFS"; IFS=''
        for _m in "${abs}"/${marker}; do
          if [ -e "$_m" ]; then marker_found=1; break; fi
        done
        IFS="$_oldifs"
        ;;
      *)
        [ -e "${abs}/${marker}" ] && marker_found=1
        ;;
    esac
  fi
  if [ -n "$marker" ] && [ "$marker_found" -eq 0 ]; then
    lib_manifest_defect "MANIFEST DEFECT — root '${root}' declares a marker file '${marker}' that is not present at ${abs}. The recorded root no longer matches a real project (renamed/moved?). Fix tests/.evals/config.json's ci.roots, not this script."
    return 1
  fi
  printf '%s\n' "$abs"
  return 0
}

# Direct hit only: did the PR change a file at, or under, this exact root?
# Both stream sources below are piped through `tr -d` to drop carriage returns: a manifest,
# fragment or git output produced on Windows would otherwise yield "common<CR>", which equals no
# root and would silently disable the entire dependency closure.
# 🔴 NO REGEX. An earlier version built a grep -E pattern from the root, which meant every root
#    containing a regex metacharacter (a dot, a plus, brackets -- "src/app.v2", "packages/c++/core")
#    needed escaping, and a single escaping slip either matched paths the root does not own or
#    failed to match paths it does. Bash's own quoted case-pattern match needs no escaping at all:
#    inside case, "$r"/* treats $r literally and only the trailing /* is a wildcard.
_root_prefix_touched() {
  local root="$1" line r
  [ "$root" = "." ] && return 0
  r="${root%/}"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    [ "$line" = "$r" ] && return 0
    case "$line" in "$r"/*) return 0 ;; esac
  done < <(printf '%s\n' "${CHANGED:-}" | tr -d '\r')
  return 1
}

# 🔴 TRANSITIVE dependency closure over ci.roots[].dependsOn — cycle-safe via the visited list.
_root_dep_touched() {
  local root="$1" seen="$2" dep
  local mm="${MERGED_MANIFEST:-tests/.evals/_run/merged-manifest.json}"
  [ -f "$mm" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  case " $seen " in *" $root "*) return 1 ;; esac   # already visited — cycle guard
  seen="$seen $root"
  while IFS= read -r dep; do
    # tolerate CRLF: a manifest or fragment written on Windows yields a trailing
    # carriage return, which matches no root and silently disables the whole closure
    [ -z "$dep" ] && continue
    # A DANGLING dependsOn IS A MANIFEST DEFECT, NOT A NO-OP. One typo ("comon" for "common")
    # silently restored the exact pre-fix behaviour with zero signal: the edge resolved to nothing,
    # the dependent root was skipped, and the verdict was PASS. The whole value of the closure is
    # that a MISSING edge is invisible - so the edge itself has to be validated.
    if ! jq -e --arg d "$dep" 'any(.[]; .root == $d)' "$mm" >/dev/null 2>&1; then
      lib_manifest_defect "MANIFEST DEFECT - root '${root}' declares dependsOn '${dep}', which is not a root in the merged manifest. That edge resolves to nothing, so a change to the intended root would silently skip '${root}'. Fix the owning work unit's fragment."
    fi
    _root_prefix_touched "$dep" && return 0
    _root_dep_touched "$dep" "$seen" && return 0
  done < <(jq -r --arg r "$root" '.[] | select(.root == $r) | .dependsOn[]? // empty' "$mm" 2>/dev/null | tr -d '\r')
  return 1
}

# 🔴 A ROOT IS TOUCHED WHEN IT, OR ANYTHING IT CONSUMES, CHANGED.
#    This used to be a bare path-prefix test with no dependency model at all, which is only sound for
#    INDEPENDENT roots. Section 3 mandates one ci.roots[] entry PER PACKAGE for a monorepo, and every
#    idiomatic monorepo has intra-repo dependencies — so a PR touching only `common` skipped `api`
#    entirely: api was never compiled, its tests never ran, its D-gates reported N/A, and the verdict
#    was PASS. A compile-breaking change merged clean and became the baseline everything later was
#    diffed against. Same shape on pnpm/yarn workspaces, go.work, .sln ProjectReference, and
#    path-installed Python siblings.
#    A root with an empty (or absent) dependsOn behaves EXACTLY as before, so single-root repos and
#    genuinely independent packages are unaffected.
root_touched() {
  local root="$1"
  _root_prefix_touched "$root" && return 0
  _root_dep_touched "$root" "" && return 0
  return 1
}
