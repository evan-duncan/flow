# Flow

Personal coding-agent skills, packaged as a Claude Code and Codex plugin.

## Install

```
/plugin install flow --marketplace evan-duncan/flow
```

Codex: the plugin manifest is `.codex-plugin/plugin.json`. Or skip the plugin and copy `.agents/skills/*` into `~/.agents/skills/`. Codex, and other agents that support the [Agent Skills](https://agentskills.io) format, discover skills there.

## Skills

- `pair-programming`: two subagents (pragmatist and skeptic) pair through ping-pong TDD while the main agent coaches, runs the tests, and commits.
- `execution-plan`: break work into an ordered stack of small PRs, write the plan as layer 1, and deliver it layer by layer with stacked-branch helpers (`start`, `show`, `restack`, `sync-after-land`) and optional tracker sub-tasks.
- `intent-docs`: an `INTENT.md` plus runtime-agnostic Gherkin scenarios per module are the source of truth; code is regenerable from them, judged by contract tests that quote each scenario. Includes a coverage check and same-runtime / new-runtime regeneration drills. Pairs with `execution-plan`.
- `fat-marker`: draw the shape of the work on a local tldraw canvas (or hand over a photo), get it back as an image plus a text outline, confirm the agent's read-back, and plan from it. Pairs with `execution-plan`: the plan gets a Sketch section and each layer names the sketch parts it delivers.

## Legal

Copyright 2026 Evan Duncan

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
