#!/usr/bin/env bash
# check-intent-doc.sh — structural checks for one intent-docs unit.
#
# Usage: check-intent-doc.sh <unit-dir> <contract-test-file>...
#
# Prints one line per failed check and exits 1 if any failed. Checks only what
# a script can judge; prose quality is left to the model-graded rubric.

set -uo pipefail

unit="$1"; shift
tests=("$@")
intent="${unit}/INTENT.md"
failed=0
fail() { echo "FAIL: $*"; failed=1; }

[[ -f "${intent}" ]] || { echo "FAIL: ${intent} missing"; exit 1; }
features=("${unit}"/*.feature)
[[ -f "${features[0]}" ]] || { echo "FAIL: no .feature files in ${unit}"; exit 1; }

# Title line, then the skill marker line.
head -1 "${intent}" | grep -qE '^# [^#]' || fail "first line is not a '# <unit name>' title"
grep -qxF 'Follows the intent-docs skill.' "${intent}" || fail "missing 'Follows the intent-docs skill.' line"

# Required sections, in order. Undecided is optional; Behavior must be gone.
expected="Purpose Glossary Public surface Decisions Non-goals Acceptance"
actual="$(grep -E '^## ' "${intent}" | sed 's/^## //' | grep -vx 'Undecided' | paste -sd' ' -)"
[[ "${actual}" == "${expected}" ]] || fail "sections are [${actual}], want [${expected}] (Undecided optional)"
grep -qE '^## Behavior' "${intent}" && fail "INTENT.md still has a Behavior section"

# No code blocks in INTENT.md.
grep -q '^[[:space:]]*```' "${intent}" && fail "INTENT.md contains a code block"

# Decision ids: each one tags at least one scenario; no scenario tag points at a
# missing decision.
ids="$(grep -oE '\bdecision-[0-9]+\b' "${intent}" | sort -u)"
[[ -n "${ids}" ]] || fail "Decisions table has no decision-<n> ids"
for id in ${ids}; do
  grep -qE "@${id}\b" "${features[@]}" || fail "${id} tags no scenario"
done
for tag in $(grep -ohE '@decision-[0-9]+\b' "${features[@]}" | sort -u); do
  grep -qE "\b${tag#@}\b" "${intent}" || fail "scenario tag ${tag} has no Decisions row"
done

# Scenario titles: unique within the unit, each quoted by a contract test.
titles="$(grep -hE '^[[:space:]]*(Scenario( Outline| Template)?|Example):' "${features[@]}" \
  | sed -E 's/^[[:space:]]*(Scenario( Outline| Template)?|Example):[[:space:]]*//')"
[[ -n "${titles}" ]] || fail "no scenarios found"
dupes="$(printf '%s\n' "${titles}" | sort | uniq -d)"
[[ -z "${dupes}" ]] || fail "duplicate scenario titles: ${dupes}"
if [[ ${#tests[@]} -eq 0 ]]; then
  fail "no contract test files given"
else
  while IFS= read -r t; do
    [[ -z "${t}" ]] && continue
    grep -qF -- "${t}" "${tests[@]}" || fail "uncovered scenario: ${t}"
  done <<< "${titles}"
fi

# No BDD framework dependency anywhere in the repo's manifests.
repo="$(git -C "${unit}" rev-parse --show-toplevel 2>/dev/null || echo "${unit}")"
if grep -rqiE '"(@cucumber/[a-z-]+|cucumber|jest-cucumber|behave|pytest-bdd|godog)"|^(behave|pytest-bdd)|cucumber/godog' \
    --include=package.json --include=requirements*.txt --include=pyproject.toml --include=go.mod \
    "${repo}" 2>/dev/null; then
  fail "a BDD framework dependency was added"
fi

exit "${failed}"
