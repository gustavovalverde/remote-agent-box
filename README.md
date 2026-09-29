# remote-agent-box

Build an always-on Linux box that runs Claude Code, Codex and other coding harnesses, reachable from a laptop and a phone over a private mesh, where work keeps running when a device sleeps. This guide is for a developer who wants their own box, and for that developer's coding agent, which can do most of the setup by following the pages in order.

## What you end up with

- A box on a private mesh, with SSH closed on public interfaces and no ports published to the internet.
- Desktop apps over SSH as the daily clients (the Claude desktop app Code tab and the Codex app), plus an editor over SSH and the CLI over SSH.
- Skills, plugins, instructions and MCP servers kept in sync from manifests, so no harness holds a private copy.
- Encrypted, scheduled, restore-tested backups of agent config, manifests, mesh identity and project secrets.
- Harness approvals on.
- No multiplexer, unless you choose to add one (Herdr adds an optional lead-agent operating model).

## How it fits together

```text
 laptop ─┐                         ┌─ desktop-app daemons (Claude, Codex)
 phone ──┼──  private mesh  ──  box ├─ harness CLIs and their sessions
 tablet ─┘   (SSH, mesh ACL)       └─ repos, worktrees, builds, containers
```

Devices only display and type. Repos, builds and agent processes live on the box, and the mesh is the only way in. The Claude desktop app Code tab and the Codex app both run sessions on a remote machine over SSH, which makes them practical daily clients.

Read [how it works](docs/learn/how-it-works.md) for the model, and [access modes](docs/decide/access-modes.md) for what keeps running after a client disconnects.

## Pick a path

### Understand it

Read [how it works](docs/learn/how-it-works.md), then [the security model](docs/learn/security-model.md).

### Decide your setup

Read [choose your setup](docs/decide/choose-your-setup.md) for the choices that shape the build, then [access modes](docs/decide/access-modes.md) to compare ways of reaching agents. To run several agents at once, read [coordinate several agents](docs/decide/coordinate-agents.md).

### Build it with your coding agent

Open your coding agent in a clone of this repo and tell it:

```text
Read AGENTS.md and follow docs/do/00-bootstrap-with-an-agent.md.
```

The agent interviews you, walks the build pages in order, stops whenever a step needs you (logins, provider console, mesh admin console), and runs each page's checks.

### Build it by hand

Work through `docs/do/` in order:

1. [Provision the box](docs/do/01-provision-the-host.md)
2. [Lock down the network](docs/do/02-lock-down-the-network.md)
3. [Install toolchains](docs/do/03-install-toolchains.md)
4. [Install agent harnesses](docs/do/04-install-agent-harnesses.md)
5. [Connect your clients](docs/do/05-connect-clients.md)
6. [Sync skills, plugins, instructions and MCP](docs/do/06-sync-skills-plugins-mcp.md)
7. [Back up the box](docs/do/07-back-up.md)
8. [Add a multiplexer](docs/do/08-optional-multiplexer.md), only if you want one
9. [Coordinate agents with Herdr](docs/do/09-coordinate-agents-with-herdr.md), only if you chose Herdr and want a lead agent supervising others

## Before you start

- A Linux box you can order or already reach over SSH.
- An account on a private mesh (Tailscale is the worked example; Headscale, NetBird and plain WireGuard also work).
- At least one harness subscription login or API key.
- A device with an SSH client.
- A private place for box notes: your own repo or notes folder, not this one.

## What this repo does not hold

Your IP addresses, hostnames, emails, tokens, model choices and project names. Pages use placeholders such as `<box>`, `<user>` and `<mesh-ip>`. Your own values go in your box notes; [the bootstrap page](docs/do/00-bootstrap-with-an-agent.md#3-create-the-box-notes) shows the layout.

## Page map

| Page | Answers the question |
| --- | --- |
| [docs/learn/how-it-works.md](docs/learn/how-it-works.md) | What is the model, and what lessons cost time? |
| [docs/learn/security-model.md](docs/learn/security-model.md) | What protects the box, and which exceptions need recording? |
| [docs/decide/choose-your-setup.md](docs/decide/choose-your-setup.md) | Which options fit me, and what are the defaults? |
| [docs/decide/access-modes.md](docs/decide/access-modes.md) | How do clients reach agents, and what survives a disconnect or reboot? |
| [docs/decide/coordinate-agents.md](docs/decide/coordinate-agents.md) | Should I supervise native CLIs or use a unifying harness, and how many agents do I run? |
| [docs/do/00-bootstrap-with-an-agent.md](docs/do/00-bootstrap-with-an-agent.md) | How does my coding agent run this build? |
| [docs/do/01-provision-the-host.md](docs/do/01-provision-the-host.md) | How do I get a sized, updated box with a non-root user? |
| [docs/do/02-lock-down-the-network.md](docs/do/02-lock-down-the-network.md) | How do I join the mesh and close public interfaces? |
| [docs/do/03-install-toolchains.md](docs/do/03-install-toolchains.md) | How do I install Node, Rust, Docker and GitHub auth? |
| [docs/do/04-install-agent-harnesses.md](docs/do/04-install-agent-harnesses.md) | How do I install and log in to harnesses? |
| [docs/do/05-connect-clients.md](docs/do/05-connect-clients.md) | How do I connect desktop apps, editors and a phone, and prove agents survive a disconnect? |
| [docs/do/06-sync-skills-plugins-mcp.md](docs/do/06-sync-skills-plugins-mcp.md) | How do I keep skills, plugins, instructions and MCP in sync? |
| [docs/do/07-back-up.md](docs/do/07-back-up.md) | How do I back up and test a restore? |
| [docs/do/08-optional-multiplexer.md](docs/do/08-optional-multiplexer.md) | How do I add tmux or Herdr, and configure Herdr, if I want one? |
| [docs/do/09-coordinate-agents-with-herdr.md](docs/do/09-coordinate-agents-with-herdr.md) | How does a lead agent supervise other agents in Herdr with evidence-based completion? |
| [examples/ssh-config](examples/ssh-config) | What does a client SSH config for the box look like? |
| [examples/docker-daemon.json](examples/docker-daemon.json) | How do I make Docker bind to loopback by default? |
| [examples/herdr-config.toml](examples/herdr-config.toml) | What is the tested Herdr config baseline? |
| [examples/skills.txt](examples/skills.txt) | What does a skills manifest look like? |
| [examples/claude-settings.fragment.json](examples/claude-settings.fragment.json) | Which Claude settings declare marketplaces and plugins? |
| [examples/codex-config.fragment.toml](examples/codex-config.fragment.toml) | Which Codex config keys matter for this setup? |
| [scripts/check-public.sh](scripts/check-public.sh) | How do contributors check that no instance data leaked in? |

## Status labels

Vendor facts are as of 2026-09. Behavior claims carry one of three labels:

- **Documented:** a vendor page says so, and the page is linked.
- **Observed:** seen on a real box, not promised by the vendor.
- **Unverified:** nobody has confirmed it.

Open an issue when a vendor changes behavior.

## License

MIT. See [LICENSE](LICENSE).
