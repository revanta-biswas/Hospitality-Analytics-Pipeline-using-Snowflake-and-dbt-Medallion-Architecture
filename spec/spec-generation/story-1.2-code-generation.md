# Code Generation Plan — Story 1.2: Externalize dbt connection secrets via environment variables

**Covers**: REQ-F-02, REQ-NF-01, REQ-NF-02
**Tracker ID**: [GitHub #2](https://github.com/revanta-biswas/Hospitality-Analytics-Pipeline-using-Snowflake-and-dbt-Medallion-Architecture/issues/2)

## Steps

- [ ] 1. Write `spec/behavior/story-1.2.feature` — one Gherkin scenario per AC, `@AC-n` tagged (REQ-F-02, all ACs)
- [ ] 2. Edit `src/dbt_code/profiles.yml`: replace `account`, `user`, `password`, `role`, `warehouse` literal placeholder values with `{{ env_var('DBT_...') }}` references (REQ-F-02 AC-1, AC-2)
- [ ] 3. Document the required environment variable names in `src/dbt_code/README.md` (REQ-F-02 AC-3)
- [ ] 4. Mechanically verify: repo-wide grep for a literal password/account/user value in `profiles.yml` returns zero matches (REQ-NF-01 AC-4)
- [ ] 5. Statically validate `profiles.yml` remains valid YAML via `python3 -c "import yaml; yaml.safe_load(...)"` (REQ-NF-02 AC-5)
- [ ] 6. Write real pytest-bdd step definitions that verify the YAML structure/content directly (same pattern as Story 1.1 — no live Snowflake account exists, REQ-NF-02)
- [ ] 7. Run the Test Placement Verification Gate self-check: this story adds test files under `tests/behavior/` and `tests/unit/`? — actually only behavior-tier files, no unit-tier files; confirm placement matches `common/directory-structure.md` rules
- [ ] 8. Invoke `ve-implement` in workflow mode (mandatory per the updated dev-implement.md Step 6.7 part 1) to generate this story's manual test-plan artifacts
- [ ] 9. Run Static Eval Gate (D1-D7) diff against baseline
- [ ] 10. Run Behavioral Test Gate (B1 containerized, B2)

## Note on AC-2 scope

The story's AC-2 text lists "schema/threads/type/target" as fields that "may remain literal". In
`profiles.yml`'s actual structure, `target: dev` is a **top-level key under `dbt_code:`** (dbt's
output-selector), not a field inside `outputs.dev` alongside the connection parameters — it was never
a candidate for `env_var()` externalization in the first place (it selects which named output to use,
it holds no secret). The Gherkin scenario for AC-2 was written to assert against `schema`/`threads`/`type`
only, since those are the actual sibling fields of the 5 externalized ones within `outputs.dev`. This
is a structural clarification, not a scope reduction — `target` was never at risk of containing a
secret and needed no test.

## REQ/AC Trace Summary

| Plan Step | REQ-ID | AC |
|---|---|---|
| 2 | REQ-F-02 | AC-1, AC-2 |
| 3 | REQ-F-02 | AC-3 |
| 4 | REQ-NF-01 | AC-4 |
| 5 | REQ-NF-02 | AC-5 |

Every AC (1-5) and every covered REQ-ID (REQ-F-02, REQ-NF-01, REQ-NF-02) appears in ≥1 plan step. Trace complete.
