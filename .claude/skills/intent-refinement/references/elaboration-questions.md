# Elaboration question bank

Use these in **Step 3** to drive out the intent's full content. Work in batches, one section at a
time, starting from the top (highest priority). Prefer multiple-choice options with an open
**"Other"**, and stop after each batch to let the user answer.

Stop elaborating once the intent is verifiable: measurable success criteria with thresholds and
verification methods, clear scope, known constraints, modelled domain, identified risks. Ask only
what's needed to reach that bar. Genuine unknowns become Open Questions.

---

## Priority 1 — load-bearing fields (never skip)

These are what verifiability turns on.

### Outcome
- In one sentence, what business result should exist that doesn't today?
- Who is worse off if this is never built, and how?
- *Watch for solution language* — "build a scanner" is a solution; "admit attendees fast without duplicates" is an outcome. Reflect it back stripped of solution language.

### Success criteria (measurable)
- How will we know this worked — what would you measure?
- For each measure, what's the threshold? (a number, a rate, a time)
- How would that be verified — test, metric, audit log, user acceptance?
- *If the answer isn't measurable, keep pushing.* Offer candidates: "Would 'median X under N seconds' capture it, or is it more about error rate?"

### Scope — especially out-of-scope
- What's clearly included?
- What might someone assume is included that is **not**? (populate this — empty out-of-scope is a failure)
- Where's the nearest thing you're deliberately *not* touching, and why?

### Binding constraints
Offer as a checklist, capture only the ones that are truly fixed:
- Stack / platform mandated? [ yes → which / no / unknown ]
- Systems it must integrate with? [ list / none / unknown ]
- Data residency or handling rules? [ ... ]
- Hard performance floors? [ ... ]
- Regulatory or policy limits? [ ... ]
- *Unknown ≠ none.* Unknowns are Open Questions, not assumed-absent.

---

## Priority 2 — domain and user context

### Domain & system context (DDD)
- What are the distinct areas of the business this touches? (candidate bounded contexts)
- What are the key things/nouns in this domain, and what do they mean?
- What rules must always hold true? (invariants — e.g. "a ticket admits exactly once")

### Users & personas
- Who uses or is affected by this? Name each role.
- What does each need from it?

---

## Priority 3 — governance and NFRs (essential in regulated verticals)

### Compliance & risk
- Any regulatory regime in play? (e.g. PCI-DSS, HIPAA, regional privacy)
- What's the worst plausible failure, and how likely?
- Capture top risks with likelihood/impact and a mitigation.

### NFR floor
- Minimum security posture?
- Availability target?
- Latency / throughput floor?
- What must be observable (logged/traced)?

---

## Closing the batch

Before drafting the refined intent, sanity-check verifiability out loud:

*"Could we prove, at the end of building, that we met this intent?"*

If yes — the success criteria have clear thresholds and verification methods — proceed to draft.
If no — run one more targeted batch on the weak spot only, then draft.
