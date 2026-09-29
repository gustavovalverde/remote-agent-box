# Access modes

How you reach an agent and what keeps it running are separate questions. This page answers both for every mode, so you can pick how each device connects and know what survives a dropped connection or a reboot.

Every claim carries a [status label](../../README.md#status-labels), as of 2026-09.

## Modes at a glance

| Mode | Transport | Where the agent runs | Survives a disconnect | Billing | Use it for |
| --- | --- | --- | --- | --- | --- |
| Claude desktop app over SSH | SSH to the box | Desktop-app daemon on the box | Yes while `KillUserProcesses` is off (Observed) | Account signed in to the desktop app (Observed) | Daily work with long runs |
| Codex app over SSH | SSH to the box | Desktop-app daemon on the box | Yes while `KillUserProcesses` is off (Observed) | The box's `codex` login (Documented) | Daily work with long runs |
| Editor over SSH (Cursor, VS Code, Zed) | SSH to the box | Editor server on the box | Agent threads reported to stop (Unverified); VS Code docs silent | The editor's own plan | Reading and editing |
| CLI over SSH (plain) | SSH terminal | The terminal session | No: ends with the terminal (Documented for Claude) | The box's harness login or key | Quick tasks, scripts |
| CLI with a built-in background mode | SSH terminal, then detach | A supervisor or server on the box | `claude --bg` survives SSH drops (Documented); Cursor `agent persist` survives disconnect (Documented); `codex --remote` attaches to an app-server whose threads unload after 30 idle minutes (Documented) | The box's harness login or key | Terminal agents without a multiplexer |
| CLI in a multiplexer | SSH terminal | A tmux or Herdr session | Yes, until the multiplexer stops | The box's harness login or key | Phone SSH into live sessions; see [add a multiplexer](../do/08-optional-multiplexer.md) |
| OpenCode `serve` with `attach` or web | SSH port forward | OpenCode server on the box | Not documented (Unverified) | API keys or provider logins | API-key or multi-provider users |
| Claude Remote Control | Vendor relay (outbound HTTPS) | The `claude` process on the box | While the process runs; server mode exits after about 10 minutes of outage (Documented) | Subscription login only (Documented) | Phone or web control; a recorded exception |
| Codex mobile, Claude Dispatch | Vendor relay to a desktop app | A Mac or PC; with Codex, that host can drive an SSH-connected box (Unverified) | Only while that computer stays awake (Documented) | The desktop app's account | Not a box mode; a relay to record |
| Codex remote control | Vendor relay from the box's own daemon (experimental) | The Codex app-server daemon on the box | While the daemon runs (Observed, codex-cli 0.155.1) | The Codex login | Off by default; a recorded exception |

## The default: desktop app over SSH, plus an editor over SSH and the CLI

Agents run on the box in desktop-app daemons that outlive the client. The editor is for reading and editing. The CLI covers everything else. Setup is in [connect your clients](../do/05-connect-clients.md).

## What survives a disconnect

### Desktop-app daemons (Observed)

Each desktop app starts a long-lived process on the box and reconnects to it. The Claude desktop app's Code tab runs a thin `server --bridge` stdio bridge per SSH connection into a `~/.claude/remote/srv/<hash>/server --serve` daemon, with `ccd-cli` child processes. The Codex app runs `codex app-server proxy` over SSH into a long-lived `codex app-server --listen unix://`.

Both daemons are reparented to PID 1 and live inside the SSH login's session scope. They survive client disconnects while systemd-logind `KillUserProcesses` is off. Ending the session with `loginctl terminate-session` or `loginctl terminate-user` ends them. Linger plays no part. The Claude daemon log shows idle connections closing and processes re-attaching from new connections.

No vendor page promises this, and the Claude desktop docs do not state what happens to SSH sessions when the app closes. Confirm it on your own box with the disconnect test in [connect your clients](../do/05-connect-clients.md#check).

### Codex threads (Documented)

A Codex thread with no subscriber stays loaded for 30 minutes of inactivity, then unloads. Threads persist as rollouts and resume by id. `codex --remote <endpoint>` attaches the terminal UI to a running app-server. See the [Codex app-server docs](https://learn.chatgpt.com/docs/app-server).

### CLI over SSH (Documented for Claude)

A plain `claude` session ends when its terminal closes. `claude --bg` starts a session under a supervisor that survives closing the shell or dropping SSH, and is managed with `claude attach`, `claude logs`, `claude stop`, `claude respawn` and `claude agents`. See [agent view](https://code.claude.com/docs/en/agent-view.md).

Cursor's CLI documents `agent persist` (with `/detach`, `agent persist attach`, `list`, `stop` and `--resume`) for agents that keep running after disconnect. `agent login` shows a QR code for SSH authentication. See the [Cursor CLI changelog](https://cursor.com/docs/cli/changelog).

### Editors over SSH (Unverified)

The Cursor IDE agent is reported to stop or show "Reconnecting" after an SSH drop, and Zed agent panel threads are reported to be interrupted on disconnect. These come from forum and issue reports, not vendor documentation. VS Code Remote-SSH installs a server on the box and tunnels all traffic over SSH; its docs do not describe process survival on disconnect ([VS Code Remote-SSH](https://code.visualstudio.com/docs/remote/ssh)). Use the CLI or a desktop app for long runs.

## What nothing survives

A reboot ends every live agent process, in every mode.

- Claude background sessions stop on machine shutdown (Documented).
- Herdr does not keep processes across a server restart. It restores layout and relaunches supported agents with their resume command when their integration reported a session id, after a client attaches (Documented: [Herdr session state](https://herdr.dev/docs/session-state/)).
- tmux keeps nothing; restore plugins such as resurrect and continuum can replay a stale layout when no recent snapshot was saved (Observed).
- Whether desktop-app conversations resume after a host reboot has not been observed (Unverified).

## Where billing comes from

- **Claude desktop app:** Code tab sessions carry the desktop app's account through injected OAuth; the session environment includes `CLAUDE_CODE_OAUTH_TOKEN` and `CLAUDE_CODE_SUBSCRIPTION_TYPE`. The box's own `claude` login applies to terminal use (Observed). Behavior with an API-key desktop setup is Unverified.
- **Codex app:** uses the box's `codex` login, which must be signed in on the box (Documented: [Codex remote connections](https://learn.chatgpt.com/docs/remote-connections)).
- **Claude Remote Control:** needs a subscription login (Documented: [Remote Control](https://code.claude.com/docs/en/remote-control)).

For the subscription-versus-key choice, see [Harnesses and billing](choose-your-setup.md#6-harnesses-and-billing).

## Client OS support

| Client | macOS | Windows | Linux |
| --- | --- | --- | --- |
| Claude desktop app | Yes | Yes | SSH environments from a Linux client Unverified |
| Codex app | Yes | Yes | SSH environments from a Linux client Unverified |
| Editors over SSH (Cursor, VS Code, Zed) | Yes | Yes | Yes |
| CLI over SSH | Yes | Yes | Yes |

The box itself must be Linux or macOS for the Claude desktop app (Documented: [Claude desktop docs](https://code.claude.com/docs/en/desktop)).

## Phone options

- **SSH client over the mesh:** works with any phone SSH app that supports keys. Add a [multiplexer](../do/08-optional-multiplexer.md) to reach live terminal sessions.
- **Claude mobile app through Remote Control:** a relay channel, so a recorded exception. See the [security model](../learn/security-model.md#relay-channels-bypass-the-mesh).
- **Codex mobile and Claude Dispatch:** they pair with a desktop app on a Mac or PC, which must stay awake. Dispatch does not run agents on a headless box; Codex mobile can reach one only through a desktop host connected to it over SSH (Unverified), which makes it a relay to record (Documented: [Claude platforms](https://code.claude.com/docs/en/platforms.md), [Codex remote connections](https://learn.chatgpt.com/docs/remote-connections)).
- **Third-party wrappers:** exist; their behavior is Unverified.

