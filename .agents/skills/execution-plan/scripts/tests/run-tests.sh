#!/usr/bin/env bash
# run-tests.sh — self-contained test suite for the stacked diff CLI (the scripts
# in ../). No external test framework: just bash and git.
#
# Usage:
#   run-tests.sh            # run every test
#   run-tests.sh -v         # also echo each test's captured output
#
# Each test runs in its own throwaway git repo (with a bare "origin" remote) so
# tests never touch the real repository and can't contaminate each other. A
# stub `gh` is injected on PATH where a test needs a deterministic PR-retarget
# result.
#
# Exit code is non-zero if any test fails, so CI can gate on it.

set -uo pipefail

VERBOSE=false
[[ "${1:-}" == "-v" || "${1:-}" == "--verbose" ]] && VERBOSE=true

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK="${SCRIPTS_DIR}/stack.sh"

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/stack-tests.XXXXXX")"
trap 'rm -rf "${TMPROOT}"' EXIT

TESTS_RUN=0
TESTS_FAILED=0

# ----- assertions (call exit 1 on failure; tests run inside $() subshells) -----

fail() {
  echo "ASSERT FAILED: $*" >&2
  exit 1
}

assert_eq() {
  # assert_eq <expected> <actual> [message]
  [[ "$1" == "$2" ]] || fail "${3:-equality} — expected [$1], got [$2]"
}

assert_contains() {
  # assert_contains <haystack> <needle> [message]
  case "$1" in
    *"$2"*) : ;;
    *) fail "${3:-contains} — [$2] not found in output" ;;
  esac
}

assert_succeeds() {
  "$@" || fail "expected success but got exit $?: $*"
}

assert_fails() {
  # Used in `if` so set -e never aborts on the expected failure.
  if "$@" >/dev/null 2>&1; then
    fail "expected failure but command succeeded: $*"
  fi
}

assert_ancestor() {
  # assert_ancestor <maybe-ancestor> <descendant> [message]
  git merge-base --is-ancestor "$1" "$2" \
    || fail "${3:-ancestry} — [$1] is not an ancestor of [$2]"
}

assert_config() {
  # assert_config <git-config-key> <expected-value> [message]
  assert_eq "$2" "$(git config --get "$1" || true)" "${3:-config $1}"
}

# ----- fixtures -----------------------------------------------------------------

# Create a fresh repo with a bare origin and a base commit on main; cd into it.
make_repo() {
  local root
  root="$(mktemp -d "${TMPROOT}/repo.XXXXXX")"
  git init -q --bare "${root}/origin.git"
  git clone -q "${root}/origin.git" "${root}/work" 2>/dev/null
  cd "${root}/work" || exit 1
  git config user.name "Test Runner"
  git config user.email "test@example.com"
  git symbolic-ref HEAD refs/heads/main
  echo base > base.txt
  git add base.txt
  git commit -qm "chore: base commit"
  git push -q -u origin main
}

# Put a stub `gh` on PATH that exits with the given code, so sync-after-land's
# retarget branch is deterministic. Call inside a test (PATH change is local).
stub_gh() {
  # Create the stub OUTSIDE the work tree so it never dirties the repo under
  # test (sync-after-land correctly refuses on a dirty tree).
  local code="${1:-0}" bindir
  bindir="$(mktemp -d "${TMPROOT}/fakebin.XXXXXX")"
  cat > "${bindir}/gh" <<EOF
#!/usr/bin/env bash
echo "stub-gh $*" >&2
exit ${code}
EOF
  chmod +x "${bindir}/gh"
  export PATH="${bindir}:${PATH}"
}

# Build a 3-layer stack a <- b <- c, each with one commit.
build_stack() {
  "${STACK}" start stack-0-a main >/dev/null
  echo a1 > a.txt; git add a.txt; git commit -qm "feat: a1"
  "${STACK}" start stack-1-b stack-0-a >/dev/null
  echo b1 > b.txt; git add b.txt; git commit -qm "feat: b1"
  "${STACK}" start stack-2-c stack-1-b >/dev/null
  echo c1 > c.txt; git add c.txt; git commit -qm "feat: c1"
}

