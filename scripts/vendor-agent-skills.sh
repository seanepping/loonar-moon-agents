#!/usr/bin/env bash
set -Eeuo pipefail

# Vendor loonar-moon-agent-skills into skills-pack/ using git subtree.
#
# Supports two modes:
# - local path (default) for development in this workspace
# - GitHub remote via --github (for when repos are hosted)

usage() {
  cat >&2 <<'USAGE'
Usage:
  ./scripts/vendor-agent-skills.sh --ref <sha|tag> [--github <org>/<repo>] [--prefix <dir>] [--dry-run]

Defaults:
  --github loonar-moon/loonar-moon-agent-skills
  --prefix skills-pack

Without --github, uses the local workspace path:
  /var/lib/openclaw/.openclaw/workspace/loonar-moon-agent-skills

Notes:
- You must pass --ref (tag or SHA). This avoids accidentally pinning floating branches.
- This script validates the SkillPack contract before vendoring.
USAGE
}

GITHUB=""
REF=""
PREFIX="skills-pack"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --github) GITHUB="$2"; shift 2;;
    --ref) REF="$2"; shift 2;;
    --prefix) PREFIX="$2"; shift 2;;
    --dry-run) DRY_RUN=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "unknown arg: $1" >&2; usage; exit 2;;
  esac
done

if [[ -z "$REF" ]]; then
  echo "missing required: --ref <sha|tag>" >&2
  usage
  exit 2
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "$1 not found" >&2; exit 1; }; }
need git

# `git subtree` creates a commit in the target repo, so give non-interactive runs a
# deterministic local identity instead of depending on root/global git config.
export GIT_AUTHOR_NAME=${GIT_AUTHOR_NAME:-"OpenClaw"}
export GIT_AUTHOR_EMAIL=${GIT_AUTHOR_EMAIL:-"openclaw@local"}
export GIT_COMMITTER_NAME=${GIT_COMMITTER_NAME:-"$GIT_AUTHOR_NAME"}
export GIT_COMMITTER_EMAIL=${GIT_COMMITTER_EMAIL:-"$GIT_AUTHOR_EMAIL"}

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

REMOTE_NAME="loonar-moon-agent-skills"

REMOTE_URL=""
if [[ -n "$GITHUB" ]]; then
  REMOTE_URL="https://github.com/$GITHUB.git"
else
  REMOTE_URL="/var/lib/openclaw/.openclaw/workspace/loonar-moon-agent-skills"
fi

if git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  git remote set-url "$REMOTE_NAME" "$REMOTE_URL"
else
  git remote add "$REMOTE_NAME" "$REMOTE_URL"
fi

git fetch "$REMOTE_NAME" --prune

# `git subtree` accepts raw commit SHAs, but `remote/<sha>` is not a valid object name.
# Validate against the fetched SHA directly when the pin is a detached commit.
REMOTE_REF="$REF"
if ! git rev-parse --verify "$REMOTE_REF^{commit}" >/dev/null 2>&1; then
  REMOTE_REF="$REMOTE_NAME/$REF"
fi

# Contract validation: ensure the referenced tree looks like loonar-moon-agent-skills.
# Validate only the contract (manifest+profiles+skills), not implementation details.
required_paths=(
  "agent-skills.json"
  "profiles"
)

missing=0
for p in "${required_paths[@]}"; do
  if ! git ls-tree -d --name-only "$REMOTE_REF" "$p" >/dev/null 2>&1 && \
     ! git ls-tree --name-only "$REMOTE_REF" "$p" | grep -qx "$p"; then
    echo "missing required path in $REMOTE_REF: $p" >&2
    missing=1
  fi
done

# Require at least one SKILL.md under skills/ or dist/skills/.
if ! git ls-tree -r --name-only "$REMOTE_REF" | grep -E '^(skills|dist/skills)/[^/]+/SKILL\.md$' >/dev/null; then
  echo "missing SKILL.md under skills/ or dist/skills/ in $REMOTE_REF" >&2
  missing=1
fi

if [[ "$missing" -ne 0 ]]; then
  exit 2
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo "DRY RUN:" >&2
  echo "  remote: $REMOTE_URL" >&2
  echo "  ref:    $REMOTE_REF" >&2
  echo "  prefix: $PREFIX" >&2
  exit 0
fi

# If prefix exists, use subtree pull; otherwise, subtree add.
if [[ -d "$PREFIX" ]]; then
  # If the prefix is empty (repo skeleton created it), subtree add will fail.
  # Use a guard: require it be non-empty and git-tracked to treat as subtree.
  if git ls-files --error-unmatch "$PREFIX" >/dev/null 2>&1; then
    git subtree pull --prefix="$PREFIX" "$REMOTE_NAME" "$REF" --squash
  else
    rm -rf "$PREFIX"
    git subtree add --prefix="$PREFIX" "$REMOTE_NAME" "$REF" --squash
  fi
else
  git subtree add --prefix="$PREFIX" "$REMOTE_NAME" "$REF" --squash
fi

echo "Vendored $REMOTE_URL ($REF) into $PREFIX" >&2
