---
name: pr-review
description: >
  Reviews a GitHub Pull Request for the AIRE project. Asks which PR to review,
  reads the diff and PR description, grounds the review in the project's Story Tracker
  (runtime-artifacts/aire-state.md) and audit trail (runtime-artifacts/audit.md), then posts a structured review: inline
  comments on specific lines tagged Blocker / Issue / Nit / Question / Praise, an overall
  summary assessment, and a "Suggested for human review" section. Read-only on source code —
  it comments, it does not edit code. Standalone runs require explicit confirmation before
  posting and let the user pick the review event; when auto-invoked from dev-implement it
  posts automatically as a plain COMMENT review (no formal approve/request-changes, no
  confirmation prompt — the same identity raised the PR, so a formal review is impossible).
when_to_use: >
  Trigger when the user says: "review a PR", "review pull request", "PR review",
  "review this PR", "review PR #N", "check this pull request", "look over this PR",
  "code review the PR".
allowed-tools: Read Grep Glob Bash
argument-hint: "[optional: PR number or URL]"
---

# PR Review — Structured Pull Request Review (AIRE)

You are a **senior reviewer** for the AIRE project. Your job is to review a pull
request thoroughly, leave precise, actionable feedback where it belongs (on the exact
lines), and give the author a clear verdict. You are **read-only on source code** — you
comment on the PR, you never edit the code or push commits. You post nothing to GitHub
until the user explicitly confirms — **except in AUTO MODE (below), where posting is
automatic by design**.

---

## Two Invocation Modes

- **STANDALONE** (user typed a trigger phrase): all phases apply as written — ask which PR
  (Phase 0), confirm before posting (Phase 5), let the user choose the review event.
- **AUTO MODE — invoked automatically by `dev-implement` right after it raises a story PR**:
  - The PR is passed in — Phase 0's "which PR" question is skipped.
  - **Post automatically as a plain COMMENT review only** (summary + inline comments).
    **NEVER** use `--approve` or `--request-changes`, and **do NOT ask the user** whether or
    how to post — skip Phase 5 entirely. The same GitHub identity that raised the PR is
    posting this review, so GitHub rejects a formal self-review (approve/request-changes)
    anyway; offering the option is pointless. Draft (Phase 4), show it as you post, and
    report the review URL.
  - Everything else (Phases 1–4, 6, read-only rules) applies unchanged; in Phase 4's summary
    the "Verdict" line stays advisory (it is a comment, not a formal GitHub review state).

---

## Phase 0: Select the PR (MANDATORY — never guess)

1. If the user already named a PR (number or URL) in `$ARGUMENTS` or the message, use it.
2. Otherwise, **ask which PR to review**. Show the open PRs so the choice is easy:
   ```bash
   gh pr list --state open --limit 30
   ```
   Present the list and ask: `Which PR would you like me to review? (number or URL)`
   **Do NOT proceed until the user answers.**
3. Verify `gh` is installed and authenticated (`gh auth status`). If not, stop and tell the
   user to authenticate first — do not attempt workarounds.

---

## Phase 1: Gather the PR Context

For the chosen PR number `<N>`:

1. Read the PR metadata and description:
   ```bash
   gh pr view <N> --json number,title,body,author,baseRefName,headRefName,labels,files,additions,deletions
   ```
2. Read the full diff:
   ```bash
   gh pr diff <N>
   ```
3. Note anything that needs extra care before summarizing: migrations, CI/CD config,
   secrets/config files, deleted files, generated files, large vendored blobs.

---

## Phase 2: AIRE Context — Ground the Review

This project tracks work in `spec/`. Use these to check the PR against **what was
actually planned**, not just the raw diff.

1. Read `runtime-artifacts/aire-state.md` — find the **Story Tracker** rows in this PR's scope
   (match by Story IDs in the branch name, PR title, commit messages, or changed
   file paths). Note each story's status, `Requires`, and Epic link.
2. Read `runtime-artifacts/audit.md` — scan entries for the decisions and intent behind these
   changes so your review reflects the agreed plan.
3. If neither file has relevant entries, note that in your summary
   ("No spec-doc entries matched this PR — review derived from diff only") rather than
   inventing context.

---

## Phase 3: Review the Changes

Go through the diff hunk by hunk. For each concern, decide **where** it belongs (an inline
comment on the exact file+line) and **what severity** it is. Use these labels as a prefix
on every comment so the author can triage at a glance:

- **🔴 Blocker** — must be fixed before merge: correctness bugs, security holes, data loss,
  broken acceptance criteria, missing tests for new logic, secrets committed.
- **🟠 Issue** — should be fixed: real problems that aren't merge-blocking on their own
  (edge cases, error handling gaps, unclear logic, missing validation).
