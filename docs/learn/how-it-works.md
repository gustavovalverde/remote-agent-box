# How a remote agent box works

After reading this page you can explain where your work lives, why agents run there, what the three layers are, and which mistakes cost the most time.

## The box holds the work; every device is a window

Repos, builds, containers and agent processes live on the box. Devices only display and type. Close the laptop and the agents keep going; [access modes](../decide/access-modes.md) says exactly which ones, and what a reboot ends (every live agent, in every mode).

## Why move agents off the laptop

- Laptop sleep and network changes end runs.
- Parallel agents and builds need cores, RAM and disk that a laptop should not spend.
- Every device sees one environment instead of its own drifting copy.

## Three layers

### The box

Hardware, OS, mesh, host firewall and toolchains. Built in [do/01](../do/01-provision-the-host.md) to [do/03](../do/03-install-toolchains.md).

### Access

How clients reach agents and what keeps them running. Compared in [access modes](../decide/access-modes.md), wired up in [do/05](../do/05-connect-clients.md).

### Harnesses and their config

Harnesses, their logins and approvals, and the skills, plugins, instructions and MCP servers that follow them. Built in [do/04](../do/04-install-agent-harnesses.md) and [do/06](../do/06-sync-skills-plugins-mcp.md).

## One test for any new tool

Ask whether it creates a second copy of state that can drift. Second copies seen in practice (Observed, as of 2026-09):

- The same skill copied into several harness directories next to the shared skills store.
- Plugin marketplaces registered by hand that no settings file declares.
- Two global instruction files edited separately, with diverging content.
- An old package-manager install of a harness shadowing the vendor install on `PATH`.

The remedy is one source per concern, applied by a vendor command from a manifest. See [do/06](../do/06-sync-skills-plugins-mcp.md).

## Daily rules

- A repo lives where it builds: on the box.
- One worktree per agent.
- Never mount the box's filesystem on a device.
- Move work with git, not file copies.
- Approvals stay on unless you recorded an exception; see [the security model](security-model.md).

## Lessons that cost time

### Order enough disk up front

On many dedicated-server offers, storage is fixed at order time and cannot be added later. RAID1 across two equal disks leaves about half the raw capacity. Size for repos times worktrees, plus build caches and container images.

### New group membership needs a fresh login

A process's groups are fixed when it starts. Long-lived sessions, such as desktop-app daemons and multiplexers, do not see a newly added group like `docker` until they restart. Reconnecting a desktop app does not help: it re-attaches to the same daemon, which keeps its old group list (Observed, as of 2026-09). Restart the daemon itself: `codex app-server daemon restart` for Codex; for Claude, end the `~/.claude/remote/srv/*/server --serve` process after its sessions finish, then reconnect. `loginctl terminate-user` also works but ends every desktop-app daemon and lingering user service, so use it deliberately.

### Leave a tool's managed defaults alone until you know why they exist

Pinning an editor-managed language server's binary path (rust-analyzer in an editor's settings) broke once repos used different toolchains; the editor's own resolution handles per-repo toolchains. Before overriding a default a tool manages for you, find out what it handles.
