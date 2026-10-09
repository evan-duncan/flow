# Flow

Personal Claude Code skills, packaged as a plugin.

## Install

```
/plugin install flow --marketplace evan-duncan/flow
```

## Skills

- `pair-programming`: two subagents (pragmatist and skeptic) pair through ping-pong TDD while Claude coaches, runs the tests, and commits.
- `execution-plan`: break work into an ordered stack of small PRs, write the plan as layer 1, and deliver it layer by layer with stacked-branch helpers (`start`, `show`, `restack`, `sync-after-land`) and optional tracker sub-tasks.
- `intent-docs`: an `INTENT.md` plus runtime-agnostic Gherkin scenarios per module are the source of truth; code is regenerable from them, judged by contract tests that quote each scenario. Includes a coverage check and same-runtime / new-runtime regeneration drills. Pairs with `execution-plan`.
