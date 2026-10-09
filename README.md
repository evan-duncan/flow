# Flow

Personal Claude Code skills, packaged as a plugin.

## Install

```
/plugin install flow --marketplace evan-duncan/flow
```

## Skills

- `pair-programming`: two subagents (pragmatist and skeptic) pair through ping-pong TDD while Claude coaches, runs the tests, and commits.
- `execution-plan`: break work into an ordered stack of small PRs, write the plan as layer 1, and deliver it layer by layer with stacked-branch helpers (`start`, `show`, `restack`, `sync-after-land`) and optional tracker sub-tasks.
- `intent-docs`: an `INTENT.md` per module is the source of truth; code is regenerable from it plus contract tests. Language-agnostic layout, behavior-change ordering, and a regeneration drill. Pairs with `execution-plan`.
