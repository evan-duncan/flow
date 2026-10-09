#!/usr/bin/env bash
# stack.sh — the "stack" CLI: one entrypoint for the stacked-diff helpers. It's a thin dispatcher over the sibling scripts in this
# directory, so each helper is still runnable on its own and the document in
# SKILL.md stays the source of truth.
#
# Usage:
#   stack.sh <command> [args…]
#
# Commands:
#   start <branch> [<parent>]      Create the next stacked layer branch and
#                                  record its parent. (start-stack-layer.sh)
#   show [<branch>]                Print the stack from leaf to base.
#                                  (show-stack.sh)
#   restack [<branch>]             Rebase a layer + its descendants back onto
#                                  their parent after the parent changed.
#                                  (restack.sh)
#   sync-after-land <branch>       After a layer lands in main, retarget its
#                                  child layers onto main. (sync-after-land.sh)
#   help                           Show this help.
#
# Every command forwards its remaining arguments verbatim, and each underlying
# script accepts -h/--help for its own detailed usage, e.g.:
#   stack.sh restack --help
#
# The trunk branch defaults to `main`; set STACK_BASE to override (e.g.
# STACK_BASE=master).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  sed -n '2,/^set -euo pipefail/{/^set -euo pipefail/!p;}' "$0" \
    | sed 's/^# \{0,1\}//'
}

cmd="${1:-help}"
if [[ $# -gt 0 ]]; then
  shift
fi

case "${cmd}" in
  start)
    exec bash "${SCRIPT_DIR}/start-stack-layer.sh" "$@"
    ;;
  show)
    exec bash "${SCRIPT_DIR}/show-stack.sh" "$@"
    ;;
  restack)
    exec bash "${SCRIPT_DIR}/restack.sh" "$@"
    ;;
  sync-after-land)
    exec bash "${SCRIPT_DIR}/sync-after-land.sh" "$@"
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown command: ${cmd}" >&2
    echo >&2
    usage >&2
    exit 2
    ;;
esac
