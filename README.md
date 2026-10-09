# Flow

Personal Claude Code skills, packaged as a plugin.

## Install

```
/plugin install flow --marketplace evan-duncan/flow
```

Codex: the plugin manifest is `.codex-plugin/plugin.json`. Or skip the plugin and copy `.agents/skills/*` into `~/.agents/skills/`. Codex, and other agents that support the [Agent Skills](https://agentskills.io) format, discover skills there. `pair-programming` uses Claude Code's subagent tools, so it only works in Claude Code.

## Skills

- `pair-programming`: two subagents (pragmatist and skeptic) pair through ping-pong TDD while Claude coaches, runs the tests, and commits.
- `execution-plan`: break work into an ordered stack of small PRs, write the plan as layer 1, and deliver it layer by layer with stacked-branch helpers (`start`, `show`, `restack`, `sync-after-land`) and optional tracker sub-tasks.
- `intent-docs`: an `INTENT.md` plus runtime-agnostic Gherkin scenarios per module are the source of truth; code is regenerable from them, judged by contract tests that quote each scenario. Includes a coverage check and same-runtime / new-runtime regeneration drills. Pairs with `execution-plan`.
- `fat-marker`: draw the shape of the work on a local tldraw canvas (or hand over a photo), get it back as an image plus a text outline, confirm the agent's read-back, and plan from it. Pairs with `execution-plan`: the plan gets a Sketch section and each layer names the sketch parts it delivers.
