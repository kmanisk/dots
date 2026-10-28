# ChatGPT Remote Coding Control Plane

This system makes ChatGPT Web + Desktop Commander behave like a persistent remote coding workspace while the laptop remains at home.

## Architecture

- ChatGPT Project instructions define the workflow for each workspace.
- Desktop Commander reads and changes the live machine.
- `/home/onyx/.local/share/agent/GLOBAL.md` stores durable cross-chat rules.
- `/home/onyx/Projects/AGENTS.md` stores coding-wide rules.
- Each repo `AGENTS.md` stores repo-specific rules.
- Each repo `HANDOFF.md` stores current task/session state.
- Git is the code source of truth.
- `/home/onyx/docs` is the system documentation source of truth.

## Commands

### `agent-context <project>`

Primary bootstrap command for a new ChatGPT conversation. It automatically refreshes live machine state and prints:

- current OS/kernel/session/display/GPU mode
- Desktop Commander service state
- shared rules
- coding-wide rules
- project rules
- project handoff
- branch, commit, status and origin
- standard validation commands

Examples:

```sh
agent-context ytui
agent-context watchparty
agent-context tele-sixel
agent-context system
```

### `agent-refresh`

Regenerates `~/.local/share/agent/environment.json` from the live system. Normally it does not need to be called directly because `agent-context` refreshes automatically.

### `agent-check <project>`

Runs the standard validation sequence registered for that project and stops at the first failure.

## Shared state

`~/.local/share/agent/projects.json` maps short project names to local paths, stacks and validation commands.

`~/.local/share/agent/environment.json` is generated runtime state and must not be treated as static configuration.

## Rule propagation

When a durable rule is established, write it to the narrowest correct scope:

1. Cross-project/system-wide agent rule: `~/.local/share/agent/GLOBAL.md`
2. Coding-wide rule: `~/Projects/AGENTS.md`
3. Repo-specific rule: `<repo>/AGENTS.md`
4. Temporary/current-task state: `<repo>/HANDOFF.md`

Every new ChatGPT coding conversation should begin by running `agent-context <project>`, so changes made by another chat become visible without copying conversation history.

## Remote safety

Remote actions are intentionally separate from local code changes. Do not commit, push, force-push, update/open a PR, merge, publish or deploy unless the user explicitly requests that remote action.
