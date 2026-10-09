#!/usr/bin/env bash
# restack.sh — rebase a stacked layer (and its descendants) back on top of its
# parent layer after the parent was amended, rebased, or grew new commits.
#
# Usage:
#   restack.sh                # restack the current branch + its descendants
#   restack.sh <branch>       # restack <branch> + its descendants
#
# It relies only on the relationship state recorded by start-stack-layer.sh in
# plain git config — no state outside the repo:
#   branch.<name>.stackParent     the parent layer's branch name
#   branch.<name>.stackParentTip  the parent tip this layer was last built on
#                                     (the rebase "old base"). Falls back to the
#                                     merge-base for layers created before this
#                                     field existed.
#
# Algorithm:
#   1. <branch> defaults to the current branch.
#   2. parent = branch.<branch>.stackParent. No parent => it's a base
#      branch (e.g. main); nothing to rebase, just walk into its children.
#   3. old_base = branch.<branch>.stackParentTip, else merge-base(parent,branch).
#   4. If the parent tip already equals old_base — or the branch already
#      contains the parent tip (a conflicted restack finished by hand left
#      old_base stale) — the layer is current; skip its rebase. Otherwise:
#      git rebase --onto <parent> <old_base> <branch>.
#   5. Record the parent's current tip in stackParentTip.
#   6. Recurse into children (branches whose stackParent == branch) so the
#      whole stack above <branch> is moved too.
#
# Refuses on a dirty working tree. Restores the originally checked-out branch
# when it finishes cleanly. If a rebase hits a conflict, git stops as usual —
# resolve it, `git rebase --continue`, then re-run restack.sh to finish the
# rest of the stack.

set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,/^set -euo pipefail/{/^set -euo pipefail/!p;}' "$0" \
    | sed 's/^# \{0,1\}//'
  exit 0
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not inside a git repository." >&2
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree not clean. Commit or stash before restacking." >&2
  git status --short >&2
  exit 1
fi

start_branch="${1:-$(git rev-parse --abbrev-ref HEAD)}"
if [[ "${start_branch}" == "HEAD" ]]; then
  echo "Detached HEAD — check out a stack branch first." >&2
  exit 1
fi
if ! git show-ref --verify --quiet "refs/heads/${start_branch}"; then
  echo "Branch '${start_branch}' does not exist locally." >&2
  exit 1
fi

original_branch="$(git rev-parse --abbrev-ref HEAD)"

# Print the branch names whose recorded parent is $1, one per line. Git stores
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

restack_one() {
  local branch="$1" parent parent_tip old_base child
  parent="$(git config --get "branch.${branch}.stackParent" || true)"

  if [[ -z "${parent}" ]]; then
    echo "• ${branch} is a base branch (no recorded parent); nothing to rebase."
  elif ! git show-ref --verify --quiet "refs/heads/${parent}"; then
    echo "! parent '${parent}' of '${branch}' missing locally; skipping its rebase." >&2
  else
    parent_tip="$(git rev-parse "${parent}")"
    old_base="$(git config --get "branch.${branch}.stackParentTip" || true)"
    if [[ -z "${old_base}" ]]; then
      old_base="$(git merge-base "${parent}" "${branch}")"
    fi
    if [[ "${parent_tip}" == "${old_base}" ]]; then
      echo "✓ ${branch} already on latest ${parent} (${parent_tip:0:9}); no rebase needed."
    elif git merge-base --is-ancestor "${parent_tip}" "${branch}"; then
      # The layer already sits on the parent's tip but its recorded old base
      # is stale — e.g. a prior restack conflicted (dying before the tip
      # update below) and the rebase was finished by hand. Rebasing again
      # with the stale old base would replay the parent's own commits through
      # the layer; just record the tip instead.
      echo "✓ ${branch} already contains ${parent} tip (${parent_tip:0:9}); recording it as the new base."
    else
      echo "↻ restacking ${branch} onto ${parent} (${old_base:0:9} → ${parent_tip:0:9})…"
      git rebase --onto "${parent}" "${old_base}" "${branch}"
    fi
    git config "branch.${branch}.stackParentTip" "${parent_tip}"
  fi

  while IFS= read -r child; do
    [[ -z "${child}" ]] && continue
    restack_one "${child}"
  done < <(children_of "${branch}")
}

restack_one "${start_branch}"

# Return to wherever the caller started, if it still exists.
if git show-ref --verify --quiet "refs/heads/${original_branch}"; then
  git checkout -q "${original_branch}"
fi

echo
echo "Restack complete. Current stack:"
bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/show-stack.sh" "${start_branch}"
