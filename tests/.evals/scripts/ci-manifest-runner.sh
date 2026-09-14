#!/usr/bin/env bash
# ci-manifest-runner.sh — reads the MERGED manifest (config.json + ci-manifest.d/ fragments) at RUN
# TIME and executes install/build/coverage for every root, diff-scoped. This is the #7a fix: the
# generated YAML calls THIS fixed, versioned script instead of baking per-repo install/build/coverage
# text once at generation time — so a later work unit's new root (a new fragment) is picked up on its
# own PR without ever touching the committed workflow file (common/ci-pipeline-generation.md Section 4.0d/4.0g).
#
# Contract:
#   arg1  MODE      — "install" | "build" | "coverage"
#   arg2  BASE_SHA  — required for install/build (diff-scoping); coverage runs unconditionally per root
#                     that has changed files, same as install/build, but always produces its report
#                     (the report is what run-static-evals.sh's coverage_delta() later reads)
#   Exits non-zero if ANY root's command fails. A root the PR never touched is skipped (diff-scoped,
#   Section 4.0g) and reported N/A on stdout — never silently absent.
set -uo pipefail

MODE="${1:-}"
BASE_SHA="${2:-}"
CONFIG="tests/.evals/config.json"
MANIFEST_DIR="tests/.evals/ci-manifest.d"
MERGED_MANIFEST="tests/.evals/_run/merged-manifest.json"

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-manifest.sh
source "${LIB_DIR}/lib-manifest.sh"

fail() { echo "ci-manifest-runner: ERROR: $*" >&2; }

case "$MODE" in
  install|build|coverage|toolchain) ;;
  *) fail "usage: ci-manifest-runner.sh <install|build|coverage|toolchain> [base-sha]"; exit 2 ;;
esac
if [ ! -f "$CONFIG" ]; then
  fail "$CONFIG missing — cannot resolve the manifest"
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  fail "jq not installed — required to read the manifest"
  exit 2
fi

build_merged_manifest "$CONFIG" "$MANIFEST_DIR" "$MERGED_MANIFEST"

ROOT_COUNT=$(jq -r 'length' "$MERGED_MANIFEST")
if [ "$ROOT_COUNT" -eq 0 ]; then
  echo "ci-manifest-runner (${MODE}): N/A — no roots in the merged manifest (manifestState: unresolved, or a legacy flat manifest with no roots[] at all)"
  exit 0
fi

CHANGED=""
if [ -n "$BASE_SHA" ]; then
  # See run-static-evals.sh for the full rationale: a FAILED diff is not an empty diff. Swallowing the
  # exit code let a shallow clone or unreachable merge base skip every root and exit 0.
  _diff_rc=0
  CHANGED="$(git diff --name-only "${BASE_SHA}...HEAD" 2>/dev/null)" || _diff_rc=$?
  if [ "$_diff_rc" -ne 0 ]; then
    fail "PIPELINE DEFECT — 'git diff --name-only ${BASE_SHA}...HEAD' failed (exit ${_diff_rc}). Every root would be skipped as untouched and this job would exit 0 having run nothing. Most likely a shallow clone (needs fetch-depth: 0) or an unreachable merge base."
    exit 2
  fi
fi

overall_fail=0

