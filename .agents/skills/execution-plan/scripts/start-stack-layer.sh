#!/usr/bin/env bash
# start-stack-layer.sh — create the next stacked branch for a layer and
# record its parent layer in git config so show-stack.sh can walk the stack.
#
# Usage:
#   start-stack-layer.sh <branch> [<parent-branch>]
#
#   <branch>         The new branch name. Must be a valid git branch name.
#   <parent-branch>  Optional. The branch this layer stacks on top of. Defaults
#                    to the currently checked-out branch unless that is the
#                    trunk ($STACK_BASE, default `main`) or detached, in which
#                    case it defaults to the trunk.
#
# The script:
#   1. Refuses unless the working tree is clean (no uncommitted changes).
#   2. Refuses unless the branch name is a valid git branch name.
#   3. Ensures the parent branch exists locally.
#   4. Creates the new branch off the parent and checks it out.
#   5. Records the parent in git config (branch.<new>.stackParent) so
#      show-stack.sh can walk relationships, plus the parent's current tip
#      (branch.<new>.stackParentTip) so restack.sh knows the rebase base.
#
# It deliberately does NOT push the branch or open a PR — that happens once
# real commits exist on the layer (the planning-doc commit on the first layer,
# the implementation commits on subsequent layers).

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: start-stack-layer.sh <branch> [<parent-branch>]" >&2
  exit 2
fi

new_branch="$1"
parent_branch="${2:-}"
base_branch="${STACK_BASE:-main}"

# 1. Validate name.
if ! git check-ref-format --branch "${new_branch}" >/dev/null 2>&1; then
  echo "Not a valid branch name: '${new_branch}'" >&2
  exit 1
fi

# 2. Repo + clean tree.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not inside a git repository." >&2
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree not clean. Commit or stash before starting a new layer." >&2
  git status --short >&2
  exit 1
fi

# 3. Resolve parent.
current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ -z "${parent_branch}" ]]; then
  if [[ "${current_branch}" == "${base_branch}" || "${current_branch}" == "HEAD" ]]; then
    parent_branch="${base_branch}"
  else
    parent_branch="${current_branch}"
  fi
fi

if ! git show-ref --verify --quiet "refs/heads/${parent_branch}"; then
  echo "Parent branch '${parent_branch}' does not exist locally." >&2
  echo "Hint: run 'git fetch origin ${parent_branch}:${parent_branch}' or check the name." >&2
  exit 1
fi

if git show-ref --verify --quiet "refs/heads/${new_branch}"; then
  echo "Branch '${new_branch}' already exists. Refusing to overwrite." >&2
  exit 1
fi

# 4. Create and check out.
git checkout -b "${new_branch}" "${parent_branch}"

# 5. Record parent (so show-stack.sh can walk relationships) and the parent's
#    current tip (so restack.sh / sync-after-land.sh have a precise rebase base
#    even after the parent is later amended or rebased). Both live in plain git
#    config — no state outside the repo.
git config "branch.${new_branch}.stackParent" "${parent_branch}"
git config "branch.${new_branch}.stackParentTip" "$(git rev-parse "${parent_branch}")"

echo
echo "Started layer:"
echo "  branch: ${new_branch}"
echo "  parent: ${parent_branch}"
echo
echo "Next: commit the layer's work, then open its PR against '${parent_branch}'."
