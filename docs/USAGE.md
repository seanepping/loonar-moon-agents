# Usage

## Vendor skills-pack

We vendor `loonar-moon-agent-skills` into `skills-pack/` using git subtree.

See `loonar-float-nix/docs/GIT-SUBTREE-RUNBOOK.md`.

## Agent presets

Agent presets live under `agents/<id>/`.

Each preset should:
- declare which skill profile(s) it enables
- optionally declare tool allowlists/guardrails

