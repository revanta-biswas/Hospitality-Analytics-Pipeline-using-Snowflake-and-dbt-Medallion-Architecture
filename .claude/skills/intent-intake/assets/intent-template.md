---
intent_id:        # stable, unique — never reused
title:            # short outcome name
status:           idea      # idea → intake → epic → decomposing → ready → building → done
fill_level:       baseline  # baseline (from intake) | full (from Refinement)
kpi:              # the business outcome / metric this moves
confidence:       # low | med | high — how sure are we this is worth doing
context_link:     # URL/path to the research, prototype, deck, or notes this came from
tracker_id:       # the Epic — filled once it's real in the configured tracker (JIRA/ADO/GITHUB), or LOCAL
gate:             open      # open | intake-passed 
owner:            # the PO accountable
created:
updated:
---

# Intent: [title]

> One document, two fill levels. **Intake** fills the BASELINE fields — just enough thought to be
> real in the tracker. **Refinement** fills the FULL fields — the depth you do with engineers before
> Stories exist. The configured tracker (or, for Local, this document itself) is the system of record for anything real; this doc is the workspace and the
> traceability link. On any drift, **the tracker wins** (or this document, for Local).

---

## 1. Outcome — the *why*  ·  [BASELINE]

*One sentence, business terms, no solution language.*

[ ... ]

## 2. Business outcome & KPI  ·  [BASELINE]

*The metric this is meant to move, and roughly by how much / by when if known.*

- **KPI:** [ ... ]
- **Target (if known):** [ ... ]

## 3. Success signal → success criteria  ·  [BASELINE → FULL]

*Baseline: a rough, directional signal ("faster entry", "fewer failed checkouts"). Full: sharpen
each into a measurable criterion with a verification method — this is refinement's job, not
intake's.*

**Baseline signal:** [ directional ]

**Testable criteria (full):**
| # | Criterion (measurable) | How it's verified |
|---|------------------------|-------------------|
| SC-1 | [ ... ] | [ ... ] |

## 4. Scope  ·  [BASELINE requires ≥1 out; FULL completes both]

**Explicitly out of scope** *(intake requires at least one — an empty out-of-scope invites scope creep)*
- [ ... ]

**In scope** *(full)*
- [ ... ]

## 5. Constraints  ·  [BASELINE: known-or-"none"; FULL: complete]

*Baseline: hard constraints you already know, or an honest "none known." Full: the complete binding
technical environment.*

- [ ... or "none known" ]

## 6. Open questions & confidence  ·  [BASELINE]

*Honest unknowns — a declared unknown is fine; a hidden guess is not.*

| # | Question | Owner | Resolution |
|---|----------|-------|------------|
| OQ-1 | [ ... ] | [ ... ] | |

---
*The sections below are filled during **Refinement** (fill_level: full), not intake.*

## 7. Domain & system context — *DDD*  ·  [FULL]

- **Bounded contexts:** [ ... ]
- **Key entities:** [ ... ]
- **Core invariants:** [ ... ]

## 8. Users & personas  ·  [FULL]

- [ ... ]

## 9. Compliance & risk  ·  [FULL]

- **Compliance:** [ ... ]
- **Risk register:** [ ... ]

## 10. NFR floor  ·  [FULL]

- **Security / Availability / Latency / Observability:** [ ... ]

## 11. Traceability

- **Tracker anchor (Epic):** [ tracker_id ]

---

## Intake gate — *baseline is real enough for the tracker*

- [ ] Outcome is one business sentence, no solution
- [ ] KPI named
- [ ] A rough success signal exists (need not be testable yet)
- [ ] At least one explicit out-of-scope
- [ ] Known constraints listed, or an honest "none known"
- [ ] Confidence set and open unknowns declared
- [ ] Context link present

