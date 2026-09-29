# Connect your clients

By the end of this page, every device reaches the box by one SSH alias, the Claude desktop app and the Codex app run sessions on the box, an editor over SSH works, and you have proven on your own box that agents survive closing the client.

## Goal

Desktop apps over SSH, an editor over SSH and the CLI over SSH all work against the box, with disconnect survival verified.

## Before you start

- [Lock down the network](02-lock-down-the-network.md) and [Install agent harnesses](04-install-agent-harnesses.md) are done.
- Each device is on the mesh and has an SSH key whose public half is authorized on the box.
- `codex` is installed and signed in on the box if you use the Codex app.
- You know which mode you want per device; see [Access modes](../decide/access-modes.md).

## Steps

### 1. Add the box to each device's SSH config

Copy [examples/ssh-config](../../examples/ssh-config) into `~/.ssh/config` on each device and replace `<box>`, `<mesh-ip>` and `<user>`. Use a concrete `Host` alias: the Codex app reads concrete aliases and ignores pattern-only entries (Documented, as of 2026-09: [Codex remote connections](https://learn.chatgpt.com/docs/remote-connections)).

```bash
ssh <box> true
```

### 2. Make harness binaries visible to login shells

The Codex app launches `codex app-server` through the remote user's login shell, so `codex` must be on that PATH. Put PATH changes in `~/.profile`, not only in the interactive part of `~/.bashrc`.

```bash
ssh <box> 'bash -lc "command -v codex claude"'
```

Both paths should print. If one is missing, fix the PATH and rerun.

### 3. Claude desktop app

In the Code tab, add an SSH environment with the host alias (or `user@host`, port and identity file). On first connect the app installs Claude Code on the box and later pushes updated builds to `~/.claude/remote/ccd-cli`, so desktop sessions can run a different Claude Code version than the box's CLI. Skills come from the box; plugins come from both the box's `enabledPlugins` and the desktop app on the device (Observed, as of 2026-09; [do/06](06-sync-skills-plugins-mcp.md#3-declare-claude-plugins-in-settings)). "Continue on the web" is unavailable for SSH sessions. Details: [Claude desktop docs](https://code.claude.com/docs/en/desktop).

### 4. Codex app

Open Settings, then Connections, add the host alias, and choose a remote folder.

### 5. Editor over SSH

Connect Cursor, VS Code or Zed Remote-SSH to `<box>`. The box needs outbound HTTPS for the editor server's updates and extensions ([VS Code Remote-SSH](https://code.visualstudio.com/docs/remote/ssh)). Use the editor for reading and editing; for long agent runs, use a desktop app or the CLI ([why](../decide/access-modes.md#editors-over-ssh-unverified)).

### 6. CLI over SSH

```bash
ssh <box>
```

For runs that must outlive the terminal, use `claude --bg` or Cursor `agent persist` ([access modes](../decide/access-modes.md#cli-over-ssh-documented-for-claude)), or [add a multiplexer](08-optional-multiplexer.md).

### 7. Phone

Install an SSH client on the phone, generate a key there, authorize it on the box, and connect over the mesh. To drive live terminal sessions, [add a multiplexer](08-optional-multiplexer.md). Other phone options are compared in [access modes](../decide/access-modes.md#phone-options).

## Check

From a device:

```bash
ssh <box> true
```

Exits 0 with no output.

```bash
ssh <box> 'bash -lc "command -v codex claude"'
```

Prints a path for each harness you use.

On the box, after opening a desktop-app session from a device:

```bash
pgrep -af 'claude/remote/srv/.*/server --serve'
```

Prints one daemon after a Claude desktop session is open. Take its PID as `<pid>`.

```bash
ps -o ppid= -p <pid>
cat /proc/<pid>/cgroup
```

The parent PID is `1`, and the cgroup path ends in `session-<n>.scope`.

```bash
pgrep -af 'codex.*app-server --listen'
```

Prints one daemon after a Codex app connection, with parent PID `1` in a session scope; the app may insert `-c` overrides between `codex` and `app-server`, which the pattern allows; new connections arrive as `codex app-server proxy`.

```bash
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager KillUserProcesses
```

Prints `b false`. If it prints `b true`, desktop-app daemons die when the last login ends; fix it with [do/01 step 6](01-provision-the-host.md#6-confirm-logind-keeps-user-processes-after-logout).

Disconnect test: start a long task in a desktop-app session, quit the app or sleep the device, wait several minutes, then reconnect. The task keeps running and the same daemon PID is still alive. This is Observed behavior, not a vendor promise, so run it once on your own box.

## Needs a human

- Install the desktop apps and your editor on each device, and sign in.
- Add the SSH host in each app's UI.
- Install a phone SSH app and create its key.
- Run the disconnect test: close the app, wait, reopen.
