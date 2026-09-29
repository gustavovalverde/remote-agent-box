# Security model

This page gives you a clear picture of who can reach your box and what agents can do once they run. Read it before [locking down the network](../do/02-lock-down-the-network.md), and again before you grant any exception.

Claims carry a [status label](../../README.md#status-labels), as of 2026-09.

## What the box protects, and what it does not

The network layers below limit who can connect to the box. They do not limit what an agent does after it starts. A harness runs commands as your user, with your files, your logged-in accounts and your network access.

With approvals on, each command or edit waits for you. With approvals off, nothing waits, and containment reduces to two things: the scope of the credentials on the box, and the security of the accounts those credentials belong to. Give the box tokens that can do only what its work needs, and turn on multi-factor authentication for the provider, mesh and source-hosting accounts behind them.

## Layers, outside in

### The mesh ACL is the peer boundary

Every listener bound to <mesh-ip> or 0.0.0.0 is reachable by every peer the mesh ACL allows. The host firewall does not narrow that (see "On Tailscale, mesh traffic skips UFW" below). So the policy is where you decide which devices reach which ports.

Tag the box, allow only your own devices to reach it, and list the ports they need (22 at minimum). Adding a phone or a new laptop later is an edit to this policy, not to the box. Each mesh names its policy differently: a Tailscale policy file, a Headscale ACL, NetBird policies. Plain WireGuard has no policy layer; there, the peer list and the host firewall are all you have.

### The host firewall closes everything that is not the mesh

The host firewall (UFW here) has a narrower job: deny incoming traffic by default and allow SSH only on <mesh-iface>. That keeps the box off the public internet. It is not what separates one mesh peer from another.

sshd still binds all addresses (0.0.0.0:22 and [::]:22), so the firewall alone keeps it off the public interface (Observed). If the firewall is disabled or flushed, SSH is public again.

### sshd accepts keys only

Password and keyboard-interactive logins are off, and root can log in only with a key. A public SSH port then costs the attacker a key guess instead of a password guess, which is a useful second layer if the firewall ever fails. The steps are in [lock down the network](../do/02-lock-down-the-network.md).

### Docker publishes bypass the host firewall

Docker publishes a port by rewriting the destination of incoming packets (DNAT) before UFW's rules see them. A compose file that publishes a port on 0.0.0.0 or [::] is reachable from the public interface even when UFW says deny, as long as the DOCKER-USER chain is empty (Observed). An explicit host address in a compose file overrides the daemon default.

So the daemon default bind is 127.0.0.1, every compose `ports:` entry names its host address, and a bind to <mesh-ip> is an exception because it exposes the port to every peer the ACL allows. The steps are in [lock down the network](../do/02-lock-down-the-network.md#5-keep-docker-off-public-interfaces).

### Funnel and Serve publish ports

Tailscale Funnel publishes a local port to the public internet; Serve publishes it inside the tailnet. A Funnel entry left in place with nothing listening behind it is a trap: the next process to start on that port is public (Observed). Keep both off unless you record an exception; the reset is in [lock down the network](../do/02-lock-down-the-network.md#6-turn-off-funnel-and-serve).

## On Tailscale, mesh traffic skips UFW

Tailscale's daemon installs its own chain, ts-input, and jumps to it before any UFW chain. That chain accepts traffic arriving on the mesh interface. So UFW rules scoped to <mesh-iface> do not filter per port between peers: a listener on <mesh-ip> is reachable by any allowed peer whether or not a UFW rule mentions it.

Observed: `sudo iptables -S INPUT` shows `-A INPUT -j ts-input` ahead of every UFW chain, and ts-input holds an ACCEPT for the mesh interface. Look at your own box to see the same ordering:

```bash
sudo iptables -S INPUT
sudo iptables -S ts-input
```

The consequence is the one above: the ACL is your per-port control between peers. Other meshes order their rules differently; check yours before assuming.

## Relay channels bypass the mesh

A relay channel is a vendor-hosted outbound connection that lets a web or phone client drive an agent without going through the mesh. Nothing on your firewall or ACL sees it; the vendor account, not the mesh, decides who can drive the agent. Default: off. Each one you keep is an exception you record. How each channel works, and what it needs, is in [access modes](../decide/access-modes.md).

- Claude Remote Control uses outbound HTTPS only and opens no inbound port. A phone or web client can drive the session; mobile Remote Control sessions cannot use bypass permissions (Documented: [Remote Control](https://code.claude.com/docs/en/remote-control), [mobile](https://code.claude.com/docs/en/mobile.md)).
- Codex mobile pairing relays prompts and approvals from a phone to a paired desktop Codex app on a Mac or PC (Documented: [remote connections](https://learn.chatgpt.com/docs/remote-connections)). The same page describes connecting that desktop host to an SSH environment, so a phone could then drive agents that run on the box (Unverified). Record it as a relay.
- The Codex CLI ships an experimental relay for the box's own daemon: `codex remote-control start|stop|pair` and `codex app-server daemon enable-remote-control|disable-remote-control` (Observed, experimental, codex-cli 0.155.1, as of 2026-09). Remove it with `codex app-server daemon disable-remote-control` or `codex remote-control stop`.
- Claude Code settings `remoteControlAtStartup` and `crossSessionInbound` exist in `~/.claude/settings.json`. What `crossSessionInbound` opens is not confirmed from vendor documentation (Unverified). Check both keys on your box and leave them off until you know.

Two harness servers are easy to expose by accident. `codex app-server` has an experimental `ws://` transport whose non-loopback listeners accept unauthenticated connections by default, and OpenAI says to reach it only through a private network ([app server](https://learn.chatgpt.com/docs/app-server)). `opencode serve` binds 127.0.0.1:4096 by default and is unsecured unless `OPENCODE_SERVER_PASSWORD` is set ([server docs](https://opencode.ai/docs/server/)). Both are Documented. Keep both on loopback.

## A multiplexer is not a security boundary

tmux and Herdr are optional (see [optional multiplexer](../do/08-optional-multiplexer.md)). Neither separates anything. Their control surface is a local Unix socket, and any process running as the same user can read every pane and type into it.

Documented ([Herdr persistence](https://herdr.dev/docs/persistence-remote/), [session state](https://herdr.dev/docs/session-state/)): Herdr's sockets are mode 0600, and its socket API can inject input into any pane, so anything running as your user controls the agents inside. With `pane_history = true`, Herdr writes recent pane output to `session-history.json` on disk, and that output can contain prompts, code, logs and secrets. It is off by default. Turning it on is a deliberate trade-off for screen replay after a server restart, and you then treat `~/.config/herdr` like terminal history; the trade-off is set out in [add a multiplexer](../do/08-optional-multiplexer.md#trade-off-pane-history).

## Harness approvals

### Default: approvals on

Both Claude Code and Codex ask before running commands or editing files, within the rules you configure. Keep that default. It is the one control that limits what an agent does, and no network layer replaces it.

### Approvals off is a trade-off you record

Running with approvals off is legitimate for sandboxed or disposable work. It is a decision, so make it deliberately and write it down as an exception.

| Harness | Persistent setting | One-run flag |
| --- | --- | --- |
| Claude Code | `permissions.defaultMode` set to `bypassPermissions`; `skipDangerousModePermissionPrompt` hides the warning | `--dangerously-skip-permissions` |
| Codex | `approval_policy = "never"` and `sandbox_mode = "danger-full-access"` in `config.toml` | `--dangerously-bypass-approvals-and-sandbox` |

Both flags and the Codex keys behave as described (Observed).

What you give up: every prompt injection in a file, web page or dependency the agent reads can run commands as your user without asking. The blast radius is everything your user can reach, including deploy keys, cloud tokens and any device the box can SSH to. Prefer the one-run flag over the persistent setting, and prefer narrow credentials over either.

## Credentials on the box

- Harness logins stay in each vendor's own store (the harness's own login flow writes them). Do not copy them into your notes or manifests, and do not commit them.
- MCP servers authenticate with OAuth or with the name of an environment variable, never a literal token or authorization header in a config file. A static header fails with HTTP 401 once the token expires, and the harness does not fall back to OAuth (Observed); OAuth entries (for example `codex mcp login <name>`) refresh on their own.
- A process argument list can carry a credential, and other local users can read it when `/proc` is mounted without `hidepid`. Editor agent workers have been seen with an `--api-key` flag in their arguments (Observed). Avoid tools that take keys as arguments, or keep the box single-user.
- Never paste secrets into an agent chat. They land in transcripts on the box and at the vendor.
- Project secrets have one encrypted home, described in [back up](../do/07-back-up.md). Do not scatter them across dotfiles.

## Recording an exception

An exception is a deliberate, recorded departure from a default: a relay channel, a port bound to <mesh-ip>, Funnel or Serve, approvals off. Keep the record in your box notes (never in this repository), one row each:

| Field | Meaning |
| --- | --- |
| What | The thing that is on |
| Who can reach it | Which peers, accounts or the public |
| Why | The need it serves |
| Owner | The person who answers for it |
| Date | When it was granted |
| Check | A command that shows the current state |
| Remove | How to turn it off |

Example rows, with placeholders:

| What | Who can reach it | Why | Owner | Date | Check | Remove |
| --- | --- | --- | --- | --- | --- | --- |
| Compose service bound to `<mesh-ip>:<port>` | Every peer the ACL allows to <port> | Open the preview from a phone | <user> | 2026-09 | `ss -tln \| grep <port>` | Change the bind to 127.0.0.1 and recreate the service |
| Claude Remote Control on | Phone and web, via the vendor relay | Approve prompts away from a laptop | <user> | 2026-09 | `jq '.remoteControlAtStartup' ~/.claude/settings.json` | Set the key to false and restart the session |

Review the record whenever you change the mesh ACL, and before you hand the box to anyone else.