# ----- tests --------------------------------------------------------------------

test_start_creates_branch_and_records_parent_and_tip() {
  make_repo
  local main_tip
  main_tip="$(git rev-parse main)"
  "${STACK}" start stack-0-a main >/dev/null
  assert_eq "stack-0-a" "$(git rev-parse --abbrev-ref HEAD)" "checked out new branch"
  assert_config "branch.stack-0-a.stackParent" "main" "records parent"
  assert_config "branch.stack-0-a.stackParentTip" "${main_tip}" "records parent tip"
}

test_start_defaults_parent_to_current_branch() {
  make_repo
  "${STACK}" start stack-0-a main >/dev/null
  # No explicit parent: should stack on the current branch (a).
  "${STACK}" start stack-1-b >/dev/null
  assert_config "branch.stack-1-b.stackParent" "stack-0-a" "defaults to current branch"
}

test_start_rejects_bad_branch_name() {
  make_repo
  assert_fails "${STACK}" start "bad..name" main
}

test_start_rejects_dirty_tree() {
  make_repo
  echo dirty > dirty.txt
  git add dirty.txt
  assert_fails "${STACK}" start stack-0-a main
}

test_start_rejects_existing_branch() {
  make_repo
  "${STACK}" start stack-0-a main >/dev/null
  git checkout -q main
  assert_fails "${STACK}" start stack-0-a main
}

test_start_rejects_missing_parent() {
  make_repo
  assert_fails "${STACK}" start stack-0-a does-not-exist
}

test_show_prints_chain_leaf_to_base() {
  make_repo
  build_stack
  local out
  out="$("${STACK}" show stack-2-c)"
  assert_contains "${out}" "main" "shows base"
  assert_contains "${out}" "stack-0-a" "shows layer a"
  assert_contains "${out}" "stack-1-b" "shows layer b"
  assert_contains "${out}" "stack-2-c <- current" "marks current leaf"
}

test_show_flags_missing_parent() {
  make_repo
  "${STACK}" start stack-0-a main >/dev/null
  echo a1 > a.txt; git add a.txt; git commit -qm "feat: a1"
  "${STACK}" start stack-1-b stack-0-a >/dev/null
  git branch -D stack-0-a >/dev/null 2>&1 || true
  assert_contains "$("${STACK}" show stack-1-b)" "missing locally" "flags missing parent"
}

test_restack_moves_descendants_after_parent_changes() {
  make_repo
  build_stack
  git checkout -q stack-0-a
  echo a2 > a2.txt; git add a2.txt; git commit -qm "feat: a2"
  local a_tip
  a_tip="$(git rev-parse stack-0-a)"
  "${STACK}" restack stack-0-a >/dev/null
  assert_ancestor "${a_tip}" "stack-1-b" "b rebased onto new a"
  assert_ancestor "${a_tip}" "stack-2-c" "c rebased onto new a"
  assert_config "branch.stack-1-b.stackParentTip" "${a_tip}" "b parent tip updated"
}

test_restack_is_noop_when_up_to_date() {
  make_repo
  build_stack
  local b_before
  b_before="$(git rev-parse stack-1-b)"
  local out
  out="$("${STACK}" restack stack-0-a)"
  assert_contains "${out}" "no rebase needed" "reports up-to-date"
  assert_eq "${b_before}" "$(git rev-parse stack-1-b)" "b unchanged when current"
}

test_restack_no_duplicate_commits() {
  make_repo
  build_stack
  git checkout -q stack-0-a
  echo a2 > a2.txt; git add a2.txt; git commit -qm "feat: a2"
  "${STACK}" restack stack-0-a >/dev/null
  # b should still contain exactly its own commit relative to its parent.
  local subjects
  subjects="$(git log --format='%s' stack-0-a..stack-1-b)"
  assert_eq "feat: b1" "${subjects}" "b has only its own commit over a"
}

