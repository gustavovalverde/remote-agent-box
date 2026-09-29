# Coordinate agents with Herdr

You get recipes for running one lead agent that supervises native harness CLIs in Herdr panes, with every harness keeping its own login. Vendor facts carry a [status label](../../README.md#status-labels), as of 2026-09. The reasoning is in [coordinate agents](../decide/coordinate-agents.md).

## Goal

A lead agent inside a Herdr pane delegates bounded work to native CLIs, verifies results with evidence, and hands decisions it cannot make back to you.

## Before you start

- [do/08](08-optional-multiplexer.md#option-b-herdr) Herdr section is done: Herdr installed, integrations installed for the harnesses you use, the `herdr` skill installed, the config baseline applied.
- Each harness CLI is signed in on the box ([do/04](04-install-agent-harnesses.md)), and its repository trust prompt is accepted for the repository you will use.
- `ANTHROPIC_API_KEY` is not set in the environment Herdr runs in, unless you want API billing.
- `jq` is installed (the recipes read JSON from Herdr).
- Every command below runs inside the coordinating Herdr pane. `herdr agent` is a Herdr subcommand; it is not Cursor's standalone `agent` executable.

## Steps

### 1. Start the lead inside Herdr

From an outer terminal, change to the repository and run `herdr`, or attach with `herdr session attach <session>`. Do not start a nested Herdr TUI in a pane. In a shell pane, verify the context:

```bash
test "${HERDR_ENV:-}" = 1 && echo in-herdr
herdr status
herdr integration status
```

Stop if `HERDR_ENV` is not `1`: a conversation in a desktop app is not inside Herdr, and the skill refuses to control panes from outside. Then start one native CLI as the lead, for example `claude --model <model> --effort <effort>` or `codex --model <model>`, with your usual approval settings. Unrestricted execution does not fix missing pane context.

Ask the lead to run `test "${HERDR_ENV:-}" = 1` and `herdr pane current --current` in its own tool shell. The pane it reports must be its own. It can then name itself:

```bash
herdr agent rename "$HERDR_PANE_ID" task-lead
```

If the tool shell lacks the variables, fix the launch; do not carry on as if the lead were inside Herdr.

Observed (Codex codex-cli 0.155.1, as of 2026-09): Codex did not pass the `HERDR_*` variables into its tool shell, and forwarding them through `shell_environment_policy.set` fixed it. Claude Code inherited them normally. Run this only in the verified pane, with that pane's own values:

```bash
codex --model <model> \
  -c "shell_environment_policy.set.HERDR_ENV=\"$HERDR_ENV\"" \
  -c "shell_environment_policy.set.HERDR_SESSION=\"$HERDR_SESSION\"" \
  -c "shell_environment_policy.set.HERDR_SOCKET_PATH=\"$HERDR_SOCKET_PATH\"" \
  -c "shell_environment_policy.set.HERDR_PANE_ID=\"$HERDR_PANE_ID\"" \
  -c "shell_environment_policy.set.HERDR_TAB_ID=\"$HERDR_TAB_ID\"" \
  -c "shell_environment_policy.set.HERDR_WORKSPACE_ID=\"$HERDR_WORKSPACE_ID\""
```

Treat this as a per-launch workaround, not global config, and never copy one pane's ids into another agent. Re-test without it after each Codex update.

### 2. Give the lead a bounded task

Replace the bracketed fields:

```text
Deliver [outcome] in [repository]. Acceptance criteria: [observable behavior and checks].
Stay within [scope and authorization]. Use the Herdr skill directly and remain the sole
coordinator. Delegate only independent slices, each with explicit file ownership or a
requested worktree. Give each test pane one owner while its command runs. Ask for an
independent review of the exact candidate from a different model family if the change
warrants it. Inspect timed-out work before retrying. Escalate blocked questions to me
without answering them. Report changed files, checks, unresolved issues and any decision
I must make. Do not create a harness or custom workflow.
```

Agree a short interface contract before workers touch a shared boundary. Skip large contract documents.

### 3. Coordinate through native commands

Start a reviewer or worker in a sibling pane without taking focus. Choose `right` or `down` to suit the layout:

```bash
split=$(herdr pane split --current --direction right --cwd "$PWD" --no-focus)
pane=$(printf '%s' "$split" | jq -er '.result.pane.pane_id')
herdr agent start reviewer --kind claude --pane "$pane" -- --model <model>
herdr agent get reviewer
herdr agent read reviewer --source visible
```

`--kind` also accepts `codex` and `cursor`. Stop on any failed command or unexpected startup screen, and confirm the composer is ready before sending work. Trust dialogs can read as idle (Observed, as of 2026-09), so look at the pane, not only the state.

Give each worker its objective, owned files, acceptance checks and scope limits. Dispatch independent workers before waiting on any of them. To prompt an idle agent:

```bash
herdr agent prompt reviewer "<exact candidate, scope, acceptance criteria>" --wait --timeout 120000
herdr agent read reviewer --source recent-unwrapped --lines 120
```

Use `herdr agent wait reviewer --timeout 120000` for work already running. A wait observes lifecycle state; it does not identify one task's result. Read the response and check the deliverable before the next step. If a completed reply is missing from the read, read more lines; if still missing, ask the agent to write its result to a temporary Markdown file. Semantics: [agent automation](https://herdr.dev/docs/agent-automation/).

### 4. Parallel writers in worktrees

Two writers never share a checkout. Give each its own worktree and file set; the lead keeps the integration checkout. Read-only helpers do not need one.

Inspect `git status` and existing worktrees first, and preserve unrelated changes. Then, with a clean, committed repository:

```bash
repo=<repo-path>
git -C "$repo" status --short
base=$(git -C "$repo" rev-parse HEAD)
herdr worktree create --cwd "$repo" --branch task/<a> --base "$base" --path <path-a> --label <a> --no-focus
herdr worktree create --cwd "$repo" --branch task/<b> --base "$base" --path <path-b> --label <b> --no-focus
```

Read each response before continuing; it returned `.result.root_pane.pane_id` and `.result.workspace.workspace_id` (Observed in Herdr 0.9.x, as of 2026-09). Start each worker with `herdr agent start ... --pane <root pane id>` and confirm its reported cwd matches its assigned checkout. Send both assignments before waiting.

Require each worker to return its commit SHA, changed paths, targeted checks and open concerns. Before integrating, confirm:

- The integration checkout is unchanged and clean.
- Each worker checkout is clean, and its commit touches only its assigned paths.
- No worker copied the other's code to make combined tests pass.
- The lead integrates the exact accepted SHAs, not moving branch names.

The lead reviews each diff, integrates with the repository's normal procedure into the authorized integration branch, and reruns the combined checks. Herdr creates checkouts; it does not review or authorize merges. Worktrees share Git metadata and do not isolate credentials, services or ports. Closing a Herdr workspace does not remove its worktree, and neither is an automatic cleanup step. See [worktrees](https://herdr.dev/docs/cli-reference/#worktrees).

### 5. Run verification in a dedicated pane

Use an ordinary shell pane for tests, not another model session. Give it one owner until the command finishes and its result is read. A fresh marker proves this run finished, and the exit code proves whether it passed:

```bash
split=$(herdr pane split --current --direction down --cwd "$PWD" --no-focus)
test_pane=$(printf '%s' "$split" | jq -er '.result.pane.pane_id')
id=$(python3 -c 'import uuid; print(uuid.uuid4().hex)')
herdr pane run "$test_pane" "<test command>; rc=\$?; printf '\\nCHECK_${id} exit=%s\\n' \"\$rc\""
herdr pane wait-output "$test_pane" --source recent-unwrapped --regex "^CHECK_${id} exit=[0-9]+$" --timeout 120000
herdr pane read "$test_pane" --source recent-unwrapped --lines 120
```

Run each step only after the previous one succeeds. A matched wait means the marker appeared, not that tests passed: read the exit value, and confirm the log shows the expected suite ran. The anchored regex skips the echoed command, and a fresh id skips old output. Never match a generic word such as `passed` or reuse an id.

After a failure, the lead sends the concrete failure to the original author, waits for the fix, and reruns in the same pane with a new id.

### 6. Review and finish

Give the reviewer the exact commit (or a clearly identified uncommitted diff), the acceptance criteria and the test evidence, read-only. A plain response is enough. The lead assesses findings, returns concrete fixes to the original author and reruns the affected checks. Ask for a bounded re-review when needed. Escalate an unresolved scope decision or a repeated failed approach; do not build an automatic repair loop.

Review completion is not test success, and local tests are not hosted verification. The lead finishes with the source identity, checks run, known limits and any delivery step you still must authorize. Commit, push, merge and deploy each stay subject to your authorization and the repository's gates. Leave useful panes open, and do not close unrelated ones.

### 7. Escalate a blocked question

`blocked` means Herdr recognized an approval or question screen. It is not completion, and it is not permission to answer. From the lead's pane:

```bash
herdr agent get <worker>
herdr agent read <worker> --source visible
herdr agent explain <worker> --json
```

Record the pane, the exact question, its options and the unfinished work. The lead ends its turn with a short needs-input message to you and does not pick a default. If the visible screen contradicts the reported state, report the mismatch.

After you decide, inspect the actual dialog and send only keys it shows (`herdr agent send-keys <worker> enter` selects the highlighted option in a question dialog). Never send a precomputed key sequence across several screens. Then have the lead confirm the worker's identity, wait, and read the result without re-prompting:

```bash
herdr agent get <worker>
herdr agent wait <worker> --timeout 120000
herdr agent read <worker> --source recent-unwrapped --lines 120
```

An already-finished task makes the wait return at once; check the deliverable. A changed native session id needs reconciliation, not an assumption that the task survived.

### 8. Detach and return

To leave a running task, detach the client: `ctrl+b`, then `q`. This does not stop the server or its panes. Reattach from an outer terminal:

```bash
herdr session attach <session>
```

Do not use `herdr server stop`, `herdr session stop`, an update or a process kill as a substitute; they end pane processes. Before sending any follow-up, read the original worker's output. If it finished while you were away, use its result instead of resending. If it is blocked, follow step 7. Viewport size and "seen" badges change on attach; compare pane and agent identity and real output before deciding anything restarted. Detach, server restart and agent restore are different events ([what persistence means](08-optional-multiplexer.md#what-persistence-means)); restore a session only after verifying its model, permissions, working directory, login and task.

### 9. Notifications are not acknowledgments

With `ui.toast.delivery = "herdr"`, an attached client shows toasts for finished and needs-input agents without moving focus. A toast names the agent kind and workspace (Observed, as of 2026-09), so inspect the pane to find the exact agent. With default bindings, `ctrl+b` then `o` opens the visible notification's target; it does not answer anything. A vanished toast is not an acknowledgment, and `herdr notification show` only displays text. Delivery to a detached client, desktop or phone is Unverified. Use the lead's end-of-turn message as the durable record of a pending decision.

### 10. Recover from a timeout without repeating work

If `herdr pane wait-output` times out, read the same pane and inspect the running command. Wait again for the original marker; do not `pane run` a second copy because the first wait expired. For `agent prompt`, a timeout or `agent_prompt_stalled` can occur after the input was delivered, so read the agent's output before resending.

### 11. Diagnose

```bash
herdr status                          # server and client versions, runtime
herdr agent list                      # agents, ids and states
herdr agent explain <target> --json   # matched rule and evidence behind a state
herdr integration status              # per-harness integration and version
```

| Observation | Action |
| --- | --- |
| State idle but a dialog is on screen | Read `--source visible` and run `agent explain`; resolve the real UI before prompting |
| Codex hook-review notice | Inspect it; Escape dismissed the observed notice without trusting hooks. Verify the composer after |
| `HERDR_*` missing in Codex tool shell | Relaunch with this pane's variables ([step 1](#1-start-the-lead-inside-herdr)) |
| Timeout or `agent_prompt_stalled` | Inspect state and output; the input may have arrived |
| `unknown`, `blocked` or `agent_not_idle` | Attention needed, not completion; read `--source visible` while active |
| Client and server versions differ after an update | Check `herdr status` before using a new feature |

## Check

Run this after step 1 and whenever a CLI or Herdr updates:

```bash
test "${HERDR_ENV:-}" = 1 && echo in-herdr    # prints in-herdr
herdr status                                   # server running
herdr integration status                       # your harnesses current
herdr agent list                               # includes the lead
```

Then run one end-to-end task: a lead, one worker in its own pane, and one read-only review. It passes when the result carries a commit SHA, changed paths and test output that you confirmed yourself, and no login prompt or API charge appeared.

## Needs a human

- Signing in to each harness CLI and accepting its repository trust prompt.
- Every decision a blocked worker asks for, and every commit, push, merge or deploy the task does not already authorize.
- Reading your usage meters before and after a large run; Herdr does not combine or choose allowances.
