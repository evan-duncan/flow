---
name: intent-docs
description: Use when reading, writing or editing any INTENT.md or its .feature scenarios; when changing behavior or code in a directory that contains an INTENT.md; or when setting up a module so its code can be regenerated from intent.
---

# Intent docs

An `INTENT.md` and its `.feature` files are the source of truth for the
unit (module, package, feature directory) they sit in:

- **`INTENT.md`** says why the unit exists and why it behaves as it does.
- **The `.feature` files** say what must be true, as Gherkin scenarios.
  They are written for agents and humans to read, not for a Gherkin
  runner. They don't depend on any runtime.

The unit's implementation is a build output. An agent should be able to
delete it and regenerate it, in this runtime or another one, from four
things: the intent doc, the scenarios, the repo's conventions, and the
contract tests.

## Durable and disposable files

| File | Role |
| --- | --- |
| `INTENT.md` | Why the unit exists, its vocabulary, and its decisions. |
| `*.feature` | What must be true. Runtime-agnostic. |
| Public surface | The only module that code outside the unit imports. Defines the unit's API. |
| Contract tests | Runtime-specific tests. Each one checks one or more scenarios through the public surface and quotes their titles. |
| Everything else | Disposable, unit tests included. A rebuild may lay it out however it likes. |

The `.feature` files sit beside `INTENT.md`. Lay the rest out so a rebuild
has one obvious thing to delete: a single directory of disposable code.
That directory never contains a durable file except `INTENT.md` and the
`.feature` files. Follow the repo's existing layout if it has one.
Otherwise pick the pattern that fits the language:

| Language | Public surface | Disposable code | Contract tests |
| --- | --- | --- | --- |
| TypeScript / JavaScript | `<parent>/<name>.ts`, beside the directory (a named file, not an `index.ts` barrel) | `<parent>/<name>/` | `<parent>/<name>.contract.test.ts` |
| Rust | `<parent>/<name>.rs`, beside the directory | `<parent>/<name>/` | `tests/<name>_contract.rs` |
| Go | `<name>/<name>.go` | `<name>/internal/` | `<name>/contract_test.go`, in `package <name>_test` |
| Python | `<name>/__init__.py` | `<name>/_impl/` | `tests/contract/test_<name>.py` |

## Changing behavior

Do these steps in this order, in the same change. Never split them across
commits or PRs that ship separately:

1. Edit `INTENT.md`. Add a row to **Decisions** that names the choice, the
   alternative you rejected, and why. A behavior change without a
   decision row is incomplete. If the new decision replaces an earlier
   one, keep the old row and start its decision text with
   `Superseded by decision-N.` Don't edit the old row in place: its id is
   the history of why the behavior changed.
2. Add or edit the scenario that states the new behavior. Tag it with the
   decision's id.
3. Add or update a contract test that quotes the scenario's title. Check
   that it fails on the old behavior.
4. Change the code.

If the change raises a question you can't answer, list it under
**Undecided**. Don't choose silently.

A change that alters no behavior (a refactor) leaves `INTENT.md`, the
scenarios and the contract tests unchanged. If any of them has to change,
the change alters behavior.

## Writing scenarios

- Group the scenarios into one or more `.feature` files by area of
  behavior. Group related scenarios under a `Rule:` that states the rule
  in one line.
- Write steps as what a caller, user or report observes, in Glossary
  terms. For example: "Given an admin", "When they request the invoice
  list", "Then the response is `403 Forbidden`". Don't name internals,
  and don't describe UI mechanics unless the UI is the public surface.
- Do include caller-visible values: routes, error names, messages,
  events, table names.
- Give each scenario one behavior and a title that's unique within the
  unit. The title is the scenario's id: contract tests quote it.
  Renaming a scenario means updating the tests that quote it.
- Use `Scenario Outline` with an `Examples` table for edge cases and
  boundaries.
- Tag each scenario that a decision drives with that decision's id
  (`@decision-3`). Every decision has at least one tagged scenario,
  except superseded ones, which tag none.
- Never assert anything listed under **Undecided**.
- No step definitions, and never add a BDD framework (Cucumber, behave,
  SpecFlow, …) to run the scenarios. Gherkin is only the format of the
  contract. The Given/When/Then wording is for the reader. The contract
  tests, in the repo's normal test runner, decide how to check it.
- If the repo already runs `.feature` files through a BDD framework, keep
  intent scenarios out of that framework's search paths, or the scenarios
  will fail as undefined steps.

## Writing an INTENT.md

Sections, in order:

1. **Purpose**: the problem, in the user's terms. It is the only summary;
   the doc never restates the scenarios.
2. **Glossary**: the terms the scenarios and the rest of the doc rely on.
3. **Public surface**: the public-surface file's path, what it exports,
   and what each export is for, in prose.
4. **Decisions**: a table of id (`decision-1`, `decision-2`, …), decision,
   rejected alternative, and why. Never reuse an id. A replaced decision
   stays in the table, marked `Superseded by decision-N.`
5. **Undecided**: questions a rebuild may answer either way. Omit the
   section when it's empty.
6. **Non-goals**.
7. **Acceptance**: the `.feature` files, then the contract test files a
   rebuild in this runtime must pass unchanged.

Every sentence describes behavior or a contract, including each
decision's "why". The only file paths are the unit's durable files. Name
anything else by what it is ("the shared palette list"). Don't say where
or how something is enforced, such as "checked in the router" or "the
request schema rejects it". Leave that to the code. Don't include code
blocks or type signatures.

Title the doc with the unit's name alone (`# Invoices`). Put the line
`Follows the intent-docs skill.` under the title.

## Contract tests

- Import only the public surface, plus dependencies outside the unit: a
  DB client, tables or schemas the unit doesn't own, config.
- Quote the scenario's title verbatim in the test name. If the runner
  can't hold it, put it in a comment on the test. For a
  `Scenario Outline`, cover every `Examples` row.
- Fake only what lies outside the unit, such as a third-party API or a
  remote service.
- Use the repo's normal test runner and naming.
- **Coverage:** every scenario must have a contract test that quotes its
  title. Run this check after any scenario or contract test change. It
  prints each scenario with no contract test:

  ```bash
  grep -hE '^[[:space:]]*(Scenario( Outline| Template)?|Example):' <unit-dir>/*.feature \
    | sed -E 's/^[[:space:]]*(Scenario( Outline| Template)?|Example):[[:space:]]*//' \
    | while IFS= read -r t; do grep -rqF -- "$t" <contract-tests> || echo "uncovered: $t"; done
  ```

## Regeneration drill

The drill proves the intent doc and the scenarios are enough to rebuild
the unit. The agent that writes the code never writes or edits the tests
that judge it.

**Same runtime:**

1. Delete the unit's disposable code. Hide the contract tests.
2. A fresh agent rebuilds the unit from `INTENT.md`, the scenarios, the
   public surface and the repo. It has no access to git history.
3. Restore the contract tests. Run them and the coverage check.

**New runtime:**

1. A verifier agent writes the contract tests from `INTENT.md` and the
   scenarios alone. The coverage check must pass.
2. A different agent builds the unit until those tests pass. It doesn't
   edit the tests. If a test looks wrong, it reports that to the user.

In both cases, each failure, each ambiguity and each question an agent
reports becomes an edit to `INTENT.md` or the scenarios. Don't patch
around it in the code or the tests.
