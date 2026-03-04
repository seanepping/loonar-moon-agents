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
  ./scripts/vendor-agent-skills.sh [--github <org>/<repo>] [--branch <name>] [--prefix <dir>]

Defaults:
  --github loonar-moon/loonar-moon-agent-skills
  --branch main
  --prefix skills-pack

Without --github, uses the local workspace path:
  /var/lib/openclaw/.openclaw/workspace/loonar-moon-agent-skills
USAGE
}

GITHUB=""
BRANCH="main"
PREFIX="skills-pack"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --github) GITHUB="$2"; shift 2;;
    --branch) BRANCH="$2"; shift 2;;
    --prefix) PREFIX="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "unknown arg: $1" >&2; usage; exit 2;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "$1 not found" >&2; exit 1; }; }
need git

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

# If prefix exists, use subtree pull; otherwise, subtree add.
if [[ -d "$PREFIX" ]]; then
  # If the prefix is empty (repo skeleton created it), subtree add will fail.
  # Use a guard: require it be non-empty and git-tracked to treat as subtree.
  if git ls-files --error-unmatch "$PREFIX" >/dev/null 2>&1; then
    git subtree pull --prefix="$PREFIX" "$REMOTE_NAME" "$BRANCH" --squash
  else
    rm -rf "$PREFIX"
    git subtree add --prefix="$PREFIX" "$REMOTE_NAME" "$BRANCH" --squash
  fi
else
  git subtree add --prefix="$PREFIX" "$REMOTE_NAME" "$BRANCH" --squash
fi

echo "Vendored $REMOTE_URL into $PREFIX" >&2
