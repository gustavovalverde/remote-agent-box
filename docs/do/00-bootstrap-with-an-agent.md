# Bootstrap a box with your coding agent

Your coding agent builds the box for you: it detects what it can, asks you for the rest, walks the `do/` pages in order, stops whenever only a human can act, and reports done only when every check passes.

## Goal

A working box built by your agent, with every decision recorded in your box notes and every check passing.

## Before you start

- Decide where the agent runs first. Either on a device that already has SSH access to the box, or on the box itself once [do/01](01-provision-the-host.md) is done.
- Create a private repo or folder for your box notes. Call it `<notes-dir>` below. Host facts, choices and exceptions go there and never into this repo.
- Point the agent at this repo's [AGENTS.md](../../AGENTS.md) first. It holds the operating rules the agent follows throughout. The agent reads this repo and never writes to it.
- Have the pages you will need open: [choose-your-setup](../decide/choose-your-setup.md) holds the choices the interview asks about, and [security-model](../learn/security-model.md#recording-an-exception) defines the exception record.

## Steps

### 1. Detect before you ask

The agent runs read-only detection on the machine it is on, and again on the box once it can reach it:

```bash
cat /etc/os-release
nproc; free -h
lsblk; df -h
command -v claude codex cursor-agent opencode
tailscale status
docker version
```

Each command may fail on a fresh machine; a failure is an answer ("not installed"). The agent asks only what detection cannot answer.

### 2. Interview the reader

The agent asks one question at a time and ties each to a section of [choose-your-setup](../decide/choose-your-setup.md):

1. Provider and hardware, or an existing box to adopt.
2. Mesh: which one, and whether an account exists.
3. Devices and their operating systems.
4. Harnesses, and for each one a subscription login or an API key.
5. Editor: Cursor, VS Code, Zed or none.
6. Whether you need phone access. A yes decides whether [do/08](08-optional-multiplexer.md) runs.
7. Docker and toolchains you need (Node, Rust, others).
8. Backup target.
9. Where box notes live.

The agent writes each answer into `choices.md` as it is given.

### 3. Create the box notes

In `<notes-dir>` the agent creates:

| File | Holds |
| --- | --- |
| `host.md` | Host facts from detection and provisioning (OS, disks, mesh address, user). |
| `choices.md` | The interview answers. |
| `exceptions.md` | One record per deliberate departure from a default, in the [exception record format](../learn/security-model.md#recording-an-exception). |
| `skills.txt` | Skills manifest, started from [examples/skills.txt](../../examples/skills.txt). |
| `claude-settings.fragment.json` | Started from [examples/claude-settings.fragment.json](../../examples/claude-settings.fragment.json). |
| `codex-config.fragment.toml` | Started from [examples/codex-config.fragment.toml](../../examples/codex-config.fragment.toml). |
| `AGENTS.md` | Your instructions core, shared by every harness. |
| `backup.md` | Backup target and schedule. |

Anything secret is recorded as a key name or a placeholder, never as a value. The agent commits the notes to a private location.

### 4. Walk the do/ pages in order

Run [01](01-provision-the-host.md), [02](02-lock-down-the-network.md), [03](03-install-toolchains.md), [04](04-install-agent-harnesses.md), [05](05-connect-clients.md), [06](06-sync-skills-plugins-mcp.md) and [07](07-back-up.md). Run [08](08-optional-multiplexer.md) only if you chose a multiplexer, and [09](09-coordinate-agents-with-herdr.md) only if you chose Herdr and want a lead agent supervising others.

For each page the agent reads Goal and Before you start, runs the Steps, runs every Check, records the results in `host.md`, and stops on any failure. A failed check is fixed until the original check passes; it is never skipped. The agent follows the operating rules in [AGENTS.md](../../AGENTS.md#if-you-are-building-a-box) throughout.

### 5. Stop at every hand-off

At each Needs a human item the agent says exactly what you must do and where, waits for your confirmation, and then runs the page's check. The consolidated list is under [Needs a human](#needs-a-human).

## Check

Done means all of these hold:

- Every do/ page's Check passes.
- A desktop app over SSH session runs a task on the box.
- The disconnect test in [do/05](05-connect-clients.md) passes.
- A restic restore sample in [do/07](07-back-up.md) matches.
- The box notes are committed to the private location:

```bash
git -C <notes-dir> status --porcelain   # prints nothing
git -C <notes-dir> log -1 --oneline     # shows the latest notes commit
```

## Needs a human

| Page | Hand-off |
| --- | --- |
| 01 | Order the box and install the OS; store the rescue console login. |
| 02 | Mesh login and mesh ACL edit; the off-mesh probe from a device not on the mesh. |
| 03 | `gh auth login`. |
| 04 | Harness logins (`claude`, `codex login`, `cursor-agent login`) for subscription logins. |
| 05 | Install the desktop apps and add the SSH host on each device and in your editor. |
| 06 | Trust prompts, MCP OAuth consent, Codex hook re-trust. |
| 07 | Create the backup storage account; store the restic password in a password manager. |
| 08 | Install a phone SSH app and key, and decide whether to keep `pane_history` (only if you chose a multiplexer). |
| 09 | Sign in to each harness CLI, and answer any blocked question (only if you run a lead agent in Herdr). |
