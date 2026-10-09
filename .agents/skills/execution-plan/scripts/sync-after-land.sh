#!/usr/bin/env bash
# sync-after-land.sh — after a layer's PR merges into the trunk, bring the rest
# of the stack back to a sane state: rebase the landed layer's direct children
# onto the freshly-updated trunk, retarget their PRs to it, and re-point their
# recorded parent. Descendants deeper in the stack are restacked too.
#
# The trunk is $STACK_BASE (default `main`); "main" below means the trunk.
#
# Usage:
#   sync-after-land.sh <landed-branch>
#
# Steps:
#   1. Fetch origin and fast-forward the local `main` to origin/main.
#   2. Find local branches whose stackParent == <landed-branch>.
#   3. For each such child:
#        a. git rebase --onto main <old_base> <child>   (old_base = the landed
#           tip the child was built on, from stackParentTip).
#        b. Re-point: branch.<child>.stackParent = main,
#                     branch.<child>.stackParentTip = main tip.
#        c. gh pr edit <child> --base main  (best-effort; prints the manual
#           command if the GitHub CLI is unavailable or not authenticated).
#        d. restack.sh <child> to move any of the child's own descendants.
#
# Refuses on a dirty working tree. Restores the originally checked-out branch.
# After a clean run the landed branch has no children left pointing at it and
# can be deleted (git branch -d <landed-branch>) once its PR is merged.

set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,/^set -euo pipefail/{/^set -euo pipefail/!p;}' "$0" \
    | sed 's/^# \{0,1\}//'
  exit 0
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: sync-after-land.sh <landed-branch>" >&2
  exit 2
fi
landed_branch="$1"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not inside a git repository." >&2
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree not clean. Commit or stash before syncing." >&2
  git status --short >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
original_branch="$(git rev-parse --abbrev-ref HEAD)"
base="${STACK_BASE:-main}"

# 1. Update main from origin (fast-forward only — main never diverges locally).
echo "Fetching origin/${base}…"
git fetch origin "${base}"
if [[ "${original_branch}" == "${base}" ]]; then
  git merge --ff-only "origin/${base}"
else
  git branch -f "${base}" "origin/${base}"
fi
main_tip="$(git rev-parse "${base}")"
echo "${base} is now at ${main_tip:0:9}."

# Print branch names whose recorded parent is $1, one per line. Git stores
# config variable names lowercased (the branch subsection keeps its case), so we
# match the canonical `.stackparent` key and read its value directly.
children_of() {
  local target="$1" key value name
  while read -r key value; do
    [[ -z "${key}" ]] && continue
    [[ "${value}" == "${target}" ]] || continue
    name="${key#branch.}"
    name="${name%.stackparent}"
    echo "${name}"
  done < <(git config --get-regexp '^branch\..*\.stackparent$' 2>/dev/null || true)
}

# Collect children into an array without `mapfile` (unavailable in bash 3.2,
# which is what ships on macOS).
children=()
while IFS= read -r child_name; do
  [[ -z "${child_name}" ]] && continue
  children+=("${child_name}")
done < <(children_of "${landed_branch}")

if [[ ${#children[@]} -eq 0 ]]; then
  echo "No local branches are stacked on '${landed_branch}'. Nothing to do."
  exit 0
fi

have_gh=false
if command -v gh >/dev/null 2>&1; then
  have_gh=true
fi

for child in "${children[@]}"; do
  echo
  echo "── Reparenting ${child}: ${landed_branch} → ${base} ──"

  old_base="$(git config --get "branch.${child}.stackParentTip" || true)"
  if [[ -z "${old_base}" ]]; then
    if git show-ref --verify --quiet "refs/heads/${landed_branch}"; then
      old_base="$(git rev-parse "${landed_branch}")"
    else
      old_base="$(git merge-base "${base}" "${child}")"
    fi
  fi

  echo "↻ rebasing ${child} onto ${base} (${old_base:0:9} → ${main_tip:0:9})…"
  git rebase --onto "${base}" "${old_base}" "${child}"

  git config "branch.${child}.stackParent" "${base}"
  git config "branch.${child}.stackParentTip" "${main_tip}"

  if [[ "${have_gh}" == true ]]; then
    if gh pr edit "${child}" --base "${base}" >/dev/null 2>&1; then
      echo "✓ retargeted ${child} PR base → ${base} via gh."
    else
      echo "! could not retarget ${child} PR automatically." >&2
      echo "  Run manually once its PR exists: gh pr edit ${child} --base ${base}" >&2
    fi
  else
    echo "  gh CLI not found — retarget the PR manually: gh pr edit ${child} --base ${base}"
  fi

  # Move any of this child's own descendants onto the rebased child.
  bash "${SCRIPT_DIR}/restack.sh" "${child}"
done

if git show-ref --verify --quiet "refs/heads/${original_branch}"; then
  git checkout -q "${original_branch}"
fi

echo
echo "Sync complete. '${landed_branch}' has no children left on it."
echo "Once its PR is merged you can: git branch -d ${landed_branch}"
