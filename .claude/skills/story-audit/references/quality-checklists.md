# Quality Checklists

Two checklists — one for Epics, one for Stories. Each item is marked **Required** or **Recommended**.
Required items that are MISSING make the verdict "Incomplete". Recommended items that are MISSING
only contribute to "Needs Work".

---

## Epic Checklist

Derived from the AIRE intent-intake and intent-refinement quality bars.

### Required

1. **Outcome statement** — one business sentence, no solution language.
   - PASS: Clear business outcome in user/business terms.
   - WEAK: Present but contains solution language ("build a microservice") or is vague ("make it better").
   - MISSING: No outcome or only a title with no elaboration.

2. **KPI / business outcome** — at least one named metric this is meant to move.
   - PASS: Specific metric(s) named (revenue, conversion rate, time-to-X, etc.).
   - WEAK: Vague ("improve performance") without naming the metric.
   - MISSING: No business metric mentioned.

3. **Success signal** — directional indicator of what "working" looks like.
   - PASS: Clear directional signal ("organizers create events in minutes, not hours").
   - WEAK: Too vague to be useful ("things are better").
   - MISSING: No success signal.

4. **Scope — out-of-scope section** — at least one explicit exclusion.
   - PASS: One or more explicit out-of-scope items that prevent scope creep.
   - WEAK: Out-of-scope exists but is trivially obvious or doesn't address likely assumptions.
   - MISSING: No out-of-scope section at all.

5. **Scope — in-scope section** — what's included.
   - PASS: Clear list of what the Epic covers.
   - WEAK: Implied but not explicitly listed.
   - MISSING: No in-scope definition.

### Recommended

6. **Hard constraints** — tech stack, integrations, scale, regulatory, or "none known".
   - PASS: Constraints listed or explicitly "none known".
   - WEAK: Partial (e.g., mentions AWS but not scale requirements).
   - MISSING: No mention of constraints.

7. **Confidence and open unknowns** — honest assessment of certainty.
   - PASS: Confidence level stated, unknowns declared.
   - WEAK: Confidence stated but no unknowns listed (or vice versa).
   - MISSING: No confidence or unknowns section.

8. **Context link** — reference to source material (PRD, research, Confluence, etc.).
   - PASS: Link or reference to source material present.
   - WEAK: Vague reference ("based on team discussion") with no link.
   - MISSING: No context link.

9. **Acceptance criteria (measurable)** — testable criteria with thresholds.
   - PASS: Measurable criteria with specific thresholds and verification methods.
   - WEAK: Criteria exist but are not measurable ("should be fast").
   - MISSING: No acceptance criteria. (Note: acceptable for baseline Epics pre-refinement.)

10. **Child issues linked** — Epic has Stories or Tasks linked beneath it.
    - PASS: One or more child issues linked.
    - WEAK: Children exist but aren't linked in the tracker.
    - MISSING: No children. (Note: acceptable for newly created Epics.)

---

## Story Checklist

Derived from the AIRE user-stories standards and INVEST criteria.

### Required

1. **User story narrative** — describes the feature from the user's perspective.
   - PASS: Clear narrative, ideally in "As a [persona], I want [action], so that [benefit]" format, or equivalent user-centered language.
   - WEAK: Describes the feature but is developer-centric ("implement an API endpoint") rather than user-centric.
   - MISSING: No narrative — just a title or a bare task description.

2. **Acceptance criteria** — testable conditions that define "done".
   - PASS: Clear, testable criteria. Given/When/Then (Gherkin) format preferred but not required. Each criterion is specific and verifiable.
   - WEAK: Criteria exist but are vague ("should work correctly"), untestable, or incomplete.
   - MISSING: No acceptance criteria at all.

3. **Persona reference** — identifies who this story is for.
   - PASS: Names a specific persona or user role (e.g., "Field Responder (Ravi)", "Organizer").
   - WEAK: Generic ("the user") without identifying the specific role.
   - MISSING: No persona or user role mentioned.

4. **Clear scope** — what this story does and doesn't cover.
   - PASS: Boundaries are clear from the narrative and acceptance criteria — you know exactly what's in and what's not.
   - WEAK: Scope is mostly clear but has ambiguous edges.
   - MISSING: Scope is unclear — could be interpreted multiple ways.

5. **Testability (INVEST: T)** — can you write a test for every acceptance criterion?
   - PASS: Every criterion maps to a concrete test scenario.
   - WEAK: Most criteria are testable but 1+ are subjective ("should feel fast").
   - MISSING: Criteria are too vague to derive tests from.

### Recommended

6. **Independence (INVEST: I)** — can this story be implemented without waiting on other in-progress stories?
   - PASS: Story can be built independently (dependencies are on completed work only).
   - WEAK: Has soft dependencies that could cause merge conflicts or coordination needs.
   - MISSING: Tightly coupled to another in-progress story.

7. **Size / granularity (INVEST: S)** — small enough for one developer in one iteration.
   - PASS: Appropriately scoped — implementable by one developer.
   - WEAK: On the large side but still manageable.
   - MISSING: Too large — should be split into multiple stories.

8. **Technical notes** — implementation hints, relevant architecture, data model notes.
   - PASS: Useful technical context included (e.g., "Use SQLite WASM for local storage").
   - WEAK: Minimal technical context.
   - MISSING: No technical notes. (Acceptable for non-technical stories.)

9. **Value statement (INVEST: V)** — clear why this matters to the user or business.
   - PASS: The "so that" clause or equivalent clearly articulates value.
   - WEAK: Value is implied but not stated.
   - MISSING: No value articulation — reads like a task, not a story.

10. **Error / edge cases in acceptance criteria** — what happens when things go wrong.
    - PASS: At least one criterion covers error handling, validation failure, or edge case behavior.
    - WEAK: Only happy-path criteria.
    - MISSING: No error/edge case coverage at all.
