#!/usr/bin/env bash
# read-manifest.sh — builds the merged manifest and emits, in KEY=VALUE lines (one per line, suitable
# for appending straight to $GITHUB_OUTPUT), whether each known stack is present ANYWHERE in the merged
# ci.roots[] and which runtimeVersion to pin for it.
#
# 🔴 This is what lets the generated pipeline keep ALL FIVE `actions/setup-*` blocks permanently present,
#    each `if:`-gated on one of these booleans, instead of generating a different subset of setup steps
#    per repo (common/ci-pipeline-generation.md Section 4.0d.1/#7a). A repo becomes "node-enabled" the
#    moment ANY root — including one a later work unit's fragment adds — declares stack: "node"; nothing
#    here is re-detected from the filesystem, it is read straight from what a work unit already verified.
#
# Contract: no args. Reads tests/.evals/config.json + tests/.evals/ci-manifest.d/*.json. Prints:
#   has_node=true|false
#   node_version=<runtimeVersion of the first root declaring stack "node", or empty>
#   ... one pair per stack in STACKS below ...
#   unknown_stacks=<roots declaring a stack with no setup block AND no toolchainSetup, or empty>
# Exits non-zero only on a real setup failure (missing jq, missing config) — never on "no roots yet".
set -uo pipefail

CONFIG="tests/.evals/config.json"
MANIFEST_DIR="tests/.evals/ci-manifest.d"
MERGED_MANIFEST="tests/.evals/_run/merged-manifest.json"
STACKS="node python java go dotnet"

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-manifest.sh
source "${LIB_DIR}/lib-manifest.sh"

if [ ! -f "$CONFIG" ]; then
  echo "read-manifest: ERROR: ${CONFIG} missing" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "read-manifest: ERROR: jq not installed" >&2
  exit 2
fi

build_merged_manifest "$CONFIG" "$MANIFEST_DIR" "$MERGED_MANIFEST"

# 🔴 A STACK THE PIPELINE CANNOT PROVISION MUST BE LOUD, NEVER SILENT.
#    STACKS below is a CLOSED list, because the template carries exactly five actions/setup-* blocks.
#    A root declaring anything else - rust, ruby, php, scala, elixir, swift, cpp - used to produce NO
#    output line, NO warning, and exit 0: zero toolchain steps ran, the runtimeVersion the schema
#    promises is "read back to pin the setup step" was consumed by nothing, and the build then ran
#    against whatever version the runner image happened to ship. Meanwhile the schema itself lists
#    Cargo.toml, Gemfile and composer.json as valid markerFile values, so the framework actively
#    invites stacks it cannot provision.
#    Such a root is now a MANIFEST defect unless it carries its own toolchainSetup commands - which
#    routes it to Section 6.4's Manifest triage class (report and stop, never a code repair, no retry
#    consumed) instead of letting self-repair burn its budget editing source to fix a toolchain pin.
UNKNOWN_STACKS=$(jq -r --arg known "$STACKS" '
  ($known | split(" ")) as $k
  | [ .[] | select((.stack // "unknown") as $s | ($k | index($s)) == null)
          | select((.toolchainSetup // []) | length == 0)
          | .root + " (stack: " + (.stack // "unknown") + ")" ]
  | join(", ")' "$MERGED_MANIFEST" 2>/dev/null || echo "")
if [ -n "$UNKNOWN_STACKS" ]; then
  lib_manifest_defect "MANIFEST DEFECT - these ci.roots[] declare a stack this pipeline has no actions/setup-* block for, and no toolchainSetup commands to install it themselves: ${UNKNOWN_STACKS}. Nothing would install or pin their toolchain, so the build would silently run against whatever the runner image ships. Add ci.roots[].toolchainSetup (pinned from the repo's own rust-toolchain.toml / .ruby-version / .tool-versions / composer.json platform config), or record manifestState 'unresolved' with the reason."
  echo "unknown_stacks=${UNKNOWN_STACKS}"
  # 🔴 EXITING 0 HERE MADE THE WHOLE CHECK A NO-OP. The marker file is only ever read by
  #    auto-fix-agent, which only runs when the job has ALREADY failed - and nothing else would fail,
  #    because an unprovisionable stack installs nothing and therefore breaks nothing until a build
  #    command runs against the wrong runtime. A Rust repo went fully green with zero toolchain
  #    provisioning. A stack the pipeline cannot provision is a real setup failure, which this
  #    script's own contract says is exactly when it exits non-zero.
  echo "read-manifest: ERROR: the roots above declare a stack with no actions/setup-* block and no ci.roots[].toolchainSetup. Nothing would install or pin their toolchain. Add toolchainSetup (pinned from the repo's own pin file), or record manifestState 'unresolved' with the reason." >&2
  exit 2
else
  echo "unknown_stacks="
fi

for stack in $STACKS; do
  present=$(jq -r --arg s "$stack" '[.[] | select(.stack == $s)] | length > 0' "$MERGED_MANIFEST")
  echo "has_${stack}=${present}"
  if [ "$present" = "true" ]; then
    # 🔴 First root declaring this stack wins the version pin. Two roots sharing a stack with a
    #    genuinely different runtimeVersion is a #14.1-class conflict — surfaced at RECONCILIATION time
    #    (the workflow step writing the second fragment checks for this before writing), never silently
    #    resolved here by picking one arbitrarily and hiding the disagreement.
    version=$(jq -r --arg s "$stack" '[.[] | select(.stack == $s) | .runtimeVersion // empty] | first // empty' "$MERGED_MANIFEST")
    echo "${stack}_version=${version}"
  else
    echo "${stack}_version="
  fi
done
