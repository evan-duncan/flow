---
name: execution-plan
description: Use when the user wants to break a feature, story, or ticket into an ordered stack of small, independently reviewable PRs and then deliver it layer by layer — "plan this as stacked PRs", "break this into layers", "start the next stack layer", "open the layer PR", "restack", "the parent layer landed". Covers the planning doc, per-layer Definition of Done, stacked branches, and optional issue-tracker sub-tasks.
---

# Execution plan — stacked delivery

Turn one piece of work into an ordered stack of layers, then ship it one
layer at a time. Each layer gets one branch and one PR. If a tracker is in
play, each layer also gets one sub-task.

Files (paths relative to this skill's directory):

- `templates/planning-doc.md`: the plan, committed as layer 1's first commit.
- `templates/dod-checklist.md`: the per-layer Definition of Done.
- `scripts/stack.sh`: the stack CLI (`start`, `show`, `restack`,
  `sync-after-land`). Run it as `bash <skill-dir>/scripts/stack.sh …`.

## Why these rules

- Big PRs get rubber-stamped. Small layers get real review, and reviewers
  can start on layer 1 while layer 2 is still being written.
- A layer that bundles two concerns can't be reverted or reviewed alone.
  One cut point is one layer is one PR.
- Writing the plan before the code makes the cut points explicit. Putting
  the plan in layer 1 lets reviewers see the whole shape first.
- A PR for layer N>1 that targets the trunk shows every lower layer's diff.
  It targets layer N-1's branch.

## 1. Plan

1. **Get the work.** It can be a ticket (read it with whatever tracker
   tools are connected), a spec doc, or a prompt. Do not create the parent
   ticket. The user provides it.
2. **Design with the user** before cutting layers. Don't write layers until
   you and the user agree on the approach and the cut points. If the user
   has a sketch, or the work has a shape worth drawing (a screen, a flow,
   how components connect), use the fat-marker skill first and plan from
   its confirmed read-back.
3. **Cut the stack.** Each layer must:
   - build and pass tests on its own, on top of the layers below it;
   - be reviewable in one sitting (aim for a few hundred lines of diff);
   - have a one-line summary that says what it delivers.

   Good cuts follow dependencies. Examples: schema, then domain logic, then
   API, then UI. Or a refactor that changes no behavior, then the feature on
   top. Layer 1 holds the planning doc, plus a small amount of foundation
   code if that makes sense. If the repo has `INTENT.md` files, also follow
   [With intent docs](#with-intent-docs). With a sketch, each layer names
   the sketch parts it delivers, and every part is in some layer or out of
   scope.
4. **Write the planning doc** from `templates/planning-doc.md`. Use the
   repo's plan directory if it has one, otherwise `docs/plans/`. Name it
   `YYYY-MM-DD-<slug>.md`. Write one section per layer, in stack order.
   Don't commit it yet; it lands on layer 1's branch, along with any
   sketch files it links.
5. **Tracker sub-tasks (optional).** If the user named a ticket or a
   tracker (Jira, Linear, GitHub Issues, …), create one sub-task per layer,
   in stack order, under the parent, using the connected tracker tools. Ask
   the user for required fields you can't infer. Then put the real
   sub-task ids and branch names into the planning doc. With no tracker,
   skip this step. The planning doc is the record.

## 2. Start a layer

1. Find the next layer. If unsure, run `stack.sh show` and check the
   planning doc.
2. Parent branch: the trunk for layer 1. For layer N>1, layer N-1's branch.
3. Branch name: follow the repo's convention. If the repo has none, use
   `<sub-task-id>-<slug>` with a tracker and `<slug>` without one.
4. Run `stack.sh start <new-branch> [<parent-branch>]`. It refuses a dirty
   tree, an invalid name, a missing parent, or an existing branch. It
   records the parent in git config (`branch.<name>.stackParent`).
5. **Layer 1 only:** commit the planning doc, and its sketch files if
   any, as the first commit (`docs: plan <work> stack`).
6. If there is a tracker, move the sub-task to its in-progress state.
7. Tell the user what the layer's next concrete commit should be.

Commits follow the repo's conventions. If it has none, use Conventional
Commits with a body that explains why.

## 3. Open the layer PR

1. Walk `templates/dod-checklist.md` with the user. Run the repo's checks
   yourself. Never report a check you did not run.
2. `git push -u origin HEAD`.
3. PR base: the trunk for layer 1. Otherwise read
   `git config branch.$(git rev-parse --abbrev-ref HEAD).stackParent`.
   Never let it default to the trunk for layers above 1.
4. Open the PR. If the repo has a PR skill or template, use it with the
   explicit base. Otherwise use `gh pr create --base <parent>`. Mention the
   layer number and link the planning doc in the body.
5. If there is a tracker, move the sub-task to its review state.

## 4. Keep the stack healthy

- **A lower layer changed** (review fixes, amend, rebase): run
  `stack.sh restack <changed-branch>`. It rebases every layer above it. If
  a conflict stops it, resolve the conflict, run `git rebase --continue`,
  then run `stack.sh restack` again.
- **A layer's PR merged:** run `stack.sh sync-after-land <landed-branch>`.
  It updates the trunk, rebases the landed layer's children onto it,
  retargets their PRs with `gh`, and restacks deeper layers.
- **The trunk isn't `main`:** set `STACK_BASE=<trunk>` on every
  `stack.sh` call.
- **The plan changed:** update the planning doc in the current layer's PR.
  Don't let the plan and the stack drift apart.

## With intent docs

When the work touches units that have an `INTENT.md` (see the intent-docs
skill), or creates new ones, the two docs split the job:

- **The intent doc owns behavior.** `INTENT.md` and its `.feature`
  scenarios record what a unit does and the decisions behind that, and
  they last.
- **The planning doc owns delivery.** It records cut points, layer order
  and sequencing, and it describes one change.

If the two disagree about behavior, the intent doc wins.

Rules:

- **One layer carries the whole behavior change.** For each unit whose
  behavior a layer changes, the layer includes the Decisions row, the
  scenario, the contract test, and the code. Never cut an intent-only or
  test-only layer. It would split one change across PRs
  and leave a layer red.
- **A new unit lands in one layer.** That layer holds the `INTENT.md`, its
  scenarios, the public surface, the contract tests and the code. If that is too big to
  review, give the unit less behavior and add the rest in later layers.
  Each later layer brings its own intent edit.
- **Write behavior decisions into `INTENT.md`, not the plan.** Write them
  in the layer that makes them. The plan's Approach links to those
  Decisions rows instead of restating them. The plan's own decisions are
  delivery choices only, such as why the cuts fall where they do.
- **Leave open behavior open.** When the request doesn't settle a
  behavior choice (a formula, a cutoff, an edge case), list it under Open
  questions, or as a proposed Decisions row in the layer that will make
  it. Never state it as settled in the Approach. The plan can recommend
  an answer, but the user or the layer's intent edit decides it.
- **Resolve open questions before their layer ships.** A plan Open
  question becomes one of two things: a Decisions row, or an **Undecided**
  entry if rebuilds may answer it either way. Don't leave it open in the
  plan.
- **Use scenarios as "Done when".** For a layer that touches a unit,
  "Done when" lists the titles of the scenarios that must pass. Don't
  restate them.

## Scripts

The scripts need `bash` and `git`, plus `gh` for PR retargeting. On
Windows they run in Git Bash, which Claude Code's Bash tool already uses.
All state lives in git config; nothing is stored outside the repo.

Tests: `bash scripts/tests/run-tests.sh` (add `-v` for output). Each test
runs in a throwaway repo with a stubbed `gh`. If you change a helper,
update or add a test. If a script disagrees with this document, the
document wins: fix the script.

## Don't

- Bundle several layers into one PR, or split one layer across several PRs.
- Target the trunk for layers above 1.
- Merge, force-push the trunk, or move tracker items past review. Humans
  do that.
- Create or edit the parent ticket.
