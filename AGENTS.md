# Agent guide

This repo is a public guide for building an always-on remote Linux box that runs coding harnesses. You open it in one of two roles; follow the section that matches your task.

## If you are building a box

- Start at [docs/do/00-bootstrap-with-an-agent.md](docs/do/00-bootstrap-with-an-agent.md) and walk the `docs/do/` pages in order.
- Stop at every "Needs a human" item and wait for the person. Do not guess past a login, a provider console or a mesh admin console.
- Run every Check. Do not advance to the next page on a failure; fix it until the original check passes.
- Write the person's answers and host facts only to their box notes, never to this repo.
- Never print secret values. For `auth.json`, `.env*`, `~/.claude.json`, `mcp.json`, `.npmrc` and similar files, read only key names with `jq` or `grep`.
- Never turn approvals off, enable a relay channel or open a public port on your own initiative. Each is the person's decision, recorded as an exception ([security model](docs/learn/security-model.md#recording-an-exception)).
- Keep a second SSH session open during network changes.
- Ask before destructive commands: disk formatting, reboots, firewall changes without the dead-man switch in [do/02](docs/do/02-lock-down-the-network.md), and `loginctl terminate-*`.

## If you are editing this repo

### Page shapes

- `docs/learn/` explains. It builds understanding and links out for steps.
- `docs/decide/` compares options and states a default for each.
- `docs/do/` pages use exactly these sections, in order: Goal, Before you start, Steps, Check, Needs a human. Check holds copy-pasteable commands with expected results and never prints secret values.

### One owner per topic

Other pages link to the owner instead of repeating the topic.

| Topic | Owning page |
| --- | --- |
| Orientation, reading paths, page map, status labels | [README.md](README.md) |
| Agent operating rules, ownership map, contribution rules | [AGENTS.md](AGENTS.md) |
| The box-holds-the-work model, three layers, second-copy-of-state test, daily rules, lessons (disk sizing, group membership, managed defaults) | [how-it-works](docs/learn/how-it-works.md) |
| Threat model, mesh ACL as peer boundary, firewall ordering, Docker publish bypass, relay channels, multiplexer as non-boundary, approvals trade-off, credential rules, exception record | [security-model](docs/learn/security-model.md) |
| Setup decisions and defaults, billing model, OpenCode and the Claude subscription | [choose-your-setup](docs/decide/choose-your-setup.md) |
| Native CLIs versus a unifying harness, lead and team size, roles, evidence for completion, deferred tooling | [coordinate-agents](docs/decide/coordinate-agents.md) |
| Access modes, disconnect and reboot survival, billing per client, client OS support, phone options | [access-modes](docs/decide/access-modes.md) |
| Agent bootstrap, interview, box notes layout, consolidated hand-offs, done criteria | [do/00](docs/do/00-bootstrap-with-an-agent.md) |
| Ordering, OS install, user, base packages, updates and reboots, logind `KillUserProcesses` | [do/01](docs/do/01-provision-the-host.md) |
| Mesh join and ACL, sshd hardening, UFW with dead-man switch, Docker bind, Funnel and Serve reset | [do/02](docs/do/02-lock-down-the-network.md) |
| Node, Rust, Docker Engine, git identity, GitHub auth, disk hygiene | [do/03](docs/do/03-install-toolchains.md) |
| Harness install and update, login stores, approvals and relay settings | [do/04](docs/do/04-install-agent-harnesses.md) |
| Device SSH config, desktop apps and editors over SSH, login-shell PATH, disconnect test | [do/05](docs/do/05-connect-clients.md) |
| Sync matrix, skills manifest, plugins, instructions core, MCP, model pin keys, what is not synced | [do/06](docs/do/06-sync-skills-plugins-mcp.md) |
| Backup scope, project secrets, restic schedule and restore test, pre-wipe check | [do/07](docs/do/07-back-up.md) |
| When a multiplexer is worth it, tmux, Herdr install, integrations, config baseline, `pane_history` trade-off, persistence meanings, mosh | [do/08](docs/do/08-optional-multiplexer.md) |
| Lead agent recipes in Herdr: task brief, native commands, worktrees, verification pane, blocked questions, detach, diagnostics | [do/09](docs/do/09-coordinate-agents-with-herdr.md) |
| Public-content lint rules | [scripts/check-public.sh](scripts/check-public.sh) |

### Facts carry a label and a date

Label every survival, billing and relay claim with a status label from the [README](README.md#status-labels) and "as of 2026-09". Link vendor docs for install URLs and version-sensitive details. For model pins, document the config key name, never a value.

### Placeholders

Use `<box>`, `<user>`, `<mesh-ip>`, `<mesh-iface>`, `<public-ip>`, `<owner/repo>`, `<plugin>`, `<marketplace>`, `<model>` and `<notes-dir>`. Name any other value the same way, for example `<port>`. Never use a realistic-looking sample value.

### Writing rules

- Lead every page with what the reader gets.
- No em dashes; use colons, semicolons or parentheses.
- Describe the current state only.
- Keep greppable names (commands, config keys, file paths) exact.
- Use the glossary terms: "box" (not "server", "host" or "VPS" for the machine itself), "harness" (not "agent CLI"), "mesh" (not "VPN").

### Before you commit

Run `bash scripts/check-public.sh`; it fails on instance data such as mesh addresses, tailnet names, emails and em dashes. Set `PUBLIC_DENYLIST` to your own instance terms (hostnames, project names) to catch those too. Commit with a GitHub noreply email address, set before the first commit:

1. `git config user.email '<id>+<user>@users.noreply.github.com'` (repo-local, so the global address is not used).
2. On the GitHub account, enable "Block command line pushes that expose my email".
3. Run `bash scripts/check-public.sh --commits` before the first push; the CI commit check only runs after the push, when an address is already public.
4. Before publishing, set the `PUBLIC_DENYLIST` secret and the `REQUIRE_DENYLIST=true` variable. Without them CI skips the denylist and instance terms go unchecked.

## Repository layout

```text
README.md  AGENTS.md  CLAUDE.md  LICENSE
docs/learn/     explanations
docs/decide/    option comparisons and defaults
docs/do/        numbered build pages, 00 to 09
examples/       manifests and config fragments
scripts/        check-public.sh
.github/workflows/check.yml
```
