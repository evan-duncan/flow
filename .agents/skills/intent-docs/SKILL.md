---
name: intent-docs
description: Use when reading, writing or editing any INTENT.md; when changing behavior or code in a directory that contains an INTENT.md; or when setting up a module so its code can be regenerated from intent.
---

# Intent docs

An `INTENT.md` is the source of truth for the unit (module, package,
feature directory) it sits in. The unit's implementation is a build
output. An agent should be able to delete it and regenerate it from three
things: the intent doc, the repo's conventions, and the contract tests.

## Durable and disposable files

Every unit has three durable files. Everything else in it is disposable:

| File | Role |
| --- | --- |
| `INTENT.md` | What the unit does and why. |
| Public surface | The only module that code outside the unit imports. Defines the unit's API. |
| Contract tests | Test behavior through the public surface only. They judge any rebuild. |
| Everything else | Disposable, unit tests included. A rebuild may lay it out however it likes. |

Lay the files out so a rebuild has one obvious thing to delete: a single
directory of disposable code. That directory never contains a durable
file except `INTENT.md`. Follow the repo's existing layout if it has one.
Otherwise pick the pattern that fits the language:

| Language | Public surface | Disposable code | Contract tests |
| --- | --- | --- | --- |
| TypeScript / JavaScript | `<parent>/<name>.ts`, beside the directory (a named file, not an `index.ts` barrel) | `<parent>/<name>/` | `<parent>/<name>.contract.test.ts` |
| Rust | `<parent>/<name>.rs`, beside the directory | `<parent>/<name>/` | `tests/<name>_contract.rs` |
| Go | `<name>/<name>.go` | `<name>/internal/` | `<name>/contract_test.go`, in `package <name>_test` |
| Python | `<name>/__init__.py` | `<name>/_impl/` | `tests/contract/test_<name>.py` |

Name the public surface and contract test paths in the intent doc (see
**Public surface** and **Acceptance** below), so a rebuild knows what to
keep.

## Changing behavior

Do these steps in this order, in the same change. Never split them across
commits or PRs that ship separately:

1. Edit `INTENT.md`. Write the behavior rule. Add a row to **Decisions**
   that names the choice, the alternative you rejected, and why. A
   behavior change without a decision row is incomplete.
2. Add or update a contract test that fails on the old behavior.
3. Change the code.

If the change raises a question you can't answer, list it under
**Undecided**. Don't choose silently.

A change that alters no behavior (a refactor) leaves `INTENT.md` and the
contract tests unchanged. If either has to change, the change alters
behavior.

## Writing an INTENT.md

Sections, in order:

1. **Purpose**: the problem, in the user's terms.
2. **Glossary**: the terms the rest of the doc relies on.
3. **Behavior**: observable rules. State each one as what a caller, user
   or report sees. Example: "Served at `/api/x`. Only admins may call it."
4. **Public surface**: the public-surface file's path, what it exports,
   and what each export is for, in prose.
5. **Decisions**: a table of decision, rejected alternative, and why.
6. **Undecided**: questions a rebuild may answer either way. Omit the
   section when it's empty.
7. **Non-goals**.
8. **Acceptance**: the contract test files a rebuild must pass unchanged.

Every sentence describes behavior or a contract, including each
decision's "why". The only file paths are the unit's durable files. Name
anything else by what it is ("the shared palette list"). Don't say where
or how something is enforced, such as "checked in the router" or "the
request schema rejects it". Leave that to the code. Don't include code
blocks or type signatures. Do include error names, messages, routes,
events and table names, because callers see them.

Title the doc with the unit's name alone (`# Invoices`). Put the line
`Follows the intent-docs skill.` under the title.

## Contract tests

- Import only the public surface, plus dependencies outside the unit: a
  DB client, tables or schemas the unit doesn't own, config.
- Write one test per Behavior rule and one per Decision.
- Fake only what lies outside the unit, such as a third-party API or a
  remote service.
- Use the repo's normal test runner and naming. The contract tests only
  need to be identifiable, so a rebuild can hide and restore them.

## Regeneration drill

The drill proves the doc is sufficient:

1. Delete the unit's disposable code. Hide the contract tests.
2. A fresh agent rebuilds the unit from `INTENT.md`, the public surface
   and the repo. It has no access to git history.
3. Restore the contract tests and run the Acceptance list.
4. Each failure, and each question the agent reports, becomes an edit to
   the intent doc.