run_root() {
  local root="$1" stack="$2" marker="$3" cmd="$4" no_tests_exit="${5:-}"
  local abs rc

  if [ -n "$BASE_SHA" ] && ! root_touched "$root"; then
    echo "ci-manifest-runner (${MODE}): N/A — root '${root}' (${stack}) — no changed files under this root for this PR (diff-scoped, Section 4.0g)"
    return 0
  fi

  abs="$(resolve_and_verify_root "$root" "$marker")" || {
    lib_manifest_defect "MANIFEST DEFECT while running '${MODE}' for root '${root}' — see above. Never a code defect; fix ${CONFIG}'s ci.roots or the owning work unit's fragment."
    overall_fail=1
    return 0
  }

  if [ -z "$cmd" ] || [ "$cmd" = "null" ]; then
    echo "ci-manifest-runner (${MODE}): N/A — root '${root}' (${stack}) has no ${MODE} command (stack genuinely has none, e.g. plain Python has no compile step)"
    return 0
  fi

  echo "ci-manifest-runner (${MODE}): running for root '${root}' (${stack}) at ${abs}"
  rc=0
  ( cd "$abs" && eval "$cmd" ) || rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "ci-manifest-runner (${MODE}): root '${root}' — OK"
    return 0
  fi

  # 🔴 "THE SUITE COLLECTED ZERO TESTS" IS N/A, NEVER A FAILURE — and never something to self-repair.
  #    pytest exits 5 and jest/vitest exit 1 when they find no tests at all. That is the NORMAL state of
  #    a greenfield repo before its first story, and of a brownfield repo that has no suite yet. Treating
  #    it as a code-class failure is what once sent CI self-repair off to invent DUMMY TESTS purely to
  #    turn the gate green — fabricating a pass (an SH-6 violation) and poisoning the regression baseline
  #    every later work unit is diffed against, because those fake tests then merge and become "existing".
  #    A root declares its own runner's no-tests code as ci.roots[].noTestsExitCode (Section 3), because
  #    the value is stack-specific and must never be guessed here.
  #
  #    🔴 THIS CANNOT HIDE A MISSING TEST: run-static-evals.*'s coverage_delta() independently enforces
  #    the real threshold on the CHANGED files and records ERROR ("no coverage data found for any changed
  #    file") when a changed file has no coverage. So a work unit that ships code without tests still
  #    fails — on the gate that can actually tell, with a diff to point at. What is suppressed here is
  #    only the vacuous case: nothing changed under this root, or the project genuinely has no suite yet.
  if [ -n "$no_tests_exit" ] && [ "$no_tests_exit" != "null" ] && [ "$rc" -eq "$no_tests_exit" ]; then
    echo "ci-manifest-runner (${MODE}): N/A — root '${root}' (${stack}) — the test runner collected ZERO tests (exit ${rc} = ci.roots[].noTestsExitCode). No suite exists here yet; the delta-scoped coverage gate still enforces the threshold on any changed file."
    return 0
  fi

  fail "root '${root}' (${stack}) — '${MODE}' command failed: ${cmd}"
  overall_fail=1
}

