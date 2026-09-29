# Coordinate several agents

You decide whether to run several coding agents through one unifying harness or to supervise each vendor's own CLI, and you get the operating model that keeps every subscription login intact. Claims carry a [status label](../../README.md#status-labels), as of 2026-09.

## The decision

**Default:** one lead agent, running the real native CLIs of the harnesses you already pay for inside [Herdr](../do/08-optional-multiplexer.md#option-b-herdr), with no harness, scheduler or task ledger of your own on top.

| Option | What it is | Cost of choosing it |
| --- | --- | --- |
| Supervise native CLIs (default) | A lead starts and prompts each vendor's own CLI in a pane | You handle each CLI's quirks; every login and meter stays native |
| Unifying harness | One tool (OpenCode, Pi, fx) calls every model itself | It must authenticate to each provider, and some routes are not subscription routes |
| Custom controller | Your own scheduler, task database or review protocol | You maintain it, and it duplicates what the lead and Herdr already do |

## Why native CLIs

Herdr starts the real CLI process in a terminal pane, so the vendor's own login, metering and terms apply. Herdr takes no provider login of its own and does not combine allowances or choose billing routes (Observed, as of 2026-09).

A unifying harness has to reach each provider itself, and each of the three below breaks at least one subscription meter (as of 2026-09):

- **OpenCode:** it cannot use a Claude subscription ([why](choose-your-setup.md#opencode-cannot-use-a-claude-subscription)).
- **Pi:** its providers page documents Claude only through API keys and tokens, with no Claude subscription route (Documented: [Pi providers](https://pi.dev/docs/latest/providers)), and Anthropic bars third parties from routing requests through subscription credentials ([subscription login](choose-your-setup.md#subscription-login)).
- **fx:** it supports Codex and Grok subscription logins, one active provider at a time, and has no Claude subscription provider (Documented: [fx authentication](https://fx.sh/docs/getting-started/authentication)).

These tools can still run inside a Herdr pane. The point is that they are not the way to spend a subscription you already hold.

Two billing traps apply to native CLIs too:

- `claude --bare` skips OAuth and keychain reads, so it cannot use a subscription; it needs an API key or a credential helper (Documented: [Claude Code headless](https://code.claude.com/docs/en/headless)). Plain `claude -p` can use the subscription login.
- Do not set `ANTHROPIC_API_KEY` in the environment Herdr runs in unless you want API billing. Claude Code uses a present key instead of the subscription login (Documented: [Claude Code with a Claude plan](https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan)). Check the active authentication before relying on a meter.

Which login each client bills is in [where billing comes from](access-modes.md#where-billing-comes-from).

## The operating model

**One lead.** One native agent owns planning, assignments, review requests and delivery. It must run inside a Herdr pane; a conversation in a desktop app is not the controller ([do/09](../do/09-coordinate-agents-with-herdr.md#1-start-the-lead-inside-herdr)).

**The smallest useful team.** A small, clear change stays with one agent. Add helpers only for slices that are independently useful. Extra agents duplicate context and consume more of a shared allowance, and two subscriptions do not make one allowance.

**Roles by capability, not by model name.**

| Role | Give it | Notes |
| --- | --- | --- |
| Lead | Ambiguous, tightly coupled or integration work | Keeps the hardest work itself |
| Worker | A well-specified, independent slice with explicit file ownership | Cheaper or faster tier where your harness offers one |
| Reviewer | The exact candidate, read-only | A different model family from the author for consequential work |

Cross-family review diversifies mistakes; it does not replace the repository's own checks. Which model fills a role is your choice and changes often, so this guide names none ([model pin keys](../do/06-sync-skills-plugins-mcp.md#7-pin-models-with-your-own-values)).

**Parallelize only independent ownership.** Two writers never share a checkout. Read-only helpers use sibling panes; concurrent writers get separate worktrees ([recipe](../do/09-coordinate-agents-with-herdr.md#4-parallel-writers-in-worktrees)). Worktrees isolate files, not credentials, services or ports.

**Completion needs evidence.** For Codex, Claude Code and Cursor, Herdr classifies state from the screen; the integrations supply session identity for restore, not lifecycle truth (Documented: [Herdr agents](https://herdr.dev/docs/agents/)). Trust dialogs have shown as idle (Observed, as of 2026-09), and a settled wait does not identify which turn finished. Accept a task as done only with a commit SHA, the changed paths and test output. Treat `blocked` and `unknown` as attention needed, never as success.

## What to leave out

- **No custom harness, scheduler or task ledger.** Herdr already provides panes, worktrees, agent start, prompt, wait and read commands, and a skill that teaches a lead to use them. A wrapper adds state to keep correct and hides the states you need to see. Add one only for a concrete gap that a real run exposed.
- **No unattended repair loop.** A failed check goes back to its author under the lead's eye; repeated failure is escalated to you.

## Deferred

Revisit these when a specific pain appears; none is a prerequisite.

- **Code Mode and Executor.** They are a tool layer (compose tool calls, share integrations and authentication across CLIs), not an agent layer. Claude Code already defers MCP tool discovery ([MCP tool search](https://code.claude.com/docs/en/mcp#scale-with-mcp-tool-search)), so the gain is unproven until duplicated integrations or very large tool catalogs hurt. Sandboxed code can still call powerful connected tools, so start with narrow read policies.
- **Another coding harness as the center.** Try it as a separate comparison, not as a layer under the lead.
- **Cloud errand bots.** They sit outside this topology.

## Next

Set up Herdr in [add a multiplexer](../do/08-optional-multiplexer.md), then follow [coordinate agents with Herdr](../do/09-coordinate-agents-with-herdr.md).
