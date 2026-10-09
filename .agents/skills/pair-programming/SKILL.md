---
name: pair-programming
description: Use when the user wants two agents to pair XP-style on a feature while the user monitors — "pair on this", "start a pairing session", "have two agents pair on <ticket>", "ping-pong TDD this plan", or asks for a driver and navigator agent pair. Not when the user wants to pair with you directly.
---

# Pair programming (coach protocol)

You are the **coach**. Two subagents, `pragmatist` and `skeptic`, pair on the work through ping-pong TDD. You relay every
message, run every test, and make every commit. The user monitors.
They get a digest line per task and get interrupted only on
exceptions.

Files: `assets/pair-brief.md` (send to each agent) and `assets/personalities.md`
(paste the agent's own section into its brief).

## Why these rules

- Agents claim tests pass when they do not. You run every test yourself.
  Never report a gate result you did not run.
- An unwatched coach invents results. Never write, predict, or
  summarize an agent's reply before it arrives. If the
  user asks for progress, say the agent is still running.
- Two agents talking directly can loop forever. You relay every message
  and cap every exchange.
- A navigator who reviews only at the end challenges the direction
  after it is built, when changing it means rework. Every turn opens
  with a forced `AGREE`, `CONCERN`, or `OBJECT`.
- An agent left alone settles spec ambiguities silently. Agents raise
  them as `ASK`, and the plan review runs before any code.
- An agent left alone edits files outside the task. Each turn gets a
  scope check against the task's expected file area.
- If agents commit, tests and code land in one commit and no red is
  ever seen. Only you commit, after you watch the red fail and the
  green pass.

## 1. Setup

1. **Normalize input** into a task list. Input can be a plan doc (use
   its tasks), a ticket (read it and derive tasks), or a prompt
   (derive tasks). Each task: `T<n>`, a title, acceptance criteria as a
   bullet list, and an expected file area (globs). If you cannot write
   acceptance criteria for a task, ask the user before you spawn
   anything.
2. **Project profile.** Read CLAUDE.md / AGENTS.md, the README, and the
   build manifest (`package.json`, `pyproject.toml`, `Makefile`,
   `Cargo.toml`, `go.mod`, `Gemfile`, ...). Record:
   - `SETUP_CMD`: install deps and any codegen a fresh checkout needs
     (e.g. `npm ci`, `uv sync`, `bundle install`, `go mod download`).
   - `TEST_CMD`: runs the given test files once and exits. Never a
     watch mode (`npm test` often is one; prefer `npx vitest run`,
     `npx jest`, `pytest`, `go test`, `cargo test`, `bundle exec rspec`).
   - `CHECK_CMDS`: the project's lint, typecheck, and format checks,
     as CI runs them.
   - `REPO_RULES`: a few lines of conventions the agents must follow,
     taken from CLAUDE.md / AGENTS.md and the codebase (package
     manager, layering rules, style rules). If CLAUDE.md or AGENTS.md
     covers them, write its name instead. If the user has no documented
     coding standards, use the
     [XP coding standard](https://en.wikipedia.org/wiki/Extreme_programming_practices#Coding_standard):
     write code that is self-documenting to the furthest degree
     possible. This reduces the need for code comments, which can lose
     synchrony with the code over time.

   If you cannot find a test command that runs single files, ask the
   user before you spawn anything.
3. **Worktree.** Never pair in the main checkout. Branch from the
   branch that holds the plan doc. That is the default branch only
   when the plan is merged. Run these from the main checkout root:
   ```bash
   git worktree add ../<repo>-pair-<slug> -b <branch> <base>
   ```
   Copy untracked local config the project needs to run tests (e.g.
   `.env*`) into the worktree. Then run `SETUP_CMD` inside it.
4. **Spawn** two general-purpose subagents with your host's subagent
   tool, named `pair: pragmatist` and `pair: skeptic`. Each must keep
   its context across messages: keep the ID or handle the tool returns
   and send every later message to that same agent. Load the tool
   first if your host defers it. If your host cannot message a
   subagent again, spawn a fresh one each turn and send it the
   brief again, plus that agent's past handoff notes and the rulings.
   If your host has no subagents, tell the user and stop. Each agent gets `assets/pair-brief.md` with every placeholder
   filled. `{{PERSONALITY}}` is the agent's own section from
   `assets/personalities.md`. Their first message is the plan review (the
   brief's "Before any code" section).
5. **Merge the reviews.** Wait for both replies. Settle
   questions both agents answered the same way as coach defaults. Any
   question they split on, or that changes acceptance criteria, goes
   to the user in one `ASK` exception. If the answer reframes the
   question instead of picking a side, ask a follow-up before any
   code. Send both agents the rulings, marked `HUMAN:`, and the
   defaults. Then tell the user: `Pairing on <n> tasks in <worktree>.`

## 2. Turn loop

Shell variables do not survive between Bash calls. Write every sha you
record into your own notes and use the literal value later.

**Task start.** Record the task-start sha (`git rev-parse HEAD`). The
skeptic drives first.

**First turn of a task** (and the turn after a `REFUSE`): send only the
task id, its acceptance criteria, and, after a refusal, the reason.
Expect `CHALLENGE: AGREE` and `GREEN: n/a`. Gate the red only.

**Every later turn:** send the incoming agent:
- the partner's handoff note,
- `git diff <sha at this agent's last handoff>..HEAD`,
- your gate result and the commit sha.

**Before each turn**, write down `git rev-parse HEAD`,
`git symbolic-ref HEAD`, and confirm that `git status --porcelain` is
empty. Every passed turn is committed, so each turn starts from a
clean tree.

Wait for the agent's reply. Then:

1. **Protocol checks.**
   - If the branch changed, run `git switch <recorded branch>`. If the
     sha moved, the agent committed: run
     `git reset --soft <recorded sha>`. Tell the agent the rule.
   - If the note has `ASK:`, pause before the gate. Raise the ASK
     exception, send the `HUMAN:` answer to the same agent, and let it
     finish the turn. This does not count as a gate failure.
2. **Challenge.** Log every `CONCERN` with its task id. On `OBJECT`,
   go to section 3.
3. **Gate.** Run every test file touched in this task, in one run:
   `<TEST_CMD> <files> > <log> 2>&1`, then read the per-test failure
   lines and the summary. Tests outside the touched files are checked
   at Finish.
   - **Green:** the partner's red test passes, and so does every other
     test except the new red.
   - **Red:** exactly one test fails: the one named in `RED:`. Its
     failure message matches the `expected to fail because` reason.
   - **Wrong reason:** a non-zero exit code does not prove a red. If
     the run collected no tests, could not find the file, hit an
     import, compile, or syntax error, or shows no failure line for the
     named test, the test never ran. That is a gate failure, not a red.
   - **DONE turn:** everything passes.
4. **Gate failure.** Send the test output back to the same agent and
   say which check failed. Count failures per turn. On the third
   failure, raise an exception.
5. **Scope check.** Compare `git status --porcelain` against the task's
   expected file area. A file outside the area, or behavior that is
   not in the acceptance criteria, is scope drift. Raise an exception.
6. **Commit** the whole turn once the gate passes: the green, the
   coverage, and the new red together. The red usually lives in the
   same file as the green tests, so it cannot be split out. Each commit
   carries at most one known-failing test, and the message names it:
   ```bash
   git add -A && git commit -m "<type>(<scope>): <what went green>; red: <next red>"
   ```
   Append the commit attribution trailer your session uses, if any. If
   the repo has commit hooks that run the test suite, they will reject
   the known red: commit with `--no-verify` only after asking the user
   once at setup.
   A first turn commits as `test(<scope>): red: <next red>`. A DONE
   turn commits with no `red:` clause and no failing test.
7. **Progress check.** A cycle is one turn by each agent. If two cycles
   pass and no acceptance criterion moved from unmet to met, that is a
   stall. Raise an exception.
8. **Hand off** to the other agent.

## 3. Read-only replies: OBJECT, rebuttal, sign-off

A challenge that ends in `OBJECT`, a rebuttal, and a sign-off are all
read-only. After each of these replies, check `git status --porcelain`.
If it is not empty, the agent edited files. Run
`git checkout -- . && git clean -fd` yourself, because agents may not
use those commands, then tell the agent the rule.

**OBJECT flow:**
1. Send the objection, with the objecting agent's reasoning, to the
   other agent as a rebuttal request.
2. Send the rebuttal back to the objector: "Withdraw, or hold?"
3. If the objector withdraws, it continues its normal turn. If both
   agents settle on a revised direction, log the outcome. The objector
   then replaces the partner's red with one that fits the revised
   direction, gated as a first turn.
4. If the objection still stands, raise an exception. Show both
   positions, then your recommendation in one line.

There is no second rebuttal round.

## 4. Task done

When a handoff has `DONE: T<n>`:
1. Gate it as a DONE turn and commit it.
2. Send the other agent `git diff <task-start sha>..HEAD` plus the
   acceptance criteria, as a sign-off request.
3. On `REFUSE`, the claimer writes a red for the unmet criterion the
   refusal names. That turn is gated as a first turn.
4. On `SIGN-OFF`, post the digest line. Do not wait for a reply.
   Then start the next task.

Digest format:
```
✓ T<n> <title> — <cycles> cycles, <k> CONCERNs, <objections or "no objections">
```

## 5. Exceptions (stop the pair, ask the user)

Raise one of these by pausing the loop:

| Trigger | What you show the user |
|---|---|
| OBJECT still stands after rebuttal | both positions plus your one-line recommendation |
| Gate fails 3 times on one turn | the check, the last test output tail, the agent's last note |
| Scope drift | the files or behavior, and the acceptance criteria they exceed |
| `ASK:` from an agent | the question, verbatim, and who asked it |
| Stall (2 cycles, no criterion moved) | the criteria still open and the last two handoff notes |

Send the user's answer to both agents, marked `HUMAN:`. Then resume.

## 6. Finish

1. In the worktree, run every `CHECK_CMDS` entry and
   `<TEST_CMD> <all touched test files>`. A failure goes back to the
   pair as a new task, `T<n+1> fix checks`.
2. Post the session summary: the task digests, every logged CONCERN,
   every OBJECT and how it was resolved, and every exception and the
   user's answer.
3. Offer to push the branch and open a PR. Never merge.
4. Leave the agents idle. Do not send them further messages.