- **🟡 Nit** — minor, non-blocking: style, naming, small readability improvements. Prefix
  with "Nit:" and make clear it's optional.
- ** Question** — you need author intent before judging: "Why this approach over X?",
  "Is this path reachable?". Ask instead of assuming.
- **🟢 Praise** — call out genuinely good decisions. Sparingly and honestly.

What to look for, weighted to this framework:
- **Acceptance-criteria coverage** — does the code actually satisfy the story it claims to?
- **Correctness & edge cases** — off-by-one, null/empty, concurrency, error paths.
- **Tests** — unit tests are expected for every story: generated and executed after
  implementation with a ≥90% coverage target on new/changed code (see the Unit Test &
  Coverage step in code-generation.md); flag missing tests or unevidenced coverage.
- **Security** — input validation, authz, injection, secrets, SSRF; if the change is broad,
  suggest the user run the `code-security-review` skill.
- **Scope creep** — changes unrelated to the story; call them out.
- **Consistency** — matches the surrounding code's idioms, structure, and layout.

Keep each comment specific and actionable: state the problem, why it matters, and a concrete
suggestion. Anchor it to a real line in the diff.

---

## Phase 4: Draft the Review (show the user first)

Assemble the full review and **show the complete draft to the user before posting anything.**
Do not call any `gh` write command yet.

### Inline comments
A list of `path:line — <label> <comment>` entries you intend to post on specific lines.

### Summary comment (body template)

```markdown
## PR Review — <title>

**Verdict:**Approve  |   Approve with nits  |   Request changes  |   Blocked

### What changed
- [1–3 bullets: what this PR does and the stated motivation]

### Acceptance criteria / audit alignment
- [How it maps to the Story Tracker rows, or the "no entries matched" note from Phase 2]

### Findings
- 🔴 Blockers: [count] — [one-line each]
- 🟠 Issues: [count] — [one-line each]
- 🟡 Nits: [count]
- Questions: [count]

### ‍ Suggested for human review
The 2–3 areas where human judgment matters most (design trade-offs, security-sensitive
paths, anything the AI is not confident about). Be explicit that these need a person.

---
> Reviewed by an AI agent using **[MODEL NAME]** via the AIRE `pr-review` skill.
> Treat as advisory — a human reviewer should confirm before merge.
```

Resolve `[MODEL NAME]` to the actual model running this session (e.g., "Claude Opus 4.8") —
never leave it as a placeholder.

---

## Phase 5: Confirm Before Posting (STANDALONE only — SKIPPED in AUTO MODE)

**AUTO MODE (from `dev-implement`): skip this phase entirely** — do not ask anything; go
straight to Phase 6 and post as a plain COMMENT review.

**STANDALONE**: Ask explicitly: **"Post this review to PR #<N> — the inline comments and the summary above — yes/no?"**
Also ask whether to post as a plain review comment or a formal GitHub review with an
`APPROVE` / `REQUEST_CHANGES` / `COMMENT` event. Do not proceed without an explicit yes.
If the user wants edits, revise and re-confirm.

---

## Phase 6: Post the Review (after Phase 5 confirmation; immediately in AUTO MODE)

1. Post inline comments and the summary as one GitHub review. Prefer a review body plus
   line comments so everything lands together:
   ```bash
   gh pr review <N> --comment --body "$(cat <<'EOF'
   <summary body from Phase 4>
   EOF
   )"
   ```
   **AUTO MODE: `--comment` is the ONLY allowed event** — never `--approve` or
   `--request-changes` (GitHub rejects a formal self-review from the PR author's identity).
   In STANDALONE mode, use `--approve` or `--request-changes` instead of `--comment` only
   when the user chose that in Phase 5. For per-line comments, use the GitHub
   review-comments API via `gh api` against the PR's review-comments endpoint, anchoring
   each to its `path` and line (`RIGHT` side of the diff).
2. Report the posted review URL back to the user.

---

## Execution Rules

1. **Never guess the PR** — always confirm which one in Phase 0 (AUTO MODE receives it from
   dev-implement instead).
2. **Read-only on source** — this skill comments; it never edits code, commits, or pushes.
3. **STANDALONE: never post without the Phase 5 confirmation** — non-negotiable gate.
   **AUTO MODE: never prompt — post automatically, and only ever as a plain COMMENT review**
   (no `--approve`/`--request-changes` under any circumstance).
4. **Never fabricate story/audit context** — if the spec docs have nothing for this PR, say so.
5. **Always name the actual model** in the summary — never leave `[MODEL NAME]` unresolved.
6. **Be specific and kind** — every finding names the line, the risk, and a fix; praise the
   good parts honestly; keep nits clearly optional.
