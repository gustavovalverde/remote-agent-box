# Add a multiplexer (optional)

You get tmux or Herdr set up so terminal agents can be reattached from any SSH client, including a phone.

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

Herdr is agent-aware and pre-1.0: releases are frequent and can break things, such as removing `--no-session` in v0.9.0 (as of 2026-09; [releases](https://github.com/herdrdev/herdr/releases)). Install per [herdr.dev](https://herdr.dev/docs/install/):

```bash
curl -fsSL https://herdr.dev/install.sh | sh
herdr
```

Let agents report session ids so they can resume:

```bash
herdr integration install claude
herdr integration install codex
herdr integration install cursor
herdr integration install opencode
herdr integration status
```

Install only the integrations for harnesses you use. Attach from a device with `herdr --remote <box>`, or save the box once with `herdr machine add <box>`; saved machines hold no credentials.

Documented (as of 2026-09; [session state](https://herdr.dev/docs/session-state/), [persistence and remote](https://herdr.dev/docs/persistence-remote/)): detach and reattach keep processes; a server restart restores the layout, not processes; with `resume_agents_on_restore`, integrated agents resume after a client attaches. Herdr documents no boot autostart, and a user unit running `herdr server` is Unverified. Leave `pane_history` off, or treat `~/.config/herdr` like terminal history.

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
herdr status               # reports the server running while a client is attached
herdr integration status   # lists your chosen harnesses as current
```

## Needs a human

- A phone SSH app and key.
- The reboot test: run `sudo reboot` yourself (it ends every live agent session), reconnect, then run `tmux ls`.
