#!/usr/bin/env bash
# show-stack.sh — print the current stack as recorded by start-stack-layer.sh.
#
# Walks branch.<name>.stackParent git config entries starting from the
# current branch (or a branch you pass in) until it reaches a branch with no
# recorded parent (typically `main`).
#
# Usage:
#   show-stack.sh                 # show stack rooted at current branch
#   show-stack.sh <branch>        # show stack rooted at <branch>

set -euo pipefail

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not inside a git repository." >&2
  exit 1
fi

start_branch="${1:-$(git rev-parse --abbrev-ref HEAD)}"

if [[ "${start_branch}" == "HEAD" ]]; then
  echo "Detached HEAD — no stack to show." >&2
  exit 1
fi

# Collect chain from leaf -> base.
chain=()
current="${start_branch}"
seen=()
while [[ -n "${current}" ]]; do
  for s in "${seen[@]:-}"; do
    if [[ "${s}" == "${current}" ]]; then
      echo "Detected a cycle in stackParent config at '${current}'. Aborting." >&2
      exit 1
    fi
  done
  seen+=("${current}")
  chain+=("${current}")
  parent=$(git config --get "branch.${current}.stackParent" || true)
  if [[ -z "${parent}" ]]; then
    break
  fi
  if ! git show-ref --verify --quiet "refs/heads/${parent}"; then
    chain+=("${parent} (missing locally)")
    break
  fi
  current="${parent}"
done

echo "Stack from current layer down to base:"
echo
indent=""
for ((i=${#chain[@]}-1; i>=0; i--)); do
  branch="${chain[i]}"
  marker=""
  if [[ "${branch}" == "${start_branch}" ]]; then
    marker=" <- current"
  fi
  echo "${indent}${branch}${marker}"
  indent="${indent}  "
done