test_restack_conflict_recovery_after_continue() {
  # The documented recovery path: a layer's rebase conflicts, the user resolves
  # and `git rebase --continue`s, then re-runs restack. The re-run must treat
  # the layer as already rebased (its recorded stackParentTip is stale —
  # restack died before updating it) instead of replaying the parent's own
  # commits through the layer, and must continue into descendants.
  make_repo
  "${STACK}" start stack-0-a main >/dev/null
  echo v1 > shared.txt; echo base > conflict.txt
  git add .; git commit -qm "feat: a1"
  "${STACK}" start stack-1-b stack-0-a >/dev/null
  echo from-b > conflict.txt; git add .; git commit -qm "feat: b1"
  "${STACK}" start stack-2-c stack-1-b >/dev/null
  echo c1 > c.txt; git add c.txt; git commit -qm "feat: c1"
  # Parent advances: one commit conflicting with b, plus two sequential edits
  # to the same line of shared.txt — replaying those parent commits through b
  # (the bug) conflicts deterministically.
  git checkout -q stack-0-a
  echo from-a > conflict.txt; git add .; git commit -qm "feat: a2"
  echo v2 > shared.txt; git add .; git commit -qm "feat: a3"
  echo v3 > shared.txt; git add .; git commit -qm "feat: a4"
  local a_tip
  a_tip="$(git rev-parse stack-0-a)"
  # First restack stops on b's real conflict.
  assert_fails "${STACK}" restack stack-0-a
  # Resolve and continue, per the documented recovery path.
  echo resolved > conflict.txt
  git add conflict.txt
  GIT_EDITOR=true git rebase --continue >/dev/null 2>&1 \
    || fail "rebase --continue did not complete"
  # Re-run restack: must skip b's rebase and move c onto the new b.
  assert_succeeds "${STACK}" restack stack-0-a
  assert_eq "feat: b1" "$(git log --format='%s' stack-0-a..stack-1-b)" \
    "b has only its own commit over a (no replayed parent commits)"
  assert_ancestor "${a_tip}" "stack-2-c" "c restacked onto recovered b"
  assert_config "branch.stack-1-b.stackParentTip" "${a_tip}" "b parent tip healed"
}

test_sync_after_land_reparents_children_to_main() {
  make_repo
  build_stack
  stub_gh 1   # gh present but cannot retarget (no real PR)
  git checkout -q main
  git merge -q --no-ff stack-0-a -m "Merge stack-0-a"
  git push -q origin main
  git reset -q --hard HEAD~1     # pretend we hadn't pulled the landed main yet
  git checkout -q stack-2-c
  local out
  # Capture stderr too: the manual retarget hint is a warning on stderr.
  out="$("${STACK}" sync-after-land stack-0-a 2>&1)"
  assert_config "branch.stack-1-b.stackParent" "main" "b reparented to main"
  assert_config "branch.stack-2-c.stackParent" "stack-1-b" "c still on b"
  assert_ancestor "$(git rev-parse main)" "stack-1-b" "b sits on landed main"
  assert_ancestor "$(git rev-parse main)" "stack-2-c" "c sits on landed main"
  assert_eq "feat: b1" "$(git log --format='%s' main..stack-1-b)" "no duplicate a-commits in b"
  assert_contains "${out}" "gh pr edit stack-1-b --base main" "prints manual retarget hint on gh failure"
}

test_sync_after_land_uses_gh_on_success() {
  make_repo
  build_stack
  stub_gh 0   # gh present and succeeds
  git checkout -q main
  git merge -q --no-ff stack-0-a -m "Merge stack-0-a"
  git push -q origin main
  git reset -q --hard HEAD~1
  git checkout -q stack-2-c
  assert_contains "$("${STACK}" sync-after-land stack-0-a)" \
    "retargeted stack-1-b PR base" "reports successful gh retarget"
}

