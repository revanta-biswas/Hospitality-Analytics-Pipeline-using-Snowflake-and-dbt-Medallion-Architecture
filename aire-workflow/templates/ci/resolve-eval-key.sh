#!/usr/bin/env bash
# Resolve the work-unit EVAL_KEY from a branch ref. 🔴 A branch ref contains a slash; the evidence key
# must NOT — `eval-evidence/${key}` becomes a nested dir otherwise, orphaning every downstream reader.
#
# The prefix set is read from `tests/.evals/config.json` -> ci.integrationBranchPrefixes (the SINGLE SOURCE
# OF TRUTH), so adding a prefix there — e.g. `ci` — is why `ci/**` branches no longer crash here.
#
# Contract: prints `key=<slug>` to $GITHUB_OUTPUT (or stdout when run locally). Fails LOUDLY — never
# falls through to `unknown` — when the ref cannot be reduced to a slash-free key.
set -euo pipefail

head_ref="${1:-}"
ref_name="${2:-}"
ref="${head_ref:-$ref_name}"

if [ -z "$ref" ]; then
  echo "EVAL_KEY unresolved: no branch ref supplied" >&2
  exit 1
fi

config="tests/.evals/config.json"
prefixes="epic bug enhancement ci story ve"
if [ -f "$config" ] && command -v jq >/dev/null 2>&1; then
  from_manifest="$(jq -r '.ci.integrationBranchPrefixes // [] | join(" ")' "$config" 2>/dev/null || true)"
  [ -n "$from_manifest" ] && prefixes="$from_manifest"
fi

key=""
for p in $prefixes; do
  case "$ref" in
    "$p"/*)
      rest="${ref#"$p"/}"          # e.g. "2-frontend-cta" or "PROJ-102-title"
      # The identifier is the ticket/story ref: a leading non-numeric token followed by a numeric
      # token (PROJ-102), or a single numeric token alone (2). Taking only the token before the
      # FIRST hyphen collides every ticket in the same tracker project onto one key — PROJ-101,
      # PROJ-102 and PROJ-999 all became "bug-PROJ" — so this looks one token further whenever the
      # first token isn't already numeric.
      IFS='-' read -r first second _rest_unused <<< "$rest"
      if [[ "$first" =~ ^[0-9]+$ ]]; then
        ident="$first"                    # story/2-frontend-... -> story-2
      elif [[ "${second:-}" =~ ^[0-9]+$ ]]; then
        ident="${first}-${second}"        # bug/PROJ-102-title  -> bug-PROJ-102
      else
        ident="$first"                    # ci/agentic-eval-... -> ci-agentic
      fi
      key="${p}-${ident}"
      break
      ;;
  esac
done

# Refs that match no known prefix (e.g. the base branch on a push): slugify the whole ref safely.
if [ -z "$key" ]; then
  key="$(printf '%s' "$ref" | tr '/' '-' | tr -cs 'A-Za-z0-9._-' '-')"
fi

case "$key" in
  */* | "")
    echo "EVAL_KEY unresolved from '$ref' -> '$key' (still contains '/' or empty)" >&2
    exit 1
    ;;
esac

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "key=$key" >> "$GITHUB_OUTPUT"
fi
echo "$key"
