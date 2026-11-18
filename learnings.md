# Learnings

## 2026-11-18: review of skills

- Keep one maintained source for each skill. This repository has eight duplicated entry-point pairs, five of which differ.
- Current Claude documentation supports root-level skills. Missing nested trees alone do not prove installation failure.
- `allowed-tools` pre-approves tools; it does not limit the available tool set. Skill bodies load on invocation.
- Release fixtures reproduce an early exit when incrementing a zero version component and unintended dependency version changes in Cargo files.
- Measure task success and automatic selection separately. Compare current and reduced instructions against a no-skill baseline.
- Research sources, limits, review evidence, and proposed work: [Skills review](notes/2026-11-18-skills-review.md).