test_sync_after_land_no_children_is_safe() {
  make_repo
  "${STACK}" start stack-0-a main >/dev/null
  echo a1 > a.txt; git add a.txt; git commit -qm "feat: a1"
  stub_gh 0
  git checkout -q main
  assert_contains "$("${STACK}" sync-after-land stack-0-a)" \
    "No local branches are stacked" "handles no-children gracefully"
}

test_stack_base_overrides_trunk() {
  make_repo
  git branch -m main trunk
  git push -q -u origin trunk
  STACK_BASE=trunk "${STACK}" start stack-0-a >/dev/null
  assert_config "branch.stack-0-a.stackParent" "trunk" "defaults parent to STACK_BASE"
  echo a1 > a.txt; git add a.txt; git commit -qm "feat: a1"
  "${STACK}" start stack-1-b >/dev/null
  echo b1 > b.txt; git add b.txt; git commit -qm "feat: b1"
  stub_gh 0
  git checkout -q trunk
  git merge -q --no-ff stack-0-a -m "Merge stack-0-a"
  git push -q origin trunk
  git reset -q --hard HEAD~1
  git checkout -q stack-1-b
  STACK_BASE=trunk "${STACK}" sync-after-land stack-0-a >/dev/null 2>&1 \
    || fail "sync-after-land failed with STACK_BASE=trunk"
  assert_config "branch.stack-1-b.stackParent" "trunk" "b reparented to STACK_BASE"
  assert_ancestor "$(git rev-parse trunk)" "stack-1-b" "b sits on landed trunk"
}

test_dispatch_unknown_command_exits_2() {
  make_repo
  local code=0
  "${STACK}" totally-bogus >/dev/null 2>&1 || code=$?
  assert_eq "2" "${code}" "unknown command exits 2"
}

test_dispatch_help_lists_commands() {
  make_repo
  assert_contains "$("${STACK}" help)" "sync-after-land" "help lists commands"
}

# ----- runner -------------------------------------------------------------------

run_test() {
  local name="$1" out status
  TESTS_RUN=$((TESTS_RUN + 1))
  # Command substitution runs in a subshell, so a failing assertion's `exit 1`
  # ends only this test, and `cd` into the fixture never leaks.
  if out="$("${name}" 2>&1)"; then
    echo "ok   - ${name}"
    if [[ "${VERBOSE}" == true && -n "${out}" ]]; then
      echo "${out}" | sed 's/^/       /'
    fi
  else
    status=$?
    echo "FAIL - ${name} (exit ${status})"
    echo "${out}" | sed 's/^/       /'
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

main() {
  echo "Running stack CLI tests against: ${SCRIPTS_DIR}"
  echo

  # Sanity: every helper must at least parse.
  local s
  for s in "${SCRIPTS_DIR}"/*.sh; do
    bash -n "${s}" || { echo "FAIL - syntax error in ${s}"; exit 1; }
  done

  run_test test_start_creates_branch_and_records_parent_and_tip
  run_test test_start_defaults_parent_to_current_branch
  run_test test_start_rejects_bad_branch_name
  run_test test_start_rejects_dirty_tree
  run_test test_start_rejects_existing_branch
  run_test test_start_rejects_missing_parent
  run_test test_show_prints_chain_leaf_to_base
  run_test test_show_flags_missing_parent
  run_test test_restack_moves_descendants_after_parent_changes
  run_test test_restack_is_noop_when_up_to_date
  run_test test_restack_no_duplicate_commits
  run_test test_restack_conflict_recovery_after_continue
  run_test test_sync_after_land_reparents_children_to_main
  run_test test_sync_after_land_uses_gh_on_success
  run_test test_sync_after_land_no_children_is_safe
  run_test test_stack_base_overrides_trunk
  run_test test_dispatch_unknown_command_exits_2
  run_test test_dispatch_help_lists_commands

  echo
  echo "----------------------------------------"
  echo "Ran ${TESTS_RUN} tests, ${TESTS_FAILED} failed."
  [[ "${TESTS_FAILED}" -eq 0 ]]
}

main "$@"