case "$MODE" in
  install)
    while IFS=$'\t' read -r root stack marker; do
      [ -z "$root" ] && continue
      # installCommands is an array — run each one in sequence, same cd/verify, first failure stops this root.
      cmds="$(jq -r --arg r "$root" '.[] | select(.root == $r) | .installCommands[]? // empty' "$MERGED_MANIFEST" | tr -d '\r')"
      if [ -z "$cmds" ]; then
        echo "ci-manifest-runner (install): N/A — root '${root}' (${stack}) has no installCommands"
        continue
      fi
      if [ -n "$BASE_SHA" ] && ! root_touched "$root"; then
        echo "ci-manifest-runner (install): N/A — root '${root}' (${stack}) — no changed files under this root for this PR (diff-scoped)"
        continue
      fi
      abs="$(resolve_and_verify_root "$root" "$marker")" || {
        lib_manifest_defect "MANIFEST DEFECT while running 'install' for root '${root}' — see above. Never a code defect; fix ${CONFIG}'s ci.roots or the owning work unit's fragment."
        overall_fail=1; continue
      }
      while IFS= read -r one_cmd; do
        [ -z "$one_cmd" ] && continue
        echo "ci-manifest-runner (install): root '${root}' (${stack}) at ${abs}: ${one_cmd}"
        if ! ( cd "$abs" && eval "$one_cmd" ); then
          fail "root '${root}' (${stack}) — install command failed: ${one_cmd}"
          overall_fail=1
          break
        fi
      done <<< "$cmds"
    done < <(jq -r '.[] | [.root, (.stack // "unknown"), (.markerFile // "")] | @tsv' "$MERGED_MANIFEST" | tr -d '\r')

    # 🔴 Eval tools (semgrep, gitleaks, pip-audit, …) — deduped by NAME across every root's
    #    toolInstallCommands, run from the repo root (these are global/CLI installs, not root-scoped
    #    project dependencies, so no cd here). This is what removes the separately-generated "Install
    #    eval tools" YAML block: a work unit that brings the repo's first stack of a given kind brings
    #    that stack's eval tools with it, on its own PR, with nothing here to hand-edit (#7a). A tool
    #    named in `tools` with no matching `toolInstallCommands` entry anywhere in the merged manifest is
    #    a Manifest defect (V30-class — untraceable value), not silently skipped.
    while IFS=$'\t' read -r tool cmd; do
      [ -z "$tool" ] && continue
      if [ -z "$cmd" ] || [ "$cmd" = "null" ]; then
        lib_manifest_defect "MANIFEST DEFECT — tool '${tool}' is listed in ci.roots[].tools but no root's toolInstallCommands names it. Fix the owning work unit's fragment, not this script."
        overall_fail=1
        continue
      fi
      echo "ci-manifest-runner (install): eval tool '${tool}': ${cmd}"
      if ! eval "$cmd"; then
        fail "eval tool '${tool}' install failed: ${cmd}"
        overall_fail=1
      fi
    done < <(jq -r '
      ([.[].tools[]?] | unique) as $names
      | ($names[] as $n | [$n, ([.[] | .toolInstallCommands[$n]? // empty] | first // "")]) | @tsv
    ' "$MERGED_MANIFEST" | tr -d '\r')
    ;;
  build)
    while IFS=$'\t' read -r root stack marker cmd; do
      [ -z "$root" ] && continue
      run_root "$root" "$stack" "$marker" "$cmd"
    done < <(jq -r '.[] | [.root, (.stack // "unknown"), (.markerFile // ""), (.buildCommand // "")] | @tsv' "$MERGED_MANIFEST" | tr -d '\r')
    ;;
  toolchain)
    # 🔴 The escape hatch for a stack the template has no actions/setup-* block for. Each root's
    #    toolchainSetup commands install and PIN its own toolchain, read from that repo's own pin file
    #    (rust-toolchain.toml, .ruby-version, .tool-versions, composer.json config.platform) - never
    #    invented here. A root with a known stack has no toolchainSetup and is simply skipped: the
    #    permanently-present setup blocks already cover it.
    while IFS=$'\t' read -r root stack marker; do
      [ -z "$root" ] && continue
      cmds="$(jq -r --arg r "$root" '.[] | select(.root == $r) | .toolchainSetup[]? // empty' "$MERGED_MANIFEST" | tr -d '\r')"
      if [ -z "$cmds" ]; then
        echo "ci-manifest-runner (toolchain): N/A — root '${root}' (${stack}) declares no toolchainSetup (its stack has a built-in setup block, or it needs none)"
        continue
      fi
      abs="$(resolve_and_verify_root "$root" "$marker")" || {
        lib_manifest_defect "MANIFEST DEFECT while running 'toolchain' for root '${root}' — see above."
        overall_fail=1; continue
      }
      while IFS= read -r one_cmd; do
        [ -z "$one_cmd" ] && continue
        echo "ci-manifest-runner (toolchain): root '${root}' (${stack}) at ${abs}: ${one_cmd}"
        if ! ( cd "$abs" && eval "$one_cmd" ); then
          fail "root '${root}' (${stack}) — toolchain command failed: ${one_cmd}"
          overall_fail=1
          break
        fi
      done <<< "$cmds"
    done < <(jq -r '.[] | [.root, (.stack // "unknown"), (.markerFile // "")] | @tsv' "$MERGED_MANIFEST" | tr -d '\r')
    ;;
  coverage)
    while IFS=$'\t' read -r root stack marker cmd no_tests_exit; do
      [ -z "$root" ] && continue
      run_root "$root" "$stack" "$marker" "$cmd" "$no_tests_exit"
    done < <(jq -r '.[] | [.root, (.stack // "unknown"), (.markerFile // ""), (.coverageCommand // ""), (.noTestsExitCode // "" | tostring)] | @tsv' "$MERGED_MANIFEST" | tr -d '\r')
    ;;
esac

exit "$overall_fail"
