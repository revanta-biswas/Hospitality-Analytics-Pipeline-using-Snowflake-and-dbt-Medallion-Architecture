---
intent_id:        # stable, unique — never reused
title:            # short outcome name
status:           idea      # idea → intake → epic → refining → refined → building → done
fill_level:       baseline  # baseline (thin/as-fetched) | full (after refinement)
kpi:              # the business outcome / metric this moves
confidence:       # low | med | high — how sure are we this is worth doing
context_link:     # URL/path to the research, prototype, deck, or notes this came from
tracker_id:       # the Epic's ID in the configured tracker (JIRA/ADO/GITHUB), or LOCAL
owner:            # the PO accountable
created:
updated:
---

# Intent: [title]

> One document, two fill levels. **Baseline** captures what's already in the Epic — just enough
> to orient. **Full** adds the depth driven by refinement: measurable criteria, domain model,
> constraints, NFRs, risks. The configured tracker is the system of record (or this document itself, for Local); this doc is the workspace artifact.
> On any drift, **the tracker wins** (or this document, for Local).

---

## 1. Outcome — the *why*

*One sentence, business terms, no solution language.*

[ ... ]

## 2. Business outcome & KPI

*The metric this is meant to move, and roughly by how much / by when if known.*

- **KPI:** [ ... ]
- **Target (if known):** [ ... ]

## 3. Success criteria

*Sharpen the rough success signal into measurable criteria with thresholds and verification methods.*

| # | Criterion (measurable) | Threshold | How it's verified |
|---|------------------------|-----------|-------------------|
| SC-1 | [ ... ] | [ ... ] | [ ... ] |

## 4. Scope

**Explicitly out of scope** *(required — an empty out-of-scope invites scope creep)*
- [ ... ]

**In scope**
- [ ... ]

## 5. Constraints

*Hard constraints that are truly fixed. Unknown ≠ absent — unknowns go to Open Questions.*

- [ ... or "none known" ]

## 6. Open questions

*Honest unknowns — a declared unknown is fine; a hidden guess is not.*

| # | Question | Owner | Resolution |
|---|----------|-------|------------|
| OQ-1 | [ ... ] | [ ... ] | |

## 7. Domain & system context

- **Bounded contexts:** [ ... ]
- **Key entities:** [ ... ]
- **Core invariants:** [ ... ]

## 8. Users & personas

- [ ... ]

## 9. Compliance & risk

- **Compliance:** [ ... ]
- **Risk register:** [ ... ]

## 10. NFR floor

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

