# Add a multiplexer (optional)

You get tmux or Herdr set up so terminal agents can be reattached from any SSH client, including a phone. For Herdr you also get a tested config baseline with a reason for each setting.

## Goal

Reattach to live terminal agents from any SSH client.

## Before you start

- [do/05](05-connect-clients.md) is done.
- Skip this page if you use desktop apps over SSH and run CLI work with `claude --bg` or Cursor `agent persist`. A multiplexer adds a second thing to maintain and keeps no live processes through a reboot. It earns its place if you run terminal agents or want phone SSH into live sessions.
- A multiplexer is not a security boundary: anything running as your user can read and type into every pane ([security model](../learn/security-model.md#a-multiplexer-is-not-a-security-boundary)).

## Steps

### Option A: tmux

```bash
sudo apt-get install -y tmux
tmux new -A -s main
```

To bring an empty `main` session back after boot, create `~/.config/systemd/user/tmux-main.service`:

```ini
[Unit]
Description=tmux main session

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'tmux has-session -t main || tmux new-session -d -s main'

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable tmux-main.service
sudo loginctl enable-linger <user>
```

After a reboot only an empty session returns; live processes do not. Restore plugins can replay a stale layout (Observed, as of 2026-09), so verify before relying on one.

### Option B: Herdr

Herdr is agent-aware and pre-1.0: releases are frequent and can break things, such as removing `--no-session` in v0.9.0 (as of 2026-09; [releases](https://github.com/herdrdev/herdr/releases)). The settings below were checked against the v0.9.x docs. To supervise several agents with it, see [coordinate agents](../decide/coordinate-agents.md) and [do/09](09-coordinate-agents-with-herdr.md).

#### Install

Install per [herdr.dev](https://herdr.dev/docs/install/):

```bash
curl -fsSL https://herdr.dev/install.sh | sh
herdr
```

Attach from a device with `herdr --remote <box>`, or save the box once with `herdr machine add <box>`; saved machines hold no passwords or keys, and authentication stays with OpenSSH (Documented: [connecting machines](https://herdr.dev/docs/connecting-machines/)).

#### Integrations

Let agents report session ids so they can resume. Install only the integrations for harnesses you use:

```bash
herdr integration install claude
herdr integration install codex
herdr integration install cursor
herdr integration install opencode
herdr integration status
```

For Codex, Claude Code and Cursor the integration supplies native session identity for restore. It is not a lifecycle authority: Herdr classifies their state from the screen (Documented: [Herdr agents](https://herdr.dev/docs/agents/)).

#### The skill

The skill teaches a lead agent the Herdr commands. It acts only when `HERDR_ENV=1`, which Herdr sets in its managed panes, and otherwise stops (Documented: [agent skill](https://herdr.dev/docs/agent-skill/)):

```bash
npx skills add herdrdev/herdr --skill herdr -g
```

To keep it in your manifest, see the optional line in [skills.txt](../../examples/skills.txt). The repository copy can differ from your installed release; `herdr --skill` prints the copy bundled with your binary (Documented). `HERDR_ENV` steers the agent; it is not a security boundary. Do not start a Herdr TUI inside a Herdr pane.

#### Config baseline

Copy [herdr-config.toml](../../examples/herdr-config.toml) to `~/.config/herdr/config.toml`, then apply it:

```bash
herdr server reload-config
```

Reload applies most UI settings without restarting panes; startup-only settings need a restart (Documented: [configuration](https://herdr.dev/docs/configuration/)). Herdr works with no config file, and `herdr --default-config` prints the defaults. Rows marked (default) match the Herdr default and are set explicitly so the baseline holds if a default changes.

| Setting | Value | Why |
| --- | --- | --- |
| `terminal.new_cwd` | `"follow"` (default) | New panes start in the current repository or worktree |
| `worktrees.directory` | `"~/.herdr/worktrees"` (default) | Agent checkouts stay out of the source repository |
| `ui.sidebar_width` | `32` | Room for workspace and agent names |
| `ui.confirm_close` | `true` (default) | A stray keypress cannot close a workspace with a running agent |
| `ui.prompt_new_workspace_name` | `true` | Workspaces get meaningful names |
| `ui.agent_panel_sort` | `"priority"` | The agent list becomes an attention queue |
| `ui.status_indicators` | `"symbols"` | States are distinguishable without color |
| `ui.show_agent_labels_on_pane_borders` | `true` | You can tell which agent owns a pane at a glance |
| `ui.toast.delivery`, `ui.toast.herdr.position` | `"herdr"`, `"top-right"` | Silent in-app toasts for finished and needs-input agents |
| `ui.sound.enabled` | `false` | Silence on a shared or remote session |
| `session.resume_agents_on_restore` | `true` (default) | Integrated agents relaunch with their resume command |
| `advanced.scrollback_limit_bytes` | `52428800` | 50 MiB per pane, against a default of about 10 MB, for reviewing long sessions |
| `experimental.pane_history` | `true` | See the trade-off below |

Defaults are from the [config reference](https://herdr.dev/docs/config-reference/) (Documented, as of 2026-09).

The example ends with commented bindings for the optional Annotate plugin, which reviews plans, terminal output and agent replies. Plugins run with your user privileges, so read its code and install it only at a pinned commit (`herdr plugin install plannotator/herdr-annotate --ref <commit>`), never with an auto-updating source.

#### Trade-off: pane history

The baseline turns `pane_history` on and raises scrollback to 50 MiB. That keeps long agent context available for review, and after a server restart the recent screen returns.

The cost is retention. `pane_history = true` writes recent pane output to `session-history.json` beside `session.json`, and that output can hold prompts, code, logs, provider data and secrets (Documented: [session state](https://herdr.dev/docs/session-state/)). The docs describe that file as recent screen content; they do not say the whole scrollback buffer is written. Treat `~/.config/herdr` like terminal history: keep it out of backups you share and out of repositories, and do not enable this on a box where you print secrets into panes. To avoid the file, set `pane_history = false`; you lose screen replay after a restart, not live detach and reattach.

When agent restore applies to a pane, Herdr resumes the agent session instead of replaying saved history for that pane (Documented: [session state](https://herdr.dev/docs/session-state/)). History replay therefore matters for plain shells and unsupported agents.

#### What persistence means

"Survives" covers three different events (Documented: [session state](https://herdr.dev/docs/session-state/), as of 2026-09):

| Event | Processes | What returns |
| --- | --- | --- |
| Detach (`ctrl+b`, then `q`), terminal close or SSH drop | Keep running | Layout and recent screen; agent conversations continue because nothing stopped |
| Server restart (`herdr server stop`, then start) | Gone | Workspaces, tabs, panes, directories, layout and focus; panes reopen as fresh shells |
| Agent restore | A new process | A supported agent resumes its conversation from the session id its integration reported, once a client attaches |

Recent screen content returns after a restart only with `pane_history`. Herdr documents no boot autostart, and a user unit running `herdr server` is Unverified.

### Optional: mosh for flaky networks

```bash
sudo apt-get install -y mosh
sudo ufw allow in on <mesh-iface> to any port 60000:61000 proto udp
```


## Check

tmux:

```bash
tmux ls          # lists main
```

After the reboot test in Needs a human, `tmux ls` lists main if the unit is enabled.

Herdr:

```bash
herdr status                 # reports the server running while a client is attached
herdr integration status     # lists your chosen harnesses as current
herdr server reload-config   # succeeds after you copy the baseline config
npx skills list -g | grep -i herdr   # lists the herdr skill if you installed it
```

## Needs a human

- A phone SSH app and key.
- The choice to keep or drop `pane_history`, given the retention cost above.
- The reboot test: run `sudo reboot` yourself (it ends every live agent session), reconnect, then run `tmux ls`.
