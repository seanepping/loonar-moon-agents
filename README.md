# loonar-moon-agents

Curated agent presets for the Loonar ecosystem.

This repo is the "distribution" layer:
- it defines agent presets (persona + skill profiles + tool guardrails)
- it vendors `loonar-moon-agent-skills` under `skills-pack/` (recommended: git subtree)

Canonical skills library:
- `loonar-moon-agent-skills`

See:
- `loonar-float-nix/docs/GIT-SUBTREE-RUNBOOK.md` for subtree mechanics
- `loonar-float-nix/docs/MOON-AGENT-SKILLS-CHAIN.md` for dependency chain design
