<!--
dod-checklist.md — the per-layer Definition of Done. Walk it with the user
before opening the layer's PR. Paste the checked list into the PR body.
Skip items that don't apply; add repo-specific ones from CLAUDE.md /
AGENTS.md / CONTRIBUTING.md.
-->

## Definition of Done — Layer {{layer_number}}{{ ({{subtask_id}})}}

### Code

- [ ] Scope matches this layer's section of the planning doc; nothing from
      other layers snuck in.
- [ ] The repo's lint / typecheck / format checks pass locally.
- [ ] The repo's tests pass locally for the affected areas.
- [ ] No debug code or stray TODOs left behind.

### Tests

- [ ] Tests were added or updated for every behavior change.
- [ ] The layer is green on its own, on top of its parent layer.

### Intent docs (skip if no unit with an INTENT.md is touched)

- [ ] Every behavior change has its Decisions row and a scenario tagged
      with that decision's id, in this same layer.
- [ ] Each new or changed scenario has a contract test that quotes its
      title, failed on the old behavior, and passes now.
- [ ] The intent-docs coverage check reports no uncovered scenarios.
- [ ] Open questions this layer settles are now Decisions or Undecided
      entries, not open in the plan.
- [ ] A refactor-only layer leaves `INTENT.md`, scenarios and contract
      tests unchanged.

### Stack hygiene

- [ ] Branch is up to date with its parent layer (`stack.sh restack` if not).
- [ ] PR base is the parent layer's branch (or the trunk for layer 1).
- [ ] Commits follow the repo's message conventions.

### Delivery

- [ ] Tracker sub-task (if any) is in its review state.
- [ ] Planning doc still matches reality, or is updated in this PR.

### Not here

- ✗ Don't merge the PR or edit the trunk directly. Humans land it.
